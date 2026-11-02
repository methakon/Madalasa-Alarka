#include "google_jwks.h"
#include <openssl/evp.h>
#include <openssl/core_names.h>
#include <openssl/bn.h>
#include <atomic>
#include <cassert>
#include <condition_variable>
#include <iostream>
#include <mutex>
#include <stdexcept>
#include <vector>
using namespace std::chrono_literals;

namespace {
std::string b64(const BIGNUM* n) {
  std::string bytes(BN_num_bytes(n), '\0');
  BN_bn2bin(n, reinterpret_cast<unsigned char*>(bytes.data()));
  std::string out(4 * ((bytes.size() + 2) / 3), '\0');
  EVP_EncodeBlock(reinterpret_cast<unsigned char*>(out.data()), reinterpret_cast<const unsigned char*>(bytes.data()), static_cast<int>(bytes.size()));
  while (!out.empty() && out.back() == '=') out.pop_back();
  for (char& c : out) { if (c == '+') c = '-'; if (c == '/') c = '_'; }
  return out;
}
std::string fixture(const std::string& kid) {
  // Ephemeral signing key is generated solely to extract a valid public n/e.
  // Private material never serialized or persisted.
  std::unique_ptr<EVP_PKEY_CTX, decltype(&EVP_PKEY_CTX_free)> ctx(EVP_PKEY_CTX_new_from_name(nullptr, "RSA", nullptr), EVP_PKEY_CTX_free);
  if (!ctx || EVP_PKEY_keygen_init(ctx.get()) <= 0) throw std::runtime_error("keygen init");
  unsigned bits = 2048;
  OSSL_PARAM params[] = {OSSL_PARAM_construct_uint(OSSL_PKEY_PARAM_BITS, &bits), OSSL_PARAM_construct_end()};
  if (EVP_PKEY_CTX_set_params(ctx.get(), params) <= 0) throw std::runtime_error("keygen params");
  EVP_PKEY* raw = nullptr;
  if (EVP_PKEY_generate(ctx.get(), &raw) <= 0) throw std::runtime_error("keygen");
  ma::OidcPublicKey key(raw, EVP_PKEY_free);
  BIGNUM *n = nullptr, *e = nullptr;
  if (!EVP_PKEY_get_bn_param(key.get(), OSSL_PKEY_PARAM_RSA_N, &n) || !EVP_PKEY_get_bn_param(key.get(), OSSL_PKEY_PARAM_RSA_E, &e)) throw std::runtime_error("public params");
  std::unique_ptr<BIGNUM, decltype(&BN_free)> bn(n, BN_free), be(e, BN_free);
  return "{\"keys\":[{\"kty\":\"RSA\",\"use\":\"sig\",\"alg\":\"RS256\",\"kid\":\"" + kid + "\",\"n\":\"" + b64(n) + "\",\"e\":\"" + b64(e) + "\"}]}";
}
struct Driver {
  std::mutex m;
  std::condition_variable_any cv;
  std::optional<ma::GoogleJwksResponse> result;
  unsigned calls = 0;
  bool release = false;
  std::thread::id worker;
  std::atomic<long> seconds{0};
  auto clock() { return ma::GoogleJwksCache::TimePoint{} + std::chrono::seconds(seconds.load()); }
  auto fetch(std::stop_token stop) {
    std::unique_lock lock(m);
    ++calls; worker = std::this_thread::get_id(); cv.notify_all();
    cv.wait(lock, stop, [&] { return release; });
    return stop.stop_requested() ? std::optional<ma::GoogleJwksResponse>{} : result;
  }
  void prepare(std::optional<ma::GoogleJwksResponse> r) { std::lock_guard l(m); result = std::move(r); release = false; }
  bool started(unsigned n) { std::unique_lock l(m); return cv.wait_for(l, 3s, [&] { return calls >= n; }); }
  void finish() { std::lock_guard l(m); release = true; cv.notify_all(); }
  unsigned count() { std::lock_guard l(m); return calls; }
};
}
int main() {
  unsigned checks = 0;
  auto check = [&](bool v) { if (!v) { std::cerr << "failed cache check " << checks + 1 << '\n'; std::abort(); } ++checks; };
  auto a = fixture("a"), b = fixture("b");
  check(bool(ma::parse_google_jwks(a)) && bool(ma::parse_google_jwks(b)));
  Driver d;
  ma::GoogleJwksCache cache([&](auto s) { return d.fetch(s); }, [&] { return d.clock(); });
  check(!cache.key("") && !cache.key(std::string(257, 'x')) && d.count() == 0);
  d.prepare(ma::GoogleJwksResponse{a, 120s});
  check(!cache.key("a")); // cold deny, no blocking on network barrier
  check(d.started(1));
  check(d.worker != std::this_thread::get_id());
  for (int i = 0; i < 10000; ++i) check(!cache.key("unknown-" + std::to_string(i)));
  check(d.count() == 1);
  d.finish(); check(cache.wait_for_idle(3s));
  auto held = cache.key("a"); check(bool(held));
  check(!cache.key("b") && d.count() == 1); // throttle independent of kid
  d.seconds = 30;
  d.prepare(std::nullopt);
  check(!cache.key("missing")); check(d.started(2));
  check(cache.key("a") == held); // unexpired snapshot survives an in-flight outage
  d.finish(); check(cache.wait_for_idle(3s));
  check(cache.key("a") == held);
  d.seconds = 60;
  d.prepare(ma::GoogleJwksResponse{"{broken", 86400s});
  check(!cache.key("missing")); check(d.started(3));
  d.finish(); check(cache.wait_for_idle(3s));
  check(cache.key("a") == held);
  d.seconds = 120;
  d.prepare(std::nullopt);
  check(!cache.key("a")); check(d.started(4)); // failures have NOT extended original expiry
  d.finish(); check(cache.wait_for_idle(3s));
  check(!cache.key("a"));
  d.seconds = 150;
  d.prepare(ma::GoogleJwksResponse{b, 120s});
  check(!cache.key("b")); check(d.started(5));
  d.finish(); check(cache.wait_for_idle(3s));
  check(bool(cache.key("b"))); check(!cache.key("a")); // rotation REPLACES, never merges
  check(bool(held)); // old immutable snapshot handles remain memory-safe
  d.seconds = 180;
  d.prepare(ma::GoogleJwksResponse{a, 0s});
  check(!cache.key("missing")); check(d.started(6));
  d.finish(); check(cache.wait_for_idle(3s));
  check(bool(cache.key("b")) && !cache.key("a"));
  d.seconds = 210;
  d.prepare(ma::GoogleJwksResponse{a, 999999s});
  check(!cache.key("missing")); check(d.started(7));
  d.finish(); check(cache.wait_for_idle(3s)); check(bool(cache.key("a")));
  d.seconds = 210 + 86400;
  d.prepare(std::nullopt);
  check(!cache.key("a")); check(d.started(8));
  d.finish(); check(cache.wait_for_idle(3s));
  // Concurrent kid flood still admits exactly one fetch and stores no kid queue.
  d.seconds = 90000;
  d.prepare(ma::GoogleJwksResponse{a, 120s});
  std::vector<std::jthread> callers;
  std::atomic<bool> unexpectedly_found{false};
  for (int i = 0; i < 8; ++i) callers.emplace_back([&,i] { for (int j = 0; j < 1000; ++j) if (cache.key("flood-" + std::to_string(i) + "-" + std::to_string(j))) unexpectedly_found = true; });
  callers.clear(); check(!unexpectedly_found); check(d.started(9)); check(d.count() == 9);
  d.finish(); check(cache.wait_for_idle(3s));
  // Bounded cooperative shutdown of an in-flight injected fetch: no sleeps.
  Driver shutdown;
  const auto shutdown_started = std::chrono::steady_clock::now();
  {
    ma::GoogleJwksCache c([&](auto s) { return shutdown.fetch(s); }, [&] { return shutdown.clock(); });
    check(!c.key("a")); check(shutdown.started(1));
  }
  check(shutdown.count() == 1);
  check(std::chrono::steady_clock::now() - shutdown_started < 3s);
  {
    auto lookup = ma::make_google_jwks_lookup();
    auto other = ma::make_google_jwks_lookup();
    check(!lookup("") && !other(std::string(257, 'x'))); // composition, no live networking
  }
  Driver throws;
  {
    ma::GoogleJwksCache c([](auto) -> std::optional<ma::GoogleJwksResponse> { throw std::runtime_error("outage"); }, [&] { return throws.clock(); });
    check(!c.key("a")); check(c.wait_for_idle(3s)); check(!c.key("a"));
  }
  std::cout << checks << " cache checks passed\n";
}
