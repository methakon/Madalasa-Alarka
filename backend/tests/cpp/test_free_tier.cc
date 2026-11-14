// L10-003 — "Expired paid reverts free with reduced cadence".
//
// Governance: SRS free-first direction (reduced adaptive GPS interval, six hours
// visible history, no paid media on expiry) and the Play declaration that the
// premium viewer addon goes dormant on a base-plan lapse while its own expiry is
// untouched.
//
// Expectations are evaluated explicitly; assert() would vanish under -DNDEBUG.
#include "../../src/free_tier.h"

#include <iostream>
#include <set>

namespace {

using ma::EntitlementState;

int failed = 0;
void chk(bool ok, const char* label) {
  if (!ok) {
    std::cerr << "FAIL " << label << '\n';
    ++failed;
  }
}

}  // namespace

int main() {
  // 1. An expired prepaid plan is on the free tier and nothing paid survives.
  const auto expired = ma::resolve_entitlement(EntitlementState::PaidExpired);
  chk(!expired.paid_features_enabled, "expired prepaid exposes no paid feature");
  chk(ma::is_on_free_tier(expired), "expired prepaid is on the free tier");
  chk(expired.reverted_to_free, "expired prepaid is marked reverted");
  chk(!expired.media_enabled, "expired prepaid exposes no paid media");

  // 2. Reduced cadence: expiry must move from the eligible 1-2 minute upload
  //    target to the documented reduced 10-15 minute interval, and must not land
  //    somewhere tighter or looser than that documented window.
  chk(expired.cadence.minutes_min == 10 && expired.cadence.minutes_max == 15,
      "expired prepaid uses the documented reduced interval");
  chk(expired.cadence.minutes_min >= ma::eligible_upload_cadence().minutes_max,
      "reduced cadence is genuinely slower than the eligible target");

  // 3. Six hours of visible history, and the free window is the only history
  //    figure the free tier may claim.
  chk(expired.visible_history_hours == 6, "expired prepaid keeps the six-hour window");

  // 4. A paid history depth is not specified anywhere yet, so nothing may claim
  //    one. An expired plan must report no entitled depth, not a guessed number.
  chk(!expired.entitled_history_hours.has_value(),
      "expired prepaid claims no unspecified history depth");

  // 5. The premium viewer addon is dormant, not deleted, after a lapse.
  const auto lapsed_with_addon = ma::resolve_entitlement(EntitlementState::PaidExpired, true);
  chk(lapsed_with_addon.premium_addon_held, "a held premium addon is remembered after lapse");
  chk(!lapsed_with_addon.premium_addon_active, "a held premium addon is dormant during the lapse");
  chk(!lapsed_with_addon.paid_features_enabled, "a dormant addon is not an active paid feature");

  // 6. An active paid balance does enable the eligible cadence, but still no
  //    invented history depth and still no media while FREE_ONLY.
  const auto paid = ma::resolve_entitlement(EntitlementState::PaidActive, true);
  chk(paid.paid_features_enabled, "active prepaid exposes paid features");
  chk(paid.cadence.minutes_min == 1 && paid.cadence.minutes_max == 2,
      "active prepaid uses the documented eligible upload target");
  chk(paid.premium_addon_active, "an addon is active while the base plan is in force");
  chk(!paid.media_enabled, "FREE_ONLY keeps media off even for a paid balance");
  chk(!paid.entitled_history_hours.has_value(), "active prepaid claims no unspecified history depth");

  // 7. The one-time trial behaves like paid while it runs and reverts on expiry,
  //    and it never grants the separately purchased premium addon.
  const auto trial = ma::resolve_entitlement(EntitlementState::TrialActive, true);
  chk(trial.paid_features_enabled, "an active trial exposes trial features");
  chk(!trial.premium_addon_active, "the trial does not grant the premium addon");
  const auto trial_over = ma::resolve_entitlement(EntitlementState::TrialExpired);
  chk(ma::is_on_free_tier(trial_over) && trial_over.reverted_to_free,
      "an ended trial reverts to the free tier");
  chk(trial_over.cadence.minutes_min == 10 && trial_over.cadence.minutes_max == 15,
      "an ended trial uses the reduced interval");
  chk(trial_over.visible_history_hours == 6, "an ended trial keeps the six-hour window");

  // 8. A household that never paid starts on the free tier and cannot acquire
  //    paid capability merely by being resolved.
  const auto free = ma::resolve_entitlement(EntitlementState::Free);
  chk(ma::is_on_free_tier(free), "the free state holds no paid capability");
  chk(!free.reverted_to_free, "the free state did not revert from anything");
  chk(free.cadence.minutes_min == 10 && free.cadence.minutes_max == 15,
      "the free state uses the reduced interval");
  chk(!free.premium_addon_active && !free.premium_addon_held, "free holds no addon");

  // 9. Exhaustive: whichever way the free tier is reached, the capability set is
  //    identical. No expiry path may leave a wider window or a faster cadence.
  std::set<long> fingerprint;
  for (auto s : {EntitlementState::Free, EntitlementState::PaidExpired, EntitlementState::TrialExpired}) {
    const auto p = ma::resolve_entitlement(s);
    fingerprint.insert(static_cast<long>(p.visible_history_hours) * 1000000L +
                       static_cast<long>(p.cadence.minutes_min) * 10000L +
                       static_cast<long>(p.cadence.minutes_max) * 100L +
                       (p.paid_features_enabled ? 1L : 0L));
  }
  chk(fingerprint.size() == 1, "every free-tier entry path yields one capability set");

  if (failed) return 1;
  std::cout << "free_tier PASS\n";
  return 0;
}
