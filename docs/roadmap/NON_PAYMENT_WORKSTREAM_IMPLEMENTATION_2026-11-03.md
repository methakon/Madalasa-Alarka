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
