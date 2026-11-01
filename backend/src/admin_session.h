// Admin session authentication and applicant self-status (no role escalation).
// Sessions are issued by admin_auth.h through the separate ap_auth_issuer login.
// Here ap_m1_api can validate the already hashed/revocable token via ctx_admin.
#pragma once
#include <algorithm>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <drogon/drogon.h>
#include "db_support.h"
#include "http_support.h"

namespace ma {

inline std::optional<std::string> admin_session_cookie(std::string_view cookie_header) {
  // One unambiguous 32-byte opaque token in hex, not a bearer JWT; no cookie
  // fixation from duplicated name, partial matches, or control bytes.
  if (cookie_header.empty() || cookie_header.size() > 4096) return std::nullopt;
  std::optional<std::string> found;
  std::size_t pos = 0;
  while (pos < cookie_header.size()) {
    auto end = cookie_header.find(';', pos);
    if (end == std::string_view::npos) end = cookie_header.size();
    auto part = cookie_header.substr(pos, end - pos);
    while (!part.empty() && part.front() == ' ') part.remove_prefix(1);
    if (part.substr(0, 18) == "__Host-ma_admin_s=") {
      if (found || part.size() != 18 + 64) return std::nullopt;
      for (const unsigned char c : part.substr(18)) {
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')))
          return std::nullopt;
      }
      found = std::string(part.substr(18));
    }
    if (end == cookie_header.size()) break;
    pos = end + 1;
  }
  return found;
}

// Drogon moves the Cookie request header into its cookie map (the raw header is
// not retained), so real requests are read through getCookie(). A raw header, as
// set by in-process tests, still goes through the strict duplicate-aware parser.
inline std::optional<std::string> admin_session_cookie(const drogon::HttpRequestPtr& req) {
  const auto& raw = req->getHeader("cookie");
  if (!raw.empty()) return admin_session_cookie(std::string_view(raw));
  const auto& value = req->getCookie("__Host-ma_admin_s");
  if (value.size() != 64) return std::nullopt;
  for (const unsigned char c : value)
    if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return std::nullopt;
  return value;
}

inline drogon::Task<drogon::HttpResponsePtr> admin_access_me(
    drogon::HttpRequestPtr req) {
  using namespace drogon;
  const auto rid = request_id_of(req);
  auto token = admin_session_cookie(req);
  if (!token) co_return error_response("UNAUTHENTICATED", "administrator session required", rid);
  if (!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  auto db = app().getDbClient(kDbClientName);
  std::shared_ptr<orm::Transaction> tx;
  try {
    tx = co_await db->newTransactionCoro();
    co_await tx->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms),std::to_string(db_limits().statement_ms));
    co_await tx->execSqlCoro(
        "SELECT set_config('ap.admin_session_token',$1,true)",*token);
    // Database validates token hash, expiration, revocation epoch and account.
    auto record = co_await tx->execSqlCoro(
        "SELECT a.id::text AS id,a.state AS account_state,"
        "COALESCE((SELECT p.contact_verified_at IS NOT NULL FROM ap_m1.admin_profiles p "
        " WHERE p.admin_id=a.id),false) AS email_verified,"
        "ap_m1.admin_is_owner(a.id) AS owner,"
        "ap_m1.has_admin_permission('FAQ_EDIT') AS faq,"
        "ap_m1.has_admin_permission('SUPPORT_READ') AS support,"
        "ap_m1.has_admin_permission('BILLING_READ') AS billing,"
        "ap_m1.has_admin_permission('USAGE_READ') AS usage,"
        "EXISTS(SELECT 1 FROM ap_m1.admin_access_requests r WHERE r.admin_id=a.id "
        "AND r.state='PENDING_REVIEW') AS pending,"
        "(SELECT r.id::text FROM ap_m1.admin_access_requests r WHERE r.admin_id=a.id "
        " ORDER BY r.submitted_at DESC,r.id DESC LIMIT 1) AS latest_request,"
        "s.role_codes::text AS role_codes,s.mfa_active,"
        "to_char(s.expires_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS session_expires_at "
        "FROM ap_m1.admin_accounts a JOIN ap_m1.admin_session_state() s ON s.admin_id=a.id "
        "WHERE a.id=ap_m1.ctx_admin()");
    if (record.empty()) {
      rollback_quietly(tx);
      co_return error_response("UNAUTHENTICATED","administrator session invalid",rid);
    }
    const auto row=record.at(0);
    const bool active = row["account_state"].as<std::string>() == "ACTIVE";
    const bool privileged = row["owner"].as<bool>() || row["faq"].as<bool>() ||
        row["support"].as<bool>() || row["billing"].as<bool>() || row["usage"].as<bool>();
    Json::Value result(Json::objectValue);
    result["state"] = active && privileged ? "APPROVED" :
        row["pending"].as<bool>() ? "PENDING_REVIEW" : "NO_ACCESS";
    result["email_verified"] = row["email_verified"].as<bool>();
    result["request_id"] = row["latest_request"].isNull() ? Json::Value(Json::nullValue)
                                                         : Json::Value(row["latest_request"].as<std::string>());
    // Server-authoritative roles for page reloads; the browser never asserts a role.
    result["role_codes"] = Json::Value(Json::arrayValue);
    {
      const auto raw = row["role_codes"].isNull() ? std::string("{}") : row["role_codes"].as<std::string>();
      std::string item;
      for (std::size_t i = 1; i + 1 < raw.size(); ++i) {
        if (raw[i] == ',') { if (!item.empty()) result["role_codes"].append(item); item.clear(); }
        else if ((raw[i] >= 'A' && raw[i] <= 'Z') || raw[i] == '_') item.push_back(raw[i]);
      }
      if (!item.empty()) result["role_codes"].append(item);
    }
    result["mfa_active"] = row["mfa_active"].as<bool>();
    result["session_expires_at"] = row["session_expires_at"].as<std::string>();
    result["allowed_actions"] = Json::Value(Json::arrayValue);
    if (!active && row["email_verified"].as<bool>() &&
        !row["pending"].as<bool>()) {
      result["allowed_actions"].append("REQUEST_ACCESS");
    }
    rollback_quietly(tx); // no persistent data change by self-status GET
    auto response=HttpResponse::newHttpJsonResponse(result);
    response->setStatusCode(k200OK);
    response->addHeader(kRequestIdHeader,rid);
    response->addHeader("Cache-Control","no-store");
    co_return response;
  } catch (const orm::SqlError& e) {
    rollback_quietly(tx);
    LOG_ERROR << "admin_access_me SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    co_return response_for_sqlstate(e.sqlState(),rid);
  } catch (const orm::TimeoutError&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  } catch (const orm::BrokenConnection&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  } catch (const std::exception&) {
    rollback_quietly(tx);
    co_return error_response("INTERNAL_ERROR","unexpected server error",rid);
  }
}

} // namespace ma
