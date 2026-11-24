#include <drogon/drogon.h>
#include "admin/access_state.h"
#include "admin_session.h"
#include <iostream>

static int failures = 0;
#define CHECK(x) do { if (!(x)) { std::cerr << "FAIL line " << __LINE__ << ": " #x "\n"; ++failures; } } while(0)

int main() {
  using namespace ma::admin;

  // 1. Serialization and Parsing
  CHECK(to_string(AccessState::NoAccess) == "NO_ACCESS");
  CHECK(to_string(AccessState::PendingReview) == "PENDING_REVIEW");
  CHECK(to_string(AccessState::Approved) == "APPROVED");
  CHECK(to_string(AccessState::Suspended) == "SUSPENDED");
  CHECK(to_string(AccessState::Revoked) == "REVOKED");

  CHECK(parse_access_state("NO_ACCESS") == AccessState::NoAccess);
  CHECK(parse_access_state("PENDING_REVIEW") == AccessState::PendingReview);
  CHECK(parse_access_state("APPROVED") == AccessState::Approved);
  CHECK(parse_access_state("SUSPENDED") == AccessState::Suspended);
  CHECK(parse_access_state("REVOKED") == AccessState::Revoked);
  CHECK(!parse_access_state("UNKNOWN").has_value());
  CHECK(!parse_access_state("").has_value());

  // 2. Access State Evaluation Matrix
  // Active + privileged -> Approved
  CHECK(evaluate_access_state("ACTIVE", true, false) == AccessState::Approved);
  CHECK(evaluate_access_state("ACTIVE", true, true) == AccessState::Approved);

  // Active + unprivileged (e.g. without granted roles or MFA)
  CHECK(evaluate_access_state("ACTIVE", false, false) == AccessState::NoAccess);
  CHECK(evaluate_access_state("ACTIVE", false, true) == AccessState::PendingReview);

  // Initial applicant login defaults to NO_ACCESS account_state
  CHECK(evaluate_access_state("NO_ACCESS", false, false) == AccessState::NoAccess);
  CHECK(evaluate_access_state("NO_ACCESS", false, true) == AccessState::PendingReview);

  // Suspended and Revoked fail closed unconditionally
  CHECK(evaluate_access_state("SUSPENDED", true, true) == AccessState::Suspended);
  CHECK(evaluate_access_state("REVOKED", true, true) == AccessState::Revoked);
  CHECK(evaluate_access_state("SUSPENDED", false, false) == AccessState::Suspended);
  CHECK(evaluate_access_state("REVOKED", false, false) == AccessState::Revoked);

  // 3. Operational Action Boundary (Negative Gates)
  // Under NO_ACCESS, all operational administrative actions must be refused
  const std::string_view operational_actions[] = {
    "OWNER_MANAGE",
    "FAQ_EDIT",
    "FAQ_PUBLISH",
    "SUPPORT_READ",
    "SUPPORT_REPLY",
    "BILLING_READ",
    "USAGE_READ",
    "AUDIT_READ"
  };

  for (const auto action : operational_actions) {
    CHECK(!is_action_permitted(AccessState::NoAccess, action));
    CHECK(!is_action_permitted(AccessState::PendingReview, action));
    CHECK(!is_action_permitted(AccessState::Suspended, action));
    CHECK(!is_action_permitted(AccessState::Revoked, action));
    CHECK(is_action_permitted(AccessState::Approved, action));
  }

  // Self-service actions under NO_ACCESS
  CHECK(is_action_permitted(AccessState::NoAccess, "READ_SELF_STATUS"));
  CHECK(is_action_permitted(AccessState::NoAccess, "UPDATE_SELF_PROFILE"));
  CHECK(is_action_permitted(AccessState::NoAccess, "SUBMIT_ACCESS_REQUEST"));
  CHECK(!is_action_permitted(AccessState::NoAccess, "OTHER_ACTION"));

  // Self-service actions under PENDING_REVIEW
  CHECK(is_action_permitted(AccessState::PendingReview, "READ_SELF_STATUS"));
  CHECK(is_action_permitted(AccessState::PendingReview, "READ_SELF_REQUEST"));
  CHECK(!is_action_permitted(AccessState::PendingReview, "UPDATE_SELF_PROFILE"));
  CHECK(!is_action_permitted(AccessState::PendingReview, "SUBMIT_ACCESS_REQUEST"));

  // 4. Admin Access Self Status Endpoint (Negative & Offline Gates)
  auto req = drogon::HttpRequest::newHttpRequest();
  req->setMethod(drogon::Get);
  req->setPath("/v1/admin/access/me");

  // Anonymous request fails with 401
  auto unauth = drogon::sync_wait(ma::admin_access_me(req));
  CHECK(unauth->statusCode() == drogon::k401Unauthorized);

  // Request with invalid cookie format fails with 401
  req->addHeader("cookie", "__Host-ma_admin_s=invalid-short-token");
  auto invalid_cookie = drogon::sync_wait(ma::admin_access_me(req));
  CHECK(invalid_cookie->statusCode() == drogon::k401Unauthorized);

  // Valid cookie format with offline DB returns 503 SERVICE_UNAVAILABLE
  const std::string valid_cookie(64, 'b');
  req->addHeader("cookie", "__Host-ma_admin_s=" + valid_cookie);
  auto offline = drogon::sync_wait(ma::admin_access_me(req));
  CHECK(offline->statusCode() == drogon::k503ServiceUnavailable);
  CHECK(offline->getJsonObject() != nullptr);
  CHECK((*offline->getJsonObject())["code"] == "SERVICE_UNAVAILABLE");

  if (failures) return 1;
  std::cout << "admin access state and negative operational boundary tests PASS\n";
  return 0;
}
