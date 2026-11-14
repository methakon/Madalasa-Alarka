// Free-first release-boundary checks. Must be meaningful in release builds:
// assert() is compiled out under -DNDEBUG, so every expectation below is
// evaluated explicitly and a mismatch makes the process exit non-zero.
#include "../../src/release_profile.h"

#include <iostream>

namespace {

int failed = 0;
void chk(bool ok, const char* label) {
  if (!ok) {
    std::cerr << "FAIL " << label << '\n';
    ++failed;
  }
}

}  // namespace

int main() {
  using ma::ReleaseProfile;

  // Unset, empty and the explicit free profile all resolve to FREE_ONLY.
  chk(ma::parse_release_profile(nullptr) == ReleaseProfile::FreeOnly, "nullptr -> FreeOnly");
  chk(ma::parse_release_profile("") == ReleaseProfile::FreeOnly, "empty -> FreeOnly");
  chk(ma::parse_release_profile("FREE_ONLY") == ReleaseProfile::FreeOnly, "FREE_ONLY -> FreeOnly");

  // Unknown or aspirational values must be rejected, not silently accepted.
  chk(!ma::parse_release_profile("enabled"), "unknown value rejected");
  chk(!ma::parse_release_profile("PAID_VERIFIED_NOW"), "near-miss paid value rejected");

  // Free capabilities never expose paid, trial or premium media by accident.
  const auto free = ma::free_release_capabilities();
  chk(free.freeHistoryHours == 6, "free history window is 6 hours");
  chk(!free.paidEnabled, "free profile has no paid capability");
  chk(!free.trialEnabled, "free profile has no trial capability");
  chk(!free.premiumMediaEnabled, "free profile has no premium media capability");
  chk(free.movingLocationMinutesMin == 10 && free.movingLocationMinutesMax == 15,
      "moving-cadence policy window");

  // The paid latch needs the profile AND all three independent approvals.
  chk(!ma::paid_release_authorized(ReleaseProfile::PaidVerified, nullptr, nullptr, nullptr),
      "paid profile alone is not enough");
  chk(!ma::paid_release_authorized(ReleaseProfile::PaidVerified, "CONFIRMED", nullptr, "CONFIRMED"),
      "missing provider approval blocks paid");
  chk(!ma::paid_release_authorized(ReleaseProfile::FreeOnly, "CONFIRMED", "CONFIRMED", "CONFIRMED"),
      "free profile cannot be escalated by approvals");
  chk(ma::paid_release_authorized(ReleaseProfile::PaidVerified, "CONFIRMED", "CONFIRMED", "CONFIRMED"),
      "paid profile with all approvals");

  // Media stays off even in the paid capability set.
  chk(!ma::paid_release_capabilities().premiumMediaEnabled, "paid set still omits premium media");

  if (failed) return 1;
  std::cout << "free_release_profile PASS\n";
  return 0;
}
