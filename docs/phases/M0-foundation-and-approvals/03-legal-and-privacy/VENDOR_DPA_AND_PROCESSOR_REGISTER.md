# Vendor DPA / Data Processor Register — Contract and Transfer Gate

> **Document control:** M0 / 03-legal-and-privacy · Proposed owner: Privacy counsel + owner (not assigned) · Registry: DRAFT_LEGAL_REVIEW_REQUIRED; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Status — reviewed 2026-10-30:** Draft vendor due-diligence register, no signed DPAs or selected deployment region verified. Responsible contracting publisher is **owner-declared Individual SWARNA SEKHAR DHAR, India**, same intended legal/Play publisher. **Identity evidence, Payments identity, merchant setup, public support confirmation and legal review pending.** No company, GST registration, address or email is inferred; declaration is not an executed vendor contract. **Real child-data release OFF.**

## Current role and contract gate — 2026-10-30

The [official-source legal gate](INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md#current-source-grounded-review--2026-10-30) records commencement, current IT/CERT-In duties and future DPDP obligations. Section 8(1)–(2) retains fiduciary responsibility and requires a valid contract for a processor engagement when commenced; future-phase Rule 6 requires appropriate processor security terms when commenced. A list of products is not proof that every supplier is a processor: document **actual legal counterparty and role per flow** (processor, independent fiduciary or other recipient), governing terms/version, instructions, independent purposes, onward recipients and review evidence. Obtain an applicable valid agreement; do not invent a separately signed DPA where the actual contract mechanism is different or unverified.

Record actual storage, backup, remote-support and subprocessor locations, transfer basis/current restrictions, incident cooperation, rights assistance, exit/deletion and restricted holds. India OCI storage does not prove Google/Maps/FCM/Play/Drive processing stays in India; final production region/tenancy/economics are separate deployment decisions, not prerequisites for synthetic local work. Future Rule 8(3) covers personal data/traffic/processing logs, not just security logs; contracts must reconcile it with the still-unadopted retention schedule. No data-residency certification is inferred.

Keep current CERT-In six-hour Annexure I reporting distinct from future Rule 7 affected-person/initial Board intimation **without delay** and specified Board detail within 72 hours (or permitted extension). Require vendor notice/cooperation fast enough for the applicable duty; do not accept a generic “72-hour notice” as sufficient for every route. Do not automatically apply the direction's provider-class five-year subscriber record rule to this app merely because it rents a cloud server. Google OIDC is authentication, not an authority-verification processor or Family Link relationship service. Public support and statutory contacts remain unconfirmed.

| Vendor or service | Planned use and personal data | Contract/DPA/compliance assessment | Actual status |
|---|---|---|---|
| Oracle Cloud Infrastructure (OCI) | C++ API, PostgreSQL raw child GPS/history, inbox/WAL/backups, security logs | Verify legal controller and OCI region (historical Chicago vs possible Mumbai), India transfer controls, DPA, support residency, subprocessor list, recovery, incident notice, encryption/key custody | NO VERIFIED TENANCY/DPA/FINAL REGION |
| Google OIDC | Guardian sign-in, account identifiers | Privacy terms, OpenID verification, scopes, retention, minors policy, OAuth app verification | DESIGN ONLY |
| Google Maps / Roads | Map tiles, optional road matching; potentially location requests/IP/device tokens | Exact SDK/APIs/Google Maps Platform terms, geospatial caching/storage restrictions and location disclosure | DESIGN ONLY |
| Firebase Cloud Messaging | Device push token, event notification hints (never raw child GPS in push) | Google/Firebase terms, transfer and processor details, minimum payload, authorization/revocation | DESIGN ONLY |
| Google Play Billing / Play Console | Parent manual-renewal prepaid purchases/receipts and installation/reviewer declarations | Same owner-declared individual legal/Play publisher; verify actual developer/Payments/merchant terms, tax/refund duties and each processing role | PAYMENTS IDENTITY / MERCHANT SETUP PENDING; no verified commercial release |
| Google Drive API (optional) | Guardian-consented selected files or backups | OAuth restricted scopes, app verification, user-specific data deletion and transfer | DISABLED / DESIGN |
| WebRTC / coturn relay | Encrypted transient sensor media if ever permitted; metadata and IPs | Hosting/operator selection, processing terms, IP logging, no persisted media, legal and Play media gates | RESEARCH P3 OFF |
| SMS/email provider | SOS fallback, guardian verification, notices | DPA, local consent, delivery receipts, costs, support and deletion | UNSELECTED |
| SSO/MFA vendor for admin | Privileged staff identity, case-access logs | Data minimization, incident alerts, sign-in key privacy, review | UNSELECTED |
| Security/observability/backup provider | Redacted ops metrics, ICT logging, backup content | India 180-day ICT logs where covered, encryption/retention and no raw child coordinate leakage | UNSELECTED |

## Contract artifacts required per actual vendor
- [ ] Correct signed publisher legal entity / controller identity and processor legal name.
- [ ] Master service agreement, executed DPA (where applicable), privacy notice and relevant lawful transfer/legal basis.
- [ ] Scoped categories (parent IDs, child GPS, permissions, media metadata, usage events), purposes, subprocessors, region/transfers and technical measures.
- [ ] Roles, audit rights, security certifications **verified** (not assumed), encryption, key access, backup locations and deletion schedule.
- [ ] Incident notification time to enable CERT-In 6h triage and applicable phased DPDP notifications; named contact/backup.
- [ ] Actual access/inventory log, cost/exit plan, data export/revocation/deletion and test evidence.
- [ ] Counsel/security/vendor owner approval and signature reference stored privately, not uploaded to public GitHub.

Do **not** copy third-party vendor template terms into an unsigned pseudo-DPA and call them legally executed. This register is an owner assignment ledger; exact vendor contracts must be obtained, reviewed and signed through normal procurement.

Related: [DPIA](DPIA.md), [India/Play Risks](INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md), [Retention](DATA_RETENTION_SCHEDULE.md), [Security](../../M8-operational-readiness/02-operations-and-support/SECURITY_AND_OPERATIONS.md).
