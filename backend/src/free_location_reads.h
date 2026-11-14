// Free-first, parent-session child-scoped location reads.
// RLS and consent are authoritative; this HTTP layer additionally fixes the
// visible window to 6 hours regardless of stored paid entitlements.
#pragma once
#include <memory>
#include <optional>
#include <string>
#include <drogon/drogon.h>
#include "parent_session.h"
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"

namespace ma {

inline drogon::Task<drogon::HttpResponsePtr> free_location_read(
    drogon::HttpRequestPtr req, std::string child_param, ParentAuth auth, bool history) {
  using namespace drogon;
  const auto rid=request_id_of(req);
  if (!req->body().empty())
    co_return error_response("INVALID_REQUEST","GET body must be empty",rid);
  auto child=normalize_uuid(child_param);
  if (!child) co_return error_response("INVALID_REQUEST","childId must be a UUID",rid);
  // No client-supplied time range can ever expand the free-history window.
  if (!req->getParameters().empty())
    co_return error_response("INVALID_REQUEST","free location reads do not accept query parameters",rid);
  if(auth.mode!=ParentAuthMode::V2Session)
    co_return error_response("SERVICE_UNAVAILABLE","trusted parent session required",rid,true);
  auto credential=parent_credential(auth,req);
  if(!credential)
    co_return error_response("UNAUTHENTICATED","verified parent session required",rid);
  if(!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE","database not configured",rid,true);
  auto db=app().getDbClient(kDbClientName);
  std::shared_ptr<orm::Transaction> tx;
  try {
    tx=co_await db->newTransactionCoro();
    co_await tx->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms),std::to_string(db_limits().statement_ms));
    if(!(co_await bind_parent_principal(tx,*credential))) {
      rollback_quietly(tx);
      co_return error_response("UNAUTHENTICATED","session expired or revoked",rid);
    }
    const std::string scope=history ? "VIEW_HISTORY" : "VIEW_LOCATION";
    // The children table is RLS protected. Unknown children and missing
    // grants/consent are indistinguishable to prevent IDOR/probing.
    auto access=co_await tx->execSqlCoro(
        "SELECT 1 FROM ap_m1.children c WHERE c.id=$1::uuid "
        "AND ap_m1.has_child_scope_v2(c.id,$2) "
        "AND ap_m1.has_consent(c.id,'LOCATION') "
        "AND NOT ap_m1.child_deleted(c.id) LIMIT 1", *child,scope);
    if(access.empty()) {
      rollback_quietly(tx);
      co_return error_response("NOT_FOUND","child not found",rid);
    }

    // Direct table scan retains RLS; the explicit WHERE prevents older
    // paid/trial rows from leaking under any feature-flag configuration.
    // LIMIT $2::int is required: the driver binds a C++ int as a 4-byte binary
    // int4, so an uncast LIMIT parameter (inferred bigint) fails protocol
    // decoding with SQLSTATE 08P01 and every read answers 503.
    const std::string sql=
       "SELECT o.device_id::text AS device_id, o.event_id::text AS event_id,"
       " (extract(epoch from o.observed_at)*1000)::bigint AS observed_ms,"
       " (extract(epoch from o.received_at)*1000)::bigint AS ingested_ms,"
       " o.latitude,o.longitude,o.accuracy_m,o.quality "
       "FROM ap_m1.location_observations o WHERE o.child_id=$1::uuid "
       "AND o.observed_at>=statement_timestamp()-interval '6 hours' "
       "AND o.observed_at<=statement_timestamp() AND o.quality='QUALIFIED' "
       "ORDER BY o.observed_at DESC, o.event_id DESC LIMIT $2::int";
    const int pageLimit=history ? 200 : 1;
    auto rows=co_await tx->execSqlCoro(sql,*child,pageLimit);
    Json::Value out(Json::objectValue);
    out["child_id"]=*child;
    out["history_window_hours"]=6;
    out["server_verified"]=true;
    if(history) {
      out["items"]=Json::Value(Json::arrayValue);
      for(const auto& row:rows) {
        Json::Value item(Json::objectValue);
        item["event_id"]=row["event_id"].as<std::string>();
        item["source_device_id"]=row["device_id"].as<std::string>();
        item["observed_at_epoch_ms"]=static_cast<Json::Int64>(row["observed_ms"].as<long long>());
        item["ingested_at_epoch_ms"]=static_cast<Json::Int64>(row["ingested_ms"].as<long long>());
        item["latitude_e6"]=static_cast<int>(row["latitude"].as<double>()*1000000);
        item["longitude_e6"]=static_cast<int>(row["longitude"].as<double>()*1000000);
        item["accuracy_meters"]=row["accuracy_m"].as<double>();
        out["items"].append(item);
      }
      out["has_more"]=rows.size()==static_cast<std::size_t>(pageLimit);
    } else {
      out["location"]=Json::Value(Json::nullValue);
      out["state"]="UNAVAILABLE";
      if(!rows.empty()) {
        const auto& row=rows.at(0);
        Json::Value item(Json::objectValue);
        item["source_device_id"]=row["device_id"].as<std::string>();
        item["observed_at_epoch_ms"]=static_cast<Json::Int64>(row["observed_ms"].as<long long>());
        item["ingested_at_epoch_ms"]=static_cast<Json::Int64>(row["ingested_ms"].as<long long>());
        item["latitude_e6"]=static_cast<int>(row["latitude"].as<double>()*1000000);
        item["longitude_e6"]=static_cast<int>(row["longitude"].as<double>()*1000000);
        item["accuracy_meters"]=row["accuracy_m"].as<double>();
        out["location"]=item;
        out["state"]="LAST_KNOWN";
      }
    }
    rollback_quietly(tx);
    auto resp=HttpResponse::newHttpJsonResponse(out);
    resp->setStatusCode(k200OK);
    resp->addHeader(kRequestIdHeader,rid);
    add_no_store(resp);
    co_return resp;
  } catch(const orm::SqlError& e) {
    rollback_quietly(tx);
    LOG_ERROR<<"free location SQLSTATE="<<e.sqlState()<<" request_id="<<rid;
    co_return response_for_sqlstate(e.sqlState(),rid);
  } catch(const orm::TimeoutError&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE","database deadline exceeded",rid,true);
  } catch(const orm::BrokenConnection&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  } catch(const std::exception&) {
    rollback_quietly(tx);
    co_return error_response("INTERNAL_ERROR","free location read failed",rid);
  }
}
} // namespace ma
