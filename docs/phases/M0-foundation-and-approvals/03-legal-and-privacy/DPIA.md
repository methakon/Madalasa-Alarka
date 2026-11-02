# Data Protection Impact Assessment (DPIA) — Madalasa–Alarka

> **Document control:** M0 / 03-legal-and-privacy · Proposed owner: Privacy counsel + owner (not assigned) · Registry: DRAFT_LEGAL_REVIEW_REQUIRED; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**MA-DPIA-001 | Reviewed 2026-10-30 | DRAFT / NOT APPROVED.** Assessor [UNASSIGNED], security lead [UNASSIGNED], India counsel [UNASSIGNED], Product owner signoff [PENDING]. Responsible publisher/data-fiduciary identity is **owner-declared Individual SWARNA SEKHAR DHAR, India**, same intended legal/Play publisher; **identity evidence, Payments identity, merchant setup, public support confirmation and legal review pending**. No company, GST status, address or email is inferred. Final production region is reserved for deployment, not a local-development prerequisite. **REAL CHILD-DATA RELEASE OFF / NO REAL-MINOR DATA PILOT.**

## Legal and policy interpretation
India's DPDP Act 2023 and 2025 Rules have **phased commencement**. Gazette notices dated 13 Nov 2025 specify many substantive child-data provisions 18 months after publication, subject to amendments. DPIA-specific statutory assessment obligations attach to **notified Significant Data Fiduciaries** under Act section 10; voluntarily drafting this DPIA does not prove this startup has that designation. Child behavioral monitoring is restricted under Act section 9 with **narrow, conditional exceptions**; a hypothesized real-time safety tracking exception must not be extended automatically to historical GPS profiles, app usage analytics, or remote camera/microphone capture. Android OS grants do not substitute for verified guardian authority, proper legal processing or Google Play policy.

Official sources: https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf ; https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023.pdf ; https://www.cert-in.org.in/Directions70B.jsp.

## Current legal reconciliation — 2026-10-30

The [source-grounded legal gate](INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md#current-source-grounded-review--2026-10-30) controls commencement, exceptions and retrieval limits. Section 9/Rules 10 and 12 are future-phase provisions; no unrestricted release is justified by phased commencement. Existing IT Act/SPDI/CERT-In duties require role/data-specific assessment now. The voluntary DPIA does not imply notified Significant Data Fiduciary status.

- Google Sign-In is authentication only, not age/guardian proof. No Family Link dependency; accepted sharing invitations are **one exact child**, with approved authority/consent where required and no sibling/billing-family expansion. Adult verification and custody/dispute safeguards need separate legal and abuse-risk review.
- The real-time safety-location exception cannot be assumed to extend to route history, app usage, DPC controls, predictions, media or media metadata. Consent does not itself disapply behavioural-monitoring restrictions. Keep each unapproved purpose OFF.
- Add to R13: future Rule 8(3) expressly covers **personal data, associated traffic data and other processing logs**, not security logs alone. Resolve it with Rule 6(1)(e), erasure/withdrawal, processor copies, holds and backup restoration before accepting short candidate GPS/backup TTLs. No one-year blanket GPS policy or unconditional immediate-erasure promise is adopted.
- Add to R11/R12: keep CERT-In six-hour reportability/India ICT logs separate from future DPDP breach notices (without-delay initial intimation plus specified 72-hour detail). Confirm the applicable grievance regime, including **2026-amended** intermediary deadlines if that role applies. Neither an app-support email nor the owner's declaration proves a staffed statutory contact or grievance appointment.
- Actual vendor roles, valid processor contracts where required, region/transfers, subprocessor copies and deletion evidence remain unapproved. Individual publisher status does not automatically exclude commercial data-security obligations.

**Residual disposition unchanged: NO-GO.** The owner declaration resolves the identity choice, not verification, signoff, contractual or implementation gates; no real child-data processing or external identity-document upload is authorized.

## Proposed processing and deployment reality
| Activity | Data/source | Status |
|---|---|---|
| Guardian pairing and child-specific grants | Adult identity/child/device and permission receipt | M1 contract+SQL test only |
| Location/live safety | GPS, time, accuracy, speed, phone/watch source | DESIGN, release gated |
| Detailed history/trips/named places | GPS path, school/home inferences | RESTRICTED, separately release gated |
| App usage sessions | Package name/activity timestamps, duration | P3/behavior monitoring gate OFF |
| Capability and permission report | OS sensors/support/Android grant scopes | DESIGN; read-only scan before grants |
| SOS and command receipts | Guardian action, location/event receipt | DESIGN, no emergency delivery guarantee |
| Remote mic/camera/screen/AV | Live media transport and local optional recordings | RESEARCH ONLY OFF, no VPS media files |
| Media metadata history | Who/when/requested/viewed/saved, duration/filesize/failure | DESIGN, child-linked sensitive |
| Administrator support | Parent/child name+ID autocomplete and media/event audit | DESIGN; case/MFA read audit required |
| Local location queue | Up-to-48h encrypted device capacity target | DESIGN, not always-on guarantee |
| GPS durable PostgreSQL inbox | Temporary raw JSON GPS and WAL/backup | DESIGN, additional sensitive copy |
| Derived trip/usage | PostGIS location, outbox, aggregated sessions | DESIGN, worker not implemented |
| Vendor services | OCI/Google/Maps/FCM/Drive/Play Billing, optional TURN/SMS | Not finally contracted |

The 2026-10-27 baseline did not verify a deployed Android application, backend, production database or restored offsite backup. This legal-document review does **not** certify the current build/signing/deployment state. Historical Chicago/India hosting scenarios are not selected infrastructure; final deployment region and processor contracts remain unconfirmed.

## Data flows and trust
Alarka OS → encrypted local queue → authenticated child-bound HTTPS → Drogon Tx A durable PostgreSQL inbox **after commit HTTP 202** → C++ leased bulk worker Tx B raw location+dedup+outbox → separate trip worker → authorized Madalasa. 202 inbox queued is not live GPS/trip completion. UsageStats is separate, may be delayed, and needs independent processing authority. All live content feature flags OFF. Admin roles by default see aggregate metrics; named child access needs MFA, approved case/purpose and separately logged reads.

## Risk register (initial qualitative; residual untested)
| ID | Threat | Baseline risk | Safeguard before pilot |
|---|---|---|---|
| R1 | Abusive/unauthorized adult links or tracks a child's device | CRITICAL | verifiable guardian identity/authority, safe dispute/grievance, visible Alarka |
| R2 | Cross-family or same-family wrong-child location leak | CRITICAL | app child scope + Postgres forced RLS, negative tests |
| R3 | Child behavioral/app usage profiling unlawfully processed | CRITICAL | India legal review, purpose gating, feature OFF |
| R4 | GPS history exposes school/home routes | HIGH | time/precision minimization, separate history retention and scope |
| R5 | Alarka stolen/rooted exposes 48h local coordinates | HIGH | actually encrypted queue/KeyStore, battery/OS evidence |
| R6 | Temporary Postgres inbox/WAL/backups leak GPS | CRITICAL | DB least privilege, encryption, TTL, backup/legal/region checks |
| R7 | Deleted child revived by offline queue or restored backup | CRITICAL | revoke generations/tombstones before ingestion/read, restore drill |
| R8 | Administrator enumerates or exports named child histories | CRITICAL | exceptional MFA case, audit fail-closed, no global root data rights |
| R9 | OS capture performed without lawful child transparency | CRITICAL | media P3 OFF, Android indicators and per-session consent |
| R10 | False live GPS/usage/SOS status makes guardian rely on missing service | HIGH | last observed/ingested/reconstructed indicators, unavailable reasons |
| R11 | No 24×7 incident owner or India CERT-In logs | HIGH | contact, 6-hour reportability triage, India ICT-log store |
| R12 | Insecure Android signing, supply chain or vendor transfer | HIGH | audited signing, SBOM, signed vendors/contracts, Play review |
| R13 | Ambiguous raw GPS 14 vs 30 day retention | HIGH | sign unified retention schedule, erase and restore tests |
| R14 | Multiple devices/proxy watch location misidentify child | HIGH | provenance/source selection, uncertainty and gaps |

## Necessity and less intrusive alternatives
- Prefer event-driven SOS/guardian initiated child check-in over indefinite high-resolution tracking where feasible.
- If lawful safety current-location scope qualifies, preserve a narrow version; do not assume unrestricted path history or UsageStats.
- App usage: on-device-only summary or disabled until independent India/Play judgment.
- Media: do not implement covert remote sensing; OS user action and visible indicators remain.
- Parent map draws actual verified points; optional road matching must be labelled estimated, never reconstruct invented turns.
- Raw media is **not stored on VPS**, but media metadata and parent-local saved content remain relevant personal processing.
- Minimize persistent child GPS copies, choose direct bulk if equal resilience with less resource use after benchmark; current accepted default durable inbox+bulk requires explicit TTL.

## Required approvals & acceptance evidence
- [ ] Verify owner-declared Individual SWARNA SEKHAR DHAR as responsible legal/Play publisher; complete pending Payments/merchant/public-support evidence. India counsel confirms actual statutory commencement, exemptions, privacy notice and Play Families/monitoring restrictions.
- [ ] Verified guardian consent/authority with child safety complaint process; under-18 and adulthood transition handling.
- [ ] Data retention including 14 vs 30 day raw GPS conflict; inbox, WAL, backup purge; data subjects rights and deletion.
- [ ] OCI region, vendor DPAs and Indian ICT security log storage decided; restore and incident-reporting drill.
- [ ] STRIDE and independent security review, Android device permission/OEM proof, signed APK/CI/SBOM, RLS/sibling negative tests.
- [ ] T-ING-01…24, T-CAP-01…24, T-AUD-01…22, T-ADM-01…14 performed with synthetic/adult fixtures and recorded.
- [ ] Product owner, security lead, legal officer, grievance lead sign a GO decision with date/version.

**Risk disposition:** real-minor pilot **NO-GO** and commercial Play release **NO-GO**. Assessment to be revised on new feature/vendor/law, and annually after full ownership assigned.

## 2026-10-27 comparison with uploaded MA-DPIA-001: extended processing inventory and risk disposition

The uploaded 146-line assessment enumerated 12 processing activities and risks **K-01…K-18**. The existing project DPIA above is more current on **2025 DPDP phased commencement**, the unverified OCI region, device-local encrypted 48h-capacity buffer, PostgreSQL temporary GPS inbox/WAL, and no verified app deployment. Those safeguards and NO-GO gates remain authoritative. This appendix preserves useful uploaded assessment categories not otherwise explicit while avoiding unsupported legal conclusions or pretending residual risk is mitigated.

### Additional data-subject and purpose questions to sign off

| Activity originally identified | Review before processing | Less intrusive/default treatment |
|---|---|---|
| P1 Adult sign-in, Google identity, guardian/child pairing | Verified parent/legal guardian authority, safety of disputed custody and child consent/transparency; no assumption any signed-in adult can see GPS | **Only paired child-scoped owner roles**, incident-safe revocation and no default admin viewer |
| P2 Current location and speed | Real-time safety exemption eligibility must be legally **proved for this product**, not presumed from Android permission | On-demand/limited precision and age of last observation; release OFF until counsel |
| P3 Trip history, route stops and named places | Home/school inference, other family members, multi-day profiling; risk independent of current-location view | Separate purpose switch and shorter raw/derived retention; observed route not invented |
| P4 App UsageStats/managed app controls | Behavior monitoring prohibition/exemptions, special Android permission and truly provisioned device-owner controls | **Default OFF**; consider device-local aggregate only if independently lawful |
| P5 Capabilities and permission audits | Device metadata may identify a child; avoid immutable/unlimited hardware fingerprint | Store minimal allowlisted and versioned statuses with freshness |
| P6 SOS/safety checks | Misleading delivered/accepted vs received by humans; SMS/FCM reliability | Explicit qualified acknowledgment and external emergency advice |
| P7 Remote audio/camera/screen and file browsing | Bystanders, consent each screen session, OS sensor startup prohibition, guardian misuse | **Research P3 OFF**; no covert operation, persistent identification/indicators |
| P8 Media **activity** metadata (not binary media) | Who observed a child, duration, verified failure; this is child-related personal data even without files | Scaled-minimal events, nullable size, no file content; parent and case-scoped admin |
| P9 Guardian-authorized Drive backup | Independent third-party retention, regional transfer and deletion | Optional and revocable; no universal deletion promise for copies |
| P10 Subscription, billing and tax | Publisher declared Individual SWARNA SEKHAR DHAR; Payments identity/merchant setup pending; receipts/tax applicability need accountant | Manual prepaid renewal only; minimal billing reference, no card numbers or inferred GST status |
| P11 Administrator panel | Broad child-name/ID autocomplete is an enumeration surface | Case/purpose/MFA + separate audited read, fail-closed if audit fails |
| P12 Security/auth/operational logs | CERT-In covered ICT logs, not an excuse to retain raw GPS for 180d | 180-day India secured **ICT log** obligation assessment separate from GPS TTL |

### Uploaded risk crosswalk and additional risks to own

| Uploaded ID | Concern | Action incorporated here |
|---|---|---|
| K-01, K-02 | Child location leak; cross-family access | Existing R1/R2/R4/R6 CRITICAL/HIGH; add child-vs-device and wrong-sibling checks |
| K-03, K-04 | Stalking by non-guardian; custody and abusive adults | R1 and admin/guardian protection; confidential abuse escalation without alerting accused person |
| K-05, K-06 | DPDP child monitoring and Google Play/Families rejection | **Blocker still CRITICAL**, not reduced by permission grants or India hosting |
| K-07, K-13 | Retention creep, erasure and rights | No valid 14/30-day GPS choice; require backup/offline queue/inbox/tombstone tests |
| K-08 | Support/insider browsing | Case-specific MFA, expiry, independent admin read audit; no universal root |
| K-09, K-10 | Vendors and offshore transfers | OCI region and FCM/Maps/TURN/Drive processors to be confirmed |
| K-11 | SOS failure as safety risk | Add negative end-to-end acknowledged delivery test and honest status |
| K-12 | Media misuse | Feature OFF; no raw VPS media but parent-local captures may exist |
| K-14 | Single-VM / no verified restore | Verify offsite backup, RPO/RTO, DNS/TLS, deleted-child nonresurrection |
| K-15 | Child reaches age 18 | Age transition, withdrawal/authority reset and delete/limit workflow remains unsigned |
| K-16 | Incident notice late | Named IC/legal, CERT-In 6h covered categories; phased DPDP Rule 7 review |
| K-17 | False privacy notices or Google Play Data Safety entries | Reconcile policy to actual code/telemetry pre-launch |
| K-18 | Child unaware of monitoring | Plain-language child-app onboarding, visible identity/notifications and clear permission changes |

**Residual-risk rule:** uploaded draft listed some residual risks as Low/Medium assuming mitigations. These are **predicted only, not evidenced**. Until hardware, law, RLS, security, deletion and incident controls are actually tested, high-risk rows must remain **unaccepted**. No DPIA sign-off by writing an appendix.

### Controller/assessor sign-off and alternatives record (blank by design)

- Legal publisher/controller: **UNDECIDED**; privacy lead: **UNASSIGNED**; India counsel: **UNASSIGNED**; date/signature: **PENDING**.
- Actual deployment region/processors/India log residency: **UNVERIFIED**; previous Chicago cost plan not a live deployment.
- Feature-by-feature basis: real-time location [PENDING counsel]; historical GPS [PENDING counsel]; app usage [PENDING counsel]; media [OFF]; case-scoped admin [PENDING owner/security/privacy].
- Data deletion categories: [Retention Draft](DATA_RETENTION_SCHEDULE.md) has conflicting **14 vs 30 days** raw GPS and no adopted period.
- Data-subject consultation, age/guardian evidence, information security test, physical device/OEM, policy gate and signed GO/NO-GO record: **NOT EXECUTED**.
- Re-evaluate this DPIA after materially changed backend ingest (inbox/backup), new admin access, device/age policy, Google Play policy, legislation or any SEV-1/2 incident; annual review if an owner has been assigned.

**Verified external source pointers** (re-check official texts and commencement on actual launch): DPDP Act 2023; Gazette G.S.R. 843(E) 13 Nov 2025 (phased commencement): https://egazette.gov.in/WriteReadData/2025/267647.pdf ; DPDP Rules G.S.R. 846(E) 2025; Google Play monitoring policy: https://support.google.com/googleplay/android-developer/answer/9888380 .

**Position:** Synthetic development may proceed. NO real child GPS, usage, media or admin named-child logs and NO Play release until the actual M0 release gate is signed.

