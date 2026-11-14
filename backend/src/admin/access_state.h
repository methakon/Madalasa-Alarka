// Pure access state evaluation and endpoint permission bounds for administrator accounts.
// Invariant: Unapproved Google logins evaluate to NO_ACCESS with empty roles,
// completely disallowing queries to all operational admin endpoints.
#pragma once

#include <optional>
#include <string_view>

namespace ma::admin {

enum class AccessState {
  NoAccess,
  PendingReview,
  Approved,
  Suspended,
  Revoked
};

constexpr std::string_view to_string(AccessState state) {
  switch (state) {
    case AccessState::NoAccess: return "NO_ACCESS";
    case AccessState::PendingReview: return "PENDING_REVIEW";
    case AccessState::Approved: return "APPROVED";
    case AccessState::Suspended: return "SUSPENDED";
    case AccessState::Revoked: return "REVOKED";
  }
  return "NO_ACCESS";
}

std::optional<AccessState> parse_access_state(std::string_view s);

// Evaluates the administrative access state based on account attributes:
// - account_state: 'ACTIVE', 'SUSPENDED', 'REVOKED', 'NO_ACCESS'
// - has_privileged_role: whether the caller holds any active, valid admin permission or owner role
// - has_pending_request: whether an access request is pending review
AccessState evaluate_access_state(std::string_view account_state,
                                  bool has_privileged_role,
                                  bool has_pending_request);

// Verifies if a given administrative action/endpoint is permitted under the state.
// Under NoAccess, PendingReview, Suspended, or Revoked, ALL administrative queries/mutations
// to operational endpoints are strictly DENIED (fail-closed).
// Only self profile reads/updates and request submission are permitted in unapproved states.
bool is_action_permitted(AccessState state, std::string_view action);

} // namespace ma::admin
