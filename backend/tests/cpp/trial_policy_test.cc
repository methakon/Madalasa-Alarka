// L10-001/L10-002: trial request handling without a database. Synthetic identity only.
// Proves input, auth and error-mapping rules; the one-per-family/payer rule itself is exercised against
// real PostgreSQL in backend/tests/m1_trial_policy.sql.
#include <drogon/drogon.h>
#include <iostream>
#include "billing_trial.h"

int main() {
  const std::string fam = "00000000-0000-4000-8000-000000000001";
  ma::Authenticator who = [](const drogon::HttpRequestPtr&) -> std::optional<ma::Principal> {
    return ma::Principal{"https://synthetic.invalid", "test-only-principal"};
  };
  const ma::ParentAuth allow{ma::ParentAuthMode::M1DirectOidc, who};
  const ma::ParentAuth deny{ma::ParentAuthMode::M1DirectOidc, ma::reject_all_authenticator()};
  int failed = 0;
  auto check = [&](bool ok, const char* label) { if (!ok) { std::cerr << "FAIL " << label << '\n'; ++failed; } };
  auto mk = [&](drogon::HttpMethod m, const std::string& body) {
    auto r = drogon::HttpRequest::newHttpRequest();
    r->setMethod(m);
    r->setPath("/v1/families/" + fam + "/trial/start");
    if (!body.empty()) { r->setBody(body); r->setContentTypeCode(drogon::CT_APPLICATION_JSON); }
    return r;
  };
  auto run = [&](drogon::HttpMethod m, const std::string& id, const std::string& body, const ma::ParentAuth& a, bool start) {
    return drogon::sync_wait(ma::family_trial(mk(m, body), id, a, start))->statusCode();
  };
  const std::string ok = "{\"acknowledge_one_time_trial\":true}";

  check(run(drogon::Post, "not-a-uuid", ok, allow, true) == drogon::k400BadRequest, "bad family id");
  check(run(drogon::Post, fam, "", allow, true) == drogon::k400BadRequest, "missing body");
  check(run(drogon::Post, fam, "{}", allow, true) == drogon::k400BadRequest, "empty object");
  check(run(drogon::Post, fam, "{\"acknowledge_one_time_trial\":\"yes\"}", allow, true) == drogon::k400BadRequest, "non-bool ack");
  check(run(drogon::Post, fam, "{\"acknowledge_one_time_trial\":true,\"extra\":1}", allow, true) == drogon::k400BadRequest, "extra field");
  check(run(drogon::Post, fam, "{\"acknowledge_one_time_trial\":true,\"acknowledge_one_time_trial\":true}", allow, true) == drogon::k400BadRequest, "duplicate key");
  check(run(drogon::Post, fam, std::string(70 * 1024, 'x'), allow, true) == drogon::k413RequestEntityTooLarge, "oversize");
  check(run(drogon::Get, fam, "{}", allow, false) == drogon::k400BadRequest, "GET with body");
  check(run(drogon::Post, fam, ok, deny, true) == drogon::k401Unauthorized, "start unauthenticated");
  check(run(drogon::Get, fam, "", deny, false) == drogon::k401Unauthorized, "eligibility unauthenticated");
  check(run(drogon::Post, fam, "{\"acknowledge_one_time_trial\":false}", allow, true) == drogon::k422UnprocessableEntity, "ack false");
  // Authenticated and valid but no database configured: honest 503, never a fabricated success.
  check(run(drogon::Post, fam, ok, allow, true) == drogon::k503ServiceUnavailable, "start without database");
  check(run(drogon::Get, fam, "", allow, false) == drogon::k503ServiceUnavailable, "eligibility without database");

  using ma::trial_outcome_for_sqlstate;
  check(trial_outcome_for_sqlstate("42501", "billing owner required").status == 404, "non-owner hidden as 404");
  check(trial_outcome_for_sqlstate("P0001", "trial already used or previously paid").status == 409, "repeat trial is 409");
  check(trial_outcome_for_sqlstate("23505", "duplicate").status == 409, "unique race is 409");
  check(trial_outcome_for_sqlstate("P0001", "something else").status == 422, "other raise is 422");
  check(trial_outcome_for_sqlstate("55P03", "").status == 503, "lock timeout is 503");
  check(trial_outcome_for_sqlstate("XX000", "").status == 500, "unknown is 500");
  check(ma::kTrialDurationHours == 48, "duration is 48h");
  if (failed) return 1;
  std::cout << "trial policy handler tests PASS\n";
  return 0;
}
