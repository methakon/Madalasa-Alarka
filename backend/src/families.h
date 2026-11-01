// POST /v1/families (createFamily). Idempotent: claim, create and record share ONE database transaction
// (migration 0004/0005; docs/API_CONVENTIONS_AND_ERROR_CATALOG.md sections 5.3 and 6).
//
// Check order (section 5.3 rule 5): size 413 -> syntax 400 -> authentication 401 -> value rules 422 -> database.
// (Quota 429 sits in front of the app, at the proxy; not implemented here.)
#pragma once
#include <optional>
#include <string>

#include <drogon/drogon.h>

#include "auth.h"
#include "parent_session.h"
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"
#include "validation.h"

namespace ma {

inline constexpr const char* kCreateFamilyNamespace = "POST /families";

inline drogon::HttpResponsePtr family_response(const Json::Value& family, const std::string& rid) {
  auto resp = drogon::HttpResponse::newHttpJsonResponse(family);
  resp->setStatusCode(drogon::k201Created);
  resp->addHeader(kRequestIdHeader, rid);
  return resp;
}

inline drogon::Task<drogon::HttpResponsePtr> create_family(drogon::HttpRequestPtr req, ParentAuth auth) {
  using namespace drogon;
  const std::string rid = request_id_of(req);

  // 413
  if (req->body().size() > kMaxBodyBytes) co_return error_response("PAYLOAD_TOO_LARGE", "request body too large", rid);
  // 400: header, content type, JSON, shape
  auto key_hash = hash_idempotency_key(req->getHeader("idempotency-key"));
  if (!key_hash) co_return error_response("INVALID_REQUEST", "Idempotency-Key must be a UUID", rid);
  if (req->contentType() != CT_APPLICATION_JSON)
    co_return error_response("INVALID_REQUEST", "content type must be application/json", rid);
  Json::Value body;
  if (!parse_json_strict(req->body(), body)) co_return error_response("INVALID_REQUEST", "malformed JSON", rid);
  std::string label;
  auto check = check_family_body(body, label);
  if (check == LabelCheck::Malformed) co_return error_response("INVALID_REQUEST", "body must be {\"label\": string}", rid);
  // 401
  auto credential = parent_credential(auth, req);
  if (!credential) co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);
  // 422
  if (check == LabelCheck::OutOfRange) co_return error_response("VALIDATION_FAILED", "label must be 1 to 100 characters", rid);

  // getDbClient asserts (debug) or throws (release) for an unknown name.
  // A null test after calling it does not protect an unconfigured service.
  if (!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  auto db = app().getDbClient(kDbClientName);
  if (!db) co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);

  const std::string req_hash = to_pg_bytea(request_hash(body));
  const std::string key_hex = to_pg_bytea(*key_hash);
  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    auto bound = co_await bind_parent_principal(trans, *credential);
    if (!bound) {
      rollback_quietly(trans);
      co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);
    }
    const std::string principal = *bound;

    auto claim = co_await trans->execSqlCoro(
        "SELECT outcome, response_status, response_body::text AS response_body "
        "FROM ap_m1.idempotency_claim($1::uuid, $2, $3::bytea, $4::bytea)",
        principal, std::string(kCreateFamilyNamespace), key_hex, req_hash);
    const std::string outcome = claim.at(0)["outcome"].as<std::string>();

    if (outcome == "MISMATCH") {
      rollback_quietly(trans);
      co_return error_response("IDEMPOTENCY_KEY_REUSED", "Idempotency-Key was already used with a different request", rid);
    }
    if (outcome == "PENDING") {  // a committed claim without a result is a backend bug (migration 0004 header)
      rollback_quietly(trans);
      LOG_ERROR << "idempotency PENDING outcome, request_id=" << rid;
      co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
    }
    if (outcome == "REPLAY") {
      Json::Value stored;
      const bool usable = !claim.at(0)["response_body"].isNull() &&
                          parse_json_strict(claim.at(0)["response_body"].as<std::string>(), stored) &&
                          claim.at(0)["response_status"].as<int>() == 201;
      rollback_quietly(trans);
      if (!usable) {
        LOG_ERROR << "idempotency replay without a usable stored body, request_id=" << rid;
        co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
      }
      co_return family_response(stored, rid);
    }
    if (outcome != "NEW") {
      rollback_quietly(trans);
      co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
    }

    auto created = co_await trans->execSqlCoro("SELECT id::text AS id, label, state FROM ap_m1.create_family($1)", label);
    Json::Value family;
    family["id"] = created.at(0)["id"].as<std::string>();
    family["label"] = created.at(0)["label"].as<std::string>();
    family["status"] = created.at(0)["state"].as<std::string>();
    auto rec = co_await trans->execSqlCoro("SELECT ap_m1.idempotency_record($1::uuid, $2, $3::bytea, 201, $4::jsonb) AS ok",
                                           principal, std::string(kCreateFamilyNamespace), key_hex, canonical_json(family));
    if (!rec.at(0)["ok"].as<bool>()) {
      rollback_quietly(trans);
      LOG_ERROR << "idempotency_record refused, request_id=" << rid;
      co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
    }
    if (!(co_await commit(std::move(trans)))) {
      LOG_ERROR << "commit failed, request_id=" << rid;
      co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable; retry the same request", rid, true);
    }
    co_return family_response(family, rid);
  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "sql error state=" << e.sqlState() << " request_id=" << rid;  // never the message: may carry data
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const orm::TimeoutError&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const orm::BrokenConnection&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    rollback_quietly(trans);
    LOG_ERROR << "unexpected exception, request_id=" << rid;
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

}  // namespace ma
