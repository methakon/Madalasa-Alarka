# Project Discussion and Decisions

> **Document control:** M0 / 01-project-governance · Proposed owner: Project owner (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product:** **Madalasa** (parent app) + **Alarka** (child app); the GitHub repository is now **[Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka)**. [English mythological inspiration](../02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

- **Project:** Madalasa–Alarka
- **Document version:** 0.1
- **Date:** 2026-10-25
- **Status:** Initial baseline

## 1. Product concept

The product is a subscription-based parental monitoring and device-management system with three main parts:

1. A child-side Android app, configured by the parent on the child's device.
2. A parent-side app/dashboard for location, routes, usage reports, and supported controls.
3. A lightweight C++ backend that stores telemetry, handles paired-device commands, validates subscription entitlements, and coordinates optional media backup.

The child app should not need its main screen to remain open for all supported background features. Android may still impose foreground-service, notification, permission, privacy-indicator, lifecycle, and device-management requirements.

## 2. Requirements discussed

- Parent performs initial setup and grants applicable permissions on the child's phone.
- No separate child login is required in the initial design; securely pair the device to a parent account.
- Show the latest reported location on Google Maps, route history, and speed when available.
- Provide app-usage summaries by day, week, month, and year after Usage Access is granted.
- Support remote commands and scheduled restrictions where Android APIs permit them.
- App restrictions should be stronger in an appropriately provisioned managed-device mode; ordinary installation cannot universally prevent third-party apps from launching.
- Remote photo/video requests must be checked against Android version, permissions, enrollment mode, and supported capture mode. If the OS rejects an operation, return a truthful status rather than claiming success.
- Audio/camera use must follow applicable OS permissions, background restrictions, and privacy indicators.
- Only list or transfer files accessible through app-owned storage or appropriately granted access.
- Keep resource consumption low through adaptive sampling, batching, and bounded local queues.
- Allow parent-authorized Google Drive backup for selected media.
- Include secure pairing, encryption, retention controls, device revocation, audit logging, and paid subscriptions.

## 3. Decisions

### D-001 — Hybrid Android implementation
Use C++17/20 for shared/performance-sensitive logic and Kotlin/Java for Android lifecycle, services, runtime permissions, UsageStatsManager, location, camera integration, device policy, and WorkManager. A pure-C++ Android design is not recommended because the app still needs supported platform interfaces.

### D-002 — Permissions are not an OS bypass
The setup experience can guide the parent through runtime and special-access settings. Granting a permission does not remove all background-execution or device-policy restrictions, and permissions can later be revoked.

### D-003 — Two supported operating modes
- **Standard mode:** installed on an existing personal phone; feature availability is limited to APIs and permissions available to an ordinary app.
- **Managed mode:** phone is deliberately provisioned under Android device-management controls; stronger restrictions may be available.

The UI, backend capability profile, and documentation must not imply these modes provide identical functionality.

### D-004 — Capability-gated media requests
A parent-side photo/video request is only dispatched where the device's capability profile indicates a tested supported workflow. The child agent revalidates capability at execution time. Supported states include queued, accepted, completed, failed, unsupported, permission required, OS rejected, and user action required. Success requires confirmation of the resulting media.

### D-005 — Authorized and transparent capture
No covert capture, hidden indicators, permission bypasses, or techniques designed to evade Android safeguards. Implement only supported capture workflows with the required authorization and indicators.

### D-006 — Security and privacy by design
Use TLS, per-device credentials, least-privilege authorization, protected audit logs, encrypted sensitive data, revocation, configurable retention, and parent-authorized OAuth for Drive. Do not collect or store Google passwords.

### D-007 — Local-first reliability
Persist events locally in an encrypted queue and upload in batches. Expose location age and accuracy rather than presenting stale coordinates as live.

### D-008 — Honest command outcomes
Every command must have an ID, expiry, and auditable state. A queued or delivered request is not a completed operation.

## 4. Open questions

1. Minimum Android version and target API level.
2. Is managed-device enrollment optional or required for the first release?
3. Parent interface: native Android, web, or both?
4. Backend hosting environment, expected scale, and database choice.
5. Data-retention defaults and deployment/data-residency requirements.
6. Subscription regions, pricing, grace periods, refunds, and entitlements.
7. Google Play distribution and policy-review strategy.
8. Should media capabilities be deferred until compatibility tests complete?
9. Which phone manufacturers/models are in the first supported test matrix?

## 5. Acceptance principles

- Each feature has documented permission, enrollment, and compatibility requirements.
- Remote commands are authorized and have accurate execution status.
- The dashboard distinguishes live, stale, approximate, and unavailable data.
- The product does not promise universal app blocking or unrestricted background recording.
- Permission revocation, offline devices, and OS rejection produce clear degraded/error states.


## 6. Proposed feasibility assessment

This assessment records the initial planning view, not a guarantee that every feature works on every Android device. Final feasibility must be confirmed on target API levels, OEMs, permission states, distribution channel, and enrollment modes.

| Feature | Initial feasibility | Key condition / limitation |
|---|---|---|
| Pairing without a separate child account | Feasible | Short-lived pairing and revocable device credentials. |
| Background location, position, route history and speed | Feasible with conditions | Appropriate permissions, compliant background execution, connectivity, and accuracy/freshness reporting. |
| Daily/weekly/monthly/yearly app usage | Feasible with special access | Usage Access must be granted; available data depends on Android APIs. |
| Remote commands and file listing | Partial | Command delivery is feasible; file access is limited to app-owned or explicitly accessible storage. |
| Scheduled app blocking | Conditional | Strong enforcement generally requires supported device-policy controls and managed-device provisioning. Ordinary apps cannot universally block all other apps. |
| Remote photo/video requests | Conditional and capability-gated | Check OS/API level, permission, service/lifecycle restrictions, enrollment mode, and tested device behavior; report OS rejection or user-action-required states truthfully. |
| Remote audio recording | Restricted / requires validation | Runtime permission alone does not guarantee arbitrary background activation; use supported authorized workflows and honor privacy indicators. |
| Parent-authorized Google Drive backup | Feasible | OAuth authorization, least-privilege scopes, secure token handling, and upload retry/resume. |
| Subscription billing | Feasible | Trusted provider integration and server-side entitlement validation. |
| Low CPU/RAM/battery use | Goal, not yet measured | Adaptive sampling, bounded queues, batching, and real-device performance tests are required. |
| Lightweight C++ backend | Feasible | Production-grade TLS, authentication, rate limiting, secure storage, monitoring, and operations are required. |

### Feasibility validation plan

1. Select a minimum Android API level and representative devices/OEMs.
2. Test standard installation and managed-device enrollment separately.
3. Verify each permission/special-access flow, including later revocation.
4. Test location in background, stationary/moving states, offline recovery, and battery impact.
5. Test Usage Access and usage aggregation.
6. Test app restrictions on a properly provisioned managed test device.
7. Test camera/audio requests against actual OS behavior; verify indicators and truthful command statuses.
8. Validate Google OAuth/Drive upload, subscription entitlement, security, and retention.
9. Record results as **Pass**, **Pass with conditions**, **Fail**, or **Not tested**, including OS/device/build details.

No feature should be described as production-supported until this validation is complete.

## 7. Follow-up conditional feasibility review — 2026-10-25

The initial matrix in section 6 was a preliminary assessment. A more detailed, source-linked review is maintained in [Feature Feasibility Conditions and Evidence](../02-market-and-feasibility/FEASIBILITY_CONDITIONS_AND_EVIDENCE.md). Treat the newer document as authoritative for **why** features work, **what conditions** are needed and **what remains unsupported**. In particular:

- Eligible applications may be suspended under correctly provisioned managed-device policy APIs; ordinary runtime permissions alone do not confer that authority.
- Camera/microphone access is not universally impossible but is highly conditional on permitted platform execution context, privacy/disclosure requirements and independent distribution approval. Unrestricted or concealed remote recording is not a product promise.
- The initial parent-granted-permissions assumption remains, but permission grants do not override background execution constraints.
- Proposed roadmap, Play declaration and validation details are in [Implementation Technical Specification](../../M1-secure-platform-foundation/01-requirements-and-architecture/IMPLEMENTATION_TECHNICAL_SPECIFICATION.md), [Google Play Publishing Requirements](../../M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md) and [Validation and Release Plan](../../M8-operational-readiness/03-quality-and-evidence/VALIDATION_AND_RELEASE_PLAN.md).
- **No Android device compatibility results or Google Play approvals have yet been obtained.**

## 8. New product request: parent-labeled addresses, road history and multiple stops (2026-10-25)

The parent shall be able to create arbitrary address/coordinate pins with titles and see these labels near the observed child position on Google Maps. Historical movement shall be shown as a segmented, time-ordered travelled track with multiple dwell-stop markers, not a computed directions route presented as a fact.

**Decision D-013:** Evaluate stops and named-place matches on the C++ backend so the child need not run geocoding or map rendering. Parent place markers require no additional child GPS sampling.

**Decision D-014:** Use adaptive location modes and define the measurable battery/accuracy trade-off. Default to lower-power, potentially sparse tracks; reserve time-limited high-detail recording for genuine need.

**Decision D-015:** Apply road matching only to sufficiently dense, reliable vehicle observations **after** checking Google Roads API commercial tracking license and content retention terms. Sparse segments and unknown gaps shall remain explicitly approximate/unknown.

**Decision D-016:** Preserve independent device provenance when watches/tablets/phones may report the same child's position. Watch GNSS absence and disconnects must not be hidden.

Detailed conditions, technical approach, schemas, API endpoints and device tests: [Live Trip Route, Named Places and Battery Specification](../../M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md).

## 2026-10-26 — Owner decision on conditional media and parent-unavailable reasons

**Accepted:** media functionality is technically **conditional, not inherently impossible**. Research one-way live audio, permitted parent-local recordings, live camera, front/rear photo snapshots with flash-off when hardware allows, authorized video, MediaProjection screen viewing with a **new system consent per session**, and previously authorized app-owned/shared MediaStore/SAF file listings/transfers. Do not provide arbitrary app-private-file browsing. Alarka's main Activity normally appears only during initial setup or when opened intentionally to inspect permissions; required system indicators and identifiable monitoring notification persist. STANDARD vs genuinely provisioned MANAGED_DEVICE_OWNER differs for Android background microphone/camera FGS starts. Device-owner exception is test-only, not a general permission bypass.

Madalasa must show the actual **Command.status + reason_code**, verified from Alarka, and a useful next step on each unavailable action. Examples: microphone permission revoked, Android blocked a standard-mode background start, managed provisioning required, child action or per-session screen-share consent needed, device offline, sensor unavailable, session interrupted, file scope revoked, network down. Never invent a permission failure when no device response exists or claim capture succeeded upon FCM delivery. Owner acceptance of technical constraints **does not waive existing Indian legal, Google Play, child privacy, security or commercial-release gates**. Media remains P3 research / off at launch.

Proposed research transport is P2P-first encrypted WebRTC + TURN fallback, no VPS media files, optional encrypted recording on parent phone and separately modeled relay costs. Full mapping and tests: [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md).

## 2026-10-27 owner decision: scan → guided grant → device-confirmed parent status

The owner requests first-install **automatic Alarka hardware/Android feature discovery**, upload of the compatibility list after **secure family/device pairing**, step-by-step in-app rationale followed by **Android-owned permission grants or Settings** and confirmation UI. Alarka verifies each *actual Android grant* after the dialog/Settings returns, increments a device-local monotonic report version, securely synchronizes the new state and waits for durable server ACK. Madalasa fetches its authorized child-device compatibility list and displays a positive verified-grant confirmation; separate runtime/release/freshness checks decide whether the **feature itself is ready**, especially for remote audio/camera P3 research. A grant of CAMERA/RECORD_AUDIO never implies always-on background capture. No server/parent-generated fake Android grant reports.

Changes of permission in Android Settings, one-time permission expiry, selected-photo scopes and reapproval must likewise resync **at the next permitted Alarka execution**. Android may kill the process on revoke and offline/force-stop may delay sync; parent shows last verified timestamp / STALE / UNKNOWN rather than a spurious immediate revoke. Alarka main Activity may close after setup while required app identity, monitoring notice and OS indicators remain. Foreground/background location are separate steps on Android 11+; screen sharing needs new consent each session. This product-design decision is in [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md), with [46 editable Figma screens](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-2). Engineering, India DPDP, Google Play and real-minor testing gates remain open.

## 2026-10-27 owner accepts PostgreSQL durable inbox plus batched C++ GPS inserts

Previous design conversation: GPS must preserve enough **actual recorded coordinates** to reproduce Google Maps trip lines rather than inventing a road path between two endpoints. Alarka shall **record adaptive GPS independently of network upload** and persist eligible timestamped observations in an **encrypted 48h offline-capacity local queue**. When Android service/network allow, target sending **one JSON array batch every 1–2 minutes**, not one network request per point. The child Activity normally stays closed after setup; system-required location foreground-service monitoring remains visible. GPS collection frequency depends on movement and route quality; existing 300 points/day is an economic average scenario, not enforced limit.

Owner asked whether server-side buffering such as Redis would help and accepted a lower-overhead approach: **PostgreSQL durable inbox (one row per uploaded batch) instead of Redis**. Crucially, owner also accepted **bulk database insertion**: C++ Drogon authenticates/validates and durably COMMITs inbox Tx A before HTTP 202 QUEUED, then independent C++ worker leases batches and uses **prepared multirow/COPY staging → dedup + time-partitioned raw GPS + reconstruction outbox + inbox processed in Tx B COMMIT**. The client can remove only positively ACKed local batches. Usage events/sessions get a distinct batch/aggregation pipeline. Parent map reads last committed data with observed/received/processed freshness and reconstructed late trips. A same-transaction direct raw+dedup+outbox bulk path must be benchmarked because it may be cheaper in WAL; no measured performance claim yet. No Redis required for MVP, optional if proven later.

Canonical [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md); editable [HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-2), [LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-60), [decision diagram](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-126). T-ING-01…24 NOT_TESTED. India children’s location/usage processing restrictions and Play requirements are unchanged.
