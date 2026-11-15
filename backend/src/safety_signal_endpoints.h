// Safety signal and SOS handlers:
// Device: POST /v1/devices/{deviceId}/signals
// Device: GET  /v1/devices/{deviceId}/signals/{eventId}/status
// Parent: GET  /v1/children/{childId}/signals
// Parent: POST /v1/children/{childId}/signals/{eventId}/ack
#pragma once
#include <string>
#include <string_view>
#include <optional>
#include <memory>

#include <drogon/drogon.h>

#include "crypto_support.h"
#include "db_support.h"
#include "device_auth.h"
#include "http_support.h"
#include "parent_session.h"
#include "validation.h"

namespace ma {

// Device handler: POST /v1/devices/{deviceId}/signals
inline drogon::Task<drogon::HttpResponsePtr> record_child_signal(
    drogon::HttpRequestPtr req, std::string device_id_param) {
  using namespace drogon;
  const std::string rid = request_id_of(req);

  if (req->body().size() > kMaxBodyBytes) {
    co_return error_response("PAYLOAD_TOO_LARGE", "request body too large", rid);
  }

  auto normalized_device = normalize_uuid(device_id_param);
  if (!normalized_device) {
    co_return error_response("INVALID_REQUEST", "deviceId must be a valid UUID", rid);
  }

  if (req->contentType() != CT_APPLICATION_JSON) {
    co_return error_response("INVALID_REQUEST", "content type must be application/json", rid);
  }

  Json::Value body;
  if (!parse_json_strict(req->body(), body)) {
    co_return error_response("INVALID_REQUEST", "malformed JSON", rid);
  }

  if (!body.isObject() || !body.isMember("event_id") || !body["event_id"].isString() ||
      !body.isMember("kind") || !body["kind"].isString() ||
      !body.isMember("observed_at") || !body["observed_at"].isString()) {
    co_return error_response("INVALID_REQUEST", "invalid signal payload shape", rid);
  }

  auto normalized_event = normalize_uuid(body["event_id"].asString());
  if (!normalized_event) {
    co_return error_response("INVALID_REQUEST", "event_id must be a valid UUID", rid);
  }

  const std::string kind = body["kind"].asString();
  if (kind != "SOS" && kind != "IM_SAFE" && kind != "PLEASE_CALL" && kind != "NEED_PICKUP") {
    co_return error_response("VALIDATION_FAILED", "unsupported signal kind", rid);
  }

  const std::string observed_at = body["observed_at"].asString();

  // Authentication
  auto device_principal = co_await authenticate_device(req);
  if (!device_principal) {
    co_return error_response("UNAUTHENTICATED", "credential missing, expired or device revoked", rid);
  }

  // Path matches credential device
  if (device_principal->device_id != *normalized_device) {
    co_return error_response("FORBIDDEN", "credential belongs to a different device than path", rid);
  }

  if (!app().hasDbClient(kDbClientName)) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }
  auto db = app().getDbClient(kDbClientName);

  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    if (!(co_await bind_device_transaction(trans, *device_principal))) {
      rollback_quietly(trans);
      co_return error_response("FORBIDDEN", "device transaction bind failed", rid);
    }

    auto rows = co_await trans->execSqlCoro(
        "SELECT ap_m1.record_child_signal($1::uuid, $2::uuid, $3::text, $4::timestamptz) AS event_id",
        *normalized_device, *normalized_event, kind, observed_at);

    if (rows.empty() || rows.at(0)["event_id"].isNull()) {
      rollback_quietly(trans);
      co_return error_response("INTERNAL_ERROR", "signal record failed", rid);
    }

    if (!(co_await commit(std::move(trans)))) {
      co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable", rid, true);
    }

    Json::Value resp(Json::objectValue);
    resp["event_id"] = *normalized_event;
    resp["stage"] = "SERVER_ACCEPTED";
    resp["kind"] = kind;

    auto http_resp = HttpResponse::newHttpJsonResponse(resp);
    http_resp->setStatusCode(k201Created);
    http_resp->addHeader(kRequestIdHeader, rid);
    add_no_store(http_resp);
    co_return http_resp;

  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "record_child_signal SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    if (e.sqlState() == "23505") { // Replay conflict
      co_return error_response("CONFLICT", "signal replay with mismatched payload", rid);
    }
    if (e.sqlState() == "22023") { // Invalid signal time
      co_return error_response("INVALID_REQUEST", "invalid or expired signal timestamp", rid);
    }
    if (e.sqlState() == "42501") {
      co_return error_response("FORBIDDEN", "device lacks authority or consent for signal", rid);
    }
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const orm::TimeoutError&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const orm::BrokenConnection&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    rollback_quietly(trans);
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

// Device handler: GET /v1/devices/{deviceId}/signals/{eventId}/status
inline drogon::Task<drogon::HttpResponsePtr> get_child_signal_status(
    drogon::HttpRequestPtr req, std::string device_id_param, std::string event_id_param) {
  using namespace drogon;
  const std::string rid = request_id_of(req);

  auto normalized_device = normalize_uuid(device_id_param);
  auto normalized_event = normalize_uuid(event_id_param);
  if (!normalized_device || !normalized_event) {
    co_return error_response("INVALID_REQUEST", "deviceId and eventId must be valid UUIDs", rid);
  }

  auto device_principal = co_await authenticate_device(req);
  if (!device_principal) {
    co_return error_response("UNAUTHENTICATED", "credential missing, expired or device revoked", rid);
  }
  if (device_principal->device_id != *normalized_device) {
    co_return error_response("FORBIDDEN", "credential belongs to a different device than path", rid);
  }

  if (!app().hasDbClient(kDbClientName)) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }
  auto db = app().getDbClient(kDbClientName);

  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    if (!(co_await bind_device_transaction(trans, *device_principal))) {
      rollback_quietly(trans);
      co_return error_response("FORBIDDEN", "device transaction bind failed", rid);
    }

    auto rows = co_await trans->execSqlCoro(
        "SELECT s.event_id::text AS event_id, s.kind, "
        "EXISTS(SELECT 1 FROM ap_m1.signal_acknowledgements a WHERE a.event_id = s.event_id) AS acknowledged, "
        "EXISTS(SELECT 1 FROM ap_m1.notification_deliveries d WHERE d.alert_id = e.id AND d.status = 'DELIVERY_CONFIRMED') AS delivered "
        "FROM ap_m1.child_signals s "
        "LEFT JOIN ap_m1.alert_events e ON e.signal_event_id = s.event_id "
        "WHERE s.event_id = $1::uuid AND s.device_id = $2::uuid",
        *normalized_event, *normalized_device);

    if (rows.empty()) {
      rollback_quietly(trans);
      co_return error_response("NOT_FOUND", "signal event not found for device", rid);
    }

    const bool ack = rows.at(0)["acknowledged"].as<bool>();
    const bool delivered = rows.at(0)["delivered"].as<bool>();
    const std::string stage = ack ? "GUARDIAN_ACKNOWLEDGED"
                                  : (delivered ? "NOTIFICATION_DELIVERED" : "SERVER_ACCEPTED");

    Json::Value resp(Json::objectValue);
    resp["event_id"] = *normalized_event;
    resp["stage"] = stage;
    resp["kind"] = rows.at(0)["kind"].as<std::string>();
    resp["guardian_acknowledged"] = ack;

    rollback_quietly(trans); // Read-only query

    auto http_resp = HttpResponse::newHttpJsonResponse(resp);
    http_resp->setStatusCode(k200OK);
    http_resp->addHeader(kRequestIdHeader, rid);
    add_no_store(http_resp);
    co_return http_resp;

  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const orm::TimeoutError&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const orm::BrokenConnection&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    rollback_quietly(trans);
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

// Guardian handler: GET /v1/children/{childId}/signals
inline drogon::Task<drogon::HttpResponsePtr> list_child_signals(
    drogon::HttpRequestPtr req, std::string child_id_param, ParentAuth auth) {
  using namespace drogon;
  const std::string rid = request_id_of(req);

  auto normalized_child = normalize_uuid(child_id_param);
  if (!normalized_child) {
    co_return error_response("INVALID_REQUEST", "childId must be a valid UUID", rid);
  }

  if (auth.mode != ParentAuthMode::V2Session) {
    co_return error_response("SERVICE_UNAVAILABLE", "signals API requires trusted parent sessions", rid);
  }
  auto credential = parent_credential(auth, req);
  if (!credential) {
    co_return unauthenticated_no_store("missing or invalid parent session", rid);
  }

  if (!app().hasDbClient(kDbClientName)) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }
  auto db = app().getDbClient(kDbClientName);

  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));

    auto principal_id = co_await bind_parent_principal(trans, *credential);
    if (!principal_id) {
      rollback_quietly(trans);
      co_return unauthenticated_no_store("invalid or expired parent session", rid);
    }

    auto scope_chk = co_await trans->execSqlCoro(
        "SELECT ap_m1.has_child_scope_v2($1::uuid, 'VIEW_ALERTS') AS allowed", *normalized_child);
    if (scope_chk.empty() || !scope_chk.at(0)["allowed"].as<bool>()) {
      rollback_quietly(trans);
      co_return error_response("FORBIDDEN", "parent lacks VIEW_ALERTS scope for child", rid);
    }

    auto rows = co_await trans->execSqlCoro(
        "SELECT e.id::text AS alert_id, s.event_id::text AS event_id, s.kind, "
        "to_char(s.observed_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS observed_at, "
        "EXISTS(SELECT 1 FROM ap_m1.signal_acknowledgements a WHERE a.event_id = s.event_id) AS acknowledged "
        "FROM ap_m1.alert_events e "
        "JOIN ap_m1.child_signals s ON s.event_id = e.signal_event_id "
        "WHERE e.child_id = $1::uuid "
        "ORDER BY s.observed_at DESC LIMIT 50",
        *normalized_child);

    Json::Value items(Json::arrayValue);
    for (const auto& row : rows) {
      Json::Value item(Json::objectValue);
      item["alert_id"] = row["alert_id"].as<std::string>();
      item["event_id"] = row["event_id"].as<std::string>();
      item["kind"] = row["kind"].as<std::string>();
      item["observed_at"] = row["observed_at"].as<std::string>();
      item["acknowledged"] = row["acknowledged"].as<bool>();
      items.append(item);
    }

    Json::Value resp(Json::objectValue);
    resp["child_id"] = *normalized_child;
    resp["signals"] = items;

    rollback_quietly(trans); // Read-only query

    auto http_resp = HttpResponse::newHttpJsonResponse(resp);
    http_resp->setStatusCode(k200OK);
    http_resp->addHeader(kRequestIdHeader, rid);
    add_no_store(http_resp);
    co_return http_resp;

  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const orm::TimeoutError&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const orm::BrokenConnection&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    rollback_quietly(trans);
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

// Guardian handler: POST /v1/children/{childId}/signals/{eventId}/ack
inline drogon::Task<drogon::HttpResponsePtr> acknowledge_child_signal(
    drogon::HttpRequestPtr req, std::string child_id_param, std::string event_id_param, ParentAuth auth) {
  using namespace drogon;
  const std::string rid = request_id_of(req);

  auto normalized_child = normalize_uuid(child_id_param);
  auto normalized_event = normalize_uuid(event_id_param);
  if (!normalized_child || !normalized_event) {
    co_return error_response("INVALID_REQUEST", "childId and eventId must be valid UUIDs", rid);
  }

  if (auth.mode != ParentAuthMode::V2Session) {
    co_return error_response("SERVICE_UNAVAILABLE", "signals API requires trusted parent sessions", rid);
  }
  auto credential = parent_credential(auth, req);
  if (!credential) {
    co_return unauthenticated_no_store("missing or invalid parent session", rid);
  }

  if (!app().hasDbClient(kDbClientName)) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }
  auto db = app().getDbClient(kDbClientName);

  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));

    auto principal_id = co_await bind_parent_principal(trans, *credential);
    if (!principal_id) {
      rollback_quietly(trans);
      co_return unauthenticated_no_store("invalid or expired parent session", rid);
    }

    co_await trans->execSqlCoro(
        "SELECT ap_m1.acknowledge_child_signal($1::uuid, $2::uuid)",
        *normalized_child, *normalized_event);

    if (!(co_await commit(std::move(trans)))) {
      co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable", rid, true);
    }

    Json::Value resp(Json::objectValue);
    resp["event_id"] = *normalized_event;
    resp["stage"] = "GUARDIAN_ACKNOWLEDGED";
    resp["acknowledged_by"] = *principal_id;

    auto http_resp = HttpResponse::newHttpJsonResponse(resp);
    http_resp->setStatusCode(k200OK);
    http_resp->addHeader(kRequestIdHeader, rid);
    add_no_store(http_resp);
    co_return http_resp;

  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "acknowledge_child_signal SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    if (e.sqlState() == "42501") {
      co_return error_response("FORBIDDEN", "parent lacks authority to acknowledge signal", rid);
    }
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const orm::TimeoutError&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const orm::BrokenConnection&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    rollback_quietly(trans);
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

} // namespace ma
