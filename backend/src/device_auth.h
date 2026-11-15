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
  // Bearer-equivalent proof; never log. Synthetic headers cannot create it.
  std::optional<Sha256> credential_sha256{};
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
        res.at(0)["child_id"].as<std::string>(), token_hash};
  } catch (...) {
    co_return std::nullopt;
  }
}

// Bind on the SAME transaction that writes. The preliminary lookup is not
// authorization for a later transaction; SQL revalidates on every ctx_* use.
inline drogon::Task<bool> bind_device_transaction(
    const std::shared_ptr<drogon::orm::Transaction>& tx,
    const DevicePrincipal& principal) {
  if (!principal.credential_sha256) co_return false;
  co_await tx->execSqlCoro(
      "SELECT set_config('ap.session_token','',true),"
      "set_config('ap.device_credential_sha256',$1,true)",
      to_pg_bytea(*principal.credential_sha256).substr(2));
  auto context = co_await tx->execSqlCoro(
      "SELECT ap_m1.ctx_device()::text AS device_id, ap_m1.ctx_principal() AS principal_id");
  co_return !context.empty() && !context.at(0)["device_id"].isNull() &&
      context.at(0)["principal_id"].isNull() &&
      context.at(0)["device_id"].as<std::string>() == principal.device_id;
}

}  // namespace ma
