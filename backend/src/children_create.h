// POST /v1/families/{familyId}/children (createChild).
// Frozen M1 scope: *synthetic* child profile only, no inferred child consent,
// no auto-added guardian grants, no location ingestion or media permission.
#pragma once
#include <drogon/drogon.h>
#include <memory>
#include <string>
#include "auth.h"
#include "parent_session.h"
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"
#include "validation.h"

namespace ma {
inline constexpr const char* kCreateChildNamespace = "POST /families/{familyId}/children";

inline drogon::Task<drogon::HttpResponsePtr> create_child(
    drogon::HttpRequestPtr req, std::string family_param, ParentAuth auth) {
  using namespace drogon;
  const auto rid = request_id_of(req);
  if (req->body().size() > kMaxBodyBytes)
    co_return error_response("PAYLOAD_TOO_LARGE","request body too large",rid);
  auto family = normalize_uuid(family_param);
  if (!family) co_return error_response("INVALID_REQUEST","familyId must be a UUID",rid);
  auto key_hash = hash_idempotency_key(req->getHeader("idempotency-key"));
  if (!key_hash) co_return error_response("INVALID_REQUEST","Idempotency-Key must be a UUID",rid);
  if (req->contentType() != CT_APPLICATION_JSON)
    co_return error_response("INVALID_REQUEST","content type must be application/json",rid);
  Json::Value body;
  if (!parse_json_strict(req->body(),body) || !body.isObject() ||
      body.size()!=1 || !body["alias"].isString())
    co_return error_response("INVALID_REQUEST","body must be {alias:string}",rid);
  const auto alias = body["alias"].asString();
  const auto codepoints = utf8_codepoints(alias);
  if (!codepoints || alias.find('\0') != std::string::npos)
    co_return error_response("INVALID_REQUEST","invalid alias encoding",rid);
  auto credential = parent_credential(auth, req);
  if (!credential) co_return error_response("UNAUTHENTICATED","missing or invalid parent credential",rid);
  if (*codepoints<1 || *codepoints>80)
    co_return error_response("VALIDATION_FAILED","alias must be 1..80 characters",rid);
  if (!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE","database not configured",rid,true);
  auto db = app().getDbClient(kDbClientName);
  const auto request_digest = to_pg_bytea(sha256_bytes(*family+"\n"+canonical_json(body)));
  const auto key = to_pg_bytea(*key_hash);
  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms),std::to_string(db_limits().statement_ms));
    // Path familyId is only a selector; SQL honours it for a live membership.
    auto bound = co_await bind_parent_principal(trans, *credential, *family);
    if (!bound) {
      rollback_quietly(trans);
      co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);
    }
    const std::string principal = *bound;
    // The v2 family_owner function requires an authoritative session; setting
    // a client GUC without a valid issuer-approved token never grants authority.
    auto owner = co_await trans->execSqlCoro(
        "SELECT ap_m1.family_owner($1::uuid) AS permitted",*family);
    if (!owner.at(0)["permitted"].as<bool>()) {
      rollback_quietly(trans);
      co_return error_response("NOT_FOUND","family not found",rid);
    }
    // Idempotency and creation live in one transaction; path family is part
    // of digest to prevent replay into a different family.
    const auto claim = co_await trans->execSqlCoro(
        "SELECT outcome,response_status,response_body::text AS response_body "
        "FROM ap_m1.idempotency_claim($1::uuid,$2,$3::bytea,$4::bytea)",
        principal,std::string(kCreateChildNamespace),key,request_digest);
    const auto outcome = claim.at(0)["outcome"].as<std::string>();
    if (outcome=="MISMATCH") {
      rollback_quietly(trans);
      co_return error_response("IDEMPOTENCY_KEY_REUSED","Idempotency-Key was used for another request",rid);
    }
    if (outcome=="REPLAY") {
      Json::Value replay;
      const bool usable = !claim.at(0)["response_body"].isNull() &&
          claim.at(0)["response_status"].as<int>()==201 &&
          parse_json_strict(claim.at(0)["response_body"].as<std::string>(),replay);
      rollback_quietly(trans);
      if (!usable) co_return error_response("INTERNAL_ERROR","invalid stored idempotency response",rid);
      auto response = HttpResponse::newHttpJsonResponse(replay);
      response->setStatusCode(k201Created);
      response->addHeader(kRequestIdHeader,rid);
      co_return response;
    }
    if (outcome!="NEW") {
      rollback_quietly(trans);
      co_return error_response("INTERNAL_ERROR","invalid idempotency state",rid);
    }
    // V2 create_child enforces current owner/authority, audits provisioning,
    // and creates NO child access grant or consent as an implicit side effect.
    auto created = co_await trans->execSqlCoro(
        "SELECT ap_m1.create_child($1)::text AS id",alias);
    Json::Value result(Json::objectValue);
    result["id"] = created.at(0)["id"].as<std::string>();
    result["family_id"] = *family;
    result["alias"] = alias;
    result["state"] = "ACTIVE"; // schema default on successful synthetic create
    auto rec = co_await trans->execSqlCoro(
        "SELECT ap_m1.idempotency_record($1::uuid,$2,$3::bytea,201,$4::jsonb) AS ok",
        principal,std::string(kCreateChildNamespace),key,canonical_json(result));
    if (!rec.at(0)["ok"].as<bool>()) {
      rollback_quietly(trans);
      co_return error_response("INTERNAL_ERROR","idempotency store refused",rid);
    }
    if (!(co_await commit(std::move(trans))))
      co_return error_response("SERVICE_UNAVAILABLE","database commit unavailable",rid,true);
    auto response = HttpResponse::newHttpJsonResponse(result);
    response->setStatusCode(k201Created);
    response->addHeader(kRequestIdHeader,rid);
    co_return response;
  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "create_child SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    if (e.sqlState()=="42501")
      co_return error_response("FORBIDDEN","family creation permission denied",rid);
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
