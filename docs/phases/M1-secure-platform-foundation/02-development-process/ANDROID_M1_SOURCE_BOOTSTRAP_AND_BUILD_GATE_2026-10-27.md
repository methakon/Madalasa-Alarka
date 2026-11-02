# Android Source-to-Build Gate — Madalasa and Alarka

> **Document control:** M1 / 02-development-process · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Status:** Design plan / not buildable yet, 2026-10-27. **Not** a Gradle project or claim of functioning Android app.  
**Purpose:** Close the concrete source/build gap identified during the repository checklist review.  
**Source inventory checked:** `android/README.md`, `android/alarka/src/main/kotlin/org/madalasa/alarka/domain/LocationObservation.kt` and `android/madalasa/src/main/kotlin/org/madalasa/madalasa/domain/VerifiedLocationState.kt` exist; **no `gradlew`, `settings.gradle.kts`, app-level `build.gradle.kts`, AndroidManifest or compiled APK** exists. Repo current CI only tests 11-operation M1 JSON-formatted OpenAPI and PostgreSQL 16 synthetic tenant isolation.

## Bootstrap checklist — separate app responsibilities

| Deliverable | Madalasa parent | Alarka child |
|---|---|---|
| Actual package/application ID | Select & verify Play/publisher ownership | Separately select, review Android monitoring metadata and policy |
| Gradle/AGP/Kotlin/JDK/wrapper version | Pin compatible supported versions, lock dependencies and CI | Same compatibility exercise, not guessed hardcoded versions |
| AndroidManifest | Minimal launcher, no unnecessary device permissions | Visible launcher, declared and lawfully approved monitoring components; **no covert microphone/camera code** |
| First Kotlin Activity | Compose accessible child-selector/empty-state design using mock data | Visible transparency/onboarding and read-only capability scan on synthetic/default mock; OS permission prompts only when user follows actual flow |
| Networking | Versioned authenticated M1 client; scoped child grants | Device-bound enrollment and idempotent results with no raw child data in logs |
| Data persistence | Encrypted local sensitive tokens, authorized offline UI cache | Actual encrypted local SQLite/Keystore queue **only after legal release decision**, 48-hour capacity target, not always-on collection guarantee |
| Location, UsageStats, media | Parent map displays stale/last-confirmed and no fake live marker | Each feature independently Android/India/Play gated; remote mic/camera/screen research stays OFF |
| Tests | Reducer/UI accessibility, cross-child scope, failed auth, pagination/regrant and offline | Android physical permission/FGS, battery, partial media access, managed DPC real enrollment and 48h offline recovery |
| Signing/release | Debug signing first; Play key/KMS separate | Same, dedicated package and publisher permission; no production key in Git |
| Evidence | `./gradlew :madalasa:assembleDebug` + unit test artifact after Gradle project exists | `./gradlew :alarka:assembleDebug` + unit/instrumented evidence after Gradle project exists |

## Ordered milestones

1. **A0: Owner/platform decisions.** Confirm publisher identity, supported country/age policy, Java/AGP/Kotlin/SDK versions from official platform docs, device package IDs, branch CI, API baseline and signing custody. Verify no forbidden real-child monitoring path before any device test.
2. **A1: Safe app bootstrap.** Create independent Gradle modules, manifest, standard launcher icon and an obvious transparency/about screen with **no location/usage/camera/microphone/screen capture permission requested**. Build debug APKs and synthetic UI unit tests. This is an **implementable** milestone without activating protected monitoring.
3. **A2: M1 pairing/authentication.** Device enrollment and parent grant protocol; validated account and child isolation; command receipt statuses and OS permission-state reducer. Never translate guardian remote request to silent Android permission grant.
4. **A3: Permission and source-capability gate.** Hardware scan public properties, per-feature contextual rationale, Android-owned prompt/settings with version-specific checks, durable child->server versioned report after enrollment, parent last-verified status. Physical OEM acceptance T-CAP-01…24 required.
5. **A4: Location pipeline (LEGAL/PLAY RELEASE-GATED).** Adaptive location callback separated from eligible 1–2-minute uploader, encrypted 48h offline **capacity** buffer, authenticated durable 202/Postgres inbox Tx A, C++ worker bulk Tx B and parent route freshness. Tests T-ING-01…24; no collection while blocked, revoked or unapproved.
6. **A5: Separate app usage, SOS, media research, admin.** UsageStats sessions are not precise live foreground truth; SOS not guaranteed emergency dispatch; P3 mic/camera/screen research remains disabled pending explicit review. No privileged admin UI embedded in Alarka or Madalasa.

## Build and CI acceptance evidence (all pending)

- [ ] Real `android/gradlew` with checked in wrapper configuration and checksum, no unsigned binary downloaded from random sources.
- [ ] Real `settings.gradle.kts`, version catalog/lockfiles, `madalasa` and `alarka` Gradle application modules with separate IDs.
- [ ] Minimal manifests, launcher Activities, visible Alarka monitoring branding, accessibility and CI debug APK build.
- [ ] Kotlin static formatting/lint and deterministic unit tests on synthetic only; physical Android/OEM instrumentation matrix.
- [ ] Supply-chain/SBOM, third-party Google/AndroidX licence inventory, no credentials in Firebase config or Gradle files.
- [ ] No child monitoring flags enabled until signed DPIA/retention/verified parental authority/India law and Play decisions.
- [ ] M1 SQL/API integration with per-child grants/negative tests, transparent failure receipts, documented version compatibility.
- [ ] Test and file actual build logs/checksums under secure build artifact storage; no false "APK available" claim.

**Next implementation work is Android A1 bootstrap, not copying placeholder Gradle commands into README.** Refer to [Build guide](BUILD_AND_RUN.md), [Coding standards](DEVELOPER_ONBOARDING_AND_CODING_STANDARDS.md), [Capability ADR](../03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md), [GPS queue ADR](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md), [M1 scope](../01-requirements-and-architecture/M1_ANDROID_CPP_ARCHITECTURE_AND_IMPLEMENTATION.md), [app signing policy](../03-security-and-permissions/APP_SIGNING_AND_KEY_MANAGEMENT_POLICY.md), [release gate](../../M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md).
