# Evidence: M1 Device Lifecycle & Enrollment HTTP Endpoints (E-02)

**Date:** 2026-10-31  
**Target:** Drogon C++20 HTTP Handlers with PostgreSQL Persistence  
**Final Merge Commit (`main`):** `154d401c2db1fc1dc74e11bef332f9b15b8fddcf`  
**PR #14 (`api` → `dev`):** https://github.com/methakon/Madalasa-Alarka/pull/14 (Merged)  
**PR #15 (`dev` → `main`):** https://github.com/methakon/Madalasa-Alarka/pull/15 (Merged)  

---

## 1. Scope & Implementation Overview

Seven core M1 device lifecycle endpoints were implemented in C++20 Drogon on branch `api` with PostgreSQL persistence conforming strictly to `docs/openapi-m1.yaml` and `docs/openapi.yaml`:

1. **`POST /v1/children/{childId}/pairing-codes`**
   - Validates parent principal session and child scope `PAIR_DEVICE`.
   - Prevents overlapping active codes (409 CONFLICT).
   - Generates unambiguous 10-character code (`23456789ABCDEFGHJKLMNPQRSTUVWXYZ`, excluding `0`, `O`, `1`, `I`).
   - Records idempotency key in `ap_m1.idempotency_records`.
2. **`POST /v1/enrollment`**
   - Validates Redeem schema, algorithm `ECDSA_P256_SHA256`, and minSdk >= 29.
   - Invokes `ap_m1.redeem_pairing_code` to issue enrollment challenge and cryptographic nonce.
3. **`POST /v1/enrollment/{enrollmentId}/proof`**
   - Implements two-transaction pattern: tx1 spends challenge via `ap_m1.consume_enrollment_challenge` and commits; verifies ECDSA P-256 SPKI proof out of transaction; tx2 activates device via `ap_m1.activate_enrolled_device`.
   - Returns bearer `DeviceToken` with fingerprint and generation.
4. **`POST /v1/devices/{deviceId}/credential/challenge`**
   - Validates 43-character base64url SPKI key fingerprint against device's active key.
   - Issues renewal challenge via `ap_m1.issue_credential_renewal_challenge`.
5. **`POST /v1/devices/{deviceId}/credential/renew`**
   - Two-transaction renewal: spends challenge via `ap_m1.consume_renewal_challenge`, verifies signature over challenge nonce and SPKI, issues renewed credential via `ap_m1.issue_renewal_credential`.
6. **`POST /v1/devices/{deviceId}/health`**
   - Authenticates device token via `ap_m1.authenticate_device_credential`.
   - Sets session configuration `ap.device_id`.
   - Upserts health status into `ap_m1.device_health`, returning 202 QUEUED receipt.
7. **`POST /v1/devices/{deviceId}/locations:batch`**
   - Authenticates device principal; validates batch size (1..500 events).
   - Ingests batch via `ap_m1.ingest_location_batch`, returning 202 QUEUED receipt with `INBOX_COMMITTED`.

---

## 2. Test Execution & Verification

### CTest Suites (7/7 Passed)
```
    Start 1: core
1/7 Test #1: core .............................   Passed    0.01 sec
    Start 2: oidc
2/7 Test #2: oidc .............................   Passed    8.75 sec
    Start 3: jwks
3/7 Test #3: jwks .............................   Passed    0.39 sec
    Start 4: jwks_fetch
4/7 Test #4: jwks_fetch .......................   Passed    0.01 sec
    Start 5: crypto
5/7 Test #5: crypto ...........................   Passed    0.01 sec
    Start 6: device_endpoints
6/7 Test #6: device_endpoints .................   Passed    0.01 sec
    Start 7: oidc_http
7/7 Test #7: oidc_http ........................   Passed    0.34 sec

100% tests passed, 0 tests failed out of 7
```

### Full Database Test Suite (232 Tests)
```
Ran 232 tests in 77.260s
OK (skipped=10)
```

### Structural & Security Checks
- **OpenAPI M1 Structural Lint:** PASS (`14 M1 operations, 21 schemas, 14 unique operationIds`)
- **OpenAPI Full Lint:** PASS (`171 operations, 155 paths, 187 Figma screens, 120 conceptual tables`)
- **Production Auth Marker Gate:** PASS (`marker exclusion only, not OIDC acceptance`)
- **Branch Route Governance:** PASS (`api -> dev -> main`, zero docs leaked in PRs)
- **Documentation Validation:** PASS (`37 tests passed, 0 errors`)

---

## 3. Branch Promotion Flow Summary

1. `api`: Implementation and unit tests committed (`de58159`), synced with `origin/main` and `origin/dev`, pushed (`61ecee5`).
2. PR #14 (`api` → `dev`): All 5 CI workflows passed; merged into `dev` (`8661bb7`).
3. PR #15 (`dev` → `main`): All 7 CI workflows passed; merged into `main` (`154d401`).
4. Canonical documentation and evidence recorded directly on `main`.
