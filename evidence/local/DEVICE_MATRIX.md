# Android physical-device acceptance matrix

**Task:** L18-012 — "Run mixed API29..36 Android physical/OEM acceptance"
**Acceptance:** *"No green pass without actual tested device"*
**Status:** PARTIAL — real devices tested, full API 29..36 span NOT covered
**Release gate:** LOCAL_ONLY · **Privacy class:** SYNTHETIC_DATA_ONLY

**Branch:** `api` · **Host:** Ubuntu 24.04.5 LTS, kernel 7.0.0-42-generic · JDK 17.0.20.1 ·
Android SDK platform 36 / build-tools 36.0.0 · Gradle 8.9 · adb 1.0.41 (34.0.4-debian,
`/usr/lib/android-sdk/platform-tools/adb`) · **API levels tested:** 30 and 28.

Device serials are redacted; devices are referenced as A and B. Results are read from the
generated `TEST-*.xml` under `android/<module>/build/outputs/androidTest-results/connected/`.

## Devices

| Alias | Manufacturer / model | Android | API | ABI | Build | Storage | Security patch |
|---|---|---|---|---|---|---|---|
| A | Xiaomi Mi A3 (`laurel_sprout`) | 11 | 30 | arm64-v8a | `user`, encrypted, SELinux enforcing | 720x1560 @ 320dpi | 2022-08-01 |
| B | Panasonic ELUGA I7 EE | 9 | 28 | arm64-v8a | `user`, encrypted, SELinux enforcing | 720x1440 @ 320dpi | 2021-04-05 |

Both were peer-connected over USB with debugging authorized; both reported `device`
(not `offline`/`unauthorized`) throughout.

## Results — parent app (Madalasa)

Suite: `:madalasa:connectedDebugAndroidTest` — `ParentScreenRegressionTest` (Theme C
child-selection copy) and `FreeV1InteractionTest` (premium preview ₹99/month · ₹999/year,
**Pay now → Coming Soon**, dismissal; explicit-child pairing selection).

| Device | Tests | Failures | Errors | Skipped | Gradle |
|---|---|---|---|---|---|
| A (API 30) | 3 | 0 | 0 | 0 | BUILD SUCCESSFUL, exit 0 |
| B (API 28) | 3 | 0 | 0 | 0 | BUILD SUCCESSFUL, exit 0 |

Both result files: `TEST-Mi A3 - 11-_madalasa-.xml`, `TEST-ELUGA_I7_EE - 9-_madalasa-.xml`.

## Results — child app (Alarka)

Suite: `:alarka:connectedDebugAndroidTest` — `DeviceOwnerLabOnlyTest`,
`DurableLabQueueInstrumentedTest` (real Android Keystore atomic restart + revoked queue),
`PermissionMatrixInstrumentedTest`.

| Device | Tests | Failures | Errors | Skipped | Gradle |
|---|---|---|---|---|---|
| A (API 30) | 7 | 0 | 0 | 0 | BUILD SUCCESSFUL, exit 0 |
| B (API 28) | 7 | **2** | 0 | 0 | BUILD FAILED, exit 1 — see defect DM-01 |

Passing tests on device A, named:

```
DeviceOwnerLabOnlyTest            appIsNotDeviceOwnerOnOrdinaryDevice
DeviceOwnerLabOnlyTest            classifierReportsStandardWhenPlatformHasNoOwnership
DurableLabQueueInstrumentedTest   realKeystoreAtomicRestartAndRevokedQueueSurvive
PermissionMatrixInstrumentedTest  unsupportedCapabilityNeverBypassesOnThisDevice
PermissionMatrixInstrumentedTest  postNotificationsDecisionMatchesActualOsAndGrant
PermissionMatrixInstrumentedTest  runningOsIsWithinSupportedRange
PermissionMatrixInstrumentedTest  scannedManifestAndGrantsCannotBypassPairingConsentOrLegalGate
```

The first two prove the child build is **not** a Device Owner on an ordinary phone — no
DPC power is claimed without genuine factory-reset provisioning.

## Defects found and resolved

### DM-01 — child app declared `minSdk = 28` while its own policy and roadmap set the floor at API 29

- **Observed on device B:** `runningOsIsWithinSupportedRange` →
  `java.lang.AssertionError: Device API 28 below supported minimum`
  (`PermissionMatrixInstrumentedTest.kt:36`), and
  `scannedManifestAndGrantsCannotBypassPairingConsentOrLegalGate` →
  `AssertionError` at line 78 (`assertTrue(report.osVersion >= 29)`).
- **Root cause:** three sources agree the child floor is Android 10 / API 29 —
  `PermissionMatrixEvaluator.SUPPORTED_MIN_API = 29`,
  `docs/roadmap/ANDROID_10_TO_16_FREE_RELEASE_COMPATIBILITY_2026-11-03.md` records
  `android/alarka/build.gradle.kts: minSdk=29` with status "Configured", and the mandatory
  exit criteria list tests for API 29..36 only — but the build file actually declared
  `minSdk = 28`. No source sanctioned API 28.
- **Fix:** `android/alarka/build.gradle.kts` → `minSdk = 29`. Not a threshold loosening;
  the instrumented test was left unchanged because it was right.
- **Verified after the fix:**
  - device A: `:alarka:connectedDebugAndroidTest` → 7/7, BUILD SUCCESSFUL, exit 0;
  - device B: install refused with
    `INSTALL_FAILED_OLDER_SDK: ... Requires newer sdk version #29 (current version is #28)`
    for both the app and the androidTest APK — the Android 9 handset is now correctly
    outside the supported range instead of silently receiving an unsupported build.
- **Consequence the owner must know:** handset B (Android 9) can no longer run the child
  app. Mixed API 29..36 child acceptance therefore needs a second Android 10+ device.

### DM-02 — instrumented tests failed on device B because the phone was locked (environment, not product)

- All three parent tests and the whole child suite initially failed on device B with
  `IllegalStateException: No compose hierarchies found in the app`.
- Logcat showed the Compose host activity reaching `RESUMED` then dropping
  `PAUSED → STOPPED → DESTROYED` within ~200 ms; `dumpsys window` reported
  `mDreamingLockscreen=true`, `isStatusBarKeyguard=true`, `mFocusedApp=null`.
- Wake + `wm dismiss-keyguard` made every test pass. Not an app defect. Both devices were
  kept awake with `svc power stayon true` for the runs and the setting was reverted after.

## Artifact identity (bytes actually under test)

| Artifact | Bytes | SHA-256 |
|---|---|---|
| `madalasa-debug.apk` (id `in.berhampore.madalasa.synthetic`, versionCode 2) | 30,763,469 | `e8080eed0629f31d0133357ab455955c3372aa13effcabf3d76cd9878af449b4` |
| `madalasa-debug-androidTest.apk` | 2,288,583 | `ce21f0d39f7fcf2395a9ad7f200dbda0ab2b212ee142494f85266abd1848ebdf` |
| `alarka-debug.apk` (id `in.berhampore.alarka`, minSdk 29, after DM-01) | 26,383,921 | `41bd106431a026794eb18e0b46dd89ead85f65da70204f69a03b2dfe96d3bb0e` |
| `alarka-debug-androidTest.apk` (after DM-01) | 1,309,541 | `7a8c0dd29d73201cd340474dcdb41fdd7d2b5ecceb8a278003945c4957068214` |

The parent debug build carries a deliberate `applicationIdSuffix = ".synthetic"` so the lab
build coexists with any production install; the child debug build keeps the production id.

## Explicitly NOT tested (no green pass claimed)

- API **29, 31, 32, 33, 34, 35, 36** — 7 of the 8 required levels. Only 30 and 28 were run.
- No emulator run and no representative-OEM breadth beyond these two handsets.
- API 28 is outside the supported range, so it is not acceptance coverage at all.
- No live HTTPS backend: `alarka_api_origin` / `madalasaApiOrigin` are empty, so enrollment,
  ingestion and guardian reads over TLS remain **NOT_RUN** here.
- Location collection is release-gated OFF (`alarka_location_release_approved=false`); no
  location, SOS, notification-delivery or revocation end-to-end test was performed.
- Accessibility (TalkBack, 200 % font, 320 dp), screenshot diffing and install/upgrade over
  an existing production install were not exercised.
- Backend/API was not involved; this record is device-side only.

**Reviewer:** not yet assigned (human sign-off outstanding).
