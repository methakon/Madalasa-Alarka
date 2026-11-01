#include "admin_oidc.h"
#include "oidc_fixture.h"
#include <iostream>
#include <cstdlib>

static int errors = 0;
#define CHECK(cond) do {if (!(cond)) {std::cerr << "FAIL line " << __LINE__ << ": " #cond "\n"; ++errors;}} while(0)

int main() {
  const auto key=oidc_fixture::key();
  const ma::GoogleOidcConfig cfg{{"synthetic-admin-client"},{},0};
  const ma::OidcKeyLookup lookup=[key](const std::string& kid) -> ma::OidcPublicKey {
    return kid=="key-1"?key:ma::OidcPublicKey{};
  };
  const std::string nonce="SyntheticNonce_0123456789abcd";
  Json::Value claims=oidc_fixture::claims();
  claims["sub"]="test-admin-subject";
  claims["aud"]="synthetic-admin-client";
  claims["iat"]=Json::Int64(1700000000);
  claims["exp"]=Json::Int64(1700000600);
  claims["nonce"]=nonce;
  claims["email"]="test-admin@example.invalid";
  claims["email_verified"]=true;
  auto verify=[&](const Json::Value& v, std::int64_t now=1700000100,
                   const std::string& expected="SyntheticNonce_0123456789abcd") {
    return ma::verify_admin_google_id_token(oidc_fixture::sign(key,v),expected,cfg,lookup,now);
  };
  auto good=verify(claims);
  CHECK(good && good->issuer=="https://accounts.google.com");
  CHECK(good && good->subject=="test-admin-subject");
  CHECK(good && good->verified_email=="test-admin@example.invalid");
  CHECK(!verify(claims,1700000301)); // age more than 300 seconds
  CHECK(!verify(claims,1700000000,"WrongNonceValue_1234567890"));
  CHECK(!verify(claims,1700000100,"short"));
  auto bad=claims;
  bad["email_verified"]=false;CHECK(!verify(bad));
  bad=claims;bad.removeMember("email_verified");CHECK(!verify(bad));
  bad=claims;bad["email_verified"]="true";CHECK(!verify(bad));
  bad=claims;bad["email"]="test-admin@invalid\n";CHECK(!verify(bad));
  bad=claims;bad["nonce"]="other-nonce";CHECK(!verify(bad));
  bad=claims;bad.removeMember("nonce");CHECK(!verify(bad));
  bad=claims;bad["aud"]="synthetic-parent-client";CHECK(!verify(bad));
  bad=claims;bad["iss"]="https://malicious.invalid";CHECK(!verify(bad));
  bad=claims;bad["iat"]=Json::Int64(1700000101);CHECK(!verify(bad));
  bad=claims;bad["exp"]=Json::Int64(1700000100);CHECK(!verify(bad));
  CHECK(!ma::verify_admin_google_id_token("broken.token",nonce,cfg,lookup,1700000100));
  auto tampered=oidc_fixture::sign(key,claims);
  tampered.back()=tampered.back()=='A'?'B':'A';
  CHECK(!ma::verify_admin_google_id_token(tampered,nonce,cfg,lookup,1700000100));
  CHECK(!ma::verify_admin_google_id_token(oidc_fixture::sign(key,claims),nonce,
       ma::GoogleOidcConfig{{"wrong-admin-audience"},{},0},lookup,1700000100));
  if(errors) return 1;
  std::cout << "admin verified Google token + freshness/nonce/email negative matrix PASS\n";
}
