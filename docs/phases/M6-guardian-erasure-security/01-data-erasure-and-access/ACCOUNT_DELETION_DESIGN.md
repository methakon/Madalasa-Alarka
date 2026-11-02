# Account and Data Deletion: Functional and Technical Design

> **Document control:** M6 / 01-data-erasure-and-access · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product naming:** **Madalasa** parent/guardian app, **Alarka** child companion; GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka). [Brand and Markandeya Purana context](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Madalasa–Alarka | Draft 2026-10-25 | Not yet implemented**

This document describes **mandatory planned behavior** for the parent app's account deletion path, a public account-deletion web entry point, child unpairing, retention and optional Drive data. Do not publish a deletion URL or claim deletion capabilities until the service exists.

## 1. Product requirements

- A signed-in parent can access `Settings > Account > Delete account` or a clear equivalent.
- An unauthenticated former user can request deletion from a public, identifiable web page without reinstalling Madalasa–Alarka.
- The service shall provide identity verification proportional to the deletion risk, without demanding that a user restore access to the deleted app.
- The page explains which data will be deleted, which could legally be retained and how long, and how subscriptions are canceled.
- Deletion of an account revokes linked device credentials, stops new telemetry ingestion, revokes delegated backend integration access where feasible, deletes or schedules erasure of attached historical data, and records minimal auditable request state.
- A parent can unpair an individual child device without necessarily deleting their entire parent account.
- Removal from our backend does not automatically erase a parent-created Google Drive copy unless the actual authorized API operation and parent approval cover it; explain this separately.

## 2. Proposed API

```text
POST /v1/account/deletion-request
  -> request_id, verification_state, created_at
POST /v1/account/deletion-request/{id}/verify
  -> verified | rejected
GET /v1/account/deletion-request/{id}/status
  -> requested | verifying | queued | processing | completed | failed
POST /v1/devices/{deviceId}/unpair
  -> revoked_at
POST /v1/integrations/google-drive/revoke
  -> revocation_result
```

Use authenticated parent identity where available and secure one-time verification for web requests. Rate-limit requests. Do not expose request status across accounts.

## 3. Deletion state machine

```text
REQUESTED -> VERIFIED -> ACCESS_REVOKED -> DELETING -> COMPLETED
    |            |             |
    v            v             v
  REJECTED    CANCELLED    FAILED_RETRYABLE
```

Access revocation is immediate once authorized; data deletion may be asynchronous and retried. Use durable job IDs and idempotency.

## 4. Data category workflow

| Category | Expected action | Verification |
|---|---|---|
| Parent profile/auth link | Deactivate and remove/retain minimal legal audit as appropriate | Cannot authenticate after completion |
| Device enrollment keys | Revoke and remove | Child API returns unauthorized |
| Location and route history | Delete per device/account in primary storage | Queries return no deleted events |
| Usage aggregates | Delete | Reports return empty |
| Policies and commands | Cancel execution, revoke pairing, minimize audit as legally appropriate | No new command delivered |
| Optional media metadata/files | Delete owned internal storage; handle Drive copies according to clear policy and parent choice | Object inaccessible and deletion receipt |
| Google Drive OAuth | Revoke stored token and unlink | Integration no longer works |
| Backups | Delete or expire under explicit documented schedule | Restore test does not resurrect deleted data after relevant retention |
| Security/billing records | Retain only as required under defined legal/fraud obligations | Retention exception documented |

## 5. Public request page content — draft

**Title:** Request deletion of your Madalasa–Alarka account

“Use this page to request deletion of your Madalasa–Alarka parent account and associated information, including paired devices, location history and app-usage reports. We may need to verify account ownership before acting. Some transaction or security records may be retained where legally required; see our Privacy Policy for the exact categories and periods.

If you have an active subscription through Google Play, follow the Play subscription cancellation process. Account deletion and subscription cancellation are separate actions. [SUPPORT CONTACT] can help with access or deletion requests.”

**Web destination:** `https://[PUBLIC DOMAIN]/account/delete` — placeholder only, **not live**.

## 6. Test cases

- Owner requests deletion while signed in; credentials revoked and children no longer sync.
- Unauthenticated web request with valid email verification, invalid email and replay.
- Subscription active; clear instruction and entitlement handling, no surprise billing promises.
- Device offline during deletion; later sync rejected.
- Interrupted deletion job resumes without recreating accounts.
- Google Drive previously unlinked, token expired, and uploaded copies handled according to published policy.
- Deleted account attempt to sign in/re-pair without re-registration.
- Private/deleted data absent from analytics/logs/backups according to documented schedule.

## 7. Publication blockers

- [ ] Final support email/operator identity
- [ ] Actual public HTTPS deletion page and working request workflow
- [ ] In-app deletion entry point
- [ ] Tested background deletion job and device credential revocation
- [ ] Defined backup/log/legal retention limits
- [ ] Live privacy policy reflecting this behavior
- [ ] Data safety declaration reconciled with actual deletion capabilities

## Official source

https://support.google.com/googleplay/android-developer/answer/13327111

## 8. India data retention, purpose revocation and backup-recovery legal gate

The India-first plan requires consent/authority and DPDP feature-purpose review before ingestion of any real child's data: a realtime safety location exemption may not extend to app-usage or historic route datasets. [India DPDP and Chicago transfer](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md). Retention assumptions in old financial projections are not policy approval. Candidate design: raw 14d, history 90d, usage OFF, audit 365d, backups 30d; final periods require owner and legal signoff.

Erasure/restoration tests must cover **offline device queue**, replicated/bucket backups, token/SSE revocation, separate Drive account responsibilities and legally necessary record retention. A recovered snapshot may not resurrect erased child GPS; see [OCI DR and restore tests](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_RECOVERY_AND_PILOT_READINESS.md). Public deletion web page still not deployed.

## 2026-10-27 capability metadata retention/deletion addition

The new [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) designs server-stored child device compatibility, Android permission scopes/statuses, enrollment generation and report version, last verified/received timestamps and a bounded event history. Treat these as linked child/family personal metadata: include latest snapshot, historical changes, cache/SSE copies, support diagnostics and backup restore protection in authenticated family/device deletion and export assessments. Old Alarka offline reports must not revive deleted capability records or previously revoked grant state. Final retention TTL and legal basis remain undecided; no raw sensor media collected by a read-only scan. Do not publicly promise immediate revocation broadcasts when Android may kill the app.

## 2026-10-27 deletion dependencies for media activity and administrative access audit

If the proposed FR-050/051 metadata-only features ship after approval, deletion and export scope shall include **media_activity** summary, **media_activity_events** append log, support/admin query caches, authorized parent histories and backups, child/guardian identity joins, plus separately classified **admin_access_audit** of privileged reads. Remove child-linked events under approved retention policy and ensure an offline Alarka/Madalasa retry cannot reintroduce them after deletion tombstone. Legally required preservation or security audit retention, if any, needs product-specific India counsel decision, segregated access and bounded TTL; do not invent retention lengths. Media files never sit in VPS audit tables. Server cannot promise deletion of a parent-local recording not under its control. [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md).

## 2026-10-27 deletion across accepted offline device buffer and PostgreSQL location inbox

[MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) adds a temporary sensitive server `location_ingest_inbox` data store and local Alarka encrypted queued coordinates to the data lifecycle. When an authorized guardian removes device access or a child/family account is deleted, stop future ingestion **before** replay can import old 48h batches: revoked device enrollment generation/credential and server tombstone must reject all retry IDs. Apply deletion schedule to inbox PENDING/LEASED/PROCESSED/QUARANTINED, raw GPS partition rows, dedup ledger, reconstruction outbox, latest location/read caches, derived trip/usage records and backups/restore manifests. The service cannot promise to remotely wipe a force-stopped/offline physical phone instantly; on next eligible Alarka run enforce revoked grants and local queue purge under lawful policy. No unlimited deletion bypass because a worker is processing an inbox row; worker must check current authorization/tombstone before raw commit. Retention decisions and privacy audit tests T-ING-14/20 remain unresolved.


## 2026-10-27 owner commercial/UI direction — supersedes conflicting historical proposals

**State: owner-approved design direction, NOT deployed, legally signed off, or Play Console/device tested.** Launch is India-first, **manual-renewal Google Play prepaid only**. No automatic renewal, background charge, or charge triggered by opening premium feature; parents explicitly confirm each purchase/top-up in Play. At verified prepaid expiry, downgrade to free: live tracking at a reduced adaptive GPS interval (moving design target approximately 10–15 minutes, slower stationary; no Android timing guarantee), most recent **six hours of visible location history**, and no paid media. Premium requests show payment review instead of silently charging. Deleting the account revokes child/guardian access and future ingest, and cannot generate an auto-renewal; handle any legacy auto-renewing purchase independently if ever issued.

**Price targets per paid child:** public ₹99/month or ₹999/year; founding ₹50/month or ₹500/year for the first **1,008 distinct successfully paying families** counted once each. All eligible paid children in a founding family, including added later, qualify. Founding eligibility persists through prepaid lapses when lawfully recognizable. Automatic eligible early-access offer, no coupon entry, subject to real Play prepaid products/offer support, taxes, fee confirmation and purchase-screen amount. Trial activation does not count as a paying founding family.

**Introductory experience:** once per eligible verified family, 48 hours of conditional Super Access with no auto-conversion, independently server timed. Across the FULL trial per eligible child, shared between authorized guardians: 5 audio minutes (3 min max/session), 2 video minutes (1 min/session), 3 successful photo snapshots, 2 screen-view minutes (1 min/session). Paid Balanced per paid child per month: 60 audio minutes (5 min max/session), 20 video minutes (2 min/session), 30 photos, 10 screen-view minutes (2 min/session). Count confirmed delivered session consumption, not failed OS attempts. Media remains **OFF / P3 conditional research** until Android, legal, Google Play, safety and device gates permit. No implied covert or guaranteed background sensor access.

**No repeated trial:** verify adult parent identity and prior redeemed or paid eligibility server-side, with a minimized bounded lawful anti-abuse ledger; optional Play Integrity/Device Recall subject to availability and review. Reinstall, logout, closure/recreation, or adding a child never restarts a lawfully recognized trial. Do not store child routes, images, microphone recordings, Aadhaar or IMEI to enforce eligibility. Legitimate families incorrectly blocked require review; permanent matching of an erased identity is not guaranteed.

**Storage vs visibility:** six-hour free history is an access limit, NOT a retention authorization. Earlier child location data can only remain for independently approved purpose-specific periods, not automatically until account closure. Deletion revokes token access, cuts off late offline uploads, and erases eligible data including backups as policy dictates. Legal retention, deletion exceptions, guardian authority and cross-border processing remain open gates.

**Parent UI:** replace oversized purple 48h hero with compact off-white/teal-style dismissible trial strip/pill (around 48–64 dp): “✦ Super Access · 47h left” plus accessible close X. The close dismisses marketing banner for the current in-app navigation session, NOT trial entitlement/countdown; a small plan/status entry remains visible. No flashing, support reduced motion. The opening welcome announcement may show once, then small strip; real countdown derives from backend. Trial-ended messaging clearly explains free tracking and manual prepaid upgrade.

**Costing:** existing OCI 1,000-child allocation (~₹3,238/month) explicitly excluded media. Provisional separate ₹3,000/month testing reserve is NOT a TURN/WebRTC provider quote, nor a production capacity promise; measure concurrency, relay ratio, bandwidth, storage, taxes, prepaid Play fees and full operating expenses. Older ₹50/₹500 as universal public pricing, auto-renewing products, 15% auto-renew fee cases, and corresponding revenue scenarios in preceding sections are HISTORICAL and need a full prepaid recalculation. Confirm Play Console purchase/top-up/seat-count/offer behavior before enabling billing.

**Screen consistency and traceability:** base UI source [existing 81-screen Figma handoff](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=6-2) (off-white/teal parent visuals). Update dashboard/map/history trial strip and billing screens P-47/P-48/P-49 plus deletion P-44, capabilities P-46, trial eligibility and media views to show this rule. Do not claim static Figma designs are working Android screens.
