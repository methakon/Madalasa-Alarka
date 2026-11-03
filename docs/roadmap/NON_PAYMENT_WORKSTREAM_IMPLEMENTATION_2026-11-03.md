# Non-payment workstreams — implementation and verification record

**Date:** 2026-11-03 IST · **Scope:** local engineering only · **Release gate:** NO-GO for real-child processing or commercial use.

Owner request: implement **(1) admin and security, (2) parent Android core, (3) child Android setup and safety, (4) privacy and data management** without waiting for BillDesk, Play Billing or merchant approvals. This is an incremental code delivery, **not** a declaration that all L12–L15 tasks are finished.

## Branches, code and test evidence

| Track | Code ref (pending integration via `dev`) | Implemented in this slice | Verification |
| --- | --- | --- | --- |
| Admin web | `admin-web` at `ad9932f` | Challenge nonce comes from `/v1/admin/auth/challenge`; login posts exactly `id_token,nonce`; in-memory CSRF from server; privileged reload only from fresh session roles; server-side logout; owner decisions use actual revision; applicant DOB/address/gender fields removed | Nine source-contract invariants inspected; `admin-web/tests/security.test.mjs` extended. **Full npm build/test NOT RUN here.** |
| Admin/API bridge | `api` at `1df38c3` (subsequent code added on same branch) | `/v1/admin/access/me` returns `state/status`, server-session-derived `role_codes`, profile revision and conditional request-access affordance. Does **not** infer roles from Google email or client input | Static inspection. **Drogon build, SQL integration and test-owner review NOT RUN here.** |
| Parent Android | `parent` at `c10ac32` | Synthetic repository now rejects child IDs outside the selected adult's loaded families, refuses pairing for unlisted children, clears location/selection before a new request, clears caches when child list refresh or profile fails; adds `ChildRevocationGuardTest` | Regression tests committed; **Gradle/JUnit/instrumented tests NOT RUN here**. Backend grants/RLS remain authoritative. |
| Child Android | `child` at `5bea4f4` | `ChildPairingPolicy` requires disclosure acknowledgment and six ASCII digits explicitly entered; `ChildViewModel` enforces it; unpairing resets disclosure; JUnit regression tests committed | Equivalent policy compiled and executed with `kotlinc` + `java -jar` on JDK; **Gradle Android unit/device tests NOT RUN here**. Still a synthetic enrollment service, not real pairing proof. |
| Privacy erasure | `api` at `e5ff928` | Pure C++20 erasure coordinator state machine: request immediately denies reads; requires authority revocation then durable tombstone; generation-bound per-store receipts; cannot report completion early; restored items are suppressed; CMake test target registered | Equivalent standalone header/test verified with `g++ -std=c++20 -Wall -Wextra -Werror`: PASS. **Not wired to SQL, deletion workers, queues, APIs or backup recovery.** |

## Follow-up integration changes (same day)

- **Parent read-only job status:** `parent` now includes `PrivacyGateway.erasureRequests/exportRequests`, the requests-page navigation and unauthenticated negative tests. Submission buttons remain disabled.
- **Backend authenticated request routes:** `api` now includes four POST/GET child-scoped erasure/export routes, using existing reviewed PostgreSQL request functions and request-owner RLS. **202 means accepted request, not completed processing.** See [narrow API contract supplement](NON_PAYMENT_PRIVACY_API_CONTRACT_2026-11-03.md).
- **Branch reconciliation:** `api` was synchronized to the latest `main` as a two-parent merge commit, preserving all existing Phase 10 work while removing outdated `docs/**` differences; `dev` fast-forwarded to current documentation. Existing API PR #28 still includes Phase 10 work; do not merge billing changes without its independent tests.
- **CI findings:** Admin web and child Android checks passed on their initial PR heads. Parent Android CI caught two outdated test expectations; those tests were updated and require a new CI pass. API full C++/PostgreSQL checks and branch-route revalidation are pending. No unsupported claim of complete E2E acceptance.

## Parent verified HTTPS integration update

The `parent` branch now includes `HttpsMadalasaApiClient` and a verified-session actor accessor. With a configured HTTPS API origin it uses the real V2 parent session to obtain:

- GET `/v1/families`: authorized family identifiers, with server membership checks.
- GET `/v1/families/{familyId}/children`: DB grant/RLS-filtered child list.
- GET `/v1/children/{childId}`: exact-child existence/authority check before any location projection.
- POST `/v1/children/{childId}/pairing-codes`: UUID idempotency key and bounded requested TTL, parsed expiration.

**Missing server interface:** there is currently **no parent-facing latest-location GET handler** in the C++ server. The HTTPS client therefore returns `Freshness.UNAVAILABLE` and null latitude/longitude even after a child is authorized; `ShellScreen` explicitly renders "Location unavailable" instead of the previous synthetic `0,0` coordinates. No live location capability is claimed. A real parent location/history endpoint and legal/Android gate checks remain a separate integration task.

`DefaultAppContainer` selects the live HTTPS client when an origin is configured, uses mock fixtures only in debuggable builds with no API origin and fails closed in unconfigured non-debuggable builds. Successful Google P-04 handoff reloads the real repository; an attempted child selection cannot navigate to the child shell until a scoped read succeeds. The synthetic demo is hidden in a configured Google environment.

CI for these new transport/navigation changes still requires the parent Android Gradle suite and physical/HTTPS integration tests. No production account/child data was used.

## Child synthetic-enrollment release fence and CI

The `child` branch now contains `UnavailableAlarkaEnrollmentService` and a `DefaultChildAppContainer` injection rule: only debuggable builds instantiate `SyntheticAlarkaEnrollmentService`. Non-debuggable builds refuse pairing until Keystore-bound device proof, approved guardian authority, Android platform consent and backend enrollment are implemented and tested.

`ChildViewModel` no longer labels any successful synthetic operation as a live guardian connection; unsuccessful enrollment results are not turned into success, and a failed unpair request does not wipe local UI state or falsely claim revocation. The PairingScreen identifies mock enrollment as **synthetic preview** and shows test helper codes only in debuggable builds. The release fallback has an explicit JUnit denial test.

**CI checkpoint:** Admin-web synthetic checks and original child Android build/tests passed; parent Android CI (latest verified head before these doc changes) passed its compile/unit workflow including the authenticated family client. The final child-branch production-guard test run remains to be independently verified before merge. The API's M1 backend/test suite and branch-route CI passed after rebasing the effective code changes on the newer main docs; no production OAuth, actual child enrollment, HTTP-to-Postgres deletion/export or real-location endpoint has been end-to-end exercised by this record.

## Key fail-closed invariants

- An administrator's OIDC identity alone never supplies privileges; the server authorizes current roles from a live session. The frontend keeps CSRF proof only in process memory; the admin logout button invokes the server logout route and does not silently claim success.
- The parent app must not show one child's old coordinates after a different child is selected or after an authorization refresh fails. Client filtering is **defense in depth**: every backend read and mutation still requires live child-specific authorization and Row Level Security.
- A suggested six-digit pairing code on a mock screen is not consent, not a user-entered code and not permission to begin monitoring. Child setup must confirm acknowledgment before calling enrollment; server challenge, Keystore proof, OS permissions and guardian authorization are separate gates.
- An erasure request must revoke views immediately; job receipts belong to the exact deletion generation. A durable store tombstone and cross-store cleanup receipts are required before completion. Never treat a UI acknowledgment or a queued cleanup as erasure completed.

## Roadmap dependency correction

`LOCAL_TASK_GRAPH_2026-10-28.json` was amended **on `main` only** to remove the false `L11-014` prerequisite from `L12-001`, isolate paid-plan UI tasks `L12-008` and `L12-009` behind the correct billing milestones, move independent `L12-010` core UI off the paid chain, and remove `L14-013` payment reporting as a prerequisite for `L14-014` restricted non-payment administrative views.

All **262 task IDs and dependencies** were checked for existing references and acyclic order after the edit. No completed-task claims were added to the task status ledger.

## Required follow-up before merger or acceptance

1. **Sync work branches and resolve divergence, especially `api`.** Follow `AGENTS.md`, `docs/tools/sync_work_branch.sh <branch>` and clean worktrees; run code PRs into `dev`, and only after integrated review into `main`. Do not force-push another worker's work.
2. **Admin:** run `cd admin-web && npm ci && npm run test && npm run build`, then exercise challenge → real Google OIDC (approved adult test account) → applicant profile → verified contact → owner MFA approval → reload → revoke → logout. Verify same-origin CSRF, role removal, XSS denial and server audit. Do not equate source regex assertions with E2E authentication.
3. **Parent:** run `./gradlew :madalasa:testDebugUnitTest :madalasa:assembleDebug` and Android navigation/permission UI tests. Replace the synthetic API repository with a separately reviewed authenticated implementation; do not use sample data for authorized family claims.
4. **Child:** run `./gradlew :alarka:testDebugUnitTest :alarka:assembleDebug` and supported-owner-device checks. Verify no re-enrollment without visible acknowledgment and no monitoring grants in the synthetic manifest.
5. **Privacy:** run the C++/ctest target and full Drogon + disposable PostgreSQL suite. Implement a durable DB request/tombstone ledger, child-authority revocation, per-store delete workers, bounded authorized export, legal retention decisions and restored-backup suppression. Until then expose **no deletion-completed response**.
6. **Cross-workstream:** run authenticated parent/child/admin UI→API→SQL integration, unauthorized sibling/revoked-parent negative tests, concurrency/replay, accessibility and screenshots. Capture exact exit codes, commits, test fixtures and reviewer in `evidence/local/tasks/` before changing acceptance statuses.

## Current status and explicit exclusions

**Implemented:** isolated, reviewed-in-source safety and integration changes described above, with limited standalone toolchain evidence. **Incomplete:** entire L12/L13/L14/L15 phase acceptance, full Android app end-to-end implementation, SQL erasure integration, production OIDC, live device proof, payment sandbox, legal approval, Play release. Paid subscriptions, paid viewer add-ons and purchases remain independent and are not prerequisites for the non-payment core.

See `docs/roadmap/LOCAL_TASK_EXECUTION_STATUS.json` for the **authoritative unchanged phase task counts**, `AGENTS.md` for branch rules and the Play/India release gate documents for external approvals. These changes use no real children's information.
