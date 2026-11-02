# MA-CAP-ADR-002 — Alarka Device Discovery, Permission Wizard, Verified Capability Sync and Madalasa State UX

> **Document control:** M1 / 03-security-and-permissions · Proposed owner: Security + Android/backend (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Decision:** 2026-10-27 · **Owner direction accepted for design** · **Implementation:** NOT_IMPLEMENTED / NOT_DEVICE_TESTED  
**Apps:** Alarka = child Android companion; Madalasa = guardian Android app. **Server:** C++20 Drogon/API + PostgreSQL.  
**Prerequisites:** authenticated child-device pairing, signed/account-scoped guardian access, legal/Play release gates.  
**Relevant existing requirements:** FR-001 secure pairing, FR-002 onboarding, FR-006 command truthfulness, FR-008/009/010 scoped media, FR-014 operational status, FR-039 capability-before-purchase, FR-040/041 transparency, NFR security/freshness.  
**Related:** [Media runtime decision](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md), [Android matrix](ANDROID_COMPATIBILITY_MATRIX.md), [M1 API](../../../openapi-m1.yaml), [draft whole-project API](../../../openapi.yaml).

## 1. Exact owner decision

1. At the **first launch of Alarka**, perform a **read-only device compatibility scan before requesting sensitive permissions**: Android API level/target SDK/app version, manufacturer/model only as needed for compatibility, location/camera/microphone availability, installed public hardware features, limited accessible media capabilities, notification support, Usage Access availability, foreground-service execution constraints and enrollment mode. Detection is **not media capture** or approval to collect child data.
2. Show a per-feature list: **SUPPORTED / UNSUPPORTED / UNKNOWN** at hardware/API level, distinct from **NOT_REQUESTED / DENIED / GRANTED / PARTIAL / TEMPORARY / REVOKED** Android grant states and from **AVAILABLE / CONDITIONAL / ACTION_REQUIRED / UNAVAILABLE / UNKNOWN** operational states. Never display a mere permission grant as continuous live microphone/camera activation.
3. Pair to the correct child/family using one-use code, Android Keystore-bound enrollment credential, server-side child ownership and guardian authority verification. **Only after successful pairing** upload a signed/device-authenticated baseline versioned capability report; server stores minimized latest state plus bounded audit history. The parent cannot forge an Alarka permission report.
4. The backend offers an **authenticated, child-scoped GET API** so Madalasa can show compatibility, permissions, operational conditions, feature-release eligibility, latest device-observed time and server receive time. Backend may signal a change via event/FCM; Madalasa fetches the authoritative server record. Notification delivery does not prove the child saw it.
5. Alarka presents an **individual, progressive, user-visible permission guide**: explain purpose, exact data, recipients, scope, duration, optionality and safety/Play context before launching **Android-controlled** permission dialog/Settings/SAF picker. User can decline optional steps. Parent's "start" button does not grant Android permission itself.
6. After **every Android result** (ActivityResult, resume from Settings, SAF picker, notification/special access screens), Alarka must **re-read the actual OS state**, assign new device-local monotonic revision when state truly changes, report securely, wait for durable server ACK, then Madalasa refreshes. Separate: (a) local granted, (b) server received, (c) parent observed. A locally granted permission with an offline child is **not yet a parent-confirmed green report**.
7. When Android permission is revoked or scope changes later, Alarka detects it at the **next eligible observation** (app resume, allowed sync, service startup, command execution, device reboot after normal restart), persists a new revision and re-syncs. **No guarantee of immediate notification** when background restricted/offline, force-stopped or Android terminates Alarka on revocation. Never infer a sensor-specific cause solely from silence.
8. For reapproval, use the same visible Android system flow, re-check, revision and sync sequence. A grant of camera/mic during initial setup is **not a permanent future background FGS exemption**; a device-owner exception must be validated on genuinely provisioned devices. MediaProjection **requires fresh OS consent per session**, not a persistent permission.
9. Main Alarka **Activity can close after initial setup** and normally stay closed. Identifiable monitoring app icon/required ongoing monitoring notification and OS camera/microphone indicators remain, and Android system prompts require valid device-side interaction. No covert capture or bypassing Android policies.
10. "Feature green" for Madalasa means **known supported, correctly granted within intended scope, currently release-enabled, fresh and verified as ready in its stated context**, or a separate **permission-granted green check** explicitly labeled as a permission only. Use amber for conditional, partial, temporary, need-action; red for verified unavailable/revoked/unsupported; grey for unknown/offline/stale/pending. Always show reason, last verified and next allowed action. Never represent remote audio/video RESEARCH P3 as commercially active merely because permission is granted.

## 2. Discovery adapters and Android system constraints

| Layer | Candidate Android API / probe | Can determine | Cannot promise |
|---|---|---|---|
| Build/platform | `Build.VERSION.SDK_INT`, targetSdk and app version; `PackageManager.hasSystemFeature` | API/declared hardware compatibility, Android version | Third-party OEM startup behavior; legal release |
| Camera | `PackageManager.FEATURE_CAMERA_ANY`, `CameraManager.cameraIdList` and camera characteristics | Reported available front/rear lenses/characteristics | Camera access will succeed when camera busy/blocked, or remote background service launch |
| Microphone | `PackageManager.FEATURE_MICROPHONE`, `AudioManager` where public | Declared audio input availability | Always-available ambient listening/privileged voice call input |
| GPS/location | `LocationManager`, package features, permission checks and settings | Provider enabled state/grant/approximate vs precise when exposed | Guaranteed accurate position, continuous background fixes |
| Sensors | `SensorManager.getSensorList`, where needed | Public motion/other sensor inventory | Sensitive/privileged sensors or actual location accuracy |
| Notifications | `NotificationManager.areNotificationsEnabled` and relevant POST_NOTIFICATIONS permission | App notification settings at verification time | Guaranteed displayed notification/delivery |
| Usage Access | documented UsageStats/AppOps special access or OS Settings flow | Whether authorized usage APIs are eligible at verification time | Retrospective completeness; authority to profile children |
| Shared photos/videos/audio | MediaStore permissions and Android Photo Picker or selected-photo grant | Approved visible scope (ALL/SELECTED/NONE), feature-specific | Full photos when only selected; another app's private data |
| Documents/folders | Storage Access Framework picker and persisted URI grants | User-selected files/folders allowed by Android | Unrestricted filesystem browsing |
| Screen view | MediaProjection availability and user system prompt | OS support and **per-session** approval | Persistent setup grant or capture of FLAG_SECURE windows |
| Managed-device role | `DevicePolicyManager.isDeviceOwnerApp` / actual provisioned status | True DPC owner role for an enrolled package | Privilege inferred from Device Administrator toggle alone |
| Camera/mic service start | current permission + typed FGS declaration, current eligible Android context and executed test | At execution, whether an attempted authorized session worked | Universal foreground-service access based on setup grant |
| Global sensor privacy | Public APIs only where permitted, otherwise mark UNKNOWN | Available verified sensor blocking evidence | Reliably detecting every OEM/privacy/hardware switch |

**Permission ordering:** Foreground location first; background location only in a separate Android-compliant step (Android 11+ ignores a simultaneous foreground/background request). Request notification permission where required; Usage Access is a **Settings special grant**, SAF/Photo Picker uses system selection, and CAMERA/RECORD_AUDIO use runtime dialogs **only in approved builds** with applicable functionality. In-app pre-disclosure is not the Android permission dialog. Android 11+ supports one-time location/camera/microphone permissions; expect expiry and Android process termination upon certain revocations. Avoid repeated prompt harassment and safely handle "Don't ask again", Settings-denied, selected-media limits and Android permission auto-reset.

## 3. Alarka startup and permission wizard finite state machine

`NEW_INSTALL → LOCAL_DISCOVERING → LOCAL_SCAN_READY → PAIRING_PENDING → PAIRED → BASELINE_REPORT_PENDING → BASELINE_ACKED → WIZARD_DISCLOSURE → WAITING_ANDROID_RESULT → VERIFYING_OS_STATE → UPDATED_REPORT_PENDING → UPDATED_REPORT_ACKED → (NEXT_STEP | SETUP_COMPLETE)`

Other outcomes: `OS_DENIED`, `PARTIAL_SCOPE`, `TEMPORARY_GRANT`, `FEATURE_NOT_RELEASED`, `DEVICE_UNSUPPORTED`, `NETWORK_OFFLINE`, `REPAIR_REQUIRED`, `REVOKED`. None grants prohibited functionality. A restart must resume safely from persisted onboarding progress **without reusing a pairing code or replaying a one-time OS consent token**. The baseline upload must be authenticated and idempotent. Keep screen progress useful even without network; do not declare parent sync succeeded before server confirmation.

**Routine lifecycle checks** after setup: compare on `onResume`; on actual permission-request result; before each sensitive operation; at permitted WorkManager/FCM-triggered and heartbeat synchronizations; on applicable package/policy update, boot and mode changes after permitted startup. Limit scanning and transmission: do not poll sensors continuously or wake the device solely for a parent opening a static dashboard.

## 4. Canonical versioned report and parent projection

**Suggested report format (design, not committed handler):**

```json
{
  "schema_version": 1,
  "enrollment_generation": 1,
  "report_version": 18,
  "observed_at": "2026-10-27T00:10:00Z",
  "android_api": 36,
  "mode": "STANDARD",
  "target_sdk": 36,
  "app_version": "0.1.0-test",
  "features": {
    "microphone": {
      "hardware": "SUPPORTED",
      "permission": "GRANTED",
      "scope": "WHILE_IN_USE",
      "runtime": "CONDITIONAL",
      "release": "RESEARCH_DISABLED",
      "reason_code": "BACKGROUND_SENSOR_START_RESTRICTED",
      "checked_at": "2026-10-27T00:10:00Z"
    },
    "photos": {
      "hardware": "SUPPORTED",
      "permission": "PARTIAL",
      "scope": "SELECTED_ITEMS",
      "runtime": "AVAILABLE_WITHIN_SCOPE",
      "release": "RESEARCH_DISABLED",
      "checked_at": "2026-10-27T00:10:00Z"
    }
  }
}
```

**Server-generated fields:** `received_at`, `server_revision`, `last_seen_at`, `freshness`, release-policy/entitlement flags, redacted change summary and safe parent suggestion. Do not accept these values from a child payload as authoritative server facts. `report_version` is monotonic **within enrollment_generation**, and an older report never restores a previously revoked green flag. Identical repeated report (same version+digest) returns idempotent receipt; same version and different digest is a conflict. Time drift is checked with tolerance; `received_at` never equals device-observed time by assumption.

**Minimum storage design:** `device_capability_snapshots(device_id PK, enrollment_generation, report_version, observed_at, received_at, schema_version, minimal_fingerprint, payload_json, audit_digest)`; separate bounded `device_capability_changes` for material transitions (permission/scoped grant, runtime-mode, release gate), retaining device ID/time/reason but no child media/raw location/contacts/document names. All reads by child-scoped guardian authorization; device updates ONLY by self-bound authenticated Alarka. Raw device identifiers must be minimized.

**Interfaces:** Existing M1 `POST /devices/{deviceId}/capabilities` remains a **narrow M1 snapshot**. Whole-project draft `POST /devices/{deviceId}/capabilities` is extended to a richer report and durable ACK; proposed parent `GET /children/{childId}/devices/{deviceId}/capabilities` returns authorized projection + `ETag`/freshness, not raw internal sensor fingerprint. Parents may request a bounded recheck as a permitted command; it is a **request** and cannot bypass OS process limitations. No media capture endpoint is implied. Reconcile the M1 schema and migration only through a separate scoped change with tests; do not silently break the currently linted M1 contract.

## 5. Parent color, freshness and failure semantics

| UI | When justified | Parent copy |
|---|---|---|
| Green `PERMISSION GRANTED` | Authenticated current Android grant is verified; **permission column only** | "Microphone permission granted · capture availability conditional" |
| Green `READY / AVAILABLE` | Supported + permitted scope + release-enabled + recently verified operational context | "Notifications available · checked [timestamp]" |
| Amber `CONDITIONAL` | OS FGS/start restriction, managed-only gate, partial/temporary grant | "Camera permission granted; new background session may require on-device action" |
| Amber `ACTION REQUIRED` | Android prompt/Settings/MediaProjection session consent needed | "Approve on Alarka's phone" |
| Red `DENIED / REVOKED` | Current authenticated device observation proves denial | "Location permission revoked · last confirmed [timestamp]" |
| Red `UNSUPPORTED / NOT RELEASED` | Genuine hardware/OS not available, or official release/legal flag blocks | "Feature is unavailable in this build"; do not advise bypass |
| Grey `OFFLINE / STALE / UNKNOWN / PENDING` | No fresh device confirmation or server ACK | "Last verified [timestamp]; current permission state not confirmed" |

**Never confuse:** feature hardware supported, Android permission granted, system sensor available, session running, legal release gate and parent-visible status. The parent should see reason-specific next steps mapped to `Command.status/reason_code` of [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md), e.g. `CAMERA_PERMISSION_MISSING`, `MICROPHONE_PERMISSION_MISSING`, `BACKGROUND_SENSOR_START_BLOCKED`, `SCREEN_SHARE_CONSENT_REQUIRED`, `MEDIA_SCOPE_NOT_GRANTED`, `DEVICE_NOT_REACHABLE`; an offline report cannot prove "permission revoked."

## 6. Security, abuse, availability and privacy requirements

- Device reports use existing M1 enrollment/Keystore PoP identity; authenticated parent GET requires live scope/role and rate limits. Never let Madalasa submit a fabricated child sensor report; a parent "permission accepted" button is only UI confirmation, **not Android authority**.
- Enforce schema allowlist, payload byte/feature count caps, input timestamps and version monotonicity, replay protection, server-produced receipts and cross-family zero-access negative tests. On revoke/re-enroll, increment `enrollment_generation`, expire old credentials and prevent stale report resurrection.
- WorkManager background jobs are best effort (Doze, OEM restriction, Wi-Fi/data, app force-stop, process kill). A permission revoke can terminate an Android process; until next authenticated observation show STALE/UNKNOWN rather than an invented real-time transition. Do not promise immediate real-time changes.
- Separate collection of hardware/permission *metadata* from any child location/history/usage/media processing; minimum required purpose, retention, disclosure, third-party/processor analysis and adult guardian authority. Protected feature release flags (particularly precise child location, usage, camera/mic) remain **OFF** until India DPDP and Play/Families review. Do not use capability scanning to begin collecting minor's actual sensor data.
- Do not require all optional permissions to install/use unrelated features; no coercive prompts or stealth sensor operations. Respect app-wide uninstall, Android privacy indicators, system notification and guardian revocation.
- Check feasibility on representative Pixel/Samsung/OEM phones Android API 29–36, target SDK required by Play, standard and genuinely provisioned device-owner modes. Record build hash, app/OS versions, screenshot, command result and user-facing reason.

## 7. Tests and evidence (all NOT_IMPLEMENTED / NOT_TESTED)

| ID | Test | Required proof |
|---|---|---|
| T-CAP-01 | Fresh launch with no grants | Read-only scan finds public hardware only; no sensor capture |
| T-CAP-02 | Present/absent camera/mic/GPS | Correct SUPPORT vs UNKNOWN vs UNSUPPORTED, with OEM evidence |
| T-CAP-03 | Pairing not complete | No report upload readable by unauthorized parent |
| T-CAP-04 | Pairing succeeds | Device-bound signed/authenticated baseline report, server durable ACK |
| T-CAP-05 | Invalid/foreign parent report | IDOR denied; cannot spoof child device or mark grants GREEN |
| T-CAP-06 | Android permission accepted | Re-read OS state; local granted → server ACK → parent verified |
| T-CAP-07 | Permission declined / Don't ask again | Never assert granted; legal path to Settings, optional skip |
| T-CAP-08 | Foreground then background location on Android 11+ | Separate prompts; simultaneous request not used; version evidence |
| T-CAP-09 | Approximate vs precise / one-time grant | PARTIAL/TEMPORARY represented, no false fine/all-time status |
| T-CAP-10 | POST_NOTIFICATIONS / monitoring identity | Visibility, denied state, correct Android notification status |
| T-CAP-11 | Usage Access via Settings | AppOps checked after returning, not inferred from intent |
| T-CAP-12 | Photo selected-items / SAF URI | Scope-limited permissions, revoked URI denied |
| T-CAP-13 | Standard camera/mic startup restricted | GRANTED permission, CONDITIONAL operation, no covert capture |
| T-CAP-14 | Actual device-owner DPC | Owner mode distinguished from legacy admin; OEM evidence |
| T-CAP-15 | MediaProjection fresh consent | Permission only per session, fresh OS approval each time |
| T-CAP-16 | Revoke one-time/granted permission | Stop invalid use; recheck when app next runs; no instant guarantee |
| T-CAP-17 | Permission auto-reset / process kill | Parent shows STALE/UNKNOWN until new verified report |
| T-CAP-18 | Regrant via Settings | New OS check, newer report, then parent UI verified |
| T-CAP-19 | Offline after local grant | Parent must NOT turn green without durable server ACK |
| T-CAP-20 | Reordered/duplicated/outdated revisions | Ignore stale reports, idempotent same digest, conflict different digest |
| T-CAP-21 | Server restart/FCM lost | Parent fetch recovers canonical state; no duplicate false notification |
| T-CAP-22 | Wrong-family / revoked guardian | No child capability leak via API, caches, SSE or push |
| T-CAP-23 | Freshness/OS service context changes | READY degrades to CONDITIONAL/UNKNOWN rather than stale active green |
| T-CAP-24 | Figma state fidelity and accessibility | 46 screen mockups map to code states; colors accompanied by labels |

## 8. Editable Figma handoff (saved 2026-10-27)

**46 new Android screen mockups:** [Alarka + Madalasa capability onboarding page](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-2), 24 Alarka (`A-01…A-24`), 22 Madalasa (`P-01…P-22`) with individual developer implementation notes. [Capability sync HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=27-2), [permission/revocation LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=27-40), plus existing earlier media diagrams. Visuals are **editable mockups, not Android dialogs or implemented API**. Complete node index in [Figma handoff](../../../ui/figma-functional-handoff/README.md).

## 9. Official Android references

- Android runtime permission request and one-time grants: https://developer.android.com/training/permissions/requesting
- Foreground and separate background location request: https://developer.android.com/develop/sensors-and-location/location/permissions/runtime
- Android camera/microphone FGS exceptions: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- Android MediaProjection: https://developer.android.com/media/grow/media-projection
- Android shared media: https://developer.android.com/training/data-storage/shared/media
- Google Play monitoring apps: https://support.google.com/googleplay/android-developer/answer/9888380

**Rule:** This ADR updates the **design target** and does not close previous legal, India DPDP, Google Play, managed-device, security, device compatibility or release blockers.

## 2026-10-27 separated media activity-event logging versus OS permission capability reports

Permission/hardware capability reports and **media activity history** remain independent data systems. Capability snapshot can say microphone grant/release runtime is conditional; a media_activity event records **an actual authenticated media request/attempt/verified result**, not the device capability itself. Both are child-scoped, minimally stored and UTC-stamped. Denied or offline requests have reason evidence and no fictitious duration/file size; P3 camera/mic research flag OFF still prohibits real-minor capture. Parent screens for media event history and admin case-access browser: [07 media audit Figma inventory](../../../ui/figma-functional-handoff/07-media-activity-audit.json); source [media audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md), [admin console](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md).
