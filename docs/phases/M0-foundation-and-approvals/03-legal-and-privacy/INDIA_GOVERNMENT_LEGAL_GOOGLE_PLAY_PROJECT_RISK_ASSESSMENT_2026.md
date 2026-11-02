> **Current 2026-10-31 legal-paperwork correction:** Older requirements for a mandatory signed Indian advocate opinion are *superseded*. The DPDP Act and Rules reviewed do not prescribe a routine legal-opinion certificate. The substantive per-feature Indian-law assessment, under-18 restrictions, Google Play and Android gates **remain**. See [2026-10-31 primary-law desk review](INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md#2026-10-31-first-party-primary-law-review-no-mandatory-paid-counsel-opinion). This is not a finding that child monitoring is legally approved.

# Madalasa & Alarka — India Government, Legal, Google Play & Android Project Assessment

> **Document control:** M0 / 03-legal-and-privacy · Proposed owner: Privacy counsel + owner (not assigned) · Registry: DRAFT_LEGAL_REVIEW_REQUIRED; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Reference:** MA-COMPLIANCE-001 | **Reviewed:** 26 October 2026 | **India-first** | **Status:** product risk assessment, NOT legal advice or Play approval.  
**Apps:** Madalasa (parent/guardian), Alarka (child companion). **Repository:** https://github.com/methakon/Madalasa-Alarka.

**Decision:** NO-GO for real-minor monitoring and Google Play release while the critical approvals below remain open. GO for synthetic-data engineering and security tests. **Scope rule:** A feature must pass Indian law, Google Play policy and Android OS restrictions separately; a parent granting OS permissions is not enough.

## Current legal and owner reconciliation — 2026-10-30

Owner-declared publisher: **Individual SWARNA SEKHAR DHAR, India**, same intended legal/Google Play publisher. India-only first release and children ages **0–17** are owner-decided; **identity evidence, Payments identity, merchant setup, public support confirmation and legal review remain pending**. No company, GST registration, public address/email, grievance appointment or counsel approval is inferred. **Real child-data release OFF.**

The [current source-grounded legal gate](INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md#current-source-grounded-review--2026-10-30) takes precedence over earlier legal summaries here: it records notified DPDP phases, December 2025 corrigendum, PIB guidance versus Gazette law, current IT/SPDI applicability/retrieval limits, **2026-amended** intermediary grievance clocks if applicable, CERT-In directions/FAQ, and future Rule 8(3)'s express personal-data/traffic/processing-log retention scope. Candidate short GPS/backup TTLs remain unadopted pending reconciliation. Play/Android findings below are historical research, not a newly performed platform-policy certification.

No Google Family Link dependency: Google sign-in is account authentication, not adult-age or parent/guardian proof. Sharing requires acceptance for **one exact child**, authorized inviter and approved authority/consent where required; no siblings or automatic billing-family access. Final production region/tenancy/economics are deployment decisions, not prerequisites to synthetic local coding.

## 1. Highest priority findings

**R-01 — Google Play child app + GPS conflict (CRITICAL).** Google Play Families Policy states **apps solely targeted at children may not request location permission or collect, use or transmit precise location** [P1]. Alarka is to be installed on children's phones. Google's separate monitoring-app exception for parent-to-child monitoring [P2,P3] has **not** been shown to override that Families condition for our actual child companion. Written product-specific Play classification is therefore required BEFORE promising/implementing an Alarka GPS launch. **Do not falsely label the app adult-targeted to get around policy.**

**R-02 — DPDP children tracking distinction (CRITICAL).** India's DPDP Act section 9 prohibits tracking/behavioural monitoring of under-18s subject to narrow exceptions. The 2025 Rules Fourth Schedule Part B item 4 addresses **real-time location limited to child safety/protection/security**, rather than blanket historic trips, geofence profiles, app usage, or media surveillance [L1,L3]. Commercial consumer applicability needs a primary-source-backed assessment; qualified advice is recommended if unresolved. Until supported: **real minor data OFF; history, usage and route profiling OFF**.

**R-03 — transparent monitoring and OS limits (CRITICAL).** Eligible Play child-monitoring apps need a recognizable icon, monitoring disclosure, a persistent notification while running and the isMonitoringTool child_monitoring flag where applicable [P2,P3]. Android foreground/background restrictions, especially Android 14+ camera/mic/location while-in-use checks, remain effective after runtime grants [A1,A2]. **No stealth/hidden tracking, remote silent mic/camera, guaranteed background capture, or bypass.**

**R-04 — operational obligations (HIGH).** CERT-In 2022 cyber directions may require covered providers to report listed incidents within **6 hours** and maintain ICT logs **180 days within India** [L4]. DPDP Rules introduce one-year processing/traffic/security log requirements and other breach notices when their staged provisions commence [L3]. Data class retention must be reconciled with erasure. OCI Mumbai primary hosting does not mean Firebase, identity, SMS, support and backups are all India-local.

## 2. Legal / Play / Android source register — primary sources

**Indian Government**
- **[L1]** Digital Personal Data Protection Act, 2023. Section 2(f) child under 18, sections 4–9, 11–13, 16. https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023.pdf
- **[L2]** MeitY Gazette G.S.R. 843(E), 13 November 2025: phased commencement. Key sections 3–10 and 11–17, with specified exceptions, start **18 months from Gazette publication**, approximately mid-May 2027; printed date and online publication marker need lawyer verification. Other sections started earlier. https://www.meity.gov.in/static/uploads/2025/11/c56ceae6c383460ca69577428d36828b.pdf
- **[L3]** DPDP Rules 2025 G.S.R. 846(E): Rule 10 adult-verification, Fourth Schedule Part B #4 child real-time safety location exception, Rules 3/6/7/8/9/12/14/15 notice, security, breach, retention, rights and transfer. Several relevant rules phase in after 18 months, not necessarily in force on 26 Oct 2026. https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf
- **[L4]** CERT-In 28 Apr 2022 directions under IT Act section 70B: reportable listed incidents 6 hours, covered entities' ICT logs 180 days in India, NTP and designated contact. Publisher applicability requires assessment. https://www.cert-in.org.in/PDF/CERT-In_Directions_70B_28.04.2022.pdf
- **[L5]** CERT-In clarifications and FAQs: https://www.cert-in.org.in/Directions70B.jsp

**Google Play**
- **[P1]** Families policy, accurate audience declaration, solely child-targeted location and identifier restrictions, SDK vetting: https://support.google.com/googleplay/android-developer/answer/9893335?hl=en
- **[P2]** Stalkerware/parent monitoring policy, transparent monitoring, notification, icon, no adult spouse monitoring: https://support.google.com/googleplay/android-developer/answer/9888380?hl=en
- **[P3]** isMonitoringTool with child_monitoring manifest flag for relevant monitoring-app builds across all Play tracks: https://support.google.com/googleplay/android-developer/answer/12955211?hl=en
- **[P4]** Background location core function, minimal scope, explicit disclosure, in-app privacy, permissions declaration and Android demo video: https://support.google.com/googleplay/android-developer/answer/9799150?hl=en
- **[P5]** Permissions/User Data/SDKs: purpose-limited and accurate collection and Data Safety: https://support.google.com/googleplay/android-developer/answer/16558241?hl=en
- **[P6]** Account deletion: if created in-app, accessible in-app AND public web deletion route and data erasure: https://support.google.com/googleplay/android-developer/answer/13327111?hl=en
- **[P7]** Play Billing for digital subscriptions except published exceptions; truthful pricing/cancellation: https://support.google.com/googleplay/android-developer/answer/9858738?hl=en
- **[P8]** Target API: 31 Aug 2026 milestone for standard new Android phone apps **API 36+**, extension exceptions require verification: https://support.google.com/googleplay/android-developer/answer/11926878?hl=en
- **[P9]** No device/network abuse, OS bypass, abusive update/power management: https://support.google.com/googleplay/android-developer/answer/16559646?hl=en
- **[P10]** AccessibilityService restrictions and disclosure: https://support.google.com/googleplay/android-developer/answer/10964491?hl=en

**Android OS**
- **[A1]** Foreground-service background-start and camera/mic/location while-in-use restrictions: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- **[A2]** Specific foreground-service types and permission requirements: https://developer.android.com/about/versions/14/changes/fgs-types-required
- **[A3]** NDK C++ 16KB native page alignment, compatibility and Google Play update milestone in 2027: https://developer.android.com/guide/practices/page-sizes

## 3. Risk definitions

**CRITICAL/BLOCKER:** plausible business-model/legal/Play disqualification or serious covert tracking/child-data security risk. **HIGH:** material rejection, exposure, misleading safety or incident impact. **MEDIUM:** releasable only after test/disclosure. These are conservative **risk ratings, not legal guilt findings**.

## 4. Norm-versus-project risk register

| ID | Severity | Gap against rules | Product action and reason | Evidence to close |
|---|---|---|---|---|
| R01 | **CRITICAL** | Alarka child audience and precise location vs Families restriction [P1,P2] | BLOCK child GPS Play launch; obtain real-use eligibility decision; never misstate audience | Written Play classification for actual target ages/manifest |
| R02 | **CRITICAL** | Historic tracking, inferred stops/behavior vs narrow DPDP real-time exception [L1,L3] | OFF for minors until case-specific legal purpose decision | Dated primary-law feature assessment; specialist advice if unresolved |
| R03 | **CRITICAL** | Parent OIDC and device permission are not verified adult/custody consent [L1,L3] | Independent lawful guardian identity and authority verification | Approved adult-age, parent proof and contested-custody workflow |
| R04 | **CRITICAL** | Individual publisher / India ages 0–17 owner-decided; verification, retention, notice and legal approval incomplete | No real child data before M0 owner/legal signature | Publisher evidence, Payments/merchant/public support, B-01/B-02 implementation and counsel review |
| R05 | **CRITICAL** | Hidden Alarka/stealth monitoring vs stalkerware [P2,P3] | Visible icon, persistent monitoring notification while running, clear child-accessible purpose statement | APK + actual notification/listing video |
| R06 | HIGH | Madalasa claims to remotely grant child Android permissions [A1,P5] | Parent guide only; child Android Settings grants and rechecks | Real phone deny/grant/OS_REJECTED test |
| R07 | HIGH | Background GPS without Play core-feature approval [P4] | Conditional on R01/R02, then Play form, prominent disclosure and video | Play policy response, runtime permission video |
| R08 | **CRITICAL** | Hidden microphone/camera/video and remote start [A1,A2,P2] | Exclude; visible user-initiated capture requires separate future review | Separate OS, counsel and Play evidence |
| R09 | HIGH | Child UsageStats and per-app behavioural data [L1,L3] | OFF even after Usage Access until per-purpose legal determination | Signed behavioural-monitoring assessment |
| R10 | HIGH | STANDARD Android cannot be presumed device owner [P9,A1] | DPC app-blocking LAB ONLY on legitimate provisioned device | Real factory-resettable phone proof, protected apps, rollback |
| R11 | **CRITICAL** | Another family/guardian guesses child ID [L1,P5] | Server child-scoped permissions + forced RLS + revoke stream/cache | Two-family SQL + API negative tests PASS |
| R12 | HIGH | Retention plans conflict with logs/erasure/incident obligations [L3,L4] | Separate minimized product GPS from restricted legally required logs | Counsel data category matrix, TTL and restore audit |
| R13 | HIGH | Account deletion absent on web, backup resurrects a child [P6,L1] | Public web and in-app deletion, processor erase, tombstones | Functional deletion link and DR no-resurrection |
| R14 | HIGH | OCI Mumbai described as all data India, Google subprocessors cross-border possible [L1,L3] | Map every SDK, backups, telemetry and access jurisdiction | Signed subprocessor and transfer matrix |
| R15 | HIGH | SOS may fail if single VM fails; claimed emergency-grade alert | Best-effort check-in only or build independent funded backup | Outage + guardian human-ACK drills |
| R16 | HIGH | FCM provider accepted equated to actual guardian ACK [P5] | Separate OFFLINE_QUEUED / SERVER_ACCEPTED / PROVIDER_ACCEPTED / GUARDIAN_ACK | Retry/duplicate/offline tests |
| R17 | HIGH | No incident operator/CERT 6h reporting process [L3,L4] | On-call owner, log pipeline, templates, NTP, contact and drills | Timed cyber incident tabletop and response |
| R18 | HIGH | Child audience, ads, advertising IDs, SDK data flows [P1,P5] | No child-targeted ads; minimize identifiers; honest audience declarations | SDK/App Content/Data Safety audit |
| R19 | HIGH | Two apps share incorrect disclosure, data categories, publisher identity [P2,P5] | Per-app privacy/Play listing and child visible consent; match AAB | Madalasa + Alarka manifest/flow review |
| R20 | HIGH | Sandbox/AccessibilityService/file extraction or unapproved power bypass [P9,P10] | Exclude; child-visible Storage Access Framework selected files only if separately approved | Manifest permissions audit |
| R21 | MEDIUM | ₹50/month, ₹500/year not verified in Play for fees/tax/refund [P7] | Sell only released eligible functions, actual Play price/seat/cancel | Sandbox payment and merchant reconciliation |
| R22 | HIGH | 2026 API36 requirement & C++ native 16KB [P8,A3] | Build API36 AAB and test 16KB, Android OS behavior | CI AAB validation and OEM matrix |
| R23 | HIGH | Pairing replay, stolen token, guardian scope mix-up [P5,L3] | Expiring single-use code, Keystore proof, no client tenant authority | All M1-01..05 plus revoked key tests |
| R24 | **CRITICAL** | Misrepresent Alarka as adult-only to bypass Families [P1] | Forbidden strategy; resolve real audience classification or pivot product | Actual truthful Play age declaration |
| R25 | MEDIUM | Abusive adult/spouse/custody conflict [P2,L1] | Guardian verification, child-specific grants, abuse complaints, rapid revocation | Safety misuse cases, complaint SOP |
| R26 | MEDIUM | Brand/public legal publisher/trademark/API strings drift [P5] | Use Madalasa/Alarka in listings; check naming rights, IDs separately | Signed store metadata and branding review |

## 5. WHAT TO INCLUDE / RESTRICT / AVOID

| Capability | Recommendation | Why |
|---|---|---|
| Parent Google login, family UI, transparent Alarka setup | **INCLUDE as synthetic M1** | Lowest initial data footprint, foundation for verified identity; Google account does NOT establish lawful parent |
| Child installation/permission walkthrough | **INCLUDE** | Visible user authorization; cannot remotely grant OS permissions |
| One-time code, Android Keystore signature, child-scoped grants, device revocation | **INCLUDE, synthetic first** | Essential family authorization and abuse resistance |
| Child heartbeat/battery last-known health | **CONDITIONAL minimum only** | Even device metadata needs purpose and minimization; health is not location |
| Current child location strictly for immediate safety | **BLOCKED until Play + counsel** | Play Families conflict and narrow DPDP exception; location permission only after all three gates |
| Persistent background location | **BLOCKED until Play + counsel + OS test** | Sensitive core-use permission needs declaration and Android lifecycle eligibility |
| Stored trips, stop inference, saved-place alerts, commute prediction | **OFF** | Not automatically real-time safety location; exposes behaviour/risk |
| App usage, screen time, behavioural profiles | **OFF for Indian minors** | DPDP s9(3) and separate usage-access / Play review |
| Child-initiated visible check-in | **CONDITIONAL promising MVP** | Lower data requirement but still needs guardian purpose and Play child-app audience analysis |
| FCM notifications + explicit guardian acknowledge | **INCLUDE honest state** | Provider acceptance is not human acknowledgement |
| "Guaranteed" SOS/emergency dispatch | **DO NOT CLAIM** | Single VM/SMS/fallback/responder not operationally proven |
| Temporary pickup/extra guardian | **CONDITIONAL** | Adult proof, child scope, expiry, revoked access and custody checks |
| Managed app blocking/screen-time policies | **LAB ONLY** | Requires OS-verified device owner, not ordinary install |
| Hidden microphone/video/camera and remote ambient recording | **EXCLUDE from commercial scope** | Very high privacy, background OS and Play monitoring risk |
| Call/SMS scraping, keylogging, covert screenshots, Accessibility workarounds | **EXCLUDE** | Irrelevant to narrow family safety and substantial malware/restricted-permission exposure |
| Explicit selected-file backup/Google Drive | **DEFER** | New purpose, selected file access, consent, processor audit |
| Child accessible notice, grievance, deletion, privacy/export rights | **INCLUDE before release** | Legal and Play data control obligations |
| Dark/normal/eco app appearance | **DEVELOPERS IMPLEMENT** | Styling is not data permission; eco mode must show actual observation age |
| ₹50/₹500 Play child seats | **DEFER until approvable offering** | Real product/price/tax, cancellation and entitlements must be validated |

## 6. Security, incident-response and retention design

**2026 vs 2027:** DPDP Act child sections and corresponding Rules are **phased**, projected mid-May 2027 [L2,L3]. Never call the whole Act currently enforceable, but also never assume Play/CERT/other Indian duties are deferred. Verify precise Gazette publication commencement dates, intervening orders and India-law applicability through specialist counsel.

**CERT-In [L4]:** for covered entities, report listed cyber incidents within 6h of notice and retain appropriate ICT logs in India for a rolling 180d. **DPDP Rules [L3], when effective:** Rule 7 affected-person notice without delay, Board initial notice without delay plus details within 72h (or allowed extension). Different reporting clocks must be handled separately.

**Log retention:** Rule 6 safeguarding and Rule 8(3) specified one-year processing/traffic/log retention require a legal classification assessment; not blanket permission to keep raw kid GPS in accessible product history. Prior suggestions: raw location 14d, derived route 90d, backup 30d, audit 365d — ALL **candidates**, not legally signed. Build matrix by class: current fix, raw GPS, route/usage, consent, guardian ACL, access logs, auth events, traffic/security logs, SOS, backups; capture purpose, legal minimum/maximum, India region/subprocessors, secure readers, erasure trigger and no-resurrection evidence.

**India hosting — historical preference clarified 2026-10-30:** Mumbai/Hyderabad are scenarios, not final deployment choices; no tenancy or off-host recovery is certified here. Google identity/FCM/Maps/Billing/SMS/support may process abroad, so do not claim all data remains in India. Keep third-party contracts/dataflow and backups in review.

## 7. Minimum viable product recommendations (NOT approval)

**Option A: lawful, narrowly-scoped child-safety location** *only if* official Play classification and an owner-reviewed source-cited legal assessment support Alarka's exact child-audience/location behavior. Include current last-observed time/accuracy, minimal approved storage, visible notification, parent legal verification, no history/usage/media, child permissions and secure per-child grants. Must also pass Android background tests and Play declaration.

**Option B: low-data family connection until location dispute resolved**: parent account+guardian verification, child-transparent Alarka, child-initiated “I'm OK / contact me” check-ins, user-controlled manual contact, permission coach. Even optional one-time location sharing is not automatically exempt from Play Families location rule. No disguised side-loaded location app or false target audience.

**Neither path is automatically approved.** No real child data or sales until G01/G02 and operational prerequisites pass.

## 8. Mandatory signoff and evidence gates

| Gate | Owner role | Written proof required before live feature |
|---|---|---|
| G01 Play child location **CRITICAL** | Product owner / Play policy liaison | Actual child audience and monitoring classification; written location eligibility review |
| G02 India child legal **CRITICAL** | Owner and qualified privacy reviewer (specialist lawyer optional if unresolved) | Purposes, safety exception, history/usage, guardian verification/consent, correct dates |
| G03 Publisher/ages/guardian | Owner / legal | Verify declared individual B-01; India ages 0–17 B-02 decided; Payments/merchant/public-support pending; custody/pickup/revoke B-09/18 and adult verification remain separate |
| G04 Play package/submission | Android+Play lead | Final Alarka/Madalasa manifests, age labels, MonitoringTool, disclosures, background video, Data Safety |
| G05 Devices | Android QA | API 29/30/34/36 coverage; actual resettable DPC phone; native 16KB; OS deny/revoke behaviors |
| G06 Security | Backend + independent QA | PostgreSQL two-family RLS PASS, Keystore PoP, replay, scopes, revoke, sanitized logs |
| G07 Privacy & deletion | Privacy engineer / counsel | Public web delete, in-app delete, vendor map, approved retention, encrypted backup restore |
| G08 Incident / DR | Security and infra | CERT 6h on-call runbook and contacts; clock sync; logs; OCI region, restore and RPO/RTO tests |
| G09 SOS | Product / operations | Best-effort label or paid independent fallback with proven guardian ACK |
| G10 Billing | Play merchant / finance | Actual SKU+price+tax, seat entitlement and cancel/refund sandbox tests |
| G11 Final launch | Product+counsel+Play+QA | Signed feature flags, build SHA, privacy URL, access/reviewer walkthrough |

**No persons, counsel approvals, real child hardware, CI results or Play permissions have been invented.** The GitHub M1 SQL and 14 tests are planned/reproducible artifacts, not necessarily executed or passed.

## 9. Specific changes this assessment requires

1. **Master milestone M0:** add critical G01 Google Play Families-versus-child-monitoring-location resolution **before M2 child GPS engineering commitment**.
2. **SRS / feature feasibility:** mark location as Play/legal blocked; history, behavioural usage, remote media and managed controls are NOT launch-approved merely because the feature is designed.
3. **Play Publishing Guide:** isMonitoringTool child_monitoring designation is necessary where applicable, but it is **NOT** a blanket Families/child GPS eligibility waiver; exact child target audience must be truthful.
4. **81-screen Figma handoff:** identify privacy/OS/legal-blocked screens as disabled, research or simulation; static mockup does not convey product eligibility.
5. **Blockers:** keep founder identity, exact age/custody, processor map, retention, hardware, counsel, ops budget open, plus new G01.
6. **Incident/retention:** plan 6h CERT reporting and prospective DPDP rights/breach obligations with purpose-specific restricted logs; test backup deletion.
7. **Google Play distribution:** separate accurate Madalasa parent and Alarka child listings, monitoring notice, SDK data flow, privacy, deletion web link and parent billing.

Related source documents: [India DPDP Gate](INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md), [Google Play Publishing Requirements](../../M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md), [Master M0–M9](../01-project-governance/MASTER_MILESTONE_IMPLEMENTATION_AND_RELEASE_PLAN.md), [SRS](../../M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md), [SOS fallback](../../M4-usage-health-sos/01-usage-health-and-sos/SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md), [M1 API](../../../openapi-m1.yaml), [M1 tests](../../../../backend/tests/M1_ACCEPTANCE_TEST_CASES.md), [Figma UI](../../../ui/figma-functional-handoff/README.md), [Blockers](../01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md).

**Review trigger:** before first Play upload, first real-child pilot, each sensitive feature activation, material Play/Android/Government change, and DPDP children phase commencement. This is a technical product risk assessment, **not an Indian law-firm opinion, government authorization, or Google Play preapproval**.

## Addendum — 2026-10-26 conditional media R&D accepted; legal status unchanged

The owner has accepted **engineering investigation** of conditionally possible one-way microphone listening, optional parent-local recording, live camera/photos/video, MediaProjection screen sharing with new session consent, flash-off camera when supported, and scoped shared-file access. Madalasa should tell a parent *why* a request failed or requires Android interaction. This **does not** change this document's CRITICAL R05/R08 risk assessment, commercial P3 exclusion, Google Play child-monitoring/Families requirements, DPDP child data conditions, bystander/other-party privacy, or the physical-device tests. The Alarka main Activity closing after setup is not authorization to conceal monitoring.

A P2P-first/TURN design with **no media files at rest on the VPS** may reduce central archive risk but does not remove responsibility for collecting, streaming, listening, recording, endpoint security, session metadata, retention, lawful guardian authority or third-party privacy. The Android **true device-owner exception** is a technical test candidate, not a child-safety legal exemption. No real-minor media pilot or commercial activation without signed India counsel, Play decisions, physical evidence and independent security review. Full controls, UI reasons and tests: [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md).

## Addendum — 2026-10-27 capability inventory/permission state metadata (risk rating unchanged)

The owner accepted a first-launch **read-only** Alarka OS/hardware and permission scanner, paired-device-only authenticated upload, step-by-step Android-owned grants, parent child-scoped compatibility GET, and later permission-revocation/regrant status after OS-permitted verification. **No actual camera/mic/GPS capture is authorized by detecting hardware or seeing an Android grant.** API/model/OS metadata linked to children can itself be personal data requiring an appropriate lawful purpose, minimization, disclosure, guardian authority, retention/deletion, subprocessor mapping and security controls. Temporary pickup viewers do not automatically need detailed sensor-grant information.

Android may kill Alarka on permission revoke, so promised immediate parent-side red/green changes would be misleading; use last-verified/UNKNOWN/STALLED timestamps. Background child-location and usage tracking and P3 media remain subject to existing CRITICAL Google Play Families/monitoring and India DPDP determinations. This addendum **does not downgrade R02/R05/R08** or authorize real-minor data pilots. [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) and its 46 Figma screens are design-only.

## 2026-10-27 child-linked media metadata logging and administrator access legal review addendum

The owner requests searchable/paginated media-activity logs visible to parents and restricted administrators **without storing media files**. Planned data (child names/IDs, guardian actor, time/duration, type/viewed/saved outcome, file size, camera/mic failure reason, admin name/ID searches) is still linkable **children's personal data** even with zero raw-media VPS files. Risks include behavioral monitoring, domestic/custody misuse, unauthorized support staff browsing and sensitive bystander/call circumstances. Therefore India DPDP under-18 purpose, parent authority, behavioral-monitoring restrictions/exemptions, data minimization, lawful admin access, retention, cross-border hosting, disclosure and Play child-monitoring/data-safety/Families restrictions require feature-specific advice. No assumption that a parent's permission grant or an admin role waives any prohibition.

Production mode should default to no media feature and no real-minor media activity because FR-009/010 remain OFF. If released by independent approval, enforce case-scoped step-up/admin read audit and report any uncertain failure reasons honestly (no speculative 'on call'). Existing HIGH/CRITICAL gates remain unchanged; no real child media pilot approved by this addendum. [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md), [Admin Console Specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md).

## 2026-10-27 precise child GPS 48h local queue + server inbox purpose/retention gate

The owner accepted a technical GPS/usage data-path architecture: Alarka may retain **up to 48h offline GPS coordinates in an encrypted device-local queue** and later send **JSON batches** to **PostgreSQL temporary durable inbox**, then final partitioned PostGIS raw location and derived trips/usage after C++ bulk worker COMMIT. This introduces an **additional sensitive GPS copy**, temporarily held by server inbox/WAL/backup, beyond final raw location and derived history. Although Redis is not required, a PostgreSQL inbox is still child personal data storage; assess guardian authority, India DPDP children’s tracking vs behavioral monitoring restrictions/exemptions, lawful purpose, data minimization, processor/transfers, on-device/offline storage duration, server inbox purge, final retention, restore/delete and administrative read scope. 1–2min periodic upload plan is **conditional on Android OS / Google Play location permissions**.

Earlier CRITICAL/HIGH risk outcomes are **not resolved or lowered** by storing coordinates in JSON or by batching. Real-minor historical tracking/app usage remains release-OFF until counsel/Play approvals. T-ING-01…24 and independently audited security/Android evidence are required. Reference [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md).


## 2026-10-30 Google Play Console AI guidance — G01 and background-location clarification (NON-BINDING)

The project owner received an AI-generated response in the Google Play Console support flow. It stated that (a) the Families precise-location restriction is not overridden by the parental-monitoring policy; (b) declaring a mixed audience may be a possible distribution model only where the actual audience genuinely includes older users, and must not be used to misrepresent an app designed for children; and (c) **background location is not automatically permitted**. The response says background location requires a separate Play Console location-permissions declaration/review and evidence, including the core-feature rationale, in-app disclosure, runtime permission flow, demonstration video and public privacy policy.

**Evidence status:** this is an AI-generated support recommendation, not a human policy-team determination, formal app review, permission approval or binding eligibility decision. Preserve the response/screenshot and obtain a human written response for the actual Madalasa/Alarka architecture. Do not treat its mixed-audience suggestion as authorization to collect child precise location.

**Required project position:**
- Keep G01 CRITICAL OPEN. Do not enable real-child precise-location collection or represent Alarka's Play eligibility as confirmed until the applicable Families/monitoring policy question is answered for the truthful target audience and actual app design.
- Treat background location as a **separate approval gate**, independent of the Families/target-audience question. A monitoring-tool declaration, parent authorization, foreground-location grant or successful Android runtime permission does not itself grant Play approval for background location.
- Before any Play release that requests background location, submit the Play Console location-permissions declaration and obtain the required review/approval; provide the actual core safety feature, prominent in-app disclosure, runtime flow, short demonstration video, accurate store listing and active public privacy policy. Do not claim approval before it is granted.
- Keep the target-audience declaration truthful. Do not add older age groups solely to bypass Families restrictions.
- Continue synthetic-data engineering and OS capability testing only; Android OS permission availability and Google Play policy approval are distinct gates.

**Human support-ticket questions:** (1) Does the Families precise-location restriction apply to Alarka as actually designed and truthfully declared? (2) Does any genuine mixed-audience classification change that answer for child users? (3) Is parent-authorized child monitoring eligible under the monitoring-app policy, and on what exact conditions? (4) Is background location independently reviewable for this use case, and what approval evidence is required? Record the case ID and complete human response in the private evidence register.

## 2026-10-30 G02 — DPDP child real-time location exception and feature-scope legal gate

**Primary-text timing clarification:** G.S.R. 843(E) (13 November 2025) schedules DPDP Act sections 7–10, including section 9, to commence eighteen months after publication (calendar computation: 13 May 2027). G.S.R. 846(E) (13 November 2025) similarly schedules Rules 3, 5–16, 22 and 23, including Rule 12, for eighteen months after publication. Therefore, as at 30 October 2026, section 9 and Rule 12 / Fourth Schedule Part B item 4 are **not yet in force under those commencement notifications**. The calendar date is computed from the printed Gazette date; counsel should confirm the operative date, corrigenda and any later notifications before launch. Sources: G.S.R. 843(E), https://egazette.gov.in/WriteReadData/2025/267647.pdf ; G.S.R. 846(E), https://egazette.gov.in/WriteReadData/2025/267650.pdf ; corrigendum G.S.R. 892(E), https://egazette.gov.in/WriteReadData/2025/268455.pdf.

**What the scheduled text says (not yet operative on this date):** DPDP Act section 9(1) concerns verifiable parental/lawful-guardian consent; section 9(2) prohibits processing likely to cause detrimental effect on a child's well-being; section 9(3) prohibits tracking or behavioural monitoring of children and targeted advertising directed at children; section 9(4) permits prescribed classes/purposes subject to conditions. Rule 12 and Fourth Schedule Part B item 4 specify a purpose for which section 9(1) and 9(3) do not apply: determining a child's real-time location, restricted to tracking real-time location in the interest of the child's safety/protection or security.

**Important limits / interpretation questions:** the text does not expressly say that all continuous location histories, trip reconstruction, school/stop profiling, geofence inference, app-usage monitoring, screen-time records, remote media capture, or broad guardian sharing are exempt. It also does not itself settle whether this commercial parent-monitoring service qualifies for the exception, what data cadence/retention is necessary, or whether a 48-hour offline queue and server inbox are within the permitted purpose. Section 9(2)'s detrimental-effect prohibition is separate from the section 9(1)/(3) exception wording and requires specific legal analysis. The exception is not a blanket authorization for all child data processing.

**G02 status: CRITICAL OPEN for actual feature lawfulness, NOT for mandatory signed counsel paperwork.** Record a dated source-backed owner assessment and seek specialist advice if substantial uncertainty remains. It must:
1. Confirms commencement/effective dates and all applicable transitional/corrigendum/other-law provisions as at intended launch.
2. Determines whether this specific commercial service and its actual guardian/device architecture qualify for the real-time child-safety location purpose.
3. Defines the permissible scope: live location request vs periodic collection, background operation, precision, update cadence, offline queue, PostgreSQL inbox, derived trips, historical retention, geofences, school/stop detection, exports and guardian sharing.
4. Separately classifies app-usage/behavioural monitoring, SOS, media, admin access and device-management features; do not assume the location exception covers them.
5. Assesses section 9(2) detrimental-effect risk, verifiable parental consent/guardian authority, child-facing notice, withdrawal, disputes and grievance handling.
6. Provides a feature-by-feature GREEN / CONDITIONAL / PROHIBITED decision and conditions, retention limits, processor/transfer requirements and evidence to retain.

**Release control:** keep real-minor data ingestion and all unapproved child tracking/usage features disabled. Synthetic fixtures and non-production tests may continue. Do not represent the scheduled exception as currently operative on 30 October 2026 or as legal approval.