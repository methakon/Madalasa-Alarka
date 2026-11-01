// POST /v1/devices/{deviceId}/capabilities — frozen M1 DeviceBearer.
// Reported capabilities are untrusted device observations, never privilege.
#pragma once
#include <drogon/drogon.h>
#include <memory>
#include <string>
#include "capabilities_validation.h"
#include "db_support.h"
#include "device_auth.h"
#include "http_support.h"
#include "idempotency_key.h"

namespace ma {

inline drogon::Task<drogon::HttpResponsePtr> record_capabilities(
    drogon::HttpRequestPtr req, std::string device_param) {
  using namespace drogon;
  const auto rid = request_id_of(req);
  if (req->body().size() > kMaxBodyBytes)
    co_return error_response("PAYLOAD_TOO_LARGE","request body too large",rid);
  auto device_id = normalize_uuid(device_param);
  if (!device_id)
    co_return error_response("INVALID_REQUEST","deviceId must be a UUID",rid);
  if (req->contentType() != CT_APPLICATION_JSON)
    co_return error_response("INVALID_REQUEST","content type must be application/json",rid);
  Json::Value body;
  if (!parse_json_strict(req->body(),body))
    co_return error_response("INVALID_REQUEST","malformed JSON",rid);
  const auto validation = check_capability_body(body);
  if (validation == CapabilityCheck::Malformed)
    co_return error_response("INVALID_REQUEST","invalid capabilities payload",rid);
  auto principal = co_await authenticate_device(req);
  if (!principal)
    co_return error_response("UNAUTHENTICATED","device credential missing or invalid",rid);
  if (principal->device_id != *device_id)
    co_return error_response("FORBIDDEN","credential belongs to another device",rid);
  if (validation != CapabilityCheck::Ok)
    co_return error_response("VALIDATION_FAILED","unsupported capabilities value",rid);
  if (!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE","database not configured",rid,true);
  auto db = app().getDbClient(kDbClientName);
  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms),std::to_string(db_limits().statement_ms));
    co_await trans->execSqlCoro("SELECT set_config('ap.device_id',$1,true)",*device_id);
    // INSERT policy owns_active_device checks live credential-bound device.
    // No direct caller-controlled isDeviceOwner grant is ever trusted.
    const auto res = co_await trans->execSqlCoro(
        "INSERT INTO ap_m1.capability_snapshots "
        "(device_id,observed_at,android_api,device_mode,is_device_owner,features) "
        "VALUES ($1::uuid,$2::timestamptz,$3::integer,$4,$5::boolean,$6::jsonb) "
        "RETURNING id::text AS id, "
        "to_char(received_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS recorded_at",
        *device_id,body["observed_at"].asString(),body["android_api"].asInt(),
        body["device_mode"].asString(),body["is_device_owner"].asBool(),
        canonical_json(capability_feature_json(body)));
    if (res.empty()) {
      rollback_quietly(trans);
      co_return error_response("INTERNAL_ERROR","missing database receipt",rid);
    }
    Json::Value receipt(Json::objectValue);
    receipt["id"] = res.at(0)["id"].as<std::string>();
    receipt["state"] = "ACCEPTED";
    receipt["recorded_at"] = res.at(0)["recorded_at"].as<std::string>();
    if (!(co_await commit(std::move(trans))))
      co_return error_response("SERVICE_UNAVAILABLE","database commit unavailable",rid,true);
    auto resp = HttpResponse::newHttpJsonResponse(receipt);
    resp->setStatusCode(k202Accepted);
    resp->addHeader(kRequestIdHeader,rid);
    co_return resp;
  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "record_capabilities SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    co_return response_for_sqlstate(e.sqlState(),rid);
  } catch (const orm::TimeoutError&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE","database deadline exceeded",rid,true);
  } catch (const orm::BrokenConnection&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  } catch (const std::exception&) {
    rollback_quietly(trans);
    co_return error_response("INTERNAL_ERROR","unexpected server error",rid);
  }
}

} // namespace ma
