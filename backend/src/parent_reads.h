// Read-only M1 guardian handlers. PostgreSQL RLS and the V2 trusted-session
// layer remain the authority; OIDC issuer+subject are identity, NOT custody proof.
// No fabricated success or in-memory family scope for missing database grants.
#pragma once
#include <drogon/drogon.h>
#include <memory>
#include <string>
#include "auth.h"
#include "parent_session.h"
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"

namespace ma {

inline drogon::HttpResponsePtr m1_json_ok(const Json::Value& data, const std::string& rid) {
  auto resp = drogon::HttpResponse::newHttpJsonResponse(data);
  resp->setStatusCode(drogon::k200OK);
  resp->addHeader(kRequestIdHeader, rid);
  return resp;
}

// All queries below run only after PostgreSQL resolved the caller from the
// presented V2 session (or, in the explicit M1 mode, a verified ID token).
// set_config of a UUID alone never creates a trusted session.
inline drogon::Task<drogon::HttpResponsePtr> list_families(
    drogon::HttpRequestPtr req, ParentAuth auth) {
  const auto rid = request_id_of(req);
  auto credential = parent_credential(auth, req);
  if (!credential) co_return error_response("UNAUTHENTICATED", "missing or invalid parent credential", rid);
  if (!drogon::app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  auto db = drogon::app().getDbClient(kDbClientName);
  std::shared_ptr<drogon::orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    auto bound = co_await bind_parent_principal(trans, *credential);
    if (!bound) {
      rollback_quietly(trans);
      co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);
    }
    // list_my_families is an audited M1<->V2 compatibility function keyed by
    // ctx_principal, which resolves only from an accepted V2 session.
    auto rows = co_await trans->execSqlCoro(
        "SELECT id::text AS id,label,status,membership_role FROM ap_m1.list_my_families()");
    Json::Value body(Json::objectValue);
    body["items"] = Json::Value(Json::arrayValue);
    for (const auto& row : rows) {
      Json::Value family(Json::objectValue);
      family["id"] = row["id"].as<std::string>();
      family["label"] = row["label"].as<std::string>();
      family["status"] = row["status"].as<std::string>();
      family["membership_role"] = row["membership_role"].as<std::string>();
      body["items"].append(family);
    }
    rollback_quietly(trans);
    co_return m1_json_ok(body,rid);
  } catch (const drogon::orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "list_families SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    co_return response_for_sqlstate(e.sqlState(),rid);
  } catch (const drogon::orm::TimeoutError&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE","database deadline exceeded",rid,true);
  } catch (const drogon::orm::BrokenConnection&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  } catch (const std::exception&) {
    rollback_quietly(trans);
    co_return error_response("INTERNAL_ERROR","unexpected server error",rid);
  }
}

inline drogon::Task<drogon::HttpResponsePtr> get_child(
    drogon::HttpRequestPtr req, std::string child_param, ParentAuth auth) {
  const auto rid = request_id_of(req);
  auto child = normalize_uuid(child_param);
  if (!child) co_return error_response("INVALID_REQUEST","childId must be a UUID",rid);
  auto credential = parent_credential(auth, req);
  if (!credential) co_return error_response("UNAUTHENTICATED","missing or invalid parent credential",rid);
  if (!drogon::app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE","database not configured",rid,true);
  auto db = drogon::app().getDbClient(kDbClientName);
  std::shared_ptr<drogon::orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    auto bound = co_await bind_parent_principal(trans, *credential);
    if (!bound) {
      rollback_quietly(trans);
      co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);
    }
    // RLS children_r limits this to exact-child VIEW_CHILD_PROFILE.
    // Unknown and unauthorized children are deliberately indistinguishable.
    auto rows = co_await trans->execSqlCoro(
        "SELECT id::text AS id,family_id::text AS family_id,alias,state "
        "FROM ap_m1.children WHERE id=$1::uuid",*child);
    if (rows.empty()) {
      rollback_quietly(trans);
      co_return error_response("NOT_FOUND","child not found",rid);
    }
    Json::Value body(Json::objectValue);
    body["id"] = rows.at(0)["id"].as<std::string>();
    body["family_id"] = rows.at(0)["family_id"].as<std::string>();
    body["alias"] = rows.at(0)["alias"].as<std::string>();
    body["state"] = rows.at(0)["state"].as<std::string>();
    rollback_quietly(trans);
    co_return m1_json_ok(body,rid);
  } catch (const drogon::orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "get_child SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    co_return response_for_sqlstate(e.sqlState(),rid);
  } catch (const drogon::orm::TimeoutError&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE","database deadline exceeded",rid,true);
  } catch (const drogon::orm::BrokenConnection&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  } catch (const std::exception&) {
    rollback_quietly(trans);
    co_return error_response("INTERNAL_ERROR","unexpected server error",rid);
  }
}

inline drogon::Task<drogon::HttpResponsePtr> list_child_devices(
    drogon::HttpRequestPtr req, std::string child_param, ParentAuth auth) {
  const auto rid = request_id_of(req);
  auto child = normalize_uuid(child_param);
  if (!child) co_return error_response("INVALID_REQUEST","childId must be a UUID",rid);
  auto credential = parent_credential(auth, req);
  if (!credential) co_return error_response("UNAUTHENTICATED","missing or invalid parent credential",rid);
  if (!drogon::app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE","database not configured",rid,true);
  auto db = drogon::app().getDbClient(kDbClientName);
  std::shared_ptr<drogon::orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms),std::to_string(db_limits().statement_ms));
    auto bound = co_await bind_parent_principal(trans, *credential);
    if (!bound) {
      rollback_quietly(trans);
      co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);
    }
    // Separate authorization: VIEW_CHILD_DEVICES does not imply child profile
    // visibility. This helper checks current grants, consent and authority.
    auto allowed = co_await trans->execSqlCoro(
        "SELECT ap_m1.has_child_scope_v2($1::uuid,'VIEW_CHILD_DEVICES') AS ok",*child);
    if (allowed.empty() || !allowed.at(0)["ok"].as<bool>()) {
      rollback_quietly(trans);
      co_return error_response("NOT_FOUND","child not found",rid);
    }
    // devices_r RLS is the second gate. No key material or raw GPS returned.
    auto rows = co_await trans->execSqlCoro(
        "SELECT d.id::text AS id,d.child_id::text AS child_id,d.enrollment_state, "
        "COALESCE(s.device_mode,'UNKNOWN') AS device_mode, "
        "to_char(GREATEST(s.observed_at,h.observed_at) AT TIME ZONE 'UTC',"
        "'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS last_reported_at "
        "FROM ap_m1.devices d "
        "LEFT JOIN LATERAL (SELECT device_mode,observed_at "
        "FROM ap_m1.capability_snapshots WHERE device_id=d.id "
        "ORDER BY observed_at DESC,id DESC LIMIT 1) s ON true "
        "LEFT JOIN ap_m1.device_health h ON h.device_id=d.id "
        "WHERE d.child_id=$1::uuid ORDER BY d.id",*child);
    Json::Value body(Json::objectValue);
    body["items"] = Json::Value(Json::arrayValue);
    for (const auto& row : rows) {
      Json::Value device(Json::objectValue);
      device["id"] = row["id"].as<std::string>();
      device["child_id"] = row["child_id"].as<std::string>();
      device["device_mode"] = row["device_mode"].as<std::string>();
      device["enrollment_state"] = row["enrollment_state"].as<std::string>();
      if (row["last_reported_at"].isNull())
        device["last_reported_at"] = Json::nullValue;
      else
        device["last_reported_at"] = row["last_reported_at"].as<std::string>();
      body["items"].append(device);
    }
    rollback_quietly(trans);
    co_return m1_json_ok(body,rid);
  } catch (const drogon::orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "list_child_devices SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    co_return response_for_sqlstate(e.sqlState(),rid);
  } catch (const drogon::orm::TimeoutError&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE","database deadline exceeded",rid,true);
  } catch (const drogon::orm::BrokenConnection&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  } catch (const std::exception&) {
    rollback_quietly(trans);
    co_return error_response("INTERNAL_ERROR","unexpected server error",rid);
  }
}

} // namespace ma
