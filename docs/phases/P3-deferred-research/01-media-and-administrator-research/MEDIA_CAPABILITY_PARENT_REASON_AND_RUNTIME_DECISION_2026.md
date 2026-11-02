# MA-MEDIA-ADR-001 — Conditional Media Research and Parent-Specific Unavailability Reasons

> **Document control:** P3 / 01-media-and-administrator-research · Proposed owner: Product + security/privacy (not assigned) · Registry: DEFERRED_RESEARCH_DESIGN; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Date:** 2026-10-26  
**Product:** Madalasa guardian app + Alarka child companion  
**Status:** OWNER-ACCEPTED ENGINEERING DIRECTION; NOT IMPLEMENTED; NOT DEVICE-VERIFIED; NOT LEGALLY/GOOGLE-PLAY APPROVED; COMMERCIAL MEDIA FEATURES OFF.

## 1. Owner decision and intended behavior

The owner explicitly accepts **technical limitations and OS-permitted execution contexts** for remote one-way audio listening, ambient audio recording, camera live viewing, front/rear photo snapshots, authorized video recording, flash-off capture, screen viewing, and scoped file browsing/transfer. **When a parent tries an unavailable operation, Madalasa must report the specific, verified reason and a safe next action**, not an uninformative "restricted" response or false success.

The Alarka main Activity normally opens at enrollment/login/permissions and later only when someone intentionally opens it to view settings or complete an Android-required interaction. The main Activity **need not stay on screen** for permitted background work. This is NOT a stealth design: Alarka keeps its recognizable icon, required persistent monitoring notification and Android microphone/camera indicators. MediaProjection screen share requires new system consent for each session and may need a child-device prompt; there is no ordinary setup-time permanent consent.

Research objectives are accepted; FR-009/010 remain P3 behind release-disabled flags and are **not added to the approved India launch scope**. No real-minor media collection unless India counsel and Google Play gates approve the precise feature/audience/use. A parental setup permission does not automatically establish either legality or an Android background-start exception.

## 2. Exactly what the Android conditions mean

| Feature | Conditions to test | Alarka Activity closed? | Critical caveat |
|---|---|---|---|
| Live one-way microphone listening | RECORD_AUDIO currently granted, mic/sensor usable, valid service-type declaration when needed, real guardian/session authorization, Android-permitted camera/microphone foreground-service start | Yes after a valid start | A new STANDARD background start is restricted; notification/widget interaction or other documented exception can qualify; device-owner DPC exemption is test-only until proven |
| Authorized ambient audio recording | All live-audio conditions + intentional recording controls, stop, finite duration, encrypted parent-side storage and deletion | Yes in active valid session | Local parent recording does not erase privacy law, third-party capture or endpoint risk |
| Live front/rear camera | CAMERA currently granted, camera FGS permissions/type when needed, free hardware/sensor toggle, permitted start context, active visible authorized session | Yes after valid start | Remote command/FCM alone does not guarantee starting a new camera session in ordinary background |
| Snapshot of front/rear camera | Valid camera capture session, camera access and storage/transfer destination | Yes during authorized active session | Flash may be switched off where hardware permits; mandatory shutter tone/Android privacy indicator cannot be universally suppressed |
| Authorized video recording | Valid running camera media pipeline, stream/session limits, encryption, actual capture/recording receipt | Yes for valid ongoing session | Completion means a real stream or confirmed file, not merely delivered command |
| Remote screen view | MediaProjection with **fresh device-user consent each session**; FGS/callback where required | Capturing stream may continue once approved | Cannot meet zero-further-interaction startup using ordinary MediaProjection; protected FLAG_SECURE screens stay blocked |
| Files and gallery | App-owned files and authorized shared MediaStore / Storage Access Framework selections or persistable URI grants | Yes within pre-authorized scope | Cannot browse another application's protected private files; grants may expire or be revoked |
| Hidden microphone/camera/suppressed Android indicators | Never implement | No | Android/Play protection and abuse prevention; no overlays, root, Accessibility or exploits to hide capture |

**STANDARD versus MANAGED_DEVICE_OWNER:** Genuine device-owner DPC is a special provisioning/enrollment role, not simply "Device Administrator" or a setup-time permission. Official Android docs include a device-owner exemption among while-in-use FGS background-start exceptions; its actual behavior must be confirmed on each OS/OEM/build. A high-priority FCM push may allow some background FGS starts but **does not independently grant camera/microphone while-in-use access**. Do not maintain indefinitely active recording services just to evade future start restrictions.

## 3. Parent-visible reason contract

Preserve existing command states CREATED, QUEUED, DELIVERED, ACCEPTED, DEVICE_OFFLINE, COMPLETED, FAILED, EXPIRED, UNSUPPORTED, PERMISSION_REQUIRED, OS_REJECTED, USER_ACTION_REQUIRED, CANCELLED. The draft OpenAPI Command already offers a nullable reason_code. The following are **proposed reason codes** for a future, versioned contract; they are not implemented today.

| Observed condition | Command state | reason_code | Madalasa explanation / next step |
|---|---|---|---|
| Commercial feature not released / policy gate open | UNSUPPORTED before sensitive dispatch | FEATURE_NOT_RELEASED | "Not available in this version"; do not suggest bypass |
| Parent lacks grant | Auth denied before dispatch | GUARDIAN_SCOPE_DENIED | "Your guardian access does not include this action"; refer to family owner without revealing other family's existence |
| Child app unreachable/unknown state | DEVICE_OFFLINE then EXPIRED | DEVICE_NOT_REACHABLE | "Alarka is offline/not responding; last seen [timestamp]"; do not invent permission fault |
| Microphone permission actually revoked | PERMISSION_REQUIRED | MICROPHONE_PERMISSION_MISSING | "Microphone access is off on the child's device; review Alarka permissions there" |
| Camera permission actually revoked | PERMISSION_REQUIRED | CAMERA_PERMISSION_MISSING | "Camera access is off on the child's device; review Alarka permissions there" |
| Unshared/revoked file or folder permission | PERMISSION_REQUIRED | MEDIA_SCOPE_NOT_GRANTED | "Select/approve this media or folder on the child's device" |
| Ordinary background mic/camera service blocked | OS_REJECTED | BACKGROUND_SENSOR_START_BLOCKED | "Android blocked starting a new session while Alarka was backgrounded"; show only permitted child-side action |
| Managed-only workflow on normal install | UNSUPPORTED | MANAGED_ENROLLMENT_REQUIRED | "This operation needs a properly enrolled managed child device" |
| Android notification or local interaction required | USER_ACTION_REQUIRED | CHILD_DEVICE_ACTION_REQUIRED | "Complete the Android action on the child's phone" |
| New Android screen-share consent missing | USER_ACTION_REQUIRED | SCREEN_SHARE_CONSENT_REQUIRED | "Approve this individual screen-sharing session on the child's device" |
| Microphone/camera blocked or busy (actual verified outcome) | OS_REJECTED/FAILED | SENSOR_UNAVAILABLE | "The requested sensor is unavailable; close competing camera apps or review system sensor settings" |
| Secure app screen hidden from capture | FAILED or degraded stream state | PROTECTED_SCREEN_CONTENT | "The other app protects this content from screen sharing"; no workaround |
| Weak network/TURN path interrupted | FAILED/degraded session | NETWORK_OR_RELAY_UNAVAILABLE | "Live media cannot connect right now; retry when connectivity improves" |
| Media storage full/unavailable | FAILED | LOCAL_STORAGE_UNAVAILABLE | "Recording could not be saved; check local storage" |
| Session stopped/revoked | FAILED/CANCELLED | SESSION_INTERRUPTED | "The session has stopped"; terminate transport and keys |
| Old capability report, no new device proof | QUEUED with pending/unknown capability | CAPABILITY_STATUS_STALE | "Checking device status; last confirmed [timestamp]" |

**UX invariants:** Parent sees requesting/queued, delivered, actual device accepted, active streaming (separate session substate), ended, or failed reason. A push receipt is not successful audio, image, video or screen capture. Verify guardian grant, feature flag, timestamp and enrollment **before dispatch**; Alarka rechecks OS permission/FGS startup eligibility immediately before capture. Do not claim success until a real media session establishes or snapshot/file is confirmed at its approved destination. Never diagnose "missing camera permission" from an offline phone. Give safe next action only; prevent a denied or revoked session from reconnecting on a new network.

For live streams, propose separate operational substates SESSION_ESTABLISHED, STREAMING, DEGRADED, STOPPED, with duration and parent stop control; do **not** quietly overload command COMPLETED as an indefinite active stream. Sensitive explanations only to authenticated, in-scope guardian. Push messages/logs carry opaque IDs and minimal codes, never media or secrets; parent-facing duplicate notices should be rate-limited.

## 4. Media data flow and costs (research candidate, not production selection)

Preferred investigation: Kotlin/Java owns Android permission/notification/FGS/Camera/MediaProjection; C++ NDK is optional for bounded codec/session helpers. Use established encrypted WebRTC P2P with authenticated signaling, ICE and optional TURN relay instead of an always-on custom C++ full-device VPN. **No media files on VPS**, bounded in-memory live jitter buffers, no unrequested delayed media uploads, optional encrypted parent-local recording with backup/retention/revocation controls. Relay/server metadata and device endpoints remain sensitive; verify end-to-end key identity and compromised-signaling-server attacks.

Existing OCI cost documents are **non-media models**; 500-child ₹1,680/month and 1,000-child ₹3,238/month are older hosting budget allocations, not validated Mumbai bills. Adding hypothetical ₹1,200/month relay capacity gives **₹2,880/month for 500 (~₹5.76/child/month)** and **₹4,438/month for 1,000 (~₹4.44/child/month)** ONLY if moderate traffic and the shared outbound allowance remains unexceeded. Those amounts exclude real peak-concurrency upgrades, actual egress, legal/security/support, tax, optional third parties and production HA. They are not approved live media prices.

## 5. Evidence required before promoting from research to any released capability

- **T-MEDIA-01** STANDARD setup Activity closed: denied background mic/camera start gives accurate reason, not success.
- **T-MEDIA-02** A supported on-device notification action starts a legitimate visible session; indicator/FGS notice verified.
- **T-MEDIA-03** Physically provisioned device-owner DPC Android 14–16: owner proof, exception, real sensor behavior and logs.
- **T-MEDIA-04** Ordinary Device Administrator cannot masquerade as MANAGED_DEVICE_OWNER.
- **T-MEDIA-05** Mic permission revoked and later restored: correct parent reason.
- **T-MEDIA-06** Camera permission, system sensor toggle, sensor-busy cases: measured reason accuracy.
- **T-MEDIA-07** Front/rear snapshot, flash OFF and device-dependent shutter behavior; Android indicator remains.
- **T-MEDIA-08** Authorized ongoing audio/video stream with main Activity closed; explicit stop and time limits.
- **T-MEDIA-09** MediaProjection on Android 14+: no reused capture-consent token, prompt required per session.
- **T-MEDIA-10** MediaProjection cancel/device lock/FLAG_SECURE: no bypass, truthful status.
- **T-MEDIA-11** MediaStore/SAF only: grant lost, folder revoked, other-app-private content denied.
- **T-MEDIA-12** Offline device, force-stop, no response and timeout: UNKNOWN/OFFLINE rather than false permission diagnosis.
- **T-MEDIA-13** Stolen/revoked guardian, wrong-family access and command replay: zero cross-family media.
- **T-MEDIA-14** Wi-Fi/mobile handoff, low bandwidth, NAT, TURN fallback: bounded buffers and actual egress/CPU cost.
- **T-MEDIA-15** Optional encrypted parent-local recording, loss/backup/deletion, zero VPS media files.
- **T-MEDIA-16** Child disclosure, distinctive Alarka icon, persistent notification and system indicators on OEM fleet.
- **T-MEDIA-17** Signaling compromise, key substitution and TURN abuse resistance.
- **T-MEDIA-18** India minor-data legal authority, actual Google Play audience/monitoring classification, package declarations and explicit release approval.

**Evidence now:** NOT_IMPLEMENTED / NOT_TESTED. Require current physical device matrix, tests, security audit, Indian child privacy counsel memo, child-safe disclosure and real Play approval for any eventual commercial release. Media remains outside canonical M0–M9 launch milestones and disabled in commercial builds. Do not modify M1-only OpenAPI to imply media launch.

## 6. References

- Android foreground-service restrictions and exceptions: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- Android FGS camera/microphone types: https://developer.android.com/develop/background-work/services/fgs/service-types
- Android 14 MediaProjection consent: https://developer.android.com/about/versions/14/behavior-changes-14
- Android MediaProjection guide: https://developer.android.com/media/grow/media-projection
- Android shared media access: https://developer.android.com/training/data-storage/shared/media
- Google Play monitoring policy: https://support.google.com/googleplay/android-developer/answer/9888380
- Internal: SRS.md, TECHNICAL_SPECIFICATION.md, COMMAND_SOS_USAGE_QUEUE_CONTRACT.md, ANDROID_COMPATIBILITY_MATRIX.md, INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md.

## 2026-10-27 integration with owner-accepted automatic permission scanner

Media R&D preflight now receives a **device-authenticated, versioned capability profile** from first-run Alarka discovery and later Android permission rechecks; server stores a last-confirmed snapshot for Madalasa through child-scoped GET. Never interpret `CAMERA/RECORD_AUDIO=GRANTED` as actual legal release enablement or universal background start; accurate UI is "Permission granted; microphone/camera may be conditional/not released" rather than a green "Live monitoring active". Permission revocation and regrant are detected at the next OS-permitted child execution, not instantly while force-stopped/offline. Screen-sharing `PER_SESSION` consent cannot be pregranted in setup. No private app files are exposed through a generic "media access" grant.

State separation, API report version, parent UX colors and T-CAP-01…24: [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md). Both ADRs keep OS indicators, guardian child scopes, India legal/Google Play gate, not-implemented status, and no-VPS-media-file proposal unchanged. [Figma onboarding and parent compatibility board](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-2).

## 2026-10-27 metadata-only media activity evidence and read-audit handoff

The owner also accepted a **metadata-only** media-activity log at VPS (not stored media files): guardian/child IDs, AUDIO/IMAGE/VIDEO_AV/SCREEN_SHARE, requested/viewed/saved/failed, actual session start/end/duration, nullable saved-file size and separately network bytes, plus verified reason_code (Android CAMERA_IN_USE or MAX_CAMERAS_IN_USE, observed silenced microphone, actual permission/background start, offline or relay error). 'Mic already used' or 'child on a call' must NOT be asserted from an unverified silent input; stamp evidence source/confidence. Live viewing has NULL file_size_bytes; SAVED_PARENT_LOCAL is only a historical parent device acknowledgement, not server-held media. Events tie to existing Command.status and stop on revoke. Child/media release remains research P3/OFF.

Parents get children-only filtered/paginated media history; named-child administrator reads require scoped MFA case/purpose, separate audited lookup and bounded name/ID suggestions, not blanket operator/root access. No parent/admin can download VPS media, as VPS stores none. Canonical lifecycle/DDL/API/tests: [Media Activity Audit ADR](MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md); admin role/UI: [Administrator Console Specification](ADMIN_PANEL_SPECIFICATION_2026.md). [Figma media-audit parent & admin designs](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-2). T-AUD-01–22, T-ADM-01–14 all NOT_IMPLEMENTED/NOT_TESTED.


## 2026-10-31 owner-approved P2P transport method — implementation and release remain blocked

The owner selects **WebRTC ICE/STUN direct peer connections with TURN fallback**, authenticated Drogon signaling and bounded PostgreSQL metadata rather than a custom full-device VPN. Android Kotlin APIs still own microphone/camera/MediaProjection, permissions, visible notifications/indicators and Stop. An optional WebRTC DataChannel may handle *time-limited live* GPS visualization, while durable GPS queue/inbox/PostGIS/history is unchanged. No new server process or stack of QUIC/libp2p/WireGuard fallbacks is assumed; cost depends on measured TURN relay usage, not a fixed savings percentage.

**Binding detailed design and planned T-P2P-01…12 acceptance tests:** [MA-P2P-ADR-004](P2P_MEDIA_AND_LIVE_LOCATION_TRANSPORT_ARCHITECTURE_2026-10-31.md). This is a **documented transport choice only**. Separate Android compatibility, qualified India counsel and Google Play assessment all remain OPEN; public builds keep unapproved media capture and unnecessary permissions out, and production media flags OFF. Nothing authorizes hidden/background capture or fresh screen projection without per-session approval.
