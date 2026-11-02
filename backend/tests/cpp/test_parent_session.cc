// Parent session bridge: parser, configuration and offline route negatives.
// No database, network or real identity. SYNTHETIC DATA ONLY.
#include <drogon/drogon.h>
#include <iostream>
#include <string>
#include <vector>
#include "parent_session.h"

static int failed = 0;
#define CHECK(p) do { if (!(p)) { std::cerr << "FAIL line " << __LINE__ << ": " #p "\n"; ++failed; } } while (0)

static drogon::HttpRequestPtr with_authorization(const std::string& value) {
  auto req = drogon::HttpRequest::newHttpRequest();
  req->setMethod(drogon::Delete);
  req->setPath("/v1/auth/session");
  if (!value.empty()) req->addHeader("authorization", value);
  return req;
}

int main() {
  using namespace ma;
  // Mode: unset/empty => V2 sessions; anything unknown is a startup error, never a fallback.
  CHECK(parse_parent_auth_mode(nullptr) == ParentAuthMode::V2Session);
  CHECK(parse_parent_auth_mode("") == ParentAuthMode::V2Session);
  CHECK(parse_parent_auth_mode("v2_session") == ParentAuthMode::V2Session);
  CHECK(parse_parent_auth_mode("m1_direct_oidc") == ParentAuthMode::M1DirectOidc);
  for (const char* bad : {"V2_SESSION", "m1", "synthetic_test", " v2_session", "v2_session ", "none"})
    CHECK(!parse_parent_auth_mode(bad));

  // TTL bounds mirror the SQL function (300..43200 seconds).
  CHECK(parse_parent_session_ttl(nullptr) == kParentSessionDefaultTtlSeconds);
  CHECK(parse_parent_session_ttl("300") == 300);
  CHECK(parse_parent_session_ttl("43200") == 43200);
  for (const char* bad : {"299", "43201", "0", "-1", "3600s", " 3600", "999999", "1e3", "+300"})
    CHECK(!parse_parent_session_ttl(bad));

  // Session token shape is exactly what PostgreSQL issues.
  const std::string token(64, 'f');
  CHECK(is_parent_session_token(token));
  CHECK(is_parent_session_token("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"));
  CHECK(!is_parent_session_token(std::string(63, 'f')));
  CHECK(!is_parent_session_token(std::string(65, 'f')));
  CHECK(!is_parent_session_token(std::string(64, 'F')));
  CHECK(!is_parent_session_token(std::string(64, 'g')));
  CHECK(!is_parent_session_token(std::string(63, 'f') + "."));

  // Bearer parser.
  CHECK(bearer_value(with_authorization("Bearer " + token)) == token);
  CHECK(bearer_value(with_authorization("bEaReR " + token)) == token);
  for (const std::string& bad : {std::string(), std::string("Bearer"), std::string("Bearer "), "Basic " + token,
                                 "Bearer  " + token, "Bearer " + token + " ", "Bearer " + token + ",x",
                                 "Bearer\t" + token, "Bearer " + std::string(16385, 'a')})
    CHECK(!bearer_value(with_authorization(bad)));

  // Credential selection: V2 never consults the ID-token verifier.
  int verifier_calls = 0;
  Authenticator counting = [&verifier_calls](const drogon::HttpRequestPtr&) -> std::optional<Principal> {
    ++verifier_calls;
    return Principal{"https://synthetic.invalid", "unit-subject"};
  };
  const ParentAuth v2{ParentAuthMode::V2Session, counting};
  const ParentAuth m1{ParentAuthMode::M1DirectOidc, counting};
  auto v2_credential = parent_credential(v2, with_authorization("Bearer " + token));
  CHECK(v2_credential && v2_credential->session_token == token && v2_credential->identity.subject.empty());
  CHECK(!parent_credential(v2, with_authorization("Bearer header.payload.signature")));
  CHECK(!parent_credential(v2, with_authorization("")));
  CHECK(verifier_calls == 0);
  auto m1_credential = parent_credential(m1, with_authorization(""));
  CHECK(m1_credential && m1_credential->session_token.empty() && m1_credential->identity.subject == "unit-subject");
  CHECK(verifier_calls == 1);
  CHECK(!parent_credential(ParentAuth{ParentAuthMode::M1DirectOidc, {}}, with_authorization("")));

  // Exchange digest: hex bytea literal, domain separated, never the token itself.
  const auto digest = parent_exchange_credential_digest("a.b.c");
  CHECK(digest.size() == 2 + 64 && digest.rfind("\\x", 0) == 0);
  CHECK(digest != parent_exchange_credential_digest("a.b.d"));
  CHECK(digest != to_pg_bytea(sha256_bytes("a.b.c")));

  // Logout route offline negatives.
  for (const std::string& bad : {std::string(), std::string("Bearer header.payload.signature"), "Bearer " + std::string(64, 'A')}) {
    auto denied = drogon::sync_wait(revoke_parent_session(with_authorization(bad), v2));
    CHECK(denied->statusCode() == drogon::k401Unauthorized);
    CHECK(denied->getHeader("cache-control") == "no-store");
    CHECK(denied->getJsonObject() && (*denied->getJsonObject())["code"] == "UNAUTHENTICATED");
  }
  auto offline = drogon::sync_wait(revoke_parent_session(with_authorization("Bearer " + token), v2));
  CHECK(offline->statusCode() == drogon::k503ServiceUnavailable);
  CHECK(drogon::sync_wait(revoke_parent_session(with_authorization("Bearer " + token), m1))->statusCode() ==
        drogon::k404NotFound);

  // Exchange: a session token is never accepted as an identity assertion.
  auto exchange = drogon::HttpRequest::newHttpRequest();
  exchange->setMethod(drogon::Post);
  exchange->setPath("/v1/auth/parent/google");
  exchange->addHeader("authorization", "Bearer " + token);
  CHECK(drogon::sync_wait(exchange_parent_session(exchange, v2, 3600))->statusCode() == drogon::k401Unauthorized);
  CHECK(verifier_calls == 1);
  auto no_bearer = drogon::HttpRequest::newHttpRequest();
  no_bearer->setMethod(drogon::Post);
  CHECK(drogon::sync_wait(exchange_parent_session(no_bearer, v2, 3600))->statusCode() == drogon::k401Unauthorized);
  auto jwt_shaped = drogon::HttpRequest::newHttpRequest();
  jwt_shaped->setMethod(drogon::Post);
  jwt_shaped->addHeader("authorization", "Bearer header.payload.signature");
  CHECK(drogon::sync_wait(exchange_parent_session(jwt_shaped, v2, 3600))->statusCode() ==
        drogon::k503ServiceUnavailable);  // identity accepted, issuer DB absent
  CHECK(drogon::sync_wait(exchange_parent_session(jwt_shaped, v2, 60))->statusCode() ==
        drogon::k500InternalServerError);  // misconfigured lifetime never reaches SQL
  const ParentAuth v2_deny{ParentAuthMode::V2Session, reject_all_authenticator()};
  CHECK(drogon::sync_wait(exchange_parent_session(jwt_shaped, v2_deny, 3600))->statusCode() ==
        drogon::k401Unauthorized);

  if (failed) return 1;
  std::cout << "parent session bridge unit tests PASS\n";
  return 0;
}
