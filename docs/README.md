# Madalasa–Alarka — Project Documentation Library

**Organized:** 2026-10-27 · **Updated:** 2026-10-31 · **Scope:** controlled specifications and scoped engineering evidence, not whole-product or release acceptance. Canonical source documents are organized **by M0–M9 project phase, then by category** using the repository's [master milestone plan](phases/M0-foundation-and-approvals/01-project-governance/MASTER_MILESTONE_IMPLEMENTATION_AND_RELEASE_PLAN.md). P3 research remains outside the launch milestones.

The 72 root-level compatibility pointers were consolidated into [legacy-root-links](legacy-root-links/README.md), while their canonical M0–M9 full documents and the two OpenAPI files remain in place. Old direct GitHub root-level pointers should now be replaced by canonical document links.

## Start here

**Worker branch routing (mandatory):** [owner-approved workstream → dev → main policy](phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md). All documentation and planning are authored on `main` only; the five persistent work branches are `api`, `parent`, `child`, `admin-web` and `dev`. This rule overrides older feature-branch guidance.

[Master Document Control Register](MASTER_DOCUMENT_CONTROL_REGISTER.md) · [Document Control Policy](DOCUMENT_CONTROL_POLICY.md) · [Phase Coverage Matrix](PHASE_DOCUMENTATION_COVERAGE_MATRIX.md) · [Relocation Manifest](DOCUMENT_RELOCATION_MANIFEST.json) · [M1 OpenAPI contract](openapi-m1.yaml) · [Whole-project API design](openapi.yaml) · [Figma design handoff](ui/figma-functional-handoff/README.md)

[Current machine register](document-control-register.json) · [Evidence-separated phase checklist](DOCUMENTATION_PHASE_GATE_CHECKLIST.md) · [Documentation verification tools](tools/README.md)

## Swagger/OpenAPI developer tooling — 2026-10-31

[Local Swagger UI install, M1 vs design-only API views and secure synthetic Try it out](phases/M1-secure-platform-foundation/02-development-process/SWAGGER_OPENAPI_DEV_WORKFLOW_2026-10-31.md). Swagger runs on loopback as a developer process, not on production Drogon. Existing OpenAPI source files remain authoritative and unchanged.

## M1 API coding progress — 2026-10-31

[14-operation M1 route implementation matrix, latest synthetic CI checkpoint and unresolved security integration](phases/M1-secure-platform-foundation/02-development-process/M1_API_HANDLER_IMPLEMENTATION_STATUS_2026-10-31.md). Code lives on `api` only and is not merged. The wider Figma-linked API lists 171 *planned* operations, not completed endpoints. The V2 trusted-session issuer and positive role/tenant isolation tests still gate E-02.

## 2026-10-31 P2P-first media/live-location architecture

[MA-P2P-ADR-004](phases/P3-deferred-research/01-media-and-administrator-research/P2P_MEDIA_AND_LIVE_LOCATION_TRANSPORT_ARCHITECTURE_2026-10-31.md): WebRTC ICE/STUN direct, TURN relay when necessary, existing Drogon signaling, no custom VPN for these features; separate durable GPS pipeline. **Documentation only:** Android/Indian counsel/Play gate approvals remain OPEN and child capture release OFF.

## X-02 Google Play G01/G04 decision pack — 2026-10-31

[Official-policy review, evidence checklist and existing-support-case status](phases/M9-play-release/01-play-and-data-safety/X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md): Alarka true-audience and precise-location Families eligibility must be resolved **before** separate background-location declaration. Monitoring-app flag alone does not exempt location; both decisions remain open and no child release is authorized. No duplicate support case created.

## X-03 Indian child-data lawfulness — clarification 2026-10-31

[Independent primary-text DPDP Act/Rules review and feature matrix](phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md#2026-10-31-first-party-primary-law-review-no-mandatory-paid-counsel-opinion) replaces the compulsory-paid-lawyer-paperwork assumption; substantive child-data lawfulness remains gated.

**Legal compliance for each enabled feature is required; buying a signed lawyer opinion/printed certificate is not a general prerequisite.** The owner is preparing an evidence-backed feature-by-feature assessment; Tele-Law case registered, MeitY clarification email sent, responses pending. A substantive counsel email can support the record. Release-sensitive child-data features remain OFF while the substantive legality and Android/Play gates are unresolved. [Current X-03/G02 disposition](phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md).

## X-01 status — 2026-10-31

**Google Play publisher identity: COMPLETED (owner-confirmed).** BillDesk/payment verification: **SUBMITTED; AWAITING PROVIDER RESPONSE**. Distinct merchant/payment account activation: **NOT CONFIRMED**. Identity verification is removed from the active blockers; related payment activation remains a separate external dependency. [Canonical X-01 breakdown](phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md).

## Historical 2026-10-30 progress (prior identity statuses superseded)

- [2026-10-30 cross-phase progress, changed documents, decisions and next work](phases/M0-foundation-and-approvals/01-project-governance/PENDING_IDENTITY_PROGRESS_2026-10-30.md).
- [Historical exact-revision PR9 M1 stack review and PostgreSQL16/CI evidence](phases/M1-secure-platform-foundation/02-development-process/M1_STACK_PR9_REVIEW_2026-10-30.md). Later owner-authorized M1/OIDC integration and verified remote cleanup are recorded in the [current branch register](phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md); V2 database convergence remains blocked and its unique branch retained. Merge authorization is not deployment or release approval.
- [Canonical feature-by-feature Android feasibility matrix](phases/M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md), [Play reviewer pack](phases/M9-play-release/01-play-and-data-safety/PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md), [billing policy](phases/M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md), and [security evidence queue](phases/M8-operational-readiness/03-quality-and-evidence/TEST_STRATEGY_UNIT_INTEGRATION_LOAD_SECURITY.md).
- Publisher decision: **SWARNA SEKHAR DHAR**, individual, India; same legal and Play publisher. **2026-10-31 update:** Play publisher identity COMPLETED (owner-confirmed); BillDesk/payment submitted with review pending; separate merchant activation not confirmed; legal review and public support contact remain pending. These pending external gates do not stop synthetic tests, compliance analysis or documentation preparation. No Android implementation or real-child release is approved by this checkpoint.

## Repository Subfolder Structure

| Directory | Scope & Contents | Index |
|---|---|---|
| [`phases/`](phases/README.md) | Canonical M0–M9 phase specifications, architecture contracts, and governance | [Browse Phases](phases/README.md) |
| [`roadmap/`](roadmap/README.md) | Local task graph, DAG execution status, decision ledger, and test evidence rules | [Browse Roadmap](roadmap/README.md) |
| [`data-model/`](data-model/README.md) | Logical 11-domain ERD, physical schema mappings, and relational audit reports | [Browse Data Model](data-model/README.md) |
| [`audits/`](audits/README.md) | 187-screen Figma audits, 171 API contract crosswalks, and blocker reports | [Browse Audits](audits/README.md) |
| [`ui/`](ui/README.md) | Figma screen indexes, Theme C narrative, design tokens, and functional handoffs | [Browse UI](ui/README.md) |
| [`legacy-root-links/`](legacy-root-links/README.md) | Consolidated redirect pointers preserving historical root documentation links | [Browse Legacy Links](legacy-root-links/README.md) |
| [`tools/`](tools/README.md) | Automated document validation, reorganization verification, and check scripts | [Browse Tools](tools/README.md) |

## Milestones and folders

| Phase | Document category / purpose | Source documents | Browse |
|---|---|---:|---|
| **M0** | Project foundation, ownership, market feasibility, India privacy and legal decisions | 25 | [M0-foundation-and-approvals](phases/M0-foundation-and-approvals/README.md) |
| **M1** | Secure Android/C++ foundation, M1 requirements, developer standards and permissions | 16 | [M1-secure-platform-foundation](phases/M1-secure-platform-foundation/README.md) |
| **M2** | Android location collection, encrypted offline queue and durable GPS ingestion | 3 | [M2-location-collection](phases/M2-location-collection/README.md) |
| **M3** | Trip, stop and named-place geometry from recorded locations | 1 | [M3-trips-and-places](phases/M3-trips-and-places/README.md) |
| **M4** | UsageStats, check-ins, health and SOS delivery semantics | 2 | [M4-usage-health-sos](phases/M4-usage-health-sos/README.md) |
| **M5** | Eligible managed Android policies and Device Owner lifecycle | 0 | [M5-managed-android-controls](phases/M5-managed-android-controls/README.md) |
| **M6** | Per-child delegated access, account deletion, backups and recovery | 1 | [M6-guardian-erasure-security](phases/M6-guardian-erasure-security/README.md) |
| **M7** | Commercial integration, child-seat pricing and budgets | 3 | [M7-commercial-integrations](phases/M7-commercial-integrations/README.md) |
| **M8** | Operational readiness, cloud, backup, incident response, support and QA | 10 | [M8-operational-readiness](phases/M8-operational-readiness/README.md) |
| **M9** | Google Play launch, reviewer declarations, Data Safety and public contracts | 7 | [M9-play-release](phases/M9-play-release/README.md) |
| **P3** | Deferred media experiments, activity metadata and admin-panel research | 3 | [P3-deferred-research](phases/P3-deferred-research/README.md) |
| **CROSS** | Cross-milestone diagrams and existing Figma architecture indexes | 1 | [cross-milestone-references](phases/cross-milestone-references/README.md) |

**72 migrated canonical full-text source documents** (historical relocation baseline), plus subsequently registered supporting records, [two root OpenAPI contracts](openapi-m1.yaml), existing [Figma/tldraw handoffs](ui/), and root repository governance files. Historical forwarding pages are consolidated under `legacy-root-links/`; use canonical phase/category URLs rather than retired direct root paths.

## Professional control and approval approach

Filing into a phase/category is not a claim of internal sign-off. Every migrated document has a navigation-only header linking the [Master Document Control Register](MASTER_DOCUMENT_CONTROL_REGISTER.md), with a **proposed owner role** and conservative approval state. No individual has been assigned or signed a decision by this reorganization. The [Control Policy](DOCUMENT_CONTROL_POLICY.md) specifies IDs, versioning, accountability, review records, baselines and supersession.

**Critical open gates:** India children's location/usage lawfulness and Play eligibility; separate merchant/payment activation and lawful guardian authority (Play publisher identity is completed per owner); category retention; processor DPAs/deployment region; production incident/support contacts; licensing; genuine provider-issued OIDC acceptance, V2 convergence and full Android/backend acceptance. The real OIDC verifier/JWKS implementation has scoped local/CI evidence, not genuine-user/provider-to-database or full-product acceptance. M5 has no dedicated standalone technical design and is explicitly flagged in its phase index. All real-child pilot/release gates remain blocked until actual evidence and approval.

**Stable paths:** `docs/openapi-m1.yaml` and `docs/openapi.yaml` remain unchanged so existing CI/requirements contracts are not silently broken. `docs/ui/` remains in its established Figma/tldraw handoff layout.

## Agent-ready local coding plan

Use [2026-10-28 local development roadmap](roadmap/LOCAL_AGENT_DEVELOPMENT_ROADMAP_2026-10-28.md) and [262-task dependency graph](roadmap/LOCAL_TASK_GRAPH_2026-10-28.json) with [evidence rules](roadmap/AGENT_EXECUTION_AND_TEST_EVIDENCE.md). This complements older M0–M9 milestones; it does not mark them completed. [Deployment and Google Play review remain separate](roadmap/DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md).

## Local database implementation checkpoint

The [local PostgreSQL package](data-model/local-postgresql/README.md) groups its [runbook](data-model/local-postgresql/RUNBOOK.md), [current status](data-model/local-postgresql/STATUS.md) and redacted execution evidence. It supplements the historical documentation-first baseline above: implementation has begun on a feature branch, but full verification and migration-chain integration remain incomplete. No production or admin API readiness is implied.
