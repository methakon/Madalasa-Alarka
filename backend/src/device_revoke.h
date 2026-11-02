// DELETE /v1/devices/{deviceId}/pairing — M1 revokeDevice.
// ParentOIDC identifies the caller. Actual authorization is in V2 RLS and
// ap_m1.revoke_domain_device (also revokes device key and pending commands).
// Conservative interim limitation: requires VIEW_CHILD_DEVICES in addition
// to REVOKE_CHILD_DEVICE, to resolve device -> child without bypassing RLS.
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

inline drogon::HttpResponsePtr revoked_no_content(const std::string& rid) {
  auto response = drogon::HttpResponse::newHttpResponse();
  response->setStatusCode(static_cast<drogon::HttpStatusCode>(204));
  response->addHeader(kRequestIdHeader,rid);
  return response;
}

inline drogon::Task<drogon::HttpResponsePtr> revoke_device(
    drogon::HttpRequestPtr req, std::string device_param, ParentAuth auth) {
  using namespace drogon;
  const auto rid = request_id_of(req);
  auto device = normalize_uuid(device_param);
  if (!device) co_return error_response("INVALID_REQUEST","deviceId must be a UUID",rid);
  auto credential = parent_credential(auth, req);
  if (!credential) co_return error_response("UNAUTHENTICATED","missing or invalid parent credential",rid);
  if (!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE","database not configured",rid,true);
  auto db = app().getDbClient(kDbClientName);
  std::shared_ptr<orm::Transaction> trans;
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
    // RLS visible only to a principal with exact-child VIEW_CHILD_DEVICES.
    // No device/custody information is returned on a missing RLS grant.
    // Serialize repeat/concurrent DELETE without requiring direct UPDATE
    // privilege on devices (revoked from ap_m1_api in V2). The domain
    // SECURITY DEFINER mutator acquires its own device row lock.
    co_await trans->execSqlCoro(
        "SELECT pg_advisory_xact_lock(hashtextextended('ma.m1.revoke.device:' || $1,0))",
        *device);
    auto visible = co_await trans->execSqlCoro(
        "SELECT child_id::text AS child_id,family_id::text AS family_id,enrollment_state "
        "FROM ap_m1.devices WHERE id=$1::uuid",*device);
    if (visible.empty()) {
      rollback_quietly(trans);
      co_return error_response("NOT_FOUND","device not found",rid);
    }
    const std::string child = visible.at(0)["child_id"].as<std::string>();
    const std::string family = visible.at(0)["family_id"].as<std::string>();
    co_await trans->execSqlCoro("SELECT set_config('ap.family_id',$1,true)",family);
    auto grant = co_await trans->execSqlCoro(
        "SELECT ap_m1.has_child_scope_v2($1::uuid,'REVOKE_CHILD_DEVICE') AS allowed",
        child);
    if (grant.empty() || !grant.at(0)["allowed"].as<bool>()) {
      rollback_quietly(trans);
      co_return error_response("FORBIDDEN","device revocation not authorized",rid);
    }
    // Repeated DELETE is naturally idempotent. No duplicate reenrollment audit
    // event is issued once a device has already been revoked.
    if (visible.at(0)["enrollment_state"].as<std::string>() != "REVOKED") {
      auto revoked = co_await trans->execSqlCoro(
          "SELECT ap_m1.revoke_domain_device($1::uuid,$2::uuid,NULL::uuid)::text AS event_id",
          child,*device);
      if (revoked.empty()) {
        rollback_quietly(trans);
        co_return error_response("INTERNAL_ERROR","revocation result missing",rid);
      }
    }
    if (!(co_await commit(std::move(trans))))
      co_return error_response("SERVICE_UNAVAILABLE","database commit unavailable",rid,true);
    co_return revoked_no_content(rid);
  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "revoke_device SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    if (e.sqlState()=="42501")
      co_return error_response("FORBIDDEN","device revocation forbidden",rid);
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
