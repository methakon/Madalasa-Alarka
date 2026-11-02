// Google identity validation only: no adult, guardian, consent or child-access authority.
#pragma once
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <vector>
#include <openssl/types.h>

namespace ma {
struct OidcIdentity {
  std::string issuer;
  std::string subject;
};
struct GoogleOidcConfig {
  std::vector<std::string> audiences;
  // When empty, an azp presenter must match an audience. Never accept arbitrary azp.
  std::vector<std::string> presenters;
  std::int64_t clock_skew_seconds{0};
};
using OidcPublicKey = std::shared_ptr<EVP_PKEY>;
using OidcKeys = std::map<std::string, OidcPublicKey>;
using OidcKeyLookup = std::function<OidcPublicKey(const std::string&)>;
using OidcIdentityAllowed = std::function<bool(const OidcIdentity&)>;

// Production composition: fixed Google HTTPS source, one bounded background
// refresher. The returned lookup owns its cache; request callers never do I/O.
OidcKeyLookup make_google_jwks_lookup();

// Bounded, strict public RSA signing JWKS. No private material/token-controlled URL.
std::optional<OidcKeys> parse_google_jwks(std::string_view body);
// Verify the ORIGINAL encoded signing bytes with RS256, then exact provider claims.
// Both documented Google issuer spellings map explicitly to https://accounts.google.com.
// A missing key, invalid config or rejected identity fails closed; no networking here.
std::optional<OidcIdentity> verify_google_id_token(
    std::string_view token, const GoogleOidcConfig& config,
    const OidcKeyLookup& lookup, std::int64_t wall_seconds,
    const OidcIdentityAllowed& allowed = {});
}  // namespace ma
