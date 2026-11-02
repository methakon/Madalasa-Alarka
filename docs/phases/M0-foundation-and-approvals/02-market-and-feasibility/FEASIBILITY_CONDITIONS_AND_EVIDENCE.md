# Feature Feasibility Conditions

> **Document control:** M0 / 02-market-and-feasibility · Proposed owner: Product + finance (not assigned) · Registry: TEMPLATE_OR_EVIDENCE_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product naming:** **Madalasa** parent/guardian app, **Alarka** child companion; GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka). [Brand and Markandeya Purana context](BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Project:** Madalasa–Alarka  
**Date:** 2026-10-25  
**Status:** Documentation review; no device tests completed

## Assessment definitions

- **Feasible:** supported through a public Android API with normal grants.
- **Conditional:** supported only with a qualifying device setup and verified Android behavior.
- **Partial:** a limited version can be implemented; full functionality is not promised.
- **Unsupported:** cannot be guaranteed through public Android APIs.

| Feature | Status | Why and conditions |
|---|---|---|
| No child login | Feasible | Short-lived pairing code and per-device credentials |
| Location and speed | Conditional | Location grants, OS background rules, accurate satellite/network fix; speed may be unavailable |
| Route history | Feasible | Store timestamped positions; show coverage gaps |
| App usage summaries | Conditional | Usage Access granted; server builds daily to yearly aggregates |
| Scheduled app suspension | Conditional | Supported managed-device policy controller using DevicePolicyManager; some packages cannot be suspended |
| Immediate termination of another app | Partial | Suspension restricts eligible packages; universal force-stop is not a public ordinary-app capability |
| File listing | Partial | App-controlled files and user-authorized collections, not other apps' private data |
| Camera/photo/video | Restricted/conditional | Permission alone does not guarantee background capture; compliant, disclosed workflows are required |
| Microphone/audio | Restricted/conditional | Permission alone does not guarantee background recording; compliant, disclosed workflows are required |
| App without open screen | Feasible | Android background components; platform notifications/indicators still apply |
| Hidden monitoring | Unsupported for a Play release | Monitoring must not be disguised; persistent notification and identifiable icon when running |
| Drive upload | Feasible | Parent OAuth authorization and resumable upload |
| Subscriptions | Feasible | Play Billing and verified backend entitlements |
| Low resource use | Test target | Adaptive collection and benchmarking |

## Decision gates

1. Confirm public Android API support and documented permissions.
2. Verify on the intended Android API levels and handset models.
3. Verify Google Play distribution requirements separately.
4. Record status as NOT_TESTED, PASS, PASS_WITH_CONDITIONS, or FAIL.

## Key technical distinctions

**Standard installation:** parents can grant location and Usage Access, but these grants do not make the app a device owner.

**Managed installation:** supported device-owner provisioning can authorize stronger package restrictions. Managed enrollment is a distinct provisioning operation, often requiring setup of a new or reset phone; it is not a permission toggle.

**Media:** camera and microphone requests need platform-compliant user authorization, visible system indicators and lifecycle permissions. Android documents specific exceptions to foreground-service starting rules, but they do not guarantee unrestricted background recording or Google Play acceptance. The product should return clear unsupported/permission-required/user-action-required outcomes rather than claiming success.

## References

- [Android foreground services](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
- [Android device policy](https://developer.android.com/reference/android/app/admin/DevicePolicyManager)
- [Android managed-device provisioning](https://developer.android.com/work/dpc/dedicated-devices)
- [Google Play monitoring policy](https://support.google.com/googleplay/android-developer/answer/9888380)
- [Play location declaration](https://support.google.com/googleplay/android-developer/answer/9799150)

## Detailed conditional engineering decisions

The following paragraphs separate **why technically possible**, **why limited**, **conditions to ship**, and **fallback behavior**. These are design decisions, not device test passes.

### A. Background GPS tracking, route history and speed

- **Why feasible:** Android provides location APIs, optional speed and accuracy estimates, user-granted background location and foreground-service mechanisms.
- **Why conditional:** The runtime might receive approximate permission only, GPS can be unavailable, network can fail, location permission can be revoked and background services are restricted by OS and OEM power policies. Starting a location service from a background state is also subject to version/context rules.
- **Conditions:** A clear location disclosure before requesting permission; correct permission sequence and FGS declarations; observable monitoring identity; local encrypted queue; consent/retention settings; OS tests for device screen-off, reboot and battery saver.
- **Fallback:** Show last observed position, age and uncertainty; queue offline records; never label stale data live.
- **Acceptance:** At least one representative test phone records real timestamped fixes while the child setup Activity is closed, and the parent map shows truthful missing data.

### B. App usage reports

- **Why feasible:** `UsageStatsManager` exposes certain package usage summaries/events to a user-authorized application.
- **Why conditional:** Usage Access is a separate Settings grant and can be revoked; historical OS records are limited and may vary by version. Yearly history is not guaranteed to exist on a newly installed app.
- **Conditions:** Guide permission access; record intervals and timezones; securely aggregate observations daily into long-term histories; show periods with missing coverage.
- **Fallback:** Mark a report unavailable or incomplete, rather than inventing missing durations.
- **Acceptance:** Record a controlled test app's usage and reproduce daily/weekly/monthly/yearly totals from stored events.

### C. Remote app blocking and schedules

- **Why feasible:** Properly authorized Android device-policy controllers can suspend eligible packages using `DevicePolicyManager`. A locally scheduled policy can remain effective without constant connection.
- **Why conditional:** Ordinary app installation plus all runtime permissions is **not** equivalent to device-owner enrollment. Some packages are protected/unsuspendable. The API restricts application access, but is not a guaranteed generic force-stop mechanism.
- **Conditions:** Separate managed-mode enrollment with complete parent notice; programmatic verification of device-policy role and suspend eligibility; server-authorized versioned policy, local scheduler, safe critical-package exclusions, rollback, and audit.
- **Fallback:** In standard mode show “not enforceable on this device” and offer usage insights or non-coercive limits. If policy fails, return affected package names and specific failure state.
- **Acceptance:** A properly provisioned test phone blocks and restores an eligible test application, including after reboot and schedule expiry, and never attempts to suspend critical system packages.

### D. File access

- **Why partially feasible:** App-private content belonging to Madalasa–Alarka and files/documents selected through Android-approved system interfaces can be accessed.
- **Why limited:** Scoped storage isolates other applications and protected directories. A user's intent to grant access does not itself defeat the OS sandbox.
- **Conditions:** Use Storage Access Framework/MediaStore according to the resource type; persist only permitted URI grants; handle revocation; limit listing to explicit allowed roots and minimize uploads.
- **Fallback:** Explain “access not granted” or “protected by Android”.
- **Acceptance:** List authorized files and deny traversal into another application's private directory.

### E. Remote photo or video requests

- **Why conditionally possible:** Android supports camera capture in eligible app contexts and provides camera service APIs. Certain special management contexts have documented exceptions to some foreground-service background-start restrictions, but a parent pressing a remote button does not automatically create an eligible context.
- **Why restricted:** Granting CAMERA does not mean a background application can arbitrarily start capture. Android's while-in-use checks, foreground-service type and lifecycle rules, privacy indicators, OEM hardware state and Play monitoring policies still apply.
- **Conditions:** Disclosed, properly authorized and user-visible capture workflow; camera permission at execution; correctly declared service type if used; suitable platform context; device-specific tests; publication policy review. Do not conceal indicators, spoof a foreground UI, or retain an undisclosed capture session.
- **Fallback:** Return `USER_ACTION_REQUIRED`, `PERMISSION_REQUIRED`, `OS_REJECTED` or `UNSUPPORTED`; keep the feature hidden/disabled for configurations without approved support.
- **Acceptance:** A permitted, transparently visible workflow returns verified media only after an actual successful capture, and never records when Android denies access.

### F. Remote audio requests

- **Why conditionally possible:** Android provides recording APIs in properly authorized and permitted application contexts.
- **Why restricted:** RECORD_AUDIO is not blanket authorization to begin a new recording from any background state; microphone FGS restrictions, user privacy indicators and policy obligations remain.
- **Conditions:** Prominent disclosure, genuine authorization and system indicators, service/lifecycle requirements, repeat permission check, and certification on the supported Android/OEM matrix. Do not design covert listening.
- **Fallback:** Report that an on-device authorized recording interaction is required or that the current platform cannot perform the request.
- **Acceptance:** The action operates only under documented permitted conditions and records audit/notification evidence; rejection and interruption are handled safely.

### G. Minimal child UI vs completely invisible operation

- **Why part is feasible:** Onboarding can close and background location, usage, sync and policy components can operate without a persistent Activity window.
- **Why invisibility is not:** Foreground-service notifications and camera/microphone indicators are controlled by Android; Play monitoring rules require an identifiable icon, transparent marketing and persistent notification while monitoring runs.
- **Conditions:** Persistent recognizable identity, status/settings/revocation path, accurate parent/child disclosures and proper service type.
- **Fallback:** No invisible/stealth mode in the product.
- **Acceptance:** Tester can identify the app and its monitoring notification, even when the setup Activity is closed.

### H. Parent Google Drive upload

- **Why feasible:** Google Drive API supports parent-authorized OAuth and reliable upload protocols.
- **Why conditional:** Network loss, token revoke/expiry, quota and Drive organization rules affect behavior. Upload only approved media.
- **Conditions:** Separate OAuth consent, protected refresh tokens or app-owned credential storage, minimum scopes, upload checksum and explicit deletion responsibility.
- **Fallback:** Queue retryable uploads with clear error state. Never falsely report a file exists in Drive.
- **Acceptance:** Upload, interrupted resume, token revoke, and copy deletion/control tests pass.

### I. Billing and resource efficiency

- **Why feasible:** Google Play Billing provides subscription purchase state, and a lightweight C++ backend can process requests efficiently. Event-driven Android patterns can reduce unnecessary wakeups.
- **Why conditional:** Compliance, purchase validation, operational load and battery drain cannot be guaranteed merely by choosing C++. Location radio usage can dominate battery.
- **Conditions:** Play-compliant billing, server-side purchase verification, cancellation and grace cases, bounded queues, performance baselines on target devices.
- **Fallback:** Show entitlement expiry and degraded data freshness; provide transparent power usage settings.
- **Acceptance:** Payment state transitions and repeatable CPU/memory/battery measurements are recorded and signed off.

## Implementation priority and unresolved checks

**Safe MVP:** device pairing + background location + history + usage reports + security + subscriptions. **Conditional expansion:** managed-device package restrictions after supervised provisioning and device tests. **Research only:** camera/audio capabilities until an actually supported, transparently authorized, policy-compliant workflow is proven. Do not delay the entire MVP on media research.

Each completed compatibility test should be stored using the evidence template in [Android Compatibility Matrix](../../M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md). Publication requirements and permission declarations are captured in [Google Play Publishing Requirements](../../M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md).

## 2026-10-26 owner acceptance: conditional media engineering plus reason-specific UX

Interpret "Camera/photo/video RESTRICTED" and "Microphone/audio RESTRICTED" as **conditional platform feasibility and authorized engineering research**, not technical impossibility. Accepted candidates include live listening, parent-local encrypted audio recording, live camera, front/rear photo snapshot, permitted video recording and flash-off where actual hardware supports it. Alarka main Activity normally remains closed after initial setup; required Android sensor indicators and monitoring notification remain. Initial permission grants are not indefinite rights to start fresh STANDARD-mode camera/mic services from background; a genuine device-owner exception or supported child-device interaction must be validated on physical devices. Android MediaProjection requires new system consent each session. App-owned or approved MediaStore/SAF file scopes may be listed/transferred, but not another app's private files.

Madalasa SHALL display the **true execution reason and next lawful step** when requested features are unavailable: permission missing, Android blocked background service, child action/consent required, actual managed enrollment required, no current device response, sensor busy, network failure and expired session. Do not misstate completed on remote delivery or infer permission from an offline child. See [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md). All commercial and child-data legal/Play/Android test gates remain BLOCKED until their own evidence.

## 2026-10-27 automatic Alarka device compatibility and grant synchronization

**Technically feasible with standard public Android APIs** to read a limited hardware/OS inventory, offer step-by-step disclosures/approved system dialogs or special-access Settings, recheck actual grants, upload a signed capability report after device pairing and provide an authenticated Madalasa compatibility list. This does **not** authorize opening cameras/mics silently or guarantee background sensors or instant permission-revocation notifications. Verified hardware `SUPPORTED`, Android `GRANTED/PARTIAL/TEMPORARY`, Android runtime eligibility, release flags and report freshness are separate dimensions. For each permission change, Alarka detects it on its next eligible execution and server returns durable receipt; parent's dashboard must show STALE/UNKNOWN when no fresh device observation exists.

Specific feasibility gates: Android 11+ foreground location then separate background-location step; Usage Access via Settings; POST_NOTIFICATIONS where required; selected-photos, shared-media and SAF permission scope; MediaProjection fresh per-session consent; truly provisioned device-owner vs ordinary admin; while-in-use camera/mic FGS context. No P3 media app manifest functionality before release gates. [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) contains technical APIs, user interaction, tests T-CAP-01…24 and Figma designs. **No hardware tests performed.**

## 2026-10-27 owner-accepted capture/upload separation, 48h offline storage and Postgres inbox+bulk

[MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) documents a conditionally feasible Android/Kotlin + C++/Drogon/PostGIS pipeline: eligible GPS fix → encrypted local SQLite queue targeting up-to-48h offline data → bounded JSON upload every 1–2min where a legitimately running service/network allows → Postgres durable **one-row-per-batch inbox TX COMMIT** → HTTP 202 QUEUED → independent C++ lease + bulk insert TX → event-time trip/stop reconstruction. The child main Activity remains closed after setup; lawful sensor capture/notification and background FGS startup conditions must be independently tested. WorkManager 1–2min periodic upload is NOT supported (minimum periodic 15min). Redis not necessary for MVP; inbox has higher write amplification than direct bulk; run both load profiles and crash injections. No capacity, battery, 48h GNSS continuous track or pricing claim verified. Evidence T-ING-01…24 all NOT_TESTED, India child-data/Play policy clearance OPEN.
