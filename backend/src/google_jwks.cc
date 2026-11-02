#include "google_jwks.h"
#include <curl/curl.h>
#include <algorithm>
#include <charconv>
#include <limits>
#include <memory>

namespace ma {
namespace {
constexpr std::size_t body_limit = 256 * 1024, header_limit = 16 * 1024;
std::string_view trim(std::string_view v) {
  while (!v.empty() && (v.front() == ' ' || v.front() == '\t' || v.front() == '\r' || v.front() == '\n')) v.remove_prefix(1);
  while (!v.empty() && (v.back() == ' ' || v.back() == '\t' || v.back() == '\r' || v.back() == '\n')) v.remove_suffix(1);
  return v;
}
std::string lower(std::string_view v) {
  std::string s(v);
  for (auto& c : s) if (c >= 'A' && c <= 'Z') c = static_cast<char>(c + ('a' - 'A'));
  return s;
}
std::optional<unsigned long long> number(std::string_view v) {
  v = trim(v);
  unsigned long long n = 0;
  auto [end, ec] = std::from_chars(v.data(), v.data() + v.size(), n);
  if (v.empty() || ec != std::errc{} || end != v.data() + v.size()) return {};
  return n;
}
struct Transfer { jwks_detail::ResponseCollector collector; std::stop_token stop; };
std::size_t write_body(char* p, std::size_t size, std::size_t count, void* ctx) noexcept {
  auto& t = *static_cast<Transfer*>(ctx);
  return !t.stop.stop_requested() && t.collector.append(p, size, count) ? size * count : 0;
}
std::size_t write_header(char* p, std::size_t size, std::size_t count, void* ctx) noexcept {
  if (size && count > std::numeric_limits<std::size_t>::max() / size) return 0;
  auto& t = *static_cast<Transfer*>(ctx);
  return !t.stop.stop_requested() && t.collector.header({p, size * count}) ? size * count : 0;
}
int progress(void* ctx, curl_off_t, curl_off_t, curl_off_t, curl_off_t) noexcept {
  return static_cast<Transfer*>(ctx)->stop.stop_requested() ? 1 : 0;
}
}
namespace jwks_detail {
TransportPolicy transport_policy() {
  return {"https://www.googleapis.com/oauth2/v3/certs", "https", "identity",
          true, true, false, 1000, 3000, body_limit, header_limit};
}
bool ResponseCollector::append(const char* data, std::size_t size, std::size_t count) noexcept {
  if (failed_ || (size && count > std::numeric_limits<std::size_t>::max() / size)) { failed_ = true; return false; }
  const auto n = size * count;
  if (n > body_limit - body_.size()) { failed_ = true; return false; }
  try { body_.append(data, n); } catch (...) { failed_ = true; return false; }
  return true;
}
bool ResponseCollector::header(std::string_view line) noexcept {
  if (failed_ || line.size() > header_limit - header_bytes_) { failed_ = true; return false; }
  header_bytes_ += line.size();
  try {
    if (line.starts_with("HTTP/")) {
      // Interim blocks may precede final response. Aggregate limit NEVER resets.
      mime_ = cache_ = age_seen_ = encoding_seen_ = false;
      max_age_.reset(); age_ = 0;
      return true;
    }
    if (trim(line).empty()) return true;
    const auto colon = line.find(':');
    if (colon == std::string_view::npos || line.front() == ' ' || line.front() == '\t') { failed_ = true; return false; }
    auto name = lower(line.substr(0, colon));
    auto value = trim(line.substr(colon + 1));
    if (name == "content-type") {
      if (mime_ || lower(trim(value.substr(0, value.find(';')))) != "application/json") { failed_ = true; return false; }
      mime_ = true;
    } else if (name == "content-encoding") {
      if (encoding_seen_ || lower(value) != "identity") { failed_ = true; return false; }
      encoding_seen_ = true;
    } else if (name == "age") {
      auto age = number(value);
      if (age_seen_ || !age) { failed_ = true; return false; }
      age_seen_ = true; age_ = *age;
    } else if (name == "cache-control") {
      if (cache_) { failed_ = true; return false; }
      cache_ = true;
      while (!value.empty()) {
        auto comma = value.find(',');
        auto item = trim(value.substr(0, comma));
        auto equal = item.find('=');
        auto directive = lower(trim(item.substr(0, equal)));
        if (directive == "no-cache" || directive == "no-store") { failed_ = true; return false; }
        if (directive == "max-age") {
          if (max_age_ || equal == std::string_view::npos) { failed_ = true; return false; }
          max_age_ = number(item.substr(equal + 1));
          if (!max_age_) { failed_ = true; return false; }
        }
        if (comma == std::string_view::npos) break;
        value.remove_prefix(comma + 1);
      }
    }
  } catch (...) { failed_ = true; return false; }
  return true;
}
std::optional<GoogleJwksResponse> ResponseCollector::finish(long status) const {
  // Missing/quoted/malformed TTL, duplicate freshness headers and zero freshness deny.
  if (failed_ || status != 200 || !mime_ || !cache_ || !max_age_ || *max_age_ <= age_ || body_.empty()) return {};
  return GoogleJwksResponse{body_, std::chrono::seconds(std::min<unsigned long long>(*max_age_ - age_, 86400))};
}
} // namespace jwks_detail

std::optional<GoogleJwksResponse> fetch_google_jwks(std::stop_token stop) {
  // Function-local static initialization is serialized by C++; no global cleanup
  // races with other curl users or active background transfers during destruction.
  static const bool initialized = curl_global_init(CURL_GLOBAL_DEFAULT) == CURLE_OK;
  if (!initialized || stop.stop_requested()) return {};
  auto* version = curl_version_info(CURLVERSION_NOW);
  if (!version || !(version->features & CURL_VERSION_ASYNCHDNS)) return {};
  std::unique_ptr<CURL, decltype(&curl_easy_cleanup)> curl(curl_easy_init(), curl_easy_cleanup);
  if (!curl) return {};
  Transfer transfer{{}, stop};
  const auto p = jwks_detail::transport_policy();
  // Every option is checked. No URL, proxy, trust, redirect or protocol override.
  bool ok = true;
  auto set = [&](CURLoption option, auto value) { if (curl_easy_setopt(curl.get(), option, value) != CURLE_OK) ok = false; };
  set(CURLOPT_URL, p.url.data());
  set(CURLOPT_PROTOCOLS_STR, p.protocols.data());
  set(CURLOPT_REDIR_PROTOCOLS_STR, p.protocols.data());
  set(CURLOPT_FOLLOWLOCATION, p.follow_redirects ? 1L : 0L);
  set(CURLOPT_MAXREDIRS, 0L);
  set(CURLOPT_SSL_VERIFYPEER, p.verify_peer ? 1L : 0L);
  set(CURLOPT_SSL_VERIFYHOST, p.verify_host ? 2L : 0L);
  set(CURLOPT_CONNECTTIMEOUT_MS, p.connect_timeout_ms);
  set(CURLOPT_TIMEOUT_MS, p.total_timeout_ms);
  set(CURLOPT_NOSIGNAL, 1L);
  set(CURLOPT_PROXY, "");
  set(CURLOPT_NETRC, static_cast<long>(CURL_NETRC_IGNORED));
  set(CURLOPT_ACCEPT_ENCODING, p.encoding.data());
  set(CURLOPT_HTTP_CONTENT_DECODING, 0L);
  set(CURLOPT_WRITEFUNCTION, &write_body);
  set(CURLOPT_WRITEDATA, &transfer);
  set(CURLOPT_HEADERFUNCTION, &write_header);
  set(CURLOPT_HEADERDATA, &transfer);
  set(CURLOPT_XFERINFOFUNCTION, &progress);
  set(CURLOPT_XFERINFODATA, &transfer);
  set(CURLOPT_NOPROGRESS, 0L);
  if (!ok || curl_easy_perform(curl.get()) != CURLE_OK || stop.stop_requested()) return {};
  long status = 0;
  if (curl_easy_getinfo(curl.get(), CURLINFO_RESPONSE_CODE, &status) != CURLE_OK) return {};
  return transfer.collector.finish(status);
}

GoogleJwksCache::GoogleJwksCache()
    : GoogleJwksCache(fetch_google_jwks) {}
GoogleJwksCache::GoogleJwksCache(Fetch fetch, Clock clock)
    : fetch_(std::move(fetch)), clock_(std::move(clock)), snapshot_(nullptr),
      worker_([this](std::stop_token stop) { run(stop); }) {}
GoogleJwksCache::~GoogleJwksCache() {
  {
    std::lock_guard lock(mutex_);
    stopping_ = true;
    pending_ = false;
  }
  worker_.request_stop();
  cv_.notify_all();
  // Production transfers have a total 3s deadline and ASYNCHDNS. Never detach
  // a thread holding this object's state; trusted test callbacks share this contract.
  worker_.join();
}
void GoogleJwksCache::schedule(TimePoint now) {
  // Requests never wait on the fetcher or parser; contention simply denies.
  std::unique_lock lock(mutex_, std::try_to_lock);
  if (!lock || stopping_ || pending_ || active_ || (attempted_ && now < next_attempt_)) return;
  attempted_ = true;
  next_attempt_ = now + std::chrono::seconds(30);
  pending_ = true;
  cv_.notify_one();
}
OidcPublicKey GoogleJwksCache::key(const std::string& kid) {
  // OIDC core has a stricter JWT kid bound; enforce independently for embedders.
  if (kid.empty() || kid.size() > 256) return {};
  auto now = clock_();
  auto snapshot = snapshot_.load(std::memory_order_acquire);
  if (snapshot && now < snapshot->expires) {
    auto found = snapshot->keys.find(kid);
    if (found != snapshot->keys.end()) return found->second;
  }
  schedule(now);
  return {};
}
bool GoogleJwksCache::wait_for_idle(std::chrono::milliseconds timeout) {
  std::unique_lock lock(mutex_);
  return cv_.wait_for(lock, timeout, [this] { return !pending_ && !active_; });
}
void GoogleJwksCache::run(std::stop_token stop) {
  while (true) {
    {
      std::unique_lock lock(mutex_);
      cv_.wait(lock, [&] { return pending_ || stopping_ || stop.stop_requested(); });
      if (stopping_ || stop.stop_requested()) return;
      pending_ = false;
      active_ = true;
    }
    try {
      auto started = clock_();
      // Also throttle actual starts (not just scheduling) if worker was delayed.
      {
        std::lock_guard lock(mutex_);
        next_attempt_ = started + std::chrono::seconds(30);
      }
      auto response = fetch_(stop);
      if (!stop.stop_requested() && response && response->body.size() <= body_limit &&
          response->ttl > std::chrono::seconds::zero()) {
        auto ttl = std::min(response->ttl, std::chrono::seconds(86400));
        // Conservative: latency consumes freshness; never refresh expiry on failure.
        auto expires = started + ttl;
        auto parsed = parse_google_jwks(response->body);
        if (parsed && !parsed->empty() && clock_() < expires && !stop.stop_requested()) {
          snapshot_.store(std::make_shared<const Snapshot>(Snapshot{std::move(*parsed), expires}),
                          std::memory_order_release);
        }
      }
    } catch (...) {
      // No raw upstream data/errors enter logs; last snapshot keeps original expiry.
    }
    {
      std::lock_guard lock(mutex_);
      active_ = false;
    }
    cv_.notify_all();
  }
}
OidcKeyLookup make_google_jwks_lookup() {
  // All production lookups share a kid-independent throttle and ONE worker.
  // The lookup owns its cache; release of the last lookup joins the worker.
  static std::mutex mutex;
  static std::weak_ptr<GoogleJwksCache> shared;
  std::lock_guard lock(mutex);
  auto cache = shared.lock();
  if (!cache) {
    cache = std::make_shared<GoogleJwksCache>();
    shared = cache;
  }
  return [cache = std::move(cache)](const std::string& kid) { return cache->key(kid); };
}
} // namespace ma
