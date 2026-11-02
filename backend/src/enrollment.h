// POST /v1/enrollment and POST /v1/enrollment/{enrollmentId}/proof.
// Two-step pattern (M1 C-04): DB transaction 1 spends challenge and commits;
// crypto verification occurs with NO DB transaction open; DB transaction 2 activates device.
#pragma once
#include <optional>
#include <string>

#include <drogon/drogon.h>

#include "crypto_support.h"
#include "db_support.h"
#include "http_support.h"
#include "idempotency_key.h"
#include "validation.h"

namespace ma {

inline constexpr const char* kEnrollmentContext = "amar-pola-m1-device-enroll-v1";

inline drogon::HttpResponsePtr challenge_response(const Json::Value& body, const std::string& rid) {
  auto resp = drogon::HttpResponse::newHttpJsonResponse(body);
  resp->setStatusCode(drogon::k201Created);
  resp->addHeader(kRequestIdHeader, rid);
  return resp;
}

inline drogon::HttpResponsePtr token_response(const Json::Value& body, const std::string& rid) {
  auto resp = drogon::HttpResponse::newHttpJsonResponse(body);
  resp->setStatusCode(drogon::k201Created);
  resp->addHeader(kRequestIdHeader, rid);
  return resp;
}

// Handler for POST /v1/enrollment (redeem pairing code, return challenge)
inline drogon::Task<drogon::HttpResponsePtr> redeem_enrollment(drogon::HttpRequestPtr req) {
  using namespace drogon;
  const std::string rid = request_id_of(req);

  if (req->body().size() > kMaxBodyBytes) {
    co_return error_response("PAYLOAD_TOO_LARGE", "request body too large", rid);
  }

  if (req->contentType() != CT_APPLICATION_JSON) {
    co_return error_response("INVALID_REQUEST", "content type must be application/json", rid);
  }

  Json::Value body;
  if (!parse_json_strict(req->body(), body)) {
    co_return error_response("INVALID_REQUEST", "malformed JSON", rid);
  }

  if (!body.isObject() || !body.isMember("pairing_code") || !body["pairing_code"].isString() ||
      !body.isMember("public_key_spki_base64") || !body["public_key_spki_base64"].isString() ||
      !body.isMember("algorithm") || !body["algorithm"].isString() ||
      !body.isMember("app_version") || !body["app_version"].isString() ||
      !body.isMember("android_api") || !body["android_api"].isInt()) {
    co_return error_response("INVALID_REQUEST", "invalid enrollment payload shape", rid);
  }

  const std::string pairing_code = body["pairing_code"].asString();
  const std::string spki_b64 = body["public_key_spki_base64"].asString();
  const std::string algorithm = body["algorithm"].asString();
  const std::string app_version = body["app_version"].asString();
  const int android_api = body["android_api"].asInt();

  if (pairing_code.size() < 8 || pairing_code.size() > 64) {
    co_return error_response("VALIDATION_FAILED", "pairing_code length out of range", rid);
  }
  if (algorithm != "ECDSA_P256_SHA256") {
    co_return error_response("VALIDATION_FAILED", "unsupported algorithm", rid);
  }
  if (android_api < 29 || android_api > 45) {
    co_return error_response("VALIDATION_FAILED", "unsupported android_api level", rid);
  }
  if (app_version.size() > 60) {
    co_return error_response("VALIDATION_FAILED", "app_version exceeds max length", rid);
  }

  auto spki_bytes = base64_decode(spki_b64);
  if (!spki_bytes || !validate_ec_p256_spki(*spki_bytes)) {
    co_return error_response("VALIDATION_FAILED", "invalid EC P-256 SPKI public key", rid);
  }

  if (!app().hasDbClient(kDbClientName)) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }
  auto db = app().getDbClient(kDbClientName);
  if (!db) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }

  const std::string nonce_b64url = generate_secure_token(32);
  const Sha256 nonce_hash = sha256_bytes(nonce_b64url);
  const Sha256 code_hash = sha256_bytes(pairing_code);

  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));

    auto res = co_await trans->execSqlCoro(
        "SELECT enrollment_id::text AS enrollment_id, device_id::text AS device_id "
        "FROM ap_m1.redeem_pairing_code($1::bytea, $2::bytea, $3::bytea, 300)",
        to_pg_bytea(code_hash), bytes_to_pg_bytea(*spki_bytes), to_pg_bytea(nonce_hash));

    if (res.empty()) {
      rollback_quietly(trans);
      co_return error_response("NOT_FOUND", "invalid, expired or already used pairing code", rid);
    }

    const std::string enrollment_id = res.at(0)["enrollment_id"].as<std::string>();
    const std::string device_id = res.at(0)["device_id"].as<std::string>();

    auto time_res = co_await trans->execSqlCoro(
        "SELECT to_char(expires_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS expires_iso "
        "FROM ap_m1.enrollment_challenges WHERE id = $1::uuid", enrollment_id);

    const std::string expires_iso = time_res.empty() ? "" : time_res.at(0)["expires_iso"].as<std::string>();

    if (!(co_await commit(std::move(trans)))) {
      LOG_ERROR << "commit failed, request_id=" << rid;
      co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable; retry request", rid, true);
    }

    Json::Value challenge;
    challenge["enrollment_id"] = enrollment_id;
    challenge["device_id"] = device_id;
    challenge["nonce_base64url"] = nonce_b64url;
    challenge["expires_at"] = expires_iso;
    challenge["challenge_context"] = kEnrollmentContext;

    co_return challenge_response(challenge, rid);

  } catch (const orm::SqlError& e) {
    rollback_quietly(trans);
    LOG_ERROR << "sql error state=" << e.sqlState() << " request_id=" << rid;
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

// Handler for POST /v1/enrollment/{enrollmentId}/proof
inline drogon::Task<drogon::HttpResponsePtr> complete_enrollment_proof(
    drogon::HttpRequestPtr req, std::string enrollment_id_param) {
  using namespace drogon;
  const std::string rid = request_id_of(req);

  if (req->body().size() > kMaxBodyBytes) {
    co_return error_response("PAYLOAD_TOO_LARGE", "request body too large", rid);
  }

  auto normalized_enrollment = normalize_uuid(enrollment_id_param);
  if (!normalized_enrollment) {
    co_return error_response("INVALID_REQUEST", "enrollmentId must be a valid UUID", rid);
  }

  if (req->contentType() != CT_APPLICATION_JSON) {
    co_return error_response("INVALID_REQUEST", "content type must be application/json", rid);
  }

  Json::Value body;
  if (!parse_json_strict(req->body(), body)) {
    co_return error_response("INVALID_REQUEST", "malformed JSON", rid);
  }

  if (!body.isObject() || !body.isMember("nonce_base64url") || !body["nonce_base64url"].isString() ||
      !body.isMember("signature_base64url") || !body["signature_base64url"].isString()) {
    co_return error_response("INVALID_REQUEST", "invalid proof payload shape", rid);
  }

  const std::string nonce_b64url = body["nonce_base64url"].asString();
  const std::string sig_b64url = body["signature_base64url"].asString();

  if (nonce_b64url.size() < 24 || nonce_b64url.size() > 200 ||
      sig_b64url.size() < 48 || sig_b64url.size() > 4096) {
    co_return error_response("VALIDATION_FAILED", "proof parameter lengths out of range", rid);
  }

  auto sig_bytes = base64url_decode(sig_b64url);
  if (!sig_bytes) sig_bytes = base64_decode(sig_b64url);
  if (!sig_bytes) {
    co_return error_response("UNAUTHENTICATED", "invalid signature encoding", rid);
  }

  if (!app().hasDbClient(kDbClientName)) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }
  auto db = app().getDbClient(kDbClientName);
  if (!db) {
    co_return error_response("SERVICE_UNAVAILABLE", "database not configured", rid, true);
  }

  // -------------------------------------------------------------
  // Step 1: consume challenge in DB tx1 and COMMIT immediately
  // -------------------------------------------------------------
  std::string device_id;
  std::string stored_nonce_hash_raw;
  std::string spki_raw;
  {
    std::shared_ptr<orm::Transaction> trans1;
    try {
      trans1 = co_await db->newTransactionCoro();
      co_await trans1->execSqlCoro(
          "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
          std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));

      auto res = co_await trans1->execSqlCoro(
          "SELECT device_id::text AS device_id, nonce_sha256, spki_public_key "
          "FROM ap_m1.consume_enrollment_challenge($1::uuid)", *normalized_enrollment);

      if (res.empty()) {
        rollback_quietly(trans1);
        co_return error_response("UNAUTHENTICATED", "challenge not found, expired or already spent", rid);
      }

      device_id = res.at(0)["device_id"].as<std::string>();
      stored_nonce_hash_raw = pg_bytea_to_bytes(res.at(0)["nonce_sha256"].as<std::string>());
      spki_raw = pg_bytea_to_bytes(res.at(0)["spki_public_key"].as<std::string>());

      if (!(co_await commit(std::move(trans1)))) {
        co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable; retry request", rid, true);
      }
    } catch (const orm::SqlError& e) {
      rollback_quietly(trans1);
      LOG_ERROR << "sql error step 1 state=" << e.sqlState() << " request_id=" << rid;
      co_return response_for_sqlstate(e.sqlState(), rid);
    } catch (const std::exception&) {
      rollback_quietly(trans1);
      co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
    }
  }

  // -------------------------------------------------------------
  // Backend validation: NO database transaction is held open
  // -------------------------------------------------------------
  Sha256 computed_nonce_hash = sha256_bytes(nonce_b64url);
  if (std::string_view(reinterpret_cast<const char*>(computed_nonce_hash.data()), 32) != stored_nonce_hash_raw) {
    co_return error_response("UNAUTHENTICATED", "nonce does not match challenge", rid);
  }

  // Verify ECDSA signature over context + ":" + nonce or context + nonce
  const std::string msg_colon = std::string(kEnrollmentContext) + ":" + nonce_b64url;
  const std::string msg_nocolon = std::string(kEnrollmentContext) + nonce_b64url;

  bool verified = verify_ecdsa_p256_sha256(spki_raw, msg_colon, *sig_bytes);
  if (!verified) {
    verified = verify_ecdsa_p256_sha256(spki_raw, msg_nocolon, *sig_bytes);
  }
  if (!verified) {
    co_return error_response("UNAUTHENTICATED", "signature verification failed", rid);
  }

  // -------------------------------------------------------------
  // Step 2: Activate enrolled device in DB tx2
  // -------------------------------------------------------------
  const std::string token = generate_secure_token(32);
  const Sha256 token_hash = sha256_bytes(token);

  std::shared_ptr<orm::Transaction> trans2;
  try {
    trans2 = co_await db->newTransactionCoro();
    co_await trans2->execSqlCoro(
        "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));

    auto res = co_await trans2->execSqlCoro(
        "SELECT device_id::text AS device_id, "
        "to_char(expires_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS expires_iso "
        "FROM ap_m1.activate_enrolled_device($1::uuid, $2::bytea, 3600)",
        *normalized_enrollment, to_pg_bytea(token_hash));

    if (res.empty()) {
      rollback_quietly(trans2);
      co_return error_response("UNAUTHENTICATED", "device activation failed or expired", rid);
    }

    const std::string expires_iso = res.at(0)["expires_iso"].as<std::string>();

    if (!(co_await commit(std::move(trans2)))) {
      co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable; retry request", rid, true);
    }

    Json::Value token_doc;
    token_doc["device_id"] = device_id;
    token_doc["credential_token"] = token;
    token_doc["expires_at"] = expires_iso;

    co_return token_response(token_doc, rid);

  } catch (const orm::SqlError& e) {
    rollback_quietly(trans2);
    LOG_ERROR << "sql error step 2 state=" << e.sqlState() << " request_id=" << rid;
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const std::exception&) {
    rollback_quietly(trans2);
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

}  // namespace ma
