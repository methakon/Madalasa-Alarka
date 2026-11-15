// Device credential revocation and erasure tombstone verification.
// Invariant: Once an erasure request is initiated or a child tombstone is recorded,
// all child and parent device credentials must be revoked immediately, and any
// offline GPS packets replayed by devices must be rejected fail-closed.
#pragma once

#include <chrono>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

namespace ma::privacy {

enum class DeviceRevocationReason {
  None,
  ParentRevoked,
  ChildErasureRequested,
  ConsentWithdrawn,
  StaleCredentials
};

constexpr std::string_view to_string(DeviceRevocationReason reason) {
  switch (reason) {
    case DeviceRevocationReason::None: return "NONE";
    case DeviceRevocationReason::ParentRevoked: return "PARENT_REVOKED";
    case DeviceRevocationReason::ChildErasureRequested: return "CHILD_ERASURE_REQUESTED";
    case DeviceRevocationReason::ConsentWithdrawn: return "CONSENT_WITHDRAWN";
    case DeviceRevocationReason::StaleCredentials: return "STALE_CREDENTIALS";
  }
  return "NONE";
}

struct DeviceSecurityState {
  std::string device_id;
  std::string child_id;
  bool device_active{true};
  bool credentials_revoked{false};
  bool child_tombstoned{false};
  std::uint64_t revocation_epoch{0};
  std::optional<std::chrono::system_clock::time_point> erased_at{std::nullopt};
};

class ErasureReplayGuard {
 public:
  // Verifies whether a device is eligible to submit GPS batches or sync state.
  // Fails closed if the device is inactive, credentials are revoked, or the
  // associated child has an erasure tombstone.
  static bool can_ingest_telemetry(const DeviceSecurityState& state);

  // Verifies if an offline batch timestamp is valid relative to an erasure event.
  // Even if a client device cached points while offline and reconnects later,
  // NO points may be ingested if the child has been erased or the session revoked.
  static bool is_offline_replay_rejected(
      const DeviceSecurityState& state,
      std::chrono::system_clock::time_point observation_time);

  // Evaluates device state transition upon erasure request.
  // Immediately transitions device to inactive, marks credentials revoked,
  // increments the revocation epoch, and sets the erasure tombstone timestamp.
  static DeviceSecurityState revoke_for_erasure(
      DeviceSecurityState current_state,
      std::chrono::system_clock::time_point erasure_time);
};

} // namespace ma::privacy
