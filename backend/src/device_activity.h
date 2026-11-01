// Device activity handlers: POST /v1/devices/{deviceId}/health and
// POST /v1/devices/{deviceId}/locations:batch.
// Requires authenticated device principal (DeviceBearer).
#pragma once
#include <optional>
#include <string>

#include <drogon/drogon.h>

#include "crypto_support.h"
#include "db_support.h"
#include "device_auth.h"
#include "http_support.h"
#include "idempotency_key.h"
#include "validation.h"

namespace ma {

// Handler for POST /v1/devices/{deviceId}/health
inline drogon::Task<drogon::HttpResponsePtr> record_device_health(
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

  if (!body.isObject() || !body.isMember("observed_at") || !body["observed_at"].isString() ||
      !body.isMember("charging") || !body["charging"].isBool() ||
      !body.isMember("permission_revision") || !body["permission_revision"].isInt()) {
    co_return error_response("INVALID_REQUEST", "invalid health payload shape", rid);
  }

  // battery_percent: integer 0..100 or null
  int battery_percent = -1;
  bool battery_null = false;
  if (body.isMember("battery_percent")) {
    if (body["battery_percent"].isNull()) {
      battery_null = true;
    } else if (body["battery_percent"].isInt()) {
      battery_percent = body["battery_percent"].asInt();
      if (battery_percent < 0 || battery_percent > 100) {
        co_return error_response("VALIDATION_FAILED", "battery_percent out of range", rid);
      }
    } else {
      co_return error_response("INVALID_REQUEST", "battery_percent must be an integer or null", rid);
    }
  } else {
    battery_null = true;
  }

  const int perm_rev = body["permission_revision"].asInt();
  if (perm_rev < 0) {
    co_return error_response("VALIDATION_FAILED", "permission_revision must be >= 0", rid);
  }

  const std::string observed_at = body["observed_at"].asString();
  const bool charging = body["charging"].asBool();

  // Authentication
  auto device_principal = co_await authenticate_device(req);
  if (!device_principal) {
    co_return error_response("UNAUTHENTICATED", "credential missing, expired or device revoked", rid);
  }

  // 403: device ID in path must match credential's device
  if (device_principal->device_id != *normalized_device) {
    co_return error_response("FORBIDDEN", "credential belongs to a different device than path", rid);
  }

  if (!app().hasDbClient(kDbClientName)) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }
  auto db = app().getDbClient(kDbClientName);
  if (!db) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }

  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));

    co_await trans->execSqlCoro("SELECT set_config('ap.device_id', $1, true)", *normalized_device);

    std::string recorded_at;
    if (battery_null) {
      auto stored = co_await trans->execSqlCoro(
          "INSERT INTO ap_m1.device_health(device_id, observed_at, battery_percent, charging, permission_revision) "
          "VALUES($1::uuid, $2::timestamptz, NULL, $3::boolean, $4::integer) "
          "ON CONFLICT(device_id) DO UPDATE SET observed_at=EXCLUDED.observed_at, recorded_at=clock_timestamp(), "
          "battery_percent=NULL, charging=EXCLUDED.charging, permission_revision=EXCLUDED.permission_revision "
          "RETURNING to_char(recorded_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS recorded_at",
          *normalized_device, observed_at, charging, perm_rev);
      if (stored.empty()) {
        rollback_quietly(trans);
        co_return error_response("INTERNAL_ERROR","missing device-health database receipt",rid);
      }
      recorded_at = stored.at(0)["recorded_at"].as<std::string>();
    } else {
      auto stored = co_await trans->execSqlCoro(
          "INSERT INTO ap_m1.device_health(device_id, observed_at, battery_percent, charging, permission_revision) "
          "VALUES($1::uuid, $2::timestamptz, $3::integer, $4::boolean, $5::integer) "
          "ON CONFLICT(device_id) DO UPDATE SET observed_at=EXCLUDED.observed_at, recorded_at=clock_timestamp(), "
          "battery_percent=EXCLUDED.battery_percent, charging=EXCLUDED.charging, permission_revision=EXCLUDED.permission_revision "
          "RETURNING to_char(recorded_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS recorded_at",
          *normalized_device, observed_at, battery_percent, charging, perm_rev);
      if (stored.empty()) {
        rollback_quietly(trans);
        co_return error_response("INTERNAL_ERROR","missing device-health database receipt",rid);
      }
      recorded_at = stored.at(0)["recorded_at"].as<std::string>();
    }
    // The M1 frozen response is Receipt {id,state,recorded_at}, NOT a
    // location-batch receipt. Correlation id is the server-generated UUID.
    Json::Value receipt(Json::objectValue);
    receipt["id"] = rid;
    receipt["state"] = "ACCEPTED";
    receipt["recorded_at"] = recorded_at;

    if (!(co_await commit(std::move(trans))))
      co_return error_response("SERVICE_UNAVAILABLE","database commit unavailable; retry request",rid,true);
    auto resp = drogon::HttpResponse::newHttpJsonResponse(receipt);
    resp->setStatusCode(drogon::k202Accepted);
    resp->addHeader(kRequestIdHeader,rid);
    co_return resp;

  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "sql error state=" << e.sqlState() << " request_id=" << rid;
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

// Handler for POST /v1/devices/{deviceId}/locations:batch
inline drogon::Task<drogon::HttpResponsePtr> ingest_location_batch(
    drogon::HttpRequestPtr req, std::string device_id_param) {
  using namespace drogon;
  const std::string rid = request_id_of(req);

  // Allow up to 512 KiB for location batch uploads (500 events)
  constexpr std::size_t kMaxLocationBatchBytes = 512 * 1024;
  if (req->body().size() > kMaxLocationBatchBytes) {
    co_return error_response("PAYLOAD_TOO_LARGE", "batch payload too large", rid);
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

  if (!body.isObject() || !body.isMember("batch_id") || !body["batch_id"].isString() ||
      !body.isMember("events") || !body["events"].isArray()) {
    co_return error_response("INVALID_REQUEST", "invalid batch payload shape", rid);
  }

  auto normalized_batch = normalize_uuid(body["batch_id"].asString());
  if (!normalized_batch) {
    co_return error_response("INVALID_REQUEST", "batch_id must be a UUID", rid);
  }

  const auto& events = body["events"];
  if (events.empty() || events.size() > 500) {
    co_return error_response("VALIDATION_FAILED", "events count must be between 1 and 500", rid);
  }

  // Authentication
  auto device_principal = co_await authenticate_device(req);
  if (!device_principal) {
    co_return error_response("UNAUTHENTICATED", "credential missing, expired or device revoked", rid);
  }

  // 403: path device must match credential device
  if (device_principal->device_id != *normalized_device) {
    co_return error_response("FORBIDDEN", "credential belongs to a different device than path", rid);
  }

  if (!app().hasDbClient(kDbClientName)) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }
  auto db = app().getDbClient(kDbClientName);
  if (!db) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }

  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));

    co_await trans->execSqlCoro("SELECT set_config('ap.device_id', $1, true)", *normalized_device);

    const std::string events_json = canonical_json(events);
    auto res = co_await trans->execSqlCoro(
        "SELECT ap_m1.ingest_location_batch($1::uuid, $2::uuid, $3::jsonb)::text AS batch_id",
        *normalized_device, *normalized_batch, events_json);

    if (res.empty() || res.at(0)["batch_id"].isNull()) {
      rollback_quietly(trans);
      co_return error_response("VALIDATION_FAILED", "batch ingestion refused", rid);
    }

    if (!(co_await commit(std::move(trans)))) {
      co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable; retry request", rid, true);
    }

    Json::Value receipt;
    receipt["batch_id"] = *normalized_batch;
    receipt["accepted_count"] = static_cast<Json::UInt>(events.size());
    receipt["duplicate_count"] = 0;
    receipt["rejected_count"] = 0;
    receipt["processing"] = "QUEUED";
    receipt["durable_stage"] = "INBOX_COMMITTED";

    auto resp = drogon::HttpResponse::newHttpJsonResponse(receipt);
    resp->setStatusCode(drogon::k202Accepted);
    resp->addHeader(kRequestIdHeader, rid);
    co_return resp;

  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "sql error state=" << e.sqlState() << " request_id=" << rid;
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

}  // namespace ma
