# Pingo comparison, device-capability discovery and optional hardware policy

**Decision update: 2026-11-04** | Free-first Alarka: Android 10–16 (API 29–36), 108 admitted child profiles, one active child device per child, all premium/remote media disabled until their independent approvals.

## 1. What Pingo by Findmykids actually demonstrates

**Publicly verified:** The published Google Play listing for [Pingo by Findmykids](https://play.google.com/store/apps/details?id=org.findmykids.child) (LETEM LTD, publicly updated September 9, 2026) describes a separate child-phone app paired by a code to a parent Findmykids app. The description openly names child location tracking, geofence notifications, a low-battery notification, family chat, restricted premium capabilities, microphones for child-initiated voice chat, and camera for avatar capture. The Play listing discloses location and other data collection. These are *features publicly advertised*, not evidence that every permission is currently granted on every device or country.

**Not verifiable publicly:** Pingo's Google Play Console **target-audience age selections, review decisions, permissions-declaration forms, any publisher-specific policy exception, and exact currently deployed split APK/manifest**. The displayed content rating **Everyone** is not the same thing as a Play Console target-audience declaration. A third-party APK analysis or Play availability is **not** proof of regulatory entitlement for Alarka.

**Applicable policy boundaries:** Google Play [Families requirements](https://support.google.com/googleplay/android-developer/answer/9893335) prohibit an app *solely targeting children* from requesting location permission or collecting, using and transmitting precise location. The [monitoring-app policy](https://support.google.com/googleplay/android-developer/answer/18265346) permits properly designated *parental* child monitoring under strict conditions: monitoring app designation, visible and ongoing notification with identifiable icon, no stealth, prominent disclosure and lawfulness. Those are separate tests; parental monitoring does not silently override Families restrictions. [Background location](https://support.google.com/googleplay/android-developer/answer/9799150) requires separately justified core purpose/appropriate approval when applicable.

**Do what is transferable:** separate parent Madalasa and free child Alarka; guardian-issued server pairing (QR-first eventually, 10-character fallback); user-visible setup, purpose-based OS permissions, device capability/status, account and child privacy controls; adaptive location only if permitted; battery status, optional family safety and no false monitoring claims.

**Do not copy:** presumed age-declaration settings, stealth recording, undisclosed audio/video recording, another publisher's unrelated permissions, inaccessible billing/profile, confidential policy approval, or children's location in a build prohibited by Families policy. Never classify a child-directed product as 18+ merely to work around restrictions. Obtain an authoritative written Play clarification for the exact parent-controlled companion targeting/ages and India child-data advice before enabling production location collection. Public Play submission remains NO-GO until compliant functionality and review evidence are complete.

## 2. Why only INTERNET in the public manifest?

The **public release manifest is intentionally minimally privileged until location/Families/India-law review**. `android.permission.INTERNET` enables HTTPS pairing/account service calls, not GPS, microphone, camera, sensor subscriptions or remote monitoring. Most Android motion/environmental sensors (accelerometer, gyroscope, proximity, light, barometer, magnetometer) are exposed by `SensorManager.getDefaultSensor(...)` and do **not** individually request runtime dangerous permissions. Listing optional `<uses-feature android:required="false">` flags **does not grant a permission**; it prevents Play from excluding devices without that hardware.

Sensitive capabilities require separate declarations and runtime/Settings decisions in an **approved build**:
- Location: `ACCESS_COARSE_LOCATION`/`ACCESS_FINE_LOCATION`, and `ACCESS_BACKGROUND_LOCATION` only if separately justified and approved; live visible FGS type/location permission as required by OS and its Play policy. The debug manifest contains location/FGS declarations for internal tests, the current public source manifest does not.
- Direct microphone recording: `RECORD_AUDIO` runtime permission; Android mic privacy indicator and background limits always apply. **Not declared/active in public free-first Alarka.** Incidental ambient audio is not a reliable emergency detector and should never activate covertly.
- Direct camera capture: `CAMERA` runtime permission and explicit child-visible flow; Android camera indicator and financial-app capture restrictions apply. **Not declared/active in public free-first Alarka.** Camera/media picker variants can avoid camera permission for some user-initiated interactions; they still require scope review.
- Steps/activity recognition: `ACTIVITY_RECOGNITION` on API 29–36 if step counters/detectors are actually used; not required for ordinary accelerometer+gyroscope presence checks. High sensor sampling rates are restricted by Android; avoid `HIGH_SAMPLING_RATE_SENSORS` unless independently justified.
- Battery: read-only `ACTION_BATTERY_CHANGED`, `BatteryManager` percentage/state and `PowerManager` battery saver: normally no dangerous runtime permission.
- GNSS/NavIC: Android `LocationManager` reveals GPS/network-provider presence and enabled state. NavIC = IRNSS constellation ID in `GnssStatus`; a GPS chip **cannot prove NavIC support**. Constellations can be reported only after *permissioned, explicitly authorized real satellite observation*. When no authorized observation occurred, display **UNKNOWN/NOT OBSERVED**, not "supported" or "unsupported". Coarse/network location can be a separate degraded approved mode; never fabricate precision or freshness.

## 3. Implemented module-inventory and non-bypass rules

| Module | Hardware discovery | OS/purpose permission | If absent or unavailable |
|---|---|---|---|
| Accelerometer | `Sensor.TYPE_ACCELEROMETER` | Sensor presence needs no dangerous runtime grant | Motion-based fall **candidate** disabled; manual SOS remains possible |
| Gyroscope, rotation/gravity/linear acceleration | SensorManager default sensors | No dedicated grant for basic reads; rate/background rules apply | Use accelerometer-only *candidate* analysis if separately validated, otherwise disable |
| Proximity and ambient light | SensorManager default sensors | Normally no dedicated dangerous runtime grant | Disable their context input; do not disable location or pairing |
| Barometer, magnetometer | SensorManager default sensors | Normally no dedicated grant | Do not claim altitude/heading assistance |
| Step detector/counter, significant motion | SensorManager | ACTIVITY_RECOGNITION where applicable; Android power/OS constraints | Fall feature cannot rely on step hardware being present |
| GPS and network positioning | PackageManager and LocationManager | Location runtime/FGS policy when reading actual positions | Use only available permitted provider; if neither, show unavailable |
| GPS/Galileo/GLONASS/BeiDou/QZSS/NavIC | GNSS constellation callback **only after authorization** | Fine location/OS limits and legal consent | Unobserved = **unknown**, not hardware absent |
| Battery, charging, saver, low battery | Sticky ACTION_BATTERY_CHANGED, BatteryManager, PowerManager | No dangerous permission for status read | Report unknown/unavailable; no fabricated % |
| Microphone / camera | PackageManager features | Separate REVIEW + `RECORD_AUDIO`/`CAMERA`, visible consent, OS indicators | Omit feature entirely, keep free basic app working |
| Manual SOS | UI action; no special sensor | Paired/admitted/consented service and communication availability | Manual entry does not depend on movement/camera/mic |

**Code (on `child` work branch):** `DeviceHardwareInventory.kt` defines sensor list, battery/GNSS states and per-module decisions; `AndroidDeviceCapabilityScanner.kt` reads hardware, OS grant, package manifest and battery status **without starting a sensor listener or uploading data**; `DeviceCapabilityReport.hardware` is optional/backward-compatible; `PermissionsScreen.kt` displays the available/missing/unknown module inventory; `OptionalHardwareModulePolicyTest.kt` tests synthetic missing-hardware fallback across API 29–36.

The six-hour free location-history visibility, 108 child-server admission, one-active-Alarka device uniqueness, guardian consent and default-off premium gates are unchanged. Hardware scan is safe to view pre-pairing; collecting/transmitting child monitoring data is **not**.

### SOS/fall-detection constraints

A phone accelerometer may show drops, jumps, sports motion or an unattended phone falling. **An accelerometer spike alone never proves a child suffered an injury.** The motion detection pipeline, if independently approved and validated, may generate an uncertain *candidate*, then use available motion/context modules and user confirmation or human escalation; it must show false-positive handling and not automatically dial an emergency number from unsupported evidence. Missing a gyroscope or proximity sensor must only disable their respective optional signal. Record module capability/status rather than unsupported diagnoses.

Mic/camera may provide user-initiated communication after separate safeguards; they are **not** silently activated for fall detection, neither can they bypass privacy indicators, and their permissions are not requested in the current free release.

## 4. Updated editable Figma screens

Page **ALARKA • HARDWARE COMPATIBILITY • API29–36**:

- [Child: Check this phone](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=179-3): example motion/environment inventory, battery, optional hardware.
- [Child: Location capability](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=179-42): GPS/network + unknown NavIC/IRNSS, no unapproved observation.
- [Child: SOS capability fallback](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=179-75): missing gyroscope fallback, manual SOS independent, safe candidate escalation.
- [Child: Sensitive module access](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=179-104): camera/mic detected but undeclared and disabled for free release.

These editable frames are **design examples**, not screenshots taken from a live phone, and their buttons should not be interpreted as working actions.

## 5. Next engineering and publication gates

1. Green Android/JVM tests for the new hardware scanner, optional-module decisions and all eight OS API versions; run instrumented tests on representative real Android/OEM hardware including absent GPS/gyro/light and optional network-provider fallback.
2. Validate optional diagnostic read failures, batteryless devices, approximate-only permission, denied MIC/CAMERA, no sensor permission and no hardware filtering by merged AAB manifest. Confirm no child personal data is uploaded by the scan.
3. Complete and validate the actual *visible* production location FGS, secure ingestion, server admission/consent/revocation and physical GPS/Android restrictions only **after** legal/Play target-audience clearance. GNSS constellation proof requires a separately authorized observer, not a guess from GPS presence.
4. Independently design, review, and validate manual SOS and any algorithmic motion fall detection; document false positives and user-visible alerts. Remote audio/video features stay deferred and disabled.
5. Green merged PRs/production signing, family/privacy review, accurate Play Data Safety, 108-child load and actual Play approval before claiming deployable free location monitoring.

**Release verdict:** Child hardware discovery can progress without BillDesk and without collecting a child's location, but a publicly installable no-location setup app is not the same thing as the promised, operational free tracking release.

## Source documents

- Pingo listing: https://play.google.com/store/apps/details?id=org.findmykids.child
- Google Families: https://support.google.com/googleplay/android-developer/answer/9893335
- Play monitoring: https://support.google.com/googleplay/android-developer/answer/18265346
- Play background location: https://support.google.com/googleplay/android-developer/answer/9799150
- Android sensors: https://developer.android.com/develop/sensors-and-location/sensors/sensors_overview
- Android GNSS/NavIC IRNSS: https://developer.android.com/reference/android/location/GnssStatus
- Android battery: https://developer.android.com/reference/android/os/BatteryManager
