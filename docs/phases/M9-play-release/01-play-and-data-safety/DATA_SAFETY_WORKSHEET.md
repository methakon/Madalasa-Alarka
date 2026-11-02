# Data Safety and Permission Inventory — Working Worksheet

> **Document control:** M9 / 01-play-and-data-safety · Proposed owner: Play release owner + counsel (not assigned) · Registry: DRAFT_LEGAL_REVIEW_REQUIRED; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product:** **Madalasa** (parent app) + **Alarka** (child app); the GitHub repository is now **[Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka)**. [English mythological inspiration](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

## Current package-by-package release worksheet — 2026-10-30

**Draft / not a Console answer / no submitted declaration.** India Individual publisher: **SWARNA SEKHAR DHAR**; planned children **0–17**. Public contact/address and grievance/privacy contacts pending. Owner Payments identity, merchant/legal/tax information pending. Final hosting region/processors are deployment decisions; older Chicago text is historical, not a mandate. Data Safety must be reconciled to the actual released binary, all included SDKs, backend, every active track and enabled flags **separately for Madalasa and Alarka**.[13]

Use [Parent/Child checklists](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md) and the [91-row inventory](../../M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md). Rows below are complete **planning categories**, not a claim all candidate features ship. `P` = Madalasa parent, `C` = Alarka child, `W` = separate web/back office; **TBD** means unanswered until actual build/data-flow evidence. Server-only W information is not automatically collected by an Android package; disclose any app transfer/SDK collection that actually occurs. Child data appearing on P still needs correct P-side data-flow analysis.

### Per-data-category decisions to resolve for each package

| ID / category candidate | P flow / purpose | C flow / purpose | Recipient / copies to examine | Required vs optional / controls | Retention / deletion / evidence |
|---|---|---|---|---|---|
| DS01 Personal info: adult name/email/OIDC ID | Sign-in, recovery, child invitations | Pairing receives minimal authorized adult display data, not password | Google identity, backend, scoped co-parent recipient | Account core if enabled; authority verification distinct from login | Approved authority/identity ledger TTL TBD; no token/email in logs |
| DS02 Child alias/child ID/grant links | Select exact authorized child, invite/revoke, seat assignment | Device bound to one child | Backend, exact-child guardians only; admin masked projection | Pairing core; optional sharing default none | Erase/revoke/grant-dispute tests; no implicit siblings |
| DS03 Device/other IDs and push tokens | Own installation/session/FCM if used | Device credential reference/installation/push token | Backend, FCM/provider; never raw device key | Core security vs optional push decision TBD | Token rotation, delete/unpair, SDK data audit |
| DS04 Device capability/permission metadata | Read authorized last-confirmed snapshot | API/model/hardware/mode/grants/version/times; no capture during scan | Local cache, backend snapshot/change audit, P projection | Minimize core compatibility; optional feature-specific grants | Snapshot/change retention TBD; monotonic report, revoke/ACK/freshness tests |
| DS05 Precise/approximate location | Receive child fixes/map; own-location recenter only if separately enabled | Collect time/accuracy/provider/speed and location as lawfully allowed | Local encrypted queue, HTTPS inbox, PostGIS/raw/derived, WAL/backups, scoped P; maps/provider flows | Separate live/history purposes; deny/revoke; Families gate unresolved | Every copy TTL/purge TBD; six-hour free visibility ≠ retention[10] |
| DS06 Derived trips/stops/places/geofences/commute | Place titles/radii, route history/playback/confidence | Optional geofence subset; report eligible events | Backend derivatives/alerts/cache, map/roads provider if chosen | History/behavioral child-purpose approval separate from live safety | Late data/revision/erase/backups; provider retention/license evidence |
| DS07 App activity: child installed apps/usage | Receive usage summaries; configure managed rules | UsageStats intervals/selected app inventory after Settings grant | Separate usage queue/backend aggregates, authorized P only | Conditional optional module; Usage Access revoke; narrow package visibility | Legal purpose/retention TBD; missing data not zero; no admin child-behavior feed |
| DS08 App activity: commands/policies/viewer leases | Authorized action/lease/policy request and outcome | Device execution/grant/expiry receipt | Backend/audit/cache, scoped adults | Feature-dependent; actual effect separate from delivered command | Minimized metadata TTL TBD; expiry/replay/revoke tests |
| DS09 Health/battery/connectivity/alert status | Last confirmed status, notification/ACK | Battery/charge/last-seen/permitted heartbeat | Backend + P; lockscreen summaries redacted | Piggyback normal sync; no high-rate polling | No claim current settings known when device silent |
| DS10 SOS/check-in/messages | Receive/ack best-effort alert; optional typed support text | Child-visible SOS/check-in; last fix only if authorized | Durable queue/outbox/notification recipients; fallback only if selected | Child-initiated, no mic needed; chat separate candidate OFF | Delivery vs ACK; deletion/abuse/retention review; no emergency-dispatch claim |
| DS11 Photos/videos/screen content | Future receive/live display/explicit encrypted local save | Future authorized capture / selected file transfer | P2P or encrypted relay, device buffers, parent-local storage; optional Drive; **no VPS media files** | **P3 media OFF**; per-session screen consent, scoped files; no financial/unknown screens | If ever enabled, inspect content processing/recipients/backups, not blanket “no collection” |
| DS12 Audio files/live audio | Future receive/explicit local recording | Future microphone session | Same proposed endpoint/relay/local-copy surfaces; no VPS recordings | **P3 OFF**; visible authorized session, one-time grants/revoke/stop | No call interception; no “on call” inference from silence; deletion of independent copies described |
| DS13 Media activity and access audit metadata | Own-child paged metadata; view/save receipt | Verified request/start/stop/error evidence | VPS metadata/session IDs/times/duration/nullable file size/network bytes; separate W case-read audit | P3 OFF; sensitive linkable metadata; parent-local save is historical receipt only | Retention/admin audit TTL TBD; no paths/thumbs/content/transcripts in logs |
| DS14 Purchases/financial info | Play purchase/top-up, child entitlement/founding/add-on states | Entitlement projection only; no child payment capture | Play/backend verified token vault/reference and masked ledger; staff masked financial projection | Explicit manual prepaid only; stop further top-ups; refund route separate | Financial legal exceptions/periods TBD; no card/PAN/CVC/payment credentials in app backend |
| DS15 Files/documents and Drive auth | Optional consent/selected backup; token storage and revoke | Only app-owned or OS-selected URI scope | Device/cache/approved transfer, Google Drive if activated | Optional P2; narrow OAuth, no Gmail inbox scope for sign-in | Revoke stops future access; separate parent/Drive copies not falsely promised deleted |
| DS16 Crash/diagnostic/performance and support | Opt-in redacted packet, sanitized support ticket/reply | Bounded errors/queue health, no raw sensor payload | Actual SDK/provider/backend/support staff | Required security vs optional diagnostics decided by actual flow | SDK network test, minimization/redaction; TTL/deletion TBD; attachment OFF unless reviewed |
| DS17 Security/consent/authority/trial-abuse ledger | Consent version, approved authority, bounded prior trial/paid eligibility | Enrollment generation/device access security | Backend/protected verification service if selected | Legal necessity review; no Aadhaar/IMEI/child routes/media for eligibility | Retention exception must be narrow/legal; no permanent erased-identity matching guarantee |
| DS18 W-only admin applicants/FAQ/support/service-usage | P submits own support and parent-service metadata only if enabled | No staff-profile collector or sensor route | Web OIDC verified sub/MFA/role; applicant contact/profile; FAQ revisions; parent service duration/outcome; audit | DOB/address/gender necessity/mandatory status pending; no root child-privacy override | W notice/DS scope review; staff role+case+audit, failure denies sensitive reads; erase/retention TBD |

### Mandatory answer worksheet (repeat for P and C, each released category)

| Field | Madalasa answer | Alarka answer | Evidence before signoff |
|---|---|---|---|
| Final package/version/track + manifest/build SHA | TBD | TBD | Read actual signed candidate; no invented applicationId |
| Collection off device, including SDK behavior | TBD per DS row | TBD per DS row | Reproducible network trace + SDK documentation + server route |
| Sharing and applicable exceptions | TBD per recipient | TBD per recipient | User-initiated parent sharing/service-provider exceptions analyzed against Play definitions, not assumed |
| Ephemeral processing | TBD per data flow | TBD per data flow | Only in-memory/no longer than request qualifies; persisted inbox/WAL/audit is NOT ephemeral |
| Required/optional and purpose checkboxes | TBD | TBD | Match actual functionality/account management/security/other justified purposes; not default analytics |
| Encryption in transit (including SDK traffic) | UNVERIFIED | UNVERIFIED | All endpoints/relay/TLS evidence; no blanket E2EE claim |
| Account and associated-data deletion + web link | UNVERIFIED | UNVERIFIED / enrollment-specific rights | Live authenticated request test, public landing page, processor/backup erase and exceptions[14] |
| Retention per category/store/backup/dead-letter | TBD | TBD | Approved purpose/TTL + executed deletion/replay/restore tests |
| SDK/version/processors/region/legal transfer | TBD | TBD | Actual SBOM/SDK disclosures, DPAs, approved deployment selection |
| Final review/signature/date and saved Console response | NOT SIGNED | NOT SIGNED | Owner + engineering + privacy/legal, then Console owner submission |

Off-device ephemeral processing **still needs inclusion in the form response** under Play guidance, though qualifying ephemeral data may not be shown on the public label. No VPS media archive is not “no collection”: endpoint processing, transport/relay, optional local/Drive saves, metadata and SDK traffic must be assessed. “Shared” has defined exceptions; neither declare all parent transfers shared automatically nor declare “not shared” merely because a parent requested them.[13]

### Prepare-now, implementation and owner gates

- **PREP now:** category/permission/processor inventory, pair of draft responses and disclosures, explicit feature OFF list, synthetic test plan, public notice/deletion/contact text with clearly unresolved fields.
- **BUILD later:** actual manifest/SDK/traffic inventory; read-only scan vs capture separation; version/capability preflight before ACCEPT; visible monitoring/sensor flows; no financial capture/fail-closed unknown; retention/erasure/restore/purchase tests; redacted evidence per exact build.
- **OWNER/COUNSEL/CONSOLE:** purpose-specific India child consent/legal opinion, Families/monitoring/location eligibility, retention and processor/transfer approval, publisher public details, Payments/merchant identity and catalog, accurate signed final forms. No real child data, credential creation or Console submission performed.

### Official sources (retrieved 2026-10-30)

## Sources

[10] https://support.google.com/googleplay/android-developer/answer/9893335
[13] https://support.google.com/googleplay/android-developer/answer/10787469
[14] https://support.google.com/googleplay/android-developer/answer/13327111

---

## Earlier inventory (candidate history; current worksheet above governs)

**Madalasa–Alarka | Draft | 2026-10-25**

**Do not submit these rows verbatim to Play Console.** Final declarations must be taken from the actual compiled parent and child apps, included SDKs, endpoints, storage behavior, and third-party recipients. Fill one worksheet **per package** and **per release track**. “Potentially collected” does not mean an enabled shipped feature.

## 1. Data inventory

| Data type | Collection source | Why needed | Recipient/storage | User control | Play disclosure review |
|---|---|---|---|---|---|
| Parent account identifier and email | Parent authentication | Pairing, account access, support | Auth provider and backend | Account deletion | Personal info / account |
| Child device identifier and app version | Enrollment | Pairing, support and security | Backend | Unpair/delete | Device or other IDs |
| Precise/approximate location and time | Child location API | Map and route history | Backend and authenticated parent | Turn off/revoke, retention/delete | Location; determine precise/approximate |
| Travel speed and movement | Location provider | Trip report | Backend and parent | Retention/delete | May be derived from location |
| App package usage duration | UsageStatsManager | App usage report | Backend and parent | Usage Access revoke, delete | App activity |
| Installed app package inventory | Scoped package query, only if feature ships | Configure app limits | Backend if transmitted | Disable feature/delete | App info/activity |
| Policy and command/audit metadata | Parent + child | Controls and security | Backend | Retention and deletion | App activity/device metadata |
| Crash logs/performance telemetry | Optional diagnostics SDK | Reliability | Backend or named vendor | Diagnostics preferences | App performance / device IDs |
| Authorized photos/videos | Only if a released media feature works | User-approved media backup | Proposed P2P/relay + encrypted parent-local; optional approved Drive; no VPS media files | Feature-specific delete | Photos/videos |
| Authorized audio | Only if a released audio feature works | Explicit approved recording | Proposed endpoint/relay + encrypted parent-local; optional approved Drive; no VPS audio files | Feature-specific delete | Audio files |
| Subscription purchase token/entitlement | Play Billing backend verification | Entitlement and fraud prevention | Billing provider/backend | Account support/delete subject to legal retention | Purchases/financial category review |
| Drive OAuth token reference | Parent Google consent | Upload access | Encrypted secret store | Revoke integration | Authentication/integration data review |
| Push token | FCM if enabled | Wake/sync hints | Google FCM and backend | Re-pair/revoke | Device identifiers/SDK review |

## 2. Column-by-column Play Console investigation

For **every** shipped data category answer and document:
1. Collected from device? Transmitted off device? Stored only ephemerally? (Follow current Play definitions.)
2. Is transfer encrypted in transit?
3. Is collection required for core function or optional?
4. Purposes: app functionality, analytics, fraud prevention/security, account management, personalization or other (choose only truthful purposes).
5. Shared with whom? Evaluate processors/service providers and parent recipients using Play's official sharing definitions.
6. Is deletion request supported? Exact process and retention exceptions?
7. Is the feature on in the child package, parent package, both, or neither?

## 3. SDK/processors register (unresolved)

| Processor/SDK | Planned reason | Status | Before release |
|---|---|---|---|
| Google Maps SDK | Parent map | Planned, not integrated | Review data handling / Android SDK policies |
| Google Play services location | Child location | Candidate, not integrated | Audit services and data transmissions |
| Firebase Cloud Messaging | Command wake signals | Optional, not integrated | Audit SDK and registration tokens |
| Google Play Billing | Paid digital access | Planned | Audit purchase metadata and SDK data |
| Google Drive API | Parent media backup | Planned | OAuth scope and token storage review |
| Authentication provider | Parent sign-in | PROPOSED Google Sign-In via Credential Manager | Confirm vendor terms and what Google receives |
| Crash reporting | Reliability | None selected; off | Decide before any SDK is added; child location must never reach it |
| Hosting/database provider | Telemetry storage | PROPOSED Oracle OCI Mumbai | Region, DPA, access and retention |

## 4. Permission mapping to function

| Permission/privilege | Required? | Feature | Review task |
|---|---|---|---|
| Fine/coarse location | Candidate P1 | Latest position, routes | Runtime prompt and disclosure |
| Background location | Candidate P1 | Background tracking | Separate grant + Play permission form/video |
| FGS location | Candidate P1 | Running location service | FGS declaration and notification |
| Usage Access | Candidate P1 | App usage history | Settings onboarding, revocation |
| POST_NOTIFICATIONS | Candidate | Status and monitoring notification | Permission state and required visibility |
| Device owner | Optional managed mode | App suspension | Managed enrollment + separate review |
| Camera | Deferred | Approved capture only | Feature not in manifest if not shipped |
| Record audio | Deferred | Approved capture only | Feature not in manifest if not shipped |
| Broad package visibility | Avoid by default | App discovery | Justification and Play permission form if requested |
| Read arbitrary private files | Not supported | None | Do not request or promise |

## 5. Retention and security blanks (must complete)

Values marked **PROPOSED** come from [Owner and legal recommended resolutions](../../../OWNER_AND_LEGAL_RECOMMENDED_RESOLUTIONS_2026-10-27.md).
They are engineering proposals, **not approvals**: do not submit them to Google Play until the owner signs and counsel reviews.

- Default location retention: **PROPOSED raw GPS 14 days** (blocker B-07)
- Default usage retention: **PROPOSED off by default; if enabled 90 days** (B-07)
- Media retention and Drive copy ownership: **OPEN** (media release is not decided, B-16)
- Audit/security logs retention: **PROPOSED 365 days** (legal minimum under review, G03)
- Backup deletion lag: **PROPOSED 30 days**
- Primary hosting region: **PROPOSED OCI Mumbai ap-mumbai-1, Hyderabad fallback** (B-08, not provisioned)
- Company/controller legal name and contact: **OPEN, owner must supply** (B-01)
- Subprocessors and DPAs: **PROPOSED list**: Oracle (hosting), Google (sign-in, FCM, Play Billing); DPAs not signed
- Whether encryption covers all endpoints and backups: **Requires verification** (TLS in transit is in the contract; backup encryption unbuilt)
- Deletion request completion SLA and legal exceptions: **PROPOSED 30 days; backups roll off within the backup window; legal holds listed in the deletion page** (counsel to confirm)
- Parent authentication and age/authority verification policy: **PROPOSED Google Sign-In plus an adult/guardian declaration; verified-consent method OPEN with counsel** (OCI-06)

## 6. Final signoff record template

```text
Release version:
Package:
Build SHA / manifest SHA:
All runtime permissions verified: [ ]
SDK inventory verified: [ ]
Data category rows reconciled with network traffic: [ ]
Retention and deletion measured: [ ]
Public privacy policy URL verified: [ ]
Account deletion web URL verified: [ ]
Play Data safety responses saved:
Reviewer / approval:
Date:
```

## Source

https://support.google.com/googleplay/android-developer/answer/10787469

https://support.google.com/googleplay/android-developer/answer/13327111

https://support.google.com/googleplay/android-developer/answer/9859455

## India child data and cross-border review gate — 2026-10-26

Historical hosting scenario: OCI Chicago (United States), not an approved deployment mandate; final region/processors/transfer assessment remain deployment gates. Do not answer Data Safety as if all child information necessarily remains in India. Publisher selection is SWARNA SEKHAR DHAR, Individual, India; contacts/address and purpose-by-purpose Indian DPDP Act s.9, Rule 10/12 (real-time safety exception **not blanket monitoring exemption**), section 16 transfer and retention are still undecided. Child historical GPS, app-usage/behavioural monitoring, guardian invitations and SOS messages need separate documented purpose and processor review before category declarations. Google Maps/FCM, Play Billing, parent login and optional SMS/Drive must be classified by **actual integrated SDK data flows**, not architectural possibilities.

Reference: [Indian minor privacy and Chicago legal gate](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md), [Privacy Policy Draft](../02-public-legal-drafts/PRIVACY_POLICY_DRAFT.md). Until adult parent identity verification, lawful-processing opinion and signed product scope exist, **do not collect real child data** or claim a completed Data Safety form.



## Package-specific naming

Prepare separate actual Google Play Data Safety submissions for **Madalasa** (guardian Android package) and **Alarka** (child companion), matching SDK/API behavior and declared purpose. Repository rename does not change applicationIds or publisher account identifiers automatically.

## 2026-10-26 proposed P2P media flow and parent explanations (research only)

The owner accepts conditionally feasible live audio/recording, remote camera/snapshots/video, MediaProjection consent per session, and scoped file/media access as **technical research**. A possible architecture encrypts capture on Alarka, sends direct P2P or via encrypted TURN, stores **no media files on VPS**, and optionally encrypts recordings on Madalasa. The **actual eventual released** Data safety inventory must still include capture/transmission, signaling/IP/session metadata, child disclosure and permission scope, device storage and backups, optional Google Drive transfers and subprocessors. No VPS media archive does **not** mean no collection or processing. Public disclosures require evidence of the delivered architecture.

Parent sees actual device-verified `Command.status + reason_code` for unavailable operation, including revoked media grant, permitted sensor context absent, or child screen-share consent needed. Alarka Activity normally closes after setup but monitoring notification and OS indicators remain visible. Commercial CAMERA/RECORD_AUDIO/MediaProjection permissions remain disabled/not included unless later approved by India legal, OS/OEM, security and Google Play gates. Reference: [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md).

## 2026-10-27 permission and capability metadata inventory (planning only)

Initial Alarka scan may create **device compatibility metadata** (model/manufacturer/API, reported camera/microphone/GPS support, permission and special-access states, managed role, last verified timestamp, selected-media *scope type* without filenames). Store only an allowlisted, minimum required subset **after device pairing**, not a hardware advertising/fingerprinting dossier. Authentication/signaling metadata and permission change history are potentially personal data and require data-category purpose/retention, rights/deletion, cross-border subprocessor and accurate Google Play Data Safety analysis. Raw media, sensor readings or child location should **not** be collected during scan. Child phone/parent phone/server each sees only authorized report projection; temporary pickup viewer should not automatically gain detailed sensor metadata.

OS grants remain in Android, **not** stored or conferred as permission tokens by Madalasa/VPS. Device authenticated snapshots + version/received timestamps are server data, permission revocation history requires bounded retention and restore-safe deletion. Negative statuses, selected-photo subsets and per-session MediaProjection approvals must be truthful. [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md). All protected child feature processing remains gated by counsel/Play; no real-minor media authorization implied.

## 2026-10-27 media-activity metadata and admin access logging data inventory

Potential release-gated new child-linked data category: media request/session **metadata only** (child/guardian/device IDs, audio/image/AV type, view/record/save intent and verified outcome, session timestamps/duration, parent-local saved file size if confirmed, bytes transferred separately, failure codes/evidence, changed-at and actor). No media content files on VPS, but this data can reveal when and how children were monitored. Separate administration access logs include who searched children and parents by approved case/purpose/time, query result count and whether denied. Names should be resolved on authorised query, not duplicated through lifecycle event records.

Classification: sensitive linkable child-related personal metadata; inventory purpose, family role/approval, retention, deletions/backups, cross-border OCI handling, subprocessor logs and Data safety disclosures. Media capture (FR-009/010) remains unreleased; this metadata design cannot be advertised as existing or used to authorize child capture. 'No media files stored' does **not** mean 'no personal data stored'. Retention and access reviews require India counsel and Play evaluation. [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md) / [Admin Console Specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md).

## 2026-10-27 new temporary GPS data stores / ingestion processing disclosure inventory

Accepted design [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) adds two GPS processing surfaces: (a) up-to-48h **encrypted Alarka device-local unsent GPS history**; (b) PostgreSQL **inbox of full GPS batches** that is *temporarily persisted* before bulk worker writes final PostGIS `location_observations`. Inbox raw GPS payload, transaction WAL and encrypted backups may create additional retained copies; capture/updating canonical location and trip records remain separate user-data categories. Authoritative `device_event_dedup` ledger includes device IDs, event IDs and digests; parent reads only authorized committed location, never inbox. Recorded timestamps, precise lat/lon, accuracy/provider/speed and app package-usage intervals require purpose-by-purpose privacy and data safety review. Minimize operational log payloads, restrict DB roles, define actual retention/purge and consent/delete/tombstone behavior, include offline retry and failed worker dead-letters in account deletion. This is NOT public data-policy text or proof of India/Play lawful processing.
