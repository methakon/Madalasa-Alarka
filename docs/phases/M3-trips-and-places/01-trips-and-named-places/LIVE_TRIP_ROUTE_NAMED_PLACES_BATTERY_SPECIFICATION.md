# Live Trip Tracking, Road Route Reconstruction, Named Places and Battery Optimization

> **Document control:** M3 / 01-trips-and-named-places · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product naming:** **Madalasa** parent/guardian app, **Alarka** child companion; GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka). [Brand and Markandeya Purana context](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Project:** Madalasa–Alarka  
**Revision:** 1.0 (design specification)  
**Date:** 2026-10-25  
**Status:** Proposed implementation; NOT device-tested or Play-approved  
**Related:** [SRS](../../M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md), [Full Implementation Specification](../../M1-secure-platform-foundation/01-requirements-and-architecture/IMPLEMENTATION_TECHNICAL_SPECIFICATION.md), [Android Compatibility Matrix](../../M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md), [Play Requirements](../../M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md).

## 1. Product requirements and precise terminology

The parent must be able to mark any location on Google Maps and assign a human-readable title, such as "Home", "School", "Grandparents", "Tuition Centre" or "Bus Stop". During location viewing, the parent can see these custom places, the tracked child's latest position, and contextual proximity to the saved places.

When a tracked device moves, the parent must see the **observed travelled path**, not a route invented by a directions service. History should contain separate trips with departure, arrival, optional inferred travel mode, intermediate stops, duration, approximate distance and data-quality indicators. At each stop, show observed arrival/departure windows. A nearby known place is not proof the child visited it.

**Distinguish three data concepts:**
- **Raw observation:** timestamped position measured by Android, with horizontal accuracy and source metadata.
- **Observed track:** connected sequences of reliable, temporally continuous raw observations.
- **Road-matched track:** optional representation projected onto plausible road geometry where sufficiently dense observations and provider terms permit it. It is an inference, never ground truth.

The Maps SDK can render saved locations as markers and the observed/processed track as polylines. Roads API snap-to-roads is a separate paid service and has additional restrictions.

### Scope and status

A parent can open the map without causing the child device to acquire a new GPS fix merely to render custom markers. Optional "update location" requests are subject to the child's existing permission/service state and must return honest statuses.

This design is for **transparent, parent-authorized supervision**; the child app retains an identifiable on-device presence and required Android monitoring notifications. It does not circumvent Android's location controls or promise a completely invisible tracking service.

## 2. Architecture and placement of work

    Child phone/tablet/Wear OS
      Kotlin location adapter (FLP/LocationManager)
      Activity Recognition Transition API if supported
      geofence receiver for selected places if enabled
      motion-adaptive tracking state machine
      encrypted SQLite event queue + deduplication
      minimal C++ native event/validation/serialization library
                   |
          authenticated, batched HTTPS
                   v
    C++ Drogon backend
      location ingestion / validations / event dedupe
      movement, stop, and trip segmentation workers
      known-place matching / arrival/departure events
      optional, quota-limited road map matching adapter
      Postgres + optional PostGIS for spatial queries
                   |
       parent HTTPS API + optional SSE updates
                   v
    Kotlin/Compose parent app + Google Maps SDK
      latest position + timestamp/accuracy
      labeled parent-defined place markers
      raw travel polyline, segmented gaps, stop markers
      trip timeline and playback

The **child device should not render maps, look up street addresses, snap roads, reverse geocode every fix, or run complex geospatial SQL**. Those are parent/server jobs, not continuous mobile tasks.

## 3. Parent-defined named places / addresses

### 3.1 Creation and editing

1. Parent taps and holds on the map (latitude/longitude) or searches for an address via an optional Places Autocomplete interface.
2. Show a movable marker, editable **title**, optional address description, icon/category, optional radius and whether arrival/departure alerts are enabled.
3. Save the parent-specified coordinates/title immediately; a text address or optional Google Place ID may be included, respecting Maps Platform terms.
4. Show a confirmation preview, then persist under the authenticated parent/child relationship.
5. Allow rename, move, delete, reorder, icon selection and archive. Authorization always checks parent ownership.

When typing an address use a **parent-side** Places SDK, not a child's background geocoding request. A drag/tap pin should work without Places billing. Prefer a small Places Details field mask and session-token usage if the optional search UX is enabled.

### 3.2 Display while tracking

- Draw parent places as distinctive, labeled markers/advanced markers with title and optional small geofence-radius circle.
- Draw the child location as a different marker, with observation age, accuracy halo, optional heading and speed.
- On zoomed-in view, prioritize titles for places within viewport; when many markers overlap, cluster or collapse labels and show full title on tap.
- Display **nearby named places** relative to the most recent observation, sorted by geodesic distance. Distances should be labelled approximate, especially when reported accuracy is coarse.
- Parent can select all places, a named-place category, or a child-specific subset.
- Parent places are server/parent UI data; **no additional child GPS requests are necessary to keep their icons visible**.

### 3.3 Saved-place matching vs geofence notifications

Use backend distance checks to annotate already-collected tracks with "near School" or "inside Home radius" at no additional child sensor cost. If the parent explicitly enables near-real-time enter/exit alerts, optionally register a **small, selected subset** on Android GeofencingClient after appropriate permission. Android's limit is **100 active geofences per app/user**, and delivery may be delayed by minutes. Default geofence responsiveness approximately 5 minutes or greater when alerts are not urgent; do not promise instant door-crossing notifications.

Use hysteresis: arrival when confidently inside radius for multiple observations/dwell, departure only after observations sufficiently outside, considering reported accuracy. A 100 m pin radius does **not** mean a 100 m-accurate position.

## 4. Child location collection and battery management

### 4.1 Energy principle

GPS/GNSS, CPU wakeups, cellular radio wakeups and frequent high-accuracy requests cost energy. C++ alone does not make location cheap. Favor **motion changes → adaptive sampling → batching → backend computation**. Request quality/interval/distance are hints rather than strict guarantees.

Use Android's FusedLocationProviderClient LocationRequest.Builder when Play services is available, or a tested LocationManager adapter where appropriate:
- PRIORITY_PASSIVE or low power for opportunistic fixes when stationary where supported.
- PRIORITY_BALANCED_POWER_ACCURACY for ordinary background movement and noncritical history.
- PRIORITY_HIGH_ACCURACY only during time-bounded, explicit higher-detail travel conditions.
- setIntervalMillis, setMinUpdateIntervalMillis, setMinUpdateDistanceMeters and setMaxUpdateDelayMillis with test-backed profiles.
- WorkManager for deferred upload; **not as a substitute** for compliant location foreground-service lifecycle when timely ongoing updates require it.
- The Android Activity Recognition Transition API (ACTIVITY_RECOGNITION permission as applicable) can help select STILL/WALKING/RUNNING/IN_VEHICLE modes without continuous high-frequency sensor polling. Do not trust it as exact proof of travel mode or an instant traffic-stop detector.

### 4.2 Proposed initial profiles — tuning candidates, NOT measured defaults

| Device and state | Requested position interval | Distance threshold | Maximum local batching/upload window | Notes |
|---|---|---|---|---|
| Phone/tablet stationary | 5–15 min or passive/geofence-driven | 100–250 m | 15–30 min | Reduce GNSS work; occasional heartbeat and avoid inventing fresh data |
| Phone walking | 30–90 s | 30–75 m | 1–5 min | Balanced accuracy for approximate walking path |
| Phone cycling | 15–45 s | 50–100 m | 1–3 min | Adaptive on actual speed and curvature |
| Phone in vehicle (battery saver) | 30–60 s | 100–250 m | 1–3 min | **May be too sparse for reliable road matching** |
| Phone moving (route detail) | Speed-dependent target 5–15 s | 30–150 m | 30–90 s | Short periods only; higher GPS/battery cost |
| Phone temporary parent viewing | 15–60 s, if Android permits | 30–100 m | 15–60 s | Short-lived explicit mode, reverts automatically |
| Wear OS stationary | 10–20 min or event-driven | 150–300 m | 15–30 min | Avoid sustained on-watch GNSS |
| Wear OS walking/journey | 1–5 min | 75–250 m | 3–10 min | Favor low-power history, not high-detail road traces |

These are **requested targets**, not guaranteed scheduling, sampling, freshness SLAs or battery measurements. A device with coarse-only location may yield much worse accuracy. Android restricts background location retrieval; a real-time profile needs a compliant foreground service and may still be unavailable due to OS limits. Never claim fixed battery savings without controlled device tests.

### 4.3 Speed-aware route-detail policy

For a high-fidelity vehicle route, consecutive observed points should ideally be **under about 300 m apart** when later using Google's Roads API. A tentative adaptive upper interval is:

    desired_interval_s = clamp(5, 15, 200 / max(speed_mps, 1))

where speed is obtained from a sufficiently reliable recent fix; fallback conservatively if absent. At 25 m/s, this suggests approximately 8 seconds rather than a fixed 60-second update. The **200 m budget** leaves margin for GPS uncertainty and turns.

This detail mode uses significantly more battery. It must not run indefinitely in the default battery-saver profile. Apply a time/energy budget, automatically revert after trip end or a configured window, and show the parent whether the history is **recorded low-power** or **high-detail**. If battery saver/thermal pressure/low battery occurs, step down the request quality and communicate reduced fidelity.

### 4.4 Motion state machine (illustrative)

    UNKNOWN -> STILL_CANDIDATE -> STILL
        |             ^
        v             |
    MOVING_WALK / MOVING_CYCLE / MOVING_VEHICLE
        |
    POSSIBLE_STOP -> CONFIRMED_STOP -> MOVING_...

Use Activity Transition events plus valid location displacement, clock times and confidence. A vehicle waiting at a red signal is **not** a stop if it lasts only seconds. Require multi-minute dwell and enough spatial evidence to mark a meaningful visit. Limit frequent mode switching with cooldown/hysteresis (e.g., 60–120 seconds).

### 4.5 Offline handling, reboot and permission revocation

- Record locally to bounded encrypted queue with UUID, wall-clock observation time, monotonic elapsedRealtime ordering hint, source device ID, accuracy and provider.
- Batch/compress HTTP uploads; use unique IDs to deduplicate. Batched FLP locations can be out of order across batches: reorder by observation timestamp and tolerate late arrivals on server.
- Network and power conditions decide upload cadence; avoid one radio wake per GPS point.
- Re-register allowed listeners after reboot only through supported receivers/lifecycle rules; do not attempt to defeat user force-stop or Android restrictions.
- If location/notification permission is denied or revoked, disable applicable collection, report degraded capability and keep map last-observed with prominent "last seen" information.

## 5. Trip and stop detection — server-side C++

### 5.1 Ingest and quality filter

For each event:
1. Validate authentication, paired device ID, event ID, latitude [-90,90], longitude [-180,180], timestamp and accuracy.
2. Store raw events separately from derived trips. Keep legitimate raw events for audit/diagnostics under retention.
3. Deduplicate and reorder within an event-time lateness window. Recompute affected recent trips when offline batches arrive late.
4. Exclude from **derived route** only as justified: stale/out-of-order duplicates, implausible jumps relative to accuracy/time, major horizontal inaccuracy, broken provider records.
5. Mark excluded points and gaps rather than silently filling or using them to infer kilometres travelled.

Illustrative filters (tune by field validation): horizontal accuracy better than 50–100 m for high-detail road matching; up to 100–200 m may be used as approximate coarse track if marked so. Speed/distance anomaly checks must consider trains, poor fixes and time gaps; a single hard maximum speed can incorrectly discard valid travel.

### 5.2 Trip detection

- Begin **trip candidate** on reliable movement beyond an adaptive displacement threshold (e.g., more than 100 m over a suitable interval) and/or motion transitions.
- Confirm a trip after repeated movement evidence, not a lone GPS bounce.
- Define departure at the earliest credible movement after preceding dwell.
- End a trip after sustained stationary dwell or long inactivity/data gap, recording ambiguity rather than guessing.
- Keep distinct legs for movement and breaks; trips may span several confirmed stops.
- If the device disappears during travel, close the observed segment at the last real point and label the next point as **new segment after data gap**.

### 5.3 Stop clustering / dwell detection

Proposed online spatial-temporal dwell approach:
- Keep a small rolling **candidate-stop cluster** with valid fixes, accuracy-weighted centroid and enter time.
- Eligible when fixes remain near centroid inside adaptive radius: provisional base radius 50–100 m, increased when horizontal accuracy demands it.
- Confirm stop when dwell exceeds approximately **3–5 minutes** for walking/cycling, and typically **5–10 minutes** for vehicle mode to avoid signals/queues; both tunable.
- Confirm exit with consecutive reliable observations outside exit radius and motion evidence (hysteresis prevents GPS jitter flicker).
- Persist start/end, dwell duration, centroid, confidence and supporting observations. Label unknown location if no saved place matches.
- A "bus stop" or brief roadside pause shorter than dwell threshold may be represented as **brief pause** only if accuracy supports it, not a confirmed visited address.

Accuracy guard: if accuracy radius exceeds candidate radius and locations could lie on either side, classify `UNCERTAIN` and avoid confident arrival/exit statements.

### 5.4 Known-place attribution

For a confirmed stop, check proximity to the parent-defined place coordinate using a geodesic formula/PostGIS ST_DWithin with radius adjusted to reported location accuracy and confidence. If multiple places overlap, return candidates, not an arbitrary certain answer. Record:
- `stop_id`, `matched_place_id` (nullable), `distance_to_place_m`, `confidence`, `arrived_at`, `departed_at`, `dwell_seconds`.
- Example UI: "Stopped near Tuition Centre · approximately 6 min · location accuracy ±45 m".
- Passing close to School without a dwell remains "Passed near School", not "Visited School".

## 6. Drawing the travelled road on Google Maps

### 6.1 Default: truthful raw observed track

- Server returns chronological segments, separated at long gaps and invalid jumps.
- Parent app renders **Google Maps SDK polylines** per segment. Use a solid line for reliable observed paths, dashed/dotted for uncertain short interpolations (if UI chooses to show them), and break for unknown/missing spans.
- Do not draw one straight line across kilometres of missing data as though it were a known journey.
- Show separate stop markers, chronological stop order, start/end icons and timeline playback.
- Simplify with Ramer-Douglas-Peucker **for display only**, retaining start/end, sharp turns, stop boundaries, time/quality breakpoints and the full raw-event history. Tolerance should adapt to zoom and accuracy.

### 6.2 Optional: road matching for dense vehicle sections

Use a **backend RoadMatchingAdapter** so API keys and cost limits are not embedded in the child agent. Google Roads API snapToRoads permits at most **100 input points per request**, with optional `interpolate=true`. Google's guidance is consecutive points within roughly **300 m**, and dense 1–10 second samples yield higher-quality vehicle results. Never treat the returned road as verified motion.

Process:
1. Select verified *vehicle* segments with acceptable accuracy, timing, and point separation.
2. Split route at missing-data intervals, long jumps, probable parking breaks, mode changes, and sharply untrusted fixes.
3. Chunk each continuous segment into at most 100 input points, overlap boundary samples to avoid gaps.
4. Submit only eligible chunks subject to cost limits, privacy approvals and Maps Platform license.
5. Match response back to observation/time indices, verify no absurd detours or jumps and annotate confidence.
6. Fall back to raw line if match fails or quotas/policy prevent use.
7. Draw road-matched geometry **only on a Google Map** and follow provider attribution and restrictions.

**Provider legal caution:** Google Roads API content is subject to storage/caching restrictions, and **asset tracking applications may require a separate asset-tracking license**. Verify the Maps Platform terms and any necessary license *before* using road matching for Madalasa–Alarka. Do not persist Roads-derived geometry beyond what a specific permitted agreement authorizes. The source GPS events are Madalasa–Alarka observations with their own consent/retention obligations; keep them distinct from provider map content.

### 6.3 Do not use Google Directions/Routes as historical proof

Routes API computes a *possible* route between coordinates. It cannot establish the streets actually travelled by the child; do not substitute a directions route for missing location evidence. It may support clearly labeled **suggested route** navigation as a separate feature only.

## 7. Cross-device strategy: phone, tablet, watch

### Phone
Preferred continuous history source when present. Motion-aware FLP and local batching are the baseline; real-time view is opt-in and bounded.

### Tablet
Detect `PackageManager.FEATURE_LOCATION_GPS`, network location availability and Play services. Wi-Fi-only tablets may lack cellular GNSS and can provide coarse/limited positions. Report capabilities honestly rather than requesting unnecessary sensor precision.

### Wear OS
A watch may use its own GPS or obtain location from the paired phone. If watch lacks onboard GNSS and loses its phone connection, tracking can become unavailable. Check `FEATURE_LOCATION_GPS`. Wear OS FLP can support requested locations, but sustained GNSS is expensive on small batteries; prefer event-driven/longer intervals. Wear Health Services is intended primarily for workout/exercise location and should not be assumed to suit always-on parental tracking.

If one child has both phone and watch paired, **identify source device** and maintain independent tracks. Do not silently splice watch and phone samples into a fictional single observed path; support a clearly chosen active source or explicitly annotated handoff based on valid time/accuracy overlap. Direct-watch LTE uploads vs deferred companion sync require separate connectivity tests.

## 8. Backend schema extensions (PostgreSQL, optional PostGIS)

Suggested migrations / logical entities:

### named_places
- `id UUID PK`, `parent_id`, `child_id nullable`, `title`, `address_text nullable`, `latitude`, `longitude`, `place_id nullable`, `category`, `radius_m`, `alerts_enabled`, `created_at`, `updated_at`, `deleted_at nullable`.
- Parent ownership checked on all mutations. Index `(parent_id, child_id)`; use geography GiST index for large-scale proximity.

### location_observations
- `device_id`, `event_id UUID`, `observed_at`, `received_at`, `elapsed_realtime_nanos nullable`, `lat`, `lon`, `horizontal_accuracy_m`, `speed_mps nullable`, `speed_accuracy_mps nullable`, `bearing_deg nullable`, `provider`, `motion_hint`, `quality_flags`.
- Unique `(device_id,event_id)`, index `(device_id,observed_at)`, retention by policy.

### trips
- `id`, `child_id`, `source_device_id`, `first_observed_at`, `last_observed_at`, `state`, `distance_observed_m`, `confidence`, `processing_version`, `last_recomputed_at`.

### trip_segments
- `id`, `trip_id`, `start_at`, `end_at`, `segment_kind (OBSERVED/UNCERTAIN/GAP)`, `travel_mode_guess`, `source_point_refs`, `quality`.
- Road provider geometry, if used, must be handled according to **specific caching/retention terms**; do not assume unlimited persistence.

### detected_stops
- `id`, `trip_id`, `start_at`, `end_at nullable`, `centroid_lat`, `centroid_lon`, `radius_m`, `confidence`, `matched_place_id nullable`, `match_distance_m nullable`, `classification`.

### geofence_events
- `id`, `device_id`, `place_id`, `kind (ENTER/EXIT/DWELL)`, `observed_at`, `delivered_at`, `confidence/quality`. Geofence event does not by itself establish a confirmed stop.

## 9. API contracts (proposed versioned endpoints)

Parent-only endpoints, with object-level ownership:
- `POST /v1/children/{childId}/places` — title + coordinate + radius + options; validate bounded title/radius.
- `GET /v1/children/{childId}/places?bbox=...` — map-visible pins; cursor paginate.
- `PATCH /v1/children/{childId}/places/{placeId}` — rename/move/alert settings.
- `DELETE /v1/children/{childId}/places/{placeId}` — delete/revoke geofence when present.
- `GET /v1/children/{childId}/nearby-places?lat=&lon=&radius_m=` — proximity relative to observed point (optional convenience; never wake child GPS).
- `GET /v1/children/{childId}/trips?from=&to=&cursor=` — trip summaries and observation coverage.
- `GET /v1/trips/{tripId}/segments?mode=observed|road_if_eligible&zoom=` — ordered segment geometry with quality metadata, respecting map-provider terms.
- `GET /v1/trips/{tripId}/stops` — dwell events and associated known places.
- `GET /v1/children/{childId}/position` — latest observed position, `observed_at`, accuracy, `stale`.
- `GET /v1/children/{childId}/live-events` — optional authenticated SSE only while parent actively watches.

Child endpoints:
- Reuse `POST /v1/devices/{deviceId}/locations:batch` from existing API contract.
- `POST /v1/devices/{deviceId}/motion-events:batch` — if Activity Recognition is enabled; include state/confidence/times.
- `GET /v1/devices/{deviceId}/tracking-policy` — bounded, authorized sampling mode and eligible geofence subset; do not allow server to bypass OS permissions.
- `POST /v1/devices/{deviceId}/geofence-events:batch` — optional event updates.

Use authentication scopes/ownership, command TTLs, idempotent writes, pagination, rate limits, audit logs and per-parent data isolation. For live parent viewing, pushing derived server events avoids waking GPS solely to animate the marker.

## 10. Compact payload example and Kotlin pseudocode

Illustrative batched location message (values synthetic):

    {
      "device_id": "uuid",
      "profile": "BATTERY_SAVER",
      "events": [
        {
          "event_id": "uuid-1",
          "observed_at": "2026-10-25T08:12:30Z",
          "lat": 26.71,
          "lon": 88.43,
          "accuracy_m": 23.5,
          "speed_mps": 3.1,
          "motion_hint": "WALKING"
        }
      ]
    }

Representative, **not compile-ready**, Android location setup sketch:

    val request = LocationRequest.Builder(
        Priority.PRIORITY_BALANCED_POWER_ACCURACY,
        profile.intervalMs
    )
        .setMinUpdateIntervalMillis(profile.minIntervalMs)
        .setMinUpdateDistanceMeters(profile.minDistanceMeters)
        .setMaxUpdateDelayMillis(profile.batchDelayMs)
        .build()

    // Register only from a lifecycle/context where Android permits location use;
    // write callback fixes to the encrypted queue. Never upload each fix alone.

On the parent Map SDK:

    val marker = googleMap.addMarker(
        MarkerOptions()
            .position(LatLng(place.latitude, place.longitude))
            .title(place.title)
            .snippet(place.addressText)
    )
    // Draw distinct polylines for each reliable segment, never bridge a GAP.
    val polyline = googleMap.addPolyline(PolylineOptions().addAll(segmentPoints))

The data-processing pipelines should be implemented in separate testable modules. Prefer using C++ for deterministic trip/stop logic and serialization, but Kotlin remains the location/service/permission owner.

## 11. Map UX and confidence

**Live tab:** current observed point; "last updated X minutes ago", accuracy circle, speed when available, selected nearby labeled pins, route so far, and a clear battery-saving/high-detail label.

**History tab:** date/time filter, independent device sources, trip cards, duration and approximate distance, color-coded quality, tap to playback, stop markers numbered in time order, info windows with place title/uncertainty/dwell.

**Place management:** map long-press/add/search, title/description/radius, show/hide on map, optional alerts, delete/rename.

**Uncertainty:** break lines at missing periods; do not infer which street was taken after sparse data; label approximations. Map distance is not always odometer distance; sum only trustworthy observed segments or clearly qualify as estimate.

## 12. Battery/cost controls and comparison plan

### Device budgets
Measure incremental drain relative to app-disabled baseline, not only absolute Android battery percentage. Track per-device 24h stationary and 2h walking/vehicle tests, location request rate, GNSS active time (where observable), wakelocks, CPU/PSS, network bytes, and age of last fix. Include warm/cold starts and poor cellular signal. No measured data exists yet.

### Map API and server costs
- Parent map markers and polyline rendering use Maps SDK; child tracking does not use Maps tiles.
- Places Autocomplete only when parent types; avoid unnecessary details requests.
- Roads API only on qualified trip/segment, **not for every newly arriving point**, with quotas, cost ceilings and license review.
- Cache Madalasa–Alarka-owned raw observations and derived internal stop summaries according to parental retention settings, but respect provider-specific restrictions for Google Roads content.
- Avoid frequent reverse geocoding. A parent's custom place title is enough for most visit labeling.
- Perform trip/stop recalculation in incremental C++ backend workers after batched ingestion; long historical rebuild jobs run on demand.

## 13. Validation and acceptance tests

| ID | Scenario | Expected |
|---|---|---|
| RT-001 | Parent long presses map and titles pin "School" | Same marker persists on parent map and another parent session |
| RT-002 | Parent saves 100+ pins | Parent viewport markers remain usable; child geofences cap <=100 and only opted-in subset |
| RT-003 | Child passes within 100 m of School without stopping | Show proximity only, do not falsely mark School visited |
| RT-004 | Child dwells 6+ minutes in a reliable cluster | Stop created with arrival/departure and optional place match |
| RT-005 | Phone at red light for 45 sec | Do not mark an ordinary trip stop |
| RT-006 | Two-minute GPS outage while driving | Display data gap and never draw falsely verified roads |
| RT-007 | 60-second car samples separated >300 m | No high-confidence road match; default to qualified raw path |
| RT-008 | Dense reliable vehicle segment | Optional road matching succeeds within license/quotas; source raw trace retained |
| RT-009 | Out-of-order offline batches | Chronological trip reconstructs correctly with idempotent event ingest |
| RT-010 | User revokes location permission | Stop collection; show last-known/time and permission status |
| RT-011 | Watch disconnects from paired phone, lacks GPS | Report unavailable, no invented location |
| RT-012 | One child has both tablet and phone | Explicit source selection and no silent splicing |
| RT-013 | Two parent viewers open same trip | No additional child GPS sampling caused solely by marker display |
| RT-014 | Low battery / power saver | Tracking degrades to declared power profile; no false live promise |
| RT-015 | Crossing named-place radius with poor accuracy | No confident arrive/exit without supporting evidence |
| RT-016 | Parent renames/moves/deletes place | Markers and new matches update; retained historical references follow documented policy |

All tests record model, Android API, security patch, build SHA, battery and radio conditions, permissions, actual observations, screenshot/log evidence and PASS/FAIL. Play publication review is separate.

## 14. Phased implementation roadmap

**M1 — Named places and map (foundation):** parent UI add/edit/delete titled pins, backend place table + auth, markers/viewport query. No added child location overhead. Verify RT-001/002/016.

**M2 — Efficient location recorder:** child Kotlin FLP adapter, explicit location disclosures and permissions, event queue, sync, current-point parent marker. Implement profiles with conservative defaults; test battery stationary/moving/offline. Verify RT-009/010/013/014.

**M3 — Route history:** backend chronological segmentation, gap handling, display geometry simplification and parent polyline playback, confidence indicators. Verify RT-006/007.

**M4 — Trips and intermediate stops:** C++ trip/stop state machine with late-data revisions, proximity matching to saved places, visit timeline and duplicate suppression. Verify RT-003/004/005/015.

**M5 — Optional geofencing alerts:** explicitly opted-in named places, <=100 on-device active geofences, delayed delivery and careful dwell logic. No claim of instant arrival. Verify actual OEM behavior.

**M6 — Optional road matching:** only after checking Google Roads licensing/asset-tracking terms, measured sampling requirements, quota and privacy approvals. Integrate quota-limited backend adapter and fallbacks. Verify RT-007/008; skip this milestone if legal/cost/battery trade-off is unacceptable.

**M7 — Wear OS/tablet certification:** platform-specific capability profiles, GPS presence, paired-device handoff, standalone connectivity, cross-device source selection and realistic battery thresholds. Verify RT-011/012.

**M8 — Play release gates:** revisit background location declaration/demo video, persistent monitoring notification, Data safety, retention/deletion, SDK/target API, 16 KB C++ native page support and distribution terms; complete device tests before publishing.

## 15. Decisions requiring product signoff

1. Is low battery more important than perfectly snapped, street-level travel history? **Recommendation: yes by default; offer optional time-limited route-detail mode.**
2. What counts as a stop (3–5 minute walk dwell / 5–10 minute vehicle dwell initially)?
3. What default visible pin radius and alert responsiveness (initial candidate: 150 m and 5 minutes)?
4. Does the watch run independently or mainly complement the phone? **Recommend independent device IDs and prefer phone fixes if reliable.**
5. Are Google Roads licensing/cost/retention conditions acceptable for commercial family tracking? Do not enable until legally verified.
6. What retention periods should apply to raw points, trips, stop events and saved places?

## 16. Primary technical sources (consulted 2026-10-25)

- Android background battery / sampling: https://developer.android.com/develop/sensors-and-location/location/battery
- Google FLP LocationRequest.Builder batching/distance/priority: https://developers.google.com/android/reference/com/google/android/gms/location/LocationRequest.Builder
- Android Activity Recognition Transition API: https://developer.android.com/develop/sensors-and-location/location/transitions
- Android geofencing limits and DWELL: https://developer.android.com/develop/sensors-and-location/location/geofencing
- Android background location: https://developer.android.com/develop/sensors-and-location/location/background
- Wear OS location: https://developer.android.com/training/wearables/apps/location-detection
- Maps SDK markers: https://developers.google.com/maps/documentation/android-sdk/marker
- Maps SDK polylines: https://developers.google.com/maps/documentation/android-sdk/shapes
- Places Autocomplete: https://developers.google.com/maps/documentation/places/android-sdk/place-autocomplete
- Google Roads Snap to Roads: https://developers.google.com/maps/documentation/roads/snap
- Google Roads policies / asset tracking licenses: https://developers.google.com/maps/documentation/roads/policies
- Google Roads billing and quotas: https://developers.google.com/maps/documentation/roads/usage-and-billing

**Disclaimer:** This is a detailed design specification and verification roadmap, not an implementation or confirmed device-test report.

## 17. Production server implementation and multi-family security supplement

See [Adaptive Movement and Multi-Tenant C++ Server Architecture](../../M2-location-collection/01-location-collection-and-ingestion/ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md) for the deeper production architecture, including horizontal Drogon API scalability, per-device ordered reconstruction and late offline recovery, guardian-to-child grants, PostgreSQL/PostGIS migrations and partitioning, tenant RLS, queue leases, idempotent ingest, compute/fanout separation, capacity modelling and threat analysis. The current route design describes feature-level algorithms; the architecture supplement defines **how these can be operated securely and efficiently for many families**.

No implementation, Android device validation or real server performance benchmark has yet been completed.

## 2026-10-27 accepted movement-history storage pipeline for route cards

Per [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md), **record actual location observations on Alarka first**, in a device-encrypted local queue with a 48-hour offline capacity target, then upload in bounded JSON batches (1–2min target if Android eligible); original UTC event timestamps and accuracy/source live with each point. A child's moving-route card (START, FINISH, trip times, stops, compact polyline) is computed by independent C++ trip workers **only after inboxed batches are durably converted into raw PostGIS points** by C++ bulk workers; 202 inbox receipt does not mean the road line is current. Persist source-observed line with gaps and do not infer road turns from sparse points. If 48h of offline locations arrive, revise trips in event time, display revision reason and last GPS/received/trip-processed times, and do not present backfilled coordinates as live. Devices may record more than 300 points/day while moving; 300 was a finance scenario not quota. Optional road matching is distinct and subject to licensing and uncertainty flags.

**Accepted server buffer:** PostgreSQL inbox one row per authenticated device JSON batch with durable 202 queue ACK, worker leases SKIP LOCKED and 100–500-point bulk inserts (prepared multirow/optional COPY staging) into location partitions with dedup/outbox commit. No Redis MVP dependency. Parent maps/history read latest processed summaries and do not wake Alarka; live tracking is a separate, explicit, time-limited operation constrained by Android background location. HLD and LLD in [Figma](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-2). Child-location history storage remains gated by India counsel and Google Play review.
