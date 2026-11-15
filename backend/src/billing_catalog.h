// L10-005: GET /v1/billing/catalog. Prices are shown ONLY when verified Play product metadata exists. Every
// catalog row is UNVERIFIED by a database CHECK today, so quoted_price is always null and is_sandbox true;
// the local planning amounts in the table are never exposed as a quote. Response envelope: {"items":[BillingProduct]}
// (docs/openapi.yaml still declares a single BillingProduct; that mismatch is recorded in the L10-005 evidence).
#pragma once
#include <memory>
#include <optional>
#include <string>
#include <drogon/drogon.h>
#include "db_support.h"
#include "http_support.h"
#include "parent_session.h"

namespace ma {

struct CatalogRow { std::string sku, kind, currency, play_state; };

inline std::optional<std::string> catalog_term(const std::string& kind) {
  if (kind == "MONTH") return "MONTH";
  if (kind == "YEAR") return "YEAR";
  if (kind == "ADDON") return "ADDON_100_DAYS";
  return std::nullopt;
}

// Pure mapping so the "never quote an unverified price" rule is unit-testable without a database.
inline Json::Value catalog_item(const CatalogRow& r) {
  Json::Value v(Json::objectValue);
  v["sku"] = r.sku;
  v["term"] = catalog_term(r.kind).value_or("UNKNOWN");
  v["currency"] = "INR";
  v["quoted_price"] = Json::Value(Json::nullValue);  // verified Play metadata is required for any amount
  v["play_offer_id"] = Json::Value(Json::nullValue);
  v["is_sandbox"] = r.play_state != "VERIFIED";
  return v;
}

inline drogon::Task<drogon::HttpResponsePtr> billing_catalog(drogon::HttpRequestPtr req, ParentAuth auth) {
  using namespace drogon;
  const std::string rid = request_id_of(req);
  if (!req->body().empty()) co_return error_response("INVALID_REQUEST", "GET requires an empty body", rid);
  auto credential = parent_credential(auth, req);
  if (!credential) co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);
  if (!app().hasDbClient(kDbClientName)) co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  auto db = app().getDbClient(kDbClientName);
  if (!db) co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  std::shared_ptr<orm::Transaction> tx;
  try {
    tx = co_await db->newTransactionCoro();
    co_await tx->execSqlCoro("SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
                             std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    if (!(co_await bind_parent_principal(tx, *credential))) {
      rollback_quietly(tx);
      co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);
    }
    auto rows = co_await tx->execSqlCoro(
        "SELECT sku_id, kind, currency, play_configuration_state FROM ap_m1.billing_product_catalog ORDER BY sku_id");
    Json::Value body(Json::objectValue);
    body["items"] = Json::Value(Json::arrayValue);
    for (const auto& row : rows)
      body["items"].append(catalog_item({row["sku_id"].as<std::string>(), row["kind"].as<std::string>(),
                                         row["currency"].as<std::string>(),
                                         row["play_configuration_state"].as<std::string>()}));
    rollback_quietly(tx);  // read-only
    auto resp = HttpResponse::newHttpJsonResponse(body);
    resp->setStatusCode(k200OK);
    resp->addHeader(kRequestIdHeader, rid);
    add_no_store(resp);
    co_return resp;
  } catch (const orm::SqlError& e) {
    rollback_quietly(tx);
    LOG_ERROR << "catalog SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  } catch (const orm::TimeoutError&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const orm::BrokenConnection&) {
    rollback_quietly(tx);
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    rollback_quietly(tx);
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

}  // namespace ma
