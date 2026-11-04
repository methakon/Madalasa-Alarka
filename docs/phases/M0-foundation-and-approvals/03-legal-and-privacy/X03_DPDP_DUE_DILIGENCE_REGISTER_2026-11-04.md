# X03 — India DPDP Act 2023 Due-Diligence Register (Madalasa–Alarka)

> **Control:** X-03 / G02 · **Document state:** PUBLISHED DRAFT, REVIEW PENDING — DUE DILIGENCE IN PROGRESS · **Legal status:** `NOT LAW-CERTIFIED` · **Authority:** NONE. No advocate's opinion, regulator acknowledgement, government permit, Google Play decision or data-protection approval exists or is implied.
>
> **This document is not legal advice.** It is an engineering-and-governance register that collects, cites and classifies what the repository already records about India's Digital Personal Data Protection Act, 2023 and the DPDP Rules, 2025. It must not be represented to anyone — a guardian, a reviewer, a court, a regulator, or a payment provider — as legal clearance. A project self-assessment is explicitly **not** government or counsel approval.
>
> **Provenance:** composed read-only from `origin/main` @ `b4b4c898fe4edc5acfee6dc2d12a2e8772d87bbb` and `origin/api` @ `1bb3afc7d03a26f8f61be4031dab8b159e009a2d`. No tracked file was created, edited, staged or committed; no branch, merge, checkout or state-changing git command was run.
>
> **Binding project rule repeated here:** no real minor's personal data — location, usage, media, identity — in any build, test, fixture or deployment until a documented, dated, feature-specific lawful basis an auditor could check exists. Synthetic fixtures and owner-operated adult-device lab testing may continue. (D2 `docs/roadmap/LEGAL_PENDING.md` §"Binding rule")

---

## 0. How to read this register — the three-way split

Every entry carries exactly one of three tags:

| Tag | Meaning | What a reviewer may do with it |
|---|---|---|
| **`[S]` SOURCED** | The statement is a faithful restatement of a specific repo document + section. It is verified as *present in the repo*, not verified as *correct law*. | Quote it with the citation. Do not upgrade it to legal clearance. |
| **`[U]` UNVERIFIED / NEEDS LEGAL REVIEW** | The underlying legal question is unresolved, contested, feature-dependent, or expressly reserved to counsel. | Treat as fail-closed: the feature stays off or conditional. |
| **`[O]` OWNER ACTION** | A decision or external step only the owner (or owner-appointed counsel) can take. | Route to the owner; never self-answer. |

**None of the three tags is an approval.** Sections 3–8 are the register; §9–§11 restate the split in list form so nothing ambiguous survives summarisation.

**Citation keys** (full repo paths, `origin/main`):

| Key | Repository path | Sections used |
|---|---|---|
| **D1** | `docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md` | "Enactment is not commencement"; "Children, consent and exceptions"; "Existing IT framework and CERT-In"; "Retention, rights, processors and release questions"; §1; §2 table; §3; §4; §5; §6 LG-01…LG-08; §8; "2026-10-31 first-party primary-law review" §A–§E |
| **D2** | `docs/roadmap/LEGAL_PENDING.md` | "Binding rule"; "Pending legal registrations"; "No-real-data-pilot gate" |
| **D3** | `docs/roadmap/PRE_RELEASE_VERSIONING_AND_CHILD_DATA_REVIEW_POLICY_2026-11-02.md` | §2; §4 required acceptance evidence; §5 owner-device testing; §6 private lab mode; §7 privacy/guardian/retention spec pointer |
| **D4** | `docs/phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md` | §A B-02/B-07/B-09/B-18/B-16; §C X-03/X-04/X-06; "2026-10-31 correction: X-03 is legal due diligence"; "2026-10-30 G02"; "2026-10-31 X-03 consultation progress" |
| **D5** | `docs/roadmap/DECISION_LEDGER.md` | §A C-02/C-13; §B B-07/B-09/B-18/B-16; §C X-03; §E stale passages |
| **D6** | `docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md` | "Current legal reconciliation"; "Retention principles"; "Category decision ledger"; "Rights, erasure and restore requirements"; R-01…R-18 review |
| **D7** | `docs/phases/M9-play-release/01-play-and-data-safety/DATA_SAFETY_WORKSHEET.md` | DS01–DS18; "Mandatory answer worksheet"; "Prepare-now, implementation and owner gates" |
| **D8** | `docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/PRIVACY_CONTROLS_V0_TECHNICAL_AND_UI_SPEC_2026-11-02.md` | §1 runtime/purpose/category registry; §2 DB contract; §3 API contract; §4 Android UI; §5 negative tests |
| **D9** | `docs/roadmap/FREE_FIRST_108_CHILD_RELEASE_ROADMAP_2026-11-03.md` | "Decision"; "Child app is fully free"; "Capacity decision"; "Server-side enforcement"; "Security and deletion regression correction"; "New prioritized delivery checkpoints" |
| **D10** | `docs/phases/M9-play-release/01-play-and-data-safety/X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md` | §1; §5 T-X02-09 |

Cross-references inside quoted repo passages to statutory instruments (G.S.R. 843(E), 846(E), 892(E), CERT-In directions, IndiaCode/MeitY text) are reproduced **from those repo passages only**. This register performed **no independent legal retrieval** and claims none; where a repo document itself records a retrieval failure (for example the SPDI full-text timeout in D1), that limitation is carried forward rather than papered over.

---

## 1. Scope, roles and current posture

| Item | Statement | Tag | Citation |
|---|---|---|---|
| Product | Madalasa (guardian Android), Alarka (child companion Android), C++ Drogon backend, PostgreSQL/PostGIS, separate admin web | S | D8 §1 |
| Launch geography | India-only initial launch (owner decision); final production hosting region reserved for deployment | S | D4 §A B-02; D1 §8 |
| Data subjects | Guardians (adults) and children aged 0–17 inclusive | S | D4 §A B-02; D2 "Pending legal registrations" |
| Fiduciary identity | Owner-declared accountable publisher/controller: **individual, India**; formal controller/processor mapping **not finalized**; no company, GST, address, email or grievance officer inferred | S (+U on legal effect) | D1 "Current source-grounded review"; D2 "Pending legal registrations" |
| Paid legal opinion | **Not a universal statutory prerequisite**; optional supporting evidence; signed PDF not mandated | S | D1 §A; D4 "2026-10-31 correction"; D5 §E |
| Real-child processing | **OFF / NO-GO** for location, usage, media and identity until feature-specific lawfulness and separate Play/Android gates pass | S | D1 §6 LG-01…LG-08; D2 "No-real-data-pilot gate"; D9 "Decision" |
| Permitted testing | Owner-operated physical devices, consenting adults, real GPS/network and dev APIs; device ownership is **not** authority to monitor another person | S | D3 §5, §6 |
| Instrument status | The DPDP Act is **partially** in force; describing it as "nothing applies" or "all provisions apply" is wrong in both directions | S | D1 "Enactment is not commencement"; D1 §B |
| This register's own status | `DOCUMENTED_REVIEW_PENDING` — a self-assessment, not clearance | S | D4 §"2026-10-31 correction"; D5 header |

`[O]` **Owner action:** appoint the accountable owner/controller mapping and the privacy/grievance contact before any public notice is published. No name, address or email may be invented in the meantime.

---

## 2. Commencement — what is in force, and the reserved one-day question

| Phase | Provisions | Effect for this product | Tag | Citation |
|---|---|---|---|---|
| On Gazette publication, **13 Nov 2025** (G.S.R. 843(E) para (a)) | Act s.1(2), s.2, ss.18–26, 35, 38–43, s.44(1),(3) | Definitions and institutional provisions already commenced | S | D1 "Enactment is not commencement" table |
| **+1 year** (para (b)) | Act s.6(9), s.27(1)(d); Rules 4 | Consent-Manager registration — **not** automatically applicable to an app obtaining consent for its own users | S | D1 §B phase table |
| **+18 months** (para (c)), including Rules G.S.R. 846(E) rule 1 | Act ss.3–5, 6(1)–(8),(10), **7–17 including s.9**, remaining s.27, 28–34, 36–37, s.44(2); Rules 3, 5–16 **including Rule 12**, 22–23 | Core processing, children's s.9, rights, transfers, IT Act amendments — **scheduled, not operative** at the time of the repo review (30–31 Oct 2026) | S | D1 "Enactment is not commencement"; D1 §B; D4 "2026-10-30 G02" |
| Calendar planning alternatives | From the **13 Nov 2025** printed date: **13 Nov 2026 / 13 May 2027**. From the **14 Nov** digital publication identifiers: **14 Nov 2026 / 14 May 2027** | "Treat these as planning alternatives, not two statutory commencement dates" | S | D1 "Effective-date interpretation reserved" |
| Corrigendum | G.S.R. 892(E) dated **10 Dec 2025** (Gazette issue 11 Dec, digital publication 12 Dec) corrects rule 1(3)/(4) wording and specified schedule text; it does **not** remove the phases | Must be reflected, not ignored | S | D1 "Enactment is not commencement" table |
| Explanatory guidance | PIB explainer dated 17 Nov 2025 describes "full operationalisation" | Official guidance is **not** a substitute for the Gazette's express phase clauses | S | D1 "Official guidance, not commencement law" |
| Current-law backdrop | IT Act 2000, SPDI Rules 2011, CERT-In 28 Apr 2022 directions **remain** applicable during phased commencement; s.44(2) omission of s.43A/87(2)(ob) is itself future-phase | No regulatory vacuum may be assumed | S | D1 "Existing IT framework and CERT-In"; D1 §B |

**`[U]` Unresolved:** which commencement date is operative must be settled by counsel against the Gazette evidence, the corrigendum and any later notification **at release**. No one-day assumption may be used to enable child processing. ([D1 "Effective-date interpretation reserved"])

**`[U]` Also unresolved:** whether any obligation applies to this product *before* full commencement, given the IT Act/SPDI/CERT-In backdrop and the commercial (non-domestic) use of the backend. ([D1 §4 bullet 1])

---

## 3. Data-category register

Each row records: why the data exists, the *repo-stated* lawful-basis posture, the children's-provision interaction, the retention position (all numbers remain candidates unless a row says otherwise), and the rights/deletion treatment. **No row is approved.**

| ID | Data category (repo registry code) | Purpose | Lawful basis / s.9 posture as recorded | Children's provisions | Retention | Rights / deletion | Tag | Citation |
|---|---|---|---|---|---|---|---|---|
| R1 | Guardian adult identity: name/email/OIDC subject (`GUARDIAN_ACCOUNT`; DS01) | Sign-in, recovery, child invitation, account management | Consent/contract-style processing of an adult's own data; **Google OIDC login verifies an account only — not adulthood, not guardianship, not custody** | Indirectly determines who may consent for the child | "Account life"; deletion after verified closure, exceptions reviewed (R-01 candidate: +30 days after closure) | Account deletion in-app **and** via a working web URL | S + U | D7 DS01; D8 §1; D1 §C; D6 R-01 |
| R2 | Child alias / child ID / grant links (`CHILD_PROFILE`; DS02) | Select the exact authorized child; invite/revoke; seat assignment | Child personal data — s.9(1) verifiable parental consent, except where a notified purpose exception applies | **Core child-data category**; exact-child scope, no sibling inheritance | Until removal + 30 days (R-02 candidate); revoke grants and reject delayed uploads before row deletion | Erase/revoke/dispute tests; no implicit siblings | S + U | D7 DS02; D8 §1; D6 R-02 |
| R3 | Device credential / installation ID / push token (`ENROLLMENT_CREDENTIAL`; DS03) | Device binding, security, delivery | Security-necessary processing; no raw device key in logs | Device belongs to the child; credential is child-linked | Token rotation; delete/unpair; SDK data audit (TTL TBD) | Unpair wipes device credentials; server revocation tracked separately | S + U | D7 DS03; D9 "Child app is fully free" |
| R4 | Capability/permission metadata (`CAPABILITY_EVENT`; DS04) | Compatibility, honest permission state, support | Minimized technical metadata; no capture during the scan | Child device fingerprinting risk → minimize identifiers | Latest snapshot + bounded change history (candidate 90 days) | Acknowledge/report revision; delete with child | S + U | D7 DS04; D6 "Category decision ledger" |
| R5 | Precise/approximate **live, on-demand** location (`GPS_OBSERVATION`; DS05) | Guardian's real-time child-safety visibility | **Potentially** within Rule 12 / Fourth Schedule Part B item 4, which exempts *only* s.9(1) and s.9(3) for determining a child's **real-time location** in the interest of **safety and protection or security**. Eligibility of a **commercial** parent-tracking app is **not settled**; consent is not the basis for waiving s.9(3) | s.9(2) detrimental-effect prohibition **is not exempted**; s.9(3) tracking restriction only partially displaced by that narrow purpose | Raw GPS 14 d (earlier drafts) **vs** 30 d (uploaded draft) — **conflict unresolved**; measured from `observed_at` | Deny/revoke; purpose-level withdrawal; deletion applies to every copy incl. offline queue | S + **U** | D1 "Children, consent and exceptions"; D1 §C; D1 §2 table; D6 R-03 |
| R6 | **Continuous / background** location, 48 h offline device queue, server inbox | Availability while Alarka is not in use | Extent of incidental buffering inside a "real-time" purpose is **not specified**; ongoing collection risks becoming *history*, outside the exception | Unresolved; §9(3) risk grows with persistence | 48 h queue is a **device capacity target, not a retention policy**; inbox pending/leased bounds TBD | Tombstone/generation fence before deletion so 48 h retries cannot revive deleted data | **U** | D1 §D (continuous/background row); D6 "Retention principles"; D9 "Server-side enforcement" |
| R7 | Historical GPS, trips, stops, named places, geofences, commute inference (`TRIP_DERIVATIVE`) | Parent-visible history | **Not expressly included** in the narrow real-time exception; profiling risk under future s.9(3); purpose-limited deletion under s.8 | High risk: can reveal home/school patterns | 90 d candidate, **unapproved**; derived details may require *shorter* | Erase derived data with raw; backup restore must not resurrect | **U** | D1 §2 table row 3; D1 §D; D6 R-04/R-04a |
| R8 | App usage / behavioural monitoring (`USAGE_EVENT`) | Screen-time and app reports (not in the free-first release) | **Not named** by the real-time-location purpose; potentially prohibited behavioural monitoring; parental permission alone insufficient | **Highest-risk category**; feature OFF | 30 d candidate, unapproved; feature OFF | Purpose-level withdrawal; Usage Access revoke | **U** | D1 §2 table row 4; D1 §D; D6 R-05 |
| R9 | Child-initiated SOS / check-in (`SOS_EVENT`; DS10) | Safety escalation | Safety purpose plausible but **not** a blanket exception from collection/retention/guardian duties | Conditional; minimize event fields; preserve fallback | Command/SOS lifecycle candidate 12 months | Delivery vs acknowledgement distinction; deletes with child | S + U | D1 §2 table row 6; D6 R-07 |
| R10 | Camera / microphone / screen capture and media files | Not shipped | **No authorization** derived from Part B item 4; bystander and protected-financial-content risk | `CONDITIONAL / OFF`; must not be activated to demo | **Zero** — no data captured until independently approved | N/A until approved | **U** | D1 §D; D4 §A B-16; D9 "Decision" |
| R11 | Media *activity metadata* (who viewed/saved what, when, duration) | Audit of media operations | Distinct sensitive purpose requiring its own children's analysis and guardian authority; admin access not justified by infrastructure ownership | Yes — child-linked even with zero media files stored | 12 months candidate; no VPS media binaries | Restricted, case-based, audited admin reads; failure to audit blocks sensitive reads | S + U | D1 "2026-10-27 children's media-activity metadata"; D6 R-08 |
| R12 | Diagnostics, crash, health/battery/connectivity (`SUPPORT_TICKET` subset; DS09/DS16) | Support and queue health | Minimization; redaction; no raw sensor payload in crash paths | Yes — child-linked telemetry | "Remove unique child identifiers where possible"; 7–30 d candidates | Deletes with child; SDK network test required | S + U | D7 DS09/DS16; D6 "Category decision ledger" |
| R13 | Security / consent / authority / trial-abuse ledger (`SECURITY_AUDIT`) | Prove consent and authority; prevent abuse | Legal-necessity review; no Aadhaar/IMEI/child routes for eligibility | Yes | Evidentiary purpose, period TBD; audit candidate 365 d | Narrow legal exception; no permanent erased-identity matching | S + U | D7 DS17; D6 "Category decision ledger"; D5 §A C-13 |
| R14 | Billing / purchase / invoice (`BILLING_RECORD`; DS14) | **Absent from the free-first release**; needed only for a later paid release | Prepaid manual only; no auto-renew; payment never grants guardian scope or Android permission | Child entitlement projection only; no child payment capture | Statutory retention **not determined** (draft "6–8 years" rejected); accountant/counsel must identify each statute | Refund/stop-top-up routes separate | S + U | D9 "Decision"; D7 DS14; D6 R-09 |
| R15 | Admin case/search/access logs (`SECURITY_AUDIT`) | Accountable administrator access | Administrator access is not inherently justified by ownership; requires MFA, case purpose, child scope | Yes — indirect child linkage | 24 months candidate, restricted and independent | Audited denied attempts; redacted aggregate support by default | S + U | D1 "2026-10-27 children's media-activity metadata"; D6 "Category decision ledger" |
| R16 | ICT / authentication security logs | Incident investigation | CERT-In 28 Apr 2022 directions: report **Annexure I incidents within 6 hours**, keep ICT logs **rolling 180 days within Indian jurisdiction** (covered entities) | Logs may contain child identifiers → minimize | 180 days in India where applicable; separate overseas-copy inventory | Not a licence to retain raw child GPS/media 180 days | S + U | D1 "Existing IT framework and CERT-In"; D6 "Retention principles" |
| R17 | Encrypted backups / PITR | Recovery | Purpose limitation still applies; restore must honour deletions | Yes | 35 days candidate; **not verified** against RPO/RTO or erasure rights | Restore tombstone; deletion ledger re-applied before reopening APIs | S + U | D6 "Category decision ledger"; D6 "Rights, erasure and restore requirements" |
| R18 | Deletion tombstones / erasure records (`DELETION_TOMBSTONE`) | Prevent resurrection; free an admission slot | Minimum record of the fact of deletion, **no raw payload** | Yes | Tombstone kept until erasure is stable; period TBD | Insert on verified child erasure; **must never be blocked** by slot/admission state | S + U | D8 §2; D9 "Security and deletion regression correction" |
| R19 | Support / grievance / incident records | Legal and service necessity | Minimized separate legal need with scoped holds and review dates | Yes where child-linked | TBD | Scoped holds; closure-based expiry | S + U | D6 "Category decision ledger" |
| R20 | Anonymous aggregates | Product metrics | Only if demonstrably irreversible anonymity | Not child personal data **only if** genuinely irreversible | N/A | N/A | S + U | D6 "Category decision ledger" |

**Register-wide `[U]` note:** every retention number above is a *candidate*. The retention schedule is **DRAFT / NOT ADOPTED**, and "no retention or deletion job is authorized to execute on production from this draft". ([D6 header, closing line])

---

## 4. Lawful basis and the verifiable-guardian-consent model

### 4.1 The statutory shape as recorded

| Element | Repo-stated position | Tag | Citation |
|---|---|---|---|
| Child definition | Under 18 (s.2(f)); product scope 0–17 inclusive | S | D1 §C; D4 §A B-02 |
| s.9(1) | Verifiable parental consent (including lawful guardian where applicable) before processing, subject to applicable exemptions | S | D1 "Children, consent and exceptions" |
| s.9(2) | Processing likely to cause a **detrimental effect on the child's well-being** is prohibited — **not** waived by any location exception | S | D1 "Children, consent and exceptions"; D1 §C |
| s.9(3) | Restricts tracking / behavioural monitoring (and targeted advertising); **consent alone cannot waive it** | S | D1 "Children, consent and exceptions"; D1 §C |
| Rule 12 / Fourth Schedule Part B item 4 | Exempts **only s.9(1) and s.9(3)** for *determining a child's real-time location*, restricted to *safety and protection or security*. A **purpose** exception, not an individual licence, not a commercial-app clearance | S | D1 §C; D4 "2026-10-30 G02" |
| Rule 10 | Parental consent and identifiable **adult identity/age due diligence** where applicable | S | D1 "Children, consent and exceptions" |
| Rule 11 | Separate lawful-guardian rule for a person with disability | S | D1 "Children, consent and exceptions" |
| s.3(c)(i) domestic exclusion | An individual's personal/domestic processing does **not** automatically exempt the commercial backend because a family uses the app at home | S | D1 §C; D1 "Children, consent and exceptions" |
| s.10 | DPIA / independent audit / DPO duties attach to **notified Significant Data Fiduciaries**; the project's voluntary DPIA is **not** proof of designation | S | D1 "Retention, rights, processors and release questions" |
| s.6(9) Consent Manager registration | Applies to a regulated Consent Manager, **not** automatically to an app obtaining consent for its own users | S | D1 §A |

### 4.2 Control design that counsel must approve (design, not authority)

The repo specifies a multi-control model. It is a safety design **awaiting legal approval**, and explicitly **not** a claim that Rule 10 mandates any particular document upload (for example custody paperwork).

| # | Control | Purpose | Tag | Citation |
|---|---|---|---|---|
| 1 | Guardian starts from an identifiable Android app with clear age and monitoring disclosure in supported Indian languages; parent account login plus documented authority to supervise **each** child/device | Establish an accountable adult | S + U | D1 §3.1 |
| 2 | Purpose-specific notices **before** real-child collection: live location, history, app usage, sharing/temporary pickup access, SOS, optional wear/watch, third-party processors; sensitive purposes default **OFF** | Purpose limitation | S | D1 §3.2 |
| 3 | If relying on verifiable consent: a legally reviewed adult verification / identity-age proof (approved attributes or a regulated token); minimise identity-document storage and third-party transfer | Rule 10-shaped verification | S + U | D1 §3.3 |
| 4 | Versioned consent/authority **receipt**: guardian subject, child alias, verified-adult method reference, relationship attestation, purpose, document/version, timestamp, status, revocation — encrypted, scoped access, **no raw government-ID scans by default** | Provable authority | S | D1 §3.4 |
| 5 | Show currently authorized adults and each purpose to the child in age-appropriate terms; preserve the visible OS monitoring notification; provide user-friendly revocation/grievance routes | Child-facing transparency | S | D1 §3.5 |
| 6 | Dispute/custody handling: **freeze new sharing and potentially collection**, documented escalation, identity reassessment; a payment-holder is **not** automatically the lawful custodian | Dispute safety | S | D1 §3.6 |
| 7 | Withdrawal stops further relevant collection and sharing promptly; records/backup erasure follows approved policy while preservation duties are independently assessed | Withdrawal | S | D1 §3.7 |
| 8 | Test with fake identity and synthetic child data: forged/replayed consent, expired relationship, child transfer, two conflicting guardians, revoked parent, erased profile | Negative evidence | S | D1 §3.8; D8 §5 |
| 9 | Server-side purpose registry with `notice_version`, `purpose_version`, eligibility and authority status per child/device; conditional purposes default disabled; server never trusts client-supplied scope/tier/family | Enforcement | S | D8 §1 |
| 10 | Google Sign-In is **account authentication only**; **no Family Link dependency**; an accepted invitation is exact-child scoped, never automatic sibling or billing-family access | Identity vs authority separation | S | D4 §A; D5 §A C-03; D5 §E |

### 4.3 Where consent is genuinely unsettled

**`[U]`** Whether verifiable parental consent is even the correct basis for live child location (versus the Rule 12 purpose exception), and what **residual** obligations survive that exception, is a **feature-by-feature** legal determination. The repo requires it be documented with primary-law citations and treat unresolved features as excluded. ([D1 §3; D1 §4 "Decision output"; D4 "2026-10-31 correction"])

**`[U]`** Adult verification strength is unresolved: "proportional adult/guardian verification and custody disputes" is listed as an open written legal decision. ([D1 "Retention, rights, processors and release questions"])

`[O]` **Owner action:** approve the verification method and the relationship-evidence standard, or narrow the product to what can be verified. Do not deploy an unverified relationship claim.

---

## 5. Children's-data provisions — feature disposition

| Feature | What the recorded reading supports / does not settle | Disposition | Tag | Citation |
|---|---|---|---|---|
| On-demand real-time location for child safety | Potentially inside Fourth Schedule B(4) if necessity and strict safety purpose hold; commercial-service eligibility and system design still unreviewed | `CONDITIONAL` — **not cleared for real children** | S + U | D1 §D |
| Continuous/background/high-intensity GPS, 48 h device queue, server inbox | Incidental-buffering scope unspecified; may become history | `UNRESOLVED` — not enabled for unapproved real children | U | D1 §D |
| Stored historical GPS, routes, stops, school/geofence profiling; history gated behind a subscription | Not expressly inside the narrow real-time exception; s.9(3) tracking/profiling and s.8 purpose-limited deletion risk | `HIGH-RISK / OFF` pending separate affirmative basis; "indefinite until account closure" is not proved compliant by a possible upgrade | U | D1 §D |
| App usage / behavioural monitoring / screen-time | Not named by the real-time purpose; possibly prohibited behavioural monitoring | `HIGH-RISK / OFF`; parental permission alone insufficient | U | D1 §D |
| Child-initiated SOS / check-in | Safety purpose plausible; not a blanket exemption from collection/retention/guardian duties | `CONDITIONAL` — synthetic/engineering only | S + U | D1 §D |
| Remote mic, camera, photo, video, screen capture | No general authorization from B(4); third-party and protected-financial-content risk | `DEFERRED / OFF` for real children | U | D1 §D |
| Media activity metadata and administrative access | Child-linked event records are personal data even with no media files on the server | `RESEARCH ONLY`; bounded audit, scoped access | S + U | D1 "2026-10-27 …" |
| Guardian enrollment, authority, disputes, revocation | Adult Google login is not legal-parent verification; sharing and processing need proper authority and safety controls | `DESIGN/TEST with synthetic users`; real authority proof required before child onboarding | S + U | D1 §D |

**Consistency with the free-first release:** the free entitlement is live last-known location plus at most six hours of *visible* history; SOS and app-usage are separately compliance-gated and are **not** silently activated; no media, no payment. ([D9 "Decision"])

**Explicit prohibition carried from the repo:** a technical consent checkbox or an Android permission is **not** DPDP verifiable parental consent; conversely, a purpose-specific exception does **not** justify secret background capture, indefinite storage, or exposing a child's location to all relatives. ([D1 §2 closing paragraph])

---

## 6. Cross-border hosting and processors

| Item | Recorded position | Tag | Citation |
|---|---|---|---|
| Governing provision | s.16 read with Rule 15 (and stricter applicable Indian laws) requires a **separate transfer assessment**: current restrictions, contracts, notices, rights, retention, security and recipient/processor review | S | D1 §1 (s.16 row); D1 §4 |
| Current recommended deployment | India OCI preference (Mumbai preferred, Hyderabad alternative) — a **preference**, not a legal clearance; region/tenancy/bandwidth reserved for deployment | S | D1 §8; D5 §A C-01 |
| Historical contingency | US Midwest Chicago analysis retained as **contingency** for US processing/third-party transfer, **not** the recommended deployment; neither "illegal per se" nor "automatically permitted" may be asserted | S | D1 §1; D1 §4; D1 §8 |
| Processor roles | Google / OCI / Play vendors may be processor **or** independent controller per operation; an unsigned register is **not** a DPA; no India-only residency, no "all-Google-is-processor", no notified SDF status asserted | S | D1 "Retention, rights, processors and release questions" |
| Domestic hosting does not close the question | Google/Firebase/identity processors, support tooling, backup replication and any cross-border handling still need mapping even with India primary storage | S | D1 §8 |
| CERT-In log location | Rolling 180-day ICT logs in Indian jurisdiction for covered entities; overseas copies inventoried separately (FAQ Q35–Q37) | S | D1 "Existing IT framework and CERT-In" |
| Push/provider exposure | No raw child GPS or SOS text in generic logs/push payloads; FCM/provider reviewed as a disclosure | S | D1 §2 table last row; D7 DS03 |
| Blockers | B-08 (hosting/region) `DEFERRED_TO_DEPLOYMENT`; X-06 (cloud/SDK subprocessors) `OPEN / EXTERNAL` | S | D5 §B; D4 §C X-06 |

**`[U]`** Whether any transfer basis is sufficient for **child** location data, and which Indian restrictions apply at launch, is unresolved and depends on the deployment that has not been chosen. ([D1 §4 bullet 5])

`[O]` **Owner action:** select the deployment region/tenancy, then commission the processor/transfer mapping and DPAs (X-06). Public privacy text must not be finalised before that, or it will misdescribe actual processing.

---

## 7. Retention, rights, deletion and audit

### 7.1 Retention

| Item | Recorded position | Tag | Citation |
|---|---|---|---|
| Adopted policy | **None.** Schedule is DRAFT / NOT ADOPTED; every period is a candidate | S | D6 header |
| Six-hour free visibility | A **query/access window**, not a storage lifetime; conflating them is an explicit error | S | D5 §A C-02; D6 "Retention principles"; D9 "Decision" |
| Unresolved conflict | Raw GPS **14 d** (earlier drafts) vs **30 d** (uploaded draft) — owner/counsel must choose | U | D6 R-03 |
| Rule 6(1)(e) | One-year retention of specified security logs **and personal data** — scope must be reconciled with purpose limitation, withdrawal, s.8(7)/12 erasure | S + U | D1 "Retention, rights, processors and release questions"; D6 "Current legal reconciliation" |
| Rule 8(3) | Broader: personal data, associated traffic data and other processing logs at least one year for Seventh Schedule purposes; **must not** be reduced to a security-log-only rule | S + U | D1 same; D6 same |
| Rule 8(1)/Third Schedule | Class-specific inactivity periods, **not** a universal three-year permission | S | D1 same; D6 same |
| Clock origin | Measured from **original observation/event time**, not upload or batch acceptance | S | D6 "Retention principles" |
| Every copy | Must inventory subprocessor copies, cache, export, device offline queue, replication, log and backup expiry | S | D1 §5; D6 "Rights, erasure…" |
| Cost-model numbers | OCI "30-day raw GPS" is a **cost-only** assumption, not an approved retention policy | S | D1 §5 |

### 7.2 Data-principal rights (future-phase design obligations)

| Right / duty | Provision | Recorded requirement | Tag | Citation |
|---|---|---|---|---|
| Withdrawal of consent | s.6(4)–(6) | Reviewed plan for withdrawal; stops further collection/sharing promptly | S | D1 "Retention, rights…"; D1 §3.7 |
| Access / correction / erasure | ss.11–13, s.8(7) | Reviewed plan, published contact and grievance routes when commenced | S + U | D1 same |
| Grievance | Rule 14(3) | Published grievance period must **not exceed 90 days**; this is a cap, **not** a 90-day right to delay all complaints | S | D1 same |
| Notice / consent / security / processor / purpose limitation | ss.4–8 | Applies when operative; a real-time exception is **not** a consent-free basis for every associated category | S | D1 §C |
| Breach notification | Rule 7 | Affected-person and initial Board intimation **without delay**, then specified Board details within **72 hours** (or permitted extension) — **not** a blanket 72-hour wait | S | D1 "Retention, rights…" |
| CERT-In incident reporting | IT Act s.70B(6) directions | Annexure I incidents within **6 hours** of noticing; designated PoC; time sync; this is separate from and additional to Rule 7 | S | D1 "Existing IT framework and CERT-In" |
| IT Rules 2021 grievance timelines | Rules as updated 10 Feb 2026 | 24-hour acknowledgement / 7-day resolution, 36-hour subset, 2-hour intimate/impersonation complaints **if** the intermediary role applies; role applicability undeclared | S + U | D1 "Existing IT framework and CERT-In" |
| History visibility vs rights | — | Free six-hour window is a *visibility* control; it does not enlarge or restrict statutory rights | S | D8 §1 |
| Rights request handling | — | Request states must distinguish REQUESTED/VERIFYING/IN_PROGRESS/COMPLETED/PARTIAL_LEGAL_HOLD/FAILED; **no premature success** | S | D8 §3 |
| Deletion messaging | — | Confirmation must state what is gone versus lawfully held/backup-pending; never claim completion before verification | S | D8 §4 |

### 7.3 Deletion and audit integrity

| Requirement | Detail | Tag | Citation |
|---|---|---|---|
| Stop intake before erasing | Revoke ingestion and device credentials, then delete, so a 48 h offline retry cannot revive deleted child data | S | D6 "Retention principles"; D8 §1 |
| Generation fence | Tombstone/`minimum_generation` blocks stale uploads, replays, outbox and backup restores | S | D8 §1, §2 |
| Restore-safe deletion | Deletion ledger re-applied to **all** restored backups before APIs reopen | S | D6 "Rights, erasure…" |
| Deletion must never be blocked | Free-admission mechanisms must permit `enrollment_state='REVOKED'` even when the child is waitlisted/deactivated/deleted; slot logic may not block right-to-delete | S | D9 "Security and deletion regression correction" |
| Honour-system caveat | Parent-local and Google Drive copies cannot be erased instantly from inaccessible devices; this must be disclosed, not glossed | S | D6 "Rights, erasure…" |
| No sibling-wide effects | A co-parent invite must not trigger sibling-wide deletion or access | S | D6 "Rights, erasure…" |
| Audit separation | Child-scoped audit, restricted admin reads, redacted support defaults; note that `privacy_data_category_policies` uses a NULL retention duration to mean **unresolved/disabled**, never "infinite" | S | D1 "2026-10-27 …"; D8 §2 |
| Negative tests required | Unrelated family/child, expired grant, admin raw-location attempt, FREE six-hour cutoff, tier spoof, replayed privacy request, revoke-vs-stream race, stale upload after tombstone, deleted data in cache/outbox/backups | S (planned) | D8 §5; D9 "Merge and test policy" regression list |

**`[U]`** No deletion or retention job is authorized to run in production from the draft schedule, and no advertised processing deadline may be published until the service exists and counsel has reviewed it. ([D6 closing line; D6 "Rights, erasure…"])

---

## 8. Governance controls already recorded in the repo

| ID | Control | Status | Tag | Citation |
|---|---|---|---|---|
| LG-01 | Legal publisher identity verified → otherwise **block real child data** | Publisher identity owner-confirmed at Play level; legal identity mapping pending | S | D1 §6 |
| LG-02 | India initial launch + defined under-18 ages/custodial relationship formally approved → otherwise **block** | Ages decided; lawful treatment open | S | D1 §6; D4 §A B-02 |
| LG-03 | India lawyer memo for all planned purposes → otherwise **block** | Modified by the 2026-10-31 correction: feature-specific documented assessment required; paid signed opinion optional | S | D1 §6; D4 "2026-10-31 correction" |
| LG-04 | Deployment/processor regions, transfers, agreements reviewed | Deferred to deployment | S | D1 §6 |
| LG-05 | Retention/backup and delete/restore tests | Not run | S | D1 §6 |
| LG-06 | Parental verification + notice + consent/exception per purpose **in code**, backend denies missing authority | Design only | S | D1 §6; D8 §1 |
| LG-07 | Child-specific guardian scope/roles approved; disputes and revocation tested | Open (B-09/B-18) | S | D1 §6; D5 §B |
| LG-08 | Play + Android monitoring disclosures and provider policies complete → otherwise **block public release** | Open (see X02 pack) | S | D1 §6; D10 §1 |
| Feature gates | `default_when_flag_absent = DENY`; enabling requires `enabled == true` **and** every gate CLEARED with recorded evidence; a flag alone grants nothing | Enforced default | S | `config/feature-gates.example.json` (resolution_rules) |
| Evidence standard | A verifiable approval means a documented, dated, feature-specific lawful basis an auditor could check — not an assumption, not a product preference, not passing local tests | Binding | S | D2 "No-real-data-pilot gate" |
| Test-data rule | Owner-operated devices allowed; another adult must understand and agree; device ownership ≠ authority to monitor another person; no personal GPS logs/credentials/media in public repos | Binding | S | D3 §5, §6 |

---

## 9. `[S]` Sourced from repo docs — statements safe to quote with citation

1. The DPDP Act is **partially** in force; s.9 and Rule 12 are scheduled to commence 18 months after Gazette publication, with **13 vs 14 November 2025** producing 13/14 May 2027 as *planning alternatives*. — D1
2. A child is under 18; s.9(1) requires verifiable parental consent, s.9(2) prohibits processing likely to cause a detrimental effect, s.9(3) restricts tracking/behavioural monitoring and targeted advertising. — D1
3. Rule 12 / Fourth Schedule Part B item 4 exempts **only s.9(1) and s.9(3)**, **only** for determining a child's real-time location **only** in the interest of safety and protection or security; it does not exempt s.9(2) and is not an individual licence. — D1
4. Stored history, geofences, app usage, predictions and media are **not** covered by that narrow purpose and remain OFF/conditional for real children. — D1 §D
5. Google Sign-In authenticates an account only; it is not proof of adulthood, guardianship or custody, and there is **no Family Link dependency**. — D1; D4; D5
6. A paid/signed advocate opinion is **not** a universal statutory prerequisite; the project's own cited, feature-specific assessment is the required artefact, and unresolved doubt is a feature-release NO-GO. — D1 §A, §E; D4
7. The domestic/personal-use exclusion (s.3(c)(i)) does not automatically exempt the publisher's commercial backend. — D1
8. CERT-In requires 6-hour incident reporting and rolling 180-day ICT logs in Indian jurisdiction for covered entities; this does not license retaining raw child GPS/media for 180 days. — D1
9. Rule 7 requires intimation **without delay**, then Board details within 72 hours; Rule 14(3)'s grievance period must not exceed 90 days. — D1
10. Retention numbers (raw GPS 14 vs 30 days, trips 90 days, usage 30 days, backups 35 days, audit 365 days) are **candidates**, and the schedule is NOT ADOPTED. — D6
11. Six-hour free history is a **visibility** window, not a retention authorization. — D5 §A C-02; D9
12. No real minors' data in any build, test, fixture or deployment until a documented, dated, feature-specific lawful basis exists; no real-family pilot, even opt-in, even internal. — D2
13. Safety design (exact-child grants, purpose registry, versioned consent receipts, generation fences, restore-safe deletion) is **design awaiting approval**, not a legal claim that Rule 10 mandates any specific upload. — D1 §3; D8 §1
14. Free-first release: live last-known location, ≤6 hours visible history, no trial/paid history/media/payment; 108 admitted child profiles is a deployment cap, not eligibility. — D9

## 10. `[U]` Unverified / needs legal review — fail-closed until resolved

1. **Publication/effective date**: whether 13 or 14 November 2025 is the legal trigger, the corrigendum's effect, and any later notification. — D1
2. **Commercial classification**: whether the publisher's individual status, sole-proprietorship exposure under IT Act s.43A (indexed text), SPDI applicability and/or intermediary role apply; SPDI full-text retrieval was **not** completed in-repo. — D1
3. **s.9 exemption scope by feature**: does a consumer parent-tracking service qualify for Fourth Schedule Part B(4); does it permit only on-demand current location or also periodic/background collection; permissible precision, cadence, offline queue, inbox, derived data, history. — D1; D4
4. **Residual s.9(2) duty**: whether any planned feature risks a detrimental effect on well-being, independent of consent or the location exception. — D1
5. **Proportional adult/guardian verification and custody disputes**: standard of proof, document handling, conflict freeze. — D1; D2
6. **Retention and holds**: Rule 6(1)(e)/Rule 8(3) one-year scope versus purpose limitation, withdrawal, erasure and lawful holds; 14 vs 30-day raw GPS; derivative and backup periods; advertised deletion deadlines. — D1; D6
7. **Transfers**: s.16/Rule 15 basis for child location and child-linked metadata under the eventual deployment; processor vs controller roles for Google/OCI/Play/Firebase; government-access and sectoral restrictions. — D1
8. **Rights and incident operations**: applicable grievance/incident duties and contacts, interaction between Rule 7 and CERT-In 6-hour reporting, and the IT Rules 2021 timelines if the intermediary role applies. — D1
9. **Public notices**: privacy notice, terms, Data Safety answers, Play monitoring declaration and child-facing transparency text — none are lawful notices yet (drafts only). — D1 §4; D7
10. **Other-law sweep**: consumer, child-protection, employment and sectoral obligations; accessibility; any state-level requirements. — D1 "Research caveat"
11. **Trial-abuse vs minimisation (C-13)**: privacy-respecting anti-repeat method is OPEN. — D5 §A C-13
12. **Whether documentation alone ever suffices**: this register asserts that it does **not**; only a documented, dated, auditor-checkable basis plus the separate Play/Android gates can support a release decision, and even then no regulator approval exists. — D1 §E; D2

## 11. `[O]` Owner action register

| # | Action | Why it is owner-only | Blocking breadth | Source |
|---|---|---|---|---|
| O1 | Nominate the accountable controller/legal owner and publishable privacy + grievance contact | Requires accepting legal responsibility; contact details must be real, never invented | Public notices, Play listing, privacy URL | D2; D4 §C X-04 |
| O2 | Settle publication/effective date and any later amendments with counsel | Legal determination, not an engineering choice | Any real-child processing | D1 |
| O3 | Record the feature-by-feature lawful-purpose determination (GREEN / CONDITIONAL / PROHIBITED / UNRESOLVED) with primary-law citations and an accountable sign-off | Accountable governance decision | Each sensitive feature | D1 §4 "Decision output"; D4 |
| O4 | Choose retention per category (raw GPS 14 vs 30 days, trips, usage, backups, audit) or keep the category disabled | Business + legal trade-off; affects cost and product claims | Deletion jobs, data safety answers, privacy text | D6; D5 §A C-02 |
| O5 | Approve guardian add/revoke scope, TTL and history visibility (B-09/B-18) | Authority/role policy | Multi-guardian tables and sharing UI | D5 §B; D4 §A |
| O6 | Approve the adult/guardian verification method, or narrow the product to what can be verified | Identity policy with real user impact | Child onboarding | D1 §3.3 |
| O7 | Select deployment region/tenancy and commission processor/transfer review (B-08, X-06) | Contractual and jurisdictional | Public privacy text, cross-border note | D1 §8; D4 §C |
| O8 | Decide whether genuine paid-service processing is pursued at all before commencement, and how pre-commencement conduct is documented | Product/legal strategy | Paid release only | D1 §4 bullet 1; D9 |
| O9 | File/keep the optional counsel or guidance-body responses (Tele-Law registered, MeitY email sent — owner-reported, responses pending) as private evidence | Owner holds the correspondence | Does not block synthetic engineering | D4 "2026-10-31 X-03 consultation progress" |
| O10 | Authorise any real-child pilot or Play submission | Release authority | Everything | D2; D10 §1 |
| O11 | Keep case/verification identifiers, ID documents and correspondence **out of Git** | Privacy/security | — | D4 |

---

## 12. Bottom line for a reviewer

- The repo contains a genuinely careful, primary-source-cited desk assessment. It is **not** legal advice, **not** an advocate's opinion, and **not** regulator or Google Play approval.
- Every sensitive child feature (background location, history, usage/behavioural, geofences, media, SOS-to-production) is **OFF or CONDITIONAL** in the project's own documents. The register above adds no permission.
- Two things are simultaneously true and must not be collapsed: the DPDP children's provisions are **scheduled rather than fully operative**, **and** current IT Act/SPDI/CERT-In duties plus Google Play and Android constraints apply **now**. "Not yet commenced" is not a licence; "commenced" is not a permit.
- The three lists in §9, §10 and §11 are the operational split: quote §9 with citations, refuse to answer §10 without counsel, route §11 to the owner.
- Retention remains undecided, the controller/grievance contact remains unappointed, and the deployment region remains unselected. Until those three move, no privacy notice may be published as final, and no real child's data may be processed.
