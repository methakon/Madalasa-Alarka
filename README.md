# Madalasa & Alarka — Android Family Safety Platform

> **MANDATORY FOR ALL WORKERS (owner decision 2026-10-31):** Read [AGENTS.md](AGENTS.md) and the [canonical branch workflow](docs/phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md) first. Five working branches `api`, `parent`, `child`, `admin-web`, `dev` plus `main`. All implementation goes **workstream → dev (integration tests/clearance) → main (final verification)**. **All documentation and planning changes go to `main` only.** Temporary branches require explicit owner direction and are deleted only after proven main integration. This branch policy is not release authorization.

> **Project documentation is now organized by M0–M9 phase and category.** Start at the [Documentation Library](docs/README.md), [Master Document Control Register](docs/MASTER_DOCUMENT_CONTROL_REGISTER.md), and [Phase Coverage Matrix](docs/PHASE_DOCUMENTATION_COVERAGE_MATRIX.md). The original docs filenames remain as forwarding pages; API contracts and Figma inventories retain their stable paths. This is a documentation organization change, **not** an Android or backend implementation claim.

> **Product names:** **Madalasa** (parent app), **Alarka** (child app). GitHub repository **[Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka)** is the verified current name (renamed 2026-10-26). Use the verified new repository URL for all current documentation and integrations. [Naming rationale](docs/phases/M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Status:** Requirements and architecture planning  
**Documentation baseline:** SRS and canonical technical specification v1.0; deployment plan is not deployed  
**Repository (renamed):** [`methakon/Madalasa-Alarka`](https://github.com/methakon/Madalasa-Alarka)

**Madalasa & Alarka** is an India-first family-safety project inspired by Madalasa's guidance to her son Alarka in the *Markandeya Purana*. It consists of three planned components:

1. **Alarka — child Android companion** — a transparent, permission-based app with a C++ native core and Kotlin/Java integration with Android APIs.
2. **Madalasa parent app/dashboard** — map, location history, speed when available, app-usage summaries, and supported remote controls.
3. **C++ backend** — device pairing, authenticated synchronization, command delivery, telemetry storage, subscription checks, auditing, and optional parent-authorized Google Drive backup.

The child app's main activity does not need to remain open for every background feature. However, Android may require foreground services, persistent notifications, privacy indicators, specific Settings grants, or user interaction for particular capabilities.

## Developer quick-start — current repository stage (2026-10-27)

**Current executable baseline:** M1 API structural contract and synthetic PostgreSQL tenant-isolation SQL tests. **Not yet available:** runnable Android apps, C++20 Drogon server, OCI deployment, admin console, Play release or real-child data processing.

```bash
git clone https://github.com/methakon/Madalasa-Alarka.git
cd Madalasa-Alarka
python3 backend/tests/lint_openapi_m1.py docs/openapi-m1.yaml
```

For the synthetic PostgreSQL 16 migration/RLS test, see **[Build and Run](docs/phases/M1-secure-platform-foundation/02-development-process/BUILD_AND_RUN.md)**; it uses an isolated disposable database, not real user information. The new `android/alarka` and `android/madalasa` directories contain **non-runnable Kotlin domain scaffolding**, with no Gradle wrapper or AndroidManifest. `.env.example` contains placeholders only; do not commit credentials.

**Start here:**
[Engineering/Legal Document Index](docs/phases/M0-foundation-and-approvals/01-project-governance/PROJECT_DOCUMENTS_INDEX_2026.md) ·
[Onboarding/Coding Standards](docs/phases/M1-secure-platform-foundation/02-development-process/DEVELOPER_ONBOARDING_AND_CODING_STANDARDS.md) ·
[Contributing](CONTRIBUTING.md) ·
[Issue/PR Templates](.github) ·
[Security Reporting](SECURITY.md) ·
[STRIDE](docs/phases/M1-secure-platform-foundation/03-security-and-permissions/THREAT_MODEL_STRIDE.md) ·
[Tests](docs/phases/M8-operational-readiness/03-quality-and-evidence/TEST_STRATEGY_UNIT_INTEGRATION_LOAD_SECURITY.md) ·
[Deployment/Legal Gate](docs/phases/M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md).

**New review drafts:** [DPIA](docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md), [Retention](docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md), [Parental Authority](docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/VERIFIABLE_PARENTAL_CONSENT_AND_GUARDIAN_AUTHORITY.md), [Grievance](docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/GRIEVANCE_OFFICER_AND_REDRESSAL_PROCESS.md), [Vendor DPA Register](docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/VENDOR_DPA_AND_PROCESSOR_REGISTER.md), [CERT-In/DPDP Incident Procedure](docs/phases/M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md), [Play reviewer pack](docs/phases/M9-play-release/01-play-and-data-safety/PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md), and [staged public legal pages](public/legal/README.md). Legal texts are **unapproved and not published**; publisher and contacts unassigned. Root `LICENSE` is an interim all-rights-reserved notice pending an explicit IP-owner license decision.

[GitHub About description/topics owner checklist](docs/phases/M0-foundation-and-approvals/01-project-governance/REPOSITORY_ABOUT_AND_TOPICS.md) explains settings that **must be applied in GitHub UI**; committing docs doesn't change repository metadata.

## About the Madalasa and Alarka names

**Madalasa** is named for Queen Madalasa from the *Markandeya Purana*, remembered for educating her son **Alarka**. Before leaving the palace she gives Alarka a ring containing written advice for a future crisis; when he faces hardship, the message helps guide him. Our apps interpret the story as **care, foresight and guidance across distance**: Madalasa is the authorized guardian app; Alarka is the visible companion on the child's Android phone. This is a **modern design metaphor**, not a scriptural claim of continuous supernatural remote tracking. Read the [English story, references and design principles](docs/phases/M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

## Documentation

- [Discussion and decisions](docs/phases/M0-foundation-and-approvals/01-project-governance/DISCUSSION.md)
- [Software Requirements Specification (SRS)](docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md)
- [Technical Specification](docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md)
- [Oracle Chicago Deployment, Capacity and Financial Plan](docs/phases/M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md) — planned architecture, deployment sequence, finances and OCI-01–OCI-12 blockers (not provisioned)
- [**Proposed Subscription Plans, Fees and Play Rules**](docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md) — **₹50/month or ₹500/year per paid child seat**, family seat products, GST/refunds/auto-renew, price sensitivity and unresolved approvals
- [Third-Party Services Cost Analysis (excluding Oracle hosting)](docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/THIRD_PARTY_SERVICES_COST_ANALYSIS_2026.md) — Maps/Places, FCM, Play Billing fees, parent auth, Drive/Roads/SMS, monthly/yearly per-child forecasts and provider blockers
- [Audit Remediation Status](docs/phases/M0-foundation-and-approvals/01-project-governance/AUDIT_REMEDIATION_STATUS.md) — documentation fixes versus open implementation/deployment proof

## Design principles

- Verify actual platform capability before offering a remote action.
- Show honest command states; never report success until execution is confirmed.
- Treat standard installation and managed-device enrollment as separate modes.
- Minimize CPU, RAM, network traffic, and battery use.
- Protect location and media data with authentication, encryption, audit records, and retention controls.
- Do not bypass Android permissions, privacy indicators, or platform safeguards.

## Proposed first milestones

1. Confirm supported Android versions and device setup modes.
2. Implement pairing, capability reporting, permission onboarding, location capture, and an encrypted local queue.
3. Deliver location history and parent map.
4. Add usage reports and tested managed-device restrictions.
5. Add capability-gated, authorized media workflows, Drive integration, subscriptions, and release hardening.

The documents are an initial design baseline, not a claim that the application is already implemented or that every feature works on every device.

## Expanded documentation (2026-10-25 review)

The following documents supplement the initial v0.1 baseline. They are architecture, validation, and Play-submission drafts—not proof of device tests or approval:

- [Feature feasibility, reasons and precise conditions](docs/phases/M0-foundation-and-approvals/02-market-and-feasibility/FEASIBILITY_CONDITIONS_AND_EVIDENCE.md)
- [Implementation technical specification and roadmap](docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/IMPLEMENTATION_TECHNICAL_SPECIFICATION.md)
- [Google Play publishing and permission requirements](docs/phases/M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md)
- [Play Data safety and Android permission worksheet](docs/phases/M9-play-release/01-play-and-data-safety/DATA_SAFETY_WORKSHEET.md)
- [Privacy policy publication draft](docs/phases/M9-play-release/02-public-legal-drafts/PRIVACY_POLICY_DRAFT.md)
- [Account and data deletion design](docs/phases/M6-guardian-erasure-security/01-data-erasure-and-access/ACCOUNT_DELETION_DESIGN.md)
- [Store listing and Play reviewer guidance](docs/phases/M9-play-release/01-play-and-data-safety/PLAY_STORE_LISTING_AND_REVIEWER_GUIDE.md)
- [Verification, testing and release roadmap](docs/phases/M8-operational-readiness/03-quality-and-evidence/VALIDATION_AND_RELEASE_PLAN.md)
- [Security architecture and operations](docs/phases/M8-operational-readiness/02-operations-and-support/SECURITY_AND_OPERATIONS.md)

**Publication warning:** There are not yet release AABs, live privacy/deletion web pages, Play Console declarations, reviewer demonstration videos, or verified Android device test results. These must be created and validated before publishing either app.

Additional implementation and release references:
- [Android 10–16 compatibility test matrix](docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md)
- [Draft machine-readable OpenAPI contract](docs/openapi.yaml)
- [Subscription and terms disclosure template](docs/phases/M9-play-release/02-public-legal-drafts/TERMS_AND_SUBSCRIPTIONS_DRAFT.md)

## Route tracking, named places and stop detection

See [Live Trip Route, Named Places and Battery Specification](docs/phases/M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md) for the implementation design: parent-titled address markers, live map, raw GPS route polylines, multi-stop trip timeline, motion-aware low-battery collection, phone/tablet/Wear OS support, conditional Google Roads matching and device verification. This is a **proposed** implementation; no hardware tests have been executed.

## Adaptive movement tracking and scalable C++ reconstruction architecture

See [Adaptive Movement and Multi-Tenant C++ Server Architecture](docs/phases/M2-location-collection/01-location-collection-and-ingestion/ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md) for a researched implementation specification: low-battery Android collection, durable batched ingestion, multi-guardian/child authorization, stateless Drogon API replicas, C++ per-device trip/stop reconstruction workers, PostgreSQL/PostGIS schema and security controls, capacity modelling, operations, tests, and phased delivery. **Engineering design only; not a measured production implementation.**

## Competitive product review (October 2026)

[Comparison of Findmykids, Find my Phone – Family Locator, Pinardin, FamiSafe and Kids360](docs/phases/M0-foundation-and-approvals/02-market-and-feasibility/COMPETITOR_FEATURE_COMPARISON_AND_ADOPTION_2026.md) documents verified advertised features, Madalasa–Alarka gaps, conditional Android feasibility and a proposed adoption backlog. **Proposals are not automatically approved product requirements or implemented features.**

## Feedback-led differentiation study (October 2026)

[Market Feedback, Competitive Gaps & Feasible Differentiation](docs/phases/M0-foundation-and-approvals/02-market-and-feasibility/MARKET_FEEDBACK_GAPS_AND_DIFFERENTIATION_2026.md) reviews the original five Play apps plus Life360, Qustodio, Bark and Family Link against sampled Play reviews, feedback aggregators, Reddit parent discussions and official Android/Play guidance. It proposes confidence-aware trips, a device reliability center, offline trip repair, time-limited guardian grants, low-noise commute alerts, privacy access receipts and policy previews. **These are research proposals, not verified competitor absences or approved SRS features.**

## Documentation quality audit (2026-10-25)

[Technical Specification and Whole-Project SRS Gap Audit](docs/phases/M0-foundation-and-approvals/01-project-governance/TECHNICAL_DOCUMENT_AUDIT_GAPS_2026.md) records **26 prioritized findings** after reviewing the current consolidated SRS, older canonical technical specification, C++ architecture, feasibility, OpenAPI, Android compatibility, privacy and Play documents. **Most urgent:** replace outdated canonical technical spec, formalize all endpoint/tenant/deletion contracts, complete FR-to-test traceability, and validate Android, battery and server failure cases. This is a documentation audit, **not** a code, hardware or Play Console certification; corrective changes have not yet been implemented.

## Canonical project specification and blocker review — 2026-10-25

**Read in this order:**

1. [Consolidated SRS v1.0](docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md) — what the product must do; 49 FR and 16 NFR.
2. [Whole-project Feasibility Gate](docs/phases/M0-foundation-and-approvals/02-market-and-feasibility/WHOLE_PROJECT_FEASIBILITY_GATE_2026.md) — where Android/security/policy permits each feature.
3. [Canonical Whole-Project Technical Specification v1.0](docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md) — authoritative system architecture, algorithms, API/data responsibilities, security, delivery.
4. [Decisions & Blockers for the Project Owner](docs/phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) — **22 owner questions**, 14 engineering blockers and 8 external release gates.
5. [Requirements Traceability](docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/REQUIREMENTS_TRACEABILITY.md) — every FR-001–049 and NFR-001–016 mapped to planned test IDs.
6. [Audit Remediation Status](docs/phases/M0-foundation-and-approvals/01-project-governance/AUDIT_REMEDIATION_STATUS.md) — documentation fixes and real implementation/evidence still missing.

**Implementation annexes:** [Data/Authorization/Event Recovery](docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md), [Android Runtime/Tracking Algorithms](docs/phases/M2-location-collection/01-location-collection-and-ingestion/TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md), [Commands/SOS/Usage/Queue](docs/phases/M4-usage-health-sos/01-usage-health-and-sos/COMMAND_SOS_USAGE_QUEUE_CONTRACT.md), and [expanded OpenAPI 3.1 draft](docs/openapi.yaml).

These are **engineering design documents**, not executed code, verified device compatibility, legally approved privacy terms or Google Play publication approval. Older documentation reflects the historical exploration; use the above canonical sources for new implementation decisions.

## First implementation milestone — Android + C++ (2026-10-25)

The project owner selected **native parent Android**, **managed-device provisioning support**, and **mixed Android OS versions**. The new [M1 Architecture and Implementation Contract](docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/M1_ANDROID_CPP_ARCHITECTURE_AND_IMPLEMENTATION.md) defines Kotlin/Compose parent and child platform services, portable C++20 NDK library, C++20 Drogon API, PostgreSQL identity/grant schema, test DPC owner provisioning and safe eligible app suspension/restore. It specifies the 10 M1 work packages, 14 test scenarios, and next milestones. It does **not** claim Android apps, backend code or DPC tests have already been implemented. [Updated owner blockers](docs/phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) record what is decided versus still open.

## Oracle Chicago hosting and per-child finances (2026-10-25)

> **Historical.** The owner has since preferred Indian-region hosting (Mumbai, Hyderabad fallback; see the current
> hosting plan below and [Blocker register §J](docs/phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md)). Chicago figures remain only as a cost
> comparison. Nothing is provisioned in any region.

**Hosting decision (plan, not provisioned):** Oracle OCI home region **US Midwest Chicago, us-chicago-1**, first attempting Always Free Ampere A1 **2 OCPU / 12 GB** with C++20 Drogon API, C++ reconstruction worker, and PostgreSQL/PostGIS on the **same ARM64 VM**. [OCI Chicago Deployment and Financial Plan](docs/phases/M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md) documents provider sources, account/AD availability blockers, free vs paid A1 allowances, estimated monthly compute/storage/contingencies, one-subscription-per-child finances and upgrade triggers. PAYG 4/24 may remain inside the **paid-account** published A1 free-hour allowance if independently confirmed. This is a forecast, **not a billed deployment or observed capacity benchmark**.

**New cumulative hosting numbers:** [OCI paid usage: monthly, annual and planning-budget tables](docs/phases/M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md#14-cumulative-recurring-hosting-cost-beyond-free-tier--monthly-annual-and-scaling-sensitivity). Separates priced OCI usage from discretionary reserve, models 500–50,000 illustrative children without asserting VM capacity, and lists cloud-account/cost verification blockers.

## India legal, SOS, DR and current-price release gates (2026-10-26)

**No real child data pilot is authorized by documentation alone.** The India DPDP Act 2023 / Rules 2025 require a feature-by-feature legal analysis of **under-18 guardian authority**, limited real-time child-safety location exception, historical routes, **app usage/behavioural monitoring**, and US Chicago hosting. Release remains blocked until an India lawyer and actual publisher sign off. See [India DPDP Legal Gate](docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md).

**M1/M2/production blockers and actionable owner questions:** [Blocker register §I](docs/phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md): publisher name, ages/India launch, retention, owner/guardian access, login (Google Sign-In engineering candidate), Android test devices including a safe-to-reset DPC phone, staffing/cash budget and support. [Recovery and RPO/RTO plan](docs/phases/M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_RECOVERY_AND_PILOT_READINESS.md) acknowledges the single-VM failure risk, while [SOS FCM/SMS independent fallback design](docs/phases/M4-usage-health-sos/01-usage-health-and-sos/SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md) prohibits guaranteed emergency claims without tested guardian ACK and an out-of-band path.

**Current prices:** ₹50/month or ₹500/year per child are **proposed, not verified as profitable**. [Break-even, staffing and hardware](docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md) compares tax assumptions, Play fees, existing OCI reserves, additional staff/support and HA costs. Old ₹149/month cost/revenue tables remain **historical price sensitivities only**. Parent privacy/consent controls remain required even after payment.

## India-first OCI region and executable M1 validation artifacts — 2026-10-26

**Current primary hosting plan:** OCI **Mumbai (ap-mumbai-1)**, **Hyderabad (ap-hyderabad-1)** fallback, conditional on tenancy home region, actual capacity/cost and Indian child-data counsel review. Original Chicago financial report is now **historical**, not the preferred new infrastructure. See [India region and M0 decision gate](docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_REGION_AND_M0_OWNER_DECISION_GATE.md).

**One authoritative roadmap:** [Master M0–M9 milestones](docs/phases/M0-foundation-and-approvals/01-project-governance/MASTER_MILESTONE_IMPLEMENTATION_AND_RELEASE_PLAN.md). **M1 artifacts:** [11-operation OpenAPI](docs/openapi-m1.yaml), [offline structural linter](backend/tests/lint_openapi_m1.py), [PostgreSQL M1 schema/RLS](backend/persistence/migrations/0001_m1_identity.sql), [two-family SQL negative test](backend/tests/m1_tenant_isolation.sql), [14 executable case definitions](backend/tests/M1_ACCEPTANCE_TEST_CASES.md) and [PostgreSQL CI workflow](.github/workflows/m1-contract-and-tenant.yml). **API structural lint checked; database execution and real Android/API tests pending**. Real minor data blocked until counsel, owner decisions and device/recovery evidence.

## Eraser.io high- and low-level design diagrams (2026-10-26)

[**Eight editable HLD and LLD architecture diagrams**](docs/phases/cross-milestone-references/01-architecture-and-visual-indexes/ERASER_HLD_LLD_DIAGRAM_INDEX.md) are available in the connected [Eraser Madalasa–Alarka workspace](https://app.eraser.io/workspace/dP8nMbuaxaFXBkBzUHCv): context/trust boundaries, OCI Mumbai deployment, M1 pairing proof, M1 PostgreSQL ERD, GPS ingestion, guardian revocation, SOS escalation and family billing. These are planned designs; legal, device, database CI and deployment gates remain open.

## Editable Android UI boards — tldraw

[**225 editable Light / Dark / Battery Saver screen variants**](docs/ui/tldraw/README.md) for 54 parent and 21 child screens are stored in the [live tldraw board](https://www.tldraw.com/f/-IuhoGjlF7uXC5imxkaL3) with [native snapshot backup](docs/ui/tldraw/amar-pola-ui-master-snapshot.json) checked into GitHub. Covers Google Sign-In, guided child installation and permissions, location and map evidence, guardians, alerts, safety check-ins, privacy, DPC and subscription management. Visual prototypes; application implementation remains pending.

## Current Android functional UI handoff — Figma (81 screens)

The authoritative developer UI handoff is now [**81 editable Figma functional screens**](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=6-2), with **60 parent** and **21 child** views in **one** visual style. Each phone screen has a detailed implementation panel directly underneath (actions, planned APIs/state, OS/legal/access gates, failure cases, acceptance checks). The [screen inventory and version-controlled implementation specifications](docs/ui/figma-functional-handoff/README.md) are in `docs/ui/figma-functional-handoff/`. Earlier light/dark/eco sketches and the tldraw boards are historic exploration; the developer implements theming from shared design tokens rather than duplicated drawings. Structure/count verified in Figma, screenshot-based visual QA blocked by Starter MCP limit; no runnable Compose app yet.

## Indian legal, government and Google Play project risk assessment — 2026-10-26

**[Read the MA-COMPLIANCE-001 project assessment](docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md)** — 26 risk items, exact official DPDP/CERT-In/Google Play/Android sources, feature include/restrict/avoid recommendations and release-blocking evidence gates. **Critical:** Alarka's precise child-location collection versus Google Play Families policy must be settled with Play before real-GPS development/launch; India DPDP safety-location exception does not automatically authorize history, usage or media. **NO-GO for real-minor data until legal and Play decisions; synthetic M1 work permitted.**

## Media research decision — 2026-10-26

Owner accepted **conditional engineering research** of one-way audio, recording, remote camera/video/snapshots, flash-off where supported, per-session-consented screen sharing and scoped file/media access. Alarka's **main Activity stays closed after setup in routine use**, but its required monitoring notification and Android privacy indicators remain visible. Madalasa shall tell an authorized parent the **actual verified reason and safe next action** whenever a request cannot run (permission, OS background restriction, managed-only configuration, child consent, device offline, sensor/network). No commercial media release is authorized; all child-data, Play and device-test gates remain. See [Media & Parent Reason Decision](docs/phases/P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md).

## Media-specific Figma UI and system architecture update — 2026-10-26

Eight additional editable parent/child conditional-media R&D screens, [native Figma media HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=21-3) and [native Figma media LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=21-41) have been added to the existing design file. They follow [MA-MEDIA-ADR-001](docs/phases/P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md): live audio/camera, scoped file access, OS-permitted start contexts, MediaProjection per-session consent, reason-specific errors, WebRTC direct/TURN relay fallback and no VPS media archive. **These do not represent implemented or Play-approved functions.** The existing Eraser diagrams were not changed owing to its exhausted AI credits; Figma now hosts the media HLD/LLD. See [Figma handoff index](docs/ui/figma-functional-handoff/README.md).

## Automatic Alarka device discovery and permission-status synchronization — 2026-10-27

**Owner-accepted, not implemented:** At first launch, Alarka performs a read-only hardware/OS capability scan, pairs with the approved family/device identity, then uploads a versioned authenticated compatibility report to the C++ API. Its stepwise, disclosed Android permission wizard verifies the **actual OS grant** after each prompt/Settings screen, sends a newer device report, waits for server ACK and allows Madalasa to retrieve the **child-scoped verified feature list**. Revocation and regrant cause a fresh report when Android next allows execution; no instant/offline delivery is guaranteed. Madalasa distinguishes hardware supported, permission granted, actual execution context, legal/release eligibility, and last-confirmed freshness before showing green/amber/red/grey.

**[Full device-capability & permission-sync ADR](docs/phases/M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md)** · [46 additional editable Figma setup and parent status screens](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-2) · [Capability HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=27-2) · [Permission lifecycle LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=27-40). The original 81 functional handoff screens remain distinct; no production or Play approval is implied.

## 2026-10-27 Media activity logs and new administrator console — design only

The product owner accepted FR-050/051 design: **no user media file storage on VPS**, but minimal metadata for verified audio/image/AV-video/screen media requests and sessions (actor/child IDs, real duration, nullable file-size, viewed-only vs historically saved on Madalasa, evidence-grounded camera/audio/OS failure reasons). Parent Madalasa can filter its authorized children by child **name+ID**, date range, media/result/failure and cursor pagination. A **new separately authenticated administrator browser console** offers case-authorized parent/child name+ID autocomplete, date range and pagination, plus an independent read-access audit. **Administrators do not automatically get blanket child log access, nor playback or download of media.**

- [Media metadata audit ADR](docs/phases/P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md)
- [New Admin Panel specification](docs/phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md)
- [Whole-project OpenAPI design](docs/openapi.yaml) — 8 additional design-only parent/admin endpoints and separate AdminBearer; M1-only API unchanged.
- [28 editable Figma media-audit screens](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-2) — 11 Madalasa mobile and 17 admin desktop frames, each with developer note.
- [Media audit system HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=35-2) and [media audit event/query LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=35-56).
- [Exact screen/node/behavior inventory](docs/ui/figma-functional-handoff/07-media-activity-audit.json).

**All are planned / NOT_IMPLEMENTED / NOT_TESTED; P3 media capture and real-minor media remain Play/India legal/release gated.** Historical Alarka media files are never accessible through the admin panel because VPS stores none.

## Accepted GPS and app-usage ingestion architecture — 2026-10-27

**New owner-accepted engineering design (NOT IMPLEMENTED):** Alarka separately collects adaptive GPS fixes and stores an **encrypted local up-to-48-hour offline capacity buffer**, then attempts bounded JSON batch uploads every **1–2 minutes when Android execution permits**. Existing PostgreSQL + PostGIS remains the authoritative database; **no Redis server is required initially**. The C++ Drogon API validates an authenticated upload, commits **one durable PostgreSQL inbox row per batch**, and returns HTTP 202 QUEUED **only after COMMIT**. Independent C++ workers claim inbox batches via `FOR UPDATE SKIP LOCKED` leases, combine valid GPS observations and **bulk insert** them into time-partitioned PostGIS with stable event dedup and a trip reconstruction outbox; separate workers build trips, routes and app-usage aggregates. Device ACK is not raw/trip completion. Redis remains optional later if benchmarks warrant it.

The **direct bulk-insert approach without an inbox** is explicitly retained as a benchmark alternative, since inbox storage adds WAL/write amplification despite isolating server bursts. A 1–2 minute upload is not guaranteed by Android background restrictions or periodic WorkManager; 48h is local capacity target rather than continuous background capture guarantee. The previous 300 GPS fixes/day was a financial example, not a limit on moving children's route observations. Protected children’s location and usage remain India DPDP/Play release-gated.

**[Canonical Postgres Inbox + Bulk GPS ADR](docs/phases/M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md)** · [Updated editable Figma GPS Ingest HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-2) · [LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-60) · [Inbox vs Direct Bulk trade-off](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-126). All T-ING-01–24 tests are pending.

## Governance and engineering document verification — 2026-10-27

Six owner-supplied files have been verified against the existing Madalasa–Alarka architecture and M1 CI rather than overwritten blindly. See [governance upload review and file crosswalk](docs/phases/M0-foundation-and-approvals/01-project-governance/UPLOADED_GOVERNANCE_DOCUMENTS_REVIEW_2026-10-27.md), [Build & Run](docs/phases/M1-secure-platform-foundation/02-development-process/BUILD_AND_RUN.md), [Retention Schedule](docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md), [DPIA](docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md), [Incident Response](docs/phases/M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md), [Security guidance](docs/phases/M1-secure-platform-foundation/03-security-and-permissions/SECURITY.md) and [license draft review](docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/LICENSE). The root [SECURITY.md](SECURITY.md) and interim [LICENSE](LICENSE) are still authoritative; security intake, retention, license and child-data/Google Play GO decisions remain **unapproved**. The uploaded \`INCIDENT_AND_BREACH_RESPONSE_PROCEDURE-1.md\` is merged under its established canonical filename without creating a duplicate.

## 2026-10-27 verified gap register and Android build boundary

[**Repository-wide checklist versus actual GitHub files**](docs/phases/M0-foundation-and-approvals/01-project-governance/REPOSITORY_GAP_AND_DELIVERY_AUDIT_2026-10-27.md) identifies which requested root/engineering/operations/legal artifacts are already committed versus **not implemented, unsigned or not published**. The non-runnable Android source folders have a separate [Android source-to-build acceptance plan](docs/phases/M1-secure-platform-foundation/02-development-process/ANDROID_M1_SOURCE_BOOTSTRAP_AND_BUILD_GATE_2026-10-27.md); no Gradle wrapper/manifest/APK is yet present. A [governance issue template](.github/ISSUE_TEMPLATE/governance_gap.yml) has been added for safe process/approval tracking. GitHub About metadata and protected-branch rules still require **repository admin**; this connection has file push but not admin/maintain permission. A committed policy is not evidence of a functioning confidential vulnerability reporting channel or signed India/Play clearance.

## Autonomous local development roadmap (2026-10-28)

A [20-phase, 262-task local coding-agent roadmap](docs/roadmap/LOCAL_AGENT_DEVELOPMENT_ROADMAP_2026-10-28.md), [machine-readable dependency task graph](docs/roadmap/LOCAL_TASK_GRAPH_2026-10-28.json), [agent instructions](AGENTS.md), [test-evidence protocol](docs/roadmap/AGENT_EXECUTION_AND_TEST_EVIDENCE.md) and [source/conflict index](docs/roadmap/SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md) have been added. **All tasks begin NOT_STARTED**, not implemented. [Cloud deployment and Google Play readiness are in a separate plan](docs/roadmap/DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md). Synthetic-only engineering may continue while owner/legal/Play gates remain blocked.

## Final Figma/API/database audit — 2026-10-28

[187-screen API and DB traceability report](docs/audits/FINAL_FIGMA_SCREEN_BY_SCREEN_API_DB_REPORT_2026-10-28.md) · [Editable Figma screen audit](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=121-88) · [146-operation draft OpenAPI](docs/openapi.yaml) · [120 proposed logical tables / 11 Figma ERDs](docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json) · [physical SQL and co-parent authorization blockers](docs/data-model/FIGMA_SCREEN_GAP_PHYSICAL_SCHEMA_REVIEW_2026-10-28.md) · [28 additional agent tasks](docs/roadmap/FIGMA_SCREEN_API_DB_REMEDIATION_TASKS_2026-10-28.json). [Contract-only and M1 SQL CI passed](https://github.com/methakon/Madalasa-Alarka/actions/runs/40661843914), **but neither Android apps, a live C++ API nor the new database tables are implemented**. Theme C remains a collection of approved concept samples and developer handoffs, not final fully tested screens.
