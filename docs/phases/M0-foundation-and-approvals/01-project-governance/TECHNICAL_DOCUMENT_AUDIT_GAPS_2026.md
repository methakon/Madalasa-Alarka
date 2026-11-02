# Madalasa–Alarka — Technical Specification and Whole-Project SRS Gap Audit

> **Document control:** M0 / 01-project-governance · Proposed owner: Project owner (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (parent), **Alarka** (child); verified [Madalasa-Alarka GitHub repository](https://github.com/methakon/Madalasa-Alarka). [Brand contract](../02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Audit ID:** AP-AUDIT-2026-10-25-01  
**Audit date:** 2026-10-25  
**Status:** DOCUMENTATION AUDIT ONLY; no application/build/OS device security verification  
**Scope:** Current repository on main, including [SRS](../../M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md), [Technical Specification](../../M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md), [Implementation Technical Specification](../../M1-secure-platform-foundation/01-requirements-and-architecture/IMPLEMENTATION_TECHNICAL_SPECIFICATION.md), [Whole-Project Feasibility Gate](../02-market-and-feasibility/WHOLE_PROJECT_FEASIBILITY_GATE_2026.md), [Adaptive C++ Server Architecture](../../M2-location-collection/01-location-collection-and-ingestion/ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md), [Routes/Stops/Battery](../../M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md), [Draft OpenAPI](../../../openapi.yaml), [Play publishing](../../M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md), [Data safety](../../M9-play-release/01-play-and-data-safety/DATA_SAFETY_WORKSHEET.md), [Account deletion](../../M6-guardian-erasure-security/01-data-erasure-and-access/ACCOUNT_DELETION_DESIGN.md), [Testing](../../M8-operational-readiness/03-quality-and-evidence/VALIDATION_AND_RELEASE_PLAN.md), [Android compatibility](../../M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md) and feedback-derived features.

## Executive assessment

**Result: FAIL for implementation-ready canonical specification; PASS for substantial architectural research and early-stage design foundation.**

The [SRS](../../M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md) was consolidated to **v1.0 with FR-001–FR-049**, including all differentiation proposals D01–D14 and their conditions. However, at time of audit the repository's **canonical** [TECHNICAL_SPECIFICATION.md](../../M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md) still starts with the previous **v0.1** “Technical Specification” and lacks the consolidated v1.0 architecture and complete FR crosswalk. Other detailed designs exist, notably [ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md](../../M2-location-collection/01-location-collection-and-ingestion/ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md). This is a **version and ownership gap**, not evidence the technical ideas are absent everywhere.

**What works well in the design:** strict ordinary vs managed Android mode distinction; planned transparent monitoring; C++ Drogon stateless API plus independent C++ workers; durable idempotent GPS ingest; event-time late/offline trip reconstruction; source/accuracy/gap representation; appropriate PostGIS geometry; no fabricated full roads; family-specific authorization emphasis and Play publication awareness.

**What is not verified:** no APK/AAB build, no complete migrations, no executable backend, no camera/OS feature validation, no real GPS route dataset/battery tests, no C++ load tests, no live privacy/deletion website, no Play Console review. None of the conclusions below should be mistaken for a penetration test or certification.

### Severity vocabulary

- **P0 / Critical:** stop a sensitive or foundational implementation/release until design corrected.
- **P1 / High:** must be resolved before broad integration testing/first live deployment.
- **P2 / Medium:** required before feature delivery or scaling but may be staged.
- **P3 / Low:** clarity/document-maintenance improvement.

## 1. Findings register

| ID | Severity | Gap / observed evidence | Required change | Closure evidence |
|---|---|---|---|---|
| **AG-001** | **P0** | Canonical SRS v1.0 lists FR-001..049 while canonical TECHNICAL_SPECIFICATION.md remains v0.1 and points to supplements; no single authoritative how-to for all 49 | Replace/upgrade canonical TSD to v1.0, using one consistent architecture and explicit annex links; maintain ADRs for conflicts | Every FR maps to TSD section, owners and test |
| **AG-002** | **P0** | openapi.yaml is a partial illustrative contract; no schema for most newer D01–D14, emergency/pickup access, detailed trips/revisions, support diagnostics, policy previews, deletion completion | Expand OpenAPI 3.1 paths, auth scopes, DTOs, statuses, examples, pagination, error codes, idempotency, versioning; lint and generate tests | CI validates spec; mock contract tests of every released endpoint |
| **AG-003** | **P0** | Guardian/family/child/device ACL is described, but cross-family child ownership, guardian invitation proof, shared-access rules, token revocation and SSE/cache invalidation are not locked into a formal policy matrix | Explicit role×resource×action×child grant matrix; invitation acceptance and session invalidation state machine; RLS + controller enforcement | Automated zero-cross-family BOLA/IDOR tests, stream revocation and policy proofs |
| **AG-004** | **P0** | Sensitive deletion/revocation spans partitioned raw GPS, derived tracks, audit, backups, cache, support exports and Drive. Deletion is a proposed state machine, not a provable lifecycle and no final retention defaults exist | Define per-data-category retention, deletion ordering, backup expiration, restore tombstone ledger, customer notice and evidence ledger | Account/device deletion and backup-restore tests cannot resurrect deleted records after declared policy window |
| **AG-005** | **P0 release** | Privacy policy, data-safety answers, support/legal controller details and public in-app/web account deletion endpoints contain TBDs; no working publisher evidence | Final operator, hosting region, subprocessor register, Data safety per released APK, actual URLs and functional requests, policy legal review | Real public HTTPS pages and completed Play Console declarations matching binary/network behavior |
| **AG-006** | **P1** | FR-030–FR-049 acceptance requirements exist but no **full** 49-row FR→code module→API/data→test→release evidence matrix; older validation plan covers only original requirements | Create versioned machine-readable traceability register and test ID registry, including conditional/disabled rows | CI/exportable report shows zero untraced release-scope FRs |
| **AG-007** | **P1** | Location algorithms are conceptual; no fixed tested spec for quality thresholds, speed plausibility, hysteresis, stop min-fixes, time windows, when “live” becomes “stale,” or how to calibrate confidence | Design configuration schema and deterministic C++ processing states, test corpus with labelled journeys, quality-class definitions and versioned algorithm settings | Unit property/replay tests prove stable results and quantified false-stop error bounds |
| **AG-008** | **P1** | Event-time processing mentions leases/revisions, but exactly-once **business effect**, worker fencing and transactional outbox reconstruction across crash/late replay not fully implemented as SQL contract | Provide transaction-by-transaction sequence, event dedup semantics across partitions, worker epoch/fencing token, job coalescing, job poison handling, revision conflict/rollback | Crash at each commit/ack/lease boundary yields exactly one accepted event and convergent final projection |
| **AG-009** | **P1** | Device-state and foreground-service lifecycle matrix is incomplete; one-time parent grants cannot guarantee a background service can always be started, especially Android 14+ | Explicit test decision matrix for initial setup, activity closed, screen off, doze, reboot, force-stop, FGS start failure, background grant and notification state across API29–36 | Real-device test evidence per OS/OEM mode; truthful user-facing error for every forbidden state |
| **AG-010** | **P1** | “Low battery” profiles are interval hypotheses; no fixed energy/route-quality metric formula, SLA by supported device, thermal/network tests or wear sampling budget | Define battery delta baseline, qualifying coverage formula, sampling profile tuning bounds, telemetry throttling, 24h/drive/walk watch trials and graceful degradation | Reproducible battery/accuracy coverage benchmarks and documented profile cutoffs |
| **AG-011** | **P1** | High-level scaling arithmetic (up to 100k devices) exists but no deployment benchmark, peak traffic distribution, DB resource cap, data retention volume, recovery target, or cost envelope | Capacity/load/chaos test plan with observed row/index/WAL, API pool sizes, queue lag, parent fanout, region, cloud spend, RPO/RTO | Recorded synthetic 1k/10k/100k tests, resource limits and failover/restore recovery evidence |
| **AG-012** | **P1** | Data model proposals differ: some documents speak parent_id, some family_id and child_id, while device ownership and guardian grants are not normalized in runnable DDL | One versioned PostgreSQL/PostGIS migration set with FK/index/partition/RLS policies and tenant-invariant checks | Clean migration + rollback + tenant-isolation tests in CI |
| **AG-013** | **P1** | Remote command and SOS lifecycle describes statuses but lacks a canonical exhaustive transition table, priority policy, timeout races, notification acknowledgement semantics and escalations | Typed command schema, state transition table, SOS at-least-once delivery/ack, retry quotas, bounded ring command, severity escalation; no emergency dispatch promise | Deterministic offline/replay/expiry/rate-limit tests, observed status not assumed success |
| **AG-014** | **P1** | Sensitive optional modules (managed device blocking, camera/mic, protected files) remain mixed into broad product scope; no separate permission/distribution decision records or fallback UI to avoid false promises | Feature-level capabilities by Android API/standard-vs-managed, distro channel and consent. Keep media disabled until permitted visible workflow AND policy gates | Release manifests omit unused high-risk permissions; managed app suspension only on enrolled test device |
| **AG-015** | **P1** | Play target API/16KB requirements documented, but release-specific package IDs, two-app manifest permission mapping, compliance video, AAB checks and signed artifacts absent | Parent/child/Wear build matrix, Gradle manifests/CI, monitoring metadata, notification/disclosure walkthrough, AAB/16KB native checks, Play reviewer credentials workflow | Real release AABs and approved Play forms/test track results |
| **AG-016** | **P1** | Parent location-data rights, guardian authority, appropriate child disclosure and target countries/ages not formally decided; incidental child data access may be broader than needed | Document acceptable parent authority, eligibility/consent, role limits and applicable jurisdictions with privacy/legal review | Signed jurisdiction and child-data collection assessment; UI and processor contract updates |
| **AG-017** | **P2** | Offline queue bounds, encryption/key lifecycle, sequence reordering, clock skew, dropped records and corruption recovery are not precise implementation contracts | Specify SQLCipher or reviewed app-level encryption, Keystore key recovery, queue schema/limits/TTL, clock correction protocol, overflow UI, retry backoff and preservation rules | Fault test process kill/storage full/key invalidation/network loss |
| **AG-018** | **P2** | Parent map/saved-place UX does not yet have complete state/error vocabulary: unknown vs no-show, pass-near vs stop-at, ambiguous named places, multiple guardians editing same pin | Parent UX state machines; optimistic locking/versioning for places, quality legend, location-source selection and conflict/reconciliation | UI acceptance tests for stale offline, gaps, conflicting pins and multiple source devices |
| **AG-019** | **P2** | Device ownership transfer, reinstall, watch-phone companion identity, same child multiple devices and guardian conflict are underspecified | Enrollment/recovery and legitimate device transfer state machine; source provenance, key rotation and duplicate installation handling | Pair/unpair/reinstall/factory reset/phone replaced/watch disconnected test matrix |
| **AG-020** | **P2** | App usage aggregation rules for timezone, partial periods, Android API variability and year-long collection are underspecified, especially with revoked Usage Access | Define canonical UTC storage, home/report timezone rules, day/weekly/monthly/year rollover and data completeness metadata | Reproducible comparisons to controlled device usage; incomplete period displayed not zero |
| **AG-021** | **P2** | Third-party costs/permissions aren't in a measured budget: Google Maps/Places/Roads, FCM, Billing, Drive and region-specific payment/cloud support | Provider per-feature cost/quotas, cloud regional choice, fallback and key restrictions; Roads asset-tracking legal decision, caching/attribution | Cost per 1k devices and bounded quotas; provider-contract review |
| **AG-022** | **P2** | Observability/runbooks exist at a general level but no real SLO alert thresholds, support workflow, key rotation, security incident RTO/RPO and rollback ownership | Define on-call owner, dashboards, incident severities, alert thresholds, backup restore and secret rotation drill plan | Staging fault drill with evidence and redacted logs |
| **AG-023** | **P2** | New feature estimates in feedback report use person-days, but no backlog IDs, owner role, dependencies and release phase per selected D01–D14, so whole-project scope can grow uncontrolled | Adopt release scope baseline P0/P1 vs optional P2/P3, feature dependency graph, acceptance/kill criteria and cost estimate | Approved MVP scope and issue backlog mapped to AG/FR IDs |
| **AG-024** | **P2** | Details of platform execution for wear/tablets and optional geofences have no live support/certification thresholds; watches may borrow phone location | Separate parent/child/Wear app build and capability matrices; no-GPS and paired-phone-unavailable detection; geofence candidate subset | Named-device and real battery/handoff tests |
| **AG-025** | **P2** | Potential conflicts between document snapshots and design decisions; SRS calls itself current, v0.1 older TSD is still top-level, old release plan phases M0–M7 vs new M0–M9 | Add documentation hierarchy/version ownership and consistent roadmap IDs/ADR migration log | README and spec references point to one canonical v1.0, all related docs indexed |
| **AG-026** | **P3** | No precise generated client/server schemas and unified error catalog; ad hoc JSON may diverge across Kotlin and C++ | OpenAPI code generation or validated DTO templates; normalized error codes and schema migration compatibility tests | Compile-time/generated contracts and version-mismatch tests **Update 2026-10-28:** the M1 error catalog, idempotency, pagination, versioning and format rules are now in [API conventions and error catalog](../../../API_CONVENTIONS_AND_ERROR_CATALOG.md) and lint-enforced; generated DTOs and version-mismatch tests remain open. |

## 2. Root causes and concrete examples

### 2.1 Canonical document mismatch (AG-001, AG-025)

The whole-project SRS is v1.0 (FR-001–FR-049). The original technical specification was still headed simply **“Technical Specification”** with architecture and v0.1-style initial API/data model; the expanded D01–D14 methods live in other documents. This is a significant operational risk: one developer may implement against the old eight-table schema while another implements the family/guardian/child grant schema.

**Correction:** Make TECHNICAL_SPECIFICATION.md the canonical v1.0 module/data/API/algorithm roadmap, with explicit references for deep sub-algorithms. Archive the former version or preserve Git history. Keep separate change log and requirement crosswalk. Do not copy conflicting design choices into multiple standalone “canonical” files.

### 2.2 OpenAPI divergence (AG-002, AG-026)

openapi.yaml currently contains foundational endpoints (pairing, device summaries, locations, a basic usage read and command statuses), but it does not implement a complete contract for D01–D14 or every revised SRS FR. Actual API implementers need:
- Parent role and child-specific scopes per endpoint; no default broad authorization solely based on bearer authentication.
- Authenticated device binding to request path and validation of event ID, timestamps, accuracy, batch bounds, location precision, clock skew and compressed input.
- Typed SOS, named places, trip revisions, health/reliability, time-limited grants, access receipts, policy preview, capability/billing, export/deletion and support endpoints.
- All response/error shapes and idempotency semantics, pagination, cursors, request timeout, batch receipts, status transition table and API deprecation/version policy.
- A generated implementation/mock contract test; **YAML was not linted by this audit**, so do not conclude syntactic validity solely from its presence.

**Correction:** Keep an OpenAPI design review as a separate P0 gate before API implementation.

### 2.3 Multi-tenant isolation is a release blocker (AG-003, AG-012)

Multiple parents and children sharing data is easy to implement incorrectly. Define the canonical principal/family/child/device relationship and all authorized scopes before code. PostgreSQL RLS adds defense in depth, but table owners usually bypass it, and a parent who belongs to a family does not automatically have a grant to every child. Worker SQL roles and long-running live streams need equally strict protection.

**Correction:** a full role×resource×action matrix plus transaction-local trusted RLS context, and tests for **every** query and stream, not only the initial REST handler. Revoked guardians must stop receiving live position immediately.

### 2.4 Event-time consistency and offline replay (AG-007, AG-008, AG-017)

A device might capture 08:00–09:00 offline and upload at 11:00. Another sync may replay identical event IDs with slightly different timestamps. Raw points and derived trips cannot be deduplicated by \`(device_id, observed_at)\` alone. PostgreSQL unique indexes on time-partitioned tables must include the partition key.

**Correction:** stable device_event_dedup ledger with retention-safe replay behavior, durable inbox/outbox transaction, per-device job leasing with worker fencing, algorithm version and revision-aware derived writes. Test server crashes between every step. Define how to handle late events beyond the watermark and even beyond retention.

### 2.5 Location “intelligence” needs measured scientific criteria (AG-007, AG-010, AG-018)

Candidate dwell windows of 3–5 minutes (walking) or 5–10 minutes (vehicle), requested location intervals and approximate radius rules are planning heuristics. With 15-minute stationary sampling, the system may have **too few observations** to confidently identify a five-minute stop. An algorithm that presents every short proximity as a “visit” would produce false safety reports.

**Correction:** define minimum supporting fixes, accuracy-weighted radius, time bounds, dwell persistence, stop/arrival classes (CONFIRMED, PROVISIONAL, AMBIGUOUS, UNKNOWN), false-positive/error budgets and a labeled dataset. Where evidence is insufficient, show “possible stop” or “arrival not confirmed,” never assert a completed visit.

### 2.6 Publication and legal readiness (AG-005, AG-014–AG-016)

A parental monitoring application may be permissible on Play if marketed and implemented transparently, but the actual release must satisfy applicable monitoring-app identity, persistent notification, background-location declarations/disclosure and sensitive-permission review. **Android 16/API 36** is the current new-phone-app target for submissions as of October 2026, with specialized Wear requirements. Native C++ dependencies need validated 16 KB page support. Privacy policy, controller identity, data residency, retention, account deletion and parent-child authorization still have unresolved decisions.

**Correction:** require a *release-manifest and data-flow* reconciliation checklist per package and track, plus running privacy/deletion URLs and legal review. Do not assume an optional device-owner feature makes a consumer personal phone managed; do not advertise hidden recording.

## 3. Missing implementation artifacts, by team

| Owner role | Artifact missing or not finished | Suggested source/location | Exit condition |
|---|---|---|---|
| Product / systems architect | Canonical v1.0 TSD, ADR hierarchy, release feature scope | docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md and docs/ADRs/ | FR coverage and signed scope |
| Backend/C++ lead | Stable domain types, producer/consumer transaction contract, worker lease fencing spec, normalized failure catalog | backend/domain + docs/openapi.yaml | Crash/replay/concurrency tests |
| Security lead | Formal threat model, endpoint scope matrix, family/child RLS enforcement, token policy and SSE revoke behavior | docs/phases/M8-operational-readiness/02-operations-and-support/SECURITY_AND_OPERATIONS.md addendum | No cross-tenant leaks |
| Android lead | Permission/FGS lifecycle matrix with source/build/targetSdk, signed capability report, encrypted queue recovery | android/child-app and compatibility document | Instrumentation on supported OEMs |
| Geo/algorithm lead | Versioned stop/trip math, quality class definitions, labeled routes and performance benchmark | docs/ROUTE_ALGORITHM_PROFILE.md + CTest corpus | Measured stop precision/recall and gap integrity |
| DB/data lead | Executable migrations, table FK/constraint policies, time partitions, retention and deletion jobs | backend/migrations/ | Clean apply/rollback + deletion test |
| Parent Android lead | UI state model for stale/unavailable/ambiguous, invite/revoke, receipts and payments | parent app UX spec | All statuses verified in UI tests |
| QA/release lead | Full FR-001–049 traceability, SLO test matrix, Android/watch/16KB build evidence | docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/REQUIREMENTS_TRACEABILITY.md | All release-scope rows have evidence |
| Privacy/legal lead | Consent authority, supported countries/ages, retention, actual policy URL, Play data safety and account-deletion behavior | docs/phases/M9-play-release/02-public-legal-drafts/PRIVACY_POLICY_DRAFT.md etc. | Real legal operator and published policy match binaries |
| SRE/operations | RPO/RTO, incident on-call, capacity baseline, key rotation, cost budget and monitoring | docs/phases/M8-operational-readiness/02-operations-and-support/SECURITY_AND_OPERATIONS.md | Tested restore/failover and bounded cloud expenses |

## 4. Remediation ordering — avoid expensive rewrites

### Phase 0 — Before implementing irreversible schemas (P0)

1. **AG-001 + AG-025:** Choose canonical v1.0 architecture and authoritative document index.
2. **AG-003 + AG-012:** Freeze family/guardian/child/device authorization rules and normalized DB keys/RLS.
3. **AG-002:** Design complete versioned API and status schemas.
4. **AG-004 + AG-016:** Decide location/usage/audit retention, deletion, age/guardian legal authority and hosting region.
5. **AG-014:** Split standard/managed/research-only feature flags; exclude unnecessary sensitive permissions from planned MVP manifest.

### Phase 1 — Foundation implementation readiness (P0/P1)

6. AG-008 + AG-017: design durable event ingest, dedup, worker fencing and on-device encrypted queue.
7. AG-006: build FR-to-test contract and CI checks.
8. AG-009 + AG-015: validate Android supported permission/FGS/build configurations.
9. AG-007 + AG-018: define deterministic geospatial quality and stop test cases.
10. AG-013: canonical command/SOS state machine and error outcomes.

### Phase 2 — Field testing and first consumer release

11. AG-010 + AG-011: battery, tracking accuracy, queue-load and cloud cost evidence.
12. AG-019 + AG-020 + AG-024: multi-device/usage/guardian edge tests.
13. AG-005 + AG-015 + AG-016: public data deletion/privacy pages and Play reviewer declarations.
14. AG-022 + AG-023: operational runbooks and controlled MVP scope.
15. AG-021 + AG-026: provider contractual cost and generated DTO/client contract completeness.

## 5. Prioritized signoff checklist

| Gate | Status 2026-10-25 | Who signs off |
|---|---|---|
| SRS v1.0 exists | **Documented** | Product |
| Canonical TSD v1.0 matches SRS | **GAP** | System architect |
| 49-FR traceability and exact API schemas | **GAP** | Backend/QA |
| Family-child grants & RLS proof | **GAP** | Security |
| Runnable DB migrations/worker recovery contract | **GAP** | Backend/DB |
| Child app Android lifecycle tests | **NOT TESTED** | Android QA |
| Offline reconstruction labelled GPS tests | **NOT TESTED** | Geo QA |
| Battery/Wear/Tablet optimization claims | **NOT TESTED** | Device QA |
| Backend 1k/10k/100k simulations | **NOT TESTED** | Performance |
| Privacy/deletion URL and retention | **GAP** | Privacy/legal |
| Google Play declaration approval | **NOT SUBMITTED** | Release |
| Signed AAB and 16 KB native libraries | **NOT BUILT** | Android release |
| Feature release approvals | **NONE** | Product/security/QA |

## 6. Public authoritative sources verified for this audit

1. Play target API (August 31, 2026): https://support.google.com/googleplay/android-developer/answer/11926878
2. Android FGS while-in-use/background restrictions: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
3. Android typed foreground services: https://developer.android.com/about/versions/14/changes/fgs-types-required
4. Google Play monitoring applications: https://support.google.com/googleplay/android-developer/answer/9888380
5. Background location declaration and video: https://support.google.com/googleplay/android-developer/answer/9799150
6. Account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
7. Native 16 KB memory page support: https://developer.android.com/guide/practices/page-sizes
8. PostgreSQL row level security (owner/BYPASSRLS): https://www.postgresql.org/docs/current/ddl-rowsecurity.html
9. PostgreSQL partitioned unique constraints: https://www.postgresql.org/docs/current/ddl-partitioning.html
10. Google Roads API policies and possible asset-tracking license: https://developers.google.com/maps/documentation/roads/policies
11. Android FLP batched update ordering: https://developers.google.com/android/reference/com/google/android/gms/location/LocationRequest.Builder

## 7. Conclusion and audit ownership

**Decision: CONDITIONAL DESIGN ACCEPTANCE ONLY.** The documents provide enough architecture to plan work and build disposable prototypes, but not enough verified constraints to authorize a production service collecting children's precise location or a Google Play release.

Most urgently: **(1) upgrade canonical technical spec, (2) lock access control and deletion semantics, (3) complete API+DB contracts, (4) prove Android collection/worker correctness through tests, then (5) demonstrate battery/scaling/policy compliance.**

This audit leaves the implementation documents unchanged: findings are recorded here pending corrective architecture work. Each item should become an issue with owner, target phase, evidence link and resolution before closure. Do not label documentary improvements as actual testing or feature completion.

## 8. Remediation update — 2026-10-25

This audit remains the historical **finding record**; its original conclusion was accurate before remediation. The follow-up [Remediation Status Ledger](AUDIT_REMEDIATION_STATUS.md) tracks all AG-001–AG-026 against newly written canonical [Technical Specification v1.0](../../M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md), expanded [OpenAPI draft](../../../openapi.yaml), [49 FR/16 NFR Traceability](../../M1-secure-platform-foundation/01-requirements-and-architecture/REQUIREMENTS_TRACEABILITY.md), [Data/Authorization/Recovery](../../M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md), [Android/Geo Algorithms](../../M2-location-collection/01-location-collection-and-ingestion/TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md), [Command/SOS/Usage/Queue](../../M4-usage-health-sos/01-usage-health-and-sos/COMMAND_SOS_USAGE_QUEUE_CONTRACT.md) and [Owner Blockers](BLOCKERS_AND_OWNER_DECISIONS.md).

Documentation design gaps are narrower, but **all actual implementation, real-device, security, privacy and Play approval evidence gates remain OPEN** until the listed test artifacts exist.

## 2026-10-26 supplemental media capability and parent-error decision

The owner accepted conditional remote audio listening/recording, live camera/photo/video, flash-off where supported, scoped file access, and per-session-approved screen viewing **for technical investigation**, not launch. Prior references to "restricted" do not mean platform impossibility. The standard versus genuine managed-device-owner Android restrictions, setup-only Alarka main Activity, required monitoring/sensor indicators and exact Madalasa failure reason/next-action mapping are specified in [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md). All legal/Google Play, runtime device/OEM, privacy/security and actual implementation proof gaps remain OPEN; verify T-MEDIA-01–18 before any release promotion.

## 2026-10-27 capability discovery / report-trust gap addendum

The owner accepted full initial Alarka read-only feature scan, per-feature Android grant guide/actual OS confirmation, trusted report to C++ backend, Madalasa child-scoped API compatibility list, later revocation/regrant rechecks and precise parent green/amber/red/grey with freshness. See [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md), [whole-project OpenAPI design](../../../openapi.yaml), [T-CAP-01…24](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md#7-tests-and-evidence-all-not_implemented--not_tested), [Figma 46 screens](../../../ui/figma-functional-handoff/06-capability-onboarding.json). New design closes **documentation ambiguity**, not any real implementation, OS/OEM testing, M1 lint execution, legal/Play, authenticated report, backup/restore or security audit finding. Danger: Android revoke may kill Alarka before network upload; never represent last-known permission as current live status. Older M1 11-op scope remains narrow pending explicit migration.

## 2026-10-27 metadata-only media and administrator-panel gap resolution (design only)

Earlier project had no dedicated administrator-panel document or media event history schema/parent+admin browsing contract. New [Admin Panel Specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md) defines roles/case access/step-up MFA, parent+child name/ID autocomplete, audit of admin access, retention controls and desktop UI; [Media Activity ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md) defines device/parent verified event state, nullable file size vs network bytes, viewed-only/saved receipt and accurate OS failure reason provenance, child filtering, UTC date ranges and stable pagination. Whole-project OpenAPI has design-only endpoints, but M1-only API remains untouched. [Figma 28 screens](../../../ui/figma-functional-handoff/07-media-activity-audit.json) plus HLD/LLD are editable design artifacts. **Open gaps:** no real DB migration, admin identity provider, role approval workflow, counsel decision, Play review, T-AUD/ADM automation, load testing or actual production implementation.

## 2026-10-27 GPS ingest architecture cross-document consistency fix (NOT TESTED)

The accepted [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) resolves ambiguity between 'durable response after raw+outbox COMMIT' and a new separate server queue. **Selected design:** API 202 after authenticated PostgreSQL **inbox Tx A** committed; worker final raw+dedup+outbox+inbox PROCESSED **Tx B** committed later; trip processing later again. The old direct bulk commit exists **only as performance comparison**, since inbox adds WAL and temporary coordinate copies and cannot be claimed cheaper without benchmarks. JSON batches come from independently sampled GPS and local encrypted 48h offline-capacity queue; 1–2min upload only when Android permits, not a WorkManager guarantee. Native editable [HLD and LLD diagrams](../../../ui/figma-functional-handoff/08-postgres-gps-batch-system-design.json) and detailed T-ING-01…24 planned. Open: app runtime/FGS tests, exact SQL and API client contract migration, production storage/backups, lease fencing, crash recovery, 1k/10k/100k performance, India child data and Play permissions.
