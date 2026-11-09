# Release Readiness & Owner Decision Gate — M0/M1 → Android Pilot

## 2026-11-09 engineering-evidence reconciliation — Free V1 Internal Testing (NOT public clearance)

This dated note **supersedes the historical 2026-10-30 PR #9/Android scaffolding status statements for the specifically evidenced 2026-11-08 development and internal-test slices**, but does NOT check the unresolved legal, child-data, Play policy, operational, background-location or production-release approval boxes below. Basis: [dated source/evidence audit](../../../audits/RELEASE_AND_NEXT_VERSION_IMPLEMENTATION_AUDIT_2026-11-09.md) and [next full-version plan](../../../roadmap/NEXT_FULL_VERSION_IMPLEMENTATION_AND_ACCEPTANCE_2026-11-09.md).

| Milestone | Evidence as of review | Gate |
|---|---|---|
| GitHub code integration | `dev` has production-ID defaults for both Android Gradle modules; `dev → main` [PR #60](https://github.com/methakon/Madalasa-Alarka/pull/60) remains **open** (at inspection: 396 commits / 187 files ahead). Permanent `parent`/`child` branch copies require synchronized reconciliation. | REVIEW REQUIRED |
| Signed Android artifacts | Owner/Antigravity reports Alarka 0.1.0 versionCode **1**, Madalasa 0.1.0 versionCode **2**, dedicated upload keys and successful `jarsigner` verification. This documentation review did not access the AAB bytes. | ENGINEERING_REPORTED |
| Internal Play distribution | Owner supplied Alarka Internal Testing acceptance screenshots and an internal test opt-in URL. Madalasa parent signed AAB is reported ready, but no final parent Play-distribution link was verified in this audit. | ALARKA OWNER-REPORTED; PARENT BLOCKED/UNKNOWN |
| Release-built API/OAuth configuration | Non-secret HTTPS API origins and parent Google Web Client ID may be supplied at Gradle build time but **default empty**. No independently verified dump of these resources from the signed or Play-delivered AABs is available. See [Issue #61](https://github.com/methakon/Madalasa-Alarka/issues/61). | P0 VERIFY |
| Two-phone SOS/ACK | Owner/Antigravity evidence at [Issue #52](https://github.com/methakon/Madalasa-Alarka/issues/52#issuecomment-6712011065) for Android 9/11 synthetic/debug identities; same-event ACK, manual offline retry and revocation reported PASS. **Not** evidence that Play-distributed production-signed bundles passed. | REPLAY REQUIRED |
| Security baseline | CSP/HSTS and logout PRs #58/#59, 14/14 bounded staging baseline, Neon TLS, RLS worker reports; [Issue #57](https://github.com/methakon/Madalasa-Alarka/issues/57) closed. [Issues #52](https://github.com/methakon/Madalasa-Alarka/issues/52) and [#54](https://github.com/methakon/Madalasa-Alarka/issues/54) remain open pending their individual criteria. | STAGING VERIFIED BY WORKER |
| App icons & listing | Android adaptive launcher resources inspectable in source; operator reports original Queen Madalasa/Prince Alarka assets, 512px icons and feature graphics. Upload/presence of **both Play listing assets** requires Console verification. | INCOMPLETE STORE EVIDENCE |
| Public/real-minor release | Scope remains FREE_ONLY adult-owned synthetic test devices; location monitoring release gate OFF, no child personal data processing, payments or public rollout authorized. Independent India legal/retention/custody/Google Play and operations approval still pending. | **NO-GO** |

The historical `docs/roadmap/LOCAL_TASK_EXECUTION_STATUS.json` was last updated 2026-11-02 and must not be bulk-marked PASS without per-task execution evidence. For the next development milestone follow the [task- and acceptance-ordered plan](../../../roadmap/NEXT_FULL_VERSION_IMPLEMENTATION_AND_ACCEPTANCE_2026-11-09.md), not the prior assumption that all Figma/OpenAPI concepts are executable.



> **FREE-FIRST DECISION (2026-11-03):** Free-only parent/child Play launch is now the proposed first production stage, with 108 child slots and a server-enforced FIFO service queue. Parental signup remains available after capacity fills, but queued children cannot start services. Paid SKU, trial and premium functions remain preserved in code and disabled. See [free-first release roadmap](../../../roadmap/FREE_FIRST_108_CHILD_RELEASE_AND_WAITLIST_2026-11-03.md). **BillDesk approval is not a precondition for a free-only non-transactional listing, but all Google Play, child-data legal, OS permissions, security and operational gates still apply; no live release approved.**


> **Document control:** M9 / 03-release-gates · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

## Current onboarding evidence — 2026-11-03

- [x] **BillDesk application submitted:** owner provided successful-submission text from the official onboarding portal, including a numeric Application ID held privately (not committed to GitHub).
- [ ] **BillDesk KYC and approval:** Video KYC completion, provider acceptance, merchant activation and payout/tax setup have **not** been confirmed. The next action is to request status at `onboarding@billdesk.com`, including the private Application ID in the subject.
- [ ] **Unpublished Play listing question:** obtain BillDesk clarification whether a Play Console/internal-testing link is acceptable before the Play Store listing becomes public.
- [x] **Google Play publisher identity:** separate prior owner-confirmed completion; this does not certify BillDesk or merchant readiness.
- [ ] **Real-child/commercial release:** still **NO-GO** on independent product/platform/legal/technical gates.

[Current BillDesk status tracker](BILLDESK_APPLICATION_SUBMISSION_TRACKER_2026-11-03.md). Any 2026-10-30/earlier pending-identity or PR9-only engineering statements below are *historical*, not the current GitHub build status. Portal submission alone is not KYC approval.

**Current state, 2026-10-30:** real-child and commercial release **NO-GO**. PR9 has a runnable, CI-tested narrow Drogon backend and fresh PostgreSQL16 M1 tests; it is unmerged and real ParentOIDC validation is absent. Android remains source scaffolding only. No production deployment or Play approval is evidenced. [Detailed M1 review](../../M1-secure-platform-foundation/02-development-process/M1_STACK_PR9_REVIEW_2026-10-30.md) and [test evidence queue](../../M8-operational-readiness/03-quality-and-evidence/TEST_STRATEGY_UNIT_INTEGRATION_LOAD_SECURITY.md) distinguish verified slices from remaining work. Google Payments verification does not prevent documentation/testing progress.

## Ownership and publisher setup
- [x] Owner-declared publisher/controller decision recorded: **SWARNA SEKHAR DHAR**, individual, India; same legal individual as Google Play publisher. This records a decision, not verified identity or counsel approval; no registered company is claimed.
- [ ] Google Payments/merchant **activation NOT VERIFIED** despite separately confirmed BillDesk application submission; provider decision and Video KYC completion **PENDING EVIDENCE**; public support contact **PENDING CONFIRMATION**; legal review **PENDING**. Any legally/platform-required address/tax/IP/license disclosures need separate owner/counsel evidence, not invented values.
- [ ] GitHub About description/topics, private vuln report channel, enforced CODEOWNERS review and branch protections set in GitHub UI.
- [ ] Named, funded security response lead/backups, Grievance Officer and confidential support contact.
- [ ] Staff responsibility roster and release/incident authorization matrix verified.

## Policy and child safety
- [ ] India counsel signs child-specific data purposes, DPDP phased commencement/exemptions and rights.
- [ ] Verifiable parental consent/authority and custody dispute/safe-report handling implemented and verified.
- [ ] Google Play Families/background location/monitoring/isMonitoringTool/usage/media/target-SDK approval from **actual Play Console**; signed reviewer demo and Data Safety.
- [ ] Final privacy, terms, cancellations/refunds and child deletion web pages **HTTPS-hosted and tested** (current public/legal pages are DRAFT, noindex).
- [ ] Actual data retention schedule signed; raw GPS 14-vs-30-day dispute resolved, local 48h capacity not mistaken for legal retention.

## Implementation and test
- [ ] Kotlin Alarka/Madalasa Gradle builds and Play-supported manifests, permissions, supported device matrix.
- [ ] C++20 Drogon API, Postgres/PostGIS migrations, device pairing, forced RLS child scopes.
- [ ] Durable PostgreSQL GPS inbox Tx A with committed 202, C++ leased bulk Tx B and 48h delayed/duplicate/deletion replay tests.
- [ ] Security leak prevention, admin MFA/case read audit, honest command and sensor statuses, SOS fallback.
- [ ] Test plan evidence: unit/integration/E2E, 1k/10k/100k scale, Android OEM, independent penetration/STRIDE, signing/SBOM/vendor.
- [ ] Report actual completed vs missing tests; design documents are not acceptance results.

## Infrastructure and operations
- [ ] OCI final region, backups/log region, processor DPAs, IAM/network/TLS/secret manager, encrypted storage.
- [ ] Off-host backup + restored test with recorded actual RPO/RTO; per-child tombstone restore, inbox durability.
- [ ] Monitored SLOs, paging/incident playbooks, CERT-In clock, applicable DPDP notice process, runbook and on-call coverage.
- [ ] Released app signing lineage, versionCode and staged rollout/rollback verified, vendor incident contacts.

## Go / No-Go record
Release type: [SYNTHETIC DEVELOPMENT / ADULT DOGFOOD / REAL CHILD PILOT / COMMERCIAL]. Legal entity: [TBD]. Release commit/build SHA: [TBD]. Approvers: Product [TBD], Android [TBD], Backend [TBD], Security [TBD], India counsel [TBD], Privacy/Grievance [TBD], Play reviewer evidence [TBD]. Decision: **NO-GO for real children until independently approved**. Date: [NOT APPROVED]. No placeholder constitutes a signature.

For future records, publisher/controller is the owner-declared individual above, not a fictional company. Keep verification evidence private. No release approval is granted by checking the owner-decision row.

## 2026-10-27 uploaded governance document reconciliation — review does not equal approval

The six supplied governance files were reviewed/merged under \`docs/\` and recorded in [review ledger](../../M0-foundation-and-approvals/01-project-governance/UPLOADED_GOVERNANCE_DOCUMENTS_REVIEW_2026-10-27.md). This **does not close** the real-child/commercial NO-GO: retention 14-vs-30-day GPS and all other periods are unsigned; DPIA has no controller/India counsel signoff; security reporter email/PGP/private GitHub intake not verified; incident roster/24x7 escalation not verified or tabletop-tested; IP/license approval remains separate from the now-recorded individual publisher; Play/DPDP child collection remains feature gated. The historical blanket assertion that no C++ implementation exists is superseded by the narrow PR9 evidence above; Android and full product/ingestion acceptance remain unverified. Owner must record each approval and evidence before this checklist can move to GO.

## 2026-10-27 repo-wide evidence gate

The [verified gap register](../../M0-foundation-and-approvals/01-project-governance/REPOSITORY_GAP_AND_DELIVERY_AUDIT_2026-10-27.md) distinguishes present governance/docs from missing actual approvals. Additional NO-GO checks: [ ] GitHub About/branch protection/private vulnerability reporting inspected and enabled by repo owner; [ ] all root policy contacts are reachable; [ ] Android source-to-build A1 runnable debug APKs, lint and signed artifact evidence filed; [ ] independent legal and security approvers assigned, not only default CODEOWNER; [ ] current partial M1 CI does not substitute for device/Play/penetration/restore tests. Documented repo sections cannot be counted as completed M0 gates.
