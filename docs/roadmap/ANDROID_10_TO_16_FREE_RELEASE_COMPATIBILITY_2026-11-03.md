# Alarka Android 10–16 compatibility and free-release gate

**Date:** 2026-11-03. **Versions:** Android 10–16 = API 29–36 (Android 12L is API 32). **Free release:** Parent pairing + one ADMITTED child-service slot + verified authority/consent + separate Play/legal approval + Android runtime grants + visible notification before sensor collection. No premium or BillDesk dependency.

## What is committed vs still missing

| Capability | Branch source | Status |
|---|---|---|
| Declare Android 10–16 support | `android/alarka/build.gradle.kts`: `minSdk=29`, `compileSdk=36`, `targetSdk=36` | Configured; physical OEM coverage still required |
| Read OS version, network/GPS provider, actual permission grants, manifest declarations, system location and notification enabled | `AndroidDeviceCapabilityScanner.kt` | Implemented read-only scan |
| Re-check OS on return from Settings | `MainActivity.onResume()`, `ChildViewModel.refreshCapabilities()` | Implemented; production service-side lifecycle/revocation subscription outstanding |
| Exact child admission + backend consent + real Keystore pairing + independent legal gate | `AndroidPermissionPreflight.kt`, `Android10To16PermissionPlan.kt`, `ChildMonitoringActivationPolicy.kt` | Policy implemented; backend explicitly returns `collection_authorized=false`, so production collection stays OFF |
| Foreground/notification permission dialogs and Settings instructions | `ChildNavHost.kt`, `PermissionsScreen.kt` | User-tap-only Android activity result controllers; impossible without verified server facts and release approval |
| Android 10–16 location foreground-service manifest and non-collecting visible QA service | `src/debug/AndroidManifest.xml`, `src/debug/kotlin/.../VisibleLocationTestService.kt` | Debug internal-only scaffold; no GPS sampled, no upload, never automatically started |
| Public release manifest | `src/main/AndroidManifest.xml` | INTERNET and monitoring disclosure metadata only; NO location permissions or monitoring FGS until approved |
| Real background location sampling, encrypted durable outbox, authenticated ingestion, permanent visible monitoring service and renew/revoke | Child/API integration | **NOT IMPLEMENTED/ACCEPTED for production** |
| Play Store/India child-data audience, policy and legal permission | External approval/evidence | **NO-GO** until independent review; cannot infer from `isMonitoringTool` |

## OS-specific implementation and expected behavior

> **2026-11-04 HARDWARE SCAN EXTENSION:** Optional accelerometer, gyro, gravity, proximity, light, barometer, compass, step and motion sensors now use `SensorManager` presence checks, not an automatic runtime permission; battery/charging/saver are local read-only diagnostics. Both GPS and network-provider availability are checked. NavIC (IRNSS) is marked **unknown** without authorized GNSS observation. Public manifest hardware features are `android:required="false"`, not dangerous sensor permissions. Child camera/mic capture remain absent from the public release. See [compliance and module fallback contract](PINGO_COMPARISON_OPTIONAL_DEVICE_HARDWARE_2026-11-04.md).

| Android | API | Free tracking permission/platform UX |
|---|---|---|
| 10 | 29 | Ask foreground location after guardian authorization. If separately approved and necessary for restart beyond visible FGS, ask background location in a **separate request**. Declare location FGS type on the active build. |
| 11 | 30 | Background permission is through Android Settings, not bundled with the foreground request. Parent/child still requires visible service start from a user-allowed context. |
| 12 / 12L | 31 / 32 | Accept approximate/coarse access; never infer precise. Background FGS starts blocked unless OS exemption genuinely applies. |
| 13 | 33 | Explicit notification runtime request when needed for visible monitoring UX. Android may still allow a foreground service if denied, but app will not claim a user-visible drawer notice. |
| 14 | 34 | Require `FOREGROUND_SERVICE_LOCATION` and `foregroundServiceType="location"` in the *approved* manifest; verify actual while-in-use access at start, avoid illegal background creation. |
| 15 | 35 | Same location/FGS restrictions, plus current OEM foreground-service and power conditions; handle rejection as a stopped state. |
| 16 | 36 | Same, and respect job/runtime quotas, including work scheduled from an FGS; do not guarantee uninterrupted GPS uploads if OS suspends/kills. |

All eight API levels are explicitly covered by `Android10To16PermissionPlanTest` and `AndroidPermissionPreflightTest` (JVM). `PermissionMatrixInstrumentedTest` checks the actual hardware/manifest/grants on a physical/emulator Android device when run using `connectedDebugAndroidTest`. **A green JVM test does not verify eight physical versions or every manufacturer.**

## Manifest boundaries

**Public release (`src/main/AndroidManifest.xml`):** child monitoring designation, INTERNET, no sensor capture permission. An app with this manifest may be installed/opened for setup but cannot perform the advertised free location monitoring and must not be marketed as operational live tracking.

**Debug-only (`src/debug/AndroidManifest.xml`):** location fine/coarse, independently reviewed background-location test declaration, foreground-service permissions/type and Android 13+ POST_NOTIFICATIONS; GPS hardware declared optional; test foreground service exported=false. The QA service displays a notification only and intentionally never samples or transmits location. Debug permissions must not be copied automatically to public release.

`R.bool.alarka_location_release_approved` defaults to **false** in Gradle and is not a user or parent override. The UI cannot request OS location permission until this gate AND server-confirmed current pairing, admission and consent all pass. The real server independently keeps `collection_authorized=false` until approved; it never equates an Android permission with legal authority.

## Mandatory public-deployment exit criteria

1. Resolve Play target-audience/Families location restriction without misrepresenting child monitoring; obtain documented legal signoff for India children's location data, DPDP applicability, guardian authority and retention. Google Play specifically bars apps solely targeting children from requesting location permission or processing precise location.
2. Implement production visible location service, correct declared permissions, supported runtime request orchestration, power management, Android 10–16 OS/OEM acceptance, disabled/degraded/offline statuses and permanent transparent notification.
3. Finish actual child Keystore pairing and QR session flow, one-active-device constraint, 108 admission, secure device bearer refresh and revocation, consent withdrawal and real location ingestion/6-hour scoped parent reads end-to-end.
4. Test Android 29,30,31,32,33,34,35,36 (physical/emulator + representative OEM), including approximate only, notification refusal, background FGS denial, GPS off, background and battery restriction, Settings revocation and local device wipe.
5. Green child, parent and API branch CI, merge-reviewed pull requests, signed release builds with production package IDs, independent security/DB RLS tests, accurate Play data safety and monitoring disclosures, Play internal/closed testing and approval.
6. Do not publish a nonfunctional app claiming live tracking or move to production solely because the test manifest and permission policy compile.

## Android/Play source policy

- https://developer.android.com/develop/sensors-and-location/location/permissions
- https://developer.android.com/develop/sensors-and-location/location/permissions/background
- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://developer.android.com/develop/background-work/services/fgs/service-types
- https://developer.android.com/develop/ui/compose/notifications/notification-permission
- https://developer.android.com/about/versions/14/changes/fgs-types-required
- https://developer.android.com/about/versions/13/behavior-changes-all
- https://developer.android.com/about/versions/15/behavior-changes-all
- https://developer.android.com/about/versions/16/behavior-changes-all
- https://support.google.com/googleplay/android-developer/answer/9893335
- https://support.google.com/googleplay/android-developer/answer/12955211

**Verdict:** Android 10–16 capability/preflight and safe permission UI implementation progressing on `child`; as of this revision **free version with live child tracking is NOT deployable to the public Play Store**. Signed AAB, production backend and actual permissions/approval remain necessary.

## Verified GitHub CI checkpoint (2026-11-03)

- Child branch `1d5121e`: [Android compilation and JVM tests PASS](https://github.com/methakon/Madalasa-Alarka/actions/runs/41694371449), [local checks PASS](https://github.com/methakon/Madalasa-Alarka/actions/runs/41694371341). Includes OS API 29–36 matrix, permission UI and debug-only visible FGS test scaffold.
- API branch `1bb3afc`: [M1 API/tenant workflow PASS](https://github.com/methakon/Madalasa-Alarka/actions/runs/41694949726), including C++ build, PostgreSQL V2 migrations, tenant isolation and ParentOIDC session HTTP E2E. New device consent response reports child-slot admission but still has `collection_authorized=false`.
- These results **do not** prove physical-device Android 10–16 compatibility, an operational tracking service, a signed production AAB, Play approval, or live/real-child rollout. The associated PRs are still subject to review and merge.
