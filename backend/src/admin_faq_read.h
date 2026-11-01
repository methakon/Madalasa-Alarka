// Read-only FAQ endpoints. Public returns PUBLISHED revision only;
// admin drafts require a revocable session and server-side FAQ_EDIT permission.
// Publishing mutations are deliberately not added before CSRF/MFA integration.
#pragma once
#include <drogon/drogon.h>
#include <memory>
#include <optional>
#include <string>
#include "admin_session.h"
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"

namespace ma {
inline drogon::Task<drogon::HttpResponsePtr> read_faqs(
    drogon::HttpRequestPtr req, bool admin_mode,
    std::optional<std::string> faq_id = std::nullopt) {
  using namespace drogon;
  const auto rid=request_id_of(req);
  if(faq_id) {
    faq_id=normalize_uuid(*faq_id);
    if(!faq_id) co_return error_response("INVALID_REQUEST","faqId must be UUID",rid);
  }
  auto token = admin_mode ? admin_session_cookie(req->getHeader("cookie")) : std::nullopt;
  if(admin_mode && !token)
    co_return error_response("UNAUTHENTICATED","administrator session required",rid);
  if(!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE","database unavailable",rid,true);
  auto db=app().getDbClient(kDbClientName);
  std::shared_ptr<orm::Transaction> tx;
  try {
    tx=co_await db->newTransactionCoro();
    co_await tx->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms),std::to_string(db_limits().statement_ms));
    if(admin_mode) {
      co_await tx->execSqlCoro(
          "SELECT set_config('ap.admin_session_token',$1,true)",*token);
      auto allowed=co_await tx->execSqlCoro(
          "SELECT ap_m1.has_admin_permission('FAQ_EDIT') AS allowed");
      if(allowed.empty() || !allowed.at(0)["allowed"].as<bool>()) {
        rollback_quietly(tx);
        co_return error_response("FORBIDDEN","FAQ editor role required",rid);
      }
    }
    // RLS is independently applied to both FAQ tables. Public reads use
    // published_revision_id, never current_revision_id, so a draft edit
    // cannot leak into the public page before MFA-gated publication.
    const std::string sql =
        "SELECT e.id::text AS id,e.slug,e.category,e.state AS status,"
        "e.revision,r.language,r.title,r.safe_body "
        "FROM ap_m1.faq_entries e "
        "JOIN ap_m1.faq_revisions r ON r.id = "
        + std::string(admin_mode ? "e.current_revision_id " : "e.published_revision_id ")
        + std::string(admin_mode ? "WHERE true " : "WHERE e.state='PUBLISHED' ")
        + (faq_id ? "AND e.id=$1::uuid " : "")
        + "ORDER BY e.updated_at DESC,e.id DESC LIMIT 50";
    // Query structure, not user content, selects the optional exact-id filter.
    // No SQL string concatenation with a client-controlled value.
    auto rows = faq_id ? co_await tx->execSqlCoro(sql,*faq_id)
                       : co_await tx->execSqlCoro(sql);
    Json::Value items(Json::arrayValue);
    for(const auto& row: rows) {
      Json::Value value(Json::objectValue);
      value["id"]=row["id"].as<std::string>();
      value["slug"]=row["slug"].as<std::string>();
      value["category"]=row["category"].as<std::string>();
      value["status"]=row["status"].as<std::string>();
      value["revision"]=row["revision"].as<int>();
      value["language"]=row["language"].as<std::string>();
      value["title"]=row["title"].as<std::string>();
      value["safe_body"]=row["safe_body"].as<std::string>();
      items.append(value);
    }
    rollback_quietly(tx);
    if(faq_id && items.empty())
      co_return error_response("NOT_FOUND","FAQ not found",rid);
    Json::Value result(Json::objectValue);
    if(faq_id) result=items[0];
    else {
      result["items"]=items;
      result["next_cursor"]=Json::nullValue;
    }
    auto resp=HttpResponse::newHttpJsonResponse(result);
    resp->setStatusCode(k200OK);
    resp->addHeader(kRequestIdHeader,rid);
    resp->addHeader("Cache-Control",admin_mode?"private, no-store":"no-store");
    co_return resp;
  } catch(const orm::SqlError& e){
    rollback_quietly(tx);
    LOG_ERROR<<"read_faqs SQLSTATE="<<e.sqlState()<<" request_id="<<rid;
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
