# Review and Reconciliation of Six Uploaded Governance Files

> **Document control:** M0 / 01-project-governance · Proposed owner: Project owner (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Review date:** 2026-10-27  
**Project:** Madalasa–Alarka | **State:** DOCUMENTATION REVIEW COMPLETE; OWNER, INDIA COUNSEL AND OPERATIONAL GATES OPEN.  
**Basis:** Six files supplied by the owner in this conversation, verified against current \`main\` repository documents, CI workflows, Android and C++ design decisions, and official India/Google Play legal notices. This report does **not** certify implementation, legal compliance, licensing ownership or publication.

## 1. Source-to-repository disposition

| Uploaded source file | Destination under docs/ | Disposition | Material reconciliation |
|---|---|---|---|
| \`BUILD_AND_RUN.md\` | [BUILD_AND_RUN.md](../../M1-secure-platform-foundation/02-development-process/BUILD_AND_RUN.md) | **MERGED INTO EXISTING REVIEWED FILE**, not replaced | Retained current verified CI: Python stdlib JSON-formatted M1 OpenAPI, PostgreSQL 16 \`postgres:16\` identity/RLS test, \`amar_pola_m1\` synthetic DB, not PostGIS required for M1. Uploaded PyYAML/PostGIS command assumption and claims about runnable future apps were corrected/qualified. |
| \`DATA_RETENTION_SCHEDULE.md\` | [DATA_RETENTION_SCHEDULE.md](../03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md) | **MERGED INTO EXISTING DRAFT; NOT ADOPTED AS POLICY** | Preserved uploaded R-01…R-18 periods as **unsigned candidate proposals**; explicitly maintained existing conflict **14 vs 30 days raw GPS**. Added 48h local queue, PostgreSQL GPS inbox/WAL, late retries, app usage, dedup, outbox, backups and deletion tombstones. CERT-In covered ICT 180-day log obligation does **not** require 180-day raw GPS. |
| \`DPIA.md\` | [DPIA.md](../03-legal-and-privacy/DPIA.md) | **MERGED INTO EXISTING CURRENT DRAFT** | Added uploaded P1…P12 processing and K-01…18 risk crosswalk, owner signature matrix and alternatives. Kept statutory **phased** DPDP commencement, M0 real-minor NO-GO, 2026 India/Play uncertainty, metadata child sensitivity, and untested residual risk. |
| \`INCIDENT_AND_BREACH_RESPONSE_PROCEDURE-1.md\` | [INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md](../../M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md) | **MERGED / CANONICALIZED FILENAME**, no second conflicting \`-1\` copy | Preserved uploaded incident phases, guardian/child, SOS, compromised account, vendor, Play signing, and evidence form; retained **CERT-In 6h covered-case assessment**, **future applicable DPDP phased duties** and no false assertion that DPDP Rule 7 was in force during Oct 2026. |
| \`SECURITY.md\` | [SECURITY.md](../../M1-secure-platform-foundation/03-security-and-permissions/SECURITY.md) | **NEW DOCS COMPANION**, root remains authoritative | Reconciles uploaded private researcher guidance, synthetic proof-of-concept boundaries, proposed SLA targets, 90-day disclosure intent and placeholder email/PGP. Explicitly warns that reporter contact and private vulnerability reporting must be enabled and tested, and no response time is guaranteed today. |
| \`LICENSE\` | [LICENSE](../03-legal-and-privacy/LICENSE) | **NEW NON-OPERATIVE REVIEW DOC**, not an effective license | Reviews custom proprietary/source-available proposal, missing publisher/contact/court, contribution and trademark clauses. Protects the repo’s authoritative **interim all-rights-reserved** [root LICENSE](../../../../LICENSE). No unsigned license grant, ownership claim or OSI classification introduced. |

**Rationale for merging rather than uploading unchanged:** Each uploaded file has the same purpose as one or more already-reviewed repository files. Blind overwrite would regress technical accuracy, invent GDPR/DPDP obligations or signed retention periods, and could accidentally present an unsigned proprietary license or unreachable security email as effective. The owner's instruction was to verify, make necessary changes and save **under docs/**; this is a project-specific integration rather than an unreviewed archive.

## 2. Project conformity checks performed (documentation)

1. **Naming and status:** the user-facing Android apps remain **Madalasa** and **Alarka**, repository \`methakon/Madalasa-Alarka\`. Only synthetic M1 contract and SQL tenant isolation tests are documented as executable; no built Android/Drogon/admin services or pilot.
2. **M1 scope:** \`.github/workflows/m1-contract-and-tenant.yml\`, \`backend/tests/lint_openapi_m1.py\`, \`backend/persistence/migrations/0001_m1_identity.sql\` and \`backend/tests/m1_tenant_isolation.sql\` are present. Python linter uses built-in \`json.loads\`. PostgreSQL 16 CI does not require PostGIS for current identity schema.
3. **Location and usage design:** separate adaptive GPS capture from conditional 1–2-minute uploads and a targeted 48-hour encrypted **offline capacity**. One authenticated JSON batch = one PostgreSQL durable inbox Tx A COMMIT before 202 ACK; independent C++ bulk worker Tx B commits raw PostGIS/dedup/reconstruction outbox and inbox PROCESSED; no Redis at MVP. Neither feature is legally released for actual children.
4. **Media and admin:** actual user audio/photo/video **not stored on the VPS**; verified **media activity metadata** would be, if approved. Admin names/IDs and search histories require MFA, case/role scopes and separate audited reads, not universal root access.
5. **Privacy:** uploaded 30-day raw GPS proposal conflicts with an earlier 14-day project draft. No duration is owner-signed. Offline queue, temporary GPS inbox/WAL and backup restore handling all require explicit retention/deletion policy. The proposed legal entity, India OCI region and processors are still unverified.
6. **Security and reporting:** six-hour CERT-In duty applies to reportable covered incidents under its directions. DPDP Act/Rules have **staggered commencement**, including many child-data and breach-rule obligations anticipated May 2027 under November 2025 notifications; verify amendment/current status with counsel on actual incident/pilot date. An uploaded universal "already in force" statement would be wrong.
7. **IP rights:** no owner-validated legal publisher, contact address, CLA, copyright provenance or proprietary/open-source selection. Root all-rights-reserved holding notice remains operative; \`docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/LICENSE\` is **not a second grant**.

## 3. Release/owner decisions NOT closed by this review

| Gate | Required decision or evidence | Current |
|---|---|---|
| O-01 | Identify legal publisher/data controller, security contact, grievance officer and India incident commander/backups | **OPEN** |
| O-02 | Confirm lawful child location and app-usage monitoring purpose/exemption, verified guardian authority, age transition, and Google Play monitoring/Families permission policy | **OPEN / NO-GO** |
| O-03 | Sign exact purpose-specific retention table including raw GPS **14 vs 30 days**, 48h local queue, server inbox, WAL, media metadata and backup retention | **OPEN** |
| O-04 | Set real confidential researcher-reporting channel (GitHub private vulnerability reporting and/or tested email/PGP), response/disclosure commitment | **OPEN** |
| O-05 | Select IP rights/publisher and approve effective repository license/contribution terms; replace root holding notice only after legal review | **OPEN** |
| O-06 | Verify India OCI region/processor contracts, security ICT log residency, incident notice applicability, exercise & signed DPIA | **OPEN** |
| O-07 | Build and run Android permission/FGS, 48h encrypted buffer, database recovery, C++ bulk SQL and admin/child auth negative tests | **NOT IMPLEMENTED / NOT TESTED** |
| O-08 | Prove sealed backups, cross-tenant RLS, deletion tombstones, offline replay rejection and legal/Play GO/NO-GO review | **OPEN** |

No user should be told these six documents alone make this product ready for real children's data, remote sensor capture, Play Store approval, or production rollout.

## 4. Official primary links checked for legal timing/policy (not legal advice)

- Gazette of India **G.S.R. 843(E)** 13 November 2025 (phased DPDP Act commencement): https://egazette.gov.in/WriteReadData/2025/267647.pdf
- MeitY DPDP Rules 2025 Gazette (phased Rules): https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf
- CERT-In Directions 28 April 2022: https://www.cert-in.org.in/PDF/CERT-In_Directions_70B_28.04.2022.pdf
- CERT-In FAQs on partial initial reports: https://www.cert-in.org.in/PDF/FAQs_on_CyberSecurityDirections_May2022.pdf
- Google Play monitoring/stalkerware classification and persistent notification requirement: https://support.google.com/googleplay/android-developer/answer/9888380

**No formal India lawyer review, CERT-In filing test, security disclosure contact validation, legal license approval or Play Console approval was performed.**
