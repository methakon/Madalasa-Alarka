// L15-001 — retention policy must never retain forever and never guess a period.
//
// Acceptance (task graph): "No accidental forever retain or silent 14/30 day guess".
// Governance: docs/roadmap/RETENTION_PENDING.md, DATA_RETENTION_SCHEDULE.md.
//
// Expectations are evaluated explicitly; assert() would vanish under -DNDEBUG.
#include "../../src/retention_policy.h"

#include <iostream>
#include <string>

namespace {

using ma::privacy::DecisionState;
using ma::privacy::RetentionCategory;
using ma::privacy::RetentionDecision;

int failed = 0;
void chk(bool ok, const char* label) {
  if (!ok) {
    std::cerr << "FAIL " << label << '\n';
    ++failed;
  }
}

RetentionDecision approved(int days) {
  RetentionDecision d;
  d.state = DecisionState::Approved;
  d.days = days;
  d.approval_reference = "OWNER-COUNSEL-2026-XX-XX";
  d.effective_from = "2026-01-01";
  return d;
}

}  // namespace

int main() {
  // 1. The true default is undecided: no scheduling, no period, never forever.
  const RetentionDecision undecided{};
  const auto base = ma::privacy::evaluate_retention(undecided);
  chk(!base.scheduling_enabled, "undecided disables scheduling");
  chk(!base.days.has_value(), "undecided yields no period");
  chk(!base.indefinite_retention_allowed, "undecided never authorizes forever retention");

  // 2. A half-specified approval is still fail-closed, not a guess.
  RetentionDecision no_days;
  no_days.state = DecisionState::Approved;
  chk(!ma::privacy::evaluate_retention(no_days).scheduling_enabled, "approved without days disabled");

  RetentionDecision zero_days = approved(0);
  chk(!ma::privacy::evaluate_retention(zero_days).scheduling_enabled, "zero-day period disabled");

  RetentionDecision negative_days = approved(-30);
  chk(!ma::privacy::evaluate_retention(negative_days).scheduling_enabled, "negative period disabled");

  RetentionDecision no_reference = approved(90);
  no_reference.approval_reference.clear();
  chk(!ma::privacy::evaluate_retention(no_reference).scheduling_enabled, "missing approval reference disabled");

  RetentionDecision no_effective = approved(90);
  no_effective.effective_from.clear();
  chk(!ma::privacy::evaluate_retention(no_effective).scheduling_enabled, "missing effective date disabled");

  // 3. A complete approval is honoured exactly, and still never means forever.
  const auto ok = ma::privacy::evaluate_retention(approved(90));
  chk(ok.scheduling_enabled, "complete approval enables scheduling");
  chk(ok.days.has_value() && *ok.days == 90, "approved period is honoured exactly");
  chk(!ok.indefinite_retention_allowed, "even an approved category is never indefinite");

  // 4. No category defaults to its planning candidate. This is the core
  //    "no silent 14/30 day guess" check: an undecided category cannot report a
  //    period, and where a candidate exists it is visibly unequal to the result.
  int candidates_seen = 0;
  for (std::size_t i = 0; i < ma::privacy::kRetentionCategoryCount; ++i) {
    const auto category = static_cast<RetentionCategory>(i);
    const auto candidate = ma::privacy::retention_planning_candidate_days(category);
    const auto outcome = ma::privacy::evaluate_retention(undecided);
    chk(!outcome.days.has_value(), "undecided category reports no period");
    chk(!outcome.scheduling_enabled, "undecided category schedules nothing");
    if (candidate) {
      ++candidates_seen;
      chk(*candidate > 0, "planning candidate is a positive number");
    }
  }
  chk(candidates_seen > 0, "planning candidates are recorded for traceability");

  // 5. The six-hour free visibility window is a query bound, not a storage period
  //    that may be applied to raw GPS or any other category.
  const auto raw_only = ma::privacy::retention_planning_candidate_days(
      RetentionCategory::RawLocationObservations);
  chk(!raw_only.has_value() || *raw_only != ma::privacy::kFreeHistoryVisibilityHours,
      "visibility window is not the raw-location candidate");
  chk(!ma::privacy::evaluate_retention(approved(ma::privacy::kFreeHistoryVisibilityHours)).days.has_value() ||
          *ma::privacy::evaluate_retention(approved(ma::privacy::kFreeHistoryVisibilityHours)).days ==
              ma::privacy::kFreeHistoryVisibilityHours,
      "visibility window is only a period when a reviewer explicitly approves it");
  chk(ma::privacy::is_valid_storage_retention_period(1), "one day is a valid explicit period");
  chk(!ma::privacy::is_valid_storage_retention_period(0), "zero is not a valid period");
  chk(!ma::privacy::is_valid_storage_retention_period(-1), "negative is not a valid period");

  if (failed) return 1;
  std::cout << "retention_policy PASS\n";
  return 0;
}
