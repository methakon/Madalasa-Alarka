# Data Retention Schedule — Candidate Periods / Owner & Counsel Sign-off Pending

> **Document control:** M0 / 03-legal-and-privacy · Proposed owner: Privacy counsel + owner (not assigned) · Registry: DRAFT_LEGAL_REVIEW_REQUIRED; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Document MA-RET-001 | 2026-10-27. Status DRAFT, NOT ADOPTED.** No real child data collection approved. Earlier docs propose **14 days raw GPS**; uploaded draft proposed **30 days**. These conflict; neither is an adopted retention policy. Date/time windows below are candidates for discussion and must be reconciled with purpose-specific India legal and Play disclosures before implementation.

## Current legal reconciliation — 2026-10-30

**Still DRAFT / NOT ADOPTED; real child-data release OFF.** Owner-declared responsible publisher is **Individual SWARNA SEKHAR DHAR, India**, same intended legal/Play publisher. Identity evidence, Payments identity, merchant setup, public support confirmation and legal review remain pending. The declaration approves no retention number or deletion exception.

The [current official-source legal gate](INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md#current-source-grounded-review--2026-10-30) distinguishes current CERT-In/IT duties from future-phase DPDP provisions. In particular, future **Rule 6(1)(e)** refers to one-year retention of the specified security logs and personal data; **Rule 8(3)** separately requires retention of **personal data, associated traffic data and other logs of processing** for at least one year for Seventh Schedule purposes. Its wording must **not** be reduced to a security-log-only rule. Counsel must reconcile its scope with purpose limitation, consent withdrawal, section 8(7)/12 erasure, processor copies and lawful holds before approving the shorter candidates below. This review neither adopts one-year retention of all GPS nor certifies that 14/30-day raw GPS or 30/35-day backups are sufficient.

Rule 8(1)/Third Schedule inactivity periods apply to specified classes/thresholds and purposes, not a general three-year allowance for this app. CERT-In's existing rolling 180-day India ICT-log duty is a separate category; its May 2022 FAQ does not authorize arbitrary child-content retention. SPDI applicability, purpose-limited retention, withdrawal, grievance and transfer/security duties still require full-text counsel review; the legal gate records the limited SPDI retrieval.

Before release, approve a per-store matrix: data category and purpose; applicable commenced law/effective date; exact statutory or necessity basis; minimum/maximum and clock; restricted hold/access; processor and backup/WAL expiry; deletion/tombstone propagation; evidence and review owner. Rights responses must distinguish revoked access, stopped intake, active-store deletion, restricted lawful retention and backup expiry, without claiming impossible remote deletion of independent adult-held copies. Preserve confidential custody/abuse reporting and exact-child authorization; no sibling-wide deletion/access simply from a co-parent invite. All periods below remain candidates subject to this reconciliation.

## Retention principles
- Data purpose + guardian authority are separate from Android grants. Retention measured from **original observation/event time** where applicable, not later upload or batch queue acceptance.
- Offline 48-hour Alarka queue is a **device storage capacity design target**, not permission for unrestricted capture, a universal 48-hour data-retention policy, or a guarantee that the OS will gather data.
- A temporary PostgreSQL inbox contains actual precise child coordinates until worker Tx B; WAL/backups and dead-letter copies must be inventoried and safely minimized. No general admin direct inbox reader.
- Stop future intake with child/device revocation-generation/tombstones **before** deleting existing records so 48h offline retry cannot revive deleted child data.
- CERT-In 28 April 2022 Directions require **secured ICT logs rolling 180 days in India for covered entities**. Do not confuse this with storing **all raw child's GPS, media or app behavior for 180 days**.

## Category decision ledger

| Data | Candidate retention / outstanding decision | Clock start |
|---|---|---|
| Guardian and child identity/pairing/grants | Needed for account; deletion after verified closure, exceptions reviewed | Closure/revocation |
| GPS raw/accuracy/speed | **14 days earlier vs 30 days submitted; OWNER/COUNSEL MUST CHOOSE** | observed_at |
| Encrypted unsynced device GPS queue | Up-to-48h **capacity target**; ACK cleanup/overflow and legal TTL to specify | capture |
| PostgreSQL inbox pending/leased/failed | As short as durable recovery safely permits, specific bound TBD; never drop ACKed data before Tx B recovery | accepted_at |
| Inbox processed payload/WAL and outbox | Purge after verified raw commit/backup retention; bound TBD | processed_at |
| Device event dedup ledger | Minimum replay window including long offline attempts; scrub identifiers on deletion | event / receipt |
| Trip geometry/history/stops/named places | 90 days proposed but unapproved; derived details may require *shorter* period | trip end |
| App usage event/session/aggregates | 30 days proposed but **feature release OFF**, behavioral-monitoring gate | observed period |
| Capability/permission changes | Latest snapshot and limited change audit, candidate 90 days | device report time |
| Command/SOS status | 12 months proposed, justify incident/safety purpose | event |
| Media-activity metadata | 12 months proposed, no VPS media binary; highly sensitive | request/session |
| VPS media contents | **NOT STORED BY DESIGN** | N/A |
| Guardian local encrypted saved media | Parent device/provider's approved controls, not VPS guarantee | local save |
| Admin case/search/access log | Candidate 24 months, restricted and independent audit | audited event |
| ICT authentication/security logs | CERT-In minimum 180 days within India **where applicable** | logged event |
| Subscription/tax/GST invoices | Per actual applicable statutory retention verified by accountant/counsel | transaction |
| Encrypted backups/PITR | 35 days proposed, not verified against RPO/RTO or deletion rights | backup completion |
| Consent/authority verification receipts | Evidentiary purpose, period TBD; no excess documents | recorded decision |
| Data subject/grievance/incident records | Minimized separate legal need, scoped holds with review date | closure/event |
| Anonymous aggregates | Only demonstrably irreversible anonymity | aggregation |

## Rights, erasure and restore requirements
Authenticated guardian/child rights and custody conflicts need safe case handling; no broad co-parent disclosure by default. Revoke new API ingestion and device credentials, publish deletion tombstone, clear raw/inbox/derived data and role-limited caches, and apply deletion ledger on **all restored backups** before reopening APIs. Parent-local/Google Drive content cannot be erased from inaccessible devices instantly. Set realistic advertised processing deadlines *only after service implementation and counsel review*. Backup/WAL expiry and legal hold exceptions must be explained to the person requesting deletion.

## Implementation and gates
- [ ] Publisher/privacy lead and India counsel approve every data category, exact number of days, purpose and legal exception.
- [ ] Resolve **14 vs 30 day GPS** conflict in previous documents; compare storage and history route impact.
- [ ] Implement per-store TTL/partition cleanup, purged inbox payload, restore tombstone, dedup and encrypted backups.
- [ ] Test long offline Android queue, worker crash after 202, stopped child device, deleted child event re-ingestion, wrong-family audit access, and old backup restoration.
- [ ] Ensure privacy notice, Google Play Data Safety and processor agreements agree.
- [ ] Check relevant DPDP provisions' phased legal commencement at actual launch; do not state that every 2025 Rule applies in Oct 2026.

**Official refs:** https://www.cert-in.org.in/PDF/CERT-In_Directions_70B_28.04.2022.pdf ; https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf. Related: [DPIA](DPIA.md) and [Account Deletion](../../M6-guardian-erasure-security/01-data-erasure-and-access/ACCOUNT_DELETION_DESIGN.md).

**No retention or deletion job is authorized to execute on production from this draft.**

## Uploaded MA-RET-001 candidate review and precise owner decision ledger — 2026-10-27

The uploaded retention document proposed numbers for **R-01…R-18**. It was **not signed by the controller/owner or India counsel**. This section preserves its numbered categories and offers its numbers as *options* without silently replacing this file's legal/no-go state. In particular **14-day raw GPS from earlier project drafts versus 30-day raw GPS in the upload remains unresolved**.

| Source ID | Category (uploaded draft) | Uploaded **candidate** | Project-aligned decision / new surface |
|---|---|---|---|
| R-01 | Guardian account | Account life + 30 days after closure | Owner/counsel approval and lawful account/security exceptions required. |
| R-02 | Child profile and paired devices | Until removal + 30 days | Revoke device grants and reject 48-hour delayed uploads **before** row deletion. |
| R-03 | Raw GPS | 30-day rolling | **CONFLICT: older 14 days; neither approved.** Applies final PostGIS observations measured from \`observed_at\`. |
| R-04 | Trips and stops | 90-day rolling | Derived geometry may expose school/home; purpose and shorter alternative to be assessed. |
| R-04a | Named places | Until manually deleted/child removal | Home/school should be handled as especially sensitive locations. |
| R-05 | App usage summaries | 30-day rolling | Separate raw UsageEvents, sessions, daily aggregate TTL; **feature OFF pending India/Play review**. |
| R-06 | Capability and permission change reports | Latest + 90 days history | Keep current authoritative snapshot and bounded revisions, child scopes. |
| R-07 | Command/SOS lifecycle | 12 months | Safety-purpose justification, truthful failure receipts and legal hold handling. |
| R-08 | Media request/session **metadata** | 12 months | No VPS media files; actor/child/time/size/reason metadata are still sensitive. |
| R-08a | Media content | Never stored on VPS | Parent-local encrypted recording and TURN transient traffic are **separate**; no VPS media archive. |
| R-09 | Payments/invoices/GST | Draft "commonly 6–8 years" | **No fixed number adopted**; accountant/counsel must identify each applicable statute. |
| R-10 | ICT/security logs | 180 days direction; 12 months proposed | CERT-In **rolling 180 days within Indian jurisdiction for covered ICT logs**; do NOT apply this to all raw GPS. |
| R-11 | Admin case/read-access audit | 24 months proposed | Strong access restrictions, immutable-style append evidence and deletion/legal holds separate. |
| R-12 | Backups | 35 days proposed | Actual RPO/RTO, PITR/WAL/offsite retention and deletion tombstone restore must be tested. |
| R-13 | Child turns 18 | Consent/authority reset and 30-day deletion proposed | **Verify lawful rights and transition design**; no unilateral silent extension of guardian monitoring. |
| R-14 | Support/grievance | 24 months after closure | Needs grievance rules and risk-based minimization. |
| R-15 | Incident records | 5 years after closure proposed | Depends on incident law, litigation hold and restricted evidence store. |
| R-16 | Parental consent/verification records | Account life + 3 years proposed | Purpose/evidence period and identity-document minimization unresolved. |
| R-17 | Guardian's optional Drive backup | Guardian-controlled | Cannot promise remotely deleting a guardian's inaccessible or copied Drive/phone files. |
| R-18 | Irreversibly anonymous aggregates | No fixed limit suggested | Must confirm non-reidentifiability; home/school routes cannot be deemed anonymous on assertion. |

### Stores added by the accepted GPS ingestion and admin-console architecture

| Surface | Specific proposed retention control required before release |
|---|---|
| Alarka encrypted **48-hour offline capacity** | Size/time quota, durable server receipt, legal TTL, overflow notification; no guaranteed 48-hour GPS capture or unconditional collection. |
| **PostgreSQL durable inbox** | Temporary GPS JSON payload; restrict read roles; process/retry/quarantine safely; purge PROCESSED payload promptly after durable Tx-B/approved retention, not before. |
| PostgreSQL WAL/PITR/offsite backups | Bound each copy's actual lifetime, prohibit restoration of deleted users without tombstone reapplication, verify India hosting/processor scope. |
| Dedup and idempotent device-event ledger | Retain enough for retry/replay window; on child deletion tombstone must block reingest even if local offline queue still exists. |
| Reconstruction jobs/route geometries and latest-location cache | Tie to original GPS purpose and child/grant rights; expire all derived copies as well as raw rows. |
| App usage raw events/sessions/daily aggregates | Treat as separately restricted behavioral data; do not assume summary TTL also covers raw event cache. |
| Independent admin-access audit | Separate case scope, access controls and law-based schedule; staff may not self-erase sensitive audit records. |

### Executable retention gate — NOT YET IMPLEMENTED

The owner must sign a category-specific decision with **retention days, start clock, legal purpose, deletion method, backups/WAL bound, exceptions, reviewer and effective date**. Verify delete jobs using partitions where appropriate and strict transactional tombstones for revoked/deleted children. Test a 48h delayed Alarka upload **after** family deletion to prove it is rejected. If backup restoration or worker replay reintroduces a deleted child's location, the release test **fails**. Do not turn any candidate period above into a production TTL before that signed decision.

The uploaded draft's suggestion to delay a deletion request indefinitely whenever another guardian objects is **not approved**; custody/abuse reports require a confidential, case-based legal decision, not routine sharing or automatic denial. Operational request response targets in the upload (3 business days acknowledgement and 30 days completion) also remain product commitments **to be validated**, not existing statutory SLAs.

Cross references: [Account Deletion](../../M6-guardian-erasure-security/01-data-erasure-and-access/ACCOUNT_DELETION_DESIGN.md), [Data authorization/recovery](../../M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md), [GPS Inbox ADR](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md), [DPIA](DPIA.md).



## 2026-10-27 owner commercial/UI direction — supersedes conflicting historical proposals

**State: owner-approved design direction, NOT deployed, legally signed off, or Play Console/device tested.** Launch is India-first, **manual-renewal Google Play prepaid only**. No automatic renewal, background charge, or charge triggered by opening premium feature; parents explicitly confirm each purchase/top-up in Play. At verified prepaid expiry, downgrade to free: live tracking at a reduced adaptive GPS interval (moving design target approximately 10–15 minutes, slower stationary; no Android timing guarantee), most recent **six hours of visible location history**, and no paid media. Premium requests show payment review instead of silently charging. Deleting the account revokes child/guardian access and future ingest, and cannot generate an auto-renewal; handle any legacy auto-renewing purchase independently if ever issued.

**Price targets per paid child:** public ₹99/month or ₹999/year; founding ₹50/month or ₹500/year for the first **1,008 distinct successfully paying families** counted once each. All eligible paid children in a founding family, including added later, qualify. Founding eligibility persists through prepaid lapses when lawfully recognizable. Automatic eligible early-access offer, no coupon entry, subject to real Play prepaid products/offer support, taxes, fee confirmation and purchase-screen amount. Trial activation does not count as a paying founding family.

**Introductory experience:** once per eligible verified family, 48 hours of conditional Super Access with no auto-conversion, independently server timed. Across the FULL trial per eligible child, shared between authorized guardians: 5 audio minutes (3 min max/session), 2 video minutes (1 min/session), 3 successful photo snapshots, 2 screen-view minutes (1 min/session). Paid Balanced per paid child per month: 60 audio minutes (5 min max/session), 20 video minutes (2 min/session), 30 photos, 10 screen-view minutes (2 min/session). Count confirmed delivered session consumption, not failed OS attempts. Media remains **OFF / P3 conditional research** until Android, legal, Google Play, safety and device gates permit. No implied covert or guaranteed background sensor access.

**No repeated trial:** verify adult parent identity and prior redeemed or paid eligibility server-side, with a minimized bounded lawful anti-abuse ledger; optional Play Integrity/Device Recall subject to availability and review. Reinstall, logout, closure/recreation, or adding a child never restarts a lawfully recognized trial. Do not store child routes, images, microphone recordings, Aadhaar or IMEI to enforce eligibility. Legitimate families incorrectly blocked require review; permanent matching of an erased identity is not guaranteed.

**Storage vs visibility:** six-hour free history is an access limit, NOT a retention authorization. Earlier child location data can only remain for independently approved purpose-specific periods, not automatically until account closure. Deletion revokes token access, cuts off late offline uploads, and erases eligible data including backups as policy dictates. Legal retention, deletion exceptions, guardian authority and cross-border processing remain open gates.

**Parent UI:** replace oversized purple 48h hero with compact off-white/teal-style dismissible trial strip/pill (around 48–64 dp): “✦ Super Access · 47h left” plus accessible close X. The close dismisses marketing banner for the current in-app navigation session, NOT trial entitlement/countdown; a small plan/status entry remains visible. No flashing, support reduced motion. The opening welcome announcement may show once, then small strip; real countdown derives from backend. Trial-ended messaging clearly explains free tracking and manual prepaid upgrade.

**Costing:** existing OCI 1,000-child allocation (~₹3,238/month) explicitly excluded media. Provisional separate ₹3,000/month testing reserve is NOT a TURN/WebRTC provider quote, nor a production capacity promise; measure concurrency, relay ratio, bandwidth, storage, taxes, prepaid Play fees and full operating expenses. Older ₹50/₹500 as universal public pricing, auto-renewing products, 15% auto-renew fee cases, and corresponding revenue scenarios in preceding sections are HISTORICAL and need a full prepaid recalculation. Confirm Play Console purchase/top-up/seat-count/offer behavior before enabling billing.

**Screen consistency and traceability:** base UI source [existing 81-screen Figma handoff](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=6-2) (off-white/teal parent visuals). Update dashboard/map/history trial strip and billing screens P-47/P-48/P-49 plus deletion P-44, capabilities P-46, trial eligibility and media views to show this rule. Do not claim static Figma designs are working Android screens.
