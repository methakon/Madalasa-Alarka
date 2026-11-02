# MA-AUDIT-ADR-003 — Media Activity Metadata, Lifecycle Evidence, Parent History and Admin Audit

> **Document control:** P3 / 01-media-and-administrator-research · Proposed owner: Product + security/privacy (not assigned) · Registry: DEFERRED_RESEARCH_DESIGN; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Decision date:** 2026-10-27  
**Product owner scope accepted for design:** record *media-operation metadata* and real failure reasons; allow a parent to filter the histories of their authorized children; allow appropriately scoped support/security administration to search parent and child histories.  
**Status:** DESIGN ONLY / NOT IMPLEMENTED / NOT DEVICE-TESTED / NOT LEGALLY OR GOOGLE-PLAY APPROVED / MEDIA CAPTURE RELEASE FLAGS OFF.  
**Related:** [Media feasibility MA-MEDIA-ADR-001](MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md), [Capability scan MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md), [Admin-panel specification](ADMIN_PANEL_SPECIFICATION_2026.md).

## 1. Explicit data boundary — no VPS media file storage

Alarka, Madalasa and the backend may produce minimal **session/event metadata** about a *lawfully authorized and Android-supported* action. Backend MUST NOT store the actual photo, audio, AV/video recording, screen frames, thumbnails, previews, file names, file paths, transcriptions, audio fingerprints, raw media buffers, hidden device content, or shared media payloads. The proposed WebRTC direct/TURN encrypted relay remains memory-only packet forwarding; a verified parent-side recording, when ever lawfully released, remains encrypted locally at Madalasa and is **not** an admin-downloadable asset.

Do log approved minimal fields: event/session/command IDs, family scope, parent actor ID, child and enrolled device ID, media category (AUDIO / IMAGE / VIDEO_AV / SCREEN_SHARE; optionally FILE_TRANSFER in adjacent audit category), action (LIVE_VIEW / SNAPSHOT / RECORD / SAVE / TRANSFER / REQUEST), timestamps, **verified** session duration, result (started/completed/viewed/saved/failed/cancelled/expired/unknown), optional measured file_size_bytes and separately measured bytes_transferred, storage outcome, reason_code, OS error source and diagnostic confidence. Parent and child **names are resolved at read time** in the approved family/identity service, not duplicated into every immutable event. Administrator must not see capture payloads or media URLs because they do not exist on the VPS.

Save semantics:
- `VIEWED_ONLY` only after a valid parent app playback/display receipt; a relay connection or FCM delivered does not prove the human viewed/heard the stream.
- `SAVED_PARENT_LOCAL` only after a signed, authenticated Madalasa **local-write receipt** (bytes and safe destination type), and is a historical acknowledgement, **not proof that the file still exists** after the parent deletes it. `FILE_SAVE_UNKNOWN` when no receipt.
- `file_size_bytes` is **nullable**: live-only streams have no file; a failed capture may have zero bytes or NULL depending on actual evidence. Never confuse `bytes_transferred`, `encoded_media_bytes`, `file_size_bytes` and `content_length`.
- `duration_ms` can be computed from verified STARTED/STOPPED device or parent receipts with approved monotonic measurement/clock skew; NULL for never-started/unknown. No inferred precision from request timestamps; optionally distinguish `request_wait_ms` from `active_duration_ms`.

## 2. Lifecycle, provenance and verified failure classification

Write an append-only lifecycle event for each authenticated transition and maintain a normalized summary/projection. Suggested transitions:

```
REQUESTED → AUTHORIZED → QUEUED → DELIVERED → DEVICE_ACCEPTED
                                      ↘ FAILED / EXPIRED / USER_ACTION_REQUIRED
DEVICE_ACCEPTED → MEDIA_STARTED → STREAMING → MEDIA_STOPPED → (VIEWED_ONLY | SAVED_PARENT_LOCAL | SAVE_FAILED)
                                                ↘ SESSION_INTERRUPTED / FAILED
```

Attempt outcomes may be `DENIED`, `OS_REJECTED`, `NOT_RELEASED`, `CANCELLED`, `TIMED_OUT`, `UNKNOWN` at the appropriate stage. An accepted/sent/queued command is **not** a capture completion or a viewed session. Distinguish **command status** (existing `Command.status`) from **media session state** and **local storage receipt**. Correlation IDs make all three queryable without inventing achievements.

**Common stable reason codes** (extensible enum; do not log arbitrary exception strings):
- `CAMERA_IN_USE` (Android CameraAccessException.CAMERA_IN_USE, if verified)
- `MAX_CAMERAS_IN_USE` (Android camera resource limit, if verified)
- `CAMERA_DISABLED_BY_POLICY`, `CAMERA_DISCONNECTED`, `CAMERA_ERROR` (only if OS signals them)
- `MIC_PERMISSION_DENIED` / `CAMERA_PERMISSION_DENIED` (actual package/runtime permission verification)
- `AUDIO_CAPTURE_SILENCED` / `AUDIO_INPUT_UNAVAILABLE` (observed capturer configuration/zero-input; competing-app attribution only if verified)
- `AUDIO_INTERRUPTED`; `CALL_INTERRUPTION_CONFIRMED` **only** when supported telephony/session evidence permits this explicit cause; otherwise `AUDIO_INPUT_UNAVAILABLE` / `UNKNOWN`. Do **not** infer "on a call" from an audio failure.
- `BACKGROUND_SENSOR_START_BLOCKED`, `CHILD_DEVICE_ACTION_REQUIRED`, `SCREEN_SHARE_CONSENT_REQUIRED`, `MEDIA_SCOPE_NOT_GRANTED`, `PERMISSION_REVOKED`, `SESSION_INTERRUPTED`, `DEVICE_OFFLINE`, `NETWORK_OR_RELAY_UNAVAILABLE`, `LOCAL_STORAGE_UNAVAILABLE`, `SAVE_FAILED`, `REQUEST_TIMED_OUT`, `FEATURE_NOT_RELEASED`, `UNKNOWN_FAILURE`.
- Keep original OS signals in a **bounded, allowlisted diagnostic** (e.g. integer camera code, Android API level, app build) and an explicit `reason_evidence = DEVICE_OS | PARENT_RECEIPT | SERVER_TRANSPORT | POLICY_GATE | UNKNOWN`; never dump exception stacks, private filenames or phone-number/call details into logs.
- Offline without an Alarka confirmation → `DEVICE_OFFLINE` / `UNKNOWN`, **not** an invented `MIC_IN_USE` or `ON_CALL` cause.

## 3. Proposed minimal relational schema — migration not executed

Below is **conceptual PostgreSQL DDL** for a reviewed future migration; reconcile references, partitioning and enum strategy with the canonical SQL migration. Assume UUID primary identities validated by existing family/device/guardian tables. Avoid globally queryable child event tables for the app role; enforce RLS and controller child-scope checks.

```sql
CREATE TABLE media_activity (
  id uuid PRIMARY KEY,
  family_id uuid NOT NULL,
  child_id uuid NOT NULL,
  device_id uuid NOT NULL,
  requesting_guardian_id uuid NOT NULL,
  command_id uuid,
  session_id uuid,
  media_kind text NOT NULL CHECK (media_kind IN ('AUDIO','IMAGE','VIDEO_AV','SCREEN_SHARE')),
  activity_kind text NOT NULL CHECK (activity_kind IN ('LIVE_VIEW','SNAPSHOT','RECORD','SAVE','REQUEST')),
  outcome text NOT NULL CHECK (outcome IN (
    'REQUESTED','QUEUED','ACTIVE','VIEWED_ONLY','SAVED_PARENT_LOCAL',
    'SAVE_FAILED','FAILED','CANCELLED','EXPIRED','DENIED','UNKNOWN')),
  request_at timestamptz NOT NULL,
  capture_started_at timestamptz,
  capture_ended_at timestamptz,
  duration_ms bigint CHECK (duration_ms >= 0),
  file_size_bytes bigint CHECK (file_size_bytes >= 0),
  bytes_transferred bigint CHECK (bytes_transferred >= 0),
  storage_outcome text NOT NULL CHECK (storage_outcome IN (
    'NOT_APPLICABLE','VIEWED_ONLY','PARENT_LOCAL_CONFIRMED','SAVE_FAILED','UNKNOWN')),
  reason_code text,
  reason_evidence text NOT NULL DEFAULT 'UNKNOWN',
  os_api_level integer,
  device_report_version bigint,
  last_verified_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (capture_ended_at IS NULL OR capture_started_at IS NOT NULL)
);
CREATE INDEX media_activity_by_parent_time
  ON media_activity (requesting_guardian_id, request_at DESC, id DESC);
CREATE INDEX media_activity_by_child_time
  ON media_activity (family_id, child_id, request_at DESC, id DESC);
CREATE INDEX media_activity_by_failure
  ON media_activity (family_id, reason_code, request_at DESC, id DESC)
  WHERE reason_code IS NOT NULL;

CREATE TABLE media_activity_events (
  id uuid PRIMARY KEY,
  activity_id uuid NOT NULL REFERENCES media_activity(id),
  event_kind text NOT NULL,
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  source_type text NOT NULL CHECK (source_type IN ('ALARKA','MADALASA','SERVER')),
  source_event_id text NOT NULL,
  reason_code text,
  evidence_kind text NOT NULL,
  payload_digest text,
  UNIQUE(source_type, source_event_id)
);
CREATE INDEX media_activity_events_by_activity
  ON media_activity_events(activity_id, occurred_at, id);
```

Enforce strong FK/CHECK/RLS and actor/family/device binding through migration (illustrative DDL omits existing table identifiers). Summary row is a projection of authenticated **append-only** lifecycle events; record correction as a separate reconciliation event (no silent history rewrite). Protect audit append permissions from normal feature code. If legally permissible configure immutability / trusted external append-only replication, otherwise call the log **tamper-evident best effort**, not absolutely immutable. Session content is never persisted.

**Admin access audit** belongs in a *separate* `admin_access_audit` store: timestamp, authenticated admin actor/role, case_reference, purpose code, route/action, requested parent/child filters (minimized), result count/status, UTC time, retention classification and request ID. Search suggestions and export attempts are access events too. Do not store free-text sensitive notes in event fields; case reference must refer to controlled case system. Audit every detailed read; no ordinary administrative delete/update of security audit records.

## 4. Parent API, search, date and pagination contract

Authorized Madalasa guardian:
`GET /v1/parents/me/media-activity?child_id=UUID&from=ISO8601&to=ISO8601&media_type=AUDIO&outcome=FAILED&page_size=20&cursor=...`

Optional child dropdown: `GET /v1/parents/me/media-activity/children` returns only active linked child IDs + display names, not another family's data. Child filter supports a single child or `all` permitted children. Parent UI includes **name+child ID** selection and date range (local timezone display; backend inclusive UTC `from`, exclusive UTC `to`), type, outcome, failure reason, paginated results, detail and empty/loading/error states. Default recent 7 days; cap individual range and earliest allowed range to data-retention policy. Results sorted `request_at DESC, id DESC`. Prefer opaque **keyset cursor pagination** (next/previous supported by cursor history); page size default 20 / max 100. Offset/page-number pagination only for safely bounded views if product explicitly needs arbitrary page jump; never run unbounded offset full table scans. Optional count is an authorized bounded total and never cross-family.

The list returns **no file URLs, filenames, recordings or thumbnails**; record size appears as '—' unless verified and `file_size_bytes != null`. For a parent with multiple children, dropdown always lists *only* children they can access; disabling a grant immediately invalidates cached results and pagination cursor access.

## 5. Administrator API and safeguards

The admin dashboard is a **separate privileged back-office interface**, not the child or parent Android app. See [admin module](ADMIN_PANEL_SPECIFICATION_2026.md) for full roles/screens.

Proposed restricted endpoints:
```
GET /v1/admin/media-activity                 # parent_id, child_id, from/to, type, outcome, reason, cursor/size
GET /v1/admin/media-activity/{activityId}    # redacted event detail
GET /v1/admin/media-activity/parents/suggest?q=...
GET /v1/admin/media-activity/children/suggest?q=...&parent_id=...
GET /v1/admin/media-activity/access-audit    # security-only scope
```

**Do not grant every administrator universal detailed access.** General support can see aggregate/redacted health only. Detailed named parent/child records require specific `MEDIA_AUDIT_READ` or incident/security scope, a server-issued **bounded case/purpose authorization**, step-up authentication, case expiration, supervisor or DPO gate for exceptionally broad access, and an append-only **read-access audit**. Suggestions are subject to the identical case scope as the eventual query to avoid enumeration. Child name autocomplete is preferably constrained by a selected authorized parent; name+ID matched server-side, never trusting UI-provided role, tenant or family IDs. Admin searches must not return direct child media content or permit start/stop sensor actions.

## 6. Lifecycle event ingestion (design only)

- Alarka produces device-authenticated `DEVICE_ACCEPTED`, `MEDIA_STARTED`, verified OS error, `MEDIA_STOPPED`; Madalasa produces guardian-authenticated `DISPLAY_CONFIRMED` and `LOCAL_SAVE_CONFIRMED` with measured file bytes and source session ID. Backend knows command dispatch, auth/policy refusal, timeout, ICE/TURN failure; reconcile duplicate/out-of-order updates by source_event_id and bounded timestamp.
- Do **not** trust either endpoint's unsigned claims or arbitrary file_size/started_at. Capture durations require monotonically measured session evidence with UTC conversion and plausibility checks; mark uncertainty. Neither TURN network bytes nor relay delivery proves human heard/viewed.
- Failed capture may not return a device receipt because offline or process killed; preserve `UNKNOWN / DEVICE_OFFLINE` and allow later signed reconciliation without mutating original event.
- Media P3 being OFF does not prevent testing the **metadata log module** with **synthetic/adult fixtures**, but it prevents actual recording pilot of children.
- No automatic capture or media-upload instruction is introduced by logging. A parent viewing logs does not wake the child device.

## 7. Privacy, retention, reliability and cost

Logs linked to a child reveal when monitoring occurred, by whom, its duration and success, so **sensitive personal metadata even without files**. Define data purpose, legitimate access, child rights, retention/deletion and backup/restore before use. **Retention values remain OWNER/COUNSEL TBD**, no silently invented 30/90-day guarantee. Use UTC stored times with parent-selected timezone rendering; minimize IP/device fingerprint, cap queries, avoid query logs containing names/PII, redact push summaries, rate limit autocomplete, and apply deletion/tombstone and legal hold only when validated.

Postgres storage should be comparatively modest but **not zero**; account for indexed rows, append-only events, backup, audit-of-admin-access, retention vacuum/partitions, per-tenant quotas and observed traffic before pricing. No VPS media files is a strict design constraint; the application can still process/transmit content during valid sessions and parent phone may retain recordings.

## 8. QA and formal acceptance

- T-AUD-01 request logging and single correlation chain; no duplicate event from retries
- T-AUD-02 success / VIEWED_ONLY receipt verified, no false viewing on server-delivery
- T-AUD-03 encrypted parent-local save ACK with measured size, distinguish saved vs currently present
- T-AUD-04 live-only duration and nullable size; compare transport bytes separately
- T-AUD-05 failed before capture (no duration/file, truthful reason)
- T-AUD-06 CameraAccessException CAMERA_IN_USE/MAX_CAMERAS_IN_USE mapping; no stack traces
- T-AUD-07 silenced concurrent mic, call interference: verified/unknown attribution only
- T-AUD-08 revoked permission/background restriction/MediaProjection consent mapping
- T-AUD-09 offline, FCM-only, timeout, duplicate/out-of-order and late signed reconciliation
- T-AUD-10 child family IDOR/RLS parent, wrong guardian denial and cache revoke
- T-AUD-11 multiple children dropdown and named child filter; zero cross-child leaks
- T-AUD-12 UTC/local date inclusive/exclusive daylight-saving boundaries, date input validation
- T-AUD-13 stable cursor pagination next/previous, changed rows, max page_size and no duplicates
- T-AUD-14 filter by media_kind, action, outcome, reason, saved/viewed; empty/loading/error UX
- T-AUD-15 admin step-up, case scope, purpose, expiration; support agent redacted-only
- T-AUD-16 admin parent/child autocomplete filtering within case; enumeration/rate limits
- T-AUD-17 admin detailed read/suggest/export attempt leaves immutable-style access audit
- T-AUD-18 re-enrollment/revocation, deletion/retention/restore safe (no resurrected event)
- T-AUD-19 database cardinality, 500/1000 children, indexes and load pagination
- T-AUD-20 no media binaries, filenames, thumbs, transcripts or phone data in DB/logs/push
- T-AUD-21 UI accessible sorting, pagination, labels and redacted privilege-denial states
- T-AUD-22 release flag OFF for media, no real-minor data pilot, legal/Play gate test

**All T-AUD-01–22:** PLANNED / NOT_IMPLEMENTED / NOT_TESTED. Evidence requires signed builds, API negative tests, DB migration, Android device receipts, security review and counsel/Play decisions before commercial availability.

## 9. Verified design navigation

Editable Figma parent log screens, admin console, metadata HLD/LLD and names/IDs are indexed in [Figma media-audit handoff](../../../ui/figma-functional-handoff/07-media-activity-audit.json) once authored. These screens are specification examples, not an implemented administrator portal. Maintain consistency with [FR-050 and FR-051](../../M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md) and [whole-project draft OpenAPI](../../../openapi.yaml). **The already scoped M1-only `openapi-m1.yaml` remains unchanged.**

## 10. Source notes

- Official Android camera error constants: https://developer.android.com/reference/android/hardware/camera2/CameraAccessException
- Android shared audio input priority / silencing: https://developer.android.com/media/platform/sharing-audio-input
- Existing Android capture authorization/release controls: [MA-MEDIA-ADR-001](MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md).
