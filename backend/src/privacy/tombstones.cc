#include "privacy/tombstones.h"

namespace ma::privacy {

bool ErasureReplayGuard::can_ingest_telemetry(const DeviceSecurityState& state) {
  // Fail-closed gate: Ingest requires active device, unrevoked credentials,
  // and absence of an erasure tombstone.
  if (!state.device_active) return false;
  if (state.credentials_revoked) return false;
  if (state.child_tombstoned) return false;
  return true;
}

bool ErasureReplayGuard::is_offline_replay_rejected(
    const DeviceSecurityState& state,
    std::chrono::system_clock::time_point observation_time) {
  // If the child is already tombstoned or credentials revoked, reject immediately.
  if (state.child_tombstoned || state.credentials_revoked || !state.device_active) {
    return true;
  }
  // If an erasure timestamp is set, any observation recorded before or after
  // is strictly rejected once erasure was executed.
  if (state.erased_at.has_value() && observation_time >= *state.erased_at) {
    return true;
  }
  return false;
}

DeviceSecurityState ErasureReplayGuard::revoke_for_erasure(
    DeviceSecurityState current_state,
    std::chrono::system_clock::time_point erasure_time) {
  current_state.device_active = false;
  current_state.credentials_revoked = true;
  current_state.child_tombstoned = true;
  current_state.revocation_epoch += 1;
  current_state.erased_at = erasure_time;
  return current_state;
}

} // namespace ma::privacy
