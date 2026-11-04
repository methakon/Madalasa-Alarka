# Privacy job API supplement — child erasure and export requests

**Date:** 2026-11-03 · **Engineering state:** `api` branch implementation pending integration and real-data legal review · **Data permitted in tests:** synthetic / approved adult test only.

This is a narrow implementation supplement to `docs/openapi.yaml`. The canonical OpenAPI master has **not yet** been reconciled with these four `/v1` routes; do not declare full contract coverage until the schema is integrated and validated. Parent app's Privacy / Requests screen currently performs **read-only** job-status queries; submit buttons deliberately remain disabled.

## Authentication and scope

Every route requires a trusted *V2 parent session* (`Authorization: Bearer <opaque 64-char hex>`). Session resolution binds the invoking adult to PostgreSQL; URLs cannot supply the acting identity. The SQL functions use exact-child `MANAGE_CONSENT` authority, and read queries use request-owner predicates plus RLS; another adult or sibling must not discover whether a job exists. Invalid child UUIDs return 400, missing/invalid sessions return 401, and unauthorized child resources are concealed as 404. Responses are `Cache-Control: no-store`.

## Routes

| Method | Path | Request contract | Response and status |
|---|---|---|---|
| POST | `/v1/children/{childId}/erasure-requests` | JSON `{"confirm_child_erasure":true}`; header `Idempotency-Key` is a fresh UUID | **202**: `{"request_id":"<uuid>","child_id":"<uuid>","kind":"ERASURE","completed":false,"message":"..."}` |
| GET | `/v1/children/{childId}/erasure-requests` | Empty request body | **200** `{"child_id":"<uuid>","items":[{"request_id":"<uuid>","state":"<SQL state>","requested_at":"<timestamp>"}]}` |
| POST | `/v1/children/{childId}/export-requests` | JSON `{"approved_policy_id":"<uuid>"}`; policy must be an active approved `DATA_SUBJECT_EXPORT` rule | **202**: `{"request_id":"<uuid>","child_id":"<uuid>","kind":"EXPORT","completed":false,"message":"..."}` |
| GET | `/v1/children/{childId}/export-requests` | Empty request body | **200** `{"child_id":"<uuid>","items":[{"request_id":"<uuid>","state":"<SQL state>","requested_at":"<timestamp>"}]}` |

Mutation JSON bodies accept exactly the listed field. Erasure uses server-side idempotent `ap_m1.request_child_erasure(child, key)`; reuse of the same key for another child is forbidden. The export policy selector does **not** create/approve a retention policy; a missing approved policy fails closed.

### State semantics

- **202 Accepted** reports only a durable request receipt after the database transaction commits. It is not a deletion-completed receipt or file-ready export.
- Child erasure is staged across primary data, backup suppression, and external references. The existing `ap_m1.erasure_jobs`/`erasure_job_targets`/`erasure_evidence` and `ma_recovery.erasure_ledger` are authoritative; `child_erasure_tombstones` protect restored and offline data.
- The pure `privacy_lifecycle_policy.h` state machine is a testable abstract guard. **It is not itself a database worker or proof that backups were deleted.** Any conflict between the illustrative model and the migrated SQL state machine must be resolved in favor of verified SQL.
- GET lists at most 50 requester-owned results per child. No download URL or sensitive payload is returned. Production exports require a separately authorized, time-bounded file-delivery endpoint and reviewed retention policy.

## Test requirements before merger or deployment

1. Build Drogon from clean checkout, run C++ unit tests (`ctest`) including `privacy_lifecycle_policy`.
2. Disposable PostgreSQL16 + PostGIS migration chain. Create adult A/child A, adult B/child B, and a second sibling under family A. Validate request identity binding and RLS.
3. Negative tests: no bearer, revoked bearer, wrong sibling/cross-family UUID, invalid/duplicate idempotency key, absent approved export retention policy, malformed payload and oversized body. None should reveal child existence or write any job.
4. Positive erasure: authorised adult initiates one job, receives `202 completed:false`, can GET its own status; a retried key returns same job, while changed child is refused.
5. Deletion/backups: adult grants revoked before purge, durable tombstone survives restore, stale offline intake cannot recreate child history, partial jobs not labeled complete.
6. Approved export policy and eventual output require purpose/legal review; test that an unauthorised adult can neither request, list nor download another child.
7. Reconcile `docs/openapi.yaml`, parent `PrivacyGateway` DTO and handler response shape. Add HTTP-to-database tests and named CI evidence. **No Phase 15 task is marked PASS solely because these routes exist.**

## Relevant code

- `backend/src/privacy_request_endpoints.h` (new request handlers), `backend/src/privacy_endpoints.h`, `backend/src/main.cc`
- `backend/persistence/migrations/0010_erasure_audit_and_recovery.sql`, `0013_restore_quarantine_and_erasure_ledger.sql`, `0014_account_erasure_requests.sql`
- `backend/src/privacy_lifecycle_policy.h`, `backend/tests/cpp/privacy_lifecycle_policy_test.cc`
- `android/madalasa/src/main/kotlin/org/madalasa/madalasa/api/PrivacyGateway.kt` and `ui/navigation/MadalasaNavHost.kt`

**Release hold:** No real child's data or externally accessible export/deletion endpoints until independent purpose-specific Indian law, guardian authority, retention and Google Play review gates are complete. These gates are distinct from merchant and Play Billing activation.
