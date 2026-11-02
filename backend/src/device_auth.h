// Authentication seam for authenticated child devices (DeviceBearer).
// Maps Bearer token -> SHA-256 -> ap_m1.authenticate_device_credential.
#pragma once
#include <optional>
#include <string>
#include <string_view>

#include <drogon/drogon.h>

#include "crypto_support.h"
#include "db_support.h"
#include "idempotency_key.h"

namespace ma {

struct DevicePrincipal {
  std::string device_id;
  std::string family_id;
  std::string child_id;
};

inline std::optional<std::string> extract_bearer_token(const drogon::HttpRequestPtr& req) {
  const auto& header = req->getHeader("authorization");
  if (header.size() <= 7 || header.size() > 4096) return std::nullopt;
  constexpr std::string_view prefix = "bearer ";
  for (std::size_t i = 0; i < prefix.size(); ++i) {
    char c = header[i];
    char p = prefix[i];
    if (c != p && c != static_cast<char>(p - 'a' + 'A')) return std::nullopt;
  }
  return std::string(header.substr(7));
}

inline drogon::Task<std::optional<DevicePrincipal>> authenticate_device(drogon::HttpRequestPtr req) {
#if defined(MA_SYNTHETIC_AUTH)
  if (const char* mode = std::getenv("MA_AUTH_MODE"); mode && std::string_view(mode) == "synthetic_test") {
    const auto& dev_header = req->getHeader("x-synthetic-device");
    if (!dev_header.empty()) {
      auto norm = normalize_uuid(dev_header);
      if (norm) {
        co_return DevicePrincipal{*norm, "00000000-0000-0000-0000-000000000000", "00000000-0000-0000-0000-000000000000"};
      }
    }
  }
#endif

  auto token = extract_bearer_token(req);
  if (!token) co_return std::nullopt;

  if (!drogon::app().hasDbClient(kDbClientName)) co_return std::nullopt;
  auto db = drogon::app().getDbClient(kDbClientName);
  if (!db) co_return std::nullopt;

  const Sha256 token_hash = sha256_bytes(*token);

  try {
    auto res = co_await db->execSqlCoro(
        "SELECT device_id::text AS device_id, family_id::text AS family_id, child_id::text AS child_id "
        "FROM ap_m1.authenticate_device_credential($1::bytea)",
        to_pg_bytea(token_hash));

    if (res.empty()) co_return std::nullopt;

    co_return DevicePrincipal{
        res.at(0)["device_id"].as<std::string>(),
        res.at(0)["family_id"].as<std::string>(),
        res.at(0)["child_id"].as<std::string>()};
  } catch (...) {
    co_return std::nullopt;
  }
}

}  // namespace ma
