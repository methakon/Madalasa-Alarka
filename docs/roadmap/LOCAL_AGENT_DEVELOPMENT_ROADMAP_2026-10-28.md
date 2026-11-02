# Madalasa–Alarka — Autonomous-Agent Local Development Roadmap

**Version:** 2026-10-28 / **Planning state:** IMPLEMENTATION ROADMAP, NOT AN IMPLEMENTATION / **Scope:** LOCAL DEVELOPMENT ONLY / **Project:** [Madalasa–Alarka](https://github.com/methakon/Madalasa-Alarka)

> **No AI or human engineering plan can guarantee “without any fail.”** This roadmap instead gives a deterministic, dependency-ordered execution protocol with testable acceptance, evidence capture, privacy stops, rollback and explicit human/Google/legal gates. A coding agent must report BLOCKED rather than fabricate completed functionality, signoffs, permission results or benchmarks.

**Authoritative machine-readable task graph:** [262 tasks / 20 phases](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/roadmap/LOCAL_TASK_GRAPH_2026-10-28.json). **Agent operating contract:** [AGENT_EXECUTION_AND_TEST_EVIDENCE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/roadmap/AGENT_EXECUTION_AND_TEST_EVIDENCE.md). **Deployment/Play release intentionally separated:** [DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/roadmap/DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md). **Source register:** [SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/roadmap/SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md).

## 1. Verified baseline and limits as at 28 October 2026

- Repository currently has **M1 identity SQL** (`backend/persistence/migrations/0001_m1_identity.sql`), M1 structural OpenAPI lint, SQL tenant-isolation test and CI workflow, 2 Kotlin domain-model files, Android icon/resources, Figma UI designs, complete domain/contract research and public policy drafts.
- **No working C++ Drogon backend, Gradle-built Madalasa/Alarka app modules, operational administrator web app or verified full integration is demonstrated by the repo tree**. Documentation/SQL scripts are not launch or build evidence. These tasks are NOT_STARTED pending independently logged execution.
- Two API scopes exist: 11-operation M1 contract `docs/openapi-m1.yaml` and large unimplemented whole-project `docs/openapi.yaml` (47 endpoint paths at review). Start with a narrow executable contract; do not generate 47 fake success handlers to satisfy a checklist.
- The conceptual Figma [database schema](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=92-2) has 112 proposed tables across 10 domains; **physical schema does not yet implement all 112**, and not every research entity must ship. Use migrations sliced by actual feature, not direct translation of the visual model into thousands of tables.
- Product client: Android-native Kotlin for OS permissions/UI/device policy, optional C++ native processing only with justified NDK tests; service: **C++20 Drogon + PostgreSQL/PostGIS**; admin: separate web application; maps/FCM/Play via sandbox adapters locally.
- Google Play: user reports an **active Personal developer account**; neither account creation date, verified device, payout profile, per-app production access nor actual closed-test eligibility was inspected. **Do not include Play developer account ID, token or payment secret in this repo**.
- **No real child data, family identity, external payment charge, camera/microphone/screen capture or production infrastructure** shall be touched by this LOCAL agent plan. Use adults/children with invented synthetic aliases, local fake identity, Play, FCM and media adapters until independently approved.

### Document authority / supersession order

1. **Owner's latest explicit decisions** (child-specific blended-family access, trial once, manual prepaid, 100-day add-on, one premium screen, admin Gmail owner) override contradictory historical price/trial passages **only as business intent**.
2. **Legal/Google Play/Android OS rules are external hard gates**; owner preference alone cannot enable data collection, parental relationship verification or background media capture.
3. Canonical SRS + technical architecture + security/consent + latest owner decision addenda + M1 OpenAPI + later domain specs.
4. Physical SQL migrations and executable contract tests govern **implemented behavior**. Figma/Eraser assets are designs; no code generation automatically implies security.
5. If two live sources disagree without signed owner/legal decision: create an ADR in blocker ledger and **STOP that affected feature** while continuing unrelated synthetic-only steps.

## 2. Dependencies, gates and agent orchestration

Each `LNN-NNN` is the smallest independently reviewable implementation slice. `depends_on` in JSON is a validated acyclic graph; the graph conservatively serializes within each phase but explicitly permits independent domain lanes to proceed in parallel after their true prerequisites pass. Conditional media research and missing physical-device evidence do NOT block unrelated local coding; they still block claims of release readiness. A knowledgeable agent may propose further parallel sub-branches, but may not remove privacy prerequisites. **Do not run a successor just because predecessor code exists: predecessor acceptance TESTS must PASS, with evidence.**

Task states: `NOT_STARTED → IN_PROGRESS → PASS`; also `BLOCKED_EXTERNAL`, `BLOCKED_ENVIRONMENT`, `FAILED_TEST`, `REVIEW_REQUIRED` and `SKIPPED_CONDITIONAL`. **Only PASS satisfies a dependency.** Conditional investigation may be SKIPPED_CONDITIONAL after a recorded scope decision and explicitly bypassed by graph edges; a blocked feature remains disabled in builds. A blocked physical-device proof must be reported in final local readiness, not hidden.

Before each task: check dependency evidence, inspect exact referenced docs, `git status --short`, create task branch, write minimal patch, tests including unauthorized/negative cases, record environment + commit SHA + command/exit code, submit PR/small atomic change. Do not commit secrets or personally identifying customer records. No free-form write access to external family Google accounts. A coding agent cannot click Play Console approval, falsely verify parent-child links or issue legal signoff.

### Local development environments to provision (not assumed existing)

| Component | Minimum reproducible target | Local proof |
|---|---|---|
| OS and repo | Linux/macOS with Docker/Podman, or Windows WSL2; clean checkout | git diff clean + tool versions logged |
| Android | Android Studio/CLI SDK, JDK pinned, Gradle wrapper, API 29–36 test matrix; target API **36** for new Play uploads as of Aug 31 2026 | `./gradlew :madalasa:assembleDebug :alarka:assembleDebug` **after modules exist** |
| Backend | C++20, CMake, pinned Drogon, OpenSSL; GoogleTest/Catch2 | `cmake -S backend -B build/backend && cmake --build build/backend && ctest --test-dir build/backend --output-on-failure` **after bootstrap** |
| Database | Disposable local PostgreSQL 16 + PostGIS, non-superuser application RLS role | migrate up; run `backend/tests/m1_tenant_isolation.sql` plus added migration/security suite |
| API | OpenAPI 3.1, validator, strict generated DTO type checks | existing `python3 backend/tests/lint_openapi_m1.py docs/openapi-m1.yaml`; add whole-project validation |
| Admin | local Node LTS application, locked dependencies; fake Google OIDC verifier in tests | unit/integration/UI tests; `npm ci` after project exists |
| Provider mocks | local fake Google Identity, FCM, Play purchase, map, device status, virtual clock | no internet/real Google billing needed for local E2E |
| Security evidence | redacted test logs, SBOM, compiler/sanitizer output, accessible UI screenshots | per-task `evidence/local/tasks/LNN-NNN.md` |

### Key stopping conditions and explicit options

| Decision / blocker | What agent may do locally | What agent MUST NOT do |
|---|---|---|
| Google Family Link child-parent attestation API NOT VERIFIED | Implement exact-child verification interface returning `VERIFICATION_UNAVAILABLE`; test fails closed | Treat Google Sign-In, surname, invite or shared family membership as verification |
| India under-18 consent and tracking restrictions / DPDP phased rules | Synthetic fixtures, denied-by-default ingestion, legal config flags | Process real children's location/usage/media, infer consumer exemption |
| Free 6-hour history vs account-lifetime retained GPS | Implement query visibility window and retention policy abstraction | Silently keep unlimited GPS indefinitely or delete older retained data prematurely |
| Chicago pricing vs India-first Mumbai preference | Local compose only; environment-agnostic config | Pick production region, publish DNS, provision cloud without owner/legal gate |
| Play prepaid/multi-seat model, founding cohort and ₹100/100-day addon | Test fake Play provider, idempotent purchase, 100-day independent entitlement | Charge cards, invent active SKUs, rely on auto-renew-only subscription add-ons |
| Media, screen capture, DPC controls | Implement disabled-flag DTO, explicit OS rejection, visible lab research only | Hidden capture, permission bypass, App Owner claim on standard Android |
| Admin Google owner and request approvals | Fake OAuth provider locally, verify owner `iss/sub` security and RBAC | Grant admin by posted email or allow child-private data to owner |
| Personal Play account active | Prepare permission checklist and test evidence | Claim closed test, AAB upload, production access or Google approval happened |

## 3. Scope and staged integration order

**Track A — launch candidate with hard gates:** visible child-safety enrollment, identity, 48h once-off intro, authorized GPS/live tracking and six-hour free view, quality-aware history/route/place/safety, prepaid plans and child seat selection, parent Theme C UI, admin read/service/FAQ, privacy erase/export. Every module still requires legal/Play eligibility before real child use.

**Track B — conditional/staged:** child's app usage/behavioral reports, device-owner app blocking, remote microphone/camera/photo/video, remote screen capture, files and unrestricted history. Keep OFF by default and label research or conditional; no billing unlocks a legally unavailable capability.

**Architecture cross-cut:** all reads/commands require distinct client audience, exact child identity and guardian scope, server-side billing entitlement when needed, child-specific parental verification (fail closed), device capability/permission and feature/legal gates. Redis/session admission not bypassable from mobile UI. All status is explicit: OBSERVED/STALE/UNKNOWN/UNSUPPORTED/PERMISSION_DENIED and never invented.

## 4. High-priority Figma and diagram handoffs

| Design family | Authoritative reference |
|---|---|
| Parent application 81-screen functional contract | [Parent & child index](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/figma-functional-handoff/README.md) and [Figma project](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli) |
| Theme C pan-Indian Markandeya Purana visual direction, English-first | [Theme C story/UI contract](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/MADALASA_ALARKA_THEME_C_STORY_AND_UI_CONTRACT_2026.md) |
| Original parent/child screenshot-based workflows | [Screenshot workflows](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/REFERENCE_SCREENSHOTS_FEATURE_WORKFLOWS_2026.md) |
| Child-specific co-parent paid seat / verified guardian restriction | [SH-01 child selection](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-179) · [SH-02 unverified parent](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-201) |
| Viewer limit and +₹100/100 day paid addon | [SH-03 one viewer](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-221) · [SH-04 add-on checkout](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-242) · [SH-06 dormant addon](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=89-180) |
| Family seat and co-parent billing states | [P-47 child seat assignment](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-179) · [P-49 covered co-parent](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-201) |
| Admin Google login → request → owner approval, FAQ, support, payments and parent service logs | [Admin screen registry](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/figma-functional-handoff/10-admin-back-office.json) · [Figma admin page](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=105-2) |
| 112 conceptual DB entities across 10 ERD domains | [Figma DB page](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=92-2) · [Machine-readable ERD](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json) |
| Eraser HLD/LLD and verification concerns | [Diagram registry](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/cross-milestone-references/01-architecture-and-visual-indexes/ERASER_HLD_LLD_DIAGRAM_INDEX.md) |

## 5. All 20 dependency-ordered phases and 262 atomic tasks

The tables below are an **execution backlog**. All statuses start NOT_STARTED until an agent actually performs and verifies the work. See JSON for full per-task source paths, privacy classification, evidence path and dependency validation.


### Phase 00: Policy gates & task governance (12 tasks)

**Primary working area:** `docs/roadmap`. **Source contracts:** [BLOCKERS_AND_OWNER_DECISIONS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) · [INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md) · [DPIA.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md) · [DATA_RETENTION_SCHEDULE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md) · [GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md) · [TECHNICAL_DOCUMENT_AUDIT_GAPS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/TECHNICAL_DOCUMENT_AUDIT_GAPS_2026.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L00-001` | **Freeze source/decision supersession index** · `docs/roadmap/DECISION_LEDGER.md` | START | Every conflict linked to latest approved owner decision; stale specs marked |
| `L00-002` | **Lock feature flag matrix by Android/Play/legal approval** · `config/feature-gates.example.json` | `L00-001` | Every sensitive feature starts disabled and missing flag denies |
| `L00-003` | **Define synthetic-only local data classification** · `docs/roadmap/LOCAL_DATA_RULES.md` | `L00-002` | No real child, payment token, government ID or home address used |
| `L00-004` | **Define owner decision template and approval signatures** · `docs/roadmap/OWNER_APPROVALS.md` | `L00-003` | Unresolved blocking decisions recorded as BLOCKED not guessed |
| `L00-005` | **Register India controller and age-band UNKNOWN** · `docs/roadmap/LEGAL_PENDING.md` | `L00-004` | No real-data pilot allowed until verifiable approval |
| `L00-006` | **Record retention contradiction as unresolved gate** · `docs/roadmap/RETENTION_PENDING.md` | `L00-005` | Six-hour access window not conflated with storage lifetime |
| `L00-007` | **Record removal of unsupported Google Family Link relationship API requirement** · `docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md` | `L00-006` | No consumer Google parent-role API dependency remains; legal authority/consent remains a separate review |
| `L00-008` | **Record base prepaid and 100-day add-on invariants** · `docs/roadmap/COMMERCE_INVARIANTS.md` | `L00-007` | Expired base suspends extra viewing but does not erase addon until own end |
| `L00-009` | **Record personal Play account as active unverified console status** · `docs/roadmap/PLAY_ACCOUNT_NONSECRET.md` | `L00-008` | No account ID, emails, tokens or keys committed |
| `L00-010` | **Define release approval authority and RACI** · `docs/roadmap/RESPONSIBILITIES.md` | `L00-009` | No agent self-approves counsel/platform/owner decisions |
| `L00-011` | **Create traceability IDs FR/NFR/UI/DB/API/test** · `docs/roadmap/TRACEABILITY_LEDGER.csv` | `L00-010` | All release candidates have references and tests |
| `L00-012` | **Build local stop/go validator for unresolved gates** · `tools/check-local-gates.py` | `L00-011` | Fails if restricted flag set true without approved evidence |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 01: Local toolchain, reproducible builds and CI (14 tasks)

**Primary working area:** `tools`. **Source contracts:** [BUILD_AND_RUN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/02-development-process/BUILD_AND_RUN.md) · [ANDROID_COMPATIBILITY_MATRIX.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md) · [openapi-m1.yaml](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/openapi-m1.yaml) · [VALIDATION_AND_RELEASE_PLAN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/03-quality-and-evidence/VALIDATION_AND_RELEASE_PLAN.md) · [TECHNICAL_SPECIFICATION.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L01-001` | **Pin JDK Gradle AGP Kotlin Android SDK NDK** · `gradle/libs.versions.toml` | `L00-012` | Fresh environment uses reproducible versions |
| `L01-002` | **Generate Gradle wrapper and parent app module** · `android/madalasa/build.gradle.kts` | `L01-001` | Parent debug APK assembles offline when cached |
| `L01-003` | **Generate child app module and manifest** · `android/alarka/build.gradle.kts` | `L01-002` | Child debug APK assembles with package separate |
| `L01-004` | **Validate manifest icons adaptive and target API 36** · `android/*/src/main/AndroidManifest.xml` | `L01-003` | APK analyzer passes icon/permissions; SDK target verified |
| `L01-005` | **Create CMake C++20 Drogon project skeleton** · `backend/CMakeLists.txt` | `L01-004` | Native backend compiles and unit-test binary links |
| `L01-006` | **Pin Drogon Postgres PostGIS OpenSSL and testing libraries** · `backend/dependencies.lock` | `L01-005` | Dependency hashes and licenses independently verified |
| `L01-007` | **Create Docker or Podman local-only Postgres+PostGIS** · `infra/local/compose.yaml` | `L01-006` | Service loopback only; health test and migrations succeed |
| `L01-008` | **Create offline-friendly synthetic fixtures and seed command** · `tools/seed-synthetic.sh` | `L01-007` | Seeding repeatable; no live API keys |
| `L01-009` | **Add lint/format/static analysis for C++ Kotlin SQL Web** · `.github/workflows/local-checks.yml` | `L01-008` | CI fails on formatting or critical analyzer findings |
| `L01-010` | **Add lockfile and dependency SCA/SBOM verification** · `tools/check-sbom.sh` | `L01-009` | SBOM generated and dependency policy checked |
| `L01-011` | **Create fast smoke pipeline for Android and backend** · `tools/smoke-local.sh` | `L01-010` | One command compiles both and runs smoke tests |
| `L01-012` | **Add isolated clean build and zero-secret scanning** · `tools/verify-clean-build.sh` | `L01-011` | Fresh checkout tests and secret scanner pass |
| `L01-013` | **Set deterministic fake clock and fake Play/FCM/OIDC adapters** · `testkit/fake-services` | `L01-012` | Time/provider tests run offline |
| `L01-014` | **Create evidence template and per-task green-check script** · `tools/verify-roadmap-task.sh` | `L01-013` | Refuses DONE without named executable test and evidence |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 02: Physical PostgreSQL schema and RLS (15 tasks)

**Primary working area:** `backend/persistence`. **Source contracts:** [MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json) · [DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md) · [0001_m1_identity.sql](https://github.com/methakon/Madalasa-Alarka/blob/main/backend/persistence/migrations/0001_m1_identity.sql) · [DATA_RETENTION_SCHEDULE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md) · [ACCOUNT_DELETION_DESIGN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M6-guardian-erasure-security/01-data-erasure-and-access/ACCOUNT_DELETION_DESIGN.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L02-001` | **Review 112 logical tables and select MVP subset** · `backend/persistence/SCHEMA_SLICING.md` | `L01-014` | No SQL for a concept-only table by accident |
| `L02-002` | **Refactor existing M1 identity migration into repeatable baseline** · `backend/persistence/migrations/0001_m1_identity.sql` | `L02-001` | Disposable database applies once and fails safely on conflicts |
| `L02-003` | **Create adult family and child primary/foreign keys** · `backend/persistence/migrations/0002_core.sql` | `L02-002` | Foreign keys reject orphan/foreign-family records |
| `L02-004` | **Create child-specific grants and verification states** · `backend/persistence/migrations/0003_guardians.sql` | `L02-003` | Default deny; no implicit sibling grants |
| `L02-005` | **Enforce row-level security on every child-related table** · `backend/persistence/policies/rls.sql` | `L02-004` | Cross-tenant SELECT/UPDATE denied including owner-admin role |
| `L02-006` | **Create device key enrollment/nonce/session schema** · `backend/persistence/migrations/0004_devices.sql` | `L02-005` | Replay and revoked device keys rejected |
| `L02-007` | **Create durable inbox,outbox,dedupe and job fences** · `backend/persistence/migrations/0005_ingest.sql` | `L02-006` | Atomic durability and no duplicate event |
| `L02-008` | **Create partitioned PostGIS coordinates and history** · `backend/persistence/migrations/0006_location.sql` | `L02-007` | Partition pruning and geom index plans verified |
| `L02-009` | **Create trips, place, geofence, SOS and usage tables** · `backend/persistence/migrations/0007_safety.sql` | `L02-008` | All child foreign keys, TTL policies and revision keys valid |
| `L02-010` | **Create prepaid seats, founding-family unique rank and add-ons** · `backend/persistence/migrations/0008_billing.sql` | `L02-009` | No seat over-assignment; 100-day addon independent of base |
| `L02-011` | **Create atomic viewer lease and shared quota ledger tables** · `backend/persistence/migrations/0009_quota.sql` | `L02-010` | Two racers cannot exceed one included slot |
| `L02-012` | **Create admin approval, FAQ, support and parent service log tables** · `backend/persistence/migrations/0010_admin.sql` | `L02-011` | Admin DB view cannot query child-private tables |
| `L02-013` | **Create tombstone, retention, erasure and backup-fence tables** · `backend/persistence/migrations/0011_erasure.sql` | `L02-012` | Deleted child replay never revives stored data |
| `L02-014` | **Add schema down/upgrade and migration drift checks** · `backend/tests/migration_replay.sql` | `L02-013` | Forward upgrades and rollback strategy tested on synthetic data |
| `L02-015` | **Add SQL injection, privilege, RLS and query-plan tests** · `backend/tests/security_sql.sql` | `L02-014` | No tenant bypass; hot path plans bounded |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 03: OpenAPI contracts and generated typed DTOs (14 tasks)

**Primary working area:** `docs/api`. **Source contracts:** [openapi.yaml](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/openapi.yaml) · [openapi-m1.yaml](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/openapi-m1.yaml) · [SRS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md) · [DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md) · [ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md) · [CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L03-001` | **Preserve narrow M1 API and review whole-project draft divergences** · `docs/api/CONTRACT_DELTA.md` | `L02-015`, `L01-014` | 47 paths reconciled without claiming live handlers |
| `L03-002` | **Split public parent/device/admin paths by audience** · `docs/api/v1/openapi.yaml` | `L03-001` | No route grants wrong issuer token access |
| `L03-003` | **Define error envelope/correlation and retry taxonomy** · `docs/api/v1/errors.yaml` | `L03-002` | All failures have typed code and request ID |
| `L03-004` | **Write parent identity family/child/guardian schemas** · `docs/api/v1/parent.yaml` | `L03-003` | Google identity only and child grant proof fail-closed |
| `L03-005` | **Write child pairing/device capability/command schemas** · `docs/api/v1/device.yaml` | `L03-004` | No self-asserted managed mode or capture success |
| `L03-006` | **Write GPS batch and event time ingestion schemas** · `docs/api/v1/location.yaml` | `L03-005` | Idempotency and honest durable ACK modeled |
| `L03-007` | **Write trip, place, SOS, alerts and history schemas** · `docs/api/v1/safety.yaml` | `L03-006` | Provisional/stale states and cursor privacy explicit |
| `L03-008` | **Write trial/billing/seat/100-day addon and lease schemas** · `docs/api/v1/billing.yaml` | `L03-007` | Manual prepaid; 100-day independent add-on clearly typed |
| `L03-009` | **Write owner admin applicant/roles/FAQ/support/log endpoints** · `docs/api/v1/admin.yaml` | `L03-008` | NO_ACCESS can only see own application |
| `L03-010` | **Write media request/outcome gated schemas** · `docs/api/v1/media-research.yaml` | `L03-009` | Feature unavailable and OS denial typed; never fake capture |
| `L03-011` | **Bundle to canonical OpenAPI 3.1 artifact** · `docs/openapi.yaml` | `L03-010` | Swagger validator zero unresolved refs and unique operation IDs |
| `L03-012` | **Generate Kotlin+C++ DTOs or schema validators** · `generated/api/README.md` | `L03-011` | Positive/negative golden vectors agree across clients |
| `L03-013` | **Add contract compatibility and breaking-change tests** · `backend/tests/openapi_contract_test.py` | `L03-012` | CI rejects undocumented or widened response properties |
| `L03-014` | **Create endpoint to UI/DB/FR traceability table** · `docs/api/API_TRACEABILITY.csv` | `L03-013` | Each operation points to owner, rows, negative tests |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 04: Adult accounts, login, tenancy and explicit parent grants (12 tasks)

**Primary working area:** `backend/src/identity`. **Source contracts:** [DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md) · [SRS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md) · [TWO_PARENT_SHARED_CHILD_PREPAID_ENTITLEMENTS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/TWO_PARENT_SHARED_CHILD_PREPAID_ENTITLEMENTS_2026.md) · [CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md) · [INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L04-001` | **Implement OIDC verifier with issuer audience expiry sub and nonce** · `backend/src/identity/oidc_verifier.cc` | `L03-014`, `L02-015` | Wrong tokens/expired/forged aud all fail |
| `L04-002` | **Implement adult account signup/revocation endpoints** · `backend/src/identity/adults.cc` | `L04-001` | Revoked adult tokens lose access immediately |
| `L04-003` | **Implement family creation and owner membership** · `backend/src/identity/families.cc` | `L04-002` | Family membership alone gives zero child rights |
| `L04-004` | **Implement child record creation and exact-family ownership checks** · `backend/src/identity/children.cc` | `L04-003` | Cross-family child creation/lookup fails |
| `L04-005` | **Implement explicit child-specific guardian invitation draft** · `backend/src/identity/invitations.cc` | `L04-004` | Single-use hashed token and expiry enforced |
| `L04-006` | **Implement child-specific invitation acceptance, consent and authority-gate interface (NOT Family Link)** · `backend/src/identity/child_authority_and_invite.cc` | `L04-005` | Synthetic exact-child invite/accept/revoke works; real-data authority/consent unknown denies; Google Sign-In alone never grants child scope |
| `L04-007` | **Implement V2 cross-family child-specific grants and revocation with RLS** · `backend/src/identity/grants.cc` | `L04-006` | Parent B can access explicitly authorized Child A in a different billing family, never Child B; revoke closes leases |
| `L04-008` | **Implement auth scope cache with child revocation epochs** · `backend/src/identity/grant_cache.cc` | `L04-007` | Revocation kills old sessions and signed URLs |
| `L04-009` | **Implement guardianship disputes and safe denial states** · `backend/src/identity/guardianship_cases.cc` | `L04-008` | No arbitrary staff override or sibling metadata leaks |
| `L04-010` | **Implement parent login refresh/logout session rotation** · `backend/src/identity/session_manager.cc` | `L04-009` | Replay and refresh reuse rejected |
| `L04-011` | **Build 4-adult 3-child blended-family adversarial test** · `backend/tests/blended_family_test.cc` | `L04-010` | No cross-child leak including errors or counters |
| `L04-012` | **Add audit of grant accesses and privacy notices** · `backend/src/identity/access_audit.cc` | `L04-011` | Sensitive read event contains actor, scope, outcome |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 05: Child enrollment and Android permissions (12 tasks)

**Primary working area:** `android/alarka`. **Source contracts:** [CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) · [ANDROID_COMPATIBILITY_MATRIX.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md) · [DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md) · [openapi-m1.yaml](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/openapi-m1.yaml) · [README.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/figma-functional-handoff/README.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L05-001` | **Implement visible Alarka setup and disclosure flow** · `android/alarka/src/main/kotlin` | `L04-012` | No surveillance or concealed permission onboarding |
| `L05-002` | **Implement time-limited pairing QR/code entry screen** · `android/alarka/src/main/kotlin` | `L05-001` | Expired, wrong-family and replay tests pass |
| `L05-003` | **Bind device keys via Android Keystore PoP** · `android/alarka/src/main/kotlin` | `L05-002` | Copied token from another device rejected |
| `L05-004` | **Implement enrollment challenge+device capability baseline** · `android/alarka/src/main/kotlin` | `L05-003` | Device proof and monotonic config revisions checked |
| `L05-005` | **Implement system permission status scanner** · `android/alarka/src/main/kotlin` | `L05-004` | Reports ACTUAL granted/denied not optimistic UI |
| `L05-006` | **Implement separate permission explanations and settings guidance** · `android/alarka/src/main/kotlin` | `L05-005` | Denial remains functional and truthful |
| `L05-007` | **Implement capability sync on resume and revocation** · `android/alarka/src/main/kotlin` | `L05-006` | Permission removed while offline detected next sync |
| `L05-008` | **Implement managed-vs-standard device mode distinction** · `android/alarka/src/main/kotlin` | `L05-007` | Normal install never claims Device Owner |
| `L05-009` | **Implement visible monitoring notification+identifying app icon** · `android/alarka/src/main/kotlin` | `L05-008` | Persistent notification and tracking disclosure QA |
| `L05-010` | **Implement secure local config and queue encryption** · `android/alarka/src/main/kotlin` | `L05-009` | No plaintext child GPS in backups/logcat |
| `L05-011` | **Test Android 10..16/OEM permission matrix with fake and physical fixtures** · `android/alarka/src/androidTest` | `L05-010` | Unsupported mode returns reason; no bypass |
| `L05-012` | **Implement enrollment stop/revoke/uninstall guidance** · `android/alarka/src/main/kotlin` | `L05-010` | Guardian revoke halts uploads; child app shows status |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 06: GPS capture, buffering and durable ingestion (13 tasks)

**Primary working area:** `backend/src/location`. **Source contracts:** [TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M2-location-collection/01-location-collection-and-ingestion/TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md) · [POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) · [CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) · [DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L06-001` | **Implement sensor-fused Android GPS observation model** · `android/alarka/src/main/kotlin` | `L05-012`, `L02-015` | Observed timestamp/accuracy/provenance retained |
| `L06-002` | **Implement power-aware tracking frequency policy** · `android/alarka/src/main/kotlin` | `L06-001` | Free cadence lower but OS permitted; no location guarantees |
| `L06-003` | **Implement offline 48h bounded encrypted device queue** · `android/alarka/src/main/kotlin` | `L06-002` | Airplane-mode then reconnect without event loss or plaintext |
| `L06-004` | **Implement Android foreground service start restrictions** · `android/alarka/src/main/kotlin` | `L06-003` | FGS denial handled; never silently run hidden |
| `L06-005` | **Implement authenticated batch ingestion endpoint** · `backend/src/location/batch_handler.cc` | `L06-004` | Device key, child revoke epoch and batch hash checked |
| `L06-006` | **Implement Tx-A durable inbox before HTTP 202** · `backend/src/location/inbox.cc` | `L06-005` | Crash before commit yields no 202, after commit recoverable |
| `L06-007` | **Implement Tx-B bulk insert and outbox worker** · `backend/src/location/worker.cc` | `L06-006` | Crash/restart inserts each event once |
| `L06-008` | **Implement device event UUID dedupe and late ordering** · `backend/src/location/dedup.cc` | `L06-007` | Duplicate, out of order and old fix tests pass |
| `L06-009` | **Implement impossible-location/clock skew filtering** · `backend/src/location/quality.cc` | `L06-008` | GPS anomalies marked unknown, no fabricated location |
| `L06-010` | **Implement update-latest by observed time and quality** · `backend/src/location/latest.cc` | `L06-009` | Older late event never becomes newest point |
| `L06-011` | **Implement GPS health/queue/status diagnostics** · `backend/src/location/diagnostics.cc` | `L06-010` | Stale/unknown/outage explicitly surfaced |
| `L06-012` | **Simulate 48h reconnect, N=10000 batches and crash recovery** · `backend/tests/location_recovery_test.cc` | `L06-011` | No loss after durable ack; performance envelope recorded |
| `L06-013` | **Implement replay fence for deleted child during offline flush** · `backend/src/location/replay_guard.cc` | `L06-012` | Erasure tombstone rejects stale queued events |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 07: Parent location history and map experience (12 tasks)

**Primary working area:** `android/madalasa`. **Source contracts:** [LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md) · [TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M2-location-collection/01-location-collection-and-ingestion/TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md) · [README.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/figma-functional-handoff/README.md) · [DATA_RETENTION_SCHEDULE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md) · [DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L07-001` | **Implement child selector with only authorized child IDs** · `android/madalasa/src/main/kotlin` | `L06-013`, `L04-012` | Unshared siblings do not appear or infer counts |
| `L07-002` | **Implement latest observed child location endpoint and DTO** · `backend/src/location/read_api.cc` | `L07-001` | Wrong guardian denied; stale state truthful |
| `L07-003` | **Implement parent map with map provider interface** · `android/madalasa/src/main/kotlin` | `L07-002` | No provider API key checked into Git |
| `L07-004` | **Implement location age/accuracy/status chips** · `android/madalasa/src/main/kotlin` | `L07-003` | Unknown/unavailable location clearly shown |
| `L07-005` | **Implement free history 6-hour backend visibility filter** · `backend/src/location/history_policy.cc` | `L07-004` | No cursor/query can retrieve earlier free fixes |
| `L07-006` | **Implement paid history read after entitlement check** · `backend/src/location/history_policy.cc` | `L07-005` | No access when expired; retention legal gate still applies |
| `L07-007` | **Implement map layers/settings provider fallback** · `android/madalasa/src/main/kotlin` | `L07-006` | No vendor or source falsely claimed supported |
| `L07-008` | **Implement route timeline loading states and pagination** · `android/madalasa/src/main/kotlin` | `L07-007` | Overlapping pages don't leak or duplicate |
| `L07-009` | **Implement trip viewer route endpoints with metadata only** · `android/madalasa/src/main/kotlin` | `L07-008` | No invented road snapping across missing GPS |
| `L07-010` | **Implement network offline/auth failure/permission UX** · `android/madalasa/src/main/kotlin` | `L07-009` | Auth revocation and stale state handled without data cache leak |
| `L07-011` | **Run screenshot regression against Theme C and reference layouts** · `android/madalasa/src/androidTest` | `L07-010` | Screens differ only documented design deviations |
| `L07-012` | **Run parent/child isolate and historical cursor tests** · `backend/tests/location_read_auth_test.cc` | `L07-011` | Child B invisible even with crafted query |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 08: Trips, saved places and notifications (12 tasks)

**Primary working area:** `backend/src/trips`. **Source contracts:** [LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md) · [TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M2-location-collection/01-location-collection-and-ingestion/TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md) · [COMMAND_SOS_USAGE_QUEUE_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M4-usage-health-sos/01-usage-health-and-sos/COMMAND_SOS_USAGE_QUEUE_CONTRACT.md) · [README.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/figma-functional-handoff/README.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L08-001` | **Implement event-time trip segmentation candidate** · `backend/src/trips/segmenter.cc` | `L07-012`, `L06-013` | Labeled datasets yield measurable precision recall |
| `L08-002` | **Implement stop detection with confidence and unknown gaps** · `backend/src/trips/stops.cc` | `L08-001` | No false exact stop when fixes missing |
| `L08-003` | **Implement motion kind hypothesis with confidence** · `backend/src/trips/mode_classifier.cc` | `L08-002` | Walk/ride only labeled as inferred |
| `L08-004` | **Implement trip revision and late-event recompute** · `backend/src/trips/revision.cc` | `L08-003` | Out-of-order event revises derived trip immutably |
| `L08-005` | **Implement route polyline and observed/inferred visualization** · `backend/src/trips/geometry.cc` | `L08-004` | No fake road segments across gaps |
| `L08-006` | **Implement saved places CRUD with child scopes** · `backend/src/places/service.cc` | `L08-005` | Names and geofences protected from other parents |
| `L08-007` | **Implement enter/exit hysteresis and dedupe** · `backend/src/places/geofence.cc` | `L08-006` | Boundary jitter doesn't spam |
| `L08-008` | **Implement per-place per-adult notification toggle** · `backend/src/places/notification_rules.cc` | `L08-007` | Unselected parent doesn't get event |
| `L08-009` | **Implement notification outbox and FCM fake adapter** · `backend/src/places/notifier.cc` | `L08-008` | Submitted not misrepresented as viewed |
| `L08-010` | **Implement named home/school privacy protections** · `backend/src/places/privacy.cc` | `L08-009` | Unapproved guardian and admins cannot read |
| `L08-011` | **Implement place/route Theme C Android screens** · `android/madalasa/src/main/kotlin` | `L08-010` | History, map and place settings match design intent |
| `L08-012` | **Run labeled route/stop/geofence QA on synthetic traces** · `backend/tests/route_quality_test.cc` | `L08-011` | Threshold report and uncertain-case label persisted |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 09: SOS, status, app usage & managed controls (12 tasks)

**Primary working area:** `backend/src/safety`. **Source contracts:** [COMMAND_SOS_USAGE_QUEUE_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M4-usage-health-sos/01-usage-health-and-sos/COMMAND_SOS_USAGE_QUEUE_CONTRACT.md) · [CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) · [ANDROID_COMPATIBILITY_MATRIX.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md) · [INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L09-001` | **Implement child initiated SOS/check-in UI** · `android/alarka/src/main/kotlin` | `L05-012`, `L04-012` | Safety action clearly accessible and tested |
| `L09-002` | **Implement SOS durable acceptance/ACK protocol** · `backend/src/safety/sos.cc` | `L09-001` | Device receipt not confused with guardian acknowledgement |
| `L09-003` | **Implement SOS fanout to authorized guardian set** · `backend/src/safety/notifier.cc` | `L09-002` | No notification to unrelated parent |
| `L09-004` | **Implement best-effort retry and explicit failed delivery** · `backend/src/safety/delivery.cc` | `L09-003` | Offline/FCM failure surfaces non-guarantee |
| `L09-005` | **Implement battery/network last seen reporting** · `backend/src/safety/health.cc` | `L09-004` | Timestamps and staleness retained |
| `L09-006` | **Implement phone-usage capability-gated event model** · `backend/src/usage/events.cc` | `L09-005` | Legal OFF gate means zero child behavior ingest |
| `L09-007` | **Implement usage aggregation with unknown coverage quality** · `backend/src/usage/aggregates.cc` | `L09-006` | Missing time never counted as zero |
| `L09-008` | **Implement conditional app control policy preview** · `backend/src/controls/policy.cc` | `L09-007` | Standard phone never claims broad app blocking |
| `L09-009` | **Implement real Device Owner DPC lab-only controls** · `android/alarka/src/androidTest` | `L09-008` | Only factory-reset test phone and actual DPC provisioning |
| `L09-010` | **Implement remote command state machine and timeout statuses** · `backend/src/commands/dispatcher.cc` | `L09-008` | OS refusal returns named failure and audit |
| `L09-011` | **Implement app usage/health/SOS parent Figma screens** · `android/madalasa/src/main/kotlin` | `L09-010` | Feature flags hide unavailable modules honestly |
| `L09-012` | **Test SOS duplicates, device offline and revocation** · `backend/tests/safety_test.cc` | `L09-011` | No duplicate unauthorized alert nor false delivered claim |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 10: 48h trial, founding families & manual prepaid billing (14 tasks)

**Primary working area:** `backend/src/billing`. **Source contracts:** [SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md) · [TWO_PARENT_SHARED_CHILD_PREPAID_ENTITLEMENTS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/TWO_PARENT_SHARED_CHILD_PREPAID_ENTITLEMENTS_2026.md) · [CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md) · [openapi.yaml](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/openapi.yaml).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L10-001` | **Define family trial abuse/privacy policy test fixture** · `backend/tests/trial_policy_test.cc` | `L04-012`, `L03-014`, `L02-015` | Second signup attempt restricted without invasive persistent ID |
| `L10-002` | **Implement server 48-hour trial state and expiry** · `backend/src/billing/trial.cc` | `L10-001` | Clock spoof doesn't extend 48h once |
| `L10-003` | **Implement separate 6-hour free history entitlement** · `backend/src/billing/free_tier.cc` | `L10-002` | Expired paid reverts free with reduced cadence |
| `L10-004` | **Implement founding family 1008 distinct paid counter** · `backend/src/billing/founding.cc` | `L10-003` | Exactly 1008 distinct families; child added later eligible |
| `L10-005` | **Implement price display from verified Play product metadata** · `backend/src/billing/catalog.cc` | `L10-004` | Never hardcode ₹50 if actual Play says otherwise |
| `L10-006` | **Build local fake Play purchase provider and webhook** · `testkit/fake-play` | `L10-005` | No live Google charge or API credential |
| `L10-007` | **Implement prepaid child-seat capacity purchase intent** · `backend/src/billing/checkout.cc` | `L10-006` | Payer explicitly selects eligible children before buy |
| `L10-008` | **Implement server Play token verification/ack/RTDN** · `backend/src/billing/verification.cc` | `L10-007` | Forged/duplicate/refunded token never grants seat |
| `L10-009` | **Implement child-seat assignment atomic transaction** · `backend/src/billing/seats.cc` | `L10-008` | No double coverage or cross-child accidental assignment |
| `L10-010` | **Implement second guardian coverage without repurchase** · `backend/src/billing/entitlements.cc` | `L10-009` | Only approved exact child co-parent sees paid benefits |
| `L10-011` | **Implement manual renewal without recurring charge** · `backend/src/billing/topup.cc` | `L10-010` | Expiry does not auto-charge; checkout requires gesture |
| `L10-012` | **Implement payment deletion/account termination semantics** · `backend/src/billing/deletion.cc` | `L10-011` | No auto-renew; refund/state reconciliation correct |
| `L10-013` | **Build one-child/many-child and multiple guardian billing tests** · `backend/tests/prepaid_billing_test.cc` | `L10-012` | Token idempotency and founded rank tested |
| `L10-014` | **Add price tax/fees/founding UI labels** · `android/madalasa/src/main/kotlin` | `L10-013` | Offer labels match server Play metadata and disclaimers |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 11: Concurrent premium viewer add-ons and shared quotas (14 tasks)

**Primary working area:** `backend/src/viewers`. **Source contracts:** [CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md) · [SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md) · [MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md) · [openapi.yaml](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/openapi.yaml).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L11-001` | **Create server-side viewer lease policy 1 slot per paid child** · `backend/src/viewers/lease.cc` | `L10-014`, `L04-012` | Second simultaneous viewer rejected atomically |
| `L11-002` | **Implement device-session lease heartbeat and expiry** · `backend/src/viewers/heartbeat.cc` | `L11-001` | Background/disconnect TTL releases slot |
| `L11-003` | **Implement voluntary ask-to-takeover workflow** · `backend/src/viewers/takeover.cc` | `L11-002` | Never silently eject other guardian |
| `L11-004` | **Implement ₹100 one-time extra slot Play purchase adapter** · `backend/src/viewers/addon_purchase.cc` | `L11-003` | Only verified one-time purchase creates capacity |
| `L11-005` | **Implement exactly 100-day independent expiry** · `backend/src/viewers/addon_expiry.cc` | `L11-004` | Monthly base expiry does not alter addon end date |
| `L11-006` | **Implement addon dormancy and renewal reactivation** · `backend/src/viewers/addon_dormancy.cc` | `L11-005` | Base lapse pauses premium; resume same addon before day 100 |
| `L11-007` | **Implement 30min combined A/V pool per addon** · `backend/src/viewers/av_pool.cc` | `L11-006` | Audio+video uses one 1800s pool not separate 1800 each |
| `L11-008` | **Implement quota reservations and delivered-only debit** · `backend/src/viewers/meter.cc` | `L11-007` | Rejected OS media attempt consumes zero |
| `L11-009` | **Implement child-shared quotas across guardian devices** · `backend/src/viewers/atomic_counter.cc` | `L11-008` | Two parents race cannot overspend child pool |
| `L11-010` | **Implement access revocation at lease and stream handoff** · `backend/src/viewers/authorize.cc` | `L11-009` | Revocation invalidates active/pending viewer tokens |
| `L11-011` | **Implement no-premium-limit on free safety features** · `backend/src/viewers/exemptions.cc` | `L11-010` | Free map/SOS accessible even when premium full |
| `L11-012` | **Implement Figma SH-03/04/06 paid screen UX** · `android/madalasa/src/main/kotlin` | `L11-011` | Shows end date, dormancy, quota and verified checkout only |
| `L11-013` | **Stress 100 concurrent parent sessions and token replay** · `backend/tests/viewer_capacity_test.cc` | `L11-012` | No over-admission; p95 and saturation recorded |
| `L11-014` | **Test 100-day UTC leap/time and refund scenarios** · `backend/tests/addon_time_test.cc` | `L11-013` | No early forfeiture, silent renewal or quota replay |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 12: Madalasa Android parent end-to-end UI (14 tasks)

**Primary working area:** `android/madalasa`. **Source contracts:** [README.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/figma-functional-handoff/README.md) · [CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md) · [LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md) · [ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L12-001` | **Create Theme C design tokens, fonts, icon resources** · `android/madalasa/src/main/res` | `L07-012`, `L08-012`, `L09-012`, `L11-014` | Screens visually consistent and English-only initially |
| `L12-002` | **Implement launcher+signed-in parent navigation** · `android/madalasa/src/main/kotlin` | `L12-001` | Deep links require auth and child grants |
| `L12-003` | **Implement home dashboard child activity cards** · `android/madalasa/src/main/kotlin` | `L12-002` | Privacy and unavailable states accurate |
| `L12-004` | **Implement add-child / family / scoped co-parent screens** · `android/madalasa/src/main/kotlin` | `L12-003` | Other siblings never auto-shared |
| `L12-005` | **Implement child visibility and access-revoked screen** · `android/madalasa/src/main/kotlin` | `L12-004` | Cached child UI cleared after revocation |
| `L12-006` | **Implement place notifications and trip detail screens** · `android/madalasa/src/main/kotlin` | `L12-005` | Map-based reference layouts kept consistent |
| `L12-007` | **Implement trial privilege chip dismissible small** · `android/madalasa/src/main/kotlin` | `L12-006` | 48-hour marker small, closable, truthful countdown |
| `L12-008` | **Implement plan/child-seat selection and founding offers** · `android/madalasa/src/main/kotlin` | `L12-007` | One seat per paid child, no auto-renew checkout |
| `L12-009` | **Implement one-screen-used and ₹100/100day addon UI** · `android/madalasa/src/main/kotlin` | `L12-008` | 100-day independent expiry displayed |
| `L12-010` | **Implement parent media audit metadata history screens** · `android/madalasa/src/main/kotlin` | `L12-009` | No media binary content from backend |
| `L12-011` | **Implement help/FAQ/support ticket UI** · `android/madalasa/src/main/kotlin` | `L12-010` | Support messages sanitized and authenticated |
| `L12-012` | **Implement account deletion, export and signout** · `android/madalasa/src/main/kotlin` | `L12-011` | Revocation clears local cache, explicit status |
| `L12-013` | **Run Compose Espresso UI tests and accessibility checks** · `android/madalasa/src/androidTest` | `L12-012` | Touch targets, text scaling, contrast, status rendering |
| `L12-014` | **Run Figma-to-screen design checklist all 81+ new states** · `android/madalasa/FIGMA_TRACEABILITY.md` | `L12-013` | Every approved state mapped to test and screenshot |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 13: Alarka child safety & setup UX (12 tasks)

**Primary working area:** `android/alarka`. **Source contracts:** [README.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/figma-functional-handoff/README.md) · [CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) · [ANDROID_COMPATIBILITY_MATRIX.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md) · [INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L13-001` | **Create Alarka Theme C child-appropriate launcher** · `android/alarka/src/main/res` | `L05-012`, `L09-012` | Portrait branding and accessibility pass |
| `L13-002` | **Implement parent-guided setup and consent disclosures** · `android/alarka/src/main/kotlin` | `L13-001` | Monitoring never hidden; child-visible notice |
| `L13-003` | **Implement capability scan and permission checklist page** · `android/alarka/src/main/kotlin` | `L13-002` | Actual OS state only |
| `L13-004` | **Implement pairing and guardian access roster screen** · `android/alarka/src/main/kotlin` | `L13-003` | Shows only truly approved guardians |
| `L13-005` | **Implement GPS monitoring running/paused status** · `android/alarka/src/main/kotlin` | `L13-004` | Status matches OS and server truth |
| `L13-006` | **Implement visible SOS/check-in shortcut** · `android/alarka/src/main/kotlin` | `L13-005` | Available without forcing parental dashboard foreground |
| `L13-007` | **Implement account remove/stop monitoring guidance** · `android/alarka/src/main/kotlin` | `L13-006` | No stealth persistence |
| `L13-008` | **Implement device health, battery and offline indicator** · `android/alarka/src/main/kotlin` | `L13-007` | Staleness handling tested |
| `L13-009` | **Implement always-present monitoring notification under policy** · `android/alarka/src/main/kotlin` | `L13-008` | Visible indicator without deceptive suppression |
| `L13-010` | **Test reboots, force-stop, permission denial and upgrades** · `android/alarka/src/androidTest` | `L13-009` | Degradation truthfully reported |
| `L13-011` | **Run minimum supported Android to target matrix on lab devices** · `android/alarka/src/androidTest` | `L13-010` | Record API/OEM environment and approved features |
| `L13-012` | **Audit permissions against exact shipped manifests** · `android/alarka/permission-audit.md` | `L13-011` | No undeclared optional permissions |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 14: Admin web OIDC, onboarding, FAQ, support and reports (18 tasks)

**Primary working area:** `admin-web`. **Source contracts:** [ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md) · [10-admin-back-office.json](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/figma-functional-handoff/10-admin-back-office.json) · [DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md) · [MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L14-001` | **Build separate admin web project and local dev shell** · `admin-web/package.json` | `L04-012`, `L03-014`, `L02-015` | Serves locally with fake account only |
| `L14-002` | **Implement secure Google ID-token verifier backend** · `backend/src/admin/google_oidc.cc` | `L14-001` | Wrong iss/aud/sub/email claim denied |
| `L14-003` | **Implement owner bootstrap bound to verified Google sub** · `backend/src/admin/bootstrap.cc` | `L14-002` | Only configured owner can grant roles |
| `L14-004` | **Implement NO_ACCESS self profile/status endpoint** · `backend/src/admin/access_state.cc` | `L14-003` | Unapproved login cannot query admin APIs |
| `L14-005` | **Implement profile validation and privacy disclosure** · `backend/src/admin/profile.cc` | `L14-004` | Address/DOB/gender necessity gate; encrypted fields |
| `L14-006` | **Implement verified-contact email challenge flow** · `backend/src/admin/email_verification.cc` | `L14-005` | Expired/replayed tokens rejected; provider verified path accepted |
| `L14-007` | **Implement idempotent Request Access submission and notification** · `backend/src/admin/access_requests.cc` | `L14-006` | Verified profile required; owner email contains no PII |
| `L14-008` | **Implement owner inbox and applicant detail read** · `backend/src/admin/request_review.cc` | `L14-007` | Owner MFA step-up and access audit required |
| `L14-009` | **Implement approve/reject atomic RBAC grant transaction** · `backend/src/admin/approve.cc` | `L14-008` | No self-role escalation, no duplicate approvals |
| `L14-010` | **Implement role-scoped revocation and session invalidation** · `backend/src/admin/revocation.cc` | `L14-009` | Immediate loss of all admin privileges |
| `L14-011` | **Implement FAQ CMS drafts/revisions/publish/sanitize** · `backend/src/admin/faqs.cc` | `L14-010` | XSS payload rejected and rollback audited |
| `L14-012` | **Implement parent-initiated support ticket and replies** · `backend/src/admin/support.cc` | `L14-011` | Ticket isolation and delivery status tracked |
| `L14-013` | **Implement subscriber ledger and masked Play payment view** · `backend/src/admin/subscribers.cc` | `L14-012` | No raw purchase tokens/cards in API |
| `L14-014` | **Implement minimal child alias/paid status restricted projection** · `backend/src/admin/child_roster.cc` | `L14-013` | Never fetch location/route/media/app behavior |
| `L14-015` | **Implement parent service-action duration log middleware** · `backend/src/admin/parent_usage.cc` | `L14-014` | Only actor/time/service/outcome; not child behavior |
| `L14-016` | **Implement admin UI BO-01..BO-09 and conditional navigation** · `admin-web/src` | `L14-015` | Unapproved sees only request; owner sees modules |
| `L14-017` | **Implement redacted audit/CSRF/MFA and paginated export limits** · `backend/src/admin/security.cc` | `L14-016` | Sensitive reads fail if audit unavailable |
| `L14-018` | **Run unauthorized/owner/support/FAQ XSS and metadata tests** · `backend/tests/admin_authorization_test.cc` | `L14-017` | All direct API privilege escalation probes fail |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 15: Privacy, retention, erasure, export (12 tasks)

**Primary working area:** `backend/src/privacy`. **Source contracts:** [ACCOUNT_DELETION_DESIGN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M6-guardian-erasure-security/01-data-erasure-and-access/ACCOUNT_DELETION_DESIGN.md) · [DATA_RETENTION_SCHEDULE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md) · [DPIA.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md) · [DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L15-001` | **Create retention categories with DRAFT disabled scheduling** · `backend/src/privacy/retention_policy.cc` | `L02-015`, `L06-013`, `L04-012` | No accidental forever retain or silent 14/30 day guess |
| `L15-002` | **Implement free 6-hour visibility separate from TTL** · `backend/src/privacy/history_visibility.cc` | `L15-001` | Free endpoint cannot exceed 6h while storage gate remains distinct |
| `L15-003` | **Implement authenticated deletion workflow and notices** · `backend/src/privacy/deletion.cc` | `L15-002` | Delete request not mistaken for immediate completion |
| `L15-004` | **Implement parent/child device revocation before erasure** · `backend/src/privacy/tombstones.cc` | `L15-003` | No offline GPS replay after deletion |
| `L15-005` | **Implement cross-store delete of raw/inbox/outbox/trips and cache** · `backend/src/privacy/delete_worker.cc` | `L15-004` | Every store gets deletion receipt |
| `L15-006` | **Implement WAL/backup restore suppression of erased children** · `backend/src/privacy/restore_guard.cc` | `L15-005` | Restored backup doesn't resurrect records |
| `L15-007` | **Implement bounded data export and authorization checks** · `backend/src/privacy/exports.cc` | `L15-006` | Export limited to child authorized by requesting adult |
| `L15-008` | **Implement retention policy audit and admin data minimization** · `backend/src/privacy/audit.cc` | `L15-007` | No raw child private data in general admin logs |
| `L15-009` | **Implement trial anti-repeat privacy-respecting risk review** · `backend/src/privacy/trial_abuse.cc` | `L15-008` | No irreversible invasive device fingerprint by default |
| `L15-010` | **Test partial deletion, offline reconnect, backup replay** · `backend/tests/privacy_lifecycle_test.cc` | `L15-009` | No deleted child records reappear |
| `L15-011` | **Prepare public local privacy/terms/deletion page previews** · `public/legal` | `L15-010` | Public copy matches actual functionality and explicit draft status |
| `L15-012` | **Mark all unapproved legal decisions fail closed** · `backend/src/privacy/legal_gate.cc` | `L15-011` | Child real-data ingestion cannot be enabled by coding agent |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 16: Conditional media, managed controls & future modules (12 tasks)

**Primary working area:** `research`. **Source contracts:** [MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md) · [ANDROID_COMPATIBILITY_MATRIX.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md) · [INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md) · [GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L16-001` | **Design capability-by-OS matrix and false-success tests** · `research/media/FEATURE_GATES.md` | `L05-012`, `L11-014` | No unsupported camera/mic promises |
| `L16-002` | **Prove visible user-authorized MediaProjection lab flow** · `research/media/screen_demo` | `L16-001` | Consent each session; no background bypass |
| `L16-003` | **Prove foreground microphone lifecycle limitations on Android 14+** · `research/media/audio_demo` | `L16-002` | OS rejection reported, not circumvented |
| `L16-004` | **Prove camera/photo/video availability with explicit child-visible UI** · `research/media/camera_demo` | `L16-003` | No covert captures and proper privacy indicators |
| `L16-005` | **Prototype parent-controlled secure file metadata only** · `research/media/files_demo` | `L16-004` | No personal file extraction without separate approval |
| `L16-006` | **Record optional managed-device DPC test constraints** · `research/managed/README.md` | `L16-005` | No consumer granted Device Owner falsely |
| `L16-007` | **Build simulator returning denied reason codes for media** · `testkit/fake-media` | `L16-006` | Features default disabled in production profiles |
| `L16-008` | **Build quota meter and per-request media evidence test corpus** · `backend/tests/media_quota_test.cc` | `L16-007` | No debit on rejected sessions |
| `L16-009` | **Implement media activity METADATA-only audit events** · `backend/src/media/audit.cc` | `L16-008` | Raw media never stored on VPS by this feature |
| `L16-010` | **Prototype parent audit filter/sort UI from Figma** · `android/madalasa/src/main/kotlin` | `L16-009` | Unapproved metadata queries cannot enumerate child |
| `L16-011` | **Prepare independent privacy/Play legal capability approval matrix** · `research/media/RELEASE_REVIEW.md` | `L16-010` | Every feature remains blocked until signed evidence |
| `L16-012` | **Do not merge media capture into release build until all gates approved** · `research/media/MERGE_GATE.md` | `L16-011` | CI rejects sensitive permissions when gate off |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 17: Security hardening, reliability and scale (15 tasks)

**Primary working area:** `backend/tests`. **Source contracts:** [THREAT_MODEL_STRIDE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/THREAT_MODEL_STRIDE.md) · [DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md) · [VALIDATION_AND_RELEASE_PLAN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/03-quality-and-evidence/VALIDATION_AND_RELEASE_PLAN.md) · [POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) · [CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L17-001` | **Run STRIDE threat scenarios per API and actor** · `backend/tests/security_threat_matrix.md` | `L08-012`, `L09-012`, `L10-014`, `L11-014`, `L12-014`, `L13-012`, `L14-018`, `L15-012` | High-severity mitigations tested |
| `L17-002` | **Automate OIDC token abuse, CSRF and session fixation tests** · `backend/tests/auth_adversarial.cc` | `L17-001` | No admin/parent impersonation |
| `L17-003` | **Run cross-tenant RLS and child-scoped authorization fuzz tests** · `backend/tests/tenant_fuzz.cc` | `L17-002` | No sibling/private child leaks |
| `L17-004` | **Run payment/webhook replay and refund chaos** · `backend/tests/payments_chaos.cc` | `L17-003` | No duplicate entitlement or negative quota |
| `L17-005` | **Run worker crash after durable 202 and retry storms** · `backend/tests/inbox_faults.cc` | `L17-004` | No acknowledged event loss |
| `L17-006` | **Run auth revocation against open viewers and signed links** · `backend/tests/revocation_chaos.cc` | `L17-005` | Tokens/streams revoked within tested bound |
| `L17-007` | **Run privacy deletion vs offline sync race/failure tests** · `backend/tests/erase_race.cc` | `L17-006` | No resurrection |
| `L17-008` | **Benchmark GPS 1k/10k/100k synthetic child scenarios** · `bench/gps_ingestion` | `L17-007` | p50/p95/throughput/CPU recorded; no real data |
| `L17-009` | **Benchmark local synthetic viewer fanout, report bytes/CPU without choosing hosting region** · `bench/viewer_cost` | `L17-008` | Measured 1/2/3 viewer throughput, CPU and bytes recorded; cloud tariff/region deferred to deployment |
| `L17-010` | **Assess DB partitions, slow queries and backups locally** · `backend/tests/postgres_perf.sql` | `L17-009` | Query plans and restore evidence saved |
| `L17-011` | **Run dependency vulnerabilities and license scan** · `tools/security-scan.sh` | `L17-010` | No unresolved Critical or High without owner exception |
| `L17-012` | **Run Android 16KB native page size and targetSdk QA** · `android/build-audit` | `L17-011` | AAB native libraries compatible; target API 36 |
| `L17-013` | **Run accessibility/privacy UI automated audits** · `android/*/src/androidTest` | `L17-012` | No hidden child monitoring and app status truthful |
| `L17-014` | **Run local incident drill with redacted logs and restore** · `testkit/incident_drill` | `L17-013` | Runbook proves synthetic recovery |
| `L17-015` | **Freeze release-candidate security & test evidence ledger** · `evidence/local/SUMMARY.md` | `L17-014` | Every required test PASS or documented blocked |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 18: Local end-to-end acceptance and change trace (15 tasks)

**Primary working area:** `evidence/local`. **Source contracts:** [VALIDATION_AND_RELEASE_PLAN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/03-quality-and-evidence/VALIDATION_AND_RELEASE_PLAN.md) · [SRS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md) · [README.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/figma-functional-handoff/README.md) · [MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json) · [openapi.yaml](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/openapi.yaml) · [GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L18-001` | **Freeze local build and Figma/API/database traceability snapshot** · `evidence/local/TRACEABILITY_SNAPSHOT.md` | `L17-015`, `L12-014`, `L13-012`, `L14-018`, `L15-012` | No unresolved required path missing |
| `L18-002` | **Run new-family → 48h trial → free downgrade end-to-end** · `evidence/local/E2E_TRIAL.md` | `L18-001` | No trial reset after account recreation attempt |
| `L18-003` | **Run child pairing → GPS → parent map → stale/offline path** · `evidence/local/E2E_GPS.md` | `L18-002` | Durable and truthful status all the way |
| `L18-004` | **End-to-end child-specific cross-family invite acceptance and legal-gate denial** · `evidence/local/E2E_PARENT_SCOPE.md` | `L18-003` | Child A grant isolated, Child B hidden; unapproved legal authority cannot enable real child processing |
| `L18-005` | **Run 2 children distinct prepaid seats and two guardians** · `evidence/local/E2E_SEATS.md` | `L18-004` | One child seat never pays twice for parents |
| `L18-006` | **Run base expiry → dormant 100-day addon → renewal** · `evidence/local/E2E_ADDON.md` | `L18-005` | 100-day timestamp unchanged; extra 1800s pool remains |
| `L18-007` | **Run one-viewer race, takeover and add-slot authorization** · `evidence/local/E2E_VIEWER.md` | `L18-006` | Strict single premium session without paid addon |
| `L18-008` | **Run child SOS and notification fault path** · `evidence/local/E2E_SOS.md` | `L18-007` | No false delivered-to-parent claim |
| `L18-009` | **Run admin NO_ACCESS → verified profile → owner approve** · `evidence/local/E2E_ADMIN.md` | `L18-008` | Unapproved account gets no billing/child metadata |
| `L18-010` | **Run FAQ publish and support reply isolation** · `evidence/local/E2E_SUPPORT.md` | `L18-009` | XSS and cross-ticket access denied |
| `L18-011` | **Run account deletion plus offline queue and restored backup** · `evidence/local/E2E_ERASURE.md` | `L18-010` | No child-data revival |
| `L18-012` | **Run mixed API29..36 Android physical/OEM acceptance** · `evidence/local/DEVICE_MATRIX.md` | `L18-011` | No green pass without actual tested device |
| `L18-013` | **Run accessibility, localization-readiness and screenshot diff** · `evidence/local/UI_ACCEPTANCE.md` | `L18-011` | Theme C, English now, translated resources ready |
| `L18-014` | **Run contract drift, migration replay and local CI from clean clone** · `evidence/local/CLEAN_BUILD.md` | `L18-013` | All executable tests green with full commands |
| `L18-015` | **Compile unresolved blockers and recommend go/no-go for LOCAL artifact** · `evidence/local/LOCAL_EXIT_REVIEW.md` | `L18-014` | Status honest: READY/NOT_READY/BLOCKED; no Play claim |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

### Phase 19: Engineering handoff without deployment (8 tasks)

**Primary working area:** `docs/roadmap`. **Source contracts:** [VALIDATION_AND_RELEASE_PLAN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/03-quality-and-evidence/VALIDATION_AND_RELEASE_PLAN.md) · [BLOCKERS_AND_OWNER_DECISIONS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) · [GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md) · [INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md).

| Task | Atomic deliverable | Depends on | Proof required |
|---|---|---|---|
| `L19-001` | **Generate final API endpoint implementation coverage report** · `docs/roadmap/API_COMPLETION.md` | `L18-015` | Spec ≠ handler; every missing route identified |
| `L19-002` | **Generate M1..M9 requirements coverage by task ID** · `docs/roadmap/FINAL_COVERAGE_MATRIX.csv` | `L19-001` | Every applicable FR/NFR mapped to test |
| `L19-003` | **Export final database migration version and ERD drift report** · `docs/roadmap/SCHEMA_DRIFT.md` | `L19-002` | 112 draft candidates distinguished from executable subset |
| `L19-004` | **Export local integration and Android device QA report** · `docs/roadmap/QA_REPORT.md` | `L19-003` | Shows all pass/fail/blocked and environments |
| `L19-005` | **Generate separate deployment prerequisites handoff** · `docs/roadmap/RELEASE_HANDOFF.md` | `L19-004` | Only requirements/evidence, no infrastructure change |
| `L19-006` | **Verify no real child records or secret credentials leaked** · `docs/roadmap/PRIVACY_EXIT.md` | `L19-005` | Synthetic-only state and clean git check |
| `L19-007` | **Flag external Play testing, legal approvals and region decisions** · `docs/roadmap/EXTERNAL_GATES.md` | `L19-006` | External gates not marked by coding agent |
| `L19-008` | **Audit PR history, SBOM and licenses for ship candidate** · `docs/roadmap/LOCAL_SIGNOFF.md` | `L19-007` | Human reviewer signoff still mandatory |

**Exit gate:** all required tasks in this phase have actual passing evidence; conditional feature tasks may be BLOCKED_EXTERNAL only with retained OFF flag, negative denial tests and recorded approval owner. No phase is completed by documenting intended behavior.

## 6. Mandatory test and clearance matrix

| Domain | Positive scenario | Mandatory failure/abuse scenario | Hard exit condition |
|---|---|---|---|
| Adult auth | Valid Google OIDC login, scoped family/child grants | Token wrong audience, forged email/role, revoked session, child B probing | Zero unauthorized child records |
| Device pairing | One-use QR/code + hardware-bound key proof | Reused token, device clone, old challenge, wrong family | All rejected and audited |
| Android capabilities | User-visible permission granted, status sync | Denied OS/FSG start, Android 14+ while-in-use camera/mic restriction, revoke mid-session | Accurate reason instead of false success |
| GPS intake | Device 48h buffered upload, DB durable ACK, latest fix | Crash after 202, duplicate, late fix, clock skew, deleted child offline replay | No loss after ACK, no replay, no false latest |
| Trips/places | Trip revision, route transparency, arrival alerts | GPS gaps, jitter, improbable motion, unapproved guardian | No invented stops/path; thresholds measured |
| Safety | SOS accepted and guardian acknowledgement | FCM offline/retry, duplicate, unacknowledged user | Honest delivery status |
| Free/trial | 48h intro once, free 6h view | Signup recreation, forged timestamp, crafted cursor retrieving >6h | Trial cannot be trivially reset; no free history leak |
| Billing | 1,008 distinct founding families, paid child seats, shared approved parent | Duplicate Play token, refund, double charge, sibling coverage | Seats and amounts server verified; no auto-renew |
| Viewer add-on | +₹100 once, +1 simultaneous viewer, 100 days, +1800 combined AV seconds | Second parent race, base lapse at day 29, renewal at day 70, expiry/refund at day100 | No early forfeiture, quota/race prevention |
| Admin | Owner reviews verified applicant and grants role | Unknown Google login, self-claimed role, XSS FAQ, ticket cross access, child GPS request | Deny by default, owner approvals audited |
| Child privacy | Six-hour free history and approved paid access | No indefinite retention decision, child erasure during queue, restored backup | No illegal/forgotten child data |
| Media research | Approved visible OS flow in lab only | Remote background camera/mic activation, denied MediaProjection, fake success | Feature flag remains OFF unless independently cleared |
| Performance | Synthetic 1k/10k/100k ingestion, 1–3 viewer loads | Saturation/failure/CPU/memory/egress peaks | Measured bound and cost, never an untested guarantee |
| Local release handoff | Clean clone, Android debug builds, C++ build and all tests | Missing device/credential/legal/Play approval | Report BLOCKED honestly, **do not deploy** |

**Evidence format per test:** task ID, exact git SHA, UTC run time, local OS/SDK/Android API/OEM, command, exit status, sanitized stdout/stderr pointer, synthetic fixture seed, expected/actual, independent reviewer/agent name and result `PASS/FAIL/BLOCKED`. Evidence files may be written only after running actual commands, never prefilled PASS.

## 7. Local finish criterion and handoff boundary

**LOCAL_IMPLEMENTATION_READY** requires: compilable source and verified manifests, functional synthetic E2E parent/child/admin workflows, current API handlers matched by OpenAPI contract, actual SQL migration/RLS, negative/fault tests, static/dependency security review, measured resource profile, Android emulator + physical-device tests when available, 100% mapping of applicable tasks/FR/NFR/Figma screens to checks and no unreviewed P0 issues.

The agent must issue a clear **LOCAL_READY / LOCAL_BLOCKED / NOT_READY** result and evidence. Separate **production/deployment** go/no-go requires human owner + counsel + Google Play + verified Play account/tracks + publisher identity, deployed hosting region, data safety and processor terms. **No local agent may mark Play production APPROVED, claim the personal account has satisfied 12-tester requirements or handle live child data without evidence.**

## 8. Verified official external rules for the separate release stream

- Google Play new uploads as of **August 31, 2026**: target Android 16 / API 36 or higher for ordinary Android phone apps. [Official Android target API requirements](https://developer.android.com/google/play/requirements/target-sdk).
- Monitoring apps require prominent notice, a persistent notification, unique icon and `isMonitoringTool=child_monitoring`; cannot be disguised or market spousal tracking. [Play monitoring policy](https://support.google.com/googleplay/android-developer/answer/9888380) · [manifest guidance](https://support.google.com/googleplay/android-developer/answer/12955211).
- Personal Play developer accounts created **after November 13, 2023** ordinarily need **12 continuously opted-in closed testers for 14 days** and separate production-access application. [Official testing policy](https://support.google.com/googleplay/android-developer/answer/14151465); exact applicability cannot be inferred from active account type alone.
- New personal accounts have a physical-device verification requirement where Console prompts. [Official guidance](https://support.google.com/googleplay/android-developer/answer/14316361).
- Android 14+ background mic/camera/location FGS restrictions cannot be bypassed by previously granted app permissions. [Android foreground-service limits](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).
- Prepaid Play plans do not automatically renew; subscription add-ons are currently only for auto-renewing plans. [Prepaid billing](https://developer.android.com/google/play/billing/subscriptions) · [subscription add-on limits](https://developer.android.com/google/play/billing/subscription-with-addons).
- Child data under India's DPDP law requires feature-by-feature legal review, including commencement and exceptions; signed-off legal assessment is not supplied by an engineering roadmap. [2023 Act](https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023.pdf) · [2025 Gazette commencement](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf).

**This file is LOCAL engineering planning only. See separate deployment and Play document for hosting, testing-track and public-release steps.**

## 2026-10-28 Screen/API/DB audit addendum — supersedes earlier snapshot counts

The original 262-task local plan and acceptance gates remain as-is. A [screen-by-screen Figma audit](../audits/FINAL_FIGMA_SCREEN_BY_SCREEN_API_DB_REPORT_2026-10-28.md) found 187 editable screen references, 58 absent original API paths, and an 8-entity persistence gap. The extended [whole-project OpenAPI](../openapi.yaml) now defines **146 draft operations (96 newly specified, zero new handlers proven)**. The conceptual database registry now lists **120 candidate tables across 11 ERD domains** (112 previously documented + eight proposed), **not 120 executable migrations**. There are [28 extra dependency-checked remediation tasks](FIGMA_SCREEN_API_DB_REMEDIATION_TASKS_2026-10-28.json) in addition to the base 262, including an exact-child external-parent RLS fix. Coding agents MUST read/implement this addendum before LOCAL_READY. The original screen examples are still developer handoffs/Theme C samples, not production-complete UI. External Play/legal gates are unchanged.


## 2026-10-28 owner correction — execution gate removals

- DROP Google Family Link parent-role API as a technical prerequisite. Use [V2 cross-family child access ADR](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md): verified Google adult identity, specific-child invite + acceptance + scoped grant. Applicable statutory parent/guardian legal authority and consent review are **still required** before real child data; do not conflate with Family Link.
- Current M1 FK to same-family `guardian_memberships` cannot express cross-household allowed co-parents. Keep `0001` immutable; implement separately tested versioned V2 grant migration and RLS semantics.
- PROD hosting region (India/Chicago) and FINAL cloud bandwidth economics are **deployment decisions, not local coding blockers**. Local backend must be configurable and synthetic load benchmarks still run. [Separate deployment plan](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/roadmap/DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md).
- Play sandbox setup is separate from secrets in chat; local fake billing tests need no credentials. [Implementation and Play sandbox checklist](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/roadmap/IMPLEMENTATION_PROOF_AND_PLAY_SANDBOX_HANDOFF_2026-10-28.md).
