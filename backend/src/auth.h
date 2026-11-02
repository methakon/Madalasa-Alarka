// Authentication seam for ParentOIDC routes.
//
// Google RS256 identity validation uses a fixed-provider, freshness-bounded JWKS
// cache. No audience configuration, unavailable keys or invalid tokens => 401.
// Authentication returns identity only, never adult/guardian/child-access authority.
//
// A header-based authenticator for tests is compiled only with -DMA_SYNTHETIC_AUTH=ON (CMake option, default OFF) and is
// additionally switched on at run time by MA_AUTH_MODE=synthetic_test. A production build therefore cannot contain it.
#pragma once
#include <cstdlib>
#include <algorithm>
#include <chrono>
#include <functional>
#include <optional>
#include <stdexcept>
#include <string>
#include "google_oidc.h"

#include <drogon/drogon.h>

namespace ma {

struct Principal {
  std::string issuer;
  std::string subject;
};

using Authenticator = std::function<std::optional<Principal>(const drogon::HttpRequestPtr&)>;

inline Authenticator reject_all_authenticator() {
  return [](const drogon::HttpRequestPtr&) -> std::optional<Principal> { return std::nullopt; };
}

using OidcWallClock = std::function<std::int64_t()>;
inline Authenticator make_google_oidc_authenticator(
    GoogleOidcConfig config, OidcKeyLookup lookup,
    OidcIdentityAllowed allowed = {}, OidcWallClock clock = {}) {
  return [config = std::move(config), lookup = std::move(lookup),
          allowed = std::move(allowed), clock = std::move(clock)](
             const drogon::HttpRequestPtr& req) -> std::optional<Principal> {
    const auto& header = req->getHeader("authorization");
    if (header.size() <= 7 || header.size() > 16384 + 7 || header[6] != ' ') return std::nullopt;
    constexpr std::string_view scheme = "bearer";
    for (std::size_t i = 0; i < scheme.size(); ++i) {
      const char c = header[i];
      if (c != scheme[i] && c != static_cast<char>(scheme[i] - 'a' + 'A')) return std::nullopt;
    }
    const std::string_view token(header.data() + 7, header.size() - 7);
    for (unsigned char c : token)
      if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.')) return std::nullopt;
    try {
      const auto now = clock ? clock() : std::chrono::duration_cast<std::chrono::seconds>(
          std::chrono::system_clock::now().time_since_epoch()).count();
      auto identity = verify_google_id_token(token, config, lookup, now, allowed);
      if (identity) return Principal{identity->issuer, identity->subject};
    } catch (const std::exception&) {
      // Never expose tokens, claims or dependency exceptions to logs/responses.
    }
    return std::nullopt;
  };
}

inline std::vector<std::string> oidc_client_ids(const char* text) {
  std::vector<std::string> result;
  if (!text || !*text) return result;
  const std::string_view input(text);
  if (input.size() > 8192) throw std::invalid_argument("OIDC client configuration");
  std::size_t start = 0;
  while (start <= input.size()) {
    auto end = input.find(',', start);
    if (end == std::string_view::npos) end = input.size();
    const auto value = input.substr(start, end - start);
    if (value.empty() || value.size() > 512 || result.size() >= 16)
      throw std::invalid_argument("OIDC client configuration");
    for (unsigned char c : value)
      if (c < 0x21 || c > 0x7e) throw std::invalid_argument("OIDC client configuration");
    const std::string id(value);
    if (std::find(result.begin(), result.end(), id) != result.end())
      throw std::invalid_argument("OIDC client configuration");
    result.push_back(id);
    if (end == input.size()) break;
    start = end + 1;
  }
  return result;
}

#ifdef MA_SYNTHETIC_AUTH
// Test only: identity taken from X-Synthetic-Subject. Issuer is fixed and clearly fake.
inline Authenticator synthetic_authenticator() {
  return [](const drogon::HttpRequestPtr& req) -> std::optional<Principal> {
    const std::string& s = req->getHeader("x-synthetic-subject");
    if (s.empty() || s.size() > 200) return std::nullopt;
    return Principal{"https://synthetic.invalid", s};
  };
}
#endif

inline Authenticator select_authenticator() {
#ifdef MA_SYNTHETIC_AUTH
  const char* mode = std::getenv("MA_AUTH_MODE");
  if (mode && std::string(mode) == "synthetic_test") {
    LOG_WARN << "SYNTHETIC AUTHENTICATION ENABLED: test build only, never deploy";
    return synthetic_authenticator();
  }
#endif
  GoogleOidcConfig config{oidc_client_ids(std::getenv("MA_GOOGLE_OIDC_AUDIENCE")),
                          oidc_client_ids(std::getenv("MA_GOOGLE_OIDC_PRESENTERS")), 0};
  if (config.audiences.empty()) {
    LOG_WARN << "Google OIDC audience is not configured: authenticated routes answer 401";
    return reject_all_authenticator();
  }
  return make_google_oidc_authenticator(std::move(config), make_google_jwks_lookup());
}

}  // namespace ma
