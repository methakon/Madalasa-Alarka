// Admin applicant self-service read APIs. Cookie is a revocable database token,
// never a role claim supplied by the browser. No public admin list or child data.
#pragma once
#include <drogon/drogon.h>
#include <memory>
#include <string>
#include "admin_session.h"
#include "db_support.h"
#include "http_support.h"

namespace ma {

inline drogon::Task<drogon::HttpResponsePtr> admin_applicant_self_read(
    drogon::HttpRequestPtr req, bool request_status) {
  using namespace drogon;
  const auto rid=request_id_of(req);
  const auto token=admin_session_cookie(req);
  if (!token) co_return error_response("UNAUTHENTICATED","administrator session required",rid);
  if (!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  auto db=app().getDbClient(kDbClientName);
  std::shared_ptr<orm::Transaction> tx;
  try {
    tx=co_await db->newTransactionCoro();
    co_await tx->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms),std::to_string(db_limits().statement_ms));
    co_await tx->execSqlCoro("SELECT set_config('ap.admin_session_token',$1,true)",*token);

    // Resolve through the hashed session, revocation epoch and RLS only.
    auto account=co_await tx->execSqlCoro(
        "SELECT a.id::text AS admin_id,a.state AS account_state,"
        "ap_m1.admin_is_owner(a.id) AS is_owner,"
        "p.full_name AS full_name,p.contact_email AS contact_email,"
        "p.contact_verified_at IS NOT NULL AS email_verified,"
        "p.revision AS profile_revision,p.privacy_notice_version AS notice_version "
        "FROM ap_m1.admin_accounts a "
        "LEFT JOIN ap_m1.admin_profiles p ON p.admin_id=a.id "
        "WHERE a.id=ap_m1.ctx_admin()");
    if(account.empty()){
      rollback_quietly(tx);
      co_return error_response("UNAUTHENTICATED","administrator session invalid",rid);
    }
    const auto a=account.at(0);
    Json::Value result(Json::objectValue);

    if(request_status){
      // Only the invoking applicant's own most recent request.
      auto rows=co_await tx->execSqlCoro(
          "SELECT id::text AS id,admin_id::text AS applicant_id,state,revision,"
          "to_char(submitted_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS submitted_at,"
          "CASE WHEN decided_at IS NULL THEN NULL ELSE "
          "to_char(decided_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') END AS decided_at "
          "FROM ap_m1.admin_access_requests WHERE admin_id=ap_m1.ctx_admin() "
          "ORDER BY submitted_at DESC,id DESC LIMIT 1");
      if(rows.empty()){
        rollback_quietly(tx);
        co_return error_response("NOT_FOUND","no access request for this account",rid);
      }
      const auto row=rows.at(0);
      result["id"]=row["id"].as<std::string>();
      result["applicant_id"]=row["applicant_id"].as<std::string>();
      result["state"]=row["state"].as<std::string>();
      result["revision"]=Json::Int64(row["revision"].as<std::int64_t>());
      result["submitted_at"]=row["submitted_at"].as<std::string>();
      result["decided_at"]=row["decided_at"].isNull() ?
          Json::Value(Json::nullValue) : Json::Value(row["decided_at"].as<std::string>());
    }else{
      auto rows=co_await tx->execSqlCoro(
          "SELECT state FROM ap_m1.admin_access_requests "
          "WHERE admin_id=ap_m1.ctx_admin() ORDER BY submitted_at DESC,id DESC LIMIT 1");
      const std::string request_state=rows.empty() ? "" : rows.at(0)["state"].as<std::string>();
      const bool approved=a["account_state"].as<std::string>()=="ACTIVE";
      result["status"]=approved?"APPROVED":request_state=="PENDING_REVIEW"?
          "PENDING_REVIEW":request_state=="REJECTED"?"REJECTED":
          a["profile_revision"].isNull()?"NO_ACCESS":"PROFILE_DRAFT";
      result["full_name"]=a["full_name"].isNull()?
          Json::Value(Json::nullValue):Json::Value(a["full_name"].as<std::string>());
      result["contact_email"]=a["contact_email"].isNull()?
          Json::Value(Json::nullValue):Json::Value(a["contact_email"].as<std::string>());
      result["postal_address"]=Json::nullValue;  // minimized until documented need
      result["date_of_birth"]=Json::nullValue;
      result["gender"]=Json::nullValue;
      result["email_verified"]=a["email_verified"].as<bool>();
      result["profile_revision"]=a["profile_revision"].isNull()?
          Json::Value(Json::nullValue):Json::Value(Json::Int64(a["profile_revision"].as<std::int64_t>()));
      result["profile_complete"]=!a["profile_revision"].isNull() &&
          a["email_verified"].as<bool>();
      result["notice_version"]=a["notice_version"].isNull()?
          Json::Value(Json::nullValue):Json::Value(a["notice_version"].as<std::string>());
    }
    rollback_quietly(tx);
    auto response=HttpResponse::newHttpJsonResponse(result);
    response->setStatusCode(k200OK);
    response->addHeader(kRequestIdHeader,rid);
    response->addHeader("Cache-Control","private, no-store");
    co_return response;
  } catch(const orm::SqlError& e){
    rollback_quietly(tx);
    LOG_ERROR<<"admin_applicant_self_read SQLSTATE="<<e.sqlState()<<" request_id="<<rid;
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
