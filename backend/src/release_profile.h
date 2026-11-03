// Free-first public release boundary. These env flags do NOT substitute for
// legal, Google Play, merchant or actual review evidence. Default is FREE_ONLY.
#pragma once
#include <cstdlib>
#include <optional>
#include <string_view>

namespace ma {
enum class ReleaseProfile { FreeOnly, PaidVerified };

inline std::optional<ReleaseProfile> parse_release_profile(const char* raw) {
  if (!raw || !*raw || std::string_view(raw)=="FREE_ONLY")
    return ReleaseProfile::FreeOnly;
  if (std::string_view(raw)=="PAID_VERIFIED")
    return ReleaseProfile::PaidVerified;
  return std::nullopt;
}

// Only an explicit, deliberate paid release may expose purchase/trial routes.
// This check is a safety latch, NOT evidence that the vendor or counsel approved.
inline bool paid_release_authorized(ReleaseProfile profile,
                                    const char* owner_approval,
                                    const char* provider_approval,
                                    const char* play_billing_review) {
  return profile==ReleaseProfile::PaidVerified &&
         owner_approval && std::string_view(owner_approval)=="CONFIRMED" &&
         provider_approval && std::string_view(provider_approval)=="CONFIRMED" &&
         play_billing_review && std::string_view(play_billing_review)=="CONFIRMED";
}

struct ReleaseCapabilities {
  ReleaseProfile profile{ReleaseProfile::FreeOnly};
  bool paidEnabled{false};
  bool trialEnabled{false};
  bool premiumMediaEnabled{false};
  int freeHistoryHours{6};
  // Moving interval is a policy *target*; Android may deliver more slowly.
  int movingLocationMinutesMin{10};
  int movingLocationMinutesMax{15};
};

inline ReleaseCapabilities free_release_capabilities() { return {}; }
inline ReleaseCapabilities paid_release_capabilities() {
  ReleaseCapabilities v;
  v.profile=ReleaseProfile::PaidVerified;
  v.paidEnabled=true;
  v.trialEnabled=true;  // still subject to independent child eligibility and OS gates
  v.premiumMediaEnabled=false; // no camera/mic/screen capabilities by implication
  return v;
}
} // namespace ma
