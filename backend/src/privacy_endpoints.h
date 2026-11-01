// Parent and device privacy APIs backed by existing V2 SQL authorization.
// No lab shortcut bypasses child-scoped grants, consent or revocation.
// Uses existing physical schema, never derives authority from a billing family.
#pragma once
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <drogon/drogon.h>
#include "parent_session.h"
#include "device_auth.h"
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"

namespace ma {

enum class PrivacyReadKind { GuardianGrants, Consents };

inline drogon::HttpResponsePtr privacy_json(const Json::Value& body, const std::string& rid) {
  auto resp = drogon::HttpResponse::newHttpJsonResponse(body);
  resp->setStatusCode(drogon::k200OK);
  resp->addHeader(kRequestIdHeader, rid);
  add_no_store(resp);
  return resp;
}

inline drogon::HttpResponsePtr privacy_not_found(const std::string& rid) {
  auto resp = error_response("NOT_FOUND", "child or resource not found", rid);
  add_no_store(resp);
  return resp;
}

// Caller must present a trusted V2 parent session. Even a current family member
// is NOT automatically a guardian for the requested child.
inline drogon::Task<drogon::HttpResponsePtr> read_child_privacy(
    drogon::HttpRequestPtr req, std::string child_id, ParentAuth auth, PrivacyReadKind kind) {
  const auto rid = request_id_of(req);
  auto child = normalize_uuid(child_id);
  if (!child) co_return error_response("INVALID_REQUEST", "childId must be a UUID", rid);
  if (auth.mode != ParentAuthMode::V2Session)
    co_return error_response("SERVICE_UNAVAILABLE", "privacy APIs require trusted parent sessions", rid);
  auto credential = parent_credential(auth, req);
  if (!credential) co_return unauthenticated_no_store("missing or invalid parent session", rid);
  if (!drogon::app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  auto db = drogon::app().getDbClient(kDbClientName);
  std::shared_ptr<drogon::orm::Transaction> tx;
  try {
    tx = co_await db->newTransactionCoro();
    co_await tx->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    if (!(co_await bind_parent_principal(tx, *credential))) {
      rollback_quietly(tx);
      co_return unauthenticated_no_store("invalid or expired parent session", rid);
    }
    const std::string scope = kind == PrivacyReadKind::GuardianGrants
          ? "MANAGE_CHILD_GRANTS" : "MANAGE_CONSENT";
    auto allowed = co_await tx->execSqlCoro(
        "SELECT ap_m1.has_child_scope_v2($1::uuid,$2::text) AS allowed", *child, scope);
    if (allowed.empty() || !allowed.at(0)["allowed"].as<bool>()) {
      rollback_quietly(tx);
      co_return privacy_not_found(rid);
    }
    Json::Value result(Json::objectValue);
    result["child_id"] = *child;
    result["items"] = Json::Value(Json::arrayValue);
    if (kind == PrivacyReadKind::GuardianGrants) {
      // RLS still independently filters this SELECT. Deliberately no invite
      // token, authority evidence, ID photo, email or other siblings.
      auto rows = co_await tx->execSqlCoro(
          "SELECT id::text AS id,adult_id::text AS adult_id,scope,"
          "coalesce(to_char(expires_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),'') AS expires_at "
          "FROM ap_m1.child_access_grants_v2 "
          "WHERE child_id=$1::uuid AND revoked_at IS NULL "
          "ORDER BY created_at DESC,id LIMIT 200", *child);
      for (const auto& row : rows) {
        Json::Value item(Json::objectValue);
        item["id"] = row["id"].as<std::string>();
        item["adult_id"] = row["adult_id"].as<std::string>();
        item["scope"] = row["scope"].as<std::string>();
        item["expires_at"] = row["expires_at"].as<std::string>();
        result["items"].append(item);
      }
    } else {
      auto rows = co_await tx->execSqlCoro(
          "SELECT purpose,status,legal_state,notice_version,"
          "coalesce(to_char(expires_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),'') AS expires_at "
          "FROM ap_m1.consent_records WHERE child_id=$1::uuid "
          "ORDER BY granted_at DESC,id LIMIT 100", *child);
      for (const auto& row : rows) {
        Json::Value item(Json::objectValue);
        item["purpose"] = row["purpose"].as<std::string>();
        item["status"] = row["status"].as<std::string>();
        item["legal_state"] = row["legal_state"].as<std::string>();
        item["notice_version"] = row["notice_version"].as<std::string>();
        item["expires_at"] = row["expires_at"].as<std::string>();
        result["items"].append(item);
      }
    }
    rollback_quietly(tx);
    co_return privacy_json(result, rid);
  } catch (const drogon::orm::SqlError& e) {
    rollback_quietly(tx);
    LOG_ERROR << "privacy read SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const drogon::orm::TimeoutError&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const drogon::orm::BrokenConnection&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    rollback_quietly(tx);
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

// Existing SQL revoke_child_grant is SECURITY DEFINER; use its checked path.
// Resolve grant->child before invoking it, to prevent an ID from one child
// being passed under a different child's URL.
inline drogon::Task<drogon::HttpResponsePtr> delete_child_privacy_grant(
    drogon::HttpRequestPtr req, std::string child_id, std::string grant_id, ParentAuth auth) {
  const auto rid = request_id_of(req);
  const auto child = normalize_uuid(child_id);
  const auto grant = normalize_uuid(grant_id);
  if (!child || !grant) co_return error_response("INVALID_REQUEST", "childId and grantId must be UUIDs", rid);
  if (!req->body().empty()) co_return error_response("INVALID_REQUEST", "DELETE requires an empty body", rid);
  if (auth.mode != ParentAuthMode::V2Session)
    co_return error_response("SERVICE_UNAVAILABLE", "privacy APIs require trusted parent sessions", rid);
  auto credential = parent_credential(auth, req);
  if (!credential) co_return unauthenticated_no_store("missing or invalid parent session", rid);
  if (!drogon::app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  auto db = drogon::app().getDbClient(kDbClientName);
  std::shared_ptr<drogon::orm::Transaction> tx;
  try {
    tx = co_await db->newTransactionCoro();
    co_await tx->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    if (!(co_await bind_parent_principal(tx, *credential))) {
      rollback_quietly(tx);
      co_return unauthenticated_no_store("invalid or expired parent session", rid);
    }
    auto match = co_await tx->execSqlCoro(
        "SELECT EXISTS(SELECT 1 FROM ap_m1.child_access_grants_v2 "
        "WHERE id=$1::uuid AND child_id=$2::uuid) AS present,"
        "ap_m1.has_child_scope_v2($2::uuid,'MANAGE_CHILD_GRANTS') AS allowed",
        *grant, *child);
    if (match.empty() || !match.at(0)["present"].as<bool>() || !match.at(0)["allowed"].as<bool>()) {
      rollback_quietly(tx);
      co_return privacy_not_found(rid);
    }
    co_await tx->execSqlCoro("SELECT ap_m1.revoke_child_grant($1::uuid)", *grant);
    if (!(co_await commit(std::move(tx))))
      co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable", rid, true);
    auto resp = drogon::HttpResponse::newHttpResponse();
    resp->setStatusCode(static_cast<drogon::HttpStatusCode>(204));
    resp->addHeader(kRequestIdHeader, rid);
    add_no_store(resp);
    co_return resp;
  } catch (const drogon::orm::SqlError& e) {
    rollback_quietly(tx);
    LOG_ERROR << "privacy revoke SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    if (e.sqlState() == "42501") co_return privacy_not_found(rid);
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const drogon::orm::TimeoutError&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const drogon::orm::BrokenConnection&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    rollback_quietly(tx);
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

// Returns only the enrolled device's own consent-derived policy eligibility;
// never claims a live location stream, an Android OS grant or guardian identity.
inline drogon::Task<drogon::HttpResponsePtr> device_consent_status(
    drogon::HttpRequestPtr req, std::string device_id) {
  const auto rid = request_id_of(req);
  const auto target = normalize_uuid(device_id);
  if (!target) co_return error_response("INVALID_REQUEST", "deviceId must be a UUID", rid);
  auto actor = co_await authenticate_device(req);
  if (!actor) co_return unauthenticated_no_store("missing or invalid device credential", rid);
  if (*target != actor->device_id) co_return privacy_not_found(rid);
  if (!drogon::app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  try {
    auto db = drogon::app().getDbClient(kDbClientName);
    auto rows = co_await db->execSqlCoro(
        "SELECT ap_m1.child_deleted($1::uuid) AS deleted,"
        "ap_m1.has_consent($1::uuid,'CORE') AS core,"
        "ap_m1.has_consent($1::uuid,'LOCATION') AS location,"
        "ap_m1.has_consent($1::uuid,'USAGE') AS usage,"
        "ap_m1.has_consent($1::uuid,'MEDIA') AS media", actor->child_id);
    if (rows.empty()) co_return error_response("SERVICE_UNAVAILABLE", "policy unavailable", rid, true);
    Json::Value body(Json::objectValue);
    body["device_id"] = actor->device_id;
    body["deleted"] = rows.at(0)["deleted"].as<bool>();
    body["core_consent"] = rows.at(0)["core"].as<bool>();
    body["location_consent"] = rows.at(0)["location"].as<bool>();
    body["usage_consent"] = rows.at(0)["usage"].as<bool>();
    body["media_consent"] = rows.at(0)["media"].as<bool>();
    body["android_permission_state"] = "UNKNOWN_DEVICE_LOCAL_ONLY";
    body["collection_authorized"] = false;  // Needs independent platform+purpose eligibility.
    co_return privacy_json(body, rid);
  } catch (const drogon::orm::SqlError& e) {
    LOG_ERROR << "device consent status SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const drogon::orm::TimeoutError&) {
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const drogon::orm::BrokenConnection&) {
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

}  // namespace ma
