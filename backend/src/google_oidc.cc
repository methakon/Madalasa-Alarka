// Pure Google OIDC authentication. No network I/O or authority inference.
#include "google_oidc.h"
#include <json/json.h>
#include <openssl/bn.h>
#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <openssl/param_build.h>
#include <openssl/rsa.h>
#include <algorithm>
#include <limits>
#include <set>

namespace ma {
namespace {
template<class T, void (*Free)(T*)> using Owned = std::unique_ptr<T, decltype(Free)>;
bool utf8(std::string_view s) {
  for (std::size_t i=0;i<s.size();) {
    auto c=static_cast<unsigned char>(s[i++]); unsigned cp; std::size_t n;
    if(c<128){cp=c;n=0;} else if(c>=0xc2 && c<=0xdf){cp=c&31;n=1;}
    else if(c>=0xe0 && c<=0xef){cp=c&15;n=2;} else if(c>=0xf0 && c<=0xf4){cp=c&7;n=3;} else return false;
    if(n>s.size()-i)return false;
    for(std::size_t j=0;j<n;++j){auto b=static_cast<unsigned char>(s[i++]);if((b&192)!=128)return false;cp=(cp<<6)|(b&63);}
    if((n==1 && cp<128)||(n==2 && cp<2048)||(n==3 && cp<65536)||cp>0x10ffff||(cp>=0xd800 && cp<=0xdfff))return false;
  }
  return true;
}
bool valid_tree(const Json::Value& v) {
  if(v.isString())return utf8(v.asString());
  if(v.isObject())for(const auto& name:v.getMemberNames())if(!utf8(name)||!valid_tree(v[name]))return false;
  if(v.isArray())for(const auto& x:v)if(!valid_tree(x))return false;
  return true;
}
bool object(std::string_view s, Json::Value& v) {
  if(!utf8(s))return false;
  Json::CharReaderBuilder b;Json::CharReaderBuilder::strictMode(&b.settings_);
  b["rejectDupKeys"]=true;b["failIfExtra"]=true;b["stackLimit"]=16;b["skipBom"]=false;
  std::unique_ptr<Json::CharReader> reader(b.newCharReader());
  std::string errors;
  return reader->parse(s.data(),s.data()+s.size(),&v,&errors)&&v.isObject()&&valid_tree(v);
}
std::optional<std::string> decode(std::string_view s) {
  if(s.empty()||s.size()%4==1)return std::nullopt;
  std::string out;out.reserve(s.size()*3/4);unsigned acc=0;int bits=0;
  for(unsigned char c:s){unsigned v;
    if(c>='A'&&c<='Z')v=c-'A';else if(c>='a'&&c<='z')v=c-'a'+26;
    else if(c>='0'&&c<='9')v=c-'0'+52;else if(c=='-')v=62;else if(c=='_')v=63;else return std::nullopt;
    acc=(acc<<6)|v;bits+=6;if(bits>=8){bits-=8;out+=static_cast<char>((acc>>bits)&255);}
  }
  if(bits && (acc&((1u<<bits)-1)))return std::nullopt;
  return out;
}
bool text(const Json::Value& v,std::size_t max) {
  if(!v.isString())return false;
  auto s=v.asString();
  if(s.empty()||s.size()>max||!utf8(s))return false;
  for(std::size_t i=0;i<s.size();++i){
    auto c=static_cast<unsigned char>(s[i]);
    if(c<32||c==127)return false;
    // Unicode C1 controls U+0080..U+009F, encoded canonically in UTF-8.
    if(c==0xc2 && i+1<s.size() && static_cast<unsigned char>(s[i+1])<=0x9f)return false;
  }
  return true;
}
bool member_text(const Json::Value& v,const char* n,std::size_t max){return v.isMember(n)&&text(v[n],max);}
bool strings(const std::vector<std::string>& values) {
  if(values.size()>32)return false;
  std::set<std::string> seen;
  for(const auto& v:values)if(!text(Json::Value(v),1024)||!seen.insert(v).second)return false;
  return true;
}
bool contains(const std::vector<std::string>& values,const std::string& v){return std::find(values.begin(),values.end(),v)!=values.end();}
bool date(const Json::Value& v,std::int64_t& out) {
  if((v.type()!=Json::intValue && v.type()!=Json::uintValue)||!v.isInt64())return false;
  out=v.asInt64();return true;
}
// Ordered subtraction in unsigned arithmetic remains defined even across INT64 limits.
bool ahead(std::int64_t value,std::int64_t now,std::int64_t skew) {
  return value>now && static_cast<std::uint64_t>(value)-static_cast<std::uint64_t>(now)>static_cast<std::uint64_t>(skew);
}
}  // namespace
std::optional<OidcKeys> parse_google_jwks(std::string_view body) {
  try {
    if(body.empty()||body.size()>256*1024)return std::nullopt;
    Json::Value root;if(!object(body,root)||!root["keys"].isArray()||root["keys"].empty()||root["keys"].size()>32)return std::nullopt;
    OidcKeys keys;
    for(const auto& k:root["keys"]){
      if(!k.isObject()||k["kty"]!="RSA"||!member_text(k,"kid",128))return std::nullopt;
      for(auto name:{"d","p","q","dp","dq","qi","oth"})if(k.isMember(name))return std::nullopt;
      if((k.isMember("alg")&&k["alg"]!="RS256")||(k.isMember("use")&&k["use"]!="sig"))return std::nullopt;
      if(k.isMember("key_ops")&&(!k["key_ops"].isArray()||k["key_ops"].size()!=1||k["key_ops"][0]!="verify"))return std::nullopt;
      if(!member_text(k,"n",1366)||!member_text(k,"e",6))return std::nullopt;
      auto n=decode(k["n"].asString()),e=decode(k["e"].asString());
      if(!n||!e||n->size()>1024||n->size()<256||e->size()>4||(*n)[0]=='\0'||(*e)[0]=='\0')return std::nullopt;
      Owned<BIGNUM,BN_free> bn(BN_bin2bn(reinterpret_cast<const unsigned char*>(n->data()),static_cast<int>(n->size()),nullptr),BN_free);
      Owned<BIGNUM,BN_free> be(BN_bin2bn(reinterpret_cast<const unsigned char*>(e->data()),static_cast<int>(e->size()),nullptr),BN_free);
      if(!bn||!be||BN_num_bits(bn.get())<2048||BN_num_bits(bn.get())>8192||!BN_is_odd(bn.get())||!BN_is_odd(be.get())||BN_get_word(be.get())<3)return std::nullopt;
      Owned<OSSL_PARAM_BLD,OSSL_PARAM_BLD_free> builder(OSSL_PARAM_BLD_new(),OSSL_PARAM_BLD_free);
      if(!builder||OSSL_PARAM_BLD_push_BN(builder.get(),OSSL_PKEY_PARAM_RSA_N,bn.get())!=1||OSSL_PARAM_BLD_push_BN(builder.get(),OSSL_PKEY_PARAM_RSA_E,be.get())!=1)return std::nullopt;
      Owned<OSSL_PARAM,OSSL_PARAM_free> params(OSSL_PARAM_BLD_to_param(builder.get()),OSSL_PARAM_free);
      Owned<EVP_PKEY_CTX,EVP_PKEY_CTX_free> ctx(EVP_PKEY_CTX_new_from_name(nullptr,"RSA",nullptr),EVP_PKEY_CTX_free);
      if(!params||!ctx||EVP_PKEY_fromdata_init(ctx.get())!=1)return std::nullopt;
      EVP_PKEY* raw=nullptr;int imported=EVP_PKEY_fromdata(ctx.get(),&raw,EVP_PKEY_PUBLIC_KEY,params.get());
      OidcPublicKey key(raw,EVP_PKEY_free);if(imported!=1||!key)return std::nullopt;
      Owned<EVP_PKEY_CTX,EVP_PKEY_CTX_free> check(EVP_PKEY_CTX_new_from_pkey(nullptr,key.get(),nullptr),EVP_PKEY_CTX_free);
      if(!check||EVP_PKEY_public_check(check.get())!=1||!keys.emplace(k["kid"].asString(),key).second)return std::nullopt;
    }
    return keys;
  } catch(...) {return std::nullopt;}
}
std::optional<OidcIdentity> verify_google_id_token(std::string_view token,const GoogleOidcConfig& config,const OidcKeyLookup& lookup,std::int64_t now,const OidcIdentityAllowed& allowed) {
  try {
    if(token.empty()||token.size()>16*1024||config.audiences.empty()||!strings(config.audiences)||!strings(config.presenters)||config.clock_skew_seconds<0||config.clock_skew_seconds>60||!lookup)return std::nullopt;
    auto a=token.find('.');if(a==std::string_view::npos)return std::nullopt;auto b=token.find('.',a+1);
    if(b==std::string_view::npos||token.find('.',b+1)!=std::string_view::npos)return std::nullopt;
    auto h=decode(token.substr(0,a)),c=decode(token.substr(a+1,b-a-1)),sig=decode(token.substr(b+1));
    if(!h||!c||!sig)return std::nullopt;
    Json::Value header,claims;if(!object(*h,header)||!object(*c,claims)||header["alg"]!="RS256"||!member_text(header,"kid",128))return std::nullopt;
    if(header.isMember("typ")&&header["typ"]!="JWT")return std::nullopt;
    for(auto name:{"crit","b64","jwk","jku","x5u"})if(header.isMember(name))return std::nullopt;
    auto key=lookup(header["kid"].asString());
    if(!key||EVP_PKEY_is_a(key.get(),"RSA")!=1||EVP_PKEY_get_bits(key.get())<2048||EVP_PKEY_get_bits(key.get())>8192)return std::nullopt;
    Owned<EVP_MD_CTX,EVP_MD_CTX_free> ctx(EVP_MD_CTX_new(),EVP_MD_CTX_free);EVP_PKEY_CTX* pk=nullptr;
    if(!ctx||EVP_DigestVerifyInit(ctx.get(),&pk,EVP_sha256(),nullptr,key.get())!=1||EVP_PKEY_CTX_set_rsa_padding(pk,RSA_PKCS1_PADDING)!=1||EVP_DigestVerify(ctx.get(),reinterpret_cast<const unsigned char*>(sig->data()),sig->size(),reinterpret_cast<const unsigned char*>(token.data()),b)!=1)return std::nullopt;
    if((claims["iss"]!="https://accounts.google.com"&&claims["iss"]!="accounts.google.com")||!member_text(claims,"sub",255))return std::nullopt;
    const auto& aud=claims["aud"];std::set<std::string> audiences;bool match=false;
    if(aud.isString()){if(!text(aud,1024))return std::nullopt;audiences.insert(aud.asString());}
    else if(aud.isArray()&&!aud.empty()&&aud.size()<=32){for(const auto& v:aud){if(!text(v,1024)||!audiences.insert(v.asString()).second)return std::nullopt;}}
    else return std::nullopt;
    for(const auto& v:audiences)match=match||contains(config.audiences,v);
    if(!match)return std::nullopt;
    if(audiences.size()>1&&!claims.isMember("azp"))return std::nullopt;
    if(claims.isMember("azp")&&(!text(claims["azp"],1024)||!contains(config.presenters.empty()?config.audiences:config.presenters,claims["azp"].asString())))return std::nullopt;
    std::int64_t exp,iat,nbf;auto skew=config.clock_skew_seconds;
    if(!date(claims["exp"],exp)||!date(claims["iat"],iat)||iat>=exp||ahead(iat,now,skew))return std::nullopt;
    // Expiration is exclusive: now == exp + configured skew is expired (default skew 0).
    if(now>=exp && static_cast<std::uint64_t>(now)-static_cast<std::uint64_t>(exp)>=static_cast<std::uint64_t>(skew))return std::nullopt;
    if(claims.isMember("nbf")&&(!date(claims["nbf"],nbf)||ahead(nbf,now,skew)))return std::nullopt;
    OidcIdentity identity{"https://accounts.google.com",claims["sub"].asString()};
    if(allowed&&!allowed(identity))return std::nullopt;
    return identity;
  } catch(...) {return std::nullopt;}
}
}  // namespace ma
