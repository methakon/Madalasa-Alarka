#include "privacy/tombstones.h"
#include <chrono>
#include <iostream>

static int failures = 0;
#define CHECK(x) do { if (!(x)) { std::cerr << "FAIL line " << __LINE__ << ": " #x "\n"; ++failures; } } while(0)

int main() {
  using namespace ma::privacy;
  using namespace std::chrono;

  const auto now = system_clock::now();
  const auto one_hour_ago = now - hours(1);
  const auto ten_minutes_ago = now - minutes(10);
  const auto five_minutes_future = now + minutes(5);

  // 1. Initial paired, active device state
  DeviceSecurityState device{
    .device_id = "00000000-0000-4000-8000-000000000001",
    .child_id = "00000000-0000-4000-8000-000000000002",
    .device_active = true,
    .credentials_revoked = false,
    .child_tombstoned = false,
    .revocation_epoch = 1,
    .erased_at = std::nullopt
  };

  CHECK(ErasureReplayGuard::can_ingest_telemetry(device));
  CHECK(!ErasureReplayGuard::is_offline_replay_rejected(device, one_hour_ago));
  CHECK(!ErasureReplayGuard::is_offline_replay_rejected(device, now));

  // 2. Perform revocation before erasure
  auto revoked_device = ErasureReplayGuard::revoke_for_erasure(device, ten_minutes_ago);

  CHECK(!revoked_device.device_active);
  CHECK(revoked_device.credentials_revoked);
  CHECK(revoked_device.child_tombstoned);
  CHECK(revoked_device.revocation_epoch == 2);
  CHECK(revoked_device.erased_at.has_value());
  CHECK(*revoked_device.erased_at == ten_minutes_ago);

  // 3. Negative Ingest Gate: Ingest must fail-closed after erasure
  CHECK(!ErasureReplayGuard::can_ingest_telemetry(revoked_device));

  // 4. Offline Replay Rejection:
  // Points buffered offline before erasure, during erasure, or after erasure
  // must all be rejected once the tombstone is established.
  CHECK(ErasureReplayGuard::is_offline_replay_rejected(revoked_device, one_hour_ago));
  CHECK(ErasureReplayGuard::is_offline_replay_rejected(revoked_device, ten_minutes_ago));
  CHECK(ErasureReplayGuard::is_offline_replay_rejected(revoked_device, now));
  CHECK(ErasureReplayGuard::is_offline_replay_rejected(revoked_device, five_minutes_future));

  // 5. Partial revocation states (e.g. parent device revoke or consent withdrawal)
  // Device inactive only
  DeviceSecurityState inactive_device = device;
  inactive_device.device_active = false;
  CHECK(!ErasureReplayGuard::can_ingest_telemetry(inactive_device));
  CHECK(ErasureReplayGuard::is_offline_replay_rejected(inactive_device, now));

  // Credentials revoked only
  DeviceSecurityState stale_creds_device = device;
  stale_creds_device.credentials_revoked = true;
  CHECK(!ErasureReplayGuard::can_ingest_telemetry(stale_creds_device));
  CHECK(ErasureReplayGuard::is_offline_replay_rejected(stale_creds_device, now));

  // Child tombstoned only
  DeviceSecurityState orphaned_device = device;
  orphaned_device.child_tombstoned = true;
  CHECK(!ErasureReplayGuard::can_ingest_telemetry(orphaned_device));
  CHECK(ErasureReplayGuard::is_offline_replay_rejected(orphaned_device, now));

  if (failures) return 1;
  std::cout << "device revocation before erasure and offline replay guard tests PASS\n";
  return 0;
}
