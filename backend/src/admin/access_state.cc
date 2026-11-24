#include "admin/access_state.h"

namespace ma::admin {

std::optional<AccessState> parse_access_state(std::string_view s) {
  if (s == "NO_ACCESS") return AccessState::NoAccess;
  if (s == "PENDING_REVIEW") return AccessState::PendingReview;
  if (s == "APPROVED") return AccessState::Approved;
  if (s == "SUSPENDED") return AccessState::Suspended;
  if (s == "REVOKED") return AccessState::Revoked;
  return std::nullopt;
}

AccessState evaluate_access_state(std::string_view account_state,
                                  bool has_privileged_role,
                                  bool has_pending_request) {
  if (account_state == "SUSPENDED") return AccessState::Suspended;
  if (account_state == "REVOKED") return AccessState::Revoked;
  if (account_state == "ACTIVE" && has_privileged_role) {
    return AccessState::Approved;
  }
  if (has_pending_request) {
    return AccessState::PendingReview;
  }
  return AccessState::NoAccess;
}

bool is_action_permitted(AccessState state, std::string_view action) {
  if (state != AccessState::Approved) {
    // Only self-service registration actions allowed for unapproved applicants
    if (state == AccessState::NoAccess) {
      return action == "READ_SELF_STATUS" ||
             action == "UPDATE_SELF_PROFILE" ||
             action == "SUBMIT_ACCESS_REQUEST";
    }
    if (state == AccessState::PendingReview) {
      return action == "READ_SELF_STATUS" ||
             action == "READ_SELF_REQUEST";
    }
    return false; // Suspended and Revoked have no permitted actions
  }
  // Approved accounts are subject to role-specific permissions enforced in SQL / handlers
  return true;
}

} // namespace ma::admin
