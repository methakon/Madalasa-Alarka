// POST /v1/devices/{deviceId}/credential/challenge and POST /v1/devices/{deviceId}/credential/renew.
// Two-step pattern (M1 C-04): DB transaction 1 spends renewal challenge;
// signature verification occurs with NO DB transaction open; DB transaction 2 issues renewed credential.
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

inline constexpr const char* kRenewalContext = "amar-pola-m1-device-renew-v1";

// Handler for POST /v1/devices/{deviceId}/credential/challenge
inline drogon::Task<drogon::HttpResponsePtr> request_credential_challenge(
    drogon::HttpRequestPtr req, std::string device_id_param) {
  using namespace drogon;
  const std::string rid = request_id_of(req);

  if (req->body().size() > kMaxBodyBytes) {
    co_return error_response("PAYLOAD_TOO_LARGE", "request body too large", rid);
  }

  auto normalized_device = normalize_uuid(device_id_param);
  if (!normalized_device) {
    co_return error_response("INVALID_REQUEST", "deviceId must be a valid UUID", rid);
  }

  if (req->contentType() != CT_APPLICATION_JSON) {
    co_return error_response("INVALID_REQUEST", "content type must be application/json", rid);
  }

  Json::Value body;
  if (!parse_json_strict(req->body(), body)) {
    co_return error_response("INVALID_REQUEST", "malformed JSON", rid);
  }

  if (!body.isObject() || !body.isMember("key_fingerprint_sha256_base64url") ||
      !body["key_fingerprint_sha256_base64url"].isString()) {
    co_return error_response("INVALID_REQUEST", "body must be {\"key_fingerprint_sha256_base64url\": string}", rid);
  }

  const std::string fp_b64url = body["key_fingerprint_sha256_base64url"].asString();
  if (fp_b64url.size() != 43) {
    co_return error_response("VALIDATION_FAILED", "key_fingerprint_sha256_base64url must be 43 characters", rid);
  }

  auto fp_bytes = base64url_decode(fp_b64url);
  if (!fp_bytes || fp_bytes->size() != 32) {
    co_return error_response("VALIDATION_FAILED", "invalid key fingerprint encoding", rid);
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

  std::shared_ptr<orm::Transaction> trans;
  try {
    trans = co_await db->newTransactionCoro();
    co_await trans->execSqlCoro(
        "SELECT set_config('lock_timeout', $1, true), set_config('statement_timeout', $2, true)",
        std::to_string(db_limits().lock_ms), std::to_string(db_limits().statement_ms));

    // Check device existence and active SPKI key
    auto pk_res = co_await trans->execSqlCoro(
        "SELECT ap_m1.device_public_key($1::uuid) AS spki_public_key", *normalized_device);
    if (pk_res.empty() || pk_res.at(0)["spki_public_key"].isNull()) {
      rollback_quietly(trans);
      co_return error_response("NOT_FOUND", "device not found or not active", rid);
    }

    const std::string spki_raw = pg_bytea_to_bytes(pk_res.at(0)["spki_public_key"].as<std::string>());
    const std::string expected_fp = compute_key_fingerprint(spki_raw);
    if (expected_fp != fp_b64url) {
      rollback_quietly(trans);
      co_return error_response("NOT_FOUND", "device key mismatch", rid);
    }

    auto ch_res = co_await trans->execSqlCoro(
        "SELECT ap_m1.issue_credential_renewal_challenge($1::uuid, $2::bytea, $3::bytea, 300)::text AS challenge_id",
        *normalized_device, bytes_to_pg_bytea(*fp_bytes), to_pg_bytea(nonce_hash));

    if (ch_res.empty() || ch_res.at(0)["challenge_id"].isNull()) {
      rollback_quietly(trans);
      co_return error_response("RATE_LIMITED", "too many open renewal challenges for device", rid);
    }

    const std::string challenge_id = ch_res.at(0)["challenge_id"].as<std::string>();

    auto time_res = co_await trans->execSqlCoro(
        "SELECT to_char(expires_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS expires_iso "
        "FROM ap_m1.credential_renewal_challenges WHERE id = $1::uuid", challenge_id);
    const std::string expires_iso = time_res.empty() ? "" : time_res.at(0)["expires_iso"].as<std::string>();

    if (!(co_await commit(std::move(trans)))) {
      co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable; retry request", rid, true);
    }

    Json::Value challenge;
    challenge["challenge_id"] = challenge_id;
    challenge["device_id"] = *normalized_device;
    challenge["nonce_base64url"] = nonce_b64url;
    challenge["expires_at"] = expires_iso;
    challenge["challenge_context"] = kRenewalContext;

    auto resp = drogon::HttpResponse::newHttpJsonResponse(challenge);
    resp->setStatusCode(drogon::k201Created);
    resp->addHeader(kRequestIdHeader, rid);
    co_return resp;

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
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

// Handler for POST /v1/devices/{deviceId}/credential/renew
inline drogon::Task<drogon::HttpResponsePtr> renew_device_credential(
    drogon::HttpRequestPtr req, std::string device_id_param) {
  using namespace drogon;
  const std::string rid = request_id_of(req);

  if (req->body().size() > kMaxBodyBytes) {
    co_return error_response("PAYLOAD_TOO_LARGE", "request body too large", rid);
  }

  auto normalized_device = normalize_uuid(device_id_param);
  if (!normalized_device) {
    co_return error_response("INVALID_REQUEST", "deviceId must be a valid UUID", rid);
  }

  if (req->contentType() != CT_APPLICATION_JSON) {
    co_return error_response("INVALID_REQUEST", "content type must be application/json", rid);
  }

  Json::Value body;
  if (!parse_json_strict(req->body(), body)) {
    co_return error_response("INVALID_REQUEST", "malformed JSON", rid);
  }

  if (!body.isObject() || !body.isMember("challenge_id") || !body["challenge_id"].isString() ||
      !body.isMember("nonce_base64url") || !body["nonce_base64url"].isString() ||
      !body.isMember("signature_base64url") || !body["signature_base64url"].isString()) {
    co_return error_response("INVALID_REQUEST", "invalid renewal payload shape", rid);
  }

  auto normalized_challenge = normalize_uuid(body["challenge_id"].asString());
  if (!normalized_challenge) {
    co_return error_response("INVALID_REQUEST", "challenge_id must be a UUID", rid);
  }

  const std::string nonce_b64url = body["nonce_base64url"].asString();
  const std::string sig_b64url = body["signature_base64url"].asString();

  if (nonce_b64url.size() < 24 || nonce_b64url.size() > 200 ||
      sig_b64url.size() < 48 || sig_b64url.size() > 4096) {
    co_return error_response("VALIDATION_FAILED", "parameter length out of range", rid);
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
  // Step 1: consume renewal challenge in DB tx1 and COMMIT immediately
  // -------------------------------------------------------------
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
          "SELECT nonce_sha256, spki_public_key "
          "FROM ap_m1.consume_renewal_challenge($1::uuid, $2::uuid)",
          *normalized_device, *normalized_challenge);

      if (res.empty()) {
        rollback_quietly(trans1);
        co_return error_response("UNAUTHENTICATED", "renewal challenge not found, expired or already spent", rid);
      }

      stored_nonce_hash_raw = pg_bytea_to_bytes(res.at(0)["nonce_sha256"].as<std::string>());
      spki_raw = pg_bytea_to_bytes(res.at(0)["spki_public_key"].as<std::string>());

      if (!(co_await commit(std::move(trans1)))) {
        co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable; retry request", rid, true);
      }
    } catch (const orm::SqlError& e) {
      rollback_quietly(trans1);
      LOG_ERROR << "sql error renewal step 1 state=" << e.sqlState() << " request_id=" << rid;
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

  const std::string msg_colon = std::string(kRenewalContext) + ":" + nonce_b64url;
  const std::string msg_nocolon = std::string(kRenewalContext) + nonce_b64url;

  bool verified = verify_ecdsa_p256_sha256(spki_raw, msg_colon, *sig_bytes);
  if (!verified) {
    verified = verify_ecdsa_p256_sha256(spki_raw, msg_nocolon, *sig_bytes);
  }
  if (!verified) {
    co_return error_response("UNAUTHENTICATED", "signature verification failed", rid);
  }

  // -------------------------------------------------------------
  // Step 2: Issue renewed credential in DB tx2
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
        "SELECT to_char(ap_m1.issue_renewal_credential($1::uuid, $2::uuid, $3::bytea, 3600) AT TIME ZONE 'UTC', "
        "'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS expires_iso",
        *normalized_device, *normalized_challenge, to_pg_bytea(token_hash));

    if (res.empty() || res.at(0)["expires_iso"].isNull()) {
      rollback_quietly(trans2);
      co_return error_response("UNAUTHENTICATED", "renewal issuance refused", rid);
    }

    const std::string expires_iso = res.at(0)["expires_iso"].as<std::string>();

    if (!(co_await commit(std::move(trans2)))) {
      co_return error_response("SERVICE_UNAVAILABLE", "database commit unavailable; retry request", rid, true);
    }

    Json::Value token_doc;
    token_doc["device_id"] = *normalized_device;
    token_doc["credential_token"] = token;
    token_doc["expires_at"] = expires_iso;

    auto resp = drogon::HttpResponse::newHttpJsonResponse(token_doc);
    resp->setStatusCode(drogon::k201Created);
    resp->addHeader(kRequestIdHeader, rid);
    co_return resp;

  } catch (const orm::SqlError& e) {
    rollback_quietly(trans2);
    LOG_ERROR << "sql error renewal step 2 state=" << e.sqlState() << " request_id=" << rid;
    co_return response_for_sqlstate(e.sqlState(), rid);
  } catch (const std::exception&) {
    rollback_quietly(trans2);
    co_return error_response("INTERNAL_ERROR", "unexpected server error", rid);
  }
}

}  // namespace ma
