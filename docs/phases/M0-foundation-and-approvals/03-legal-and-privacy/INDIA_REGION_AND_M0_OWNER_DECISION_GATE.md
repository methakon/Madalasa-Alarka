# Madalasa–Alarka — India OCI Region and M0 Owner Decision Gate

> **Document control:** M0 / 03-legal-and-privacy · Proposed owner: Privacy counsel + owner (not assigned) · Registry: DRAFT_LEGAL_REVIEW_REQUIRED; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (guardian/parent), **Alarka** (child companion). GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka), renamed 2026-10-26. [Source story and naming contract](../02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

## Current X-01 state — 2026-11-03

**Google Play publisher identity:** previously owner-confirmed complete. **BillDesk:** owner has now supplied an application portal confirmation of successful submission; the numeric application reference stays private and is used in email subjects to `onboarding@billdesk.com`. **Video KYC, BillDesk decision, merchant payout/tax activation:** still unverified. **India child-data compliance and actual Play release:** independently open. This does not require the engineering team to stop local build or testing.

See [current BillDesk submission tracker](../../M9-play-release/03-release-gates/BILLDESK_APPLICATION_SUBMISSION_TRACKER_2026-11-03.md). The dated 2026-10-30 statements below are retained for history rather than current identity/payment status.

**Current status — 2026-10-30:** Owner-declared publisher is **Individual SWARNA SEKHAR DHAR, India**, the same individual intended for the legal and Google Play publisher identity. This is a declaration, not verified account evidence or legal approval. **Payments identity pending; merchant setup pending; public support confirmation pending; legal review pending.** No company, GST registration, public address or email is inferred. Real child-data release remains **OFF / NO-GO**.

**Decision version:** 2026-10-26, reconciled 2026-10-30. Hosting preferences below are deployment scenarios, not prerequisites for environment-agnostic local development. Final production region, tenancy and bandwidth economics are reserved for deployment; nothing here authorizes provisioning. The [current legal-source review](INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md#current-source-grounded-review--2026-10-30) distinguishes enacted law, commenced provisions, guidance and questions for counsel.

## 1. New preferred architecture location

- **Historical preferred primary OCI region: India West — Mumbai (ap-mumbai-1)**; final owner deployment decision remains reserved.
- **Historical alternative before tenancy creation: India South — Hyderabad (ap-hyderabad-1)**; not a verified tenancy or provisioning instruction.
- **Historical Chicago (us-chicago-1) superseded for new deployment selection**, not a physical migration. This project has not provisioned an OCI VM or database. [Chicago financial plan](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md) remains for historical scenario comparison, not a verified Mumbai quote.
- Ampere A1 availability, quotas, billable charges, invoice currency and support must be verified for actual account. Always Free compute belongs in the tenancy's **home region**; do not assume an existing US-home tenancy gets Mumbai Always Free resources. Check feasibility of a new tenancy, where appropriate, rather than silently changing an existing one.
- Oracle lists **one availability domain each** for the general Mumbai and Hyderabad OCI regions; don't invent multi-AD resilience in either region. Independent failover and real backup/restore still matter.

## 2. Local storage does not erase child privacy law

India OCI location removes the chosen **US primary OCI storage location**, but not India DPDP requirements for under-18 consent, narrow real-time safety exception, historical route and app-usage behavioral monitoring. Nor does it ensure Google/Firebase/Maps/Billing/identity/SMS services only process data in India.

Before claiming India-only storage:
1. Verify actual OCI region for PostgreSQL, boot/block, object backups, WAL, secrets, logs, snapshots, support diagnostics and disaster recovery.
2. Verify data flows/subprocessors for Google Maps, Firebase FCM, parent identity, billing and optional SMS/Drive; document cross-border cases.
3. Complete legal review under DPDP Act sections 9/16, Rules 10/12 and other applicable laws with India counsel; assess actual product exemption eligibility.
4. No real minors' location, usage or guardian authority data until purpose-specific legal gates and owner approvals pass.

Official: https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm and https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm .

## 3. Decisions — what is real vs still open

| Question | Status | Action |
|---|---|---|
| Primary hosting | Historical Mumbai preference, Hyderabad alternative; **final deployment selection reserved** | Local development is environment-agnostic; verify actual region/tenancy/costs before deployment |
| First launch B-02 | **OWNER DECIDED: India-only, children 0–17 inclusive** | No release in additional countries; under-18 legal/Play consent and feature-specific compliance still pending |
| Legal publisher B-01 | **OWNER DECIDED; VERIFICATION PENDING** | Individual legal publisher: **SWARNA SEKHAR DHAR**, India; same individual intended to own the Google Play publisher account. Play identity, Payments verification, contact channels and legal notices still require evidence |
| Age B-02 | **OWNER DECIDED: 0–17 inclusive** | Legal age-verification/authority method and age-appropriate safeguards remain open |
| Data retention B-07 | OPEN | Raw 14d / derived 90d / audit 365d / backup 30d are design candidates only; usage OFF pending counsel |
| Guardian B-09/B-18 | OPEN | Owner-only invitation/revocation, per-child scopes and 45min pickup current-view are secure **proposals**, not confirmed policy |
| Login OCI-06 | Google Sign-In via Credential Manager + backend ID-token verification **engineering candidate** | Verify provider/account recovery; independent guardian/adult verification required |
| Managed device testing | OPEN | List real older/newer phones and one owner-approved safe-to-factory-reset spare |
| Staffing B-21 | OPEN | Name engineers, QA, security, operations, lawyer, support and actual budget |
| SOS | Best-effort check-in proposed | Separate commercial SMS + independent fallback and guardian ACK tests before emergency promise |
| M2 real-child pilot | BLOCKED | Counsel and technical releases, retention, recovery and monitoring disclosures first |

## 4. Cost rebaseline and OCI account gate

The former OCI Chicago figures (at 1,000 children ~₹0.20 direct or ₹3.24 reserved per child per month) **cannot be presumed accurate for Mumbai/Hyderabad**. Use current Oracle India pricing/account and cost estimator, confirm free allowances and service quota, block volume, backups, network, IAM, region and reliability budget. Update model after live account evidence; this is not an automatic price increase or saving.

## 5. Milestone M0 acceptance

- At the separate deployment gate, decide region **before creating an OCI home tenancy**; this is not an M0 local-coding prerequisite.
- Owner supplies B-01/B-02/B-07/B-09/B-18/OCI-06/hardware/TEAM answers, with no personal child data in public repository.
- India legal counsel reviews child tracking and behavioral monitoring even if storage is entirely India-hosted.
- Work on synthetic fixtures, M1 API, SQL and test harness can proceed without using real child data.
- Sign an explicit M0 approval record before M2 real child location or public pilot.

Sources: [DPDP legal gate](INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md), [blocker register](../01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md).

## B-01 follow-up — 2026-10-30

The owner confirmed an **individual** Indian legal publisher (**SWARNA SEKHAR DHAR**) and the **same individual** for the Google Play account. This is an owner declaration, not proof of Play account verification or counsel signoff. B-01 is `DECIDED / EVIDENCE_REQUIRED`, not closed; consult the [canonical blocker register](../01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md#current-progress-while-google-identity-verification-is-pending--2026-10-30). Privacy, consent, grievance and deletion texts must identify the verified data fiduciary and approved public contact without committing private government IDs, addresses or financial details.

## B-02 decision recorded — 2026-10-30

Initial release is **India only** for children **ages 0–17 (under 18)**. Owner scope is confirmed; the child-privacy legal gate remains open. Do not claim the DPDP real-time safety-location exception automatically authorizes recorded route histories, app usage analysis, remote media, or unrestricted tracking. Keep such features subject to separate policy/consent/necessity review. See the [blocker register](../01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md#current-progress-while-google-identity-verification-is-pending--2026-10-30).
