// L15-001 — per-category retention policy abstraction, fail-closed by default.
//
// Governance source: docs/roadmap/RETENTION_PENDING.md (B-07 / conflict C-02) and
// docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md.
//
// Two rules this component exists to enforce:
//   1. No category has an operative retention period until a dated owner/counsel
//      record approves an exact number of days. An undecided or half-specified
//      category must not silently retain forever and must not silently guess a
//      period (the historical 14-day vs 30-day raw-GPS candidates are not a
//      policy).
//   2. The six-hour free history window is a read/query bound, NOT a storage
//      lifetime. It must never be usable as a retention period.
#pragma once
#include <optional>
#include <string>
#include <string_view>

namespace ma::privacy {

// Categories the candidate schedule discusses. Every one is UNDECIDED today.
enum class RetentionCategory {
  RawLocationObservations,
  DerivedTripsAndPlaces,
  AppUsageSummaries,
  CapabilityChangeReports,
  CommandAndSosStatus,
  MediaActivityMetadata,
  AdminAccessAudit,
  SecurityLogs,
  BackupAndWal,
  ConsentAndAuthorityReceipts,
};

inline constexpr std::size_t kRetentionCategoryCount = 10;

enum class DecisionState { Undecided, Approved };

// A decision is only usable when it is Approved AND carries an exact positive
// period AND an approval reference AND an effective date.
struct RetentionDecision {
  DecisionState state{DecisionState::Undecided};
  std::optional<int> days{};
  std::string approval_reference{};
  std::string effective_from{};
};

struct RetentionOutcome {
  bool scheduling_enabled{false};
  std::optional<int> days{};
  // Present for symmetry and to make the invariant explicit: this component can
  // never authorize indefinite retention, even for an approved category.
  bool indefinite_retention_allowed{false};
  std::string_view reason{};
};

// Fail-closed evaluation. Every incomplete input disables scheduling rather than
// falling back to "keep forever" or to a planning candidate.
inline RetentionOutcome evaluate_retention(const RetentionDecision& decision) {
  if (decision.state != DecisionState::Approved)
    return {false, std::nullopt, false, "no approved decision"};
  if (decision.approval_reference.empty() || decision.effective_from.empty())
    return {false, std::nullopt, false, "approval record incomplete"};
  if (!decision.days || *decision.days <= 0)
    return {false, std::nullopt, false, "no positive approved period"};
  return {true, decision.days, false, "approved"};
}

// Free-tier history visibility: a query bound only.
inline constexpr int kFreeHistoryVisibilityHours = 6;

inline bool is_valid_storage_retention_period(int days) { return days > 0; }

// Planning candidates recorded in the governance documents. These are NOT
// approved values. They are exposed so tests can prove the scheduler never falls
// back to them, and to keep the unresolved 14-vs-30-day conflict visible.
inline std::optional<int> retention_planning_candidate_days(RetentionCategory category) {
  switch (category) {
    case RetentionCategory::RawLocationObservations:
      return 14;  // conflicts with a 30-day upload; neither is adopted
    case RetentionCategory::DerivedTripsAndPlaces:
    case RetentionCategory::CapabilityChangeReports:
    case RetentionCategory::AdminAccessAudit:
      return 90;
    case RetentionCategory::AppUsageSummaries:
      return 30;
    case RetentionCategory::CommandAndSosStatus:
    case RetentionCategory::MediaActivityMetadata:
      return 365;
    case RetentionCategory::SecurityLogs:
      return 180;  // CERT-In direction for covered ICT logs, not for raw GPS
    case RetentionCategory::BackupAndWal:
    case RetentionCategory::ConsentAndAuthorityReceipts:
      return std::nullopt;  // never proposed as a number
  }
  return std::nullopt;
}

}  // namespace ma::privacy
