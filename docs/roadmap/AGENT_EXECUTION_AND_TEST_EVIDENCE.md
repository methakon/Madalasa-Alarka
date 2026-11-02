# Autonomous Coding Agent Execution & Test Evidence Contract

**Scope:** LOCAL synthetic development ONLY · Date: 2026-10-28 · **Status: instructions, NOT evidence of implementation.**

## Source of truth

- [262-task machine-readable DAG](LOCAL_TASK_GRAPH_2026-10-28.json) — immutable plan; dependency and acceptance IDs.
- [Human-readable roadmap](LOCAL_AGENT_DEVELOPMENT_ROADMAP_2026-10-28.md) — phase interpretation and Figma/DB/API links.
- [Separate deployment and Play plan](DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md) — never executed by local coding agent.
- Follow current SRS, security, India legal gates and latest owner business decisions. A Figma design is not an implemented endpoint.

## Standing authoring conventions (owner directive 2026-11-01)

These apply to every task, artifact, evidence file and commit:

1. **No automated-tool footprint.** Committed artifacts, evidence files, commit messages and metadata must not attribute work to an AI/automation tool or embed tool-identifying strings or co-author trailers. Record authorship and verification under the responsible human owner identity. Write evidence impersonally and descriptively.
2. **Figma design cross-check.** Before implementing or finalizing a task whose artifact affects a user-facing surface, data category, API contract or screen, reconcile it against the authoritative Figma sources — the [functional handoff](../ui/figma-functional-handoff/README.md) and the [Theme C UI contract](../ui/MADALASA_ALARKA_THEME_C_STORY_AND_UI_CONTRACT_2026.md) — and record a short "Figma design alignment" note in the evidence. A Figma screen is a design specification, never proof of an implemented/approved feature.


## Task selection and execution protocol

1. Record working git SHA, branch, tool versions, operating system and local synthetic seed; ensure no real family or child data.
2. Select the earliest NOT_STARTED task whose explicit depends_on list is entirely PASS with actual evidence. Independent phases may run in separate branches after prerequisites pass.
3. Read all task inputs (exact version), inspect existing code, and write test expectations BEFORE implementation; choose atomic changes.
4. Create branch local/<TASK-ID>-slug. Implement only target slice and negative security tests. Keep child-data/media/legal gates fail closed.
5. Run the focused tests, full affected integration tests, compiler/static checks and negative auth tests. Never record a passing test that was not run.
6. Review code diff, leakage, API contract, DB migration and UI/Figma traceability. Capture command/exit code, environment, redacted log and actual commit SHA.
7. If PASS, write evidence/local/tasks/<TASK-ID>.md, update execution-status ledger and create reviewable commit/PR. If FAIL, fix or report FAILED_TEST.
8. If legal/Google Play/physical-device prerequisite is missing, record BLOCKED_EXTERNAL or BLOCKED_ENVIRONMENT, with reason/owner; continue only graph-independent work.

**Do not mark planning DAG tasks PASS in the task graph itself.** Add docs/roadmap/LOCAL_TASK_EXECUTION_STATUS.json on first governance step; all 262 begin NOT_STARTED. Its updates require evidence files, not assistant claims.

## Task states

| State | Meaning | Satisfies dependency? |
|---|---|---|
| NOT_STARTED | Planned only | No |
| IN_PROGRESS | Actual change under development | No |
| PASS | Acceptance tests run; exact evidence committed | Yes |
| FAILED_TEST | One or more checks fail | No |
| BLOCKED_ENVIRONMENT | SDK, disposable physical phone or local resource absent | No |
| BLOCKED_EXTERNAL | Owner, counsel, Google, vendor or platform dependency absent | No |
| SKIPPED_CONDITIONAL | Research feature excluded and OFF with denial tests | Only if graph explicitly bypasses it |
| REVIEW_REQUIRED | Sensitive decision awaits human sign-off | No |

Conditional physical-device milestones L05-011, L09-009 and L18-012, and media research phase L16 can be bypassed for unrelated local coding by explicit graph edges. Their missing evidence still blocks any claim of FULL production readiness.

## Evidence file template

Each evidence/local/tasks/LNN-NNN.md needs: task ID, actual commit SHA, UTC run timestamp, exact OS/JDK/Android API/OEM/Postgres version, changed files, reference doc commits, executable command(s), true exit code, sanitized output path, fixture version, test ID/expected/observed and PASS/FAIL, security reviewer, unresolved issue/correct owner. Never prepopulate PASS or fake reviews. Store no developer-account ID, personal Gmail token, real child names, GPS, media binary, purchase token, API keys or identity documents.

## Current executable baseline vs future commands

- EXISTING: python3 backend/tests/lint_openapi_m1.py docs/openapi-m1.yaml
- EXISTING: backend/persistence/migrations/0001_m1_identity.sql and backend/tests/m1_tenant_isolation.sql (must run on disposable PostgreSQL as non-superuser with ON_ERROR_STOP=1).
- EXISTING: .github/workflows/m1-contract-and-tenant.yml.
- PROPOSED AFTER BOOTSTRAP: ./gradlew :madalasa:assembleDebug :alarka:assembleDebug and respective JVM/instrumentation test tasks.
- PROPOSED AFTER BOOTSTRAP: cmake -S backend -B build/backend && cmake --build build/backend && ctest --test-dir build/backend --output-on-failure.
- PROPOSED AFTER BOOTSTRAP: docker compose -f infra/local/compose.yaml up -d --wait, full OpenAPI validator, migration replay, E2E and admin test suite.

Do not claim proposed scripts or C++/Gradle builds already exist. Never run migrations on a production database. Clean temporary fixture DB only if uniquely marked disposable.

## Security and policy invariants

- Separate ParentBearer, DeviceBearer and AdminBearer. Check Google OIDC issuer/audience/sub/expiry, device proof, family/child authorization and revoke epochs server-side. A billing family is not a guardian permission grant.
- Blended families: never auto-share all children with another spouse/parent. Child-specific Google Family Link parent-role verification API is not confirmed; stub must deny sharing until lawfully verified. Google Sign-In alone authenticates identity only.
- Trial 48 hours once per family with privacy-respecting anti-repeat. Free parent sees at most last six hours history, which is a query-access window not approved infinite retention.
- Target public prepaid ₹99 monthly / ₹999 yearly; first 1,008 distinct paid founding families target ₹50/₹500 for their eligible paid children. No auto-renew; actual checkout prices/Play offer configuration override marketing mock values.
- One concurrent PREMIUM viewer per active paid child; +₹100 one-time for +1 slot lasting independently 100 calendar days, +30 total combined A/V minutes per eligible child, shared among approved guardians. Base prepaid expiry pauses premium use without deleting addon; day-100 expiry stays fixed.
- Owner's admin identity securely bootstrapped from verified Google sub, not posted email. Other accounts NO_ACCESS until verified email/profile, owner approval, assigned role. Owner administration NEVER includes raw child GPS/history/routes/media/private messages.
- Preserve Android visible monitoring disclosure, identifying icon, persistent notification, truthful permission and device-capability states. No covert mic/camera, no OS permission bypass, no false successful capture.
- Synthetic-only test data before India DPDP/guardian/privacy approval. No real Play purchases, payout interactions, OCI provisioning or production API calls.

## API, database and Figma consistency checks

Before endpoint implementation, reconcile narrow M1 docs/openapi-m1.yaml vs 47-path whole docs/openapi.yaml; ensure one unique operationId, documented auth scopes, explicit responses and negative schema vectors. Never return 200 on unsupported media commands.

Before DB migration, compare 112 **conceptual** Figma entities with existing M1 executable SQL; implement only justified tables, composite child/family constraints, forced RLS, indexes, migration/rollback and tenant test. 112 does not mean 112 must ship at once.

Before Android/web UI, inspect Theme C Figma screen registry, reference screenshots and latest UX decisions. English now, resource-based translations later. Screens must represent actual server auth/entitlement/status, not icons that imply unavailable features.

## Mandatory testing

Use C++ unit/integration/property/ASAN/UBSAN, SQL RLS/recovery, Android JVM/emulator/physical-OEM, API contract-negative/authorization, billing refunds/replay, fake time 100-day expiry, account deletion vs offline GPS/backup, admin OAuth spoofing/FAQ XSS/ticket isolation, security scans/SBOM and synthetic ingestion/viewer stress.

**Each feature must have at least one unauthorized/error/denied case**. Failure-while-offline, concurrent races, malformed tokens, refund and revocation must be tested. Do not remove failed tests to obtain green.

## Exit and strict separation

Produce LOCAL_READY / LOCAL_BLOCKED / NOT_READY with actual test evidence. Do not claim that legal/Play review or physical tests succeeded unless witnessed and logged. Deployment, developer-account verification, 12-tester closed testing, vendor contracts, signing/upload and Play public rollout are covered only by the separate plan and require human decisions. The coding agent MUST NOT execute them automatically.
