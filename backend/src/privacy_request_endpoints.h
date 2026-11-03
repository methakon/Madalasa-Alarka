// Authenticated, child-scoped privacy request endpoints. The existing V2 SQL
// functions own authority checks, immutable tombstones and job transitions.
// A queued job is NEVER presented as completed deletion or a ready export.
#pragma once
#include <memory>
#include <optional>
#include <string>
#include <drogon/drogon.h>
#include "parent_session.h"
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"
#include "privacy_endpoints.h"

namespace ma {

inline drogon::HttpResponsePtr privacy_pending(const Json::Value& body,
                                                const std::string& request_id) {
  auto out=drogon::HttpResponse::newHttpJsonResponse(body);
  out->setStatusCode(drogon::k202Accepted);
  out->addHeader(kRequestIdHeader,request_id);
  add_no_store(out);
  return out;
}

inline drogon::Task<drogon::HttpResponsePtr> child_privacy_job(
    drogon::HttpRequestPtr req, std::string child_id, ParentAuth auth,
    bool erasure, bool create) {
  using namespace drogon;
  const auto rid=request_id_of(req);
  const auto child=normalize_uuid(child_id);
  if(!child) co_return error_response("INVALID_REQUEST","childId must be a UUID",rid);
  if(auth.mode!=ParentAuthMode::V2Session)
    co_return error_response("SERVICE_UNAVAILABLE","privacy actions require a trusted parent session",rid);
  auto credential=parent_credential(auth,req);
  if(!credential) co_return unauthenticated_no_store("invalid parent session",rid);
  std::optional<std::string> key;
  std::optional<std::string> policy;
  if(create) {
    if(req->body().size()>1024)
      co_return error_response("PAYLOAD_TOO_LARGE","privacy request body too large",rid);
    Json::Value body;
    if(!parse_json_strict(req->body(),body) || !body.isObject() || body.size()!=1)
      co_return error_response("INVALID_REQUEST","expected one privacy request field",rid);
    if(erasure){
      if(!body["confirm_child_erasure"].isBool() || !body["confirm_child_erasure"].asBool())
        co_return error_response("VALIDATION_FAILED","explicit deletion acknowledgement required",rid);
      key=normalize_uuid(req->getHeader("idempotency-key"));
      if(!key) co_return error_response("INVALID_REQUEST","Idempotency-Key must be a UUID",rid);
    }else{
      if(!body["approved_policy_id"].isString())
        co_return error_response("VALIDATION_FAILED","approved_policy_id required",rid);
      policy=normalize_uuid(body["approved_policy_id"].asString());
      if(!policy) co_return error_response("VALIDATION_FAILED","approved_policy_id must be UUID",rid);
    }
  }else if(!req->body().empty()) {
    co_return error_response("INVALID_REQUEST","GET requires empty body",rid);
  }
  if(!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE","database not configured",rid,true);
  auto db=app().getDbClient(kDbClientName);
  std::shared_ptr<orm::Transaction> tx;
  try {
    tx=co_await db->newTransactionCoro();
    co_await tx->execSqlCoro("SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
            std::to_string(db_limits().lock_ms),std::to_string(db_limits().statement_ms));
    if(!(co_await bind_parent_principal(tx,*credential))){
      rollback_quietly(tx);
      co_return unauthenticated_no_store("expired or revoked parent session",rid);
    }
    if(create){
      auto rows=erasure
          ? co_await tx->execSqlCoro(
                "SELECT ap_m1.request_child_erasure($1::uuid,$2::uuid)::text AS id",*child,*key)
          : co_await tx->execSqlCoro(
                "SELECT ap_m1.request_child_export($1::uuid,$2::uuid)::text AS id",*child,*policy);
      if(rows.empty()) {rollback_quietly(tx);co_return error_response("INTERNAL_ERROR","request was not recorded",rid);}
      const std::string job_id=rows.at(0)["id"].as<std::string>();
      Json::Value result(Json::objectValue);
      result["request_id"]=job_id;
      result["child_id"]=*child;
      result["kind"]=erasure?"ERASURE":"EXPORT";
      result["completed"]=false;
      result["message"]=erasure?
          "Request recorded; primary deletion and external/backup verification are separate.":
          "Export request recorded; no personal data is available until an authorized worker completes it.";
      if(!(co_await commit(std::move(tx))))
        co_return error_response("SERVICE_UNAVAILABLE","privacy request commit failed",rid,true);
      co_return privacy_pending(result,rid);
    }
    // RLS restricts status to the requesting parent, independent of family membership.
    const std::string sql=erasure
      ? "SELECT id::text AS id,state,received_at AS requested_at FROM ap_m1.account_deletion_requests "
        "WHERE child_id=$1::uuid AND requested_by=ap_m1.ctx_principal() ORDER BY received_at DESC,id LIMIT 50"
      : "SELECT id::text AS id,state,requested_at FROM ap_m1.export_jobs "
        "WHERE child_id=$1::uuid AND requester_id=ap_m1.ctx_principal() ORDER BY requested_at DESC,id LIMIT 50";
    auto rows=co_await tx->execSqlCoro(sql,*child);
    Json::Value result(Json::objectValue);
    result["child_id"]=*child;
    result["items"]=Json::Value(Json::arrayValue);
    for(const auto& row:rows){
      Json::Value item(Json::objectValue);
      item["request_id"]=row["id"].as<std::string>();
      item["state"]=row["state"].as<std::string>();
      item["requested_at"]=row["requested_at"].as<std::string>();
      result["items"].append(item);
    }
    rollback_quietly(tx);
    auto resp=HttpResponse::newHttpJsonResponse(result);
    resp->setStatusCode(k200OK);resp->addHeader(kRequestIdHeader,rid);add_no_store(resp);
    co_return resp;
  }catch(const orm::SqlError& e){
    rollback_quietly(tx);
    LOG_ERROR<<"privacy job SQLSTATE="<<e.sqlState()<<" request_id="<<rid;
    if(e.sqlState()=="42501")co_return privacy_not_found(rid);
    co_return response_for_sqlstate(e.sqlState(),rid);
  }catch(const orm::TimeoutError&){
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE","privacy database deadline exceeded",rid,true);
  }catch(const orm::BrokenConnection&){
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE","privacy database unavailable",rid,true);
  }catch(const std::exception&){
    rollback_quietly(tx);
    co_return error_response("INTERNAL_ERROR","privacy operation failed",rid);
  }
}
} // namespace ma
