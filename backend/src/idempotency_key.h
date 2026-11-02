// Idempotency-Key handling (API conventions section 6). The database only ever sees SHA-256 hashes.
#pragma once
#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

#include <drogon/utils/Utilities.h>

namespace ma {

using Sha256 = std::array<std::uint8_t, 32>;

// Accepts a UUID in the canonical 8-4-4-4-12 hex form (either case), returns it lower-cased; anything else is nullopt.
inline std::optional<std::string> normalize_uuid(std::string_view s) {
  if (s.size() != 36) return std::nullopt;
  std::string out(s);
  for (std::size_t i = 0; i < out.size(); ++i) {
    char& c = out[i];
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      if (c != '-') return std::nullopt;
    } else if (c >= 'A' && c <= 'F') {
      c = static_cast<char>(c - 'A' + 'a');
    } else if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) {
      return std::nullopt;
    }
  }
  return out;
}

inline std::optional<Sha256> hex_to_sha256(std::string_view hex) {
  if (hex.size() != 64) return std::nullopt;
  auto nib = [](char c) -> int {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
  };
  Sha256 out{};
  for (std::size_t i = 0; i < 32; ++i) {
    int hi = nib(hex[2 * i]), lo = nib(hex[2 * i + 1]);
    if (hi < 0 || lo < 0) return std::nullopt;
    out[i] = static_cast<std::uint8_t>(hi * 16 + lo);
  }
  return out;
}

inline Sha256 sha256_bytes(std::string_view data) {
  // drogon::utils::getSha256 returns lower-case hex of the 32-byte digest.
  auto h = hex_to_sha256(drogon::utils::getSha256(data.data(), data.size()));
  return h.value();  // cannot fail: the digest is always 64 hex characters
}

// Postgres bytea hex literal ("\x...") for passing a hash as a text parameter.
inline std::string to_pg_bytea(const Sha256& h) {
  static constexpr char kHex[] = "0123456789abcdef";
  std::string s = "\\x";
  for (auto b : h) {
    s += kHex[b >> 4];
    s += kHex[b & 15];
  }
  return s;
}

// Hash of the Idempotency-Key header value, or nullopt if the header is not a UUID (caller answers 400 INVALID_REQUEST).
inline std::optional<Sha256> hash_idempotency_key(std::string_view header_value) {
  auto u = normalize_uuid(header_value);
  if (!u) return std::nullopt;
  return sha256_bytes(*u);
}

}  // namespace ma
