# Madalasa–Alarka — Adaptive Android Runtime, Movement Algorithms and Quality Test Contract

> **Document control:** M2 / 01-location-collection-and-ingestion · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (parent), **Alarka** (child); verified [Madalasa-Alarka GitHub repository](https://github.com/methakon/Madalasa-Alarka). [Brand contract](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Version:** 1.0 | **Date:** 2026-10-25 | **Status:** Testable design; NOT proven on real devices
**Covers:** FR-002–005, FR-015–021, FR-024, FR-028, FR-030–033, FR-036, FR-038, FR-042–043 and NFR-001/006/011.

## 1. Distinguish location sources and claims

- Observation: actual child device fix, observed timestamp, Android-reported accuracy, source device/provider, optional bearing/speed.
- Raw track: valid sequential observations; NOT proof of road actually followed between them.
- Derived trip and stop: algorithmic inference, carrying version, status and contributing observation window.
- Route matched geometry: optional third-party inference from dense eligible observations only, subject to Google Roads commercial tracking/retention policies.
- Child location means enrolled **device** location. A phone left at home does not prove child is home.
- Nothing labeled LIVE unless observation freshness and reasonable accuracy meet **configured** product thresholds; show “last known” otherwise.

## 2. Android runtime and permission states

Kotlin owns Android APIs; C++ NDK assists with event/queue validation and shared domain logic, while C++ server does all complex route inference.

### 2.1 Lifecycle matrix (candidate supported behavior, not guaranteed)

| Situation | Safe implementation response | Expected degradation | Test ID |
|---|---|---|---|
| Setup Activity visible; parent grants precise location | Configure location collector under eligible lifecycle; clear disclosure | If denied, permission-required | AND-01 |
| Setup Activity closed after compliant location FGS already started | Continue permitted tracking with persistent monitoring notification and correct service type | OS may throttle and user may stop service | AND-02 |
| App in background trying to start location FGS anew | Check API/version, permission, start exemptions and current foreground access; catch OS exceptions | FGS_START_REJECTED or USER_ACTION_REQUIRED | AND-03 |
| Android 14+ while-in-use permission check | Having runtime grant does NOT necessarily permit background service creation | SecurityException / OS_REJECTED | AND-04 |
| ACCESS_BACKGROUND_LOCATION granted | May allow continued background location according to service rules; not universal service-start waiver | Limited frequency/power | AND-05 |
| Screen off / Doze / Battery Saver | Request sparse low-power eligible updates, batch to local queue | Increased observation age | AND-06 |
| Reboot with documented broadcast entry | Re-register only in allowed lifecycle and start context; do not evade restrictions | App may require parent/user action | AND-07 |
| User force-stops app | No bypass/relaunch guarantee; on next allowed interaction restore status | Last known/stale | AND-08 |
| Parent revokes location or child disables GPS | Stop applicable collector, update locally and report on next connection | UNAVAILABLE/PERMISSION_REQUIRED | AND-09 |
| Poor signal / Wi-Fi only tablet | Accept coarse/uncertain data, do not compute exact route | APPROXIMATE/UNKNOWN | AND-10 |
| Wear OS connected to phone | Tag location source or provenance where available; don't assume standalone GNSS | Companion dependence and stale source | AND-11 |
| OS location source/mock anomalies | Flag suspicious observations and uncertainty, do not silently overclaim | SUSPECT/UNKNOWN | AND-12 |

Android project chooses supported minSdk after test-device selection; standard Play new app target >= API36 as of October 2026, Wear separate target requirements. Location FGS requires proper manifest type and permissions. The monitoring notification/identifiable app identity remains mandatory for Play-compliant running monitoring apps. Do not use accessibility overlays or high-priority push solely to bypass FGS start rules.

### 2.2 Decision function

Input: active_grants, apiLevel, appLifecycle, fgsState, managementMode, userLocationEnabled, batteryState, supportedProvider, childPreference.

Output: COLLECTING_BALANCED, COLLECTING_DETAIL_LIMITED, COLLECTING_PASSIVE, WAITING_FOR_ELIGIBLE_START, PERMISSION_REQUIRED, DISABLED, OS_REJECTED or UNKNOWN.

Service starting **must not be inferred from checkSelfPermission alone**. Track actual service/callback delivery and caught SecurityException or ForegroundServiceStartNotAllowedException. Persist last status and expose observed timestamp, not a speculative current OS cause when device has not connected.

> **Seven-day parent-app inactivity overlay (2026-11-01):** Routine location request rates must also follow the configurable FREE/PAID active/inactive family engagement profiles in [PARENT_APP_INACTIVITY_ADAPTIVE_LOCATION_POLICY_2026-11-01.md](PARENT_APP_INACTIVITY_ADAPTIVE_LOCATION_POLICY_2026-11-01.md). At 168h without verified guardian foreground engagement, free routine moving requests target 20min and paid 5min; stationary targets 60min free and 20min paid. Stronger safety, OS, consent and revocation requirements always take precedence. This is an unimplemented design, not a guaranteed fix rate.\n\n## 3. Adaptive sampling strategy and energy budgets

Location energy is primarily GNSS, sensor/radio wakeups and upload network activity, not whether the algorithm is written in C++.

### Initial test profiles (not production promises)

| Mode | Requested interval | Distance floor | Batch/upload | Constraint |
|---|---|---|---|---|
| Still/passive | opportunistic / 5–15 minutes | 100–250 m | 15–30 minutes | Display route coverage as sparse |
| Walking | 30–90 seconds | 30–75 m | 1–5 minutes | Balanced location |
| Cycling | 15–45 seconds | 40–100 m | 1–3 minutes | Avoid permanent high-accuracy |
| Car balanced | 30–60 seconds | 100–250 m | 1–3 minutes | Too sparse to promise exact street |
| Car detail | speed-adaptive 5–15 seconds | 30–150 m | 30–90 seconds | Explicit limited window only |
| Wear stationary | passive / 10–20 minutes | 150–300 m | 15–30 minutes | Watch model capacity-dependent |
| Wear moving | 1–5 minutes | 75–250 m | 3–10 minutes | Coarse route, not street-snapped |
| Battery-constrained | step down from current profile | dynamic | deferrable | No claim of fresh GPS at exact interval |

Use FusedLocationProvider LocationRequest.Builder setIntervalMillis, setMinUpdateIntervalMillis, setMinUpdateDistanceMeters and setMaxUpdateDelayMillis where supported. Use Activity Recognition Transition events only if user-authorized and supported, as evidence hints. Do not restart the location listener for every noisy speed reading. Apply ~60–120s minimum mode residence as an initial test value.

**Detail mode equation candidate:** if road observation separation budget is approximately 200 m, choose requested interval_sec = clamp(5, 15, 200/max(last_reliable_speed_mps,1)), with no guaranteed actual fix delivery. Expire detail mode after an approved duration; automatically downgrade on low battery/thermal events or OS denial.

## 4. Data quality classification

All thresholds below are **initial candidates requiring real-device validation**, not scientific confidence guarantees.

| Signal | Initial threshold | Classification |
|---|---|---|
| Accuracy <= 50 m, recent and consecutive fixes | Eligible for detail analysis; still inspect multipath | TRUSTED_CANDIDATE |
| Accuracy 50–150 m | Coarse history, do not assert fine street path | APPROXIMATE |
| Accuracy >150 m | Weak evidence | LOW_CONFIDENCE |
| Missing observed timestamps or invalid lat/lon/NaN | Invalid | INVALID |
| Long time gap or large displacement beyond evidence | Unknown segment | GAP |
| Implied jump that contradicts accuracy and feasible movement | Flag | SUSPECT; keep raw protected record |
| Device heartbeat current but GPS observation old | Not live | STALE_LOCATION |
| No heartbeat since threshold and state unknown | Not proof of permission revoked | DEVICE_STALE_CAUSE_UNKNOWN |

Do not call quality value a “98% probability” without calibrated model and labeled test evidence. Accuracy estimates are provider-reported horizontal uncertainty, not a deterministic bound. Reject extreme malformed coordinates but do not discard valid train/air travel with simplistic 150 km/h maximum.

## 5. C++ reconstruction algorithm contract

Process a **single device's** observations in observed-time order, within a versioned window and held lease fence. Steps:

1. Validate/dedupe; sort stable by observed_at and event_id, detect significant device clock skew and monotonic-time discontinuity.
2. Quality filter emits classification and reason codes for each fix without erasing trusted raw source.
3. Motion inference uses displacement relative to combined accuracy, speed confidence, Activity Recognition hint and time with hysteresis. Confidence class only, travel mode UNKNOWN allowed.
4. Candidate trip begins after >=2 credible moving samples or equivalent repeated evidence away from prior dwell center. A lone fix jump never starts an irreversible trip.
5. Candidate dwell cluster starts around a robust centroid of 2+ quality samples. Use adaptive radius base 50–100 m, enlarged for uncertainty. Support count and duration both required.
6. Confirm stop after **minimum 3 trustworthy samples spanning >= 3–5 min (walking)** or **>=5–10 min (vehicle)** as provisional tuning; a 30–60s red light must not count. If stationary sampling 15min yields insufficient points, output POSSIBLE_STOP or UNKNOWN; **never infer precise 5min dwell from no observations**.
7. Confirm stop exit only after >=2 credible fixes beyond radius+margin and supported motion. Report bounded estimated arrival/departure times, not invented exact minute.
8. Identify trip as legs between stops; split observed geometry at gaps. Mark END_UNKNOWN if signal vanished.
9. Match stop centroid to parent named places via PostGIS ST_DWithin within approved radius/accuracy. If multiple overlap, AMBIGUOUS; passing by is not VISITED.
10. Materialize versioned trip/leg/segment/stop projection and quality reasons. Late events revise affected window with reason LATE_DATA; no false retroactive “live” claims.
11. Parent map draws observed segments, stop markers and explicit gaps; optional Google Roads matching only for eligible dense car segments and provider license/cost/retention rules.

### Pseudocode (algorithm abstraction, not compilable C++)

~~~text
process(device, observations, config_version, watermark):
    assert current_device_lease_fence(device)
    sorted = stable_sort_dedup(observations, event_time)
    qualified = quality_filter(sorted, config)
    movement = infer_motion(qualified, prior_state, hysteresis)
    dwell = cluster_stays(qualified, movement, min_samples=3,
                          radius=max(base_radius, accuracy_envelope),
                          required_time=by_mode)
    stops = confirm_stops(dwell, exit_hysteresis, confidence_rules)
    trips = derive_legs(movement, stops, split_at_unknown_gaps)
    matches = named_place_candidates(stops, tenant_scoped_ST_DWithin)
    validate_lease_fence_again()
    commit_revision_atomically(trips, stops, matches, algorithm_version)
~~~

Incremental work can be O(n) or O(n log n) for one time-sorted window plus spatial indexed queries; **actual computational cost depends on reprocessing windows, cache, DB indexes and real traces**. Never claim “constant-memory” if windows can grow without bounds.

## 6. Trip, stop and commute status vocabulary

| Object | Allowed display status | User-visible meaning |
|---|---|---|
| Location | RECENT, STALE, APPROXIMATE, UNAVAILABLE, UNKNOWN | Recency and confidence, independent of server connection |
| Track segment | OBSERVED, APPROXIMATE, GAP | Known observations vs uncertainty vs missing data |
| Trip | PROVISIONAL, CONFIRMED, UPDATED, INCOMPLETE | Evidence/version not necessarily finalized |
| Stop | CANDIDATE, CONFIRMED, AMBIGUOUS, REJECTED | Inferred dwell, not automatically named arrival |
| Named place | NEAR, PASSED_NEAR, CONFIRMED_DWELL, UNKNOWN | Near is not visited |
| Commute | ARRIVED_CONFIRMED, ARRIVAL_NOT_CONFIRMED, DEVICE_UNAVAILABLE, DELAY_POSSIBLE, UNKNOWN | Never transform silence into confirmed danger |
| Source | PHONE, TABLET, WATCH, COMPANION_SOURCE, UNKNOWN | Physical child possession not established |

## 7. Measured field-test metrics and gates

- **Fix freshness:** interval between wall-clock parent request time and most recent device-observed fix; report p50/p95 by OS/OEM, motion and network state.
- **Observed track coverage:** percentage of a planned monitoring period for which adjacent usable fixes remain within configured age/accuracy/time-gap bounds. Publish formula and UNKNOWN intervals; not simply “device online percentage.”
- **Battery incremental drain:** (tracked device drain minus identical baseline without tracking) percent battery capacity per 24 hours, stationary and moving, with screen/network conditions matched. Also record GNSS duration where measurable, CPU/PSS, cellular data and wakelock count.
- **Stop precision:** TP/(TP+FP), **recall:** TP/(TP+FN), with field-labeled visits and unknown class tracked separately; thresholds fixed before release signoff, not retrospectively tailored to test data.
- **Commute:** false missed-arrival alert rate and notification delay from observed events, distinguish GPS unavailable scenarios.
- **Cross-source:** phone/watch handoff mistakes, unpaired watch offline cases and mixed-device location confusion.

Device matrix should include API29–36 where genuinely supported; Pixel + selected OEMs; stationary, school commute, urban canyon, tunnel/offline, incorrect wall clock, screen-off and battery saver. Use synthetic/no-personal-data datasets for CI; real volunteer tests need explicit consent and protected recordings.

## 8. Android release eligibility and Play references

- Android background FGS restriction: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- FGS location type/prerequisites: https://developer.android.com/about/versions/14/changes/fgs-types-required
- Battery recommendation: https://developer.android.com/develop/sensors-and-location/location/battery
- Activity recognition: https://developer.android.com/develop/sensors-and-location/location/transitions
- Geofence limit and delay: https://developer.android.com/develop/sensors-and-location/location/geofencing
- Wear location: https://developer.android.com/training/wearables/apps/location-detection
- Roads Snap to Roads: https://developers.google.com/maps/documentation/roads/snap

**Status:** Algorithm settings are versioned, testable hypotheses. No Android hardware test, labeled journey trial or battery improvement measurement has yet been completed.

## 2026-10-27 feature-readiness and permission state runtime refresh

Alarka initial scan and per-feature permission verification are specified in [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md). A runtime LOCATION capability has independent `hardware_support`, `foreground_permission`, `background_permission`, `precise_vs_approximate`, `location_services`, `os_foreground_service_eligibility`, `release_policy_gate` and `last_verified` signals. No single permission bit guarantees location success or continuous background fixes. On `onResume`, relevant Android grant result and permitted tracking service start, re-evaluate actual OS state; stop/restrict tracking if necessary, maintain truthful stale/provisional status and emit new authenticated version to server when possible. Revocation may terminate the app process, so Madalasa must preserve last reported time and UNKNOWN/OFFLINE until a new device proof arrives; no invented live GPS or silent regrant. Android 11+ foreground and background location prompts are separate; all minor-data policy gates remain in place.

## 2026-10-27 agreed independent GPS collection vs upload and offline durability contract

[MA-INGEST-ADR-004](POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) separates **location-fix acquisition (Android location provider callback)** from **encrypted local observation persistence**, **HTTP upload target (1–2 minutes when allowed)** and **C++ server-side durable queue + bulk database insertion**. This replaces any interpretation of the existing `Batch/upload` column as the *GPS sample interval*: collection adapts to meaningful movement, reported fix age, GPS accuracy and battery, while networking can coalesce multiple fixes. During substantial vehicle movement a higher-detail 10–30 sec **candidate** sample interval may be tested where OS permits to preserve turns; car-balanced 30–60 sec remains a battery profile. Live Tracking is separately authorized and time-limited; it may generate many more than the old **300 GPS points/child/day** financial scenario (not a daily limit).

Alarka uses actual encrypted local SQLite/envelope storage; retain a **48h offline capacity target** of original event IDs + UTC observed timestamps, with explicit quota/overflow warning and delayed replay after connectivity returns. No guarantee if powered off, force-stopped, GPS denied or OS restricted. WorkManager periodic has 15-min minimum; do not claim a background app can always run a 1–2 min timer. A valid already-running location service may attempt an upload every 1–2 minutes without leaving Alarka's Activity open, subject to Android/Play and visible notification. On connection loss, backoff and jitter without re-labeling old points as current location. Late GPS flows through C++ inbox and bulk worker, then event-time trip revision/known gaps. Parent map shows separate last observed/received/processed timestamps and source device, not an invented precise path. T-ING-01…24 hardware and recovery tests pending.
