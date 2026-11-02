# AGENTS.md — Madalasa–Alarka

This file is the **entrypoint for coding agents**. Work on local/development infrastructure; primarily test with owner-operated physical Android devices using real GPS/network and actual dev APIs, while preserving Android disclosures, permissions and secure handling. Do not use real minors' personal data without applicable authorization or deploy to production. Use non-personal fixtures when deterministic negative/security tests require them. No separate written self-consent paperwork is needed for the owner's own devices; another adult must know and agree to testing. See `docs/roadmap/PRE_RELEASE_VERSIONING_AND_CHILD_DATA_REVIEW_POLICY_2026-11-02.md`.

## MANDATORY: CURRENT BRANCH FLOW — OWNER APPROVED 2026-10-31

**Read this section before any code, branch, documentation or PR action.** Exactly five permanent **working** branches are `api`, `parent`, `child`, `admin-web` and `dev`; `main` is the sixth, canonical branch. Backend/API/SQL goes to `api`; Madalasa Android to `parent`; Alarka Android to `child`; admin panel, Terms & Conditions, FAQ and customer-care frontend to `admin-web`. **ALL code commits and temporary task branches flow to `dev` for integrated testing/security clearance first, then a reviewed `dev` → `main` PR, followed by final tests on `main`.** Do not create additional branches unless the owner explicitly orders one; owner-approved temporary branches are merged through `dev`, then `main`, verified and promptly deleted. Preserve the existing unresolved PostgreSQL branch until its unique work passes this process.

**ALL documentation, planning, governance decisions and docs tools are edited and committed ONLY on `main`.** On implementation branches propose doc changes separately; do not include canonical `docs/**` changes in their PRs. Actual web pages under `public/legal/` are implementation in `admin-web`, but legal signoff is independent. The mandatory [canonical branch policy](docs/phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md) and [branch-route CI](.github/workflows/branch-governance.yml) govern every worker. Neither a PR merge nor passing CI grants Play/DPDP release permission.

### HARD GATE BEFORE EVERY WORK SEGMENT — pull both `dev` and `main`

Before **starting or resuming any task** on `api`, `parent`, `child`, `admin-web` or an approved temporary branch, use a **clean worktree** and run `bash docs/tools/sync_work_branch.sh <current-branch>`. This fetches both `origin/main` and `origin/dev`, fast-forward-pulls the current branch, then merges `main` followed by `dev` without force. Record the three SHAs and conflict/test outcomes before coding and again before each PR. On `dev`, use the same command with `dev` to sync `main`; before documentation work on `main`, use the command with `main` to pull `main` and **inspect but never merge `dev`**. Any conflicts, dirty worktree or failed sync block the task until safely resolved. [Full preflight rules](docs/phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md#mandatory-pre-work-synchronization-from-both-main-and-dev-owner-addendum-2026-10-31).

## Historical branch discipline (2026-10-29; superseded where inconsistent)

Before committing or creating branches, read [the canonical branch policy and active branch/PR register](docs/phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md). **Reuse an appropriate existing tracked branch/PR by default.** A new task or agent does not automatically justify a new branch. Inspect live branches, PR bases, uncommitted work and dependency order; maintain the single register whenever creating, merging, retargeting, or closing work. Do not accidentally discard work in stacked PRs: merging into another feature branch is not the same as merging into `main`. New branches are appropriate only when there is a concrete independent-review/conflict/release need; record reason and owner. Never automatically delete branches or force-push another agent's commits. Normal commits and PR updates are welcome, subject to existing review and security rules.

## Read first

1. docs/roadmap/LOCAL_TASK_GRAPH_2026-10-28.json — 262 task IDs, dependencies, acceptance, source paths and evidence destinations.
2. docs/roadmap/LOCAL_AGENT_DEVELOPMENT_ROADMAP_2026-10-28.md — dependency-ordered phases, Figma/API/DB references, test gates.
3. docs/roadmap/AGENT_EXECUTION_AND_TEST_EVIDENCE.md — test and progress recording protocol.
4. docs/roadmap/SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md — authority and unresolved decisions.
5. docs/roadmap/DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md — owner-only deployment and Play actions (DO NOT execute during local coding).

## Core commands (current vs future)

Current available structural check: python3 backend/tests/lint_openapi_m1.py docs/openapi-m1.yaml.
Current available DB baseline: backend/persistence/migrations/0001_m1_identity.sql and backend/tests/m1_tenant_isolation.sql; run only in disposable local PostgreSQL with proper non-superuser RLS tests.
Gradle Android builds, C++ Drogon build and admin web testing are tasks to CREATE, not assumed to work today.

## Hard stops

- Never process real child GPS, app usage, photos or media before lawful authority, retention and Google Play policy approval.
- No Play Console upload, developer account changes, actual billing, OCI deployment, device-owner provisioning or real-device wipe without explicit owner authorization.
- Never claim Family Link parent relationship verification is available from Google Sign-In. Sharing is exact-child scoped and disabled until verified.
- Keep admin owner authority tied to verified Google OIDC sub with role authorization; owner has no unrestricted child location/media access.
- No covert microphone/camera/screen recording, permission suppression or forced Android background capture.
- No secrets, private developer account ID, real household data or raw Play purchase tokens in Git.
- Never mark a task PASS without executed commands, actual exit code, redacted evidence and commit SHA.

## Task execution

Choose earliest dependency-ready task; prefer tests-first, minimal change, strict negative authorization tests and one PR/commit per small slice. Record progress in docs/roadmap/LOCAL_TASK_EXECUTION_STATUS.json and evidence/local/tasks/<TASK-ID>.md only once executed. Block external legal, physical-device and Play dependencies; continue unrelated tasks when explicit DAG allows. Review API/OpenAPI, DB/PostGIS RLS and Figma designs before implementation.

## Identity of the system

Parent app: Madalasa (Kotlin Android); child app: Alarka (Kotlin Android); backend: C++20 Drogon; database: PostgreSQL/PostGIS; admin: separate web panel. User-facing English first, Theme C pan-Indian Markandeya Purana interpretation, multilingual-ready.

Business: 48h first trial once; free live location + last 6h visible history; prepaid per selected child without auto-renew; first 1,008 distinct paid families founding price target; exact child-specific co-parent sharing, no automatic siblings; one premium concurrent viewer per paid child and optional ₹100 once for 100 days +30 pooled audio/video minutes, dormant during base-plan lapse.

End local development with evidence-based LOCAL_READY / LOCAL_BLOCKED / NOT_READY. **Deployment is separate.**

## Mandatory 2026-10-28 Figma/API/DB audit addendum

Before declaring LOCAL_READY, read [187-screen final audit](docs/audits/FINAL_FIGMA_SCREEN_BY_SCREEN_API_DB_REPORT_2026-10-28.md), [28 atomic gap remediation tasks](docs/roadmap/FIGMA_SCREEN_API_DB_REMEDIATION_TASKS_2026-10-28.json), [120 conceptual Figma database tables](docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json), and [real ap_m1 external co-parent FK/RLS blocker](docs/data-model/FIGMA_SCREEN_GAP_PHYSICAL_SCHEMA_REVIEW_2026-10-28.md). The original 262 tasks remain unchanged; 28 additional audit tasks apply before final local signoff. Run `python3 backend/tests/lint_openapi_full.py` after checking out the latest specification. The full OpenAPI contains **146 draft operations**, not 146 working handlers. No Figma screen is a verified Android build.


## 2026-10-28 187-screen API/database audit addendum

Before coding, read [post-remediation report](docs/audits/POST_REMEDIATION_SCREEN_API_DB_REPORT_2026-10-28.md), [187-row coverage registry](docs/audits/POST_REMEDIATION_SCREEN_API_DB_COVERAGE_2026-10-28.json) and [54-item GAP task addendum](docs/roadmap/FIGMA_SCREEN_API_DB_REMEDIATION_TASKS_2026-10-28.json) in addition to the existing 262-task graph. Current master `docs/openapi.yaml` includes **171 proposed HTTP operations** but zero independently certified handlers. New generic request-body constraints and conditional feature gates are part of test scope. Base roadmap total 262 is preserved; combined open development backlog **316** tasks. Never mark gaps closed based on OpenAPI alone or force unverified cross-family membership for parent access.

## Latest owner direction (2026-10-28) — overrides earlier Family Link/hosting text

Do not require third-party Google Family Link parent-role verification. Google Sign-In authenticates each adult only, and Madalasa uses an invitation accepted for one **exact child** plus approved authority/consent when legally required, not billing-family membership. Production child-data processing still needs legal review. `0001_m1_identity.sql` is historical; V2 blended-family grants must be a separate migration with SQL RLS and negative tests. OCI production region, cloud tenancy and final bandwidth economics are reserved for deployment; write environment-agnostic, locally benchmarked code without these being prerequisites. [ADR](docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md) · [Play sandbox/evidence](docs/roadmap/IMPLEMENTATION_PROOF_AND_PLAY_SANDBOX_HANDOFF_2026-10-28.md).

## Owner-approved backend architecture (2026-10-29)

Use **Option C**: **Drogon C++20 for the HTTP API**, with independently executable **C++ background workers**, organized as **SOLID, HMVC-style domain modules**. Begin with a modular API and a small number of separate worker processes; do not create a microservice for every screen or introduce userver without a measured requirement. Use narrow interfaces, dependency injection, domain services and adapter/repository boundaries. Modules own their persistence, tests and API contracts; workers use durable transactional inbox/outbox, idempotency, child-level RLS and auditable retries. See [canonical TSD architecture decision](docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md#owner-architecture-decision--2026-10-29-option-c-solid--hmvc--independently-deployable-c-workers). Follow existing branch reuse rules.

## Physical schema audit handoff (2026-10-29)

Before schema changes, read [deep physical schema audit and remediation](docs/data-model/PHYSICAL_SCHEMA_DEEP_AUDIT_AND_REMEDIATION_2026-10-29.md). The V1 ERD JSON has corrected two dangling references to the existing `location_ingest_batches` and `admin_permissions` entities; the Figma canvas still needs sync. Preserve the 18-table M1 physical catalog and its strict CI checks when integrating stacked #3/#4/#5; 103 conceptual entities are not 103 tables to generate automatically. Implement explicit child ownership, typed columns/enums, retention category per physical table, and secure V2 grant migration with executable SQL tests. Reuse existing Git branches by default.

## 2026-10-29 database implementation branch collision — read before SQL work

The live Figma ERD page `92:2` has been synchronized for its two formerly broken references; see [physical schema deep audit](docs/data-model/PHYSICAL_SCHEMA_DEEP_AUDIT_AND_REMEDIATION_2026-10-29.md). **Important:** `feat/local-postgresql-physical-schema` already holds SQL migrations 0002–0015 with schema-completion tests, whereas the M1 PR #3/#4 line independently uses 0002–0004. Do not generate new migrations under these numbers or assume 103 missing ERD entities require separate physical tables. First reconcile histories, dependencies, naming, normalized aliases and physical FK/RLS tests. Do not overwrite or delete the existing local schema branch. Keep branch inventory updated in the canonical branching process.


## 2026-10-31 required P2P transport reading for media/network workers

For media, screen, camera, mic, TURN or high-detail live location work on `api`/`parent`/`child`, first read [MA-P2P-ADR-004](docs/phases/P3-deferred-research/01-media-and-administrator-research/P2P_MEDIA_AND_LIVE_LOCATION_TRANSPORT_ARCHITECTURE_2026-10-31.md). This owner-selected design uses WebRTC/ICE/STUN direct with quota-limited TURN fallback and existing Drogon authentication/signaling—**no custom full-device VPN**. Durable historical GPS remains in backend/PostGIS. **Design only, T-P2P-01…12 NOT RUN, all Android/India legal/Play gates OPEN, capture OFF for children**. Pre-sync both `main` and `dev`; documentation updates stay exclusively on `main`, implementation uses approved workstream → `dev` → `main`.
