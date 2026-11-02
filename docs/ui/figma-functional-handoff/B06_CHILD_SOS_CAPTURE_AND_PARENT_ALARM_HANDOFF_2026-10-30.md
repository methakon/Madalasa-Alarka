# B-06 Child-Initiated SOS, Evidence Capture and Parent Alarm — UX / Engineering Handoff

**Date:** 2026-10-30  
**Status:** PROPOSED DESIGN; owner-requested direction recorded; legal, Play and device validation are release blockers  
**Scope:** Madalasa parent app + Alarka child app; standard Android installation only  
**AI dependency:** None. SOS transport, sensor/event handling, capture orchestration and UI state are deterministic application code. No generative-AI or paid inference service is proposed.

> This is a screen-by-screen handoff specification for Figma and implementation. It is not an editable Figma file, a legal opinion, an Android capability certification, or evidence that the feature is implemented. The current workspace has no connected Figma editing capability.

## 1. Decision boundary and recommended first-release shape

The child must deliberately open Alarka and press the clearly labelled SOS control. The SOS event is sent independently of media capture. If the user has previously granted the relevant runtime permissions and the OS permits access while Alarka is visibly foregrounded, the app may offer a short, clearly indicated, user-initiated evidence-capture sequence.

**Recommended safe capture scope:**
- Attempt at most one front-facing still and one rear-facing still, sequentially, where those camera directions exist and are available. Do not promise every physical lens or simultaneous use of all cameras; Android camera hardware/concurrency support differs by device.
- Record one short audio clip (proposed maximum 10 seconds) only after an explicit, visible recording step in the foreground. Show a recording indicator and a Stop control. No continuous listening and no hidden/background capture.
- Capture is best-effort and optional. SOS delivery must never wait for, or fail because of, camera/microphone permission, hardware, OS, storage, network or upload failure.
- If a permission is missing, show the system permission request in context. If denied, do not repeatedly nag; send SOS without media and report the reason.
- Keep the Alarka Activity visibly open during camera/microphone use. Do not remotely wake the camera or microphone from a closed/background Activity. No silent remote activation.
- Use the Android privacy indicators and a persistent, identifiable Alarka monitoring notification where required. Do not suppress, cover, fake or bypass OS indicators.
- Never capture financial-app screens, protected content, another app's private data, or use Accessibility / Device Owner / permission bypass to obtain media.
- Do not upload a pre-event rolling audio buffer or pre-SOS camera frames. The evidence starts only after the child presses SOS and the capture UI is visible.

**Unresolved legal gate:** Child images, voice and emergency context are highly sensitive personal data. India DPDP Act section 9 (including child-data and tracking/behavioural-monitoring provisions) is scheduled to commence 18 months after 13-Nov-2025 (13-May-2027). The final rules' relevant provisions also have staged commencement. The statutory exemptions are purpose/class-specific; do not assume a consumer parental-control publisher automatically qualifies. Obtain qualified Indian counsel's written view on the product's broader child-monitoring model, the SOS media purpose, verifiable parental consent, child-facing notice/assent, retention, access, deletion and cross-border processing before enabling collection or launch. This document does not conclude the feature is lawful.

## 2. End-to-end interaction

1. Child opens Alarka and taps **SOS — I need help**.
2. Alarka immediately creates and sends an authenticated SOS event. It does not wait for capture.
3. Child sees a clear emergency state and may cancel an accidental SOS. Cancellation is a separate auditable event; it does not erase the original event.
4. If camera/audio permissions and foreground execution are available, show a capture explanation and start only the permitted visible capture flow.
5. Capture front/rear stills sequentially where supported, then offer/start the bounded audio clip only while the capture UI remains visible. The child can stop or skip capture.
6. Upload media as separately scoped, encrypted attachments linked to the SOS event. The backend records per-asset status and never reports an absent or rejected capture as successful.
7. Parent receives a dedicated urgent SOS notification. Parent alarm must be caused only by a valid child-originated manual SOS event, not routine check-ins, sensor suspicion, media upload, or ordinary notifications.
8. Parent can acknowledge the SOS, open the event, view available media and see precise unavailable/denied/pending states. No media must not hide the SOS itself.

## 3. Screen handoff — Alarka child app

### ALK-SOS-01 — Child safety home / SOS entry
- Header: Alarka identity and clear safety status.
- Primary, high-contrast control: **SOS — I need help**.
- Secondary action: **I'm safe / Check in** (routine, quiet notification).
- Supporting copy: "SOS sends an urgent alert to your linked guardian. Optional photos/audio are captured only after you press SOS, while Alarka is visibly open, and only if Android permits."
- Do not use deceptive system UI or make SOS indistinguishable from other buttons.
- Accessibility: large touch target, screen-reader label, high contrast, localized strings.

### ALK-SOS-02 — SOS confirmation
- Title: **Send an SOS to your guardian?**
- Copy: "Your guardian will receive an urgent alert. You can send the alert even if camera or microphone access is unavailable."
- Actions: **Send SOS** (primary), **Go back** (secondary).
- Avoid a confirmation delay that makes the emergency flow unusable. Consider press-and-hold only if usability testing proves it accessible.

### ALK-SOS-03 — SOS sent / evidence options
- Status: **SOS sent** or **Sending SOS…** based on actual server receipt.
- Clear note: "Keep Alarka open if you want to share optional evidence."
- Actions: **Take photos (if available)**, **Record short audio**, **Skip evidence**, **Cancel SOS**.
- If automatic immediate capture after the explicit SOS is retained, the screen must still visibly disclose the active camera/microphone and offer a stop/skip control. Prefer a child-visible start step for each media type.
- Camera UI: show which camera is active (Front / Rear), preview while active, capture button, switch/skip controls. Capture directions sequentially, not a promise to use every lens.
- Audio UI: visible recording timer, waveform/recording state, Stop button, maximum duration, and no hidden recording.

### ALK-SOS-04 — Capture unavailable / partial success
Use reason-specific states: CAMERA_PERMISSION_DENIED, MICROPHONE_PERMISSION_DENIED, CAMERA_UNAVAILABLE, CAMERA_CONCURRENCY_UNSUPPORTED, MICROPHONE_UNAVAILABLE, OS_BACKGROUND_OR_LIFECYCLE_REJECTED, STORAGE_UNAVAILABLE, NETWORK_PENDING, UPLOAD_FAILED, USER_SKIPPED.
- Copy examples: "SOS was sent. Photos weren't available on this phone." / "SOS was sent. Audio could not be recorded."
- Never imply the SOS failed because optional media failed.
- Offer system Settings navigation only where useful; do not loop permission prompts.

### ALK-SOS-05 — SOS delivery / retry status
- Distinguish local queued, server received, guardian push accepted, guardian acknowledged and expired/failed.
- Offline: "SOS is queued on this phone; it has not yet reached your guardian." Use bounded retry and expiry. Do not claim delivery.
- Repeated taps use an idempotency key and do not create unbounded duplicate incidents.
- Cancellation and resolution are separate state transitions with audit history.

## 4. Screen handoff — Madalasa parent app

### MAD-SOS-01 — SOS alert settings (parent device)
- Section title: **Emergency SOS alerts**.
- Explanation: "Only a manual SOS sent from a linked Alarka device uses this urgent alert. Routine check-ins and other notifications stay quiet."
- In-app preference: **Enable sound for SOS**; **Enable vibration for SOS**.
- Setup status rows: Android notifications permission; SOS channel sound; SOS channel vibration; current channel importance; device Do Not Disturb / silent-mode caveat (report only; do not request policy access by default).
- Primary action: **Enable SOS alerts**. Then request POST_NOTIFICATIONS on Android 13+ with contextual rationale and create a dedicated high-importance SOS notification channel with sound and vibration enabled by default.
- Secondary action: **Test SOS alert**. This is a clearly labelled local test, not a fake child SOS and must not be recorded as a real SOS incident.
- Link: **Open Android SOS notification settings**. Android owns the final channel settings. Once created, channel sound/vibration behavior cannot be silently changed by the app; user/system settings remain authoritative.
- Do not request Notification Policy Access / DND override in v1. Never promise sound when device volume is zero, DND/silent mode suppresses it, notification permission/channel is disabled, or OEM policy blocks it.

### MAD-SOS-02 — Incoming SOS event
- Dedicated SOS channel only. Ordinary app notifications use separate quiet channels.
- Show child/family identity, event time, current delivery state and optional location freshness if separately authorized.
- Alarm sound and vibration are tied only to a validated manual SOS event. Deduplicate by event ID; repeated push delivery must not restart the alarm indefinitely.
- Actions: **Open SOS**, **Acknowledge**, **Stop sound**. Acknowledgement and silencing are recorded separately.
- Do not auto-call emergency services or send SMS.

### MAD-SOS-03 — SOS detail and media evidence
- Timeline: child pressed SOS; server receipt; media capture attempts/results; push delivery; guardian acknowledgement.
- Media tiles show Front still / Rear still / Audio clip, timestamp and upload state.
- Explicitly label unavailable, denied, skipped, unsupported, pending and failed media. No placeholder that looks like a successful photo/audio recording.
- Access restricted to authorized guardian(s) for that child; audit view/download; retention and deletion follow approved policy. Do not expose family-wide media by default.

## 5. Parent-device notification and alarm contract

- Create a dedicated channel such as `madalasa_emergency_sos`; never put routine notifications on it.
- Android 8+ notification channels govern sound/vibration. Android 13+ requires runtime POST_NOTIFICATIONS permission for ordinary notification delivery.
- Channel initial configuration: high importance, custom app-owned alert sound, vibration pattern enabled. The parent can change or disable these in Android Settings; the app can inspect channel state and link to settings but cannot override a user's choice after channel creation.
- No exact-alarm permission, full-screen intent, DND bypass, audio-focus abuse or notification-policy access is required for the recommended v1.
- If notification permission/channel is disabled, show a persistent in-app setup warning while the parent app is open; do not claim the parent will hear an SOS.
- Sound/vibration may be suppressed by DND, silent mode, volume, OS/OEM policy, battery/network delay or force-stop. Show this limitation during setup.
- The alert is a notification, not a guaranteed siren. The app may offer an in-app audible alert while the parent app is foregrounded, subject to user settings and device audio state; do not promise to force sound from background.

## 6. Android feasibility and non-negotiable boundaries

- Android 12+ generally restricts foreground-service starts from background. Android 14+ enforces while-in-use eligibility for camera/microphone FGS creation; a background app cannot assume a prior CAMERA/RECORD_AUDIO grant authorizes a new background capture session.
- Child pressing SOS inside a visible Alarka Activity provides a user-initiated foreground context. Keep capture within that visible session and handle interruptions/revocation/OS rejection explicitly.
- CAMERA and RECORD_AUDIO runtime grants are distinct from hardware availability and execution eligibility. Permission already granted does not mean every camera lens can be opened or all cameras can run concurrently.
- Device-specific camera IDs, logical multi-camera mapping, concurrent camera sets, microphone routing and OEM behavior must be discovered and tested. First-release target should be one front + one rear still sequentially, not "all cameras".
- The app must not start camera/mic recording from a remote push while Alarka is closed, use a background service to evade restrictions, hide recording, or record before the SOS action.
- No financial-app screen capture, no bypass of FLAG_SECURE or OS indicators, no hidden camera/mic, no continuous ambient audio, no stealth recording.
- Parent alarm is best-effort notification behavior, never a guaranteed override of Android user/system settings.

## 7. Data minimization and security contract

- SOS event and each media object have independent IDs, authorization, idempotency and state.
- Encrypt in transit and at rest; short-lived upload authorization; no public media URLs; guardian access checks at every read; revoke access immediately when guardian link is revoked.
- Suggested initial retention for raw SOS media: **not approved**. Do not invent or implement a retention period until B-07 and counsel approve category-specific retention, deletion, backup expiry and incident/legal-hold rules.
- No media in analytics, crash logs, push payloads, URLs, or general-purpose debug logs. Push payload contains opaque event ID and minimal alert text.
- Record consent/disclosure version, child-initiated SOS timestamp, permission state, camera direction, capture status, audio duration, upload receipt, guardian access and deletion evidence. Avoid collecting unrelated location or sensor data as a prerequisite.
- Media is not automatically shared with every guardian; use explicit child-specific authorization and least privilege.
- Provide deletion/export/grievance paths and breach response; no indefinite retention.

## 8. India law and Google Play release gate

**Not a legal clearance.** The DPDP Act was notified with staged commencement. The 13-Nov-2025 commencement notification schedules sections 3–5, 6(1)–(8), 7–10 and other listed provisions for 18 months after publication (13-May-2027). Section 9 addresses verifiable parental consent, detrimental effects and tracking/behavioural monitoring of children, subject to prescribed class/purpose exemptions. The final DPDP Rules, 2025 also have staged commencement; rules 3 and 5–16 are scheduled for the same 18-month point. The explanatory note describes specific classes/purposes such as educational institutions and childcare providers; it is not a blanket consumer parental-control exemption. Counsel must assess the full service, not just the SOS button.
- Parent consent alone must not be assumed to settle every child privacy, recording, third-party bystander, school/exam, or future DPDP issue.
- Google Play monitoring-app requirements include clear monitoring purpose, no stealth/cloaking, persistent notification and unique app identity, listing disclosure and the applicable monitoring-tool designation. SOS media functionality needs prominent disclosure and an accurate Data Safety / permission declaration; Play approval is not guaranteed.
- Before release: written India counsel opinion; DPIA update; lawful purpose and necessity; verifiable guardian authority/consent design; age-appropriate child notice/assent; bystander privacy; purpose/retention/deletion; processor/hosting/cross-border review; Google Play policy review and reviewer-ready demonstration.

## 9. Required acceptance tests — all NOT TESTED

| ID | Test | Expected result |
|---|---|---|
| B06-01 | Child manually presses SOS with network | Server records one SOS; parent receives dedicated alert |
| B06-02 | Camera/mic permissions denied | SOS still sends; media marked unavailable with exact reason |
| B06-03 | Front/rear camera hardware variants | Sequential supported capture only; unsupported lens/concurrency reported |
| B06-04 | Android 12–16 background/foreground/lifecycle interruption | No background-start bypass; capture only in visible eligible session |
| B06-05 | Mic capture interruption, permission revoke, OS privacy toggle | Recording stops/fails explicitly; no false success |
| B06-06 | Network loss before/after SOS receipt | Queued vs server-received status accurate; bounded retry/idempotency |
| B06-07 | Parent notification permission denied/channel muted | Setup shows not-ready; no false audible-delivery claim |
| B06-08 | Parent ordinary notification and routine check-in | No SOS sound/vibration |
| B06-09 | Duplicate FCM delivery / replayed SOS | One incident; no repeated alarm loop |
| B06-10 | Parent acknowledges/stops alarm | Alarm stops; audit event recorded |
| B06-11 | Guardian revoked / wrong family / expired media token | Access denied immediately |
| B06-12 | Retention expiry/deletion/backup restore | No media reappears after approved deletion |
| B06-13 | Financial app, FLAG_SECURE, permission indicator | No protected screen capture or bypass |
| B06-14 | DND/silent/zero volume/OEM restriction | Accurate best-effort limitation; no override attempt |

No Android APK, Figma file, device test, backend handler, legal opinion or Google Play approval is produced by this handoff.

## 10. Official references reviewed 2026-10-30

- Android background FGS start and while-in-use restrictions: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- Android 14 foreground-service types: https://developer.android.com/about/versions/14/changes/fgs-types-required
- Android notification channels and user control: https://developer.android.com/develop/ui/compose/notifications/channels
- Android 13 notification runtime permission: https://developer.android.com/develop/ui/compose/notifications/notification-permission
- Google Play monitoring-app policy: https://support.google.com/googleplay/android-developer/answer/9888380
- DPDP Act 2023: https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023.pdf
- DPDP Act commencement notification 13-Nov-2025: https://www.meity.gov.in/static/uploads/2025/11/c56ceae6c383460ca69577428d36828b.pdf
- DPDP Rules 2025: https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf
- MeitY explanatory note: https://www.meity.gov.in/writereaddata/files/Explanatory-Note-DPDP-Rules-2025.pdf
