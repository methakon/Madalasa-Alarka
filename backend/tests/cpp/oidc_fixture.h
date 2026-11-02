#pragma once
// Ephemeral signing keys exist only in this test process; never write them to disk.
#include "google_oidc.h"
#include <json/json.h>
#include <openssl/evp.h>
#include <openssl/rsa.h>
#include <openssl/core_names.h>
#include <openssl/bn.h>
#include <stdexcept>
#include <vector>
namespace oidc_fixture {
inline void require(bool b) { if (!b) throw std::runtime_error("fixture crypto operation failed"); }
inline std::string encode(std::string_view s) {
  static constexpr char abc[]="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  std::string out; unsigned acc=0; int bits=0;
  for(unsigned char c:s) {acc=(acc<<8)|c; bits+=8; while(bits>=6){bits-=6;out+=abc[(acc>>bits)&63];}}
  if(bits)out+=abc[(acc<<(6-bits))&63];
  return out;
}
inline std::string json(const Json::Value& v) {Json::StreamWriterBuilder w;w["indentation"]="";return Json::writeString(w,v);}
inline ma::OidcPublicKey key(int bits=2048) {
  std::unique_ptr<EVP_PKEY_CTX,decltype(&EVP_PKEY_CTX_free)> ctx(EVP_PKEY_CTX_new_from_name(nullptr,"RSA",nullptr),EVP_PKEY_CTX_free);
  require(ctx && EVP_PKEY_keygen_init(ctx.get())>0 && EVP_PKEY_CTX_set_rsa_keygen_bits(ctx.get(),bits)>0);
  EVP_PKEY* p=nullptr;require(EVP_PKEY_generate(ctx.get(),&p)>0);return {p,EVP_PKEY_free};
}
inline Json::Value jwk(const ma::OidcPublicKey& k,std::string kid="key-1") {
  Json::Value v;v["kty"]="RSA";v["kid"]=kid;v["alg"]="RS256";v["use"]="sig";
  for(auto name:{"n","e"}) { BIGNUM* raw=nullptr;require(EVP_PKEY_get_bn_param(k.get(),name,&raw)>0);std::unique_ptr<BIGNUM,decltype(&BN_free)> b(raw,BN_free);std::string bytes(BN_num_bytes(b.get()),'\0');require(BN_bn2bin(b.get(),reinterpret_cast<unsigned char*>(bytes.data()))>0);v[name]=encode(bytes); }
  return v;
}
inline std::string jwks(const Json::Value& k) {Json::Value v;v["keys"].append(k);return json(v);}
inline Json::Value claims() {Json::Value v;v["iss"]="https://accounts.google.com";v["sub"]="opaque-subject";v["aud"]="local-client";v["iat"]=900;v["exp"]=1100;return v;}
inline Json::Value header() {Json::Value v;v["alg"]="RS256";v["kid"]="key-1";v["typ"]="JWT";return v;}
inline std::string sign_raw(const ma::OidcPublicKey& key,std::string h,std::string c,int padding=RSA_PKCS1_PADDING) {
  std::string input=encode(h)+"."+encode(c);std::unique_ptr<EVP_MD_CTX,decltype(&EVP_MD_CTX_free)> ctx(EVP_MD_CTX_new(),EVP_MD_CTX_free);
  EVP_PKEY_CTX* p=nullptr;require(ctx && EVP_DigestSignInit(ctx.get(),&p,EVP_sha256(),nullptr,key.get())>0 && EVP_PKEY_CTX_set_rsa_padding(p,padding)>0);
  size_t n=0;require(EVP_DigestSign(ctx.get(),nullptr,&n,reinterpret_cast<const unsigned char*>(input.data()),input.size())>0);std::string sig(n,'\0');require(EVP_DigestSign(ctx.get(),reinterpret_cast<unsigned char*>(sig.data()),&n,reinterpret_cast<const unsigned char*>(input.data()),input.size())>0);sig.resize(n);return input+"."+encode(sig);
}
inline std::string sign(const ma::OidcPublicKey& k,const Json::Value& c=claims(),const Json::Value& h=header()) {return sign_raw(k,json(h),json(c));}
}
