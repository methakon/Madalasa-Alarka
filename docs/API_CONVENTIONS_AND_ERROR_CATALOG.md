# API conventions and error catalog (M1, v1)

**Status: engineering baseline, not owner-approved.** It binds the C++ backend, the Madalasa (parent) app and the Alarka (child) app to
one behavior so none of them invents its own. It closes the M1 part of audit finding AG-026 ("no unified error catalog").
The machine-checked part lives in [`openapi-m1.yaml`](openapi-m1.yaml) and is enforced by
[`lint_openapi_m1.py`](../backend/tests/lint_openapi_m1.py); the rest is a rule for implementers, with the tests that must prove it
listed in section 11. Related: [Technical specification §7](phases/M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md),
[device credential lifecycle](M1_DEVICE_CREDENTIAL_LIFECYCLE.md).

Words in capitals (MUST, SHOULD) are requirements on the implementer, meant as in RFC 2119.

## 1. Transport

| Rule | Value |
|---|---|
| Scheme | HTTPS only. The contract's server URL is a placeholder until the India-region domain is approved. |
| Body | `application/json`, UTF-8. Any other content type returns `400 INVALID_REQUEST` (the error set stays small; no 415). |
| Body size limit | **64 KiB** for every M1 request. The largest legitimate M1 body is the capabilities report (its feature map is capped at 8 KiB in the database). Over the limit returns `413`. Proposed; revisit in M2 when location batches arrive. |
| Request timeout | Server closes a request that has not finished arriving after 10 s. Client timeouts: connect 10 s, total 30 s. |
| Unknown request fields | Rejected (`additionalProperties: false`, returns `400 INVALID_REQUEST`). |
| Unknown **response** fields | Clients MUST ignore them (see section 9, this is how the API can grow without a new version). |
| Unknown **enum values in responses** | Clients MUST treat them as "unknown", never crash (new states will appear). |

## 2. Naming

- URLs: lower-case, plural nouns, hyphens (`/pairing-codes`). IDs in paths are UUIDs. Verbs only for the two credential actions (`/credential/challenge`, `/credential/renew`).
- JSON fields: `snake_case`. Enum values: `SCREAMING_SNAKE_CASE`. Booleans read as facts (`is_device_owner`, `charging`).
- Units go in the name when not obvious: `expires_in_seconds`, `battery_percent`. Durations are integers in seconds.
- `operationId` is `lowerCamelCase`, unique, and a fixed list in the linter (adding an operation is a deliberate, reviewed change).

## 3. Identifiers and formats

| Thing | Format | Notes |
|---|---|---|
| IDs | UUID, lower-case hyphenated (`format: uuid`) | **Server-generated** (`gen_random_uuid()`). Clients never choose a resource ID. The only client-chosen UUID is the `Idempotency-Key`. Sequential or guessable IDs are not used. |
| Timestamps | RFC 3339, **UTC with `Z`**, at most millisecond precision (`2026-10-28T03:22:05.123Z`) | Responses always use UTC. Requests with an offset are accepted and normalized to UTC. Never send local time, epoch numbers or date-only values. |
| `observed_at` vs `recorded_at` | `observed_at` is the **device's clock**, `recorded_at` is the **server's** | The device clock is untrusted. A report with `observed_at` more than 5 minutes in the future returns `422 VALIDATION_FAILED`. Both values are stored. Server time is the authority for expiry, ordering across devices and retention. |
| Expiry (`expires_at`) | Server time | Clients renew early (see credential lifecycle C-01) rather than comparing with their own clock to the second. |
| Binary data | **base64url, no padding** (`*_base64url`) | Nonces, signatures, key fingerprints. See gap G-4 for the one field that differs. |
| Enums | Closed list in the contract | Adding a value is a compatible change (section 9). |
| Money, locations | Not in M1 | Reserved: money in integer minor units plus currency; coordinates as decimal degrees WGS84 with `accuracy_m`. |

## 4. Headers

| Header | Direction | Rule |
|---|---|---|
| `Authorization: Bearer …` | request | Parent: OIDC token (historical M1) or 64-hex opaque session token (V2 default). Device: the short-lived device credential. Never in the URL or logs. |
| `Idempotency-Key` | request | Required on `createFamily`, `createChild`, `issuePairingCode` (section 6). A new UUID per logical action, reused unchanged on every retry of that action. |
| `X-Request-Id` | **every response** | Server-generated UUID. Equals `Error.request_id` on failures. Clients log it and show it in "contact support". A client-supplied value is ignored (prevents log injection). |
| `Retry-After` | `429`, may be on `503` | Integer seconds. Clients MUST wait at least this long. |

## 5. Errors

### 5.1 Envelope (same for every non-2xx)

```json
{ "code": "NOT_FOUND", "message": "Resource not found.", "request_id": "0b9c…", "retryable": false }
```

- `code`: stable, from the catalog below (an enum in the contract). **Clients branch on `code`, never on `message` or on the HTTP status alone.**
- `message`: short English text for developers and logs. Not localized, not for display, at most 300 characters. It MUST NOT contain secrets, tokens, nonces, signature data, other tenants' identifiers or anything that explains *why* an authentication or authorization decision failed.
- `retryable`: whether repeating **the same request** may succeed later without changing it.
- No stack traces, SQL text, internal hostnames or per-field details that could leak data. (Field-level validation hints are a possible later addition and need a privacy review first.)

### 5.2 Catalog

| HTTP | `code` | `retryable` | Use when | Client action |
|---|---|---|---|---|
| 400 | `INVALID_REQUEST` | false | Malformed JSON, wrong content type, unknown field, wrong type, bad path or header value | Bug in the client. Do not retry. |
| 401 | `UNAUTHENTICATED` | false | Missing, expired, revoked or invalid credential, **or any device proof failure** | Parent app: sign in again. Child app: run the renewal flow once; if that also fails, show "re-pair needed". |
| 403 | `FORBIDDEN` | false | The caller can already see the object but lacks the required scope (for example `REVOKE_CHILD_DEVICE`) | Show "no permission". |
| 404 | `NOT_FOUND` | false | Object does not exist **or is hidden from the caller** | Treat as absent. |
| 409 | `CONFLICT` | false (true if the conflict is "another identical request is still running") | State conflict (for example revoking a pairing that is no longer pending) | Re-read state, then decide. |
| 409 | `IDEMPOTENCY_KEY_REUSED` | false | Same `Idempotency-Key` sent with a **different** request body | Bug in the client. Use a new key for a new action. |
| 410 | `CODE_EXPIRED_OR_USED` | false | A one-time pairing code or enrollment challenge is expired or already used | Parent app issues a new code. |
| 413 | `PAYLOAD_TOO_LARGE` | false | Body over 64 KiB | Bug in the client. |
| 422 | `VALIDATION_FAILED` | false | Well-formed but out of range or unsupported (unsupported Android API, `observed_at` too far in the future) | Fix the value. |
| 429 | `RATE_LIMITED` | **true** | Quota exceeded | Wait `Retry-After`, then retry (section 7). |
| 500 | `INTERNAL_ERROR` | false | Unexpected server fault. Not listed per operation in the contract; it can always happen. | Retry **once** only if the operation is idempotent; otherwise surface an error. |
| 503 | `SERVICE_UNAVAILABLE` | **true** | Dependency down or server overloaded or shutting down | Back off and retry (section 7). |

Reserved, **not yet in the contract**: `426 UPGRADE_REQUIRED` (client too old, see section 9) and `409 STALE_REVISION` (optimistic concurrency, from M2).

### 5.3 Which status to choose (decision rules)

1. **Not authenticated?** `401`. For device proof failures, unknown or revoked devices, and used or expired challenges on the **anonymous credential routes**, return the *same* `401` (or the same `404` where the contract says "not distinguished"). The database functions return no row for all these cases, so the backend cannot and must not tell them apart.
2. **Authenticated but the object is in another family, or another child outside the caller's grants?** `404`, never `403`. A `403` would confirm the object exists.
3. **Authenticated, the object is visible, but the action scope is missing?** `403`.
4. **Syntax or shape wrong?** `400`. **Shape right, value unacceptable?** `422`.
5. Check order: quota (429, before any database work) → size (413) → syntax (400) → authentication (401) → object visibility (404) → scope (403) → state (409/410) → value rules (422).
6. Anything not listed per operation in the contract is a bug unless it is `500`.

**P-1 decision status:** Security choice documented in the register; implementation committed on the `api` branch and **P-1 runtime/DB integration evidence not yet verified as of this document revision**. Existing migrations remain immutable; any pairing-code response previously stored by an older synthetic build must be scrubbed or the test database recreated before a real deployment. No live child enrollment or public release authorized.

## 6. Idempotency

A mobile client WILL retry after a lost response. A retry must not create a second family, child or pairing code.

**Rule.** The three create operations require `Idempotency-Key: <uuid>`. The server retains, for each (caller, route template, key), the request digest and (except sensitive results) the original response for **24 hours**. **P-1 security exception:** `issuePairingCode` must not persist or replay a one-time secret; same completed request returns `409 CONFLICT`, with no regenerated code. Changed child path ID is part of its request digest; different child/body under an existing key returns `409 IDEMPOTENCY_KEY_REUSED`. A new key before existing code expiry returns `409 CONFLICT` without forced rotation.

| Situation | Result |
|---|---|
| First request with this key | Processed normally; response stored. |
| Same key, same body, original finished | Non-secret creates: stored status and body. **One-time pairing code (P-1): `409 CONFLICT`, never return the secret again**. No second row. |
| Same key, same body, original still running | The second request **waits** (database `lock_timeout` 5 s). When the first commits it sees the same outcome as a completed replay (**P-1 pairing: `409 CONFLICT`**); if it rolls back the waiting caller may become `NEW`. If a lock timeout occurs: `409 CONFLICT` with `retryable: true`. |
| Same key, different body | `409 IDEMPOTENCY_KEY_REUSED`. |
| After 24 hours | Key forgotten; treated as new. |

**Every M1 operation, one by one:**

| Operation | Retry behaviour |
|---|---|
| `listFamilies`, `listChildren`, `getChild`, `listChildDevices` | Safe, repeat freely. |
| `createFamily`, `createChild`, `issuePairingCode` | `Idempotency-Key` (above); **`issuePairingCode` uses P-1 no-secret replay exception**. |
| `revokeDevice` | Idempotent by nature: revoking an already revoked device returns `204` again. |
| `recordCapabilities` | The natural key is (device, `observed_at`). A repeat returns `202` with a `Receipt` whose `state` is `ALREADY_RECORDED`. |
| `recordHealth` | One current row per device. A report older than the stored one is acknowledged with `202` and `ALREADY_RECORDED` and does not overwrite. |
| `redeemEnrollmentCode` | **Single use by design.** If the response is lost the code is spent: the parent app issues a new code. The orphaned pending device is removed by the purge job (7 days). |
| `finishEnrollmentProof` | **Single use.** If the response is lost *after* activation, the token is unrecoverable (only its hash is stored) but the device is already ACTIVE: it runs the **credential challenge and renew** flow to obtain a token. If that fails, re-pair. |
| `requestCredentialChallenge` | Not idempotent; each call makes a new challenge (at most 5 open per device). |
| `renewDeviceCredential` | Challenge is single use. If the response is lost, request a new challenge and renew again (this revokes the token the device never saw). |

## 7. Retry and backoff (client rules)

- Retry only when the response says `retryable: true`, or when there was **no response** (timeout, connection reset) **and** the operation is safe or idempotent per section 6.
- Back off exponentially with full jitter: wait a random time between 0 and `min(60 s, 1 s × 2^attempt)`. At most 5 attempts per action.
- If `Retry-After` is present, wait at least that long instead (it overrides the computed delay when larger).
- Never retry `400`, `401` (except the one renewal described above), `403`, `404`, `409 IDEMPOTENCY_KEY_REUSED`, `410`, `413`, `422`.
- On Android, retries run in `WorkManager` with network constraints, so battery cost stays bounded. No retry loops in a foreground service.

## 8. Pagination

- M1 collections are small and bounded, so they return the complete list: `{ "items": [ … ] }`. Proposed caps, enforced when the create operations are implemented: 20 children per family and 10 active devices per child. A cap breach returns `422 VALIDATION_FAILED`.
- **Every future collection that can grow** (trips, locations, audit, usage) MUST paginate with an opaque cursor:
  request `?limit=50&cursor=<opaque>` (`limit` default 50, maximum 200); response `{ "items": [ … ], "next_cursor": "…" }` with `next_cursor` absent on the last page.
- Order is stable and total (for example `observed_at DESC, id DESC`). The cursor encodes the last key, never an offset, so new rows cannot shift pages. Clients MUST NOT parse a cursor. An invalid or expired cursor returns `400 INVALID_REQUEST`.
- Time-range queries require both bounds and a maximum window (to be set per endpoint). Adding `next_cursor` to an existing list is a compatible change.

## 9. Versioning and deprecation

- Major version is in the URL: `/v1`. The contract file carries `1.0.0-m1-draft` until the owner declares a release.
- **Compatible changes (no new major version):** new endpoint; new optional request field; new response field; new enum value in a response; new optional header; a new error `code` only for a **new** failure that previously had no code. Clients already ignore unknown response fields and values (section 1).
- **Breaking changes (need `/v2`):** removing or renaming a field, path or operation; making an optional field required; changing a type, format, unit or meaning; tightening limits that valid clients already exceed; changing a status code or `code` for an existing failure.
- **Deprecation process:** announce in the changelog and in `docs/`; from that day the server adds `Deprecation: true` and a `Sunset: <HTTP-date>` header (RFC 8594) to the affected responses. **Proposed minimum overlap: 6 months** between a new major version being available and the old one being switched off, because installed Android apps update slowly.
- **Client too old:** the server MAY answer `426 UPGRADE_REQUIRED` for a version below the supported floor (reserved, not yet in the contract). The child app must show a clear "update Alarka" state, never fail silently.
- A version-mismatch test (old client against new server, new client against old server) is required from M2, once there are two released builds.

## 10. Security rules that touch the API shape

- Authentication failures and "not found" never reveal which of several reasons applied (section 5.3). Timing of the anonymous credential routes should not differ by reason either.
- Tokens, nonces, signatures and pairing codes never appear in URLs, logs, error messages or analytics.
- Rate limiting (credential lifecycle C-02) happens before authentication and database work, and returns `429` with `Retry-After`.
- The API never accepts a family, child or device ID in a body as proof of rights; the authenticated identity decides (database context `ap.family_id`, `ap.principal_id`, `ap.device_id`).

## 11. How this is enforced

**Now (automatic, in CI):** the OpenAPI linter requires: `Error.code` equals the 12 catalog codes; every response declares `X-Request-Id`; every `429` declares `Retry-After`; the three create operations take `Idempotency-Key`; every non-2xx response uses the shared `Error` schema and declares `x-error-codes` that its status allows (G-6); each operation lists only errors it can return; `410` only where a one-time code or challenge exists.

**To write with the backend (tests, before M1 sign-off):**
1. Every error response body validates against `Error` and its `request_id` equals the `X-Request-Id` header.
2. Idempotency: replay, concurrent duplicate, changed body, expired key.
3. Anonymous credential routes: unknown device, revoked device, wrong fingerprint, bad signature and used challenge give identical status, body shape and (within tolerance) timing.
4. Client contract tests in Kotlin generated from the contract: unknown response field and unknown enum value are ignored.
5. `observed_at` too far in the future is rejected; a duplicate capabilities report returns `ALREADY_RECORDED`.

## 12. Known gaps between this document, the contract and the database

| ID | Gap | Recommendation |
|---|---|---|
| G-1 | ~~No table stores idempotency keys.~~ **Closed** by migration `0004_m1_idempotency.sql` (tests `m1_idempotency.sql` ID_01-ID_11 and `m1_idempotency_concurrency.sh`). Claim, create and record happen in one transaction; a rolled-back create leaves no claim; a committed claim without a result (`PENDING`) is a backend bug and is answered `500 INTERNAL_ERROR`. | Handlers must call `idempotency_claim` first and `idempotency_record` last in the same transaction. |
| P-1 | **RESOLVED — 2026-10-31 / conservative no-secret replay:** `issuePairingCode` returns a one-time secret only in the initial successful `201`. Idempotency records set `body_omitted=true` and never retain the raw code; request digest binds the childId, canonical body and requested TTL. A same-key, same-child, same-body replay returns **409 CONFLICT**, never another code or a stored secret; a different request/child with the same key returns **409 IDEMPOTENCY_KEY_REUSED**. | After a lost first response, retain the same key only to determine it was already attempted; use the original displayed code if available, otherwise wait for the unredeemed code's expiry (up to requested 60–600 seconds) before a new logical action with a new key. Never silently invalidate an existing usable code. This is an explicit, documented secret-bearing exception to generic 201-body replay, not a claim that the API returned a 201. Scope must be revalidated on every retry. [API code](https://github.com/methakon/Madalasa-Alarka/blob/api/backend/src/pairing.h). |
| G-2 | `ALREADY_RECORDED` for capabilities needs a uniqueness rule; `capability_snapshots` has none. | Add a unique constraint on (device, `observed_at`) in a migration. |
| G-3 | Technical specification §7 calls for a stable `event_id` on device observations; M1 `Health` and `Capabilities` have none. | Use (device, `observed_at`) in M1; add `event_id` when batches arrive in M2. |
| G-4 | `public_key_spki_base64` is standard base64; every other binary field is base64url. | Decide **before the first client is built** (renaming later is a breaking change). Recommended: switch to base64url. |
| G-5 | `redeemEnrollmentCode` and `finishEnrollmentProof` declare separate `404`, `409` and `410` outcomes, but the database functions return no row for unknown, used, expired and exhausted alike, so the backend cannot produce them. | Recommended: one status for all invalid-code cases (less information leaked). Alternative: have the functions return a reason, accepting a small oracle on pairing codes. Owner and security decision. |
| G-6 | ~~The linter did not check that each operation uses only the right `code` for each status.~~ **Closed.** Every non-2xx response in `openapi-m1.yaml` declares `x-error-codes`; the linter requires each to be allowed for that status (table in `lint_openapi_m1.py`, kept equal to section 5.2 and the C++ catalog by tests) and requires `IDEMPOTENCY_KEY_REUSED` on the 409 of the three retryable creates and nowhere else. | Handlers must return one of the declared codes; add a handler-level test when routes exist. |
| G-7 | Clock-skew and size-cap rules are not implemented anywhere yet. | Backend work item with tests 11.5 and the caps in section 8. |
| G-8 | **RESOLVED — 2026-10-31 / V2 server-controlled parent session bridge:** Identity, authority and child access are segregated. `POST /v1/auth/parent/google` validates Google ID token and uses dedicated `ap_auth_issuer` credentials (`MA_PG_AUTH_USER`/`MA_PG_AUTH_PASSWORD`) to exchange for a PostgreSQL-generated 256-bit CSPRNG token (64 hex characters) stored only as SHA-256 in `ap_m1.trusted_sessions` with token replay prevention via `oidc_credential_sha256` unique constraint. Live sessions per adult are capped at 10. `DELETE /v1/auth/session` atomically revokes the presented session. Runtime role `ap_m1_api` cannot mint sessions or resolve identities. Configurable via `MA_PARENT_AUTH_MODE` (`v2_session` default vs `m1_direct_oidc`) and `MA_PARENT_SESSION_TTL_SECONDS` (default 3600, range 300..43200). Verified by `test_parent_session_bridge.py` and `integration_parent_session_v2.py`. | Documented in `docs/openapi.yaml`, deployment runbook and V2 migration 0021. |

Two contradictions found while writing this were fixed in the contract: the credential challenge no longer returns a separate `422` for a wrong key fingerprint, and renewal no longer returns `404` for unknown devices (both would have revealed whether a device exists).
