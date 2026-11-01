# Madalasa–Alarka v0.x — Privacy, Guardian Access, Retention and Erasure: Technical + UI Specification

**Version:** document revision 0.1 (pre-public development; first public app version planned 1.0.0). **Status:** ENGINEERING CONTRACT / RELEASE PURPOSES SUBJECT TO APPLICABLE LAW AND GOOGLE PLAY REVIEW. **Date:** 2026-11-02.
**Components:** Madalasa Kotlin/Compose, Alarka Kotlin/Compose, Drogon C++20, PostgreSQL/PostGIS, Drogon/HTMX administrator. **Test mode:** owner-operated physical devices with actual GPS/network and development APIs, no separate self-consent paperwork. Other adults must understand/agree to participation. Device ownership is not authority to monitor another user. Android permissions, foreground-service notifications, privacy indicators and platform constraints always apply.

## Sources and design interpretation

Public comparator documentation informs UX patterns, **not legal authorization or copied policy text**:
1. **Google Family Link** [child and parent privacy notice](https://families.google.com/familylink/privacy/notice/): understandable parent/child notice, parental controls, data/account management. Translate to explicit guardian and device visibility, *not* a Family Link identity dependency.
2. **Life360** [privacy policy](https://legal.corp.life360.com/hc/en-us/articles/16038777217175-Life360-Privacy-Policy) and [location and drive history](https://support.life360.com/hc/en-us/articles/23053602225559-Location-Drive-History): display membership-dependent **history visibility** and user controls. Translate to server-checked Free/Paid query windows, not identical retention durations.
3. **Qustodio** [family privacy policy](https://www.qustodio.com/en/family/privacy/): distinguish account, device telemetry, historic reports, purpose and deletion pathways. Translate to typed retention categories, purpose/source/access controls.
4. **Bark** [privacy policy](https://www.bark.us/privacy/): parent privacy requests, service-dependent retention, revocation and deletion processes. Translate to an authenticated privacy request flow and consistent responses.
5. **Google Play** [Families requirements](https://support.google.com/googleplay/android-developer/answer/9893335) and [monitoring apps policy](https://support.google.com/googleplay/android-developer/answer/12934922): platform constraints must be checked for actual target audience, declared functions and permissions. Competitor distribution never proves eligibility.

## 1. Runtime data and security model

**Actors:** `ParentPrincipal` (trusted Google OIDC session), `ChildDevice` (revocable device credential), `GuardianGrant` (child_id + scopes + expiry + generation), `AdminPrincipal` (limited admin role); distinct bearer audiences and RLS. Authentication is NOT custody verification; family billing membership does NOT grant child monitoring permissions. Server never trusts client-supplied guardian scope, paid tier or `family_id`.

**Purpose registry** (stable versioned machine-readable IDs): `SAFETY_CURRENT_LOCATION`, `HISTORY_TRIPS`, `CHILD_SOS`, `DEVICE_DIAGNOSTICS`, `APP_USAGE`, `MANAGED_CONTROLS`, `MEDIA_RESEARCH`, `SUPPORT`. Store `notice_version`, `purpose_version`, release eligibility flag, legal authority status and Android capability per child/device; conditional purposes default disabled. For real-child use, purpose and identity/authority evidence must be compliant before enabling collection.

**Category registry:** `GUARDIAN_ACCOUNT`, `CHILD_PROFILE`, `ENROLLMENT_CREDENTIAL`, `GPS_OBSERVATION`, `TRIP_DERIVATIVE`, `SOS_EVENT`, `USAGE_EVENT`, `CAPABILITY_EVENT`, `SUPPORT_TICKET`, `BILLING_RECORD`, `SECURITY_AUDIT`, `DELETION_TOMBSTONE`. Each record has server-side purpose, subject, family/child, observed_at/created_at, access grants, policy version, retention clock, next purge eligibility, backup and processor considerations. No global blanket retention period. Preserve product's previously requested account-history intent as **unapproved product intent**, not unlimited retention authorization.

**History access != storage:** `FREE` parent viewer has maximum past-six-hour *visibility*. Paid viewer sees server-entitled bounds (subject to lawful underlying storage and guardian scope). Backend filters all queries before pagination/export and cached results; never assume old data is retained or reconstructable. Free-window clock uses server UTC. Trial/founding/billing are determined server-side; expiry never authorizes access outside legal purpose.

**Access grant invariants:** `(family_id,child_id,principal_id,scope,expires_at,revoked_at,generation)` checked on every read/command/subscription; invitation must be expressly accepted for one child. No sibling inheritance, co-parent role leakage or admin raw GPS override.

**Revocation precedence:** Android permission denied, device revoked, child-specific guardian grant revoked, purpose disabled, expiry, tombstone or no legal authority all override paid entitlement. On revocation: invalidate relevant sessions/tokens/cache, reject new commands and ingest, freeze offline queue uploads using generation fence, enqueue derived-data deletion, suppress replay from inbox/outbox/backup recovery. Device receiving updated policy acknowledges with version; UI does not imply immediate delivery while offline.

**Security:** HTTPS, opaque scoped sessions, device Keystore-bound proof, encrypted stores, RLS FORCE, idempotency keys and event deduplication, monotonic generation, row-level child-specific joins, restricted exports and rate limiting; no raw child GPS/media in admin panels, analytics, log lines or support attachments.

## 2. Database contract (additive migrations after live schema inspection)

Use current physical migration/version lineage; never overwrite existing migrations. The following are *desired entities/columns*, not a claim that all already exist:

- `purpose_policy_versions(id, purpose_code, version, notice_digest, eligibility, effective_at)`; uniqueness `(purpose_code,version)`.
- `child_purpose_decisions(id, family_id, child_id, guardian_id, purpose_code, policy_version_id, state, effective_at, revoked_at, proof_ref, generation)`; composite FKs, RLS and an append-only decision history; external verification proof reference nullable only in test mode.
- `privacy_data_category_policies(id, category_code, jurisdiction, policy_version, access_window_seconds, retention_duration_seconds NULL, retention_trigger, processing_hold_class, approved_by, approved_at)`; a NULL retention duration means **unresolved/disabled for real-child ingestion**, not infinite retention.
- `privacy_requests(id, family_id, child_id NULL, requester_id, request_type, state, requested_at, verified_at, completed_at, failure_code, deletion_generation, evidence_digest)`.
- `privacy_deletion_tombstones(family_id, child_id, device_id, minimum_generation, created_at, reason)`; no raw data payload in tombstones. Reuse already existing tables if equivalent and document mapping; do not create duplicates.

All tables require tenant scoping and authorization tests; indexes on child/request state/purge clock; `CHECK` for legal state transitions; purging must respect verified transaction/backup recovery obligations. Explicit storage cases for PostgreSQL inbox, WAL, dead-letter, derived trip records, cached maps, local Alarka queue, backups and temporary export files. No copied competitor retention numbers.

## 3. API contract (draft operations; do not pretend implemented)

Use `/v1` for stable accepted operations and review `docs/openapi.yaml` before minting a new path. Unique operationIds, ParentSession/DeviceSession auth, 400/401/403/404/409/423/429/503 and stable `error_code`; 404 for out-of-scope child. Idempotent state changes and versioned ETag where relevant.

| Operation intent | Method/path **candidate, reconcile with master OpenAPI** | Input/output essentials |
|---|---|---|
| Obtain visible purpose disclosures | GET `/v1/privacy/purposes?childId=` | purpose/version/notice summary/eligibility/reason, no hidden tracking flag |
| Read child scoped privacy status | GET `/v1/children/{childId}/privacy/status` | guardian authority status, purpose decisions, observed OS capability, stale timestamp |
| Read retention and visibility policy | GET `/v1/children/{childId}/privacy/history-policy` | tier server-resolved visibility cutoff, retained periods actually available, category limits, policy version |
| Record or withdraw a purpose | POST `/v1/children/{childId}/privacy/purpose-decisions` | purpose, action, notice digest, idempotency key; server validates actor and eligible purpose |
| List child guardian access | GET `/v1/children/{childId}/guardian-grants` | child-only scope/expiry/state, redact unnecessary identity info |
| Revoke child grant | POST `/v1/children/{childId}/guardian-grants/{grantId}/revoke` | generation increment, cache/session fence, durable audit; fail closed |
| Request privacy export/delete | POST `/v1/privacy/requests` | child scope + request type, verification/re-auth where needed, job ID and truthful state |
| Read privacy request progress | GET `/v1/privacy/requests/{requestId}` | REQUESTED/VERIFYING/IN_PROGRESS/COMPLETED/PARTIAL_LEGAL_HOLD/FAILED; no premature success |
| Child device transparency status | GET `/v1/device/privacy-status` | server policy version, enabled purposes, last ACK, permissions and collection visibility |
| Child device confirms policy | POST `/v1/device/privacy-policy-ack` | authenticated device ID, version, OS evidence; no self-authorization |

**Pre-implementation rule:** First map these intentions to existing 171 draft OpenAPI operations; extend only missing method/path combinations. Do not introduce parallel duplicate privacy APIs.

## 4. Android UI specification (Theme C)

**Theme C:** parchment `#FFF7E7` background, ink `#292A31`, vermilion `#B73527` for destructive/emphasis, indigo `#233F69` for trusted links, minimum 48dp taps, readable scaling and TalkBack, visible last-updated data and no false success banners.

**Parent / P-09 pairing and P-13 onward setup:** show monitoring purposes and who can view data, separate identity/guardian review from OS grants. A granted location permission does NOT turn on legally disabled purpose.

**Parent / P-40..P-45 guardian/privacy governance** (verify actual ID mapping in Figma handoff): child selector → Privacy & Data → (1) Visible monitoring status, (2) Guardians with exact child access and expiry, (3) History visibility 'Free: last 6 hours' or server paid value, (4) Data by category & deletion conditions, (5) Export / Delete request and progress, (6) Stop sharing / revoke. No one-button blanket account deletion without review and confirm.

**Child / C-01 disclosures, C-07 permission guide, C-18..C-21 transparency and revocation** (verify Figma ID mapping): Alarka screen shows app name, monitoring controller, purposes actually enabled, device permission state and last confirmed policy; separate permission-denied/unknown/offline states; user-facing stop/permission settings navigation; no stealth mode.

**Required UI states:** `LOADING`, `ACTIVE_OBSERVED`, `STALE`, `OFFLINE`, `PERMISSION_DENIED`, `PENDING_GUARDIAN_AUTHORITY`, `PURPOSE_NOT_ELIGIBLE`, `REVOKED`, `DELETION_IN_PROGRESS`, `PARTIAL_LEGAL_HOLD`, `FAILURE_RETRYABLE`. Deletion confirmation states which active records are gone versus lawfully held/backup pending; never claims completed until verified.

**Confirmation microcopy:** "Stop sharing this child's location?" / "This disables new authorized sharing; an offline device may not see the updated setting immediately." / "Request deletion" / "We're processing the request. Some legally required records may be kept separately." A lab tester may use own devices without separate signed self-consent form; do not display a false `LEGAL_APPROVED` status because LAB_TEST_MODE is true.

**Figma implementation:** Preserve existing 81 screen frame IDs and add a dedicated grouped privacy-controls specification page with editable parent privacy overview, guardian access/revoke, history visibility, export/delete request, child transparency and permission-denied states; link new nodes back to P/C handoff instead of silently renumbering all existing 81.

## 5. Required negative and acceptance tests

- Unrelated family/child, no child scope, expired grant, admin attempting raw location, unverified authority, history view across FREE six-hour cutoff, payment tier spoof, replayed pairing or privacy request, concurrent grant revoke and stream, stale offline device upload after tombstone, delayed policy ACK, deleted data in cache/outbox/backups, outage/denied OS permission, unapproved purpose, B2B managed-mode misclaim.
- Android instrumentation on real owner-operated devices: explicit OS permission flow, foreground-service notification where required, location accuracy/time freshness, offline/online policy ACK, revoke on a disconnected device, reboot/battery/FGS limitations and accessibility. Preserve redacted logs, no identifiable coordinates in public Git.
- Verify export data matches scope and retention bounds, and completed deletion cannot resurrect records on retry/restore; performance/security thresholds from relevant phase docs.
- Do not mark visual, build, legal or platform gates PASS based on design/source-only implementation.

## 6. Scope boundaries and release changes

Development uses actual laboratory devices and app infrastructure; synthetic fixtures are optional adjuncts for deterministic negative tests, not a required substitute. Do not request separate signed owner self-consent for owner-only device tests. Real-child data processing and Google Play submission require their applicable legal/permission/disclosure prerequisites before use/submission; reviewer feedback may refine specifications after receipt, but cannot retroactively authorize earlier violations.

**Supersedes prose-only 'Adopt' classification** in [research and versioning addendum](../../../roadmap/PRE_RELEASE_VERSIONING_AND_CHILD_DATA_REVIEW_POLICY_2026-11-02.md) for *technical implementation*. Original source references remain as attribution and background, not a license to reproduce other companies' proprietary UI.
