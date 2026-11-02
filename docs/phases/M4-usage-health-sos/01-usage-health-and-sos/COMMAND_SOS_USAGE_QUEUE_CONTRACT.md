# Madalasa–Alarka — Command, SOS, Usage Reporting and Device Queue Contract

> **Document control:** M4 / 01-usage-health-and-sos · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product naming:** **Madalasa** parent/guardian app, **Alarka** child companion; GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka). [Brand and Markandeya Purana context](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Version:** 1.0 | **Date:** 2026-10-25 | **Status:** implementation design, not tested  
**Scope:** SRS FR-005–007, FR-014, FR-023, FR-033, FR-037, FR-044–049 and NFR-003/013.

## 1. Durable child command protocol

A parent command is an **intent**. Success can be reported only after the child agent has executed and confirmed the supported OS action. The server validates the actor's current child-specific grant, subscription, device enrollment, command capability, payload schema and expiry before queueing. The child revalidates OS mode and permission **immediately before execution**.

### Command fields

command_id UUID, family_id, child_id, device_id, actor_id, type, schema_version, idempotency_key, policy_version optional, created_at, expires_at, required_capability, payload_json (strict type allowlist), state, reason_code, created_at/accepted_at/completed_at, last_device_report_version, audit_id.

Do not store unnecessary sensitive media or raw GPS in normal command payload. Push notification contains **opaque command reference only**, never credentials or raw child location.

### State transition table

| From | Allowed next states | Reject |
|---|---|---|
| CREATED | QUEUED, UNSUPPORTED, PERMISSION_REQUIRED, CANCELLED | COMPLETED without child proof |
| QUEUED | DELIVERED, EXPIRED, CANCELLED, DEVICE_OFFLINE | COMPLETED without execution receipt |
| DEVICE_OFFLINE | QUEUED if retry window open, EXPIRED, CANCELLED | fresh execution after expiry |
| DELIVERED | ACCEPTED, EXPIRED, CANCELLED, OS_REJECTED, UNSUPPORTED, USER_ACTION_REQUIRED | server-imposed COMPLETED |
| ACCEPTED | COMPLETED, FAILED, EXPIRED, OS_REJECTED, PERMISSION_REQUIRED, USER_ACTION_REQUIRED | silently ignoring hardware/session failure |
| Terminal: COMPLETED / FAILED / EXPIRED / CANCELLED / UNSUPPORTED / PERMISSION_REQUIRED / OS_REJECTED / USER_ACTION_REQUIRED | No further ordinary transitions; correction via **new** auditable command or explicit reconciliation event | overwriting terminal success/failure without audit |

A delivered push is not completion. Accept device outcomes only when the enrolled device credential binds to the same command's device and reports a monotonic response version. A command with expired deadline must not execute on reconnection. Server cancels queued instructions on device/guardian revoke and on account deletion.

### Device-side action handler

1. Wake/sync through approved Android scheduling/notification path; no hidden persistent app UI or FGS permission bypass.
2. Verify command expiry, ID, replay and signed/authorized profile; recheck current OS permission and device owner status.
3. Persist claimed action in local command result ledger to avoid duplicate sound/policy actions on retries.
4. Apply only supported action; return typed result code.
5. Persist receipt locally, sync when allowed; server stores exact result and notifies parent. If result uncertain after process death, return INDETERMINATE / FAILED_RETRYABLE *as separate reason*, not fake COMPLETED.

Ringing must remain bounded and respect audio/DND state; remote recording is deferred unless a separate approved, visible workflow passes policy. App restrictions only via eligible DPC APIs.

## 2. SOS priority pipeline and uncertainty

- Child uses optional clearly identifiable notification action/widget or brief Activity to trigger SOS/check-in; main app screen need not stay open for routine location collection.
- SOS event carries stable UUID, device identity, observed_at, optional reference to a recent qualified GPS fix, location accuracy and message category. Do not require a fresh GNSS fix to let SOS be queued.
- Locally persist high-priority SOS event before attempting network; retain until durable receipt or explicit reasonable expiry/deletion.
- C++ API authenticates device and writes event + fanout outbox atomically. Worker dispatches notifications to authorized guardian scopes, respecting grant revocation and delivery provider status.
- Parent sees QUEUED, SENT_TO_PROVIDER, DELIVERED_IF_CONFIRMED, ACKNOWLEDGED or UNKNOWN; a provider success receipt alone may not prove user saw it.
- Urgent SOS should bypass **routine** quiet-hour digest but not platform notification restrictions. Do not promise actual emergency dispatch, availability or delivery.
- Prevent flooding: dedupe SOS UUID, dynamic abuse/rate budget, but protect against a legitimate repeated emergency; do not silently discard subsequent urgent requests.
- Parent acknowledgement requires verified guardian identity and child grant; action logged without default raw coordinates.

## 3. Application usage aggregation and incomplete history

Android UsageStatsManager provides app usage only after Usage Access. It does not guarantee complete long-term event history. The child must collect **bounded** windows, track source timestamp/collection_time, data completeness and version. Server aggregates from its own securely stored intervals.

### Canonical usage event

device_id, event_id, package_name (only authorized visibility), interval_start_utc, interval_end_utc, foreground_duration_ms, collected_at_utc, provider/source, aggregation_revision, completeness (COMPLETE/PARTIAL/UNAVAILABLE), reason_code.

Invariants:
- interval_end > start and foreground_duration_ms cannot exceed interval duration; reject or quarantine malformed events.
- UTC is canonical storage; user's report timezone determines local day/week/month/year cutoffs, including DST, so **split intervals at actual local-time boundaries** before aggregation.
- Uploads may overlap due to repeated collection; dedupe event IDs **and** use versioned interval replacement or normalized source-event identity, never sum overlapping versions twice.
- Yearly report accumulates retained server data, not assumed 365 days of available OS history.
- If Usage Access revoked or no data in a time window, mark PARTIAL/UNAVAILABLE separately from **zero minutes**.
- App categories derive from curated mapping with version/UNKNOWN fallback, not guaranteed Google Play catalog classification.

### Test vectors

- Local day includes DST 23/25-hour day, UTC-normalized duration remains valid.
- Midnight-crossing 90-minute interval contributes to two local calendar days.
- Same interval uploaded twice does not double counts.
- Reinstall/switch device does not silently merge app usage from physically separate sources.
- Child loses Usage Access midweek; report coverage shows missing window.
- API rejects packages outside configured visibility grant as designed.

## 4. Child offline queue storage decisions

Candidate storage: SQLite with approved database/content encryption (e.g., SQLCipher) and Android Keystore-backed key envelope. SQLite in default mode is not encrypted. Sensitive queue backups must be excluded from unprotected cloud/device backup paths.

### Proposed bounds (must benchmark and product-approve)

| Control | Candidate default | Safety behavior |
|---|---|---|
| Raw GPS queue | 20 MiB max disk reserved for active device telemetry | Stop unbounded growth, compact acked events, show queue-pressure warning |
| Normal telemetry queued age | up to 14 days or parent-retention lower limit | Reject stale expired records, preserve audit-safe drop summary |
| Upload batch | 100 events target, 500 hard server max | Compress when net benefit, cap decompressed input |
| Network retries | exponential backoff with jitter (e.g., 30s to 6h cap) | Obey Retry-After, battery/data saver |
| Fatal auth/revocation error | stop upload; clear sensitive device data according to owner/revocation policy | No re-pair or bypass |
| Storage full/corrupt | do not silently overwrite newest good route; mark DATA_LOSS risk and attempt safe recovery | Report gaps and operational diagnostics |
| Device reboot/process death | journaled queue survives; unsent events unchanged | Dedup stable IDs on reconnect |

These limits are engineering hypotheses, not guaranteed Android OS limits. If profile requires longer offline retention, derive disk budget from actual event size/rate and B-07. A false “complete trip” must never be produced from points dropped at the queue boundary.

### Encrypted queue transaction order

Write fix → local commit → schedule deferrable upload → send bounded batch → receive and validate committed device receipt with accepted/duplicate/rejected per event → delete only acknowledged local IDs → if timeout, retry stable UUIDs. Never delete queue on mere network send. Protect boot-locked storage behavior and key invalidation (re-enroll rather than decode without proper key).

## 5. Scheduling and policy simulation

Use a pure C++ schedule evaluator shared conceptually with child application:
- Input: timezone (IANA), calendar exception dates, local start/end (including overnight), package allow/block list, revision, expiry and permitted managed mode.
- Output: deterministic next N transitions as UTC instants, expected affected package statuses and conflicts.
- Exclude emergency dialer/system-critical apps. DPC adapter verifies eligibility and reports per package.
- During DST repeated/skipped local hours, adopt a **documented policy**: candidate first-valid local instant on fall-back, next valid instant on spring-forward; owner can revise after UX testing.
- Parent preview must not be mistaken for applied restriction; child reports actual action.
- Offline device keeps last authorized policy only until explicit TTL and local expiry. An unsuspendable package returns UNSUPPORTED_PACKAGE, not broad success.

## 6. Error and retry catalog

| Code | HTTP/device semantics | Retry? | Parent UI |
|---|---|---|---|
| AUTH_REQUIRED | 401 credentials invalid/expired | Refresh/re-auth | Sign in |
| CHILD_SCOPE_DENIED | 403 action-specific guardian grant missing | No | Access not granted |
| DEVICE_REVOKED | 403 device enrollment invalid | No | Re-pair with authorized person |
| EVENT_REPLAY_CONFLICT | 409 duplicate event ID with different digest | No, investigate | Data conflict |
| REVISION_CONFLICT | 409 stale place/policy version | Refresh-and-retry | Updated elsewhere |
| INVALID_GPS | 422 malformed/impossible location | Correct data | No reported position |
| CAPABILITY_UNSUPPORTED | 422 or device UNSUPPORTED | No | Feature unavailable on this device |
| PERMISSION_REQUIRED | device terminal response | Needs local OS grant | Permission needed |
| USER_ACTION_REQUIRED | device terminal response | On-device interaction | Finish setup on child device |
| OS_REJECTED | device terminal response | Only if context changes | Android prevented action |
| RATE_LIMITED | 429 + Retry-After | Yes, bounded | Retry scheduled |
| DEVICE_OFFLINE | Command delivery deferred | Yes until expiry | Pending; not completed |
| INGEST_UNAVAILABLE | 503, no durable ack | Yes with same event IDs | Sync delayed |
| LOCATION_STALE | Successful read of last known fix | GPS may later recover | Last seen at timestamp |
| TRIP_PROVISIONAL | Processing incomplete / late data possible | Not client retry | Trip may update |
| ACCOUNT_DELETION_QUEUED | 202 deletion request accepted | Query verified status | Deletion pending |

Use one structured error format: code, message, request_id, retryable, optional safe details. Avoid leaking whether another family's child/device exists (403/404 disclosure policy). Error codes must be reconciled with actual OpenAPI response shapes.

## 7. Verification plan

- Command transition property tests: every illegal edge denied, terminal outcomes immutable, expiry/race and idempotent replay.
- SOS offline/partial FCM delivery/guardian revocation/notification disabled, acknowledgement trace.
- Usage aggregation leap/DST/time-zone and duplicate interval tests.
- Queue process kill, key invalidation, storage nearly full, network blackout, Retry-After and duplicate 202 receipt tests.
- Managed DPC schedule day/night reboot, rollback and critical package exclusions.
- Real-device permitted sound test including mute/DND and user-perceptible status.

This document fills **protocol design**, not deployed function or delivery guarantees.

## 8. FR-044 fallback and India child-data release qualification (2026-10-26)

This contract's FCM fanout is **best-effort**, not an independently reliable SOS delivery solution. [SOS Escalation and Independent Fallback](SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md) defines **durable receipt → provider-submitted → authenticated guardian-acknowledged** states, timed no-ACK escalation, consented verified recipient and optional SMS, plus failure testing when OCI API/DB/worker are lost together. **An SMS request from the same failed VM is not an independent outage fallback.** Provider, India telecom sender registration/templates and pricing remain unselected.

**Shipping rule:** real minor's SOS tracking/guardian recipient processing needs India DPDP purpose and US-hosting legal review; only truthful best-effort child-initiated check-in can proceed after applicable signoffs. No marketing as guaranteed emergency dispatch without independent failure-domain proof, funded provider and support. Test SOS-01–12 from the fallback document; leave FR-044 emergency-level release BLOCKED.

## 9. Conditional media commands and exact parent reason codes — 2026-10-26

The owner accepted **conditional engineering research** for one-way live audio, authorized audio recording, camera live/snapshot/video, scoped MediaStore/SAF files and per-session MediaProjection. Commercial media delivery remains feature-flagged OFF until OS, India child-data law, Google Play and security gates pass. Alarka main Activity ordinarily stays closed after setup, while required notification and Android sensor indicators remain visible. Standard/background and genuinely provisioned device-owner sensor startup must be separately verified. See [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md).

Retain existing durable command statuses and OpenAPI nullable `Command.reason_code`. Proposed **device-evidenced** codes: `FEATURE_NOT_RELEASED`, `DEVICE_NOT_REACHABLE`, `MICROPHONE_PERMISSION_MISSING`, `CAMERA_PERMISSION_MISSING`, `MEDIA_SCOPE_NOT_GRANTED`, `BACKGROUND_SENSOR_START_BLOCKED`, `MANAGED_ENROLLMENT_REQUIRED`, `CHILD_DEVICE_ACTION_REQUIRED`, `SCREEN_SHARE_CONSENT_REQUIRED`, `SENSOR_UNAVAILABLE`, `PROTECTED_SCREEN_CONTENT`, `SESSION_INTERRUPTED`, `NETWORK_OR_RELAY_UNAVAILABLE`, `LOCAL_STORAGE_UNAVAILABLE`, `CAPABILITY_STATUS_STALE`; denial of guardian scope is handled **before dispatch**.

**New parent acceptance invariant:** Madalasa shows actual `status + reason_code + safe next action` for every unavailable requested feature, with accurate last-reported timestamp. `PERMISSION_REQUIRED` only after permission failure is actually verified; `USER_ACTION_REQUIRED` for needed Android interaction/MediaProjection prompt; `OS_REJECTED` for evidenced Android denial; `UNSUPPORTED` for not-released or incompatible mode; `DEVICE_OFFLINE` is uncertain and must not be misdiagnosed as a sensor error. A delivered push, `ACCEPTED` or `QUEUED` is not verified recording success. Distinguish session active/streaming/ended from snapshot/file completion. End on guardian revoke/expiry; prevent replay/duplicate stream; no payloads in push/logs. Tests T-MEDIA-01–18 from ADR are NOT_TESTED. M1 API scope remains unchanged.

## 10. 2026-10-27 Alarka capability snapshot and parent state synchronization protocol

See [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md). **Capability snapshots are NOT remote command results.** Alarka POST baseline and later on verified grant/revoke/regrant; server validates device credential/enrollment generation, feature allowlist, schema, payload caps, observed_at and **monotonically increasing report_version**. Same version+digest = idempotent receipt; same version+different content = conflict; older version never rolls back newest (especially revoked) state. Server assigns independent `received_at/server_revision`, persists latest snapshot + bounded redacted change event transactionally, ACKs only after durable write and emits parent change hint. Parent reads child-specific authorized GET; FCM hint does **not** prove parent delivery nor OS granted access.

**Parent UI contract:** show `hardware / permission / scope / runtime / release / last verified / freshness` rather than a single boolean. `GRANTED` may be green only as a *verified Android permission*; operational READY remains conditional if Android service start, legal/Play flag or privacy scope prohibits it. Verify `NO_DEVICE_REPORT`, `DEVICE_OFFLINE`, `STALE_CAPABILITY`, `PERMISSION_DENIED`, `PERMISSION_REVOKED`, `SCOPE_PARTIAL`, `ONE_TIME_EXPIRED`, `BACKGROUND_SENSOR_START_BLOCKED`, `SCREEN_SHARE_CONSENT_REQUIRED`, `REPORT_VERSION_CONFLICT`, `REPORT_UPLOAD_PENDING`; final values should be reconciled with OpenAPI before freezing. On no child response do not hallucinate a permission diagnosis. Android revoke can kill Alarka: post-fact sync delayed until next eligible execution. Never let parent submit child capability truth.

## 11. 2026-10-27 media-session logging command correlation (metadata-only)

Per [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md), media-activity logging extends but does not replace existing durable Command.status/state transitions. Distinguish **intent** REQUESTED/QUEUED/DELIVERED/DEVICE_ACCEPTED, **session** MEDIA_STARTED/STREAMING/MEDIA_STOPPED/FAILED and **client evidence** DISPLAY_CONFIRMED/SAVED_PARENT_LOCAL/SAVE_FAILED. A pushed or device-accepted command never equals viewed or saved. Authenticate Alarka OS failure source and Madalasa local save/view receipt; append one idempotent lifecycle event per source_event_id with command_id+session_id; reconcile out-of-order signed records without inventing time/success.

Persist result category AUDIO/IMAGE/VIDEO_AV/SCREEN_SHARE; operation; parent/child/device IDs; UTC/actual duration; file_size_bytes NULL unless parent-local confirmed; bytes_transferred separate; storage outcome; allowlisted reason_code + evidence category. Map CAMERA_IN_USE only to Android camera exception, AUDIO_CAPTURE_SILENCED only when observed, PHONE_CALL cause only if specifically verified; offline/no response is UNKNOWN/DEVICE_OFFLINE. Parent/admin metadata reads never cause capture or wake child device. No binary media in events, logs or VPS storage. T-AUD-01–22 remain planned; P3 media endpoints and actual child capture remain release-gated.
