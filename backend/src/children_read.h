// GET /v1/families/{familyId}/children — real PostgreSQL RLS-scoped child listing.
// Read-only transaction establishes exact principal + family context, so a guardian
// can view only children for which VIEW_CHILD_PROFILE is currently granted.
// No synthetic auth in production; no child data emitted without a live membership.
#pragma once

#include <memory>
#include <optional>
#include <string>

#include <drogon/drogon.h>
#include "auth.h"
#include "parent_session.h"
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"

namespace ma {

inline drogon::Task<drogon::HttpResponsePtr> list_children(
    drogon::HttpRequestPtr req, std::string family_id_param, ParentAuth auth) {
  using namespace drogon;
  const std::string rid = request_id_of(req);

  auto family_id = normalize_uuid(family_id_param);
  if (!family_id) co_return error_response("INVALID_REQUEST", "familyId must be a UUID", rid);

  auto credential = parent_credential(auth, req);
  if (!credential) co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);

  if (!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  auto db = app().getDbClient(kDbClientName);
  if (!db) co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);

  std::shared_ptr<orm::Transaction> transaction;
  try {
    transaction = co_await db->newTransactionCoro();
    co_await transaction->execSqlCoro(
        "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    // PostgreSQL resolves the caller from the presented session (V2); the
    // read transaction is rolled back and persists nothing.
    auto bound = co_await bind_parent_principal(transaction, *credential, *family_id);
    if (!bound) {
      rollback_quietly(transaction);
      co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);
    }
    const std::string principal_id = *bound;
    // Failure is deliberately indistinguishable from an unknown family.
    // The membership query itself is restricted by RLS.
    auto membership = co_await transaction->execSqlCoro(
        "SELECT EXISTS (SELECT 1 FROM ap_m1.guardian_memberships "
        "WHERE family_id = $1::uuid AND principal_id = $2::uuid "
        "AND revoked_at IS NULL) AS member",
        *family_id, principal_id);
    if (!membership.at(0)["member"].as<bool>()) {
      rollback_quietly(transaction);
      co_return error_response("NOT_FOUND", "family not found", rid);
    }
    // children_r uses BOTH family context and a live per-child
    // VIEW_CHILD_PROFILE grant. No broader membership-only listing.
    auto result = co_await transaction->execSqlCoro(
        "SELECT id::text AS id, family_id::text AS family_id, alias, state "
        "FROM ap_m1.children ORDER BY id");
    Json::Value body(Json::objectValue);
    body["items"] = Json::Value(Json::arrayValue);
    for (const auto& record : result) {
      Json::Value child(Json::objectValue);
      child["id"] = record["id"].as<std::string>();
      child["family_id"] = record["family_id"].as<std::string>();
      child["alias"] = record["alias"].as<std::string>();
      child["state"] = record["state"].as<std::string>();
      body["items"].append(child);
    }
    rollback_quietly(transaction);  // closes read snapshot and any temporary principal
    auto response = HttpResponse::newHttpJsonResponse(body);
    response->setStatusCode(k200OK);
    response->addHeader(kRequestIdHeader, rid);
    co_return response;
  } catch (const orm::SqlError& e) {
    rollback_quietly(transaction);
    LOG_ERROR << "list_children SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const orm::TimeoutError&) {
    rollback_quietly(transaction);
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const orm::BrokenConnection&) {
    rollback_quietly(transaction);
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    rollback_quietly(transaction);
    LOG_ERROR << "list_children unexpected exception request_id=" << rid;
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

}  // namespace ma
