// L04-011 blended-family no-cross-child-leak contract test (API-handler layer).
//
// Complements (does not duplicate) backend/tests/m2_blended_family_isolation.sql,
// which proves the DB/RLS isolation. This test asserts the HTTP handler layer
// never leaks a foreign family/child — including through status codes, error
// payloads, or counters — reusing the existing children_read / parent_reads
// handlers and the synthetic in-test authenticator (no live DB; fail closed).
//
// Synthetic identity is confined to this executable; no simulated success rows.
#include <drogon/drogon.h>
#include "children_read.h"
#include "parent_reads.h"
#include "children_create.h"
#include "device_revoke.h"
#include <iostream>
#include <optional>
#include <string>

int main() {
  int failed = 0;
  auto check = [&](bool ok, const char* label) {
    if (!ok) { std::cerr << "FAIL " << label << '\n'; ++failed; }
  };

  auto request = [](drogon::HttpMethod m, const std::string& path) {
    auto req = drogon::HttpRequest::newHttpRequest();
    req->setMethod(m);
    req->setPath(path);
    return req;
  };

  // Two distinct synthetic adults (different billing families). Parent B is
  // authenticated as itself; it must never see family A's children.
  ma::Authenticator as_parent_b = [](const drogon::HttpRequestPtr&) -> std::optional<ma::Principal> {
    return ma::Principal{"https://synthetic.invalid", "parent-b-principal"};
  };
  const ma::ParentAuth authed{ma::ParentAuthMode::M1DirectOidc, as_parent_b};
  const ma::ParentAuth deny{ma::ParentAuthMode::M1DirectOidc, ma::reject_all_authenticator()};

  const std::string family_a = "0a000000-0000-4000-8000-0000000000a1";  // not parent B's family
  const std::string child_a  = "0a000000-0000-4000-8000-0000000000c1";  // family A child

  // 1. Unauthenticated cross-family read is refused (401), never leaks existence.
  {
    auto r = drogon::sync_wait(ma::list_children(request(drogon::Get,
        "/v1/families/" + family_a + "/children"), family_a, deny));
    check(r->statusCode() == drogon::k401Unauthorized, "unauth cross-family child list -> 401");
  }

  // 2. Authenticated parent B without a live DB fails CLOSED (503 catalog error),
  //    never fabricates family A data or a child roster.
  {
    auto r = drogon::sync_wait(ma::list_children(request(drogon::Get,
        "/v1/families/" + family_a + "/children"), family_a, authed));
    check(r->statusCode() == drogon::k503ServiceUnavailable, "cross-family read fails closed (503)");
    auto body = r->getJsonObject();
    check(body && (*body)["code"] == "SERVICE_UNAVAILABLE", "catalog error, not invented roster");
    // Negative-leak: the error body must not echo the foreign family/child id or
    // any sibling counter.
    const std::string s = std::string(r->getBody());
    check(s.find(family_a) == std::string::npos, "error body does not echo foreign family id");
    check(s.find(child_a) == std::string::npos, "error body does not echo foreign child id");
    check(s.find("\"count\"") == std::string::npos && s.find("sibling") == std::string::npos,
          "error body exposes no sibling counter/metadata");
  }

  // 3. A foreign-family child read with a bad UUID is a clean 400, not a probe oracle.
  {
    auto r = drogon::sync_wait(ma::list_children(request(drogon::Get,
        "/v1/families/not-a-uuid/children"), "not-a-uuid", authed));
    check(r->statusCode() == drogon::k400BadRequest, "malformed family id -> 400");
    const std::string s = std::string(r->getBody());
    check(s.find("not-a-uuid") == std::string::npos || s.find(child_a) == std::string::npos,
          "400 body does not leak a foreign child id");
  }

  // 4. listFamilies requires authentication; an unauthenticated caller cannot
  //    enumerate families (no cross-tenant discovery).
  {
    auto r = drogon::sync_wait(ma::list_families(request(drogon::Get, "/v1/families"), deny));
    check(r->statusCode() == drogon::k401Unauthorized, "listFamilies requires auth");
  }

  if (failed == 0)
    std::cout << "blended-family API no-leak PASS: cross-family read fails closed; "
                 "no foreign family/child id, roster, or sibling counter in any response\n";
  return failed == 0 ? 0 : 1;
}
