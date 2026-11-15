// L10-002: server-side 48-hour family trial.
//   GET  /v1/families/{familyId}/trial/eligibility
//   POST /v1/families/{familyId}/trial/start      {"acknowledge_one_time_trial": true}
// All policy lives in SQL (ap_m1.check_trial_eligibility / start_family_trial): one trial per family AND per
// payer, never after a paid purchase, no device or advertising identifier involved. This layer only
// authenticates the parent session, validates input, and maps outcomes to the error catalog.
#pragma once
#include <memory>
#include <optional>
#include <string>
#include <drogon/drogon.h>
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"
#include "parent_session.h"
#include "validation.h"

namespace ma {

inline constexpr int kTrialDurationHours = 48;

// Pure mapping, unit-tested without a database. Unknown or hidden objects and non-owners are 404 so a
// caller cannot probe other families; a spent trial or earlier purchase is a 409 state conflict.
struct TrialOutcome { int status; const char* code; const char* message; };
inline TrialOutcome trial_outcome_for_sqlstate(const std::string& state, const std::string& message) {
  if (state == "42501") return {404, "NOT_FOUND", "family not found"};
  // A unique-key race between two concurrent starts must read as a spent trial, not a server fault.
  if (state == "23505") return {409, "CONFLICT", "the one-time trial is not available for this account"};
  if (state == "P0001" && message.find("trial already used") != std::string::npos)
    return {409, "CONFLICT", "the one-time trial is not available for this account"};
  if (state == "P0001") return {422, "VALIDATION_FAILED", "trial request rejected"};
  if (state == "55P03" || state == "57014") return {503, "SERVICE_UNAVAILABLE", "database deadline exceeded"};
  return {500, "INTERNAL_ERROR", "unexpected server error"};
}

inline std::optional<bool> parse_trial_start_body(std::string_view body) {
  Json::Value v;
  if (body.size() > kMaxBodyBytes || !parse_json_strict(body, v) || !v.isObject() || v.size() != 1 ||
      !v.isMember("acknowledge_one_time_trial") || !v["acknowledge_one_time_trial"].isBool())
    return std::nullopt;
  return v["acknowledge_one_time_trial"].asBool();
}

inline Json::Value trial_body(const std::string& family, bool eligible, const char* status) {
  Json::Value b(Json::objectValue);
  b["family_id"] = family;
  b["eligible"] = eligible;
  b["duration_hours"] = kTrialDurationHours;
  b["status"] = status;
  return b;
}

inline drogon::Task<drogon::HttpResponsePtr> family_trial(drogon::HttpRequestPtr req, std::string family_param,
                                                          ParentAuth auth, bool start) {
  using namespace drogon;
  const std::string rid = request_id_of(req);
  auto family = normalize_uuid(family_param);
  if (!family) co_return error_response("INVALID_REQUEST", "familyId must be a UUID", rid);
  if (start) {
    if (req->body().size() > kMaxBodyBytes) co_return error_response("PAYLOAD_TOO_LARGE", "body too large", rid);
  } else if (!req->body().empty()) {
    co_return error_response("INVALID_REQUEST", "GET requires an empty body", rid);
  }
  std::optional<bool> acknowledged;
  if (start) {
    acknowledged = parse_trial_start_body(req->body());
    if (!acknowledged) co_return error_response("INVALID_REQUEST", "expected {\"acknowledge_one_time_trial\": true}", rid);
  }
  auto credential = parent_credential(auth, req);
  if (!credential) co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);
  if (start && !*acknowledged)
    co_return error_response("VALIDATION_FAILED", "the one-time trial must be acknowledged", rid);
  if (!app().hasDbClient(kDbClientName)) co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  auto db = app().getDbClient(kDbClientName);
  if (!db) co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);

  std::shared_ptr<orm::Transaction> tx;
  try {
    tx = co_await db->newTransactionCoro();
    co_await tx->execSqlCoro("SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
                             std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    if (!(co_await bind_parent_principal(tx, *credential, *family))) {
      rollback_quietly(tx);
      co_return error_response("UNAUTHENTICATED", "missing, expired or invalid credential", rid);
    }
    HttpResponsePtr resp;
    if (start) {
      co_await tx->execSqlCoro("SELECT ap_m1.start_family_trial($1::uuid, true)", *family);
      resp = HttpResponse::newHttpJsonResponse(trial_body(*family, true, "STARTED"));
      resp->setStatusCode(k201Created);
    } else {
      auto r = co_await tx->execSqlCoro("SELECT ap_m1.check_trial_eligibility($1::uuid) AS ok", *family);
      const bool ok = !r.empty() && r.at(0)["ok"].as<bool>();
      resp = HttpResponse::newHttpJsonResponse(trial_body(*family, ok, ok ? "ELIGIBLE" : "NOT_ELIGIBLE"));
      resp->setStatusCode(k200OK);
    }
    // The eligibility check records an audit row, so both paths commit before answering.
    if (!(co_await commit(std::move(tx)))) co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable", rid, true);
    resp->addHeader(kRequestIdHeader, rid);
    add_no_store(resp);
    co_return resp;
  } catch (const orm::SqlError& e) {
    rollback_quietly(tx);
    const auto o = trial_outcome_for_sqlstate(e.sqlState(), e.what());
    LOG_ERROR << "trial SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    co_return error_response(o.code, o.message, rid, o.status == 503);
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
