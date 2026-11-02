# Madalasa–Alarka — Audit Gap Remediation Progress

> **Document control:** M0 / 01-project-governance · Proposed owner: Project owner (not assigned) · Registry: TEMPLATE_OR_EVIDENCE_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product naming:** **Madalasa** parent/guardian app, **Alarka** child companion; GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka). [Brand and Markandeya Purana context](../02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Date:** 2026-10-25 | **Scope:** Documentation remediation only | **Original audit:** [26 findings](TECHNICAL_DOCUMENT_AUDIT_GAPS_2026.md)

**Do not interpret DESIGN_UPDATED as IMPLEMENTED.** The ledger separates completed documentation work from actual code, hardware testing, cloud deployment, legal review and Google Play approval.

## 1. Status definitions

- **DESIGN_UPDATED:** an implementation-level specification or decision contract is now written; software/test proof remains open.
- **PROVISIONAL_DESIGN:** methods specified but calibration/parameter selection awaits tests.
- **PARTIAL_DESIGN:** some decisions or artifacts remain missing.
- **OWNER_OPEN:** product/legal decision required.
- **EXTERNAL_OPEN:** third-party approval, hosting identity or real release proof missing.

## 2. Findings and current closure evidence

| Audit ID | Original gap | Documentation status | Added design evidence | What is STILL needed to close implementation/release |
|---|---|---|---|---|
| AG-001 | Canonical TSD vs SRS version | DESIGN_UPDATED | Canonical TSD v1.0 replacing v0.1 | Review/signoff still required |
| AG-002 | Partial OpenAPI | DESIGN_EXPANDED | 41-operation OpenAPI 3.1 draft | Formal OpenAPI lint, generated code and contract tests remain |
| AG-003 | Per-child guardian ACL | DESIGN_UPDATED | Data authorization annex + matrix | Implement/RLS/cross-tenant tests |
| AG-004 | Deletion, backups, reingest | PARTIAL_DESIGN | Deletion ordering/tombstones in data annex | Retention decisions, code and backup restore exercise |
| AG-005 | Public privacy/deletion/Play | EXTERNAL_OPEN | Release docs and blocker register | Legal entity, URLs and actual Play approval |
| AG-006 | FR-to-test traceability | DESIGN_UPDATED | 49 FR and 16 NFR matrix | Test cases and CI evidence absent |
| AG-007 | Geo quality/stop parameters | PROVISIONAL_DESIGN | Tracking algorithm/quality contract | Labeled device trials and threshold signoff |
| AG-008 | Durable worker crash/replay | DESIGN_UPDATED | Ingest transaction+epoch fencing contract | Executable SQL and crash tests absent |
| AG-009 | Android lifecycle matrix | DESIGN_UPDATED | Android API/case table in runtime annex | Real OEM test proof absent |
| AG-010 | Battery metrics and target | PARTIAL_DESIGN | Candidate power profiles+coverage formula | Device bench and numeric acceptance targets absent |
| AG-011 | Scale/cost/RPO | PARTIAL_DESIGN | C++ server capacity model already exists | Synthetic load, RPO/RTO and provider budgets absent |
| AG-012 | Normalized DB schema | PARTIAL_DESIGN | Composite FK/RLS/migration fragments | Runnable versioned migrations not created |
| AG-013 | Command/SOS states | DESIGN_UPDATED | Command state and SOS/queue annex | Backend/device implementations and tests absent |
| AG-014 | High risk features | DESIGN_UPDATED | Feature gates standard vs managed vs media research | DPC/media actual platform, policy signoff remain |
| AG-015 | Play build manifests/AAB | EXTERNAL_OPEN | Play checklist and canonical TSD | Build/sign/16KB/test tracks actual evidence absent |
| AG-016 | Guardian age/territory law | OWNER_OPEN | Blockers B-01/B-02/B-03 | Business/legal decisions needed |
| AG-017 | Encrypted offline queue | PROVISIONAL_DESIGN | Queue size, key and retry contract | Actual crypto choices/device fault tests remain |
| AG-018 | Map UI uncertainty/conflicts | PARTIAL_DESIGN | Map status vocabulary and optimistic versioning | Final UX screens/instrumentation tests absent |
| AG-019 | Device reinstall/transfer | PARTIAL_DESIGN | Keystore credential transfer/re-enrollment guidance | Full device state machine and OS tests absent |
| AG-020 | Usage timezone/long term | DESIGN_UPDATED | UTC interval split and completeness in usage annex | Usage Access real-device sampling tests |
| AG-021 | Provider quota/licensing | EXTERNAL_OPEN | Roads off by default; API cost controls | Google license, provider pricing and finance approval |
| AG-022 | SRE on-call and restore | PARTIAL_DESIGN | Existing security/operations and 2026 architecture | Named ops owners, drills and RPO/RTO measurements |
| AG-023 | Backlog/owner/dependencies | PARTIAL_DESIGN | Phased canonical TSD+effort report+blocker owners | Real capacity plan, GitHub issues and schedule decisions |
| AG-024 | Wear/tablet certification | PARTIAL_DESIGN | Runtime matrix and source provenance design | Hardware and actual tests |
| AG-025 | Documentation precedence | DESIGN_UPDATED | Canonical v1.0 TSD and owner index | Review all annex references when changed |
| AG-026 | Generated client/error schemas | PARTIAL_DESIGN | Expanded OpenAPI/error codes annex | Formal validator and generated Kotlin/C++ DTOs absent |

## 3. Newly added/updated authoritative documents

| Document | What gap it addresses |
|---|---|
| [Canonical Technical Specification v1.0](../../M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md) | AG-001, AG-025 and architecture/code ownership |
| [Data, Authorization and Recovery](../../M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md) | AG-003/004/008/012, versioned event writes, RLS, deletion and fencing |
| [Android Runtime and Tracking Algorithms](../../M2-location-collection/01-location-collection-and-ingestion/TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md) | AG-007/009/010/018/024 |
| [Commands, SOS, Usage and Queue](../../M4-usage-health-sos/01-usage-health-and-sos/COMMAND_SOS_USAGE_QUEUE_CONTRACT.md) | AG-013/017/020 and remote command correctness |
| [Expanded OpenAPI 3.1](../../../openapi.yaml) | AG-002/026; 41 operations; **formal validation pending** |
| [Full Requirements Traceability](../../M1-secure-platform-foundation/01-requirements-and-architecture/REQUIREMENTS_TRACEABILITY.md) | AG-006, 49 FR + 16 NFR mapped to planned tests |
| [Project Owner/Engineering Blockers](BLOCKERS_AND_OWNER_DECISIONS.md) | AG-004/005/015/016/021/022/023 and evidence ownership |
| [Feasibility](../02-market-and-feasibility/WHOLE_PROJECT_FEASIBILITY_GATE_2026.md) | Android/Play/DPC/media conditional gates |

## 4. Implementation and release closures cannot be claimed yet

- No runnable PostgreSQL migrations, Drogon/Kotlin code or device key implementation is evidenced.
- No formal external OpenAPI validator result; JSON is syntactically parseable and is also valid YAML 1.2 representation, but generators, lint and cross-platform DTO checks remain.
- No Android devices were tested for FGS, battery, app usage, optional watch or managed DPC.
- No C++ server load tests, backups/RPO, retention deletes or attack test evidence.
- No actual publisher/business identity, country-specific child privacy review, live privacy/deletion URL, Play Console approval, signed AAB or real screenshots.
- Therefore no AG item is marked **production resolved**. DESIGN_UPDATED statuses mean the *documentation gaps* have substantially narrower, implementable next steps.

## 5. Highest-priority owner decisions

See [Blockers B-01 through B-22](BLOCKERS_AND_OWNER_DECISIONS.md); most important: legal publisher, launch territories/ages, transparent monitoring confirmation, standard vs managed product, retention, hosting region, target devices/watch, battery vs precision priority, subscriptions and deferral of remote media.

## 6. Recommended implementation gate order

1. Owner approves critical scope, legal/privacy, retention and device-management decisions.
2. Backend engineer creates migrations and full auth/tenant contract tests.
3. Android engineer makes compliant background-location prototype with encrypted queue and tests.
4. C++ engineer implements durable ingest/worker fencing and synthetic GPS replay.
5. QA measures route/stop accuracy, battery, offline recovery and multi-family authorization.
6. Product publishes working privacy/deletion services and submits actual Play binary/declarations for review.

This ledger should be updated when code commits, test results or third-party approvals exist. Do not close a production blocker with a document link alone.

## 7. OCI Chicago deployment documentation coverage and outstanding proof

**Reviewed:** [OCI Chicago Deployment, Capacity & Financial Plan](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md), document OCI-CHI-001. This plan predates the latest audit follow-up and **must be read alongside** the canonical TSD. It specifies the chosen us-chicago-1 region, staged Ampere A1 single-node lab/PAYG/HA options, approximate resource layout, a thirteen-step provisioning/deployment procedure (D-01 through D-13), cost/revenue sensitivity, upgrade triggers and OCI-01 through OCI-12 blockers.

| Deployment concern | Design/document coverage | Actual operational evidence needed | Current status |
|---|---|---|---|
| Cloud region and stage topology | Chicago OCI region, 2 OCPU / 12 GB candidate, Drogon + separate C++ workers + PostgreSQL/PostGIS processes on single ARM64 VM | Real tenancy, instance availability, network rules, deployed endpoints | **PLAN ONLY** |
| OCI account, identity and billing | Account/region, MFA, quotas, Always Free vs PAYG distinctions | Approved tenancy access, real benefit/quota and billing dashboard proof | **BLOCKED: OCI-01–03** |
| Network, TLS and host configuration | 443 HTTPS only, no public PostgreSQL, restricted admin/Bastion, process limits | Versioned IAM/VCN/firewall/IaC, domain/certificate, OS hardening and audits | **NOT CONFIGURED** |
| Repeatable application delivery | AArch64 build, systemd/Podman and signed build ideas | Checked-in reproducible deployment manifests, health-check gating, migration sequencing, rollback rehearsal | **NOT IMPLEMENTED** |
| Database migration/security | PostgreSQL/PostGIS, least privilege, child/family grants and RLS | Executable migrations, migration tests, real secret store and tenant attack tests | **NOT IMPLEMENTED** |
| Off-machine backups and deletion | Encrypted backups and restore plans, deletion tombstones | Tested restore, retention/deletion across backups, measured RPO/RTO and key recovery | **NOT TESTED** |
| Synthetic scaling/battery | 10–1,000 initial test rollout, estimated finances/scale | Load-test results, actual storage/WAL/cost utilization, device battery and GPS evidence | **NOT MEASURED** |
| Production availability | Single-node limitation explicitly disclosed, multi-node HA upgrade stage | Approved paid HA design, on-call, uptime/error objectives and failover/incident drills | **NOT APPROVED** |
| Child-data legal release | US regional data location acknowledged | Publisher identity, target markets, privacy/data safety pages, cross-border legal review, Play approval | **EXTERNAL OPEN** |

**Interpretation:** AG-011 (capacity/cost/RPO), AG-021 (provider licensing/fees), and AG-022 (operations) have **documentary planning coverage**, not executable deployment readiness. B-08 has a provider/region direction set but is not fully closed. Actual deployment remains blocked by OCI-01..12 and E-01..14 as applicable. Never call the service operational because an Always Free cost estimate or diagram exists.

**Next deployment deliverables when source implementation starts:** parameterized OCI IAM/VCN/compute/volume definitions, hardened non-root ARM64 application delivery, secrets provisioning, database migration and rollback pipeline, encrypted Object Storage backup + external-restore exercise, observed service health/alarms, per-child cost telemetry and a signed dev → staging → limited pilot → paid-production go/no-go record.

## 8. New India-law, resilience, subscription and capacity audit closure status (2026-10-26)

**Documentation-level remediation (NOT implementation approval):**
- **AG-005/016:** [India DPDP and US Chicago transfer assessment](../03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md) now references official Gazette, child age under 18, section 9(3) behaviour monitoring restriction, limited safety real-time exemption, phased 2027 commencement and lawyer/deployment stop gate. **LEGAL_REVIEW_OPEN**; no automatic exemption for consumer tracking/history/usage. B-01/B-02/X-03 unchanged OPEN.
- **AG-013:** [SOS escalation/fallback](../../M4-usage-health-sos/01-usage-health-and-sos/SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md) includes real guardian ACK, FCM-vs-SMS-vs-independent worker differences, bounded attempts/cost and outage tests. **SOS-B01–07 OPEN**; no emergency-grade promise.
- **AG-011/022:** [OCI disaster recovery and testable RPO/RTO targets](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_RECOVERY_AND_PILOT_READINESS.md) reconcile one Always Free VM with actual failure domains and restore evidence. **UNTESTED**; hardware/provisioning/HA funds missing.
- **AG-021/023:** [Current-price fully-loaded break-even and staffing plan](../../M7-commercial-integrations/01-commercial-plans-and-costing/PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md) proves ₹50/₹500 viability **cannot yet be concluded**, names engineering roles, hardware and cash blockers. TEAM-01–08 open.
- **AG-003/004/009:** [Owner register §I](BLOCKERS_AND_OWNER_DECISIONS.md) now provides explicit pending inputs for legal publisher, child ages, retention, guardian scopes, Google Sign-In candidate, resettable test phone and rollout gates. **OWNER_DECISION_OPEN**; product owner hasn't answered.

**No changes to earlier AG-001–AG-026 original finding counts.** These are additive design controls. Do not close an audit item merely because a document exists; actual owner decisions, code tests, legal memoranda, hardware trials and vendor/OCI billing verification are the evidence required.

## 2026-10-26 documentation-only media design clarification

New [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md) records owner acceptance of **conditional media technical research** and verified, actionable Madalasa parent failure reasons. Existing compatibility, privacy, Android security, Google Play and legal release blockers **remain OPEN**. This documentation clarification does not establish implemented code, tested devices, published media features, approved child-data processing, or a closed security audit. T-MEDIA-01–18 are planned, NOT_TESTED. Audit remediation status should not be upgraded merely because these specification links exist.

## 2026-10-27 capability scanner documentation-only remediation

Accepted documented design: read-only Alarka first-launch device sensor/API scan, pairing-bound device capability POST with monotonic version and durable ACK, OS-owned permission dialog/Settings flow with verification after return, parent scoped GET and cause/freshness UI, best-effort later revoke/regrant detection. [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) + [Figma supplement 46 screens](../../../ui/figma-functional-handoff/06-capability-onboarding.json) + [two editable Figma diagrams](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=27-2) are **design evidence ONLY**, not test implementation. Keep T-CAP-01…24 NOT_IMPLEMENTED/NOT_TESTED; M0 legal/Play, device/OEM, owner and security blockers remain open. Original M1 schema has not been changed by the extended draft full API.

## 2026-10-27 media activity log/admin-panel documentation-only change

FR-050 and FR-051 have new [media audit logging design](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md) and [admin console specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md), a draft OpenAPI with parent/admin filtered read endpoints, [28 editable Figma screen mocks](../../../ui/figma-functional-handoff/07-media-activity-audit.json) and native [audit HLD/LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=35-2). **Documentation and Figma presence are not implementation, Postgres migrations, security audit, tested app/API, counselor opinion or Google Play approval.** T-AUD-01–22 and T-ADM-01–14 remain NOT_TESTED. No raw media on VPS in proposed model, but metadata and administrator searches are privacy sensitive. The original eight Eraser diagrams were not modified.

## 2026-10-27 PostgreSQL GPS durable inbox + bulk insert design added (documentation-only)

Owner accepted design [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md); Figma [HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-2), [LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-60), [benchmark diagram](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-126) and whole-project API ack rule now align. Older 'HTTP 202 = raw table committed' narrative is explicitly superseded for preferred inbox mode. Remediation status **DESIGN ONLY**: no Android encrypted 48h queue, Postgres inbox migration, C++ workers, confirmed 1–2min background uploads, T-ING-01…24 evidence, DPDP legal approval or Play release. Redis deliberately not required in MVP. Direct bulk alternative remains unmeasured and open as a performance benchmark.
