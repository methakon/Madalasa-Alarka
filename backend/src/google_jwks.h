// Fixed-origin Google public signing keys. No credentials or JWT-derived URLs.
#pragma once
#include "google_oidc.h"
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <functional>
#include <mutex>
#include <optional>
#include <stop_token>
#include <string>
#include <string_view>
#include <thread>

namespace ma {
struct GoogleJwksResponse {
  std::string body;
  std::chrono::seconds ttl{0};
};
// HTTPS only; bounded 256KiB body, 16KiB headers, 1s connect/3s total.
// Requires libcurl ASYNCHDNS; otherwise fails closed before any request.
std::optional<GoogleJwksResponse> fetch_google_jwks(std::stop_token stop = {});

class GoogleJwksCache {
 public:
  using TimePoint = std::chrono::steady_clock::time_point;
  using Clock = std::function<TimePoint()>;
  using Fetch = std::function<std::optional<GoogleJwksResponse>(std::stop_token)>;
  GoogleJwksCache();
  // Trusted test/embedding seam, never populate from environment, JWT or HTTP input.
  // Injected callbacks must honor stop and return within 3s; clock must be monotonic,
  // thread-safe and non-blocking. Production constructor fixes the real transport.
  explicit GoogleJwksCache(Fetch fetch, Clock clock = std::chrono::steady_clock::now);
  ~GoogleJwksCache();
  GoogleJwksCache(const GoogleJwksCache&) = delete;
  GoogleJwksCache& operator=(const GoogleJwksCache&) = delete;
  // Immediate deny on cold/expired/missing kid; schedules one worker, never networking.
  // Refresh is globally kid-independent throttled to one start per 30 seconds/cache.
  OidcPublicKey key(const std::string& kid);
  // Maintenance/test barrier only, NOT for request handlers. Does not trigger fetch.
  bool wait_for_idle(std::chrono::milliseconds timeout);
 private:
  struct Snapshot { OidcKeys keys; TimePoint expires; };
  void schedule(TimePoint now);
  void run(std::stop_token stop);
  Fetch fetch_;
  Clock clock_;
  std::atomic<std::shared_ptr<const Snapshot>> snapshot_;
  std::mutex mutex_;
  std::condition_variable cv_;
  bool pending_{false}, active_{false}, stopping_{false}, attempted_{false};
  TimePoint next_attempt_{};
  std::jthread worker_; // last: all state exists before thread begins, joins before teardown
};

// Small bounded transport seam used by actual curl callbacks and hermetic tests.
// It cannot select an alternate origin, bypass TLS, or perform network I/O itself.
namespace jwks_detail {
struct TransportPolicy {
  std::string_view url, protocols, encoding;
  bool verify_peer, verify_host, follow_redirects;
  long connect_timeout_ms, total_timeout_ms;
  std::size_t max_body_bytes, max_header_bytes;
};
TransportPolicy transport_policy();
class ResponseCollector {
 public:
  bool append(const char* data, std::size_t size, std::size_t count) noexcept;
  bool header(std::string_view line) noexcept;
  std::optional<GoogleJwksResponse> finish(long http_status) const;
  std::size_t body_size() const { return body_.size(); }
 private:
  std::string body_;
  std::size_t header_bytes_{0};
  bool failed_{false}, mime_{false}, cache_{false}, age_seen_{false}, encoding_seen_{false};
  std::optional<unsigned long long> max_age_;
  unsigned long long age_{0};
};
} // namespace jwks_detail
} // namespace ma
