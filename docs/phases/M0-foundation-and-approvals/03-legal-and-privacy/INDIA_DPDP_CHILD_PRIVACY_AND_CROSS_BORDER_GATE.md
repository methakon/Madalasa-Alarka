# Madalasa–Alarka — India Child Privacy, Consent and Cross-Border Legal Gate

> **Document control:** M0 / 03-legal-and-privacy · Proposed owner: Privacy counsel + owner (not assigned) · Registry: DRAFT_LEGAL_REVIEW_REQUIRED; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (guardian/parent), **Alarka** (child companion). GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka), renamed 2026-10-26. [Source story and naming contract](../02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Status:** ENGINEERING/LEGAL ISSUE BRIEF — NOT LEGAL ADVICE OR APPROVAL  
**Reviewed:** 2026-10-30 IST | **Applies to:** India-only initial launch, children ages 0–17, parent/guardian app; final production region reserved, historical Chicago scenario not selected infrastructure
**Release decision, corrected 2026-10-31:** No *unassessed* real-child data processing: lawful feature scope, guardian authority, privacy/security controls and separate Android/Google Play gates must pass. **A paid/signed counsel opinion is not a universal legal prerequisite.** Synthetic fixtures only until feature eligibility is evidenced.

## Current source-grounded review — 2026-10-30

**Owner declaration, not verification:** **Individual SWARNA SEKHAR DHAR, India**, same intended legal/Google Play publisher. **Payments identity pending; merchant setup pending; public support confirmation pending; legal review pending.** No company, GST status, address, email, named lawyer or grievance appointment is inferred. **Real child-data release OFF / NO-GO**, including real-child enrollment/authority evidence; this review authorizes no upload, credential handling, provisioning or pilot.

### Enactment is not commencement

The DPDP Act received assent on **11 August 2023**; section 1(2) delegates commencement by notification and allows different dates for different provisions. It is incorrect either to treat assent as full commencement or to call the entire Act unenforced in October 2026.[1][2]

| Instrument / phase | Verified provision-level position as of this review |
|---|---|
| G.S.R. 843(E), dated 13 November 2025, paragraph (a) | On Gazette publication: section 1(2), section 2, sections 18–26, 35, 38–43 and section 44(1), (3). Institutional/definition provisions are already commenced.[2] |
| Same notification, paragraph (b) | One year from publication: section 6(9) and section 27(1)(d), concerning Consent Managers; not yet due on 30 October 2026.[2] |
| Same notification, paragraph (c) | Eighteen months from publication: sections 3–5, 6(1)–(8), (10), 7–17, remaining section 27, sections 28–34, 36–37 and **44(2)**. This includes core processing, children's section 9, rights, transfers and the IT Act amendments; not yet due on this review date.[2] |
| G.S.R. 846(E), rule 1 | Rules 1, 2, 17–21 on publication; rule 4 after one year; rules 3, 5–16, 22–23 after eighteen months. Thus Rules 6–12 and 14–15 are future-phase duties, not all currently operative.[3] |
| G.S.R. 892(E), corrigenda | Dated **10 December 2025**, Gazette issue **11 December**, digital publication identifier/signature **12 December**. It corrects English commencement wording in rule 1(3)/(4) from “of this Gazette” to “in the Official Gazette”, plus specified textual/schedule corrections; it does not remove the phases.[4] |

**Effective-date interpretation reserved:** the instruments are dated 13 November 2025, but carry 14 November digital publication identifiers/signatures. The legal trigger is **publication**, not the notification's drafting date or a portal summary. Calendar arithmetic from 13 November gives **13 November 2026 / 13 May 2027**; from 14 November gives **14 November 2026 / 14 May 2027**. Treat these as planning alternatives, not two statutory commencement dates. Counsel must settle the publication evidence, corrigenda and any subsequent notifications at release; no one-day assumption enables child processing. Official explanatory/press guidance does not override the notified text.[2][3][4]

**Official guidance, not commencement law:** the PIB explainer dated **17 November 2025** says the Rules were notified on 14 November and describes “full operationalisation”. That explanatory description is not a substitute for the Gazette's express one-year/eighteen-month clauses and cannot establish that section 9 or every Rule already applied in October 2026.[10][2][3]

### Children, consent and exceptions — law versus product interpretation

- **Enacted future-phase law:** a child is under 18; section 9(1) requires verifiable parental consent (including lawful guardian where applicable), section 9(2) prohibits processing likely to cause detrimental effect on the child's well-being, and section 9(3) restricts tracking/behavioural monitoring and targeted advertising. Consent alone is not an exemption from section 9(3).[1][2]
- **Notified future-phase exception:** Rule 12/Fourth Schedule Part B item 4 exempts **section 9(1) and (3)** for determination of a child's real-time location, **restricted to tracking that real-time location in the interest of safety and protection or security**. It is a purpose exception, not an automatic commercial-app approval, and does not exempt section 9(2) or every general obligation. Part A's institution/healthcare/transport classes cannot be borrowed merely by describing this consumer app as educational or protective.[1][3]
- **Legal interpretation needed:** exact eligibility of live location, frequency/precision, necessary transient storage, geofences, historical routes/stops, app usage, DPC controls, predictions, media and metadata must each be assessed. Neither consent nor that exception is treated here as blanket authorization. Section 17 exemptions, including any notified startup-class relaxation, are not presumed simply because the publisher is an individual or early-stage project.[1][3]
- **Verification rule:** Rule 10 addresses parental consent and identifiable adult identity/age due diligence; Rule 11 is the separate lawful-guardian rule for a person with disability. Adult verification, actual authority for an exact child, Android permission and an invitation acceptance are different controls. The project's anti-abuse/custody safeguards are safety design awaiting legal approval, not a claim that Rule 10 mandates a particular custody-document upload.[3]
- **Owner policy:** Google Sign-In is account authentication only, not proof of adult age or parent/guardian relationship; **no Family Link dependency**. An accepted invitation is exact-child scoped, with approved authority/consent where required, never automatic sibling or billing-family access. Domestic/personal-use exclusion in section 3(c)(i) must not be assumed to exempt the publisher's commercial backend just because a parent uses the app at home.[1]

### Existing IT framework and CERT-In — no regulatory vacuum

**Current-law transition:** DPDP section 44(2) provides for omitting IT Act section 43A and section 87(2)(ob), but is itself in the eighteen-month phase. Do not describe those amendments or retirement of the SPDI framework as already completed on 30 October 2026.[1][2] IndiaCode's indexed section 43A text expressly includes a **sole proprietorship** within “body corporate”; being an individual publisher is not by itself an exemption from commercial data-security duties.[8]

The **SPDI Rules 2011**, G.S.R. 313(E), distinguish personal information from listed sensitive data (including passwords, financial, health and biometric information); ordinary GPS is not expressly listed as a standalone SPDI category. Rule 4 privacy notices and rules 5–6 consent, lawful necessity, purpose and disclosure requirements must be assessed against actual data and commercial roles; “not SPDI” does not mean child-location processing is unrestricted.[9] **Retrieval limitation:** section 43A and the official Gazette replica were available here as indexed official text/excerpts, but direct IndiaCode/SPDI downloads timed out and the old MeitY PDF path returned 404. Full-text SPDI review, rules 5(4)/(7)/(9), 7–8, transfer standards, grievance deadline, security audit and transition/savings analysis remain **counsel verification required**, not certified findings of this review.

The IT Rules **2021 as updated on 10 February 2026** govern intermediaries; applicability depends on the actual section 2(1)(w) intermediary function, not simply operating an Android app. The official consolidated text's rule 3(2) specifies **24-hour acknowledgement / seven-day resolution**, a **36-hour** subset of removal complaints, and **two-hour** action on specified intimate/impersonation-content complaints; older fifteen-day/72-hour/24-hour content-removal summaries are stale for this version. Counsel must confirm the applicable role, effective amendments, scope and exceptions, including any later instruments; a consultation draft is not enacted law.[7] These routes are distinct from future DPDP grievance handling and any applicable SPDI duties.

CERT-In's **28 April 2022 directions**, issued under IT Act section 70B(6), require covered service providers/intermediaries/data centres/body corporate/government organisations to report **Annexure I incidents within six hours of noticing or being informed**, designate a point of contact, maintain suitable time synchronisation, and securely retain ICT logs for a **rolling 180 days within Indian jurisdiction**. The five-year subscriber-record provision is for the specified data-centre/VPS/cloud/VPN provider classes, not automatically every app using a VPS.[5] The **May 2022 FAQ** is official interpretive guidance, not an amendment: Q35 permits overseas logs also subject to production, Q36 addresses India-service logs/financial records in Indian jurisdiction, and Q37 describes sector-dependent system logs. Conservative project design keeps the required India log copy and separately inventories overseas copies; this is not a mandate to retain raw child GPS/media for 180 days.[6]

### Retention, rights, processors and release questions

Future-phase **Rule 6(1)(e)** refers to one-year retention of the specified security logs and personal data; **Rule 8(3)** is broader and expressly refers to personal data, associated traffic data and other processing logs for at least one year for Seventh Schedule purposes. Do **not** recast Rule 8(3) as applying only to security logs, nor adopt all GPS/history candidate TTLs without resolving its scope against purpose limitation, withdrawal, erasure and statutory holds. Rule 8(1)/Third Schedule's class-specific inactivity periods are not a universal three-year retention permission.[3] The [retention schedule](DATA_RETENTION_SCHEDULE.md) remains unadopted: no automatic 14/30-day GPS or 30/35-day backup decision and no unconditional immediate-erasure promise.

Sections 6(4)–(6), 8(7), 11–13 and Rules 3, 9, 14 require a reviewed plan for withdrawal, access/correction/erasure, contact and grievance routes when commenced; Rule 14(3)'s published grievance period must not exceed **ninety days**, not a universal current ninety-day right to delay all complaints. Rule 7 requires affected-person and initial Board intimation **without delay**, followed by specified Board details within **72 hours** (or permitted extension), not a blanket 72-hour wait; it does not replace CERT-In's current six-hour incident rule.[1][3][5]

Section 8(1)–(2) retains the fiduciary's responsibility and requires a valid contract for engaging a processor; section 16/Rule 15 and stricter applicable Indian laws require actual recipient/transfer assessment. Google/OCI/Play vendors may have different processor/independent roles per operation; an unsigned register is not a DPA. No India-only residency, all-Google-is-processor or notified Significant Data Fiduciary status is asserted. Section 10 DPIA/audit duties attach to **notified Significant Data Fiduciaries**; this project's voluntary DPIA is not proof of designation.[1][3]

**Open written legal decisions before any real-child release:** publication/effective date and later amendments; individual commercial/SPDI/intermediary classification; section 9 exemption scope by feature; proportional adult/guardian verification and custody disputes; lawful retained categories and deletion/restore holds under Rules 6/8; applicable grievance/incident duties and contacts; processor contracts, transfers and actual regions; public privacy/support notices. Payments/merchant/account verification and public support evidence remain separate owner gates. No counsel approval or implementation test is inferred from documentation.

## 1. Official legal instruments and exact time status

**Historical 2026-10-26 baseline:** the current 2026-10-30 review above takes precedence, including publication-date interpretation and corrigendum.

- Digital Personal Data Protection Act, 2023, section 9: special processing of children's personal data, verifiable parental consent before processing, restriction on tracking/behavioural monitoring and targeted advertising, subject to narrow regulations and exemptions; child means person under 18 per Act definitions.
- November **13, 2025** Gazette G.S.R. **843(E)**: sections 3–5, 6(1–8,10), **7–10**, **11–17**, among others commence **18 months after Gazette publication**. That computes to **approximately 13 May 2027** using the printed Gazette date, but a counsel must confirm official date/corrigenda and changes. Other provisions commenced immediately or after 1 year, so don't describe the entire Act as uniformly unenforced now.
- November **13, 2025** Gazette G.S.R. **846(E)**, rule 1: rules 3, 5–16, 22 and 23 (including **rules 10/12**) commence 18 months after Gazette publication; initial and other rule blocks follow different phases. Source government publication/web portals sometimes label the gazette 14 November; resolve any one-day official effective-date issue before launch.
- Rule **10**: where applicable, adult parent verification and verifiable consent are more than checking an app permission or relying solely on a child's assertion.
- Rule **12** / Fourth Schedule, Part B item 4: purpose-specific exception from **section 9(1) and (3)** for determination of a child's **real-time location** restricted to such tracking in the interest of the child's **safety and protection or security**. It does not dispense with all data obligations, nor is it proof that any commercial parent monitoring service qualifies.
- Section **16**, read with rule **15** and other Indian/sectoral laws: India-to-US processing requires a separate transfer assessment, current restrictions check, contracts, notices, data subject rights, retention, security and US recipient/processors review. Do **not** assert Chicago is illegal per se or automatically permitted.
- Other Indian laws, Play monitoring policy, Android permission constraints and rules for guardianship remain independent controls even prior to DPDP child-rule commencement.

**Authoritative primary documents:**  
G.S.R. 843(E): https://www.meity.gov.in/static/uploads/2025/11/c56ceae6c383460ca69577428d36828b.pdf  
G.S.R. 846(E): https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf  
MeitY Act/Rules library: https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa?pageTitle=Digital-Personal-Data-Protection-Rules-2025

## 2. Do not apply the real-time-safety exception indiscriminately

| Data product / feature | Candidate DPDP interpretation issue | Safe implementation default until written counsel advice |
|---|---|---|
| Parent-requested **current device location** solely for immediate child safety | May be within limited Rule 12 Fourth Schedule Part B purpose; qualification of consumer service requires review | **Disabled for real minors** pending verified authority and lawyer approval; use synthetic data |
| Continuous periodic location collection for later analysis | Not identical to real-time determination; necessity/proportionality, surveillance and retention issues | **OFF** for minors until separate purpose-by-purpose review |
| Stored raw GPS 14–30 days, reconstructed trip and school stop history for 90 days | Historical reconstruction and profiling may fall outside real-time exception | **OFF** for real minors pending lawful basis and proportionate retention approval |
| App-usage history, per-app time, app-blocking schedules and screen-time profiling | Potential **behavioural monitoring**; not safely covered by real-time location exception | **DISABLED** for minors pending dedicated Indian legal opinion; no broad category collection in pilot |
| Geofences, route corridor deviations and prediction | Depends on feature purpose, inference/profiling, false alarms and children tracking rules | **OFF** for pilot unless specifically approved |
| SOS initiated by child / emergency check-in | Emergency safety purpose; guardian receipts and history are still personal data | Prototype only with synthetic/test adults or counsel-approved guardian participants, explicit disclosures and fallback |
| Identifiable child account, enrolled device and parent authorization records | Account creation and access evidence may contain child data | Require separately approved minimal fields and parental authority validation |
| Pickup guardian invitations, access history and location exports | Disclosure to additional adult is not automatically lawful | Owner authority, recipient verification, scope, expiry, revocation and access trail; no links without authorization |
| Google Maps, Drive, FCM, SMS vendors, analytics | Independent disclosure to processors, subcontractor purpose & cross-border risk | Data minimization, provider review and no raw child GPS/SOS text in generic logs/push |

**A technical consent checkbox or Android permission is not equivalent to DPDP verifiable parental consent.** Conversely, the existence of a purpose-specific statutory exception does not justify secret background data capture, indefinite storage, or exposing child GPS to all relatives.

## 3. Verifiable parent/legal guardian design that counsel must approve

1. Guardian starts from identifiable Android application with clear age and monitoring disclosure in supported Indian languages. Require parent account login, initial verification and documented authority to supervise each child/device.
2. Before real child data collection: display purpose-specific notices for live location, history, app usage, share/temporary pickup access, SOS, optional wear/watch and third-party processors. Default **OFF** where no reviewed lawful basis/exemption exists.
3. If relying on verifiable consent, choose a legally reviewed adult verification/identity-age proof approach: e.g. approved identity attributes or regulated virtual token. Minimize identity document storage and third-party transfer. A Gmail sign-in proves an account, **not automatically adult/guardian authority**.
4. Maintain versioned consent/authority receipt (guardian subject, child alias/reference, verified adult method/reference, relationship evidence/attestation, purpose, document/version, timestamp, status, revocation); encrypt and scope access. No raw government ID scans by default.
5. Show currently authorized adults and each purpose to the child in age-appropriate terms, preserve visible OS monitoring notification and user-friendly revocation/grievance mechanisms.
6. Child/guardian disputes, custody changes and alleged misuse: **freeze new sharing and potentially collection**, require documented escalation and identity reassessment; do not automatically accept a payment-holder as lawful custodian.
7. Parent withdrawal stops further relevant collection and sharing promptly; records/backup erasure follows approved policy while preservation requirements are independently assessed.
8. Test with fake identity and synthetic child data: forged/replayed consent, expired relationship, child transfer, 2 guardians in conflict, revoked parent and erased profile.

## 4. Required India + US Chicago privacy assessment before production/pilot

**Required owner-led, primary-law-cited legal compliance record** (qualified counsel advice optional for unresolved/high-risk matters) must address:
- Data Fiduciary/controller and processor identity: legal entity, registered/operations location, India point of contact, grievance mechanism; guardian identity and age policy; whether Indian legal obligations apply prior to/full May 2027 rollout.
- Written construction of section 9(1–4), Rules 10 and 12, Fourth Schedule Part B real-time location purpose. **Does a consumer parent tracking app qualify?** If yes, exact necessary fields/time window and residual section 9(2) and general obligations.
- Separate lawful-purpose table for **historical routes/trips**, stop/school arrival, app usage/behavioural monitoring, managed DPC controls, predictive alerts, geofences, SOS, watch, access logs; green/yellow/red feature scope.
- Consent, adult age verification, custodial authority, conflict and withdrawals; accessibility and other applicable child-protection law.
- Section 16/Rule 15 cross-border transfer, **US Midwest Chicago** OCI, Google processors, backups, support access, potential government notifications, any sector-specific restrictions, incident response and subprocessor agreements.
- Review of data security safeguards, breach reporting, retention/deletion including backup/log requirements, data minimization and identity verification data.
- Privacy notice, Terms, Data Safety, Play monitoring declaration, exact child-facing transparency and audit; counsel signoff/review cadence as notifications evolve.

**Decision output:** OWNER-ASSESSED_LEGAL_SCOPE with dated owner review and enumerated supported features; UNRESOLVED/OFF for the rest. No claimed government or counsel approval. Keep private evidence references without publishing child PII.

## 5. Data retention decision gate (B-07)

**Unapproved architectural trial candidates, NEVER a live processing promise:**

| Category | Engineering *candidate* retention | Pending legal/product decision |
|---|---|---|
| Raw GPS fix events | **14 days** | Does history qualify? Can collection start? Necessity and supported storage region |
| Derived trip/stop history | **90 days** | Explicit separate purpose, retention necessity; otherwise **disabled** |
| Child app usage raw/aggregate | **OFF** in India minor pilot | Require independent lawful basis; if approved candidate no more than **30 days** initially, final period signed |
| Device heartbeat and non-location diagnostics | 7–30 days candidates | Remove unique child identifiers when possible |
| Significant audit/security/parent authorization receipts | **365 days compliance-planning candidate** | Specific statutory retention obligations, start/end dates and exceptions require counsel |
| Backups of permissible data | Daily encrypted, **max 30-day rolling candidate** | Restore tombstone, paid provider restrictions, legal necessity and test evidence |
| Parent age/authority evidence | Minimal verifiable reference only | Avoid raw ID; decide valid lawful minimum and deletion exceptions |
| SOS delivery metadata | **30-day candidate**, redacted | Distinguish incident record from retained GPS and emergency evidence |
| Unapproved usage / Roads / media | **0** | No data captured until independently approved |

Retention does **not** start automatically merely because a number appears in a database spec. Confirm all subprocessor copies, cache, export, device offline queue, replication, log and backup expiry. In particular, OCI financial modelling's **30-day raw GPS** is **a cost-only assumption**, not an approved retention policy.

## 6. Binding engineering stop conditions

- **LG-01:** B-01 legal publisher identity verified → otherwise **BLOCK REAL CHILD DATA**.
- **LG-02:** B-02 India initial launch + defined under-18 ages/custodial relationship formally approved → otherwise **BLOCK**.
- **LG-03:** India lawyer legal memo for all planned data purposes (live location, history, app usage separately) → otherwise **BLOCK**.
- **LG-04:** Review actual deployment/processor regions, remote support, transfers, agreements and current Government restrictions; Chicago-specific review only if that processing is actually selected → otherwise **BLOCK REAL CHILD DEPLOYMENT**, not environment-agnostic synthetic local work.
- **LG-05:** B-07 retention/backup and delete/restore tests → otherwise **BLOCK**.
- **LG-06:** Parental verification + notice + consent/exception by purpose in code (backend denies missing authority) → otherwise **BLOCK**.
- **LG-07:** Child-specific guardian scope and role management approved; identity/relationship disputes and revocation tested → otherwise **BLOCK**.
- **LG-08:** Google Play and independent Android monitoring disclosures + all real provider policies completed → otherwise **BLOCK PUBLIC RELEASE**.

**M0 may use synthetic traces. M1 enrollment may be tested only with fabricated participants or legally reviewed adult volunteers. M2/pilot involving real minors remains blocked until LG-01 through LG-07 pass.** Even after all those gates, Play release needs LG-08, working privacy/deletion pages and platform tests.

## 7. Relation to other docs / ownership

- [Owner Decisions and Blockers](../01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) B-01/B-02/B-07/B-09/B-18, X-03; legal reviewer accountable.
- [Data/Authorization/Recovery](../../M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md) implements scoped grants, erasure and source audit once approved.
- [Privacy Policy Draft](../../M9-play-release/02-public-legal-drafts/PRIVACY_POLICY_DRAFT.md) is not a published lawful notice.
- [India-first Subscription](../../M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md) cannot justify extra monitoring merely because purchased.
- [OCI Deployment](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md) region decision is conditional, not legal clearance.

**Research caveat:** This memo summarizes primary legislative instruments verified on 2026-10-26. It does not offer legal advice; lawyer review must also check any changes after that date and other sectoral, consumer, employment and cross-border obligations.

## 8. India-primary region option supersedes original Chicago preference

**Historical preference, clarified 2026-10-30:** India OCI location (Mumbai, Hyderabad alternative) was preferred, but final region/tenancy/bandwidth decisions are reserved for deployment and are not local-coding prerequisites. The original Chicago-specific analysis is retained as a contingency in case of US processing or third-party transfer, **not** the current recommended deployment. Domestic OCI hosting may simplify the primary storage transfer question, but Google/Firebase/identity processors, support, backup replication and any cross-border handling still need mapping. Section 9 and Rule 10/12 under-18 consent/behavioral-monitoring interpretation and lawful guardian verification remain open; initial India ages **0–17** are owner-decided, not unresolved. [India region decision](INDIA_REGION_AND_M0_OWNER_DECISION_GATE.md).

## 2026-10-26 Cross-policy assessment addendum

The [MA-COMPLIANCE-001 official-source assessment](INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md) adds: **(1)** Google Play Families restriction on location collection by apps solely targeted to children and unresolved compatibility with the parental-monitoring-app exception; **(2)** CERT-In incident reporting six-hour and ICT-log 180-day India obligations for covered entities; **(3)** future DPDP Rule 6/8 processing/log retention reconciliation; **(4)** Android API36 and background while-in-use policy. **Narrow DPDP real-time location allowance does not override Google Play or Android security rules.**

## 2026-10-27 children’s media-activity metadata and administrator-search gate

A design with **zero VPS audio/video/photo files** can still process child-linked metadata (who viewed or saved media, when, for how long, child/parent IDs, failed reasons, local file-size receipt and administrator access to activity). Treat this as a distinct sensitive processing purpose requiring India DPDP children's requirements/exemptions analysis, documented guardian authority and data minimization. Administrator access is not inherently justified by infrastructure ownership: require MFA, case-based purpose and child/parent scope, accountable searches, audited denied attempts and redacted aggregate support by default. Set explicit retention, deletion, access rights and cross-border backup/processor handling with counsel before deploying. No change to original M0 legal NO-GO or camera/mic P3 release status. See [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md) and [Administrator Console Specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md).

## Sources

[1] https://meity.gov.in/static/uploads/2024/06/2bf1f0e9f04e6fb4f8fef35e82c42aa5.pdf — act
[2] https://www.meity.gov.in/static/uploads/2025/11/c56ceae6c383460ca69577428d36828b.pdf — commencement
[3] https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf — rules
[4] https://www.meity.gov.in/static/uploads/2025/12/3c7ebbae0e5456f493f486e6845df86b.pdf — corrigendum
[5] https://www.cert-in.org.in/PDF/CERT-In_Directions_70B_28.04.2022.pdf — cert
[6] https://www.cert-in.org.in/PDF/FAQs_on_CyberSecurityDirections_May2022.pdf — faq
[7] https://www.meity.gov.in/static/uploads/2026/03/0b576f2071694b52e4cd6bb1b6dfab1e.pdf — it2026
[8] https://www.indiacode.nic.in/show-data?abv=CG&actid=AC_CEN_45_76_00001_200021_1517807324077&orderno=49&orgactid=AC_CG_61_1375_00002_00002_1593684216468&sectionId=13058&sectionno=43A&statehandle=123456789%2F2490 — IndiaCode IT Act section 43A (indexed section text; direct retrieval timed out)
[9] https://dispur.nic.in/itact/it-procedures-sensitive-personal-data-rules-2011.pdf — G.S.R. 313(E), 11 April 2011 (official Gazette replica, indexed excerpt only; full retrieval pending)
[10] https://static.pib.gov.in/WriteReadData/specificdocs/documents/2025/nov/doc20251117695301.pdf — PIB explainer, 17 November 2025 (guidance, not commencement instrument)


## 2026-10-31 first-party primary-law review: no mandatory paid counsel opinion

**Review type:** Project's independent statutory desk assessment. **Not legal advice from an enrolled Indian advocate, a binding court/regulator opinion, a government license or Google Play approval.** Prepared from official primary sources as of 31 October 2026. Update after relevant amendments, court decisions, Play decisions and the two pending enquiries (Tele-Law and MeitY); the owner also sent an enquiry to LegalMeet. Do not confuse *asking a lawyer* with *obtaining permission*. No legal fees or signed/printed counsel PDF are mandated as a general precondition in the cited Act/Rules.

### A. Is the supposedly compulsory lawyer's memorandum actually required?

**No general requirement found.** Nothing in the reviewed DPDP Act 2023 or DPDP Rules 2025 imposes a routine signed advocate's opinion, a paper legal certificate or a general MeitY/CERT-In approval on an ordinary commercial parental-safety Android app. This negates the *paperwork-only blocker*, **not** the obligation to lawfully process child data. Section 10's independent data audit/DPO/DPIA measures apply to operators **notified as Significant Data Fiduciaries**—not every startup automatically. Section 6(9)'s Board registration applies if acting as a regulated **Consent Manager**, not automatically to an app obtaining consent for its own users. Sector-specific rules may still require separate action if the business falls in a regulated class. An advocate's substantive email can be additional review evidence, but neither email nor signed PDF confers blanket permission.

Primary authority: [India Code DPDP Act](https://www.indiacode.nic.in/bitstream/123456789/22037/2/a2023-22.pdf), [MeitY DPDP Rules](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf).

### B. Effective dates and existing law

| Phase | Act / Rules (official commencement instruments) | Effect for project |
|---|---|---|
| **13 November 2025** | DPDP Act section 2 and listed administrative provisions / Rules 1, 2 and 17–21 commenced | The Act is *partially* in force; avoid either “nothing applies” or “all provisions apply”. |
| **13 November 2026** (+1 year, scheduled) | DPDP Act section 6(9) and 27(1)(d); Rules 4 | Registration of a Consent Manager does not automatically apply to a parent's monitoring service. |
| **13 May 2027** (+18 months, scheduled) | Act sections 3–5, 6(1–8,10), 7–17 **including section 9**; Rules 3, 5–16 **including Rule 12**, 22–23 | Build for these future obligations before any processing that continues past commencement. Recheck Gazette for later changes. |

This is calendar calculation from the Gazette's *13 November 2025* date, subject to official later changes; it is not a new promulgated launch date. Sources: [official commencement G.S.R. 843(E)](https://egazette.gov.in/WriteReadData/2025/267647.pdf); [Rules G.S.R. 846(E)](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf).

Other current law does not disappear during phased commencement. Evaluate IT Act 2000, [SPDI Rules 2011](https://indiankanoon.org/doc/114407484/) (see also [Government clarification](https://www.pib.gov.in/newsite/erelcontent.aspx?lang=2&reg=48&relid=74990)), and applicable [CERT-In 2022 cyber-incident directions](https://www.cert-in.org.in/PDF/CERT-In_Directions_70B_28.04.2022.pdf). Role applicability and any 2026/2027 amendment need fresh checking. A covered operator's **ICT security-log** retention is not a license to hold unrelated raw child GPS/audio/video for 180 days.

### C. Statutory reading and the narrow child-safety exception

- **Commercial role:** Section 3(c)(i)'s personal/domestic processing exception for an *individual* does **not automatically extend** to the business/third-party app backend simply because a family is using it at home.
- **Child:** Section 2(f) defines child as under 18; section 9(1) requires verifiable parent/guardian consent subject to applicable exemptions, 9(2) bars processing likely to harm a child's well-being, and 9(3) restricts tracking/behavioural monitoring (as well as targeted advertising). Consent by itself cannot waive a tracking prohibition.
- **Real-time safety location:** Rule 12(2), Fourth Schedule Part B item **4**, exempts **only section 9(1) and (3)** for a specified *purpose*: determining the child's **real-time location**, restricted to the child's **safety and protection or security**. It does **not** waive section 9(2), general lawful-processing and minimization duties, or Play/Android platform restrictions. A consumer app's exact eligibility and what time/buffering/storage qualifies as strictly necessary require a reasoned documented decision; the schedule is **not an individualized government license**.
- **Consent and retention:** Sections 4–8 (when operative) address lawful grounds, notices, consent, security, processors, purpose limitation and deletion. Even a real-time exception is not a blanket consent-free basis for every associated category. A Google OIDC login verifies an account, **not custody or parental authority**.

Sources: [DPDP Act §§2–10](https://www.indiacode.nic.in/bitstream/123456789/22037/2/a2023-22.pdf), [DPDP Rules Rule 12/Fourth Schedule Part B](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf).

### D. Feature-specific disposition — INDEPENDENT DESK ASSESSMENT, NOT APPROVAL

| Feature | What the primary law supports / does not settle | Project status |
|---|---|---|
| **On-demand real-time location for child safety** | Potentially within the narrowly defined Fourth Schedule B(4), provided necessity and strict safety purpose; commercial-service eligibility and system design still must be reviewed | **CONDITIONAL / not cleared for real children**; minimal on-demand scope, verified guardian authority, OS and Play G01/G04 need evidence |
| **Continuous/background/high-intensity GPS, local 48h queue, server inbox** | Extent of incidental buffering within *real-time* purpose not specified; retention and ongoing collection may turn into history | **UNRESOLVED**; minimize buffers/TTL, define lawful purposes and power/Android constraints, not enabled for unapproved real children |
| **Stored historical GPS, routes, stops, school/geofence profiling, history hidden behind paywall until subscription** | Not expressly included within narrow *real-time* location exemption; tracking and profiling risks under future §9(3), purpose-limited deletion under §8 | **HIGH-RISK / OFF pending separate affirmative lawful basis**; indefinite “until account closure” storage is not proved compliant merely because parent may upgrade |
| **App usage / behavioural monitoring / screen-time reports** | Not named by the real-time-location purpose; potentially prohibited child behavioural monitoring | **HIGH-RISK / OFF pending distinct legally supported scope; parental permission alone insufficient** |
| **Child-initiated SOS and check-in** | Safety purpose plausible, but not blanket exception from data collection/retention/guardian duties | **CONDITIONAL / engineering with synthetic data only**; minimize event fields and preserve fallback |
| **Remote mic, camera, photo, video and screen capture** | No general authorization from B(4); third-party/bystander and protected financial content risk | **DEFERRED / OFF for real children** until supported per-feature legality and actual Play + Android checks, no covert or OS-bypass capture |
| **Media activity metadata and administrative access** | Child-linked event records are still personal data even without VPS media files | **RESEARCH ONLY**; bounded audit, scoped access, lawful purpose, deletion and retention assessment |
| **Guardian enrollment, authority, disputes/revocation** | Adult Google login is not legal-parent verification; family sharing and data processing need proper authority and safety controls | **Design/test with synthetic users**; real-parent age/authority proof and notices required before child onboarding |

### E. What is cleared versus still gated

**CLOSED:** “Pay an Indian lawyer for a signed memorandum/printed certificate before we can code or otherwise clear an artificial paperwork checklist.”

**DOCUMENTED, NOT LAW-CERTIFIED:** This primary-source statutory reading, dates and feature risks. This does **not** confer legal permission or make all features safe for commercialization.

**OPEN:** X-03/G02 **substantive** feature lawfulness, duration/retention B-07, verified guardians B-09/B-18, safeguards, other-law applicability and responsible owner review. Obtain voluntary specialist advice for any still materially disputed sensitive activity, **or exclude it from release**; no mandatory expensive audit simply because the app is planned.

**SEPARATE HARD GATES:** Android OS/device permission and [Google Play Families](https://support.google.com/googleplay/android-developer/answer/9893335) (solely child-targeted apps may not request location permissions or collect/use/transmit precise location), monitoring declarations and any independent background-location review. Do not misdeclare audience.

**Future X-03 acceptance:** dated, primary-source-cited owner-reviewed per-feature lawful-purpose/consent/safety/retention assessment with all open uncertain activities explicitly excluded from production, plus separately verified Play/Android approval for actual enabled behavior. Optional consultant email or government clarification can be appended, but is not mandatory paperwork. Any continuing material doubt about a sensitive feature remains a feature-release NO-GO rather than an automatic blanket project stop.
