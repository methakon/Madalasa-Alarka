# Madalasa–Alarka — Blockers, Decisions and Resolution Register

> **Document control:** M0 / 01-project-governance · **Proposed owner:** Project owner (not yet assigned) · **Registry:** DOCUMENTED_REVIEW_PENDING; approval not recorded. [Control register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product:** **Madalasa** (parent app) + **Alarka** (child app); the GitHub repository is now **[Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka)**. [English mythological inspiration](../02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Established:** 2026-10-25 | **Updated:** 2026-10-31 | **Version:** 1.3 | **State:** DOCUMENTED_REVIEW_PENDING | **Purpose:** actionable project-owner decisions and independently verifiable engineering/release gates. Current statements below supersede historical question/queue text; an owner decision is not external verification.

Each blocker has an owner, decision or required evidence, and lifecycle: OPEN → DECIDED → IMPLEMENTED → VERIFIED → CLOSED. **Selecting a product option does not resolve software testing or Google Play review.**

**Official-text review:** [Independent Indian DPDP/Rule 12 feature assessment — 2026-10-31](../03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md#2026-10-31-first-party-primary-law-review-no-mandatory-paid-counsel-opinion). Signed-paper prerequisite REMOVED, substantive child monitoring G02 restrictions and Play G01/G04 remain unresolved.

## 2026-10-31 correction: X-03 is legal due diligence, NOT a compulsory paid-counsel/government-permit gate

**Owner challenge accepted; previous documentation incorrectly elevated a *recommended signed Indian advocate's opinion* into a universal compulsory launch condition.** Neither the DPDP Act/Rules nor Google's general Play app-review workflow has been shown to require every child-safety app developer to buy a signed legal-opinion PDF, printed certificate or separate MeitY/CERT-In approval. Do not imply that Tele-Law or MeitY can grant a general parental-monitoring license by email. Any activity-specific authorizations must be checked separately if the legal analysis identifies them.

**Keep G02 legal substance OPEN; remove the artificial document/payment blocker.** Before processing real children's information or releasing a feature, the product owner must document a *feature-specific lawfulness and compliance assessment*, with primary-source citations and risk/conditions: real-time safety location versus historical tracking, usage/behavioural reports, guardian authority, SOS, optional audio/camera/screen, third-party capture, notices, retention/deletion, cross-border processors, operative law and relevant commencement dates. Engineering must implement the necessary safeguards; Google Play and Android have **separate** policy/runtime gates. A legally sound and evidenced internal assessment can be prepared without mandatory paid counsel, but it is not itself official approval or a guarantee of compliance.

**Evidence formats:** An actionable response from a qualified Indian advocate **by email** is acceptable *supporting evidence* for the internal decision; signed PDF or paper is optional unless a particular regulator, proceeding or engagement demonstrably requires it. A 20-minute verbal call alone does not settle unanalysed features. For genuinely ambiguous/high-risk child tracking, app-usage analytics or remote media, an independent privacy-law specialist's review remains **strongly recommended**, not a universal regulatory prerequisite. If advice remains inconclusive, narrow/disable the affected feature rather than declaring it cleared.

**X-03 status:** LEGAL DUE DILIGENCE / FEATURE-BY-FEATURE ASSESSMENT IN PROGRESS; **Tele-Law case REGISTERED and MeitY guidance EMAIL SENT**, both owner-reported, responses pending. No new owner action or legal-fee payment is required just because the checklist previously said "signed opinion". Do not pause synthetic engineering; no unassessed real-child monitoring or Play release.

## X-03 legal/government consultation progress — 2026-10-31

**Owner-reported, not independently acknowledged by the authorities:** A **Government Tele-Law case has been registered** for legal guidance on the proposed Indian child-safety/parental-monitoring application. The owner has **sent the MeitY Cyber Laws clarification email** requesting guidance/referral concerning the DPDP child-safety location exception, location history, app usage, optional microphone/camera/screen features and whether any official permission or procedure applies. **MeitY acknowledgement/response has NOT been reported; no case ID, personal correspondence or private details are included in Git.**

**X-03 consultation substatus:** Tele-Law and MeitY contacts initiated, responses pending; not a government-approval process. Feature-specific documented legal due diligence remains OPEN under the correction above. A signed advocate opinion is optional, not a statutory prerequisite. Keep unassessed real-child media and monitoring OFF. Prepare technical/data-flow/legal-question packs and continue synthetic engineering independently while awaiting responses. Do not ask the owner to submit the same MeitY message again.

## X-01 updated status — 2026-10-31 (supersedes prior pending-identity wording)

**Owner-confirmed outcome:** Google Play **developer/publisher identity verification COMPLETED** (owner previously provided an identity-status screenshot; no personal document or screenshot is saved in this public repository). **Remove identity verification as an active blocker.** The owner's **BillDesk/payment verification has been SUBMITTED and is AWAITING THE PROVIDER'S RESPONSE**; merchant/payment activation is NOT CONFIRMED, and no payment account is assumed ready. BillDesk submission is not by itself proof that a separately required Google Payments merchant account/profile is activated; verify that independently if applicable.

**Track X-01 as separate substates:** X-01A **CLOSED / OWNER-CONFIRMED — Google Play publisher identity**; X-01B **IN PROGRESS / EXTERNAL RESPONSE PENDING — BillDesk/payment verification**; X-01C **OPEN / NOT YET VERIFIED — separate merchant/payment activation, tax/payment eligibility, and account-specific Play setup**. Do **not** ask the owner to re-submit completed identity documents. Do not expose ID, PAN, bank data, screenshot or transaction references in Git.

**Development impact:** Identity is no longer blocking. API, Android, P2P, synthetic billing tests, legal pages and documentation proceed independently. Only actual provider/merchant enablement and subsequent release/billing prerequisites wait on the relevant provider's decision. No claim of Play approval, child-data authority, payment acceptance or production readiness.

<a id="current-progress-while-google-identity-verification-is-pending--2026-10-30"></a>
## Historical checkpoint — 2026-10-30 (statuses superseded by 2026-10-31 above)

Source and decision owner: explicit project-owner instruction dated 2026-10-30. **Recorded owner decision:** individual publisher **SWARNA SEKHAR DHAR**, country **India**, same legal individual as Google Play publisher. **At that 2026-10-30 checkpoint only:** Payments identity PENDING, merchant setup PENDING, legal review PENDING, public support contact PENDING CONFIRMATION. **Current X-01 outcome is recorded above.** No registered company, GST registration, legal address or support email is claimed. Do not put ID/PAN/bank details, sensitive screenshots, purchase tokens or credentials in GitHub.

| Gate | Current status | Work permitted now / evidence still required |
|---|---|---|
| B-01 / X-01 publisher | **2026-10-31 CURRENT: Play identity COMPLETE (owner-confirmed); BillDesk submitted / response pending; separate merchant activation not confirmed** | Continue engineering without identity hold. Await BillDesk/provider response and confirm distinct merchant/account setup only if actually required; no repeat identity submission |
| E-09 ParentOIDC | OPEN; default-deny implementation seam only | Provider-validation design and synthetic negative tests need not wait for Payments; real parent authentication and guardian authority remain separate |
| E-01 / E-02 / PR9 | Local M1 SQL and hosted narrow backend gates VERIFIED at pinned PR head; PR9 NOT MERGED | [PR9 review](../../M1-secure-platform-foundation/02-development-process/M1_STACK_PR9_REVIEW_2026-10-30.md); owner approval required before merge, V2 co-parent/schema convergence still separate |
| B-02 / B-03 / B-04 | OWNER_DECIDED: India0–17; transparent Alarka; complete inventory eligible for review only | Feature/platform/legal/Play disposition and evidence; no blanket release or Android implementation authorization |
| B-05 | **OWNER DECIDED: standard installation first; Device Owner provisioning excluded from first release.** Read-only managed/Device Owner state detection may be designed; no elevation or silent conversion. | Never capture financial screens; no protection bypass. Future managed mode requires a separate owner decision, Android-supported provisioning, clear guardian involvement and physical-device verification |
| B-06 / B-07 / B-09 / B-18 | OPEN | Child SOS interaction, purpose/category retention and exact-child guardian invite/revoke/history scopes; qualified counsel review |
| B-14 / E-13 | Founding-family commercial rule OWNER_APPROVED; provider behavior UNVERIFIED | First 1,008 distinct paid families, one count per family, ₹50/month or ₹500/year for eligible paid children including later additions; no change to prices. Thirteen sandbox cases NOT_RUN; prepaid founding catalog and multi-child capacity unproven. Owner/finance must decide refund/fraud disqualification, slot recycling and checkout reservation/order; no automatic policy invented |
| M8 / M9 | DOCUMENTED_REVIEW_PENDING; release NOT_READY | Threat/test/incident and reviewer-pack preparation now; builds, physical OS/OEM evidence, signed notices, provider tests and owner Console actions later |
| Signing/recovery | Earlier upload-only key generated and local recovery-tested; permanent custody BLOCKED | Independent off-device backup/recovery custody and actual Play app-signing role confirmation; no new credentials authorized by current work |

**Current 2026-10-31 correction:** completed publisher identity is no longer pending. Only outstanding BillDesk/payment review, any separately required merchant setup, contact/Console eligibility and unrelated external approvals remain. Earlier text below is historical. OIDC engineering, RLS/SQL tests, legal analysis, policy checklists, billing lifecycle design and evidence preparation can continue independently. No infrastructure deployment, real-child processing, Android implementation, Console submission or PR merge is authorized by this update.

## A. Decisions you can make now

| ID | Severity | Your question / choice | Conservative default until answered | What you can provide | Blocks |
|---|---|---|---|---|---|
| **B-01** | Critical | Individual legal publisher identified: **SWARNA SEKHAR DHAR**, India; same legal individual as Google Play publisher | **OWNER_DECIDED; Google Play identity COMPLETED (owner-confirmed).** BillDesk/payment verification SUBMITTED / AWAITING RESPONSE; merchant activation NOT CONFIRMED; public support contact and legal review still pending | Owner-held Console evidence of outcome; confirm public contact and notices without publishing ID, address or payment evidence | Privacy/Play |
| **B-02** | Critical | **OWNER DECIDED: India-only initial launch; children aged 0–17 inclusive (under 18)** | Product scope established; legal assessment and Play policy classification still OPEN | India-specific parental authority, age-appropriate permissions, monitoring exemptions, consent and policy review | Child privacy/legal |
| **B-03** | Critical | **OWNER APPROVED: transparent background operation** — identifiable Alarka icon, prominent disclosure, applicable monitoring/FGS notifications, untouched OS privacy indicators, no stealth or permission bypass; Activity may close after setup, boot recovery only as Android permits | **DECIDED; Android/Play/India compliance evidence pending** | Android OS/OEM runtime tests, monitoring-app declaration, background-location review, child-privacy legal assessment | Play/Android UX |
| **B-04** | High | **OWNER DECIDED: evaluate the complete previously planned feature inventory as first-release candidates** | No blanket feature shipping approval; each candidate must pass India legal, Google Play, Android OS and security/privacy acceptance gates | Feature-by-feature eligibility evidence and final surviving release list | Delivery budget/compliance |
| **B-05** | High | **OWNER DECIDED (2026-10-30): standard installation for first release; managed Device Owner provisioning deferred.** Alarka may read and report whether the device is already managed/Device Owner, but must not elevate itself or silently convert an already-configured phone. | Standard-mode permissions and compatibility still require device tests. A future managed edition requires a new owner decision, legitimate Android provisioning (normally eligible new/factory-reset device), guardian involvement and physical proof. | First-release scope; future managed edition |
| **B-06** | High | Child-initiated SOS/check-in, optional visible foreground evidence capture, and parent-only urgent alarm | **OWNER REQUESTED DESIGN; legal/Play/Android evidence OPEN.** Child opens Alarka and presses SOS; event sends independently; optional bounded visible capture only while foreground; dedicated parent SOS notification channel only | See [B-06 UX/engineering handoff](../../../ui/figma-functional-handoff/B06_CHILD_SOS_CAPTURE_AND_PARENT_ALARM_HANDOFF_2026-10-30.md). No Figma file or implementation claimed. | Child SOS, media privacy, parent alarm |
| **B-07** | High | Retention for raw GPS, trips, usage, audit and backups? | Planning candidates: raw 14d, derived 90d, usage 90d, audit 90d; **not approved** | Actual retention per category | Privacy/schema/cost |
| **B-08** | High | Server provider and hosting/data-residency region? | No production deployment before selection | Hosting region/provider, budget | Deployment/processors |
| **B-09** | High | Who may add/revoke guardians, and how long can pickup access last? | Family owner approves per-child; temporary 45min current-location only | Roles, scopes, TTL | ACL/security |
| **B-10** | High | Launch Android versions/manufacturers? | API29+ candidate; begin Pixel + Samsung testing | Phone models/versions you can test | Device certification |
| **B-11** | High | Standalone Wear OS watch at launch? | Phone-first; Wear beta after power tests | Watch brands and GPS/LTE capability | Wear architecture |
| **B-12** | High | Battery preservation vs detailed 5–15s route capture? | Balanced default; bounded user-authorized detail mode | Accuracy/freshness preference and context | Location tuning |
| **B-13** | Medium | What counts as a stop or confirmed school arrival? | Initial candidate 3–5min walking / 5–10min vehicle with multiple trustworthy fixes | Desired rule after field tests | Trip/commute semantics |
| **B-14** | High | Founding-family pricing and eligibility owner-approved; commercial provider integration pending | First 1,008 distinct successfully paying families count once; eligible paid children retain ₹50/month or ₹500/year including later additions; no automatic renewal in prepaid design | Sandbox proof of seats/top-ups/token verification/refund behavior, merchant/tax/legal review | Billing/store |
| **B-15** | Medium | Does Google Drive backup ship in v1? What media and deletion behavior? | P2, opt-in only | Media type and retention/ownership | OAuth/data safety |
| **B-16** | High | Camera/video/microphone in Play launch or deferred? | **SOS-only media remains conditional / OFF** pending documented feature legality, Play and physical-device gates; specialist counsel recommended if legality unresolved, not compulsory paperwork; no remote/background capture | Visible child-initiated foreground capture only; one front + one rear still sequentially where supported; short visible audio clip; permission denial never blocks SOS | Sensitive permissions |
| **B-17** | Medium | Which alerts are high-priority vs quiet hours? | SOS priority; ordinary alerts deduped | Desired critical/noncritical alert list | Notification logic |
| **B-18** | High | Does a guardian see full history, current only, or child-specific subset? | Explicit least privilege, owner configurable | Role/access policy | ACL and sharing |
| **B-19** | Medium | Parent Android app only or web too? | Android first, versioned API supports future web | Client platform choices | Frontend architecture |
| **B-20** | High | Approve observed vs inferred route transparency? | Show actual fixes and gaps, no invented streets | Confirm invariant | Geo algorithms |
| **B-21** | Medium | Expected families/devices, monthly infrastructure budget and team size? | Capacity test 1k/10k/100k synthetic; no SLA claim | Budget/scale and staffing | Sizing |
| **B-22** | Medium | Launch language(s), support contact, staff coverage? | English test version; no public support claim before staffing | Languages and real support channel | Localization/Play |

**You may answer incrementally:** for example, “B-05 standard first; B-07 GPS 14 days, trips 90 days; B-11 Wear later; B-16 media deferred.” Open entries remain pending; suggested defaults are design assumptions, not approval on your behalf.

## P-1 paired-code replay disposition — 2026-10-31

**CONSERVATIVE ENGINEERING SECURITY DEFAULT SELECTED / OWNER ACCEPTANCE NOT YET RECORDED; CODE REVIEW AND CI PENDING:** `issuePairingCode` is one-time secret-bearing. The initial request returns `201` with the code; the first response is **not stored** in the idempotency table (`body_omitted=true`). An authenticated and currently authorized replay with the same key/child/body returns `409 CONFLICT` without a code and without automatic code replacement. Reuse of a key against a different child/path/body returns `409 IDEMPOTENCY_KEY_REUSED`; new key while active code exists returns `409 CONFLICT`. If the original response was lost, the parent must use any already displayed code, or wait until the requested 60–600-second expiry before issuing anew. Silent code rotation is not authorized. This deliberately overrides generic replay-of-201 semantics for secret-bearing responses, using an existing frozen M1 response code. The actor must still pass live PAIR_DEVICE authorization on retry.

**Risk/hardening:** Previously committed synthetic code may have stored a raw pairing secret in idempotency response bodies; code no longer returns such historical responses. Existing synthetic databases must be sanitized/recreated before any real deployment. M1 SQL migrations are versioned and not overwritten. Source: [P-1 resolution](../../../API_CONVENTIONS_AND_ERROR_CATALOG.md), [pending API implementation](https://github.com/methakon/Madalasa-Alarka/blob/api/backend/src/pairing.h). Runtime smoke and DB replay/one-active-code tests are still required; do not claim the pairing handler release-ready.

## 2026-11-01 Engineering Integration & Infrastructure Checkpoint

- **V2 Parent Session Bridge Integrated on main (PR #16 / PR #19, commit `accfe14`):**
  Server-controlled opaque session exchange (`POST /v1/auth/parent/google`) and revocation (`DELETE /v1/auth/session`) implemented and verified. Database migration `0021_parent_oidc_session_bridge.sql` restricts minting to dedicated `ap_auth_issuer` role, enforcing token replay prevention via SHA-256 unique index and bounding active sessions.
- **Android Foundations Promoted to main (PR #17, PR #18, PR #19, commit `accfe14`):**
  Scaffolded both Madalasa parent app (`android/madalasa`) and Alarka child companion app (`android/alarka`) with shared UI contract library (`android/ui-common`). Single-activity Compose architecture, Theme C design tokens, transparency disclosure, placeholder navigation, and zero covert recording/monitoring permissions. 18/18 unit tests passing and both debug APKs assembling cleanly.
- **Email & Communications Infrastructure Verified (2026-11-01):**
  Outbound SMTP (`mail.berhampore.in:465`, user `noreply`) and inbound mailbox (`mail.berhampore.in:993`, user `madalasa-alarka`) tested with live bidirectional email delivery and receipt against Google Gmail (`swarna.s.jobs@gmail.com`), confirming delivery directly to the primary inbox.

## 2026-10-31 E-02 API implementation update (synthetic-only)

**ALL 14 FROZEN M1 OPERATION ROUTES REGISTERED on `api`, not merged to `dev`/main; do not mark E-02 CLOSED.** [Operation-by-operation implementation/evidence register](../../M1-secure-platform-foundation/02-development-process/M1_API_HANDLER_IMPLEMENTATION_STATUS_2026-10-31.md). Added GET listFamilies/getChild/listChildDevices, POST createChild/recordCapabilities and DELETE revokeDevice, hardened issuePairingCode and corrected health Receipt, plus negative tests and static route-coverage assertion. The [api SHA `0831367` M1 CI](https://github.com/methakon/Madalasa-Alarka/actions/runs/41143455623) **PASSED all three jobs**, including the 14-route ctest assertion. Runtime V2 trusted sessions, positive exact-child access and cross-family tests are still required. **V2 trusted session issuance, authority/guardian tests, end-to-end HTTP–PostgreSQL role/isolation, revokeDevice's extra VIEW scope and P-1 owner acceptance remain OPEN.** 171 broader/Figma-planned operations are NOT M1 implementation.

## Admin P0/P1 backend workstream — 2026-10-31

Source on `api` **not merged to dev**. [Status/evidence](../../M1-secure-platform-foundation/02-development-process/ADMIN_WEB_UI_AND_API_INTEGRATION_STATUS_2026-10-31.md#admin-authenticationaccess-api-implementation--2026-10-31-synthetic). Google admin OIDC verified-claims helper, revocable admin cookie self-status, applicant own profile/request and MFA-gated owner pending queue are implemented and negative-tested. [CI baseline](https://github.com/methakon/Madalasa-Alarka/actions/runs/41177258392) PASSED for auth/applicant code before subsequent owner queue revision change. **Trusted nonce challenge, issuer-only minting, actual admin login, CSRF, owner MFA flow, owner approval mutations and positive V2 integration remain OPEN.** Worker A01/A02 independent testing requested, results not yet received. No public admin access or child data.

**FAQ read checkpoint (2026-10-31):** public published FAQ listing plus authenticated admin draft/list/detail handlers coded on `api`. [Evidence and remaining write gates](../../M1-secure-platform-foundation/02-development-process/ADMIN_WEB_UI_AND_API_INTEGRATION_STATUS_2026-10-31.md#faq-read-integration-checkpoint--2026-10-31). Publishing/CSRF/MFA HTTP integration is still OPEN; worker A03 tests requested, results not received.

## B. Engineering blockers — resolved by building and testing, not by guessing

| ID | Priority | Work and reason it blocks completion | Evidence required | Responsible role |
|---|---|---|---|---|
| **E-01** | Critical | Family/child/guardian grants, server authorization + RLS | Cross-family API, worker, cache and live-stream negative tests | Backend/security |
| **E-02** | Critical | **14/14 M1 handler routes registered; V2 parent session bridge MERGED TO MAIN (accfe14); full role integration PARTIAL** | V2 parent session bridge merged in accfe14; complete cross-tenant and guardian revocation HTTP/DB integration, full response contract, correct revoke scope | Backend |
| **E-03** | Critical | Durable GPS idempotence, partition dedup, per-device worker fences | Crash/duplicate/offline/late replay passes | C++/DB |
| **E-04** | Critical | Revocation and deletion spanning raw/derived data, backups and offline devices | Restore and no-reingest proofs | Backend/privacy |
| **E-05** | High | **Android client scaffolding and shared UI library MERGED TO MAIN (accfe14); device runtime permissions and FGS lifecycle pending** | Scaffolding complete with 18 unit tests; device API/OEM instrumentation evidence for background services | Android |
| **E-06** | High | Stop/arrival/route quality thresholds and confidence | Labeled journey precision and recall tests | Geo/QA |
| **E-07** | High | Real battery and sampling behavior (phone, tablet, watch) | Comparative controlled-device measurements | Mobile QA |
| **E-08** | High | Drogon/Postgres scaling, backup recovery and failure handling | 1k/10k/100k synthetic tests plus recovery exercise | SRE |
| **E-09** | Critical | **Parent OIDC to V2 server-controlled session bridge MERGED TO MAIN (accfe14); per-device secure keys and key rotation pending** | V2 opaque session exchange and revocation verified with test_parent_session_bridge.py; device key rotation pending | Security |
| **E-10** | High | Actual parent/child AAB, API 36 standard Play target and native 16KB support | Signed builds + device installation checks | Android release |
| **E-11** | High | SOS/command receipts, expiration, fallback and priority | Offline, replay, revoked guardian tests | Backend/QA |
| **E-12** | Medium | Parent map paging, named-place optimistic edits, uncertain state UX | Multi-guardian and stale-state UI tests | Parent UI |
| **E-13** | Medium | Play Billing and optional Drive/provider integrations | Sandbox payment and OAuth revocation results | Integrations |
| **E-14** | High | End-to-end FR-to-test traceability and CI evidence | All release-scope requirements traceable to passing tests | QA/architect |

## X-02 Google Play G01/G04 review progress — 2026-10-31

**Official-policy desktop review documented:** [X-02 product-specific Families/monitoring/background-location pack](../../M9-play-release/01-play-and-data-safety/X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md). **G01 OPEN** pending human outcome in owner-created support case; Play Console AI answer **not approval**; do not change existing ticket or send duplicate inquiries. **G04 NOT SUBMITTED and NOT APPROVED** until G01 resolution and real AAB/disclosure/short video/reviewer evidence. Both are external release gates; synthetic C++/Android/API implementation and review preparation continue. No paid paperwork can substitute for Play decision.

## C. Compliance and external prerequisites (X-03 is **not** a compulsory external approval)

| ID | Blocker | What must happen | Who can unblock |
|---|---|---|---|
| **X-01** | **Publisher identity CLOSED; payment verification IN PROGRESS** | **X-01A CLOSED:** developer identity completed per owner. **X-01B:** BillDesk/payment verification submitted, response awaited. **X-01C:** separately verify any needed Google Payments merchant activation, account/target-app/package availability, app signing and upload setup. Never treat BillDesk submission as merchant approval. | Owner / BillDesk or actual payments provider / Google Play |
| **X-02** | **G01 Families location eligibility + G04 background location separate reviews OPEN; documentation prepared** | **First** obtain actual Alarka audience/precise-location eligibility determination from Google Play in already-open support case; **then** if eligible submit one-core-feature background-location declaration with signed build, prominent consent, public HTML privacy, real Android video and reviewer access. Monitoring `isMonitoringTool` designation does not waive Families location ban. T-X02-01…10 planned/unexecuted. [X-02 policy pack](../../M9-play-release/01-play-and-data-safety/X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md) | Owner / Google Play; engineering and release prepare evidence |
| **X-03** | **India child-data lawfulness assessment IN PROGRESS; optional advice requested via Tele-Law (registered) and MeitY (email sent)** | Document feature-specific applicable law and safeguards; optionally incorporate substantive counsel email/advice. A paid signed legal opinion or general government permit is **NOT a prescribed blanket requirement**. Do not launch legally unresolved child-data features. | Project owner accountable for legal compliance; optional qualified India lawyer / guidance bodies |
| **X-04** | Public privacy and account deletion URLs | Functioning pages matching real data operations | Product/backend |
| **X-05** | Optional Google Roads asset-tracking terms | Written provider license/caching/attribution review | Legal/Maps provider |
| **X-06** | Cloud/SDK subprocessors | Region choices and processor contract/data safety evaluation | Operations/legal |
| **X-07** | Play testing gate | Determine whether your developer account requires closed testing and complete it | You / release |
| **X-08** | Physical Android/OEM/watch devices | Obtain test fleet or representative access | You / QA |

## D. Documentation versus implementation states

This documentation refresh can remediate **design gaps** AG-001/002/003/006/007/008/009/012/013/017/020/025 in writing, but cannot mark their implementation or verification complete. Every E- item stays open until tested; X- items need appropriate outside evidence. Do not equate a document with an APK, an app test, a legal review or Play permission approval.

## E. Recommended next actions for you

1. Owner decisions B-01/B-02/B-03/B-04 and founding pricing are recorded, not awaiting the same answers again. Remaining decisions/evidence: **B-05 provisioning, B-06, B-07, B-09/B-18, B-10/B-11, B-12 and final per-feature release selection**. B-08 hosting remains a deployment decision, not a synthetic engineering blocker.
2. Approve role sharing **B-09 and B-18** before multi-guardian data tables are implemented.
3. Identify available real phones/watches, developer account status and desired launch region; the design can proceed using synthetic data while answers are pending.
4. Keep **remote hidden capture, protected private-file access, and Android security bypass** excluded.

Related: [Feasibility](../02-market-and-feasibility/WHOLE_PROJECT_FEASIBILITY_GATE_2026.md) · [Audit](TECHNICAL_DOCUMENT_AUDIT_GAPS_2026.md) · [SRS](../../M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md).

## F. Historical architecture direction — superseded by owner decision 2026-10-30

The project owner has supplied these additional instructions. They update the **design direction** but do not certify platform capabilities or legal compliance:

| Blocker | New information | Decision status | What remains open |
|---|---|---|---|
| **B-05** | Earlier proposal for optional fully managed child DPC path | **SUPERSEDED 2026-10-30:** first release is STANDARD only; Device Owner provisioning deferred. Read-only state detection may be included. | Any future managed-device edition needs a fresh owner decision and Android-compliant provisioning proof |
| **B-10** | A mix of older and newer Android versions must be supported | **PARTIALLY DECIDED:** implement API-aware Android compatibility path, proposed minSdk 29 | Exact supported Android versions/OEM models, test fleet and capability pass evidence |
| **B-19** | Parent interface is a **native Android app** | **DECIDED:** Kotlin/Jetpack Compose native client, no web parent client in M1 | None for architecture choice; production UI remains to be coded |
| **B-03** | Transparent, permission-based monitoring is prioritized | **DIRECTION DECIDED:** identifiable child app and system monitoring notification are nonnegotiable | Exact localized disclosure, jurisdiction/consent and Play Console approval |

The implementation plan and acceptance tests are now specified in [M1 Android/C++ Architecture and Implementation](../../M1-secure-platform-foundation/01-requirements-and-architecture/M1_ANDROID_CPP_ARCHITECTURE_AND_IMPLEMENTATION.md). This is a design status update only. Device-owner provisioning and supported Android behavior remain engineering verification tasks.

## G. Oracle Chicago hosting selection and finance decision — 2026-10-25

The owner has selected **Oracle OCI US Midwest Chicago (us-chicago-1)** as the design/home-region target, prioritizing Always Free allowances and later PAYG scaling. Detailed deployment/cost assumptions are documented in [OCI Chicago Deployment and Financial Plan](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md).

| Existing ID | Updated decision status | Remaining blockage |
|---|---|---|
| **B-08** | **PARTIALLY DECIDED:** cloud provider Oracle, planned region Chicago | OCI account creation, real A1 capacity, US child-data hosting legality, hosting budget, backups |
| **B-21** | Cost model added for 100–10,000 children with one subscription per child | Expected actual enrollment, maximum monthly spend, staff/support/HA budget |
| **B-14** | Per-child subscription billing unit established by owner | Actual monthly price, Play fees/taxes/trial/refund policy; ₹149 is example only |
| **E-08** | Chicago hardware/load topology designed | Actual CPU/DB/queue synthetic load evidence absent |
| **X-03** | US database region made explicit | Jurisdiction, minor privacy, cross-border transfer/legal consent assessment |
| **X-08** | OCI resource selected on paper | Live VM and capacity not verified; OS/OEM test fleet still needed |

**Do not mark B-08 fully closed:** Oracle home-region selection is materially difficult to change after tenancy creation, capacity is not publicly guaranteed, and OCI requires an authorized account holder to create resources. No tenancy, instance, domain or payment method was accessed or changed by this documentation step.

**Subscription pricing direction changed on 2026-10-26:** Proposed ₹50/month or ₹500/year per child, **not** ₹149/month. See [Subscription Plans and Fees](../../M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md) for SUB-01–SUB-16 approvals and unresolved tax/Play/family-seat checkout constraints. This specifically updates product direction for B-14; **pricing is not yet activated in Play Console**.

## H. Cumulative OCI paid-hosting cost decisions (2026-10-26)

The [deployment financial document §14](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md#14-cumulative-recurring-hosting-cost-beyond-free-tier--monthly-annual-and-scaling-sensitivity) now includes **priced monthly and annual hosting totals**, explicit boot/block and Object Storage usage, a separate 20% uncertainty allowance, a discretionary hosting budget and 7 hypothetical workload/VM shapes. These **do not certify child capacity** or a managed/HA production architecture.

| ID | Owner action needed | Why it matters |
|---|---|---|
| **COST-01** | Verify Oracle PAYG 3,000 OCPU-hour / 18,000 GB-hour monthly allowance in actual Chicago tenancy | Determines whether ~4 OCPU/24 GB incurs compute charge |
| **COST-02** | Confirm successful A1 shape allocation, storage free quota and account billing mode | Published list prices do not mean your VM exists |
| **COST-03** | Decide acceptable maximum paid hosting **budget per month** and annual cash ceiling | Planning contingency is not a payable line item |
| **COST-04** | Select raw GPS/derived trip/audit retention | Determines DB, Object backups and restore cost |
| **COST-05** | Decide whether single-node low-cost pilot is acceptable or paid HA/SLA required | Full HA/managed DB and on-call are **unpriced** |
| **COST-06** | Verify cost in OCI Cost Estimator / actual invoices, tax and invoice currency | INR list price is an estimate, not a bill |
| **COST-07** | Validate load/backup capacity before linking number of children to VM | Child counts are scenario labels only |

This supplements B-07, B-08, B-12, B-14 and B-21; do not mark them closed until choices and evidence exist.

## I. 2026-10-26 critical India/M2/pilot decisions and evidence blockers

**Status rule:** Proposed defaults are NOT your answers. No real child data collection until India DPDP/legal and US hosting review. Current confirmed direction: India-first pricing and Chicago target; legal identity, country/age policy and specific purposes still unsigned.

| Prior ID / new gate | Exact decision or evidence requested **now** | Provisional architectural default | May proceed without answer? |
|---|---|---|---|
| **B-01 / LG-01** | Publisher legal name, entity type, registration/jurisdiction and public support/privacy contact | Anonymous placeholder; synthetic data | **No real child data** |
| **B-02 / LG-02** | Sign off India-only first launch, exact child ages within under-18 group, guardian authority and languages | India-only *proposal*, under-18 legal review; no global launch | **No real child data** |
| **B-07 / LG-05** | Approve raw GPS, history, usage, SOS, audit, auth, backups and deletion retention after lawyer review | Raw 14 days; history 90 days **DISABLED** pending purpose review; app usage **OFF**; backups candidate 30d; audit 365d legal candidate | Synthetic design only |
| **B-09/B-18 / LG-07** | Who may invite, approve, revoke and view each child, including disputes and pickup scope? | Verified family owner **only** can invite/revoke; per-child grants; history opt-in, pickup current only 45m candidate, no role inheritance | SQL can use defaults; cannot enable real access before approval |
| **OCI-06 / AUTH-01** | Parent login provider, India onboarding age/identity provider and account recovery | **Google Sign-In through Android Credential Manager and backend ID-token verification** as M1 *engineering candidate*, not adult/parent identity proof; no SMS initially | Synthetic pairing allowed |
| **TEAM-04 / HW-01** | Real device inventory: model, Android API/OEM, parent test phone, older phone, and one **owner-approved factory-resettable spare** | Emulator/synthetic only, standard mode first; managed-DPC proof blocked | **M1 physical acceptance cannot pass** |
| **B-21 / TEAM-01–07** | Named engineer(s), independent QA/security/legal, OCI operator, monthly cash budget and funded runway | No staffing or operating capacity presumed | No credible paid pilot estimate |
| **FR-044 / SOS-B01–07** | Decide best-effort check-in vs public emergency SOS; trusted contacts, fallback SMS/vendor/cost, independent dispatch failure path | Best-effort check-in **only**; public emergency SOS OFF | M2 prototype only |
| **OCI-12 / DR-B01–07** | Approve pilot/production RPO/RTO and paid standby, backup/restore drills, support rota | Dev synthetic 24h RPO/48h RTO **targets only**; no production claims | **No real pilot without proof** |
| **SUB-16 / TEAM-06** | Verify ₹50/₹500 final tax-inclusive checkout, Play fee, refunds, churn, support and staff break-even | Prices PROPOSED; ₹149 historic model | Pricing design only |

**Related actionable designs:** [India child privacy law](../03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md), [SOS fallback](../../M4-usage-health-sos/01-usage-health-and-sos/SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md), [OCI recovery](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_RECOVERY_AND_PILOT_READINESS.md), [Price break-even/staffing](../../M7-commercial-integrations/01-commercial-plans-and-costing/PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md).

**Answer format (any subset):** B-01 legal publisher identity; B-02 country and ages; B-07 proposed retention approved/edited; B-09/B-18 scope policy; OCI-06 login approved/changed; HW-01 devices safe for reset; B-21 team and monthly budget; SOS-B01 emergency vs check-in; DR-B01 pilot RPO/RTO and funding. Keep identity documents, passwords, child data, contact numbers and cloud keys OUT of public GitHub.

## J. Indian OCI preference and single M0–M9 / M1 validation execution (2026-10-26)

The owner has chosen **India-region preference** to avoid unnecessary primary OCI US location. **Preferred Mumbai ap-mumbai-1, alternative Hyderabad ap-hyderabad-1**; tenancy/home-region availability and price still require confirmation. **B-08 direction updated, not closed.** Chicago plan remains historical. See [India OCI region decision](../03-legal-and-privacy/INDIA_REGION_AND_M0_OWNER_DECISION_GATE.md).
Canonical milestones now [M0–M9](MASTER_MILESTONE_IMPLEMENTATION_AND_RELEASE_PLAN.md). M1-only [OpenAPI](../../../openapi-m1.yaml), [RLS migration](../../../../backend/persistence/migrations/0001_m1_identity.sql), [two-family negative test](../../../../backend/tests/m1_tenant_isolation.sql), [14 M1 test cases](../../../../backend/tests/M1_ACCEPTANCE_TEST_CASES.md) and [CI workflow](../../../../.github/workflows/m1-contract-and-tenant.yml) are committed. API structural validation is green; PostgreSQL actual execution, Kotlin/C++ code, hardware and Play/legal gates **are not** proven.

Owner answers still needed: legal publisher B-01; exact Indian children ages and guardian proof B-02; raw/location/history/audit/backup retention B-07; who can invite/revoke guardians and scope B-09/B-18; final login vendor/adult-verification plan OCI-06; actual test-device inventory/resettable handset HW-01; team size and monthly budget B-21. No secrets, identity scans or real child records in public GitHub.

## K. New government/Google Play release gate — 2026-10-26

See [MA-COMPLIANCE-001 Government/Legal/Play Risk Assessment](../03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md).

| ID | Status | Owner decision / evidence |
|---|---|---|
| **G01 / R01** | **CRITICAL OPEN** | Verify Alarka exact Google Play audience and get product-specific Google Play interpretation of Families ban on precise location collection by solely child-targeted apps vs parental monitoring policy. Never falsely label age. **No child GPS release** before this. |
| **G02 / R02** | **CRITICAL OPEN — legal substance, not lawyer paperwork** | Record a feature-by-feature legal assessment of commercial child-safety real-time location versus history, usage, behavioural inference and verified guardian authority with primary-law citations. Qualified counsel review is advisable for uncertain/high-risk features, not universally mandated. |
| **G03 / R12/R17** | **HIGH OPEN** | Decide data category retention plus CERT-In 6h incident reporting/180d India logs and prospective DPDP year logs/breach notice. |
| **G04 / R05/R19** | **HIGH OPEN** | Two accurate Play App Content/target audience/manifest/monitoring disclosure, privacy and Data Safety submissions with final package evidence. |
| **G05 / R22** | **HIGH OPEN** | Build/API 36, 16KB native ABI, Android permissions and device-owner physical acceptance, no fake success. |

These **add to**, and do not close, B-01 legal publisher, B-02 exact launch ages, B-07 retention, B-09/B-18 guardian grants, OCI-06 verifiable identity, HW-01 resettable phones, B-21 staffing/budget, SOS and disaster recovery blockers.

## B-16 clarification — owner accepted media R&D and reason-specific parent UX (2026-10-26)

**Owner decision:** CONDITIONAL media research is **accepted** for one-way live audio, optional authorized recording, remote live camera, front/rear photo snapshots, flash-off where possible, authorized video, per-session-consented screen view and permitted MediaStore/SAF files. Do not interpret "defer media" in B-16 as owner rejection of proof-of-concept work. **B-16 commercial release / Play inclusion remains OPEN and default OFF.** Standard installation and actual device-owner DPC mode must be tested separately. Alarka main Activity is normally closed after setup, but monitoring notification and OS sensor indicator remain visible.

**Product requirement:** Madalasa reports verified `Command.status + reason_code` and safe next action when a media/file request is unavailable, specifically Android background start blocked, permission revoked, user notification/system consent required, true managed enrollment required, unavailable hardware, phone offline, expired request, or network trouble. Unknown/offline must never be misdiagnosed as missing permission. Android MediaProjection must obtain system approval for each session.

**Still open:** legal publisher/guardian authority, India child-data purpose and Play/Families classification, managed-device real proof, physical OS/OEM test fleet, active session consent/retention, device encryption/key management, optional parent-local recordings, India OCI region relay bills/concurrency and funded security audits. [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md).

## I. 2026-10-27 permission onboarding design accepted; implementation/release blockers still open

**Owner DECIDED design:** First-launch Alarka reads public hardware/OS compatibility; after trusted pairing it uploads a versioned device-authenticated report to backend, then offers a stepped Android OS grant wizard with clear "why", in-app post-grant verification, server durable ACK and Madalasa child-scoped feature list with positive permission confirmations. Later Android Settings revocation/reapproval is rechecked on next eligible app execution and sent with new revision. Distinguish user-facing **permission-granted green** from actual **operational-ready green**; no false live-media claim, and offline/stale cannot be diagnosed as permission revoked.

**Engineering blockers OPEN:** device scan allowlist/metadata minimization, manifest and target-SDK review, Android API29–36/OEM behavior (one-time permission, OS process kill, Usage Access, selected photos, scoped SAF, separate background location), genuinely managed-owner proof, Keystore device/replay, backend transaction/version model, parent VIEW_DEVICE_STATUS access, event/FCM drop resilience, complete T-CAP-01…24 evidence. **External blockers OPEN:** legal guardian verification, publisher/country/ages, India child-data purpose/legal counsel, Play background-location/Families/monitoring eligibility. M1 API stays narrow until separately approved contract migration. Owner decision does not unblock protected child processing. [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md).

## J. 2026-10-27 owner design decision on media logs and new admin console

**Decided design:** Keep **no VPS media files**, but store bounded authenticated media-operation metadata (child and actor IDs, audio/image/video+audio/screen type, attempt/status, verified duration and local-saved size if any, viewed vs saved, true OS/network failure reasons) with parent child-name selector, date-range filtering and pagination; build a new administrator panel with parent name/ID autocomplete, child name/ID autocomplete (parent constrained), date/type/outcome/reason filters and pagination. Confirmed camera-busy is loggable; unverified 'on a call' attribution is not. See [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md) and [Admin Console Specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md).

**Unresolved gates:** exact India child-data legal basis, allowed media release scopes, role authority for named child logs, case approval/sign-off, admin MFA and audit-store independence, mandatory retention duration, deletion/backup/legal hold, budget and security testing. **No general operator/root universal named-child visibility**, even though appropriately authorized administrators can access scoped logs. Admin read/write audit failure must prevent sensitive detail reads. All T-AUD-01–22 and T-ADM-01–14 remain NOT_IMPLEMENTED/NOT_TESTED. Existing M0/G01/G02 legal/Play and FR-009/010 P3 blockers still open.

## K. 2026-10-27 accepted implementation design: separate capture/upload, Postgres inbox and bulk insert

**Owner decision (accepted as design, not code):** 1–2 minute authenticated JSON batch upload target for independently captured adaptive GPS; encrypted Alarka 48-hour **offline capacity** (not 48-hour guaranteed active GPS if Android off); PostgreSQL durable server inbox **one row per device upload batch**; C++ workers claim via bounded SKIP LOCKED/fenced leases; combine observations into **bulk INSERT** (multirow / optional COPY into temp staging) and atomically commit event dedup + raw time-partitioned GPS + route outbox + inbox PROCESSED. Drogon sends 202 QUEUED only after **inbox COMMIT**; device local cleanup only for durably ACKed records. Redis is **not selected** as an ingest requirement. Keep a direct raw bulk+dedup+outbox commit as mandatory resource/WAL comparison; inbox may consume MORE total DB I/O while helping burst isolation.

**Still OPEN:** target Android/OEM/Wear 48h buffer, local encryption, 1–2 minute upload permissions/FGS, mixed source identity, phone storage and overflow policy, old consent/permitted data collection, worker crash recovery/fencing, 1k/10k/100k 48h reconnect storm benchmarks, SQL migration/retention/deletion, exact transport precision/version choice, OCI Mumbai resource sizing and Play/India minors tracking/usage legality. T-ING-01…24 ALL NOT_TESTED. Canonical [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md).

## L. 2026-10-27 recommended resolutions and M1 credential decisions

Concrete recommended answers for the open owner and legal items, with the questions to put to counsel and Google Play: [Owner and legal recommended resolutions](../../../OWNER_AND_LEGAL_RECOMMENDED_RESOLUTIONS_2026-10-27.md). **Proposals only; none of B-01, B-02, B-07, B-09/B-18, OCI-06, HW-01, B-21, SOS, DR or G01–G05 is closed by them.**
Engineering decisions C-01 to C-06 (credential lifetime, rate limits, no per-request signing, first credential, cleanup, no key rotation in M1): [M1 device credential lifecycle](../../../M1_DEVICE_CREDENTIAL_LIFECYCLE.md). Migration 0003 also removes PUBLIC execute from every `ap_m1` function.


## 2026-10-30 G01 / G04 Google Play Console AI guidance — non-binding clarification

The owner received an AI-generated response in the Play Console support flow. It stated that the parental-monitoring policy does **not** override the Families restriction on precise location for apps solely targeting children. It suggested a mixed-audience model only where the app genuinely serves that audience; audience declarations must never be manipulated to bypass policy. It also stated that **background location is not automatically permitted and requires a separate location-permissions declaration/review**.

This AI response is not a human policy-team determination, app review decision or permission approval.

| Gate | Updated position | Evidence still required |
|---|---|---|
| **G01 / R01** | **CRITICAL OPEN.** Families precise-location eligibility for Alarka's actual child-facing architecture remains unconfirmed. Do not infer an exception from the monitoring-tool flag or parent authorization. | Human written Google Play policy response addressing truthful audience, child users and precise location; preserve case ID and complete response. |
| **G04 / R07** | **HIGH OPEN / separate approval gate.** Background location is not automatically permitted. A runtime permission grant or monitoring declaration is not Play approval. | Submit the Play Console location-permissions declaration; provide core-feature rationale, prominent in-app disclosure, runtime permission flow, demonstration video, accurate listing and public privacy policy; obtain required Play review approval before release. |

**Owner/project instruction:** keep real-child GPS collection disabled until G01 is resolved and all applicable legal/Play gates are satisfied. Treat background-location approval separately from G01. Keep the target-audience declaration truthful; do not add older age groups solely to bypass Families policy. Synthetic-data engineering and non-production OS tests may continue. A human support response is still pending; the AI answer alone closes neither gate.

## 2026-10-30 G02 — Indian DPDP child-location legal interpretation and commencement timing

**Primary-text timing correction:** The commencement notifications schedule DPDP Act section 9 (sections 7–10) and DPDP Rules 2025 Rule 12 (within Rules 3, 5–16) to commence eighteen months after Gazette publication on 13 November 2025. The calendar computation is **13 May 2027**. Accordingly, on 30 October 2026 these provisions are scheduled but **not yet in force** under G.S.R. 843(E) and G.S.R. 846(E). Counsel must confirm the operative date, corrigenda and any later notifications before launch. This timing does not remove the need to assess other laws, Google Play policy, Android OS limits or future compliance readiness.

**Substantive G02 question:** Once operative, section 9(3) generally prohibits tracking/behavioural monitoring of children; section 9(4) allows prescribed purposes subject to conditions. Rule 12 / Fourth Schedule Part B item 4 specifies determination of a child's real-time location, restricted to real-time tracking in the child's safety/protection or security interest, as a purpose for which section 9(1) and 9(3) do not apply. This is a narrow purpose-specific provision, not a blanket approval for historical route reconstruction, school/stop profiling, geofences, app usage, behavioural analytics, media capture, broad guardian sharing or indefinite retention. Section 9(2)'s detrimental-effect prohibition remains a separate issue.

**G02 remains CRITICAL OPEN for feature legality, not for purchasing an opinion.** Document a cited, reviewable Indian-law assessment (independent specialist consultation recommended for uncertain/high-risk activities but not a mandatory signed-paper condition) addressing:
- whether this commercial parent/guardian service qualifies for the real-time child-safety location purpose;
- whether it permits only on-demand current location or also periodic/background collection;
- permissible precision, cadence, offline device queue, PostgreSQL inbox, derived data, history, retention and guardian access;
- separate treatment of app usage/behavioural monitoring, geofences, SOS, media and admin access;
- section 9(2), guardian authority/consent, child notice, revocation and custody disputes;
- commencement dates, transitional/corrigendum position, other applicable Indian laws, subprocessors and cross-border processing.

Required output: feature-by-feature GREEN / CONDITIONAL / PROHIBITED / UNRESOLVED classification with lawful purpose, primary-law citations, controls, retention, evidence and accountable owner sign-off. A qualified lawyer's substantive email can support this record, and a signed PDF/printed opinion is optional unless a specific requirement is demonstrated. Until the particular feature's lawful basis and controls are documented and independently required Play/Android gates pass, real-minor ingestion and unapproved tracking/usage remain OFF; synthetic engineering may continue. A G02 self-assessment is not a government clearance. The India DPDP child privacy issue brief remains the design reference.