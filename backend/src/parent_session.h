// Trusted ParentOIDC -> V2 server-controlled parent session bridge. SYNTHETIC DATA ONLY.
//
// Identity, authority and child access are three separate steps:
//   1. POST /v1/auth/parent/google: the C++ verifier checks the Google ID token
//      (Authenticator, auth.h). Only then does the SEPARATE issuer database login
//      (ap_auth_issuer, never ap_m1_api) exchange (issuer, subject, one-time
//      credential digest) for an opaque token that PostgreSQL itself generates
//      and stores only as SHA-256 (migration 0021).
//   2. Every parent route presents that token. PostgreSQL resolves the caller
//      (ap_m1.ctx_principal) from the token; no client UUID is ever trusted.
//   3. Guardian authority and exact-child access stay in SQL (family_owner,
//      has_child_scope_v2, RLS). A session never grants either.
//
// ParentAuthMode::M1DirectOidc keeps the historical per-request ID-token path for
// the frozen M1 schema only. It is selected explicitly; the default is V2 sessions.
#pragma once
#include <cstdlib>
#include <memory>
#include <optional>
#include <string>
#include <string_view>

#include <drogon/drogon.h>

#include "auth.h"
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"
#include "validation.h"

namespace ma {

enum class ParentAuthMode { V2Session, M1DirectOidc };

// Unset or empty => V2 sessions (fail closed). Unknown values are rejected at startup.
inline std::optional<ParentAuthMode> parse_parent_auth_mode(const char* text) {
  if (!text || !*text) return ParentAuthMode::V2Session;
  const std::string_view value(text);
  if (value == "v2_session") return ParentAuthMode::V2Session;
  if (value == "m1_direct_oidc") return ParentAuthMode::M1DirectOidc;
  return std::nullopt;
}

inline constexpr int kParentSessionDefaultTtlSeconds = 3600;
inline constexpr int kParentSessionMinTtlSeconds = 300;     // equals the SQL bound
inline constexpr int kParentSessionMaxTtlSeconds = 43200;   // equals the SQL bound

inline std::optional<int> parse_parent_session_ttl(const char* text) {
  if (!text || !*text) return kParentSessionDefaultTtlSeconds;
  const std::string_view value(text);
  if (value.size() > 5) return std::nullopt;
  int result = 0;
  for (char c : value) {
    if (c < '0' || c > '9') return std::nullopt;
    result = result * 10 + (c - '0');
  }
  if (result < kParentSessionMinTtlSeconds || result > kParentSessionMaxTtlSeconds) return std::nullopt;
  return result;
}

struct ParentAuth {
  ParentAuthMode mode;
  Authenticator oidc;  // ID-token verifier: used by the exchange (V2) or per request (M1 only)
};

struct ParentCredential {
  ParentAuthMode mode;
  std::string session_token;  // V2Session: 64 lowercase hex characters
  Principal identity;         // M1DirectOidc: verified issuer + subject
};

inline constexpr const char* kAuthDbClientName = "ma_auth";
inline constexpr std::size_t kMaxBearerBytes = 16384;

// Strict "Bearer <token68-subset>" parser; the scheme is case-insensitive.
inline std::optional<std::string> bearer_value(const drogon::HttpRequestPtr& req) {
  const auto& header = req->getHeader("authorization");
  if (header.size() <= 7 || header.size() > kMaxBearerBytes + 7 || header[6] != ' ') return std::nullopt;
  constexpr std::string_view scheme = "bearer";
  for (std::size_t i = 0; i < scheme.size(); ++i) {
    const char c = header[i];
    if (c != scheme[i] && c != static_cast<char>(scheme[i] - 'a' + 'A')) return std::nullopt;
  }
  std::string token = header.substr(7);
  for (unsigned char c : token)
    if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
          c == '-' || c == '_' || c == '.')) return std::nullopt;
  return token;
}

// Exactly the shape PostgreSQL issues: encode(gen_random_bytes(32),'hex').
inline bool is_parent_session_token(std::string_view value) {
  if (value.size() != 64) return false;
  for (char c : value)
    if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
  return true;
}

// Domain-separated digest of the presented ID token. Lets PostgreSQL refuse a
// second exchange of the same token without ever storing the token itself.
inline std::string parent_exchange_credential_digest(std::string_view bearer) {
  std::string input("ma.parent-oidc-exchange.v1\n");
  input.append(bearer);
  return to_pg_bytea(sha256_bytes(input));
}

// Syntactic/identity step only (no database). nullopt => 401.
inline std::optional<ParentCredential> parent_credential(const ParentAuth& auth, const drogon::HttpRequestPtr& req) {
  if (auth.mode == ParentAuthMode::V2Session) {
    auto token = bearer_value(req);
    if (!token || !is_parent_session_token(*token)) return std::nullopt;
    return ParentCredential{auth.mode, std::move(*token), {}};
  }
  if (!auth.oidc) return std::nullopt;
  auto identity = auth.oidc(req);
  if (!identity) return std::nullopt;
  return ParentCredential{auth.mode, {}, std::move(*identity)};
}

// Binds the caller to THIS transaction and returns the principal that PostgreSQL
// resolved, or nullopt (=> 401) when the session is unknown, expired, revoked or
// its issuer is no longer trusted. `family` is only a selector: SQL honours it
// for a live membership and ignores it otherwise. Parameters are by value: the
// coroutine may outlive the caller's temporaries.
inline drogon::Task<std::optional<std::string>> bind_parent_principal(
    std::shared_ptr<drogon::orm::Transaction> trans, ParentCredential credential,
    std::optional<std::string> family = std::nullopt) {
  if (credential.mode == ParentAuthMode::V2Session) {
    co_await trans->execSqlCoro("SELECT set_config('ap.session_token',$1,true)", credential.session_token);
  } else {
    // Historical M1 schema only, where the runtime role still resolves identities.
    auto resolved = co_await trans->execSqlCoro(
        "SELECT ap_m1.resolve_parent_principal($1,$2)::text AS id",
        credential.identity.issuer, credential.identity.subject);
    co_await trans->execSqlCoro("SELECT set_config('ap.principal_id',$1,true)",
                                resolved.at(0)["id"].as<std::string>());
  }
  if (family) co_await trans->execSqlCoro("SELECT set_config('ap.family_id',$1,true)", *family);
  auto actor = co_await trans->execSqlCoro("SELECT ap_m1.ctx_principal()::text AS id");
  if (actor.empty() || actor.at(0)["id"].isNull()) co_return std::nullopt;
  co_return actor.at(0)["id"].as<std::string>();
}

inline void add_no_store(const drogon::HttpResponsePtr& response) {
  response->addHeader("Cache-Control", "no-store");
  response->addHeader("Pragma", "no-cache");
}

inline drogon::HttpResponsePtr unauthenticated_no_store(std::string_view message, const std::string& rid) {
  auto response = error_response("UNAUTHENTICATED", message, rid);
  add_no_store(response);
  return response;
}

// POST /v1/auth/parent/google — Authorization: Bearer <Google ID token>; body empty or {}.
inline drogon::Task<drogon::HttpResponsePtr> exchange_parent_session(
    drogon::HttpRequestPtr req, ParentAuth auth, int ttl_seconds) {
  using namespace drogon;
  const std::string rid = request_id_of(req);
  if (auth.mode != ParentAuthMode::V2Session) co_return error_response("NOT_FOUND", "no such route", rid);
  if (req->body().size() > kMaxBodyBytes) co_return error_response("PAYLOAD_TOO_LARGE", "request body too large", rid);
  if (!req->body().empty()) {
    Json::Value body;
    if (!parse_json_strict(req->body(), body) || !body.isObject() || !body.empty())
      co_return error_response("INVALID_REQUEST", "body must be empty or {}", rid);
  }
  auto bearer = bearer_value(req);
  // An already-issued session token is not an identity assertion.
  if (!bearer || is_parent_session_token(*bearer))
    co_return unauthenticated_no_store("missing or invalid identity token", rid);
  auto identity = auth.oidc ? auth.oidc(req) : std::nullopt;
  if (!identity) co_return unauthenticated_no_store("missing or invalid identity token", rid);
  if (ttl_seconds < kParentSessionMinTtlSeconds || ttl_seconds > kParentSessionMaxTtlSeconds)
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  if (!app().hasDbClient(kAuthDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE", "session issuer not configured", rid, true);
  auto db = app().getDbClient(kAuthDbClientName);
  const std::string credential_digest = parent_exchange_credential_digest(*bearer);
  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    auto rows = co_await trans->execSqlCoro(
        "SELECT session_token, principal_id::text AS principal_id, "
        "to_char(expires_at AT TIME ZONE 'UTC','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS expires_at "
        "FROM ap_m1.exchange_parent_oidc_session($1,$2,$3::bytea,$4::integer)",
        identity->issuer, identity->subject, credential_digest, std::to_string(ttl_seconds));
    if (rows.size() != 1 || rows.at(0)["session_token"].isNull()) {
      rollback_quietly(trans);
      co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
    }
    Json::Value body(Json::objectValue);
    body["session_token"] = rows.at(0)["session_token"].as<std::string>();
    body["token_type"] = "Bearer";
    body["actor_id"] = rows.at(0)["principal_id"].as<std::string>();
    body["kind"] = "PARENT";
    body["state"] = "ACTIVE";
    body["expires_at"] = rows.at(0)["expires_at"].as<std::string>();
    if (!(co_await commit(std::move(trans))))
      co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable", rid, true);
    auto response = HttpResponse::newHttpJsonResponse(body);
    response->setStatusCode(k201Created);
    response->addHeader(kRequestIdHeader, rid);
    add_no_store(response);
    co_return response;
  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "parent session exchange SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    // Untrusted issuer, replayed token, erased account or wrong DB role: one answer.
    if (e.sqlState() == "42501" || e.sqlState() == "28000")
      co_return unauthenticated_no_store("parent session exchange denied", rid);
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const orm::TimeoutError&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const orm::BrokenConnection&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    rollback_quietly(trans);
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

// DELETE /v1/auth/session — ends the presented session only.
inline drogon::Task<drogon::HttpResponsePtr> revoke_parent_session(drogon::HttpRequestPtr req, ParentAuth auth) {
  using namespace drogon;
  const std::string rid = request_id_of(req);
  if (auth.mode != ParentAuthMode::V2Session) co_return error_response("NOT_FOUND", "no such route", rid);
  auto credential = parent_credential(auth, req);
  if (!credential) co_return unauthenticated_no_store("missing or invalid parent session", rid);
  if (!app().hasDbClient(kDbClientName))
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  auto db = app().getDbClient(kDbClientName);
  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout',$1,true),set_config('statement_timeout',$2,true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));
    co_await trans->execSqlCoro("SELECT set_config('ap.session_token',$1,true)", credential->session_token);
    auto revoked = co_await trans->execSqlCoro("SELECT ap_m1.revoke_current_parent_session() AS revoked");
    if (revoked.empty() || !revoked.at(0)["revoked"].as<bool>()) {
      rollback_quietly(trans);
      co_return unauthenticated_no_store("missing or invalid parent session", rid);
    }
    if (!(co_await commit(std::move(trans))))
      co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable", rid, true);
    auto response = HttpResponse::newHttpResponse();
    response->setStatusCode(static_cast<HttpStatusCode>(204));
    response->addHeader(kRequestIdHeader, rid);
    add_no_store(response);
    co_return response;
  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "parent session revoke SQLSTATE=" << e.sqlState() << " request_id=" << rid;
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const orm::TimeoutError&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database deadline exceeded", rid, true);
  } catch (const orm::BrokenConnection&) {
    rollback_quietly(trans);
    co_return error_response("SERVICE_UNAVAILABLE", "database unavailable", rid, true);
  } catch (const std::exception&) {
    rollback_quietly(trans);
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

}  // namespace ma
