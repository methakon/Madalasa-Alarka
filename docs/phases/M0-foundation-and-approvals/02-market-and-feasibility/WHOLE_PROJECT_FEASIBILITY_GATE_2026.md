# Whole-Project Feasibility Gate and Scope Decisions

> **Document control:** M0 / 02-market-and-feasibility · Proposed owner: Product + finance (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (parent), **Alarka** (child); verified [Madalasa-Alarka GitHub repository](https://github.com/methakon/Madalasa-Alarka). [Brand contract](BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Madalasa–Alarka · 2026-10-25 · Review FG-2026-01 · Documentation-only feasibility**

Related sources: [Discussion](../01-project-governance/DISCUSSION.md), [original feasibility](FEASIBILITY_CONDITIONS_AND_EVIDENCE.md), [competitor comparison](COMPETITOR_FEATURE_COMPARISON_AND_ADOPTION_2026.md), [feedback research](MARKET_FEEDBACK_GAPS_AND_DIFFERENTIATION_2026.md), and [C++ architecture](../../M2-location-collection/01-location-collection-and-ingestion/ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md).

## 1. Approval semantics

The new features are included in **design scope after feasibility review**, not declared implemented or Play-approved. Categories: CORE = design target; CONDITIONAL = requires specific Android/device/security tests and feature flag; RESEARCH = no launch commitment; PROHIBITED = not implemented.

**No device benchmark, OS compatibility test, release-binary audit, load test or Play review has been completed by writing this document.**

## 2. D01–D14 feature gating

| ID and feature | Why technically feasible | Condition/difficulty | Gate and decision |
|---|---|---|---|
| D01 Route Evidence / Confidence | Location timestamps, accuracy and C++ trip/stop outputs already designed | Honest uncertainty labels, do not invent confidence percentages | **CORE P0**; labeled GPS tracks and gap tests |
| D02 Tracking Reliability Center | Permission snapshots, heartbeat and separate fix/ingest/processed timestamps | Cause of offline state may be unknown | **CORE P0**; injected failures and truthful UNKNOWN |
| D03 Offline Trip Recovery revisions | Encrypted queue, durable idempotent ingest and event-time workers | Late corrections/version races | **CORE P0**; late/duplicate replay test |
| D04 Commute / missed-arrival analysis | Place dwell and schedules with notification worker | GPS dropout and false safety alerts | **CONDITIONAL P1**; false-alert field pilot |
| D05 Temporary pickup guardian access | Child-scoped grants with TTL and token revocation | Link forwarding, location exposure | **CORE P1 security-gated**; revocation and SSE tests |
| D06 Access/privacy ledger | Audit entries and grant history | Metadata itself is sensitive, storage and retention | **CORE P1**; redaction and authorization tests |
| D07 Battery/coverage feedback | Location profile and observation-quality metrics | Claims cannot be made without battery/accuracy measurements | **CONDITIONAL P1**; measured phone/watch comparison |
| D08 Screen-time rule simulator | C++ policy pure functions and device policy adapter | Actual blocks need legitimate DPC authority; excluded apps | **CONDITIONAL P1 managed**; preview/rollback parity tests |
| D09 Phone/watch/tablet source handoff | Per-device identities and source timestamps | Cannot prove which device is physically carried | **CONDITIONAL P2**; multi-device trace tests |
| D10 Capability-before-purchase | Backend entitlement and device capability profile | Permissions can change later | **CORE P1**; no impossible feature advertised |
| D11 Privacy-safe support bundle | Redacted logs, error IDs and user-authorized diagnostic export | Child identity/location leakage risk | **CORE P1/P2 opt-in**; data-loss prevention tests |
| D12 Child transparency center | Existing setup, notification and capability state | Minimal UI vs visible disclosures; regional child privacy | **CORE P0/P1**; UI/disclosure audit |
| D13 Route-corridor deviation | Known routes and spatial corridor algorithms possible | Very high false positives, sparse traces, Maps licensing | **RESEARCH P3**; not launch-committed |
| D14 Schedule-aware tracking pulse | Motion/location policy states + schedule | Android background execution, battery, location uncertainty | **CONDITIONAL P2**; physical battery and lifecycle trials |

All 14 are traceable in the revised SRS. They are not all first-release deliverables.

## 3. Original project feature viability

| Feature | Engineering feasibility | Limitation | Decision |
|---|---|---|---|
| Parent login, pairing without child account | One-use pairing tokens + Keystore device identity | Must detect/revoke stolen credentials | CORE |
| Parent/family/multiple children/guardians | Family-child-device ACL + database | Cross-family access is critical risk | CORE |
| Background location, travel history, speed | Android Location APIs, permitted service, encrypted queue | Permission/FGS, GNSS, OEM and network limits | CORE conditional on grant |
| Parent-labeled places and stop detection | Maps markers, server-side geospatial dwell | Wrong GPS/short stop; 100 active geofences per app/device user | CORE; geofence alerts conditional |
| App-usage day-to-year aggregation | UsageStatsManager after Usage Access | OS history limited; long-term accumulation needed | CORE conditional on special access |
| SOS/check-in and find-device sound | User-visible actions and authenticated commands | Offline/DND/audio restrictions | P1, child-facing option |
| Scheduled app blocking | DevicePolicyManager on properly enrolled managed device | Ordinary installation not device owner, protected packages | CONDITIONAL |
| Parent file/media list + Drive backup | SAF/MediaStore/app-owned storage, parent OAuth | Other app-private data protected, Drive token/quota rules | PARTIAL P2 |
| Remote photo/video/audio requests | Properly permitted and disclosed capture workflow | No unrestricted remote background activation; Android privacy indicators; Play review | RESTRICTED P3, no covert capture |
| Google Maps parent UI and billing | Google Maps SDK, Play Billing, backend entitlements | Keys/cost, purchase lifecycle, policies | CORE commercial |
| Low CPU/battery C++ backend | Adaptive collection, batching, separate Drogon workers | Performance not proven by language choice alone | NFR and test gate |
| Play publication | App bundles, forms, monitoring disclosures | Console review, real privacy/deletion pages and tests | GATE |

## 4. Current official platform constraints, verified October 2026

- Google Play: new standard Android phone apps/updates submitted from August 31, 2026 must target Android 16/API 36+, subject to specific exemptions/extensions. Wear OS has a separate API 35+ threshold. Minimum supported Android version is a product choice.
- Android location service: foreground-service type location and FOREGROUND_SERVICE_LOCATION declarations with location grants and applicable ACCESS_BACKGROUND_LOCATION/FGS-start restrictions.
- Geofencing: 100 active per app/device-user; delayed/approximate events, not recommended for Wear OS battery.
- Managed suspension: DevicePolicyManager.setPackagesSuspended requires device owner, eligible profile owner or delegate; system-critical packages cannot be suspended. Parent onboarding permissions are not device-owner provisioning.
- Camera and microphone: background starts face while-in-use and foreground-service constraints; specific documented exceptions are test candidates, not a promise or permission for covert recording.
- Google Play monitoring: recognizable app identity, isMonitoringTool designation, transparent disclosure and persistent notification while monitoring runs.
- C++ release: native .so files and SDKs must support 16 KB page-size devices.
- Google Roads: no more than 100 GPS points per request; accurate matching needs dense points; asset-tracking/caching/license terms must be checked.

## 5. Promotion and validation gates

Feature statuses: DESIGNED → IMPLEMENTED → DEVICE_VERIFIED → SECURITY_VERIFIED → POLICY_VERIFIED → RELEASE_ENABLED.

- DESIGNED: SRS requirement, API/data model, algorithm, fallback and risk recorded.
- IMPLEMENTED: code plus automated tests exist.
- DEVICE_VERIFIED: exact OS/OEM/build and permission-state evidence.
- SECURITY_VERIFIED: cross-family, token misuse, retention and replays tested.
- POLICY_VERIFIED: actual release manifest, monitoring identity, background-location disclosure, billing, Data safety and Play acceptance as applicable.
- RELEASE_ENABLED: supported build/version and specific feature flags are enabled.

Stop/re-scope attempts to bypass Android privacy controls, enumerate other apps' protected files, hide monitoring, or claim unmeasured tracking precision. Standard and managed device modes have distinct capabilities.

## 6. Recommended validation order

1. Pairing, per-child/guardian authorization, revocation and deletion design.
2. Android background location, visible monitoring, battery sampling with real devices.
3. Durable ingest and C++ reconstruction, including offline and out-of-order data.
4. Named place, trip/stop/gap accuracy and existing usage analytics.
5. D01–D03 trust features, D05–D06 family permissions and audit.
6. Commute confidence and energy/coverage field tests.
7. Optional properly provisioned managed-device app-block rules and source handoff.
8. Google Drive, payments, SOS/check-in and release hardening.
9. Optional media only via proven authorized, visible, policy-compliant workflow; D13 corridor alerts research only.

## 7. Official sources

- Android FGS background starts: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- Android foreground service types: https://developer.android.com/about/versions/14/changes/fgs-types-required
- DevicePolicyManager: https://developer.android.com/reference/android/app/admin/DevicePolicyManager
- Android geofencing: https://developer.android.com/develop/sensors-and-location/location/geofencing
- Play monitoring: https://support.google.com/googleplay/android-developer/answer/9888380
- Play background location: https://support.google.com/googleplay/android-developer/answer/9799150
- Play target API: https://support.google.com/googleplay/android-developer/answer/11926878
- Android native page sizes: https://developer.android.com/guide/practices/page-sizes
- Roads snap-to-roads: https://developers.google.com/maps/documentation/roads/snap

**Result:** Core additions join the specification; conditionally feasible additions require specific tests, feature flags and fallbacks; deferred/unavailable features are not silently represented as shipped capabilities.

## 2026-10-26 interpretation: conditional does not mean impossible

The owner accepts investigating **technically achievable under documented conditions** one-way audio/recording, remote camera snapshots/live/video, flash-off where supported, MediaProjection with fresh Android permission each session and allowed MediaStore/SAF file/media listing. These remain **RESTRICTED P3 / RELEASE-DISABLED** until security, device, India legal and Google Play evidence exists. Initial granted CAMERA/RECORD_AUDIO permissions never guarantee later STANDARD background sensor service startup; eligible on-device interaction or genuine device-owner exception requires testing. Alarka's main Activity may stay closed after setup without disguising sensor indicators or required notification.

**Required parent outcome:** when an action cannot operate, Madalasa explains **verified exact cause and safe next action** using `Command.status + reason_code`, not generic failure; DEVICE_OFFLINE/UNKNOWN cannot be labeled permission denied. See [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md) for scope, reason codes and T-MEDIA tests. No legal/Play release gate has been waived.

## 2026-10-27 owner-accepted read-only discovery → guided Android grants → signed parent report

Add a **conditional/core engineering design** for initial Alarka hardware/API capability scan, pairing-bound versioned capability upload, progressive Android permission wizard with in-app rationale, actual OS grant verification, backend durable storage and authorized Madalasa GET. After revoke/reapproval detect when Alarka next runs under a valid OS context; do not promise immediate push after Android kills process or when offline. Parent green can describe **verified permission granted** but not unlimited operational capture; readiness requires feature release flag, OS context and fresh verification. Grey stale/offline, amber partial/temporary/conditional/action-needed, red verified denied/revoked/unsupported. Review [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md), tests T-CAP-01…24 (ALL NOT_TESTED). Android, security, Google Play/Families and India legal/child-data approval remain separate and unresolved; new UI/API are DESIGN ONLY.

## 2026-10-27 GPS buffering + Postgres inbox/bulk feasibility assessment addendum

**Technically feasible as design, NOT proven on Android/OCI hardware:** separate adaptive location fix capture from eligible 1–2min JSON network batches, encrypt a local up-to-48h offline observation capacity, commit one Postgres inbox row per device batch before 202, then C++ SKIP LOCKED workers perform bulk prepared insert / optional COPY staging into dedup+partitioned PostGIS+outbox (Tx B). Redis is optional rather than a mandatory RAM dependency. This protects delivery during transient network/worker outages, yet imposes extra Postgres WAL/storage and does not guarantee Android foreground service eligibility, accurate 5–15s GPS or all 48h samples. Compare direct raw+outbox bulk transaction resource use before production sizing. Tests T-ING-01…24 pending. India's child data and Play Families/monitoring restrictions, guardian scope, OCI hosting, privacy retention remain NO-GO gates. [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md).
