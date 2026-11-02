# M1 Drogon API implementation progress — 31 October 2026

> **Code branch:** [api](https://github.com/methakon/Madalasa-Alarka/tree/api), not merged into dev/main at this checkpoint. **Synthetic data only.** **Status:** 14/14 frozen M1 *route registrations*, **NOT** 14 release-verified API operations. This document is engineering evidence, not legal, Google Play or Android approval.
>
> **Frozen contract:** [docs/openapi-m1.yaml](../../../openapi-m1.yaml), 12 paths / 14 operations. **Broader planned API:** [docs/openapi.yaml](../../../openapi.yaml) has 155 paths / 171 planned operations, **not implemented as part of M1**. The [2026-10-28 Figma screen/API/DB audit](../../../audits/FIGMA_SCREEN_API_DB_AUDIT_2026-10-28.json) is a design snapshot, not proof of functioning API/DB integration.

## What was added on the api branch

| Frozen M1 operation | Runtime route | Workstream source | Current evidence |
|---|---|---|---|
| createFamily | POST /v1/families | \`backend/src/families.h\` | Previously implemented, synthetic end-to-end HTTP/PostgreSQL regression |
| listFamilies | GET /v1/families | \`backend/src/parent_reads.h\` | **Added:** V2 \`list_my_families\` read; negative auth/no-DB tests; V2 session-positive behavior not yet tested |
| createChild | POST /v1/families/{familyId}/children | \`backend/src/children_create.h\` | **Added:** strict alias/UUID/idempotency, scoped V2 \`create_child\` SQL, 201 replay, negative tests; V2 trusted session, DB integration still needed |
| listChildren | GET /v1/families/{familyId}/children | \`backend/src/children_read.h\` | Previously added: exact child RLS filter; offline/unauthorized negative tests; V2 session-positive test outstanding |
| getChild | GET /v1/children/{childId} | \`backend/src/parent_reads.h\` | **Added:** RLS-protected one-child read; path/auth/no-DB negatives; V2 positive integration pending |
| listChildDevices | GET /v1/children/{childId}/devices | \`backend/src/parent_reads.h\` | **Added:** \`VIEW_CHILD_DEVICES\` check and RLS filtering; returns capability/health time where present; V2 positives pending |
| issuePairingCode | POST /v1/children/{childId}/pairing-codes | \`backend/src/pairing.h\` | Existing endpoint hardened: P-1 no stored/replayed secret, child-bound idempotency hash, 60–600s TTL; *P-1 owner acceptance and concurrent replay DB/HTTP tests pending* |
| redeemEnrollmentCode | POST /v1/enrollment | \`backend/src/enrollment.h\` | Preexisting handler; proof/single-use/security still require complete integration review |
| finishEnrollmentProof | POST /v1/enrollment/{enrollmentId}/proof | \`backend/src/enrollment.h\` | Preexisting handler; no claim of release proof |
| recordCapabilities | POST /v1/devices/{deviceId}/capabilities | \`backend/src/device_capabilities.h\`, \`capabilities_validation.h\` | **Added:** DeviceBearer, strict schema/ranges/flag consistency and synthetic fixture C++ tests; permission from reported owner flag is NEVER elevated |
| recordHealth | POST /v1/devices/{deviceId}/health | \`backend/src/device_activity.h\` | Preexisting handler; corrected response to frozen M1 \`Receipt{id,state,recorded_at}\`, uses confirmed DB commit |
| revokeDevice | DELETE /v1/devices/{deviceId}/pairing | \`backend/src/device_revoke.h\` | **Added:** RLS read + exact child \`REVOKE_CHILD_DEVICE\` scope, existing V2 \`revoke_domain_device\` with transactional serialization, repeated 204; *currently also requires VIEW_CHILD_DEVICES*, which is a known stricter-than-contract limitation |
| requestCredentialChallenge | POST /v1/devices/{deviceId}/credential/challenge | \`backend/src/device_credentials.h\` | Preexisting, device-credential lifecycle tests |
| renewDeviceCredential | POST /v1/devices/{deviceId}/credential/renew | \`backend/src/device_credentials.h\` | Preexisting, key-proof and renewal lifecycle tests |

**Additional route:** \`POST /v1/devices/{deviceId}/locations:batch\` is present in the backend but is **NOT one of the 14 frozen M1 operations**. Treat its independent V2/India/Play/Android legality and integration as separate; do not increase the M1 verified count with it.

## Swagger UI added — developer-only OpenAPI renderer

The API branch now contains [local Swagger dev tooling](https://github.com/methakon/Madalasa-Alarka/blob/api/backend/scripts/swagger_dev.py), which renders both existing OpenAPI 3.1 files as separate views. **M1 only:** 14 contract operations, optionally executable against synthetic localhost backend with explicit opt-in. **Planned only:** 171 Figma-wide operations, always read-only. No production Swagger endpoint, no API-key storage, and no claim of implementation beyond the M1 route registry. [Full setup/security runbook](SWAGGER_OPENAPI_DEV_WORKFLOW_2026-10-31.md). [Latest Swagger integration CI](https://github.com/methakon/Madalasa-Alarka/actions/runs/41168787562) **PASSED** (3/3 jobs) at api SHA b1348c6. Source is on api only; live browser rendering and real-child/V2 issuer remain unverified.

## Changes / verification anchors

- Earlier branch baseline \`260bb09\`: passing [M1 API and tenant isolation](https://github.com/methakon/Madalasa-Alarka/actions/runs/41142223745).
- Added family/child reads and negative cases; corrected stale GET-families smoke test (it now requires \`401\`, while unknown paths remain \`404\`).
- Added capability ingestion and schema validation, secure device revocation route, synthetic child profile creation and health Receipt repair.
- [CI success at 7d48e57](https://github.com/methakon/Madalasa-Alarka/actions/runs/41143343437): workflow completed **SUCCESS** (C++ build/tests, synthetic HTTP, M1 DB and V2 lineage jobs). This checkpoint predates the additional route-registration assertion.
- Added [offline frozen M1 route coverage check](https://github.com/methakon/Madalasa-Alarka/blob/api/backend/tests/check_m1_route_coverage.py), registered in \`ctest\`. **VERIFIED**: the [api HEAD 0831367 M1 pipeline](https://github.com/methakon/Madalasa-Alarka/actions/runs/41143455623) completed **SUCCESS** across backend build/ctest (including route registration), M1 contract/tenant tests and V2 database-lineage checks. This is not a positive V2 trusted-session or real-child release test.
- Historical red workflows on intermediate commits reflected a now-corrected GET-families expectation and Drogon \`orm::Result\` construction error; **do not conceal failures or count an earlier failed SHA as green**.

## Gaps that still block a real-child/prod-ready E-02 close

1. **RESOLVED — V2 Trusted ParentOIDC Session Bridge Integrated (2026-10-31, PR #16):** Merged to `dev`. Server-controlled session bridge exchanges verified Google ID tokens for opaque 64-hex session tokens via dedicated database issuer role `ap_auth_issuer` (`exchange_parent_oidc_session`, V2 migration 0021). Stored exclusively as SHA-256 with token replay prevention (`oidc_credential_sha256`). Implements `POST /v1/auth/parent/google` and `DELETE /v1/auth/session`. Verified by `test_parent_session_bridge.py` and `integration_parent_session_v2.py`.
2. **Read/write integration tests:** Build executable HTTP tests against a fully converged V2 test database with two fabricated families, sibling, revoked guardian, distinct grants, expired consent, changed custody and stale session. Assert exact expected 200/201/204/401/403/404/409 paths and zero cross-tenant rows. Existing C++ unit tests and legacy M1 smoke do not prove V2 positive behavior.
3. **Scope mismatch to resolve:** \`revokeDevice\` currently needs both \`VIEW_CHILD_DEVICES\` (to resolve the path's device under RLS) and \`REVOKE_CHILD_DEVICE\`, while the frozen M1 contract names only \`REVOKE_CHILD_DEVICE\`. Resolve with a reviewed scoped lookup inside an appropriately least-privileged, versioned V2 SQL helper, with tests; do not bypass RLS.
4. **Pairing security:** concurrent issue/replay, active-code collision, expiry, 201-without-stored-secret, revoked issuer and historical synthetic idempotency table purging need real transactional HTTP tests. P-1 owner acceptance still missing; do not assume a documentation default is external approval.
5. **Response conformance:** validate actual JSON response shapes/status/header timestamps for every verb, unknown body fields, UTF-8, wrong roles, content types, data-size limits, transaction deadline and SQLSTATE mapping.
6. **Device revocation/idempotency:** test duplicate/concurrent DELETE on authorized two-family V2 data, credential invalidation, key records, command cancellation, active sessions, deny-on-revocation, retention holds and cross-tenant negative cases.
7. **Execution evidence:** API branch is not merged into dev; check [branch policy](BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md) and owner-approved PR/merge process. Documentation on main does not merge code.
8. **Release restrictions:** no real minor data, GPS/media, live family verification, production billing, Play deployment, signed build claims or actual Figma-workflow execution. X-02 Play families/location, G02 Indian child-data basis, GDPR/other territorial scope, Android device tests and X-04 privacy URLs are separate gates.

## UI / Figma alignment rule

The Oct 28 screen-by-screen Figma audit maps designs to the *wider* OpenAPI and database schema. Figma screens for maps/history, app usage, school arrival, subscriptions, admin support, SOS, remote media and trust/review journeys are **not evidence that those endpoints exist in M1**. New route additions beyond these 14 require the owning milestone contract, role/data-flow review, real source code, tests and a successful integration build; the broad 171-operation \`openapi.yaml\` is *planned*, not 171 coded APIs.

**Next coding priority (non-commercial, synthetic only):** V2 trusted-session issuer and end-to-end role tests; then correct revoke scope, add companion API client DTO tests, pairing replay/credential lifecycle tests and one proof-backed dev integration PR.
