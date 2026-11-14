// L10-003 — the free-tier entitlement after a paid plan or trial ends.
//
// Governance sources (all owner-approved design direction; none of this is a
// deployed, legally signed or Play-tested feature):
//   * docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md
//     (§ free-first direction): "At verified prepaid expiry, downgrade to free:
//     live tracking at a reduced adaptive GPS interval (moving design target
//     approximately 10-15 minutes, slower stationary; no Android timing
//     guarantee), most recent six hours of visible location history, and no paid
//     media."  The same paragraph is repeated in the retention schedule, account
//     deletion design, subscription rules, price/staffing model and the public
//     legal drafts.
//   * SRS §ingest: while eligible, the *upload* target is one JSON batch every
//     1-2 minutes. That is an upload-batch target, never a guarantee that Android
//     will observe location at that rate.
//   * Play declarations: the optional premium viewer addon is "dormant until base
//     renewed within term. Original expiry continues during base-plan lapse."
//     A lapse therefore pauses the addon; it must not delete it or restart its
//     fixed expiry clock.
//
// Two rules this component exists to enforce:
//   1. Expiry is a downgrade to *exactly* the free capability set — never a
//      silent retention of paid capability, and never a tighter-than-free
//      remainder.
//   2. No number is invented. The only cadence figures stated in the governance
//      sources are the 1-2 minute eligible upload target and the 10-15 minute
//      reduced free interval. Anything else (for example paid history depth)
//      stays undecided and is modelled as absent rather than guessed.
#pragma once
#include <optional>

namespace ma {

enum class EntitlementState {
  Free,         // never had a trial or a positive prepaid balance
  TrialActive,  // one 48-hour family trial in force
  PaidActive,   // verified prepaid balance in force
  TrialExpired, // the one-time trial has ended; it cannot be restarted
  PaidExpired,  // verified prepaid balance ended; may be topped up again
};

// A cadence target, in whole minutes, with the governance sentence it comes from.
struct CadenceTarget {
  int minutes_min{0};
  int minutes_max{0};
  const char* basis{""};
};

struct EntitlementPlan {
  EntitlementState state{EntitlementState::Free};
  bool paid_features_enabled{false};
  // Free-tier visibility: an access/query window, NOT a storage lifetime.
  int visible_history_hours{6};
  // Paid history depth is not specified anywhere yet. Absent, not guessed.
  std::optional<int> entitled_history_hours{};
  // Acquisition/upload cadence target for the class.
  CadenceTarget cadence{};
  // Premium viewer addon bookkeeping across a base-plan lapse.
  bool premium_addon_held{false};
  bool premium_addon_active{false};
  bool media_enabled{false};
  // True when the plan was reached by losing a paid/trial entitlement.
  bool reverted_to_free{false};
};

inline CadenceTarget eligible_upload_cadence() {
  // SRS: "target sending one JSON array batch every 1-2 minutes" while eligible.
  return {1, 2, "eligible JSON batch upload target (1-2 min)"};
}

inline CadenceTarget reduced_free_cadence() {
  // SRS: "reduced adaptive GPS interval (moving design target approximately
  // 10-15 minutes, slower stationary; no Android timing guarantee)".
  return {10, 15, "reduced adaptive interval on the free tier (10-15 min moving)"};
}

// Resolve the effective free-tier plan. `premium_addon_held` records whether the
// household ever held the optional premium viewer addon, so a lapse can be shown
// to pause it rather than silently drop it.
inline EntitlementPlan resolve_entitlement(EntitlementState state, bool premium_addon_held = false) {
  EntitlementPlan plan;
  plan.state = state;
  plan.premium_addon_held = premium_addon_held;

  switch (state) {
    case EntitlementState::PaidActive:
      plan.paid_features_enabled = true;
      plan.cadence = eligible_upload_cadence();
      plan.premium_addon_active = premium_addon_held;
      break;
    case EntitlementState::TrialActive:
      plan.paid_features_enabled = true;
      plan.cadence = eligible_upload_cadence();
      // The 48-hour trial with no auto-conversion does not grant the paid viewer
      // addon, which is a separate prepaid purchase.
      plan.premium_addon_active = false;
      break;
    case EntitlementState::PaidExpired:
      plan.cadence = reduced_free_cadence();
      plan.reverted_to_free = true;
      // Dormant, not deleted; its own fixed expiry is untouched here.
      plan.premium_addon_active = false;
      break;
    case EntitlementState::TrialExpired:
      plan.cadence = reduced_free_cadence();
      plan.reverted_to_free = true;
      plan.premium_addon_active = false;
      break;
    case EntitlementState::Free:
      plan.cadence = reduced_free_cadence();
      plan.premium_addon_active = false;
      break;
  }

  // FREE_ONLY is in force: no class exposes paid media, and the free-tier
  // visibility window is the query bound for every class until a paid history
  // depth is actually approved.
  plan.media_enabled = false;
  return plan;
}

// A plan is on the free tier when it holds no paid capability.
inline bool is_on_free_tier(const EntitlementPlan& plan) { return !plan.paid_features_enabled; }

}  // namespace ma
