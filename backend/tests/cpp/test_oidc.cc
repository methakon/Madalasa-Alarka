#include "oidc_fixture.h"
#ifdef MA_OIDC_BASELINE_AUTH
#include MA_OIDC_BASELINE_AUTH_HEADER
#endif
#include <iostream>
#include <limits>
#include <type_traits>
namespace {
int passed=0,failed=0;
void check(const std::string& name,bool good) {if(good){++passed;}else{++failed;std::cerr<<"FAIL "<<name<<'\n';}}
}
int main() {
  using namespace oidc_fixture;
  try {
    auto k=key(),other=key(); auto public_jwk=jwk(k);
    auto keys=ma::parse_google_jwks(jwks(public_jwk));require(keys.has_value());
    ma::GoogleOidcConfig config;config.audiences={"local-client"};
    int lookups=0,callbacks=0;
    ma::OidcKeyLookup lookup=[&](const std::string& kid){++lookups;auto i=keys->find(kid);return i==keys->end()?ma::OidcPublicKey{}:i->second;};
    ma::OidcIdentityAllowed allow=[&](const ma::OidcIdentity& id){++callbacks;return id.issuer=="https://accounts.google.com";};
    auto verify=[&](const std::string& token,std::int64_t now=1000){return ma::verify_google_id_token(token,config,lookup,now,allow);};
    auto good=sign(k);auto result=verify(good);
    check("real RSA JWKS/token roundtrip",result&&result->issuer=="https://accounts.google.com"&&result->subject=="opaque-subject"&&callbacks==1);
#ifdef MA_OIDC_BASELINE_AUTH
    // Explicitly opt in only when demonstrating the pre-integration reject-all source.
    auto request=drogon::HttpRequest::newHttpRequest();
    request->addHeader("authorization","Bearer "+good);
    check("baseline select_authenticator rejects real signed valid token",!ma::select_authenticator()(request));
#endif
    check("imported key public only",EVP_PKEY_get_size(keys->at("key-1").get())==256);
    BIGNUM* private_d=nullptr;check("no private d in imported key",EVP_PKEY_get_bn_param(keys->at("key-1").get(),"d",&private_d)!=1);BN_free(private_d);
    auto reject_token=[&](const std::string& name,const std::string& token){callbacks=0;check(name,!verify(token)&&callbacks==0);};
    auto reject_claim=[&](const std::string& name,const char* field,const Json::Value& val){auto c=claims();c[field]=val;reject_token(name,sign(k,c));};
    auto reject_header=[&](const std::string& name,const char* field,const Json::Value& val){auto h=header();h[field]=val;int before=lookups;reject_token(name,sign(k,claims(),h));check(name+" before lookup",lookups==before);};
    reject_token("wrong signing key",sign(other));
    reject_token("real PSS signature cannot masquerade as RS256",sign_raw(k,json(header()),json(claims()),RSA_PKCS1_PSS_PADDING));
    ma::OidcPublicKey ec(EVP_PKEY_Q_keygen(nullptr,nullptr,"EC","P-256"),EVP_PKEY_free);require(bool(ec));
    check("non-RSA lookup key rejected",!ma::verify_google_id_token(good,config,[&](const std::string&){return ec;},1000));
    auto tampered=good;tampered[tampered.rfind('.')+1]=tampered[tampered.rfind('.')+1]=='A'?'B':'A';reject_token("bad signature",tampered);
    auto changed=claims();changed["sub"]="changed";std::string forged=encode(json(header()))+"."+encode(json(changed))+good.substr(good.rfind('.'));reject_token("tampered claims original signature",forged);
    auto h=header();h["kid"]="key-2";reject_token("unknown kid",sign(k,claims(),h));
    auto rotated=ma::parse_google_jwks(jwks(jwk(other,"key-2")));require(rotated.has_value());keys->insert(rotated->begin(),rotated->end());
    check("rotation second kid valid",verify(sign(other,claims(),h)).has_value());
    check("rotation old kid still valid",verify(good).has_value());
    ma::OidcKeyLookup wrong=[&](const std::string&){return other;};callbacks=0;
    check("lookup wrong key rejects before identity",!ma::verify_google_id_token(good,config,wrong,1000,allow)&&callbacks==0);
    check("missing lookup fails closed",!ma::verify_google_id_token(good,config,{},1000));
    ma::OidcKeyLookup throws=[](const std::string&)->ma::OidcPublicKey{throw std::runtime_error("unavailable");};
    check("lookup exception fails closed",!ma::verify_google_id_token(good,config,throws,1000));
    for(auto alg:{"none","HS256","RS384","PS256","rs256",""})reject_header(std::string("algorithm ")+alg,"alg",alg);
    reject_header("algorithm null","alg",Json::Value());reject_header("typ lower","typ","jwt");reject_header("typ null","typ",Json::Value());
    for(auto field:{"crit","b64","jwk","jku","x5u"})reject_header(std::string("forbidden header ")+field,field,Json::Value());
    reject_header("empty kid","kid","");reject_header("long kid","kid",std::string(129,'k'));reject_header("numeric kid","kid",5);reject_header("NUL kid","kid",std::string("a\0b",3));
    h=header();h.removeMember("typ");check("optional typ omitted",verify(sign(k,claims(),h)).has_value());
    for(auto issuer:{"https://accounts.google.com/","http://accounts.google.com","https://ACCOUNTS.google.com","https://evil.invalid"," accounts.google.com",""})reject_claim(std::string("issuer ")+issuer,"iss",issuer);
    auto c=claims();c["iss"]="accounts.google.com";result=verify(sign(k,c));check("Google alias canonical after signature",result&&result->issuer=="https://accounts.google.com");
    for(auto field:{"iss","sub","aud","exp","iat"}){c=claims();c.removeMember(field);reject_token(std::string("missing ")+field,sign(k,c));}
    reject_claim("empty subject","sub","");reject_claim("long subject","sub",std::string(256,'s'));reject_claim("numeric subject","sub",12);
    for(auto s:{std::string("a\0b",3),std::string("a\nb"),std::string("a\x7f"),std::string("a\xc2\x85")})reject_claim("subject control","sub",s);
    for(auto s:{std::string(255,'S'),std::string(" Opaque.Mixed:SUB "),std::string("\xe0\xa6\x85")}){c=claims();c["sub"]=s;result=verify(sign(k,c));check("opaque subject exact preserved",result&&result->subject==s);}
    reject_claim("wrong audience","aud","other");reject_claim("aud null","aud",Json::Value());reject_claim("aud empty","aud","");reject_claim("aud huge","aud",std::string(1025,'a'));
    Json::Value array(Json::arrayValue);reject_claim("aud empty array","aud",array);
    array.append("local-client");c=claims();c["aud"]=array;check("one audience array",verify(sign(k,c)).has_value());
    array.append("second");reject_claim("multi audience no azp","aud",array);c["aud"]=array;c["azp"]="local-client";check("multi aud authorized azp",verify(sign(k,c)).has_value());
    c["azp"]="second";reject_token("multi aud arbitrary azp",sign(k,c));
    array[1]="local-client";reject_claim("aud duplicate","aud",array);array[1]=10;reject_claim("aud mixed type","aud",array);
    array=Json::Value(Json::arrayValue);for(int i=0;i<33;++i)array.append("client-"+std::to_string(i));array[0]="local-client";reject_claim("aud array bound","aud",array);
    reject_claim("single audience bad azp","azp","other");reject_claim("azp null","azp",Json::Value());reject_claim("azp empty","azp","");
    config.presenters={"presenter"};c=claims();c["azp"]="presenter";check("explicit presenter accepted",verify(sign(k,c)).has_value());c["azp"]="local-client";reject_token("explicit presenters override fallback",sign(k,c));config.presenters.clear();
    auto saved=config;config.audiences.clear();reject_token("empty config deny",good);config=saved;
    config.audiences={""};reject_token("empty config audience",good);config=saved;
    config.audiences={"local-client","local-client"};reject_token("duplicate config audience",good);config=saved;
    config.presenters={std::string(1025,'p')};reject_token("invalid presenter config",good);config=saved;
    for(int skew:{-1,61}){config.clock_skew_seconds=skew;reject_token("invalid clock skew",good);}config=saved;
    check("before exp",verify(good,1099).has_value());reject_token("expired now",sign(k,[]{auto v=claims();v["exp"]=1000;return v;}()));check("at exp rejected",!verify(good,1100));check("after exp rejected",!verify(good,1101));
    for(auto field:{"exp","iat","nbf"})for(const auto& val:std::vector<Json::Value>{Json::Value(true),Json::Value(false),Json::Value(1000.0),Json::Value("1000"),Json::Value(),Json::Value(Json::UInt64(std::numeric_limits<std::uint64_t>::max()))})reject_claim(std::string("date type ")+field,field,val);
    reject_claim("iat equal exp","iat",1100);reject_claim("iat after exp","iat",1101);reject_claim("iat future","iat",1001);
    c=claims();c["iat"]=1000;check("iat exactly now",verify(sign(k,c)).has_value());
    c=claims();c["nbf"]=1000;check("nbf exactly now",verify(sign(k,c)).has_value());reject_claim("nbf future","nbf",1001);
    config.clock_skew_seconds=60;check("expiration within skew",verify(good,1159).has_value());check("expiration at skew boundary rejected",!verify(good,1160));
    c=claims();c["iat"]=1060;check("iat exact skew",verify(sign(k,c)).has_value());c["iat"]=1061;reject_token("iat beyond skew",sign(k,c));
    c=claims();c["nbf"]=1060;check("nbf exact skew",verify(sign(k,c)).has_value());c["nbf"]=1061;reject_token("nbf beyond skew",sign(k,c));
    auto max=std::numeric_limits<std::int64_t>::max(),min=std::numeric_limits<std::int64_t>::min();
    c=claims();c["exp"]=Json::Int64(max);c["iat"]=Json::Int64(max-1);check("INT64 max skew no overflow",verify(sign(k,c),max).has_value());config.clock_skew_seconds=0;check("INT64 max expiration",!verify(sign(k,c),max));
    c["iat"]=Json::Int64(min);c["exp"]=Json::Int64(min+1);check("INT64 full span expired",!verify(sign(k,c),max));
    c["exp"]=Json::Int64(max);c["iat"]=Json::Int64(max-1);check("INT64 full span future",!verify(sign(k,c),min));config=saved;
    callbacks=0;check("identity predicate rejects",!ma::verify_google_id_token(good,config,lookup,1000,[&](const ma::OidcIdentity&){++callbacks;return false;})&&callbacks==1);
    check("identity predicate exception deny",!ma::verify_google_id_token(good,config,lookup,1000,[](const ma::OidcIdentity&)->bool{throw std::runtime_error("deny");}));
    c=claims();c["parent"]=true;c["owner"]=true;c["adult"]=true;c["role"]="admin";c["family_link_verified"]=true;c["age"]=99;result=verify(sign(k,c));
    static_assert(std::is_same_v<decltype(result),std::optional<ma::OidcIdentity>>);
    check("authority claims ignored identity only",result&&result->issuer=="https://accounts.google.com"&&result->subject=="opaque-subject");
    for(auto token:{std::string(),std::string("a.b"),std::string("a.b.c.d"),std::string(".a.b"),std::string("a..b"),std::string("a.b."),std::string("=.a.b"),std::string("A.a.b"),std::string("AA=.a.b"),std::string("AA+.a.b"),std::string("AA/.a.b"),std::string(16385,'a')})reject_token("JWT structural/base64 bound",token);
    // Changing unused base64 bits must not give a second encoding of the same signature.
    auto alternate=good;auto last=alternate.back();std::string abc="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";alternate.back()=abc[abc.find(last)+1];reject_token("signature noncanonical unused bits",alternate);
    reject_token("padding header segment",good.substr(0,good.find('.'))+"="+good.substr(good.find('.')));
    for(auto payload:{std::string("[]"),std::string("null"),std::string("{}{}"),std::string("{\"sub\":\"a\",\"sub\":\"b\"}"),std::string("{\"x\":\"\xc0\xaf\"}"),std::string("{\"x\":\"\\ud800\"}"),std::string("{/*comment*/\"x\":1}"),std::string("{\"x\":1,}"),std::string("{\"x\":NaN}")})reject_token("strict claim JSON",sign_raw(k,json(header()),payload));
    reject_token("duplicate header",sign_raw(k,"{\"alg\":\"RS256\",\"kid\":\"key-1\",\"alg\":\"RS256\"}",json(claims())));
    std::string deep="0";for(int i=0;i<20;++i)deep="["+deep+"]";reject_token("claim JSON nesting",sign_raw(k,json(header()),"{\"deep\":"+deep+"}"));
    auto bad_jwk=[&](const std::string& name,const Json::Value& v){check(name,!ma::parse_google_jwks(jwks(v)));};
    for(auto field:{"d","p","q","dp","dq","qi","oth"}){auto v=public_jwk;v[field]=Json::Value();bad_jwk(std::string("private RSA field ")+field,v);}
    for(auto field:{"kid","n","e","kty"}){auto v=public_jwk;v.removeMember(field);bad_jwk(std::string("JWK missing ")+field,v);}
    for(auto field:{"alg","use"}){auto v=public_jwk;v[field]="wrong";bad_jwk(std::string("JWK wrong ")+field,v);v[field]=Json::Value();bad_jwk(std::string("JWK null ")+field,v);}
    auto v=public_jwk;v["kid"]=std::string(129,'k');bad_jwk("JWK long kid",v);v["kid"]="";bad_jwk("JWK empty kid",v);
    v=public_jwk;v["kty"]="EC";bad_jwk("JWK non-RSA",v);
    v=public_jwk;v.removeMember("alg");v.removeMember("use");check("optional alg/use absent",ma::parse_google_jwks(jwks(v)).has_value());
    v=public_jwk;v["key_ops"].append("verify");check("verify key_ops",ma::parse_google_jwks(jwks(v)).has_value());v["key_ops"].append("sign");bad_jwk("private operation",v);
    for(auto ops:{Json::Value("verify"),Json::Value(Json::arrayValue),Json::Value()}){v=public_jwk;v["key_ops"]=ops;bad_jwk("invalid key_ops",v);}
    for(auto n:{std::string("AA"),std::string("AQ"),std::string("AAE"),std::string(1367,'A'),public_jwk["n"].asString()+"=",std::string(342,'_')}){v=public_jwk;v["n"]=n;bad_jwk("modulus bounds/canonical",v);}
    check("2048 bit real modulus accepted",ma::parse_google_jwks(jwks(public_jwk)).has_value());
    for(auto e:{std::string("AA"),std::string("AQ"),std::string("Ag"),std::string("BA"),std::string("AAEAAQ"),std::string("AQAAAAE"),std::string("AQAB="),std::string("AQAC"),std::string("AQAB!"),std::string("AR")}){v=public_jwk;v["e"]=e;bad_jwk("exponent bounds/canonical",v);}
    v=public_jwk;v["n"]=encode(std::string(255,'\xff'));bad_jwk("2040 bit modulus",v);
    v=public_jwk;v["n"]=encode(std::string(1025,'\xff'));bad_jwk("8200 bit modulus",v);
    auto maximum_key=key(8192);check("8192 bit real modulus accepted",ma::parse_google_jwks(jwks(jwk(maximum_key))).has_value());
    v=public_jwk;v["n"]=encode(std::string(1,'\0')+std::string(256,'\xff'));bad_jwk("nonminimal leading zero modulus",v);
    Json::Value set;set["keys"].append(public_jwk);set["keys"].append(public_jwk);check("duplicate kid whole set reject",!ma::parse_google_jwks(json(set)));
    auto duplicate_jwk=json(public_jwk);duplicate_jwk.pop_back();duplicate_jwk+=",\"kid\":\"different\"}";
    check("duplicate JWK object member rejected",!ma::parse_google_jwks("{\"keys\":["+duplicate_jwk+"]}"));
    set["keys"][1]=Json::Value();check("one malformed key invalidates set",!ma::parse_google_jwks(json(set)));
    set["keys"]=Json::Value(Json::arrayValue);for(int i=0;i<33;++i){v=public_jwk;v["kid"]="key-"+std::to_string(i);set["keys"].append(v);}check("33 keys rejected",!ma::parse_google_jwks(json(set)));set["keys"].resize(32);check("32 keys accepted",ma::parse_google_jwks(json(set)).has_value());
    for(auto body:{std::string(),std::string("{}"),std::string("[]"),std::string("{\"keys\":[]}"),std::string("{\"keys\":null}"),std::string("{\"keys\":[],\"keys\":[]}"),jwks(public_jwk)+"x",std::string(256*1024+1,' '),std::string("{\"keys\":[],\"bad\":\"\xff\"}")})check("JWKS strict whole body",!ma::parse_google_jwks(body));
    check("JWKS exact size limit",ma::parse_google_jwks(jwks(public_jwk)+std::string(256*1024-jwks(public_jwk).size(),' ')).has_value());
  } catch(const std::exception&){++failed;std::cerr<<"FAIL fixture or unexpected exception\n";}
  std::cout<<passed<<" passed, "<<failed<<" failed\n";return failed?1:0;
}
