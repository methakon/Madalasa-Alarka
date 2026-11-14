// L10-005: the catalog never quotes an unverified price and fails closed without auth or a database.
#include <drogon/drogon.h>
#include <iostream>
#include "billing_catalog.h"

int main() {
  int failed = 0;
  auto check = [&](bool ok, const char* label) { if (!ok) { std::cerr << "FAIL " << label << '\n'; ++failed; } };
  for (auto kind : {"MONTH", "YEAR", "ADDON"}) {
    auto v = ma::catalog_item({"local_sku", kind, "INR", "UNVERIFIED"});
    check(v["quoted_price"].isNull(), "unverified price is null");
    check(v["play_offer_id"].isNull(), "no offer id without Play");
    check(v["is_sandbox"].asBool(), "unverified is sandbox");
    check(v["currency"].asString() == "INR", "currency INR");
    check(v.getMemberNames().size() == 6, "exact BillingProduct fields");
  }
  check(ma::catalog_item({"x", "MONTH", "INR", "UNVERIFIED"})["term"].asString() == "MONTH", "month term");
  check(ma::catalog_item({"x", "ADDON", "INR", "UNVERIFIED"})["term"].asString() == "ADDON_100_DAYS", "addon term");
  check(ma::catalog_item({"x", "BOGUS", "INR", "UNVERIFIED"})["term"].asString() == "UNKNOWN", "unknown kind not guessed");

  ma::Authenticator who = [](const drogon::HttpRequestPtr&) -> std::optional<ma::Principal> {
    return ma::Principal{"https://synthetic.invalid", "test-only-principal"};
  };
  const ma::ParentAuth allow{ma::ParentAuthMode::M1DirectOidc, who};
  const ma::ParentAuth deny{ma::ParentAuthMode::M1DirectOidc, ma::reject_all_authenticator()};
  auto get = [] { auto r = drogon::HttpRequest::newHttpRequest(); r->setMethod(drogon::Get); r->setPath("/v1/billing/catalog"); return r; };
  check(drogon::sync_wait(ma::billing_catalog(get(), deny))->statusCode() == drogon::k401Unauthorized, "unauthenticated");
  check(drogon::sync_wait(ma::billing_catalog(get(), allow))->statusCode() == drogon::k503ServiceUnavailable, "no database");
  auto withbody = get(); withbody->setBody("{}");
  check(drogon::sync_wait(ma::billing_catalog(withbody, allow))->statusCode() == drogon::k400BadRequest, "GET with body");
  if (failed) return 1;
  std::cout << "billing catalog tests PASS\n";
  return 0;
}
