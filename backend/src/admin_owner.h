// Owner-only admin access request queue (BO-04).
// Database OWNER_MANAGE permission includes MFA step-up and verified owner
// issuer+subject allowlisting. No endpoint for staff to self-approve.
#pragma once
#include <drogon/drogon.h>
#include <memory>
#include <string>
#include "admin_session.h"
#include "db_support.h"
#include "http_support.h"

namespace ma {
inline drogon::Task<drogon::HttpResponsePtr> admin_owner_access_requests(
    drogon::HttpRequestPtr req) {
  using namespace drogon;
  const auto rid=request_id_of(req);
  const auto token=admin_session_cookie(req->getHeader("cookie"));
  if(!token) co_return error_response("UNAUTHENTICATED","administrator session required",rid);
  if(!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  auto db=app().getDbClient(kDbClientName);
  std::shared_ptr<orm::Transaction> tx;
  try {
    tx=co_await db->newTransactionCoro();
    co_await tx->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms),std::to_string(db_limits().statement_ms));
    co_await tx->execSqlCoro("SELECT set_config('ap.admin_session_token',$1,true)",*token);
    auto access=co_await tx->execSqlCoro(
        "SELECT ap_m1.has_admin_permission('OWNER_MANAGE') AS step_up,"
        "ap_m1.admin_is_owner(ap_m1.ctx_admin()) AS owner");
    if(access.empty() || !access.at(0)["step_up"].as<bool>() ||
        !access.at(0)["owner"].as<bool>()) {
      rollback_quietly(tx);
      co_return error_response("FORBIDDEN","verified owner MFA required",rid);
    }
    // Owner-only read; account/profile metadata is never accessible to a
    // normal SUPPORT_AGENT/FAQ_EDITOR from this endpoint.
    auto rows=co_await tx->execSqlCoro(
        "SELECT r.id::text AS id,r.admin_id::text AS applicant_id,r.state,r.revision,"
        "to_char(r.submitted_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS submitted_at,"
        "p.full_name AS full_name,p.contact_email AS contact_email "
        "FROM ap_m1.admin_access_requests r "
        "LEFT JOIN ap_m1.admin_profiles p ON p.admin_id=r.admin_id "
        "WHERE r.state='PENDING_REVIEW' ORDER BY r.submitted_at ASC,r.id ASC LIMIT 50");
    Json::Value output(Json::objectValue);
    output["items"]=Json::Value(Json::arrayValue);
    output["next_cursor"]=Json::nullValue;
    for(const auto& row:rows) {
      Json::Value item(Json::objectValue);
      item["id"]=row["id"].as<std::string>();
      item["applicant_id"]=row["applicant_id"].as<std::string>();
      item["state"]=row["state"].as<std::string>();
      item["revision"]=Json::Int64(row["revision"].as<std::int64_t>());
      item["submitted_at"]=row["submitted_at"].as<std::string>();
      Json::Value profile(Json::objectValue);
      if(!row["full_name"].isNull()) profile["full_name"]=row["full_name"].as<std::string>();
      if(!row["contact_email"].isNull()) profile["contact_email"]=row["contact_email"].as<std::string>();
      item["profile"]=profile;
      output["items"].append(item);
    }
    rollback_quietly(tx);
    auto response=HttpResponse::newHttpJsonResponse(output);
    response->setStatusCode(k200OK);
    response->addHeader(kRequestIdHeader,rid);
    response->addHeader("Cache-Control","private, no-store");
    co_return response;
  } catch(const orm::SqlError& e){
    rollback_quietly(tx);
    LOG_ERROR<<"admin_owner_access_requests SQLSTATE="<<e.sqlState()<<" request_id="<<rid;
    co_return response_for_sqlstate(e.sqlState(),rid);
  } catch(const orm::TimeoutError&){
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE","database deadline exceeded",rid,true);
  } catch(const orm::BrokenConnection&){
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  } catch(const std::exception&){
    rollback_quietly(tx);
    co_return error_response("INTERNAL_ERROR","unexpected server error",rid);
  }
}
} // namespace ma
