# Madalasa–Alarka — Decision & Source Supersession Ledger

> **Document control:** roadmap / task-governance · **Proposed owner:** Project owner (not yet assigned) · **Registry:** DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master Document Control Register](../MASTER_DOCUMENT_CONTROL_REGISTER.md) · [Control Policy](../DOCUMENT_CONTROL_POLICY.md).

**Task:** `L00-001` — Freeze source/decision supersession index.
**Established:** 2026-11-01 · **Version:** 1.0 · **State:** DOCUMENTED_REVIEW_PENDING · **Scope:** LOCAL synthetic development governance only.

## Purpose

This ledger is the single authoritative index that links every known project conflict or ambiguity to the **latest approved owner decision** (or records it as still-open), and marks superseded / stale specification passages so a coding agent never acts on an obsolete instruction. It satisfies the `L00-001` acceptance criterion: *"Every conflict linked to latest approved owner decision; stale specs marked."*

**This ledger records state; it does not create approval.** Selecting a product option, or linking a conflict to a decision here, is not legal, Google Play, Android-OS, or security verification. External hard gates (India DPDP child-data lawfulness, Google Play eligibility, physical-device evidence) override any owner business preference and remain separately tracked in the [Blockers & Owner Decisions register](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md).

## How to use this ledger

1. Before any task, re-read the exact referenced source document (it may have changed since this snapshot).
2. Resolve every conflict using the **Latest approved decision** column below; where it reads `OPEN` / `DEFERRED` / `EXTERNAL`, treat the feature as fail-closed and do not invent an answer.
3. If two live sources still disagree without a dated owner/legal decision, raise an ADR in the blockers ledger and STOP that feature while continuing unrelated synthetic-only work.

## Authority / supersession order (highest first)

1. **Owner's latest dated explicit decision** — overrides contradictory historical price/trial/feature passages *as business intent only*.
2. **Legal / Google Play / Android-OS external hard gates** — owner preference alone cannot enable data collection, parental-relationship verification, or background media capture.
3. Canonical SRS + technical architecture + security/consent specs + latest owner-decision addenda + M1 OpenAPI + later domain specs.
4. Physical SQL migrations and executable contract tests govern **implemented behavior**; Figma/Eraser assets are design, not implementation or security proof.
5. A truncated root-level pointer never overrides its canonical `docs/phases/...` document; always follow the canonical path.

## A. Conflict register → latest approved decision

Source conflicts are catalogued in the [Source & Conflict Register](SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md). Each is linked below to its current disposition.

| ID | Conflict / ambiguity | Latest approved decision (date) | Disposition | Authority |
|---|---|---|---|---|
| C-01 | OCI Chicago host-cost plans vs India-first Mumbai preference | **DEFERRED_TO_DEPLOYMENT** (2026-10-28) — not a local code blocker; write environment-agnostic, locally benchmarked code | RESOLVED for local scope; region reserved for deployment | [Conflict register §2026-10-28](SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md) · [Deployment plan](DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md) |
| C-02 | Retention raw GPS 14d/30d vs retain-until-account-close | **OPEN** (B-07) — 6-hour *visibility* window is a query-access limit, not a storage lifetime; retention per category disabled/configurable until decided | OPEN — do not conflate visibility with retention | [B-07](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) · [Data Retention Schedule](../phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md) |
| C-03 | Google Family Link second-parent support vs no verified public attestation API | **RESOLVED (2026-10-28)** — do NOT depend on Family Link parent-role verification; Google Sign-In authenticates identity only; child-specific sharing fails closed until a lawful verifier exists | RESOLVED (dependency removed); lawful authority still a separate review | [ADR 2026-10-28](../phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md) |
| C-04 | Historical auto-recurring / ₹149 / old prices vs prepaid manual ₹99/₹999, founding ₹50/₹500 | **OWNER_APPROVED (B-14)** — prepaid, no auto-renew; first 1,008 distinct paid families founding ₹50/mo or ₹500/yr; actual Play catalog price overrides marketing mock | Business intent DECIDED; provider/tax/merchant verification OPEN | [B-14](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) · [Subscription plans](../phases/M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md) |
| C-05 | 30-day shorter-of-base extra viewer vs ₹100 for 100 calendar days | **OWNER_CONFIRMED** — add-on validity independent of base lapse; dormant during base lapse; fixed 100-day expiry; +30 total combined A/V minutes | Business intent DECIDED; Play one-time product + load/cost tests OPEN | [C-05 register](SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md) · [Child-specific sharing & addons](../phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md) |
| C-06 | "One screen" = whole family vs per paid child | **WORKING INTERPRETATION: per paid child** across all approved parents; public customer copy needs owner confirmation | PARTIAL — implement per-child; confirm copy before launch | [C-06 register](SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md) |
| C-07 | Remote background audio/camera/screen capture vs Android/Play monitoring restrictions | **CONDITIONAL / OFF (B-16)** — explicit DISABLED flag, honest OS failures, visible lab research only; no remote/background capture | OPEN/OFF — fail closed | [B-16](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) · [Media capability research](../phases/P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md) |
| C-08 | Managed Device Owner vs ordinary child-phone permissions | **OWNER_DECIDED (B-05, 2026-10-30)** — standard installation first; Device Owner provisioning deferred; read-only managed-state detection allowed, no silent elevation | RESOLVED for first release; managed edition needs new owner decision | [B-05](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) · [Device Owner scope decision](../phases/M1-secure-platform-foundation/03-security-and-permissions/DEVICE_OWNER_PROVISIONING_SCOPE_DECISION_2026-10-30.md) |
| C-09 | Figma 112/120 conceptual tables vs real M1 physical SQL | **RESOLVED (process)** — implement only justified physical tables per feature; 18-table M1 catalog preserved; conceptual count is not a table-generation target | RESOLVED — slice migrations by feature | [Schema slicing policy](../data-model/PHYSICAL_SCHEMA_DEEP_AUDIT_AND_REMEDIATION_2026-10-29.md) · [Figma logical ERD](../data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json) |
| C-10 | Whole-project `openapi.yaml` (171 proposed ops) vs narrow `openapi-m1.yaml` | **RESOLVED (process)** — implement M1 contract first, then domain extensions; proposed operations are not working handlers | RESOLVED — M1-first, per-endpoint tests | [openapi-m1.yaml](../openapi-m1.yaml) · [openapi.yaml](../openapi.yaml) |
| C-11 | Admin owner "all admin access" vs child privacy | **RESOLVED (principle)** — ROOT_OWNER manages staff/content/billing/support but cannot query child-private raw GPS/history/media | RESOLVED — least privilege; audit-scope tests required | [Admin owner access spec](../phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md) |
| C-12 | Active Personal Play account ≠ verified production/closed-test access | **RECORDED (X-01)** — 2026-10-31: publisher identity COMPLETED (owner-confirmed); BillDesk/payment submitted, response pending; merchant activation NOT confirmed; no account ID/token in Git | PARTIAL — X-01A closed, X-01B/C open | [X-01](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| C-13 | 48h once-trial fraud resistance vs deletion / minimization | **OPEN** — synthetic risk model only; privacy-respecting anti-repeat; no invasive device fingerprint; owner-approved method required | OPEN | [C-13 register](SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md) · [DPIA](../phases/M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md) |
| C-14 | Older five-hour vs six-hour free history | **RESOLVED** — adopt **six-hour** parent visibility as product decision; align API/UX; retention approved separately | RESOLVED (business); retention separate | [C-14 register](SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md) |
| C-15 | Root short pointer docs vs canonical phase docs with stale appendices | **RESOLVED (policy)** — always use canonical `docs/phases/...` path and most recent dated owner addenda; root pointers consolidated under `legacy-root-links/` | RESOLVED — follow canonical path | [Legacy root links](../legacy-root-links/README.md) |

## B. Owner business decisions (latest state)

| ID | Decision | State (date) | Authority |
|---|---|---|---|
| B-01 | Publisher: SWARNA SEKHAR DHAR, individual, India; same legal + Play publisher | DECIDED; Play identity COMPLETED (2026-10-31) | [B-01](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| B-02 | India-only initial launch; children 0–17 inclusive | OWNER_DECIDED; legal/Play classification OPEN | [B-02](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| B-03 | Transparent background operation; identifiable icon; no stealth/permission bypass | OWNER_APPROVED; Android/Play/India evidence OPEN | [B-03](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| B-04 | Evaluate full prior feature inventory as first-release candidates | OWNER_DECIDED; per-feature gates still apply | [B-04](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| B-05 | Standard install first; Device Owner deferred | OWNER_DECIDED (2026-10-30) | [B-05](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| B-06 | Child SOS / optional visible foreground capture / parent alarm | DESIGN REQUESTED; legal/Play/Android OPEN | [B-06](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| B-07 | Retention per category (GPS/trips/usage/audit/backups) | OPEN | [B-07](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| B-08 | Hosting provider / region | DEFERRED_TO_DEPLOYMENT | [B-08](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| B-09 / B-18 | Guardian add/revoke authority, scope, TTL; history vs current-only | OPEN | [B-09/B-18](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| B-14 | Founding pricing (first 1,008 families ₹50/mo or ₹500/yr) | OWNER_APPROVED; provider behavior UNVERIFIED | [B-14](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| B-16 | Camera/video/mic in launch | CONDITIONAL / OFF | [B-16](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |

Remaining B-items (B-10/B-11 devices, B-12 battery, B-13 stop semantics, B-15 Drive backup, B-17 alerts, B-19 web client, B-20 route transparency, B-21 sizing, B-22 localization/support) remain as recorded in the blockers register; none is approved by this ledger.

## C. External hard gates (cannot be resolved by owner preference)

| ID | Gate | State (2026-10-31) | Authority |
|---|---|---|---|
| X-01 | Publisher identity / payment | X-01A CLOSED (identity); X-01B payment response pending; X-01C merchant activation OPEN | [X-01](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| X-02 | Google Play Families location (G01) + background location (G04) | G01 OPEN (support case pending); G04 NOT SUBMITTED | [X-02 policy review](../phases/M9-play-release/01-play-and-data-safety/X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md) |
| X-03 | India DPDP child-data lawfulness (feature-by-feature) | DUE DILIGENCE IN PROGRESS; paid signed opinion NOT a blanket prerequisite; Tele-Law + MeitY responses pending | [India DPDP gate](../phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md) |
| X-04…X-08 | Public legal URLs, Maps terms, subprocessors, Play testing, physical devices | OPEN / EXTERNAL | [Blockers register §C](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |

## D. Engineering blockers (resolved only by building and testing)

E-01…E-14 remain governed by the [Blockers & Owner Decisions register §B](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md). Current highlights (2026-11-01): E-02 (14/14 M1 routes registered on `api`; V2 parent session bridge merged to `main`; full role integration PARTIAL); E-05 (Android scaffolding merged; device runtime pending); E-09 (parent OIDC→V2 bridge merged; device key rotation pending). E-01/E-03/E-04 (RLS, GPS idempotence, deletion/backup) remain critical-open. No E-item is PASS until tested with evidence.

## E. Stale / superseded specification passages (do not act on)

| Superseded passage | Superseded by | Effective date |
|---|---|---|
| Any requirement for Google Family Link parent-role verification | [ADR 2026-10-28 — no Family Link dependency](../phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md) | 2026-10-28 |
| Auto-recurring subscriptions / ₹149 / older price points | Prepaid manual ₹99/₹999 + founding ₹50/₹500 (B-14) | 2026-10-28 |
| "Signed paid Indian advocate opinion / government permit is a compulsory launch prerequisite" | X-03 correction — feature-specific documented due diligence; paid opinion optional | 2026-10-31 |
| Five-hour free history notes | Six-hour parent visibility (C-14) | superseded |
| 30-day / shorter-of-base add-on validity | ₹100 / fixed 100-calendar-day independent add-on (C-05) | superseded |
| Feature-branch-per-task Git guidance | Five permanent branches (`api`/`parent`/`child`/`admin-web`/`dev`) → `dev` → `main`; docs on `main` only | 2026-10-31 |
| Pending-identity X-01 wording ("identity verification blocking") | X-01A CLOSED — Play publisher identity completed | 2026-10-31 |
| OCI Chicago region as a local-coding prerequisite | Region DEFERRED_TO_DEPLOYMENT; environment-agnostic code (C-01) | 2026-10-28 |
| React admin frontend prototype as the chosen stack | Drogon server-rendered HTML + HTMX + Alpine.js (CSP) | 2026-11-01 |

## Related governance sources

- [Source & Conflict Register](SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md)
- [Blockers & Owner Decisions](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md)
- [Local Agent Development Roadmap](LOCAL_AGENT_DEVELOPMENT_ROADMAP_2026-10-28.md)
- [Agent Execution & Test Evidence Contract](AGENT_EXECUTION_AND_TEST_EVIDENCE.md)
- [Task Execution Status Ledger](LOCAL_TASK_EXECUTION_STATUS.json)
- [Separate Deployment & Play Release Plan](DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md)
