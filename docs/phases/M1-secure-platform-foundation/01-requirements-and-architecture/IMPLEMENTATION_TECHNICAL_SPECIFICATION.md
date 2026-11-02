# Full Implementation Technical Specification

> **Document control:** M1 / 01-requirements-and-architecture · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product:** **Madalasa** (parent app) + **Alarka** (child app); the GitHub repository is now **[Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka)**. [English mythological inspiration](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Madalasa–Alarka | Revision 1.0 draft | 2026-10-25 | Architecture design (not implemented)**

Related: [SRS](SRS.md), [Feasibility and conditions](../../M0-foundation-and-approvals/02-market-and-feasibility/FEASIBILITY_CONDITIONS_AND_EVIDENCE.md), [Google Play requirements](../../M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md).

## 1. Objectives and boundaries

Build a parent-supervised, transparent Android management system with:
- Child Android app: a narrow Kotlin Android platform layer and an efficient C++20 core.
- Parent Android app: Jetpack Compose, Maps SDK, status, reports, eligible device policies.
- C++ backend: Drogon (recommended) + PostgreSQL, secure pairing, commands, policies, entitlement service and history.
- Optional Google Drive backup of media from approved, visible workflows.

The product will not conceal monitoring, suppress Android's privacy indicators, bypass permission checks, or claim unrestricted access to another app's private files. All conditional features are feature-flagged and must pass device and publication gates.

## 2. High-level architecture

```text
Parent Android client (Kotlin/Compose + Google Maps)
  | HTTPS + access token
  v
API gateway/TLS -> C++ Drogon service -> PostgreSQL
                  |    |      |
                  |    |      + Subscription verification / Google Play
                  |    + Command store + audit events
                  + Google Drive OAuth and upload coordination
  ^
  | HTTPS device credential, FCM signal optional
  |
Child Android agent
  Kotlin: onboarding, location adapter, usage adapter,
          WorkManager sync, lifecycle, optional DPC adapter
  JNI boundary
  C++: event validation, serialization, queue/coordinator, policy evaluation
  SQLCipher/Keystore-backed local encrypted queue
```

## 3. Technology baseline

- Build Android apps with Android Studio, Gradle, Android Gradle Plugin and Android NDK/CMake.
- Set **targetSdk=36 or higher** for a new Play submission as of 2026-10-25. Proposed minimum API is **29** (Android 10), subject to field support review; `minSdk` is not a Play-wide rule here.
- Use C++20 where NDK and chosen toolchain support it. JNI boundary should pass compact versioned data structures; never hold Android `Context` references inside native worker threads without lifecycle management.
- Android child: Kotlin coroutines/WorkManager for deferrable work; Fused Location Provider or Android LocationManager in a correctly configured location service for supported ongoing tracking; UsageStatsManager only with Usage Access.
- Server: Drogon asynchronous handlers, request size/rate limits, PostgreSQL migrations, stable structured JSON logs, OpenTelemetry metrics. Avoid home-grown crypto/TLS.
- Parent app: Kotlin, Compose, Google Maps SDK; maps API key restricted by Android package/signing certificate; UI handles freshness and accuracy.
- Build release **Android App Bundles (AAB)** with Play App Signing; inspect native `.so` compatibility with **16 KB page sizes**.

## 4. Target repository layout

```text
android/child-app/           Gradle application + Kotlin adapters
android/parent-app/          Gradle application + UI
shared/core/include/         Portable C++ public APIs
shared/core/src/             C++ implementation and tests
backend/src/                 C++ Drogon HTTP handlers/services
backend/migrations/          SQL schema migrations
backend/tests/               API/authorization/integration tests
infra/                       compose, deployment, monitoring (without secrets)
docs/                        SRS, feasibility, implementation, Play documents
.github/workflows/           unit tests, lint, build & security scans
```

## 5. Child app modules

| Module | Interface | Responsibility |
|---|---|---|
| OnboardingCoordinator | Kotlin | Pairing, consent/disclosure, permissions and diagnostics |
| PermissionRegistry | Kotlin | Read current permission/special-access state on every sensitive operation |
| LocationCollector | Kotlin | Timestamped fixes; foreground location service where supported |
| UsageCollector | Kotlin | UsageStatsManager, authorized sampling/aggregation |
| PolicyAgent | Kotlin | Managed-device package suspension, policy apply/rollback |
| SyncWorker | Kotlin | Compressed, idempotent batches using WorkManager |
| LocalQueue | C++/SQLite integration | Sequence numbers, bounds, retry metadata, encryption |
| CapabilityReporter | Kotlin + C++ model | Android API, management mode, permission state and feature support |
| MediaCapabilityAdapter | Platform integration | Optional authorized capture workflow only, behind explicit release flag |
| PrivacySurface | Kotlin | Clearly identifiable app, ongoing monitoring notice, revocation/settings UI |

The setup Activity may close after enrollment. Do not equate this with invisible monitoring. Always follow notification and privacy-indicator requirements.

## 6. Device enrollment and authentication design

1. Authenticated parent requests a short-lived pairing code.
2. Parent opens the child app and enters/scans that code during setup.
3. Child app generates a per-device key in Android Keystore where supported.
4. Backend atomically redeems code, binds device to parent, issues short-lived access token bound to device identity.
5. Device refreshes credentials through authenticated channel. Parent can revoke pairing; server rejects subsequent requests.
6. Managed-device mode has a **separate** provisioning workflow, with an explicit factory-reset/QR setup warning where applicable. A permission grant cannot silently enable device-owner status.

Failure handling: code expired, reused, wrong parent, lost network, revoked credentials and unsupported management mode.

## 7. Location and usage event design

```json
{
  "event_id": "uuid",
  "device_id": "uuid",
  "observed_at": "2026-10-25T10:00:00Z",
  "latitude": 26.0,
  "longitude": 88.0,
  "accuracy_m": 35,
  "speed_mps": null,
  "provider": "fused",
  "sequence": 123
}
```

The values above are sample schema values only, not actual device measurements. Require a timestamp and reported accuracy; speed and bearing optional. Reject invalid ranges, future clocks beyond allowed skew and duplicate `event_id` values. Never fabricate missing positions.

Usage events: package identifier where policy permits, collection interval, foreground duration, source and aggregation version. Establish daily UTC storage with explicit local-time reporting and DST/timezone rules. Persist aggregates regularly because the OS does not promise unlimited historical availability.

Local queue: encrypted SQLite, bounded by count/bytes/retention, transactional insert and acknowledgment; upload batches with idempotency keys; exponential retry and jitter. On permission loss, stop data collection for that feature, update capability state and preserve only authorized existing records per retention rules.

## 8. Parent/client API contracts (draft OpenAPI design)

All routes behind TLS; principal and object-level authorization on **every** read/write.

| Method and route | Identity | Function |
|---|---|---|
| POST /v1/pairing-codes | Parent | Issue short-lived token |
| POST /v1/enrollment | Device with code | Pair a device |
| GET /v1/devices | Parent | Paired-device list and last seen |
| POST /v1/devices/{id}/capabilities | Device | Permission/mode snapshot |
| POST /v1/devices/{id}/locations:batch | Device | Idempotent telemetry ingestion |
| GET /v1/devices/{id}/locations | Parent | Paginated time-range history |
| POST /v1/devices/{id}/usage:batch | Device | Aggregates |
| GET /v1/devices/{id}/usage | Parent | Daily/monthly/yearly totals |
| POST /v1/devices/{id}/policies | Parent | Versioned restriction rules |
| GET /v1/devices/{id}/policies | Device | Applicable policy delta |
| POST /v1/devices/{id}/commands | Parent | Supported remote control request |
| GET /v1/devices/{id}/commands | Device | Pending commands |
| POST /v1/devices/{id}/commands/{cid}:result | Device | Execution outcome |
| DELETE /v1/devices/{id}/pairing | Parent | Device revocation |
| GET /v1/audit-events | Parent | Authorized audit |
| POST /v1/account/deletion-request | Parent | Account/data erasure |
| POST /v1/subscriptions/provider-events | Verified provider | Entitlement lifecycle |

Pagination: cursor, limit <= 500, bounded query range. All write bodies validate size/schema and use request IDs. Commands accept `idempotency_key`, `expires_at`, typed parameters. Use a unique `(device_id,event_id)` constraint for ingestion.

## 9. Remote command state machine

```text
CREATED -> QUEUED -> DELIVERED -> ACCEPTED -> COMPLETED
   |         |           |          +-> FAILED
   +---------+-----------+----------+-> EXPIRED
                         +----------+-> PERMISSION_REQUIRED
                         +----------+-> USER_ACTION_REQUIRED
                         +----------+-> OS_REJECTED
                         +----------+-> UNSUPPORTED
```

A device response can also indicate OFFLINE/RETRYABLE. Server enforces legal transitions and expiry. A request is never considered completed on mere push delivery.

Camera/audio functionality: **deferred optional module**. Parent UI exposes only feature categories certified for the enrolled device and approved distribution. An authorized user-visible operation re-checks Android permission/state and reports unsupported/OS rejection honestly. No design for undisclosed recording or bypassing system indicators is included.

## 10. Managed-device application restrictions

Provide a DPC-enabled build variant only for appropriately enrolled devices. Use `DevicePolicyManager.setPackagesSuspended` for eligible installed packages. The API reports unsuspendable packages; store a per-package outcome. Do not promise universal instant force-stop.

Policy example:

```json
{
  "policy_id": "uuid",
  "version": 4,
  "target_packages": ["org.example.game"],
  "timezone": "Asia/Kolkata",
  "days_of_week": [1, 2, 3, 4, 5],
  "start_local": "20:00",
  "end_local": "06:00",
  "desired_state": "SUSPENDED"
}
```

Parse overnight windows, reboot persistence, clock/timezone changes and next transition calculation using on-device time-aware scheduling. Never suspend emergency, provisioning, admin, permission controller or other system-critical packages. Parent can revoke/roll back a policy; offline device applies last authorized policy until its expiry.

## 11. Backend relational model (initial migration)

> **SUPERSEDED for M1 (2026-10-27).** The authoritative M1 data model is
> [`0001`](../../../../backend/persistence/migrations/0001_m1_identity.sql) (family-scoped, forced row-level security),
> extended by [`0002`](../../../../backend/persistence/migrations/0002_m1_device_credentials.sql) and
> [`0003`](../../../../backend/persistence/migrations/0003_m1_enrollment_and_credential_hardening.sql). The parent-owned model below
> is kept as history of the original design and must not be implemented. Credential design:
> [M1 device credential lifecycle](../../../M1_DEVICE_CREDENTIAL_LIFECYCLE.md).

Tables:
- `parent_accounts(id, auth_subject, created_at, deletion_status)`
- `devices(id, owner_id, mode, api_level, app_version, last_seen_at, revoked_at)`
- `device_keys(id, device_id, key_fingerprint, issued_at, revoked_at)`
- `capabilities(device_id, observed_at, payload_json, capability_version)`
- `location_events(device_id, event_id, observed_at, lat, lon, accuracy_m, speed_mps, received_at)`
- `usage_aggregates(device_id, package, start_at, end_at, foreground_ms)`
- `policies(id, device_id, revision, payload_json, validity, created_by)`
- `commands(id, device_id, actor_id, type, payload_json, created_at, expires_at, state, reason)`
- `audit_events(id, actor, action, target, occurred_at, metadata_json)`
- `subscriptions(account_id, provider_ref, plan, status, valid_until)`
- `drive_grants(parent_id, encrypted_token_reference, scope_set, revoked_at)`
- `media_metadata(id, device_id, captured_at, kind, size, checksum, storage_ref, deletion_at)`

Indexes `(device_id, observed_at DESC)` for locations; partition if scale warrants. Keep audit metadata minimal. Database credentials, OAuth tokens and payment secrets remain out of app binaries and normal logs.

## 12. Privacy and security implementation

Threats: account takeover, device spoofing, abusive re-pairing, insecure IDOR endpoints, media leakage, lost phones, compromised infrastructure, replayed commands, unbounded collection.

Controls:
- Parent passkeys/OIDC + MFA option; server-side parent/device ownership checks.
- Device credentials in Android Keystore; expiration/rotation; strict pairing rate limits.
- HTTPS TLS 1.2+ (prefer 1.3), secure backend secret manager; no embedded server master key.
- Encryption at rest for sensitive data, audited access, bounded retention, export/deletion endpoints.
- Strong server-side validation for all media and attachment metadata; malware/type/size handling.
- Security logs exclude raw coordinates, media and OAuth tokens.
- Do not use AccessibilityService to bypass restrictions or conceal monitoring.
- Publish privacy policy, account deletion path and a recognizable monitoring app identity.

## 13. Cloud and subscriptions

**Drive:** Authorize the parent with Google OAuth and narrow scopes, preferably app-created files only. Backend stores protected token references, never parent password. Make upload resumable with checksums, backoff and explicit revocation; mark failures and separate Drive deletion from internal data deletion.

**Billing:** Parent Android app uses Play Billing if selling access to digital services via Play; backend validates purchase tokens/notifications and maps to entitlements. Track trial, grace period, active, hold, canceled, expired, refund/revoke. Child device never decides subscription access from local UI alone.

## 14. Performance targets (proposed, not guaranteed)

Capture baseline measurements on supported phones with tracking disabled/enabled; sample 24h stationary and 2h moving scenarios. Measure p50/p95 CPU, PSS memory, GPS usage, wakelocks, background data volume and battery delta. Initial engineering objective: avoid continuous polling, bound queue <= configurable byte limit, batch network transfers and provide configurable location update profiles. Do not publish battery percentage claims until observed on hardware.

## 15. CI/CD and release engineering

- Pull request checks: `ktlint`/Android lint, Detekt optional, C++ clang-tidy, unit tests, Gradle release assemble, CMake/CTest.
- Security: dependency/SBOM scan, secrets scan, SAST and dependency license review.
- Backend: reproducible container, migrations, integration tests with ephemeral PostgreSQL, load tests, rollback plan.
- Android: AAB signing with Play App Signing; inspect Android manifest, target API and 16 KB native library alignment/support. Keep release signing/upload keys out of Git.
- Staged Play release after internal and closed testing, with monitoring for crashes/ANRs/permission denial.

## 16. Milestones with acceptance gates

| Milestone | Deliverables | Exit condition |
|---|---|---|
| M0: Policy/platform research | This document pack, target-device list, Play permissions plan | Team approves standard/managed product scope |
| M1: Foundation | Monorepo Gradle/CMake, auth, pairing, encrypted queue, backend skeleton | Integration tests pass and revocation works |
| M2: Location MVP | Location service, events API, Maps UI, route history | Offline recovery and clear freshness/accuracy |
| M3: Usage analytics | Usage onboarding, aggregation, reports | Reports handle permission revocation/time boundaries |
| M4: Managed controls | Explicit provisioning runbook, DPC policies, schedule | Suspension tested on physical managed device; safe rollback |
| M5: Media/Drive | Only authorized Play-compatible media workflow; parent Drive consent | Permission/policy review and device test gates; otherwise defer |
| M6: Subscription | Billing validation, lifecycle, entitlement UI | Refund/grace/revoke integration tests |
| M7: Play release | AAB, listing, declarations, privacy/deletion URL, screenshots, reviewer demo | All required Play Console forms complete and review approved |

## 17. Traceable verification

See [release and test plan](../../M8-operational-readiness/03-quality-and-evidence/VALIDATION_AND_RELEASE_PLAN.md). Every SRS functional requirement maps to a test, owner, severity, supported API range and recorded results. **There is currently no executable app and no tested hardware result.** Publication documents are drafts, not evidence of Google Play approval.

## 18. References

- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://developer.android.com/about/versions/14/changes/fgs-types-required
- https://developer.android.com/reference/android/app/admin/DevicePolicyManager
- https://developer.android.com/work/dpc/dedicated-devices
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://developer.android.com/guide/practices/page-sizes

## 19. Live route tracking and named places expansion (2026-10-25)

[Live Trip Route, Named Places and Battery Specification](../../M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md) is the detailed feature-level implementation plan for the parent Google Map: labeled places and optional geofence alerts, adaptive child location collection, event-time ingest, C++ trip/stop clustering, route segmentation, conditional Google Roads API, multi-device provenance, endpoint/data-model additions and reproducible battery testing. Treat that document's 8-milestone feature roadmap as a workstream **within** the existing main M1–M7 milestones, not evidence that implementation is complete.

**Important:** Low-power history and accurately road-matched vehicle paths have competing sampling requirements. Do not offer automatic high-confidence road snapping for sparse vehicle observations. Comply with Google Roads API asset-tracking licensing, caching and attribution requirements before enabling in a commercial tracking product.

## 20. Consolidated C++ multi-tenant backend and adaptive tracking architecture

[Adaptive Movement and Multi-Tenant C++ Server Architecture](../../M2-location-collection/01-location-collection-and-ingestion/ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md) contains the detailed **how and why** behind the proposed server design: family/guardian/child/device grants, battery-aware Android motion state machine, C++ Drogon service boundaries, durable ingestion and outbox processing, C++ reconstruction pseudocode, PostGIS spatial matching, time-partitioned SQL, event-time late-data revisions, RLS, capacity and database/storage cost model, usage/command workload isolation, testing and delivery roadmap.

This supersedes overly simple assumptions that a single HTTP server should perform GPS ingestion and trip analysis synchronously. Maintain separate bounded CPU and database workloads. All performance/SLO numbers in that document are **design hypotheses until measured**.

## 21. 2026-10-26 media adapters and reason-aware runtime plan

**Owner decision:** conditionally feasible media capability **research accepted**, commercial support still P3/OFF. Alarka's setup Activity normally remains closed; required system sensor indicators, monitoring notification and Android FGS semantics still apply. Add research adapters: `MediaPermissionProbe`, `SensorStartEligibility`, `EnrollmentModeAttestation`, `MediaSessionController`, `MediaStoreSafAccess`, `MediaProjectionConsent`, `ReasonCodeMapper`, `ParentStatePresenter` and optional authenticated `WebRtcMediaTransport`. Kotlin/Java owns Android permission and lifecycle; native C++ does not bypass these controls. Genuine device-owner FGS exemption is a hardware test candidate; normal Device Administrator or FCM alone is insufficient for universal new background camera/mic sessions.

Flow: authenticated guardian media request -> release flag / fresh capability preflight -> bounded command -> Alarka rechecks OS permission and current start eligibility -> actual session/capture or verified reason -> Madalasa displays clear status/explanation/next step. Stream active/stopped is different from a command delivered. Screen view requires per-session MediaProjection prompt and respects protected screens. Remote file listing only through previously permitted MediaStore/SAF/app-owned scopes. Encrypted P2P-first WebRTC, TURN fallback, no VPS media files and optional encrypted Madalasa-local recording are **design candidates**. See [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md); all T-MEDIA-01–18 **NOT TESTED**. Child-data law, Play and security approvals independently block deployment.

## 22. 2026-10-27 capability scan, progressive grants and durable parent compatibility UI

Implement the design in [MA-CAP-ADR-002](../03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) using Android Kotlin adapters, not C++ direct Android permissions: `CapabilityScanner`, `GrantRationale`, `PermissionWizard`, `GrantResultReader`, `LocalRevisionLedger`, `CapabilitySyncWorker`, `ForegroundServiceEligibility`, `ParentCompatibilityRepository`. During first Alarka launch use **read-only OS/hardware probes** and show supported/unsupported/unknown, pair via one-use code/Keystore proof, upload a bounded baseline only after device attestation, and perform one visible OS grant step at a time. Foreground location first; background through subsequent Android Settings; Usage Access special settings; Photo Picker selected-items; SAF persisted URI; media research disabled for commercial manifests.

A local grant changes app state to **LOCAL_VERIFIED**, not `SYNCED`. Device POST with enrollment generation, monotonic `report_version` and `observed_at`; backend validates idempotency/digest/time and returns durable `received_at`. Backend retains latest report and minimal redacted change log; authorizes parent GET by child-specific role and sends a change hint. Parent GET shows support, grant scope, runtime context, release flag, server receive time, stale/offline quality, verified reason and safe next action. Newer grants/revokes supersede stale versions; never turn green from a push or old report.

Rechecks on Activity `onResume`, Android permission result, authorized scheduler/heartbeat, prior to sensitive command, and approved lifecycle triggers; OS revoke may terminate process. Do not promise immediate revocation alert. Screens A-01…A-24 and P-01…P-22, each with notes, are indexed in [Figma functional handoff](../../../ui/figma-functional-handoff/README.md); tests T-CAP-01…24 remain NOT_TESTED. Existing M1 API schema stays narrow until an explicit tested migration/contract release.

## 23. 2026-10-27 parent/admin media-activity implementation handoff (NOT BUILT)

Read [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md) and [Administrator Console Specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md). Proposed modules: MediaActivityEventIngest, MediaOutcomeReconciler, EvidenceReasonMapper, MediaActivityRepository, GuardianAuditReadPolicy, AdminCaseAuthorizationMiddleware, AdminIdentitySuggest, AdminAccessAuditAppender, CursorPager and RetentionPolicyJobs. Kotlin/Alarka emits only verified device/Android lifecycle receipts, Kotlin/Madalasa emits authenticated visible-playback/optional local-save receipts; Drogon stores metadata only after scoped authorization and idempotency; PostgreSQL stores request-time projection plus append-only events and separately restricted admin read-access audit. Avoid storing media binaries, thumbnails, file paths, filenames or raw exceptions; use nullable actual file-size/duration, distinguish relay bytes.

UI accepts child dropdown/date/type/outcome/reason and next/prev page. Admin browser has scoped parent and child name/ID autocomplete, parent-child case linkage, MFA/purpose, time-limited access and read-audit tracking for suggestions and detail. Root/system roles receive no implicit child details. Use UTC [from,to), keyset sorted by request_at+id, maximum 100 rows/page, case validity checked at every cursor page; do not issue global unbounded COUNT or mass export. Protect against cross-family BOLA, cursor forgery/replay, support-user scope escalation, event forgery and audit writer failure.

**Interface state:** 8 new design-only whole-project routes plus separate AdminBearer, and proposed schemas; all endpoints unimplemented. The existing 11-operation M1 OpenAPI has NOT gained admin or media endpoints. Tests T-AUD-01–22 / T-ADM-01–14 and [28 new Figma screens](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-2) must be implemented and reviewed in separate milestones; media feature flag remains OFF until legal/Play/security gates.

## 24. 2026-10-27 PostgreSQL durable inbox / batched C++ GPS intake implementation contract

Accepted default in [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md): Alarka `LocationCollector` → `EncryptedGpsQueue` (stable per-fix event_id, observed_at, lat/lon/accuracy/provider/optional speed; **48h capacity goal**) → `UploadBatcher` (JSON gzip when worthwhile, 1–2min *target* only inside Android-eligible service; otherwise deferrable WorkManager/retry). The main Alarka Activity can close; valid FGS and required visible monitoring notification remain OS-controlled. Local batch remains until durable Tx-A server receipt.

C++20 Drogon ingestion `LocationBatchController`: authenticate device/child, enforce release policy, max 100–500 events/byte cap, validate digest/time/identity, insert **one inbox row per JSON batch** in Postgres Tx-A with idempotent device_id+batch_id and COMMIT, then return 202 `processing=QUEUED` (`durable_stage=INBOX_COMMITTED` optional in whole-project API); not final raw commit or trip completion. Reject 409 changed digest; 429/503 backpressure with Retry-After and client jitter. Implement separate `IngestLeaseWorker`: short FOR UPDATE SKIP LOCKED claim/lease epoch, parse and merge multiple pending batches, prepared multi-row `INSERT ... SELECT` (or benchmark COPY STDIN to staging), atomic Tx-B for device_event_dedup + partitioned location_observations + reconstruction_jobs outbox + inbox PROCESSED; failed/crashed work remains retryable with fencing and quarantine. `TripReconstructor` consumes outbox in its own event-time worker and updates route summaries; parent latest/history reads only committed qualified data.

No Redis in MVP. Benchmark direct raw bulk+dedup+outbox Tx-A alternative for lower WAL/write amplification. Do not claim inbox lowers total resource use by itself. Separate UsageStats session source/table/batch worker and daily aggregate; do not merge app usage with GPS table or promise exact current app. All T-ING-01…24, schema migration and CI/Android tests NOT_IMPLEMENTED/NOT_TESTED. Whole-project OpenAPI design only; M1 `openapi-m1.yaml` unchanged. [Editable HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-2) and [LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-60).

## 2026-10-29 owner-approved Option C architecture

The canonical [Technical Specification](TECHNICAL_SPECIFICATION.md#owner-architecture-decision--2026-10-29-option-c-solid--hmvc--independently-deployable-c-workers) now governs backend layering: **Drogon ingress/API + independent C++ worker executables + SOLID, HMVC-style feature modules** with explicit domain/application/transport/infrastructure boundaries. Existing Drogon design remains in place; move expensive work out of HTTP request threads through durable inbox/outbox, transactional retry/idempotency and least-privilege access. Microservice deployment is incremental and justified by scaling/failure boundaries, not automatically one service per feature. Treat older all-in-one backend drawings as conceptual only. No completed implementation or framework switch is implied.
