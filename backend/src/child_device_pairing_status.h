// Authenticated guardian view of the one verified active Alarka child device.
// Never send child device key bytes, bearer, IMEI or unused QR session secrets.
#pragma once
#include <memory>
#include <string>
#include <drogon/drogon.h>
#include "parent_session.h"
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"

namespace ma {
inline drogon::Task<drogon::HttpResponsePtr> child_pairing_status(
    drogon::HttpRequestPtr req,std::string child_param,ParentAuth auth) {
  using namespace drogon;
  const auto rid=request_id_of(req);
  const auto child=normalize_uuid(child_param);
  if(!child) co_return error_response("INVALID_REQUEST","childId must be a UUID",rid);
  if(!req->body().empty()||!req->getParameters().empty())
    co_return error_response("INVALID_REQUEST","unexpected request body or query",rid);
  if(auth.mode!=ParentAuthMode::V2Session)
    co_return error_response("SERVICE_UNAVAILABLE","trusted parent session required",rid,true);
  auto bearer=parent_credential(auth,req);
  if(!bearer) co_return error_response("UNAUTHENTICATED","verified parent session required",rid);
  if(!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  std::shared_ptr<orm::Transaction> tx;
  try {
    tx=co_await app().getDbClient(kDbClientName)->newTransactionCoro();
    co_await tx->execSqlCoro("SELECT set_config('lock_timeout',$1,true),"
        "set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms),std::to_string(db_limits().statement_ms));
    if(!(co_await bind_parent_principal(tx,*bearer))) {
      rollback_quietly(tx);
      co_return error_response("UNAUTHENTICATED","session revoked or expired",rid);
    }
    // Verify current exact-child scope and prevent cross-family ID probes.
    auto access=co_await tx->execSqlCoro(
      "SELECT 1 FROM ap_m1.children c WHERE c.id=$1::uuid "
      "AND ap_m1.has_child_scope_v2(c.id,'VIEW_CHILD_PROFILE') "
      "AND NOT ap_m1.child_deleted(c.id) LIMIT 1",*child);
    if(access.empty()) {
      rollback_quietly(tx);
      co_return error_response("NOT_FOUND","child not found",rid);
    }
    auto rows=co_await tx->execSqlCoro(
      "SELECT device_id::text AS device_id,manufacturer,model,android_api,app_version,method,"
      " to_char(paired_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS paired_at "
      "FROM ap_m1.child_active_device_summary($1::uuid)",*child);
    Json::Value body(Json::objectValue);
    body["child_id"]=*child;
    body["device"]=Json::nullValue;
    body["state"]="UNPAIRED";
    if(!rows.empty()) {
      const auto& r=rows.at(0);
      Json::Value d(Json::objectValue);
      d["device_id"]=r["device_id"].as<std::string>();
      d["manufacturer"]=r["manufacturer"].isNull()?"Unknown":r["manufacturer"].as<std::string>();
      d["model"]=r["model"].isNull()?"Unknown":r["model"].as<std::string>();
      d["android_api"]=r["android_api"].isNull()?Json::Value(Json::nullValue):
          Json::Value(r["android_api"].as<int>());
      d["app_version"]=r["app_version"].isNull()?"Unknown":r["app_version"].as<std::string>();
      d["pairing_method"]=r["method"].as<std::string>();
      d["paired_at"]=r["paired_at"].isNull()?Json::Value(Json::nullValue):
          Json::Value(r["paired_at"].as<std::string>());
      body["device"]=d;
      body["state"]="PAIRED";
    }
    rollback_quietly(tx);
    auto resp=HttpResponse::newHttpJsonResponse(body);
    resp->setStatusCode(k200OK);
    resp->addHeader(kRequestIdHeader,rid);
    add_no_store(resp);
    co_return resp;
  }catch(const orm::SqlError& e) {
    rollback_quietly(tx);
    co_return response_for_sqlstate(e.sqlState(),rid);
  }catch(const orm::TimeoutError&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE","database deadline exceeded",rid,true);
  }catch(const orm::BrokenConnection&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  }catch(const std::exception&) {
    rollback_quietly(tx);
    co_return error_response("INTERNAL_ERROR","pairing status could not be verified",rid);
  }
}
} // namespace ma
