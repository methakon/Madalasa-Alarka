// Admin-specific Google ID token claims verification.
// Verifies RS256 signature and standard Google claims with the shared verifier
// BEFORE decoding and checking nonce, verified email, and max token age.
// Does NOT establish owner authority or grant an admin session.
#pragma once
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <json/json.h>
#include "google_oidc.h"
#include "crypto_support.h"
#include "idempotency_key.h"
#include "validation.h"

namespace ma {

struct AdminGoogleIdentity {
  std::string issuer;
  std::string subject;
  std::string verified_email;
};

inline bool valid_admin_nonce(std::string_view nonce) {
  if (nonce.size() < 16 || nonce.size() > 128) return false;
  for (const unsigned char c : nonce) {
    if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
          (c >= '0' && c <= '9') || c == '-' || c == '_'))
      return false;
  }
  return true;
}

inline bool valid_verified_email(std::string_view email) {
  if (email.size() < 3 || email.size() > 254 || email.front() == '@' ||
      email.find('@') == std::string_view::npos) return false;
  const auto at = email.find('@');
  if (at == email.size() - 1 || email.find('@', at + 1) != std::string_view::npos)
    return false;
  for (unsigned char c : email)
    if (c < 33 || c > 126 || c == '"' || c == '\\' || c == '<' || c == '>')
      return false;
  return true;
}

// IMPORTANT: Expected nonce must have been issued by the trusted backend,
// tied to a CSRF-protected login attempt and single-use server state. A
// browser-supplied arbitrary nonce/state is NOT sufficient for an admin login.
inline std::optional<AdminGoogleIdentity> verify_admin_google_id_token(
    std::string_view token, std::string_view expected_nonce,
    const GoogleOidcConfig& admin_config, const OidcKeyLookup& keys,
    std::int64_t now_seconds) {
  if (!valid_admin_nonce(expected_nonce)) return std::nullopt;
  // Enforce independent admin-only audience configured outside of the
  // normal parent Google OIDC audiences.
  auto signed_identity = verify_google_id_token(token, admin_config, keys, now_seconds);
  if (!signed_identity) return std::nullopt;

  const auto first = token.find('.');
  const auto second = first == std::string_view::npos ?
      std::string_view::npos : token.find('.', first + 1);
  if (second == std::string_view::npos) return std::nullopt;
  auto payload = base64url_decode(token.substr(first + 1, second - first - 1));
  if (!payload || payload->size() > 8192) return std::nullopt;
  Json::Value claims;
  if (!parse_json_strict(*payload, claims) || !claims.isObject()) return std::nullopt;
  if (!claims["nonce"].isString() || claims["nonce"].asString() != expected_nonce ||
      !claims["email"].isString() || claims["email_verified"] != true)
    return std::nullopt;
  const auto email = claims["email"].asString();
  if (!valid_verified_email(email)) return std::nullopt;
  if (!claims["iat"].isInt64() || !claims["exp"].isInt64()) return std::nullopt;
  const auto iat = claims["iat"].asInt64();
  // Independent admin login freshness: Google ID token may still be valid,
  // but cannot be exchanged more than 5 minutes after its issued-at time.
  if (iat > now_seconds || static_cast<std::uint64_t>(now_seconds) -
      static_cast<std::uint64_t>(iat) > 300) return std::nullopt;
  return AdminGoogleIdentity{signed_identity->issuer, signed_identity->subject, email};
}

} // namespace ma
