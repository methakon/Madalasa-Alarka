// Local-only erasure coordinator policy. No DB writes or production child data.
// The durable worker/SQL adapters must commit tombstones and per-store receipts
// before this policy can be declared integrated (Phase 15).
#pragma once
#include <array>
#include <cstddef>
#include <cstdint>

namespace ma::privacy {

enum class Store : std::size_t {
  RawLocation, PendingInbox, TripsAndPlaces, Notifications, DeviceQueue,
  GuardianViews, ExportArtifacts, BackupIndex, Count
};
constexpr std::size_t kStoreCount = static_cast<std::size_t>(Store::Count);
enum class State { Idle, Requested, Revoked, Purging, Complete };

class ErasureWorkflow {
 public:
  State state() const { return state_; }
  std::uint64_t epoch() const { return epoch_; }

  // A request immediately disables further reads even before deletion succeeds.
  bool readAllowed() const { return state_ == State::Idle; }
  bool request(std::uint64_t epoch) {
    if (epoch == 0 || state_ != State::Idle) return false;
    epoch_ = epoch;
    state_ = State::Requested;
    receipts_.fill(false);
    return true;
  }

  bool markRevoked(std::uint64_t epoch) {
    if (epoch != epoch_ || state_ != State::Requested) return false;
    state_ = State::Revoked;
    return true;
  }

  // Must correspond to a durable delete barrier, never a browser acknowledgment.
  bool markTombstoneCommitted(std::uint64_t epoch) {
    if (epoch != epoch_ || state_ != State::Revoked) return false;
    tombstoneCommitted_ = true;
    state_ = State::Purging;
    return true;
  }

  // Per-store receipts are idempotent only for this exact deletion generation.
  bool recordReceipt(std::uint64_t epoch, Store store) {
    const auto index = static_cast<std::size_t>(store);
    if (epoch != epoch_ || state_ != State::Purging || !tombstoneCommitted_ ||
        index >= kStoreCount) return false;
    receipts_[index] = true;
    return true;
  }

  bool complete(std::uint64_t epoch) {
    if (state_ != State::Purging || epoch != epoch_ || !tombstoneCommitted_) return false;
    for (const bool receipt : receipts_)
      if (!receipt) return false;
    state_ = State::Complete;
    return true;
  }

  // Restored/stale items at or before a committed deletion fence must stay hidden.
  // If deletion is pending, no item for the child is exposed at all.
  bool restoredItemCanSurface(std::uint64_t itemGeneration) const {
    if (state_ != State::Idle) return false;
    return itemGeneration > epoch_;
  }

 private:
  State state_ = State::Idle;
  std::uint64_t epoch_ = 0;
  bool tombstoneCommitted_ = false;
  std::array<bool, kStoreCount> receipts_{};
};
}  // namespace ma::privacy
