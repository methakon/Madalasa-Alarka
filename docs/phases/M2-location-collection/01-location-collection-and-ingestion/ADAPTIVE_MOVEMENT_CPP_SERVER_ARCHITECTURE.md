# Adaptive Movement Tracking & Multi-Tenant C++ Trip Reconstruction — Architecture and Detailed Technical Specification

> **Document control:** M2 / 01-location-collection-and-ingestion · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product naming:** **Madalasa** parent/guardian app, **Alarka** child companion; GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka). [Brand and Markandeya Purana context](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Project:** Madalasa–Alarka  
**Document ID:** AP-ARCH-TRK-001  
**Revision:** 1.0 — proposed design  
**Research baseline:** 2026-10-25  
**Status:** Engineering specification, NOT implemented, NOT performance-tested, NOT Google Play approved  
**Related documents:** [SRS](../../M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md), [Named Places and Route Design](../../M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md), [Implementation Technical Specification](../../M1-secure-platform-foundation/01-requirements-and-architecture/IMPLEMENTATION_TECHNICAL_SPECIFICATION.md), [Security and Operations](../../M8-operational-readiness/02-operations-and-support/SECURITY_AND_OPERATIONS.md), [Feasibility Conditions](../../M0-foundation-and-approvals/02-market-and-feasibility/FEASIBILITY_CONDITIONS_AND_EVIDENCE.md), [Validation and Release Plan](../../M8-operational-readiness/03-quality-and-evidence/VALIDATION_AND_RELEASE_PLAN.md).

## 0. Executive architecture decision

Use **Kotlin Android platform integration + a small C++ shared core** on the child device, **stateless Drogon C++ HTTP services**, **dedicated C++ stream/batch reconstruction workers**, and **PostgreSQL with PostGIS**. Use a durable database-backed work queue initially; graduate to partitioned streaming infrastructure only when operational measurements justify it.

Separate **five workloads** so that one cannot block another:

1. Child event capture and local battery-aware buffering.
2. Network ingest, authentication, validation and durable acknowledgment.
3. Asynchronous per-device, event-time ordered route/trip/stop analysis.
4. Parent map/history reads and real-time notifications.
5. Policy/subscription/account/privacy operations.

**Most important design rule:** ten parents watching a map must not create ten times as many location requests on a child phone. Parent viewing reads existing backend state. A temporary fresh-position request, if supported and separately authorized, is bounded, OS-compliant and separately audited.

A persistent notification, recognizable child-app identity, proper permissions and local privacy controls remain required. Never design covert surveillance or bypass Android system controls. Camera/microphone modules are out of scope for the route reconstruction pipeline and retain their separate gated requirements.

## 1. Source review and implications

The following are primary sources reviewed for this design:

| Source / official technical guidance | Verified finding | Architectural consequence |
|---|---|---|
| Android [background location & battery](https://developer.android.com/develop/sensors-and-location/location/battery) | Energy depends on accuracy, frequency and latency; background fixes may be throttled | Adaptive profiles and honest freshness; no 24/7 5-second default |
| Android [location best practices](https://developer.android.com/develop/sensors-and-location/location/battery/scenarios) | Prefer passive/balanced updates, geofencing where useful | Avoid unnecessary GNSS and frequent radio wakeups |
| Google Play services [LocationRequest.Builder](https://developers.google.com/android/reference/com/google/android/gms/location/LocationRequest.Builder) | Supports interval, min update interval/distance, priority and max delay; request interval is not guaranteed | Configurable request policy, batched delivery and measurement |
| Android [Activity Transition API](https://developer.android.com/develop/sensors-and-location/location/transitions) | Event-driven activity transitions can avoid constant sensor polling | Use as a motion *hint*, not ground truth |
| Android [geofences](https://developer.android.com/develop/sensors-and-location/location/geofencing) | Up to 100 active geofences per app/device user; delays and accuracy limits; Wear geofences discouraged | Parent-named places on server, optional small alert subset on phone |
| Android [foreground-service starts](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) | Background starts and while-in-use location checks are restricted | Explicit lifecycle and exception handling; no falsely guaranteed live rate |
| Android [Wear OS location](https://developer.android.com/training/wearables/apps/location-detection) | Watch may use paired-phone location; standalone GNSS may be absent | Per-source provenance and economical watch policies |
| [Drogon framework documentation](https://drogonframework.github.io/drogon-docs/) | Asynchronous C++ HTTP, PostgreSQL/Redis support and request filters | Strong fit for a lean, horizontally scalable API tier |
| PostgreSQL [partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html) | Time partitions aid retention/query pruning; partitioned unique keys must include partition key | Partition raw observations by observation time; explicit dedupe strategy |
| PostgreSQL [row-level security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) | DB can restrict tenant rows, but owner/superuser exceptions exist | Defense in depth, FORCE RLS, separate service/worker roles |
| PostgreSQL [SKIP LOCKED](https://www.postgresql.org/docs/current/sql-select.html) | Supports multiple consumers of queue-like tables | Small-scale durable worker dispatch, with lease/retry logic |
| PostGIS [ST_DWithin](https://postgis.net/docs/ST_DWithin.html) | Index-assisted proximity check, geography units in metres | Efficient named-place/dwell spatial matching |
| PostGIS [ST_MakeLine](https://postgis.net/docs/ST_MakeLine.html) | Can build ordered route lines from chronological points | Route geometry by observed time, with gaps handled separately |
| Google [Roads Snap to Roads](https://developers.google.com/maps/documentation/roads/snap) | Max 100 observations/request; input points ideally within 300 m | Only optional for dense, reliable vehicle tracks |
| Google [Roads API policies](https://developers.google.com/maps/documentation/roads/policies) | Caching/attribution restrictions and possible asset-tracking license | NO production road matching without commercial/legal review |
| [OWASP API Security Top 10](https://owasp.org/API-Security/) | Object authorization, authentication and resource consumption are critical | Tenant isolation, quotas, authenticated workflows, negative tests |

**Research conclusion:** no single Android API, C++ library or SQL function guarantees precise low-power tracking. The solution must optimize the **combined system**, measure trade-offs on target handsets and expose uncertainty rather than manufacture an exact route.

## 2. Requirements cross-reference

| Requirement | Implementation |
|---|---|
| Child background operation after parent setup | Permission-aware Android collector; Activity not required to remain open; monitoring notification where required |
| Live/latest map location and speed | Latest-observation materialized view + timestamp/accuracy; speed optional |
| Travelled road/path, multiple trips/stops | Immutable raw events, event-time reconstruction, stop clustering, segmented polylines |
| Parent-labeled Home/School/etc. | Tenant-owned named_places and proximity engine; parent-side markers |
| Daily/weekly/monthly/yearly usage | Independent UsageStats ingestion/aggregation pipeline sharing security/tenant architecture |
| Parent and multiple children; multiple parents/guardians | Explicit family/guardian roles, device-to-child mapping and fine-grained grants |
| Phone/tablet/watch | Separate device identity, source quality and capability profiles |
| Subscription | Parent account entitlements validated by backend |
| C++ low-latency high-concurrency backend | Drogon API replicas; separate C++ worker pool; bounded work |
| Strong privacy/security | Device binding, tenant authorization, least-privilege RLS, encryption, minimization and deletion |
| Battery economy | Motion-adaptive location, passive collection when suitable, batched sync, optional detail mode |
| Android/Play distribution | Background location, foreground service, monitoring disclosure and approved permissions |

## 3. Trust boundaries and component topology

~~~text
 Child Phone / Tablet / Watch                  Parent Android App / Web
 Android permission + OS lifecycle            Parent OAuth/Passkey identity
 Motion hint + location events                Google Map, saved pins, trip player
 Local encrypted queue                        HTTPS queries and optional SSE
             |                                         |
             | device-authenticated TLS                | parent-authenticated TLS
             v                                         v
       +-------------------------------------------------------+
       |     Public edge (TLS, WAF/rate limits, request size)   |
       +---------------------------+---------------------------+
                                   |
                 +-----------------v----------------+
                 | Drogon C++ API replicas (N>=1)  |
                 | Auth / Enrollment / Telemetry   |
                 | Tenant ACL / Policy / Query     |
                 +---------+---------------+-------+
                           |               |
                  bounded DB pool        Push hint broker
                           |               |
               +-----------v---------------+------------------+
               | PostgreSQL + PostGIS                         |
               | raw observations, guardian grants,          |
               | trip state, stops, named places, audit,     |
               | transactional processing jobs/outbox         |
               +-----------+----------------------------------+
                           |
                    durable jobs / leases
                           |
                +----------v-------------------+
                | C++ trip reconstruction pool |
                | single-writer per device     |
                | quality filter, segments     |
                | trip+stop state machine      |
                | named-place joins            |
                +-----------+------------------+
                            |
                    versioned derived rows
                            |
                 +----------v----------+
                 | Read cache / latest |
                 | position / SSE fanout|
                 +---------------------+

Separate workers: retention/deletion, usage aggregation, subscription,
Drive upload (if feature released), alerts and data reconciliation.
~~~

### Why this topology?

- **Stateless API instances** can be replicated without moving child sessions or rebuilding per-device state.
- **Asynchronous analysis** prevents long trip jobs from blocking the HTTP event loop or parent map.
- **Durable event inbox/outbox** allows a crash between ingestion and processing to recover without data loss.
- **Per-device logical serialization** prevents two workers from assigning contradictory stop boundaries.
- **Separate read workloads** keep one parent replaying months of tracks from starving child ingestion.
- **PostGIS** handles spatial indexing instead of scanning all saved places on every fix.
- **Avoid a microservice explosion on day 1.** Start with a modular C++ monorepo, a small number of deployable processes and clear scaling seams.

## 4. Multi-parent, multi-child, multi-device identity model

Do **not** equate one parent account with one child device.

Entities:
- **family/tenant:** logical privacy boundary.
- **guardian_membership:** authenticated adult principal and role; a child may be visible to explicitly authorized guardians only.
- **child_profile:** a supervised child entity.
- **device:** one enrolled phone, tablet or watch mapped to a child_profile; support source handoff without pretending device continuity.
- **grant:** explicit guardian-to-child permission (location read, history, edit places, manage device/policies), revocable and auditable.
- **named_place:** scoped to child/family and created by an authorized guardian.
- **subscription:** entitlement scoped to the paying parent/family according to product policy.

Baseline guardian roles:
- **OWNER:** approve/link device, grant access, delete/export and manage plan.
- **GUARDIAN:** read location/history and manage allowed child settings.
- **VIEWER:** read only, with limited duration/history window if granted.
- **DEVICE:** uploads only records for its own enrolled device; **never** reads another child's history.
- **SERVICE_WORKER:** privileged internal bounded operations; not a parent token.

If multiple adults belong to different families but supervise one child, use an explicit sharing ACL and a well-defined canonical child owner; **do not merge tenant rows implicitly**. Document revocation propagation and who may delete shared history.

Security rule: every query must check BOTH the authenticated principal's tenant and the exact child/device entitlement. Never trust a child_id/family_id or guardian_role submitted in the HTTP body or query string.

## 5. Child tracking engine: adaptive motion and resource control

### 5.1 Supported Android implementation

Kotlin manages:
- Runtime foreground/background location permission flow and disclosure.
- FusedLocationProviderClient where available; tested LocationManager fallback if appropriate.
- ACTIVITY_RECOGNITION (only if released and explicitly granted) using Transition API as an event **hint**.
- On-device tracking state machine and location request lifetime.
- WorkManager to upload queued events; approved foreground service with location service type and monitoring notification where Android policy requires it.
- Permission revoked/disabled/OS-rejected/force-stop degraded state.
- Device capability report (phone/tablet/watch, GPS present, battery constraints).

C++ NDK core, when useful, handles compact validation/serialization, queue state machine and shared data contracts; avoid wrapping every Android API in JNI or spinning custom sensor threads.

### 5.2 Adaptive states

~~~text
BOOTSTRAP
   |
   v
UNKNOWN <--> LIKELY_STILL <--> CONFIRMED_STILL
   |
   +----> WALKING_HINT / CYCLING_HINT / IN_VEHICLE_HINT
   |                 |
   +----> MOVING_CONFIRMED
                      |
                STOP_CANDIDATE ----> CONFIRMED_DWELL
                      |                   |
                      +---- MOVING <------+
   |
   +----> PERMISSION_LOST / LOCATION_DISABLED / OS_RESTRICTED
   |
   +----> POWER_CONSTRAINED
~~~

Transitions use **independent evidence**: location displacement relative to accuracy, valid speed and motion transition events. A single GPS bounce or a single classifier hint must not trigger perpetual high-accuracy updates. Apply a 60–120-second mode-switch cooldown as an initial candidate and safety timeout to detail mode.

### 5.3 Initial tuning profiles (hypotheses, not measured)

| Condition | Suggested requested fix cadence | Quality | Upload trigger / latency tradeoff |
|---|---|---|---|
| Stationary phone | passive or every 5–15 minutes | low/balanced | batch every 15–30 minutes |
| Walking | 30–90 seconds | balanced | batch 1–5 minutes |
| Cycling | 15–45 seconds | balanced/high when needed | batch 1–3 minutes |
| Vehicle ordinary | 30–60 seconds | balanced | batch 1–3 minutes |
| Vehicle detail, explicitly enabled | adapt about 5–15 seconds | high accuracy, limited duration | batch 30–90 seconds |
| Watch stationary | opportunistic or 10–20 minutes | passive/balanced | defer and batch |
| Watch moving | 1–5 minutes | balanced | 3–10-minute batch where tolerable |
| Low battery / thermal restriction | reduce sample frequency | balanced/low | postpone nonessential uploads |

The above are **proposed test profiles**, not promises of interval or measured drain. Android can deliver fewer fixes than requested. Android location request batching can reduce callback wakeups; use maxUpdateDelayMillis at least twice the request interval when meaningful, and accept that batching is best effort.

### 5.4 Change policy without GPS thrash

- A location provider should be registered **once per active policy** rather than restarted for every speed fluctuation.
- Avoid constantly toggling high-accuracy settings. Maintain motion confidence and minimum dwell per policy.
- Prefer distance filters to reject uninformative near-duplicate stationary points.
- Do not request active GNSS simply because one or more parents opened a map.
- Use bounded explicit detail mode; automatic fallback when battery is low or OS denies high-frequency operation.
- Apply timeouts and remove location listeners after mode exit.

### 5.5 Location and movement truthfulness

Store Android-reported timestamp and elapsed realtime age when available, horizontal accuracy and optional speed/bearing accuracy. Coordinates may represent the **device**, not necessarily the child personally. Mock/spoofed data detection may inform confidence but is not proof of truthful physical presence.

Phone vs tablet vs watch:
- A Wi-Fi tablet may lack dedicated GPS; honor coarse capability.
- Wear OS may use a paired phone for position; tag actual source when available.
- A child carrying watch + phone generates **two observation streams**; select one primary source for parent map based on quality and freshness, preserving separate provenance, never concatenate tracks across devices without an explicit recorded handoff.

## 6. Event model and wire protocol

Suggested event JSON (example values are synthetic):

~~~json
{
  "batch_id": "f842e1ec-8d2b-4d66-aaf8-e1cc25d792ed",
  "device_id": "e738b442-02b8-46e1-8513-81a3f46e8d0a",
  "capture_policy_version": 7,
  "events": [
    {
      "event_id": "6ea44448-97bd-44b8-ab13-5d775c8a50af",
      "observed_at": "2026-10-25T09:01:20Z",
      "elapsed_realtime_ns": 409398290002,
      "latitude": 26.7,
      "longitude": 88.4,
      "accuracy_m": 31.5,
      "speed_mps": 4.0,
      "speed_accuracy_mps": 1.5,
      "bearing_deg": 114.3,
      "provider": "fused",
      "motion_hint": "WALKING",
      "tracking_mode": "BALANCED"
    }
  ]
}
~~~

Required: event_id, source device identity, observed_at UTC, latitude/longitude, horizontal accuracy, mode/source. Optional: elapsedRealtimeNanos, speed, bearing and accuracy fields. Never require speed as an invariant.

Security and validation:
- Authenticated device ID comes from cryptographically verified credential; reject path/body credential mismatch.
- Validate coordinate bounds, finite numbers, expected time skew, impossible payload sizes, allowed enum/version.
- Batch limit candidate 100–500 events, max compressed/uncompressed size, decompression ratio limits and server-issued rate budgets.
- event_id stable across retries. Sender keeps batch until durable acknowledgment.
- Use HTTP 202 only after durable write transaction commits; **not** after async socket enqueue.
- Response reports accepted, duplicate and rejected event IDs/counts with clear reason codes.
- A stored fix is not proof that derived trip/stop processing already completed.

## 7. C++ server process design

### 7.1 Recommended stack

| Layer | Decision | Why |
|---|---|---|
| Language | C++20 with tested compiler toolchain | Performance, native shared validation logic, deterministic worker implementations |
| API | Drogon | Nonblocking HTTP handlers, async PostgreSQL support; avoids writing a network stack |
| Auth | OIDC for parents; unique device credentials / proof-of-possession where feasible | Separate identity trust domains |
| DB | PostgreSQL + PostGIS | Durable ACID ingestion, geospatial queries, row-level policies, time partitioning |
| Worker transport (phase 1) | PostgreSQL transactional outbox + queue + SKIP LOCKED leases | Minimal infrastructure, at-least-once recovery |
| Worker transport (later) | Partitioned broker (e.g., NATS JetStream / Kafka) after a verified need | Higher fanout/throughput, operational complexity |
| Read caching | Latest position table; optional Redis with TTL | Fast parent map without full historical scans |
| Real-time | Parent SSE/WebSocket for viewing session only; event versioning and bounded connections | Avoid per-parent GPS or polling |
| Metrics | OpenTelemetry-compatible spans/metrics and structured redacted logs | SLOs, load diagnosis, incident response |

**Never run expensive stop detection synchronously on Drogon's network event-loop threads.** Limit work by bounded task queue and dedicated CPU worker pool. Protect DB connections from unbounded concurrent requests.

### 7.2 Deployable services

Start with 3 main deployables:
1. **api-service**: stateless Drogon; handles parent read/write, device ingest, admin and auth integration.
2. **reconstruction-worker**: consumes committed jobs, loads per-device observation windows, updates derived trip/stop/segments.
3. **maintenance-worker**: retention, account deletion, recomputation scheduling, retry, usage aggregates and entitlement reconciliation.

Optional later: SSE gateway / independent read replicas / separate ingest tier. A modular monolith is more maintainable early than 15 microservices.

### 7.3 C++ module boundaries

~~~text
backend/
  api/
    auth_filter.cpp
    pairing_controller.cpp
    device_ingest_controller.cpp
    place_controller.cpp
    trip_controller.cpp
  domain/
    location_event.hpp
    trip.hpp
    stop.hpp
    named_place.hpp
    tracking_policy.hpp
  ingest/
    validation.cpp
    batch_writer.cpp
    outbox_writer.cpp
  reconstruction/
    chronological_buffer.cpp
    quality_filter.cpp
    motion_estimator.cpp
    stop_detector.cpp
    trip_segmenter.cpp
    place_matcher.cpp
    track_renderer.cpp
    reconstruction_worker.cpp
  persistence/
    sql_repository.cpp
    migration_runner.cpp
  security/
    principal.cpp
    tenant_authorizer.cpp
    rate_limiter.cpp
    audit.cpp
  observability/
    tracing.cpp
    metrics.cpp
  tests/
~~~

Core processing libraries depend on plain C++ domain objects and **not** Drogon HTTP classes. This lets deterministic tests replay synthetic tracks without launching the server.

## 8. Event-time processing / recovery model

### 8.1 Why timestamps are difficult

Phones can go offline for hours and upload a valid morning route in the afternoon; location fixes can arrive out of order or be replayed during retries. Processing in **arrival time** incorrectly creates trips backwards and misleading stops.

Use:
- **observed_at:** captured Android event time (subject to clock checks).
- **received_at:** trusted server ingestion time.
- **event_id:** deduplication identity.
- **source_device_id:** route provenance.
- **processing_version:** specific algorithm config.
- **reconstruction_watermark:** time through which a device's ordinary data is provisionally processed.

### 8.2 Durable processing transaction

Within one database transaction:
1. Validate credentials and per-device grant.
2. Insert accepted raw events, idempotently.
3. Update device last_seen / latest qualified position conditionally.
4. Insert a per-device work request/outbox entry identifying the **affected time range**.
5. Commit.
6. Acknowledge to child device.

Do **not** send acknowledgments before step 5. A crash after commit but before acknowledgment causes a retry, safely deduped by event identity.

### 8.3 Worker scheduling and serial ownership

- Work jobs are keyed to **device_id**, preferably a single active lease per device.
- Queue workers claim eligible rows transactionally with SKIP LOCKED, record lease owner/expiry and renew while processing.
- If process crashes, lease expires, another worker retries; all derived writes must be idempotent.
- Coalesce overlapping recompute windows per device, e.g. 10:00–10:20 + 10:15–10:35 into one.
- Enforce a max computation time/points per job; very long late-history backfills are paginated.
- Record worker algorithm version and derived-row version to avoid overlapping stale writers.
- A periodic reconciler finds raw batches with missing jobs or derived state and reschedules them.

For large volumes, partition broker messages by stable device hash to preserve ordering within each device. Never assume global event ordering among distinct devices.

### 8.4 Provisional/finalized semantics

Proposed **event-time lateness window**: 10–30 minutes for recent tracks (configurable, benchmark). Routes/stops are displayed as **provisional** until sufficient evidence. Offline data arriving outside that window triggers a bounded *retroactive correction* job over affected history, preserving revision and notifying parent readers that a trip changed.

No raw location is fabricated for gaps. The last valid point and first subsequent point are not joined as if the street path were known.

## 9. Reconstruction algorithms — detailed rationale and implementation

### 9.1 Stage 1: quality and plausibility gate

For adjacent points A, B:
- distance_m = geodesicDistance(A,B).
- dt_s = B.observed_at - A.observed_at.
- impliedSpeed = distance_m / dt_s where dt_s > 0.
- incorporate accuracy uncertainty; a 70 m displacement with 150 m horizontal error does not establish movement.
- reject malformed or clear duplicate points; **flag** uncertain but plausible jumps rather than deleting legitimate high-speed train or airplane travel solely due to a fixed speed threshold.
- detect source/time gaps, clock correction and possible GPS multipath.
- never average two points across a long tunnel outage into a fictitious road.

Illustrative quality labels: TRUSTED, APPROXIMATE, SUSPECT, INVALID, GAP. Retain protected raw observations within chosen retention even when excluded from derived path.

### 9.2 Stage 2: movement inference

Motion classification is probabilistic:
- possible WALKING/CYCLING/VEHICLE based on speed range, variance, activity transition hints and prior state;
- keep UNKNOWN when evidence is inadequate;
- use hysteresis/time persistence before switching profile/segment;
- avoid treating an Activity Recognition label as proof of exact travel mode.

Trip begins after repeated credible displacement from a stationary region (candidate 100–200 m plus confidence), not one bad fix. Trip ends after sufficient dwell or a segment-break/gap; the latter is **unknown end**, not a confirmed arrival.

### 9.3 Stage 3: stay point / stop detection

Use an **incremental accuracy-aware dwell cluster**. Candidate design (tune on labelled data):
- Start a candidate when sequential points occupy a compact region.
- Adaptive cluster radius: base 50–100 m, increased by uncertainty in the supporting fixes.
- Compute robust/geodesic centroid (or accuracy-weighted spatial centroid on projected local coordinates) and avoid a single inaccurate outlier moving the cluster.
- Confirm visit after approximately 3–5 min walking or 5–10 min vehicle dwell with repeated supporting points.
- Confirm exit only after multiple reliable points beyond radius + hysteresis margin.
- Ordinary 30–60 second traffic-light waits are **not confirmed stops**.
- Under sparse data, report UNKNOWN/DWELL_POSSIBLE; there is no evidence for the exact arrival/departure minute.

Store supporting observation IDs, start/end estimate bounds, centroid, accuracy/confidence, rule version, stop classification and whether named place match is ambiguous.

### 9.4 Stage 4: trip/leg/segment model

- **trip:** continuous travel episode including intermediate stops.
- **leg:** movement interval between stops; can contain multiple observed segments.
- **segment:** continuous observation geometry separated at data gaps or low-quality stretches.
- **stop:** supported dwell cluster between legs.
- **gap:** interval with insufficient observations, never an invented travelled road.

Example observed timeline:

~~~text
Home [07:42] --leg 1-- Stop A (6m) --leg 2-- GAP (GPS unavailable)
   --leg 2 continuation? unknown route-- School [08:40]
~~~

Parent sees:
- time and quality markers for each segment;
- a stop card for Stop A;
- explicit unknown line coverage during gap;
- saved-place labels only when evidence supports proximity/dwell.

### 9.5 Stage 5: match known addresses

Parent-defined coordinates and titles remain server-side. Match confirmed stop centroid to eligible named places within configured radius using a tenant-scoped PostGIS geography index.

Example (illustrative; assume PostGIS installed, suitable geo column and tenant ACL already applied):

~~~sql
SELECT p.id, p.title,
       ST_Distance(p.geog, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography) AS distance_m
FROM named_places p
WHERE p.family_id = :authorized_family_id
  AND ST_DWithin(
        p.geog,
        ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
        :lookup_radius_m)
ORDER BY distance_m
LIMIT 10;
~~~

Query parameterization is required; app must never trust :authorized_family_id from an unverified client value. If two saved places overlap, classify AMBIGUOUS and return candidates. A place may be near the travel path without being a visited stop.

### 9.6 Stage 6: render polyline from **observed evidence**

- Sort trusted points by time, split at gaps and unknown segments.
- Generate one LineString/polyline per supported segment.
- Simplify **for parent display only** using Ramer–Douglas–Peucker or PostGIS ST_SimplifyPreserveTopology in an appropriate *metric projected coordinate system* (degrees are not metres). Preserve endpoints, stop boundaries, turn/quality points and raw history separately.
- Segment displays include confidence and source device ID.
- Return points adapted to zoom/viewport or tile-like ranges, with strict per-query max, pagination and caching.
- Parent map draws saved pins as separate layers. An open parent map **never** automatically increases child collection cadence.

Optional Roads API:
- Only route-match vehicle sections with consecutive reliable input fixes generally within about 300 m, no long gaps and at most 100 points/request.
- Keep a separately configured Roads API quota and spend cap.
- **Legal gate:** check asset-tracking license, Google Maps-only rendering, caching limits, retention and attribution before shipping. Never automatically store provider-derived snapped geometry indefinitely.
- Default is observed polyline. A Directions/Routes endpoint describes a possible road route, **not historical proof of actual travel**.

### 9.7 Suggested C++ domain pseudocode

~~~cpp
struct Fix {
  Uuid deviceId;
  Uuid eventId;
  TimePoint observedAt;
  double latitude, longitude, accuracyMeters;
  std::optional<double> speedMps;
  MotionHint hint = MotionHint::Unknown;
};

struct ReconstructionResult {
  std::vector<Trip> trips;
  std::vector<Stop> stops;
  std::vector<ObservedSegment> segments;
  std::vector<Gap> gaps;
  AlgorithmVersion version;
};

ReconstructionResult reconstruct(
    const std::vector<Fix>& input,
    const AlgorithmConfig& config,
    const PreviousCheckpoint& checkpoint) {
  auto ordered = deduplicateAndSortByObservedTime(input);
  auto qualified = qualityFilterWithFlags(ordered, config);
  auto motion = inferMovementWithHysteresis(qualified, config);
  auto stops = detectAccuracyAwareDwell(motion, config);
  auto trips = segmentIntoTripsLegsAndGaps(motion, stops, config);
  auto tracks = buildObservedRouteSegments(trips, qualified, config);
  return {trips, stops, tracks.segments, tracks.gaps, config.version};
}
~~~

This is a **testable algorithm interface**, not production-ready code. The orchestration must support late data, revisions, backpressure and partial checkpoint recovery.

## 10. PostgreSQL/PostGIS schema design and limitations

### 10.1 Core tables

- **families**: id, owner, region, status.
- **guardian_memberships**: principal_id, family_id, role, invitation/revocation status.
- **guardian_child_grants**: principal, child_id, permissions, valid_from/to, revoked_at.
- **children**: id, family_id, metadata minimization.
- **devices**: id, child_id, family_id, platform/model/API, signed credential reference, capability state, revoked_at, last_seen.
- **location_observations**: family_id, device_id, observed_at, event_id, received_at, lat/lon, accuracy, source, sequence/flags; time-partitioned.
- **device_event_dedup**: stable device_id + event_id uniqueness independent of time-partition key, bounded by retention (or cryptographically stable timestamp/partition policy).
- **device_latest_position**: one qualified row per device, observed_at + accuracy + status.
- **named_places**: family_id, child_id optional, title, geography point, radius, notifications settings.
- **reconstruction_jobs**: device_id, from/to interval, lease/status/version/retry fields.
- **device_reconstruction_checkpoints**: device_id, time watermark, version, last processed job ID.
- **trips, trip_legs, trip_segments, detected_stops, stop_place_matches**: derived versioned records.
- **usage_aggregates, policies, commands, subscriptions, audit_events, deletion_jobs**: reuse existing project models.

### 10.2 Illustrative raw schema and index migration

~~~sql
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE location_observations (
    family_id uuid NOT NULL,
    device_id uuid NOT NULL,
    event_id uuid NOT NULL,
    observed_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    latitude double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    accuracy_m real NOT NULL CHECK (accuracy_m >= 0),
    speed_mps real NULL,
    quality_code smallint NOT NULL DEFAULT 0,
    PRIMARY KEY (device_id, observed_at, event_id)
) PARTITION BY RANGE (observed_at);

-- Illustrative monthly partition; automate creation and retirement by policy.
CREATE TABLE location_observations_2026_10
    PARTITION OF location_observations
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');

CREATE INDEX location_device_time_idx
    ON location_observations (device_id, observed_at DESC);

-- Alternative to assuming event_id is globally unique across time partitions:
CREATE TABLE device_event_dedup (
    device_id uuid NOT NULL,
    event_id uuid NOT NULL,
    first_seen_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (device_id, event_id)
);
~~~

**Important partitioning constraint:** PostgreSQL cannot enforce a unique event_id on a table partitioned by observed_at unless the partition column is part of the key. The example main PK includes observed_at; device_event_dedup prevents duplicate event IDs with maliciously changed timestamps. Coordinate the dedup insert and raw insert in one transaction. Design dedup expiry to cover retry/offline limits; never allow a replayed old event to become a new route point after purging the dedup ledger. Consider a bounded retention-aware identifier strategy for very large scale.

Use a GiST index on named_places geography only if proximity workload warrants it, and composite family/child indexes. For location history, time + device B-tree and partition pruning usually matter more than a huge global spatial index. Use EXPLAIN ANALYZE on realistic workloads; do not add spatial indexes blindly to every raw row.

### 10.3 Tenant RLS — example of defense in depth

~~~sql
ALTER TABLE named_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE named_places FORCE ROW LEVEL SECURITY;

CREATE POLICY named_places_tenant_select ON named_places
FOR SELECT USING (
  family_id = NULLIF(current_setting('app.family_id', true), '')::uuid
);

-- Similar explicit SELECT / INSERT / UPDATE / DELETE policies are needed
-- on each sensitive table, with WITH CHECK on writes.
~~~

**Critical operational caveats:**
- Authentication & per-child grant checking occurs **before** DB query. Family RLS alone does not decide whether one guardian can see a particular child.
- Use an unprivileged SQL runtime role **without BYPASSRLS**, not table owner/superuser.
- Set trusted family context with **SET LOCAL inside each transaction**, derived from validated principal; pooled connections must not leak context between requests.
- Shared worker roles need separate narrowly controlled internal access, not a universally exposed bypass token.
- RLS is defense-in-depth, not a substitute for controller-level authorization.
- All export, SSE, cache keys and error pages must include equivalent tenant scoping.

### 10.4 Durable jobs / queue example

~~~sql
WITH picked AS (
  SELECT id
  FROM reconstruction_jobs
  WHERE available_at <= now()
    AND (state = 'READY'
      OR (state = 'LEASED' AND lease_expires_at < now()))
  ORDER BY available_at, id
  FOR UPDATE SKIP LOCKED
  LIMIT :worker_batch_size
)
UPDATE reconstruction_jobs j
SET state = 'LEASED',
    lease_owner = :worker_id,
    lease_expires_at = now() + interval '60 seconds'
FROM picked
WHERE j.id = picked.id
RETURNING j.*;
~~~

Lease duration is illustrative. Keep processing outside the claim transaction; renew lease if needed; use optimistic version/write guard to stop expired workers committing stale derived rows; exponential retry, dead-letter investigation and reconciliation. Coalesce device jobs before CPU work. At larger scale, move the same logical contract to a durable partitioned broker.

## 11. API proposal and read-performance rules

**Device (credential-scoped):**
- POST /v1/devices/{deviceId}/locations:batch — durable idempotent events.
- POST /v1/devices/{deviceId}/motion-events:batch — optional hints.
- GET /v1/devices/{deviceId}/tracking-policy — versioned authorized policy.
- POST /v1/devices/{deviceId}/capabilities — permission/OS state, never fabricated support.

**Parent (grant-scoped):**
- GET /v1/children/{childId}/position — latest qualified position, source, accuracy, observed_at, stale state.
- GET /v1/children/{childId}/trips?from=&to=&cursor= — trip summaries, provisional/revision status.
- GET /v1/trips/{tripId}/segments?zoom=&cursor= — segmented lines, quality and bounds.
- GET /v1/trips/{tripId}/stops — qualified stop history.
- POST/GET/PATCH/DELETE /v1/children/{childId}/places — title/radius/markers, parent-only.
- GET /v1/children/{childId}/activity?period=day|week|month|year — aggregated app usage.
- GET /v1/children/{childId}/live — optional authorized SSE stream only while parent is actively viewing.
- GET /v1/account/export and POST /v1/account/deletion-request — subject to privacy model.

Response requirements: stable schema version, next_cursor, quality flags, source_device_id, observed vs processed timestamps. Parent should never receive another family's data through an error or guessed UUID.

Read query optimization:
- Latest position from materialized latest row/cache, **not** SELECT over millions of historical fixes.
- Trip summaries separate from detailed geometry.
- Geometry simplified per zoom; strict point caps/viewport/date bounds.
- Cache key includes tenant/family/child, permission version, trip revision and zoom; evict on grant revoke/delete.
- SSE pushes updates to parent connected session; cap streams per account and close idle sessions. Do not keep an indefinite WebSocket on child.

## 12. Scale and capacity planning

**Assumptions, not benchmarks:** Suppose an average enrolled device produces 300 accepted fixes/day after adaptive sampling; bursts could be 10× daily average. Exact production traffic needs field measurements.

| Active devices | Observations/day | Avg observation writes/s | Illustrative 10× burst/s |
|---:|---:|---:|---:|
| 1,000 | 300,000 | 3.5 | 35 |
| 10,000 | 3,000,000 | 34.7 | 347 |
| 100,000 | 30,000,000 | 347.2 | 3,472 |

Arithmetic: observations_per_day = active_devices × 300; average_s = observations_per_day / 86,400. If batches contain 30 fixes, **100,000 devices imply about 11.6 batch HTTP requests/second average**, before retries, commands and parent reads. Peak ingest will not be uniform; real-world school travel creates morning/afternoon bursts.

Illustrative **database storage**: at **0.5–1.0 KB/observation inclusive of representative row/index overhead**, 30 million/day is **15–30 GB/day** for raw/index footprint alone; approximately **450–900 GB over 30 days before WAL, backups, derived tracks, replication and compaction**. This is a sizing scenario, not a measured PostgreSQL row size.

Capacity rules:
1. Benchmark real payload compression, index size, WAL volume and DB writes at 1k, 10k, 100k devices.
2. Size API/DB pool independently; an async network stack cannot eliminate DB bottlenecks.
3. Use admission control and backpressure. Return bounded retries with Retry-After; child retains local queue.
4. Keep parent history requests paginated; no “give me all five years” unbounded query.
5. Start with **one primary Postgres, managed backups, durable worker queue and 2 API replicas** as a candidate production topology; prove performance before increasing complexity.
6. When DB becomes the bottleneck, first improve batching, partitions, indexes, read replicas and materializations. Only then evaluate broker or sharded storage.
7. Define **per-family quotas and fair scheduling**; a single abusive tenant must not monopolize worker CPU/DB or unlimited stored history.
8. Expiration/retention removes data through partition retirement where legally compatible, with per-user deletion handled separately; dropping one time partition is not equivalent to deleting an individual family.

### Candidate SLOs, to validate in load tests

- Authenticated ingest acknowledgment: p95 < 300 ms under nominal target workload (tentative).
- Latest-position parent read: p95 < 250 ms on warm read path (tentative).
- Recent committed data processed into provisional trip state: p95 < 60 seconds under nominal conditions (tentative).
- Work queue backlogs and user-facing freshness must degrade gracefully during mobile outage.
- Data durability and tenant isolation have priority over strict low-latency objectives.

These are **targets, not measured claims or service guarantees**.

## 13. Security, privacy and abuse-resilience model

### 13.1 Primary attack paths

| Threat | Likely impact | Prevention and verification |
|---|---|---|
| Parent A reads Parent B's child history (BOLA/IDOR) | Extreme location privacy breach | Controller grant check + tenant RLS + cross-tenant negative tests |
| Guess/replay child's device ID | Spoofed uploads or access | Unique per-device non-exportable credentials, TLS, replay/idempotency protection |
| Account takeover | Full history exposure | Passkey/OIDC, MFA/step-up for sharing/export/delete, session anomaly/revoke |
| API floods and giant uploaded batches | Service outage/cost runaway | Rate/size/decompression limits, bounded work and per-tenant quotas |
| Untrusted precise location in logs | Indirect privacy leak | Redact coordinates, names, device tokens and auth headers from ordinary logs |
| Wrong parent invited/shared with child | Unauthorized long-term surveillance | Explicit invite approval, narrow grants, periodic review, immediate revocation |
| Spurious GPS jumps/mock fixes | False emergency/visit reports | Accuracy and plausibility labels, no overclaim of physical truth |
| Offline stale route shown as live | Misleading safety conclusion | Latest observed_at, stale indicators, data gaps, NOT_TRACKING state |
| Cross-tenant cache/SSE data leak | Hard-to-detect unauthorized view | Tenant-scoped cache/channel keys, auth on stream connect and revoke |
| Compromised worker queue | Altered derived history | Internal job identity, reconciliation against immutable raw source, audit |
| Cloud or backup compromise | Massive location history leak | Least privilege, encryption, KMS access logging, restore/deletion verification |
| Tracking after permission/access revocation | Privacy violation | On-device permission checks, pairing/grant revoke, reject new ingest, deletion policies |

### 13.2 Authentication and encryption

- Parents: federated OIDC/passkeys with PKCE on public clients, secure refresh lifecycle, session revoke and optional step-up authentication.
- Devices: securely enrolled per-device Keystore key and short-lived credentials; consider signed proof of possession. Bind to enrolled device_id. Plan key rotation/recovery without silent takeover.
- API transport: TLS 1.2+ with 1.3 preference, approved cryptographic libraries, no custom crypto.
- Backend: secrets in managed secret store/KMS; at-rest encrypted databases/backups; restricted backup operators and audited admin access.
- Storage: encrypt child's local queue using an Android Keystore–backed key/envelope scheme with tested crash/restore behavior. Never claim standard SQLite is encrypted by itself.
- Parent's optional Drive use: OAuth narrow scopes, revocable token storage, only approved media; avoid routing raw location history through Drive unless explicitly required and disclosed.

### 13.3 Consent, transparency and data lifecycle

- Parental setup must be an authorized, transparent experience on the child's device; app identity, Play disclosures and persistent monitoring notifications remain visible as required.
- Permissions can be revoked. Degraded state is a valid response, not a reason to attempt OS bypass.
- Offer per-feature enable/disable, pairing revocation, history-retention choices, account export/deletion and accessible public deletion request path for Play.
- Example **policy choices** for design discussion: raw location 7–30 days; derived trip history 30–90 days; longer history only with explicit plan/consent. Final values require product/legal signoff and deletion implementation.
- On grant revoke, cancel further access, invalidate caches/streams, reject unauthorized queries; separate revocation of future collection from deletion of existing retained history.
- Background location on Android/Google Play requires a legitimate core purpose and appropriate declaration/reviewer evidence; comply with applicable child privacy laws.
- Do not conflate “parent owns the phone” with blanket legal authorization for any form of surveillance.

### 13.4 Deletion in time-partitioned architecture

Individual account deletion must remove relevant rows across all time partitions, derived rows, caches, pending jobs and storage; track deletion job progress with retries. Global partition drops can efficiently enforce oldest-history retention but cannot replace per-family deletion. Prevent child late-batch reingest after revocation/deletion with tombstone/credential checks. Backup retention and restore must not resurrect deleted data.

## 14. Operational reliability, observability and disaster recovery

Track metrics **without raw location payloads**:
- Authenticated ingest rate; 2xx/4xx/5xx; duplicate ratio; per-tenant quota rejection; queue depth/oldest age.
- Worker lag per device and global p50/p95; number of provisional/revised trips.
- Latest-fix age, missing-data rate, battery profile outcomes from opt-in diagnostics.
- Postgres query latencies, partition count, WAL volume, replication lag, lock waits and dead letters.
- SSE connected parents and per-account fanout.
- Cross-tenant authorization denials, anomalous pairing, credential rotation and deletion queues.

Failure modes:
- **Device offline:** encrypted queue, last seen remains stale.
- **Backend overloaded:** return retryable response; client exponential backoff with jitter.
- **API replica crashes before commit:** no ack; safe retry.
- **API replica crashes after commit:** duplicate event detected.
- **Worker crashes:** expiring lease; idempotent reconstruct.
- **DB unavailable:** fail closed for ingest/admin operations rather than claiming success.
- **Late event:** bounded recompute with revision.
- **Subscription expired:** parent entitlement changes server-side; retain/deletion governed by announced policy.

Deploy with environment-isolated secrets and staging; use immutable versions, rolling or blue/green updates where appropriate, schema migrations with rollback, synthetic-data load tests, secure backup restore practice and incident playbooks.

## 15. Test strategy

### 15.1 Unit/replay tests — deterministic C++

Synthetic and recorded **consented** test journeys:
1. 30 seconds at a traffic light => not a visit.
2. Six minutes parked => provisional or confirmed stop depending on quality.
3. Multiple stops inside one journey => one trip with multiple legs, stop IDs and time windows.
4. GPS drift 200 m while stationary => not an invented excursion.
5. Underground tunnel with missing fixes => separate segments and explicit GAP.
6. Offline batch arrives three hours late => trip recomputation, correct event-time order.
7. Overlapping/replayed events => no double distance or duplicate visits.
8. Fast train/highway journey => no overzealous speed-filter deletion.
9. Two phones/watches assigned to one child => source-handoff policy is explicit.
10. Changing known-place title/radius => restated matching without altering historical observations.
11. Approximate-only location => honest uncertainty, no exact arrival proof.
12. Same location but time zone/DST change => UTC storage, correctly rendered local day/stop durations.
13. Overlapping saved places => ambiguous label, not an arbitrary named visit.
14. Stale worker and lease expiry => only current version can commit.
15. Family access revoked during SSE session => further updates cease.

### 15.2 Integration and property tests

- PostgreSQL transaction atomicity (raw event + processing outbox), restart recovery, idempotency.
- RLS and controller ACL: two families with colliding display names; attempt every cross-family read/write/export and device spoof.
- Large protobuf/JSON malformed/zip bomb inputs; bounded memory and quota response.
- DB partition boundary replay/dedup events.
- Confirm metric and log pipelines don't contain full location payloads.
- Simulate API node death, Postgres failover, queue-worker timeout, Redis eviction, backup recovery, delete request.
- Permission/FGS denial and monitoring notification tests on physical Android devices (10–16 support matrix if still in scope).
- Watch device with/without GPS and disconnected from paired phone.

### 15.3 Load and chaos tests

Use synthetic, non-identifying tracks with configurable device distribution. Test **1k, 10k and 100k simulated enrolled devices**, including school-hour bursts, 1% malicious/invalid batches, high read concurrency, sync after network blackout and hot devices sending many points. Record:
- p50/p95/p99 API latencies and DB WAL/CPU/connection counts.
- queue catch-up time and trip reconstruction CPU seconds per 1,000 events.
- memory/CPU per API replica and per worker;
- total bytes stored including indexes/WAL, parent map response sizes;
- absolute error in stop detection and trip segmentation vs labeled ground truth.
- cost per 1,000 active devices / per 1 million points and cloud mapping API spend.

### 15.4 Acceptance gates

**No feature is marked production-supported without recorded evidence.**
- Raw ingest loss after acknowledged commit: zero in fault tests.
- Unauthorized cross-family access: zero in automated tests.
- Every trip/stop includes source, revision and quality/confidence.
- Stop false positives/negatives measured against annotated test journeys.
- Route geometry gaps clearly displayed.
- Duplicate events counted exactly once.
- Parent view does not increase child GPS sampling without a separate permitted tracking-policy request.
- Battery delta measured on each device family; no universal percentage claim.
- Roads API only enabled after its required commercial/license/retention approval.

## 16. Implementation roadmap and dependencies

| Stage | Deliverables (how) | Why now / completion gate |
|---|---|---|
| **A0: Architecture freeze** | Device/API support matrix, privacy model, guardian grants, retention, SLO goals and package/Play constraints | Prevent redesign of tenant boundaries; design approvals |
| **A1: C++ backend foundation** | Drogon HTTP, OIDC integration, device pairing, RBAC, database migrations/RLS, test harness | All access tests pass; logs redact location |
| **A2: Durable telemetry ingest** | Validated batch API, event dedupe, time partitions, outbox + queue, load tests | Committed ack; retries/duplicates safe; 1k scenario passes |
| **A3: Android adaptive collector** | Foreground location workflow, motion hints, encrypted buffer, batching, mode policy, permissions | Physical-device accuracy/drain/offline tests |
| **A4: C++ reconstruction V1** | Quality filter, ordered segmenting, stop detector, trip/leg model, provisional revision | Deterministic replay and recovery tests |
| **A5: Parent map and saved places** | Named markers, latest position, trip polyline, stop timeline, API projection/cache | Cross-family ACL tests; no extra GPS use on view |
| **A6: Scaling & operations** | Horizontal API replicas, worker pools, partitioning retention, quotas, backups, chaos/load | 10k/100k scenario benchmark and cost decision |
| **A7: Device/product extensions** | Multi-watch/tablet source selection; optional place alerts; usage activity integration | Device-specific validation and reliability |
| **A8: Optional Roads integration** | Dense-vehicle matching behind cost/license flag | Commercial license, content restrictions and test proof |
| **A9: Release compliance** | Play Data safety, background location demo, app listing, deletion URL, billing, AAB and 16 KB native libs | Review approval and publication checklists completed |

**Suggested first vertical slice:** enroll one child device, store timestamped positions with true idempotency, produce one provisional trip/stop stream on a C++ worker, and show one parent's map. Add more parents, watches and roads matching only after that slice is measured.

## 17. Key engineering difficulties and mitigation ranking

| Rank | Difficulty | Why it is hard | Mitigation / decision |
|---|---|---|---|
| **Critical** | Cross-family authorization/data isolation | A single IDOR can expose a child's complete location history | Explicit grant model, transaction-scoped tenant RLS, negative security testing |
| **Critical** | Background Android reliability vs battery | Requested sampling rate not guaranteed; OEM power and FGS restrictions | Android-compliant tracking service, adaptive profiles, honest stale state |
| **High** | Event-time ordering and offline correction | Upload order differs from travel order; derived trips may change | Per-device serialization, event-time watermarks, revisions and backfill |
| **High** | Stop recognition with GPS jitter | Home vs bus stop vs traffic light or urban canyon can look similar | Dwell thresholds, hysteresis, uncertainty scoring and labeled datasets |
| **High** | Multi-device/watch provenance | Watch may use phone fix or lose standalone GNSS | Separate source identity, explicit handoff rules, no blind merging |
| **High** | Database growth and tenant deletes | Tens of millions of points/day create storage/WAL/retention costs | Batching, time partitions, retention jobs, indexed bounded queries |
| **High** | Real-time fanout + fair scaling | Many parents watching must not starve ingest or wake child GPS | Independent read path, cache, bounded SSE/connection quotas |
| **High** | Google Roads licensing/accuracy | Sparse tracks cannot prove exact street travelled; asset license may apply | Raw polyline baseline; gated dense matching only with approval |
| **Medium** | C++ memory/concurrency safety | High-throughput parsers/workers can create races/use-after-free | RAII, sanitizers, fuzz testing, immutable message structures, bounded pools |
| **Medium** | Geofence false alarms | GPS uncertainty and delayed event delivery | Optional alerts, dwell, hysteresis, no instantaneous guarantees |
| **Medium** | Play privacy/billing/reviewer rules | Publishing a functioning APK is not the same as policy approval | Release matrix, monitoring identification, Data safety and reviewer evidence |
| **Medium** | Battery claims and hardware variety | Location cost changes across devices/conditions | 24h idle + moving comparative tests, configurable modes |

### Priority decisions

1. **Privacy isolation first**, not an afterthought; raw child's GPS is highly sensitive.
2. **Raw, defensible route history before road-matched aesthetic geometry.**
3. **Adaptive collection on child, expensive inference on C++ server.**
4. **Durable, idempotent batched ingest before “live” dashboards.**
5. **Algorithm versioning and late-data corrections from the beginning.**
6. **Do not optimize by guessing:** tune from CPU/memory/battery, WAL, queue-lag and stop-accuracy measurements.
7. **No covert tracking behavior.** A parent configuration wizard does not eliminate system notifications, privacy requirements or Android restrictions.

## 18. Open decisions / owner signoff matrix

| Decision | Initial recommendation | Required approver |
|---|---|---|
| Minimum Android version | API 29 as candidate; test API 29–36 | Android lead |
| Supported phone manufacturers | Pixel + selected common OEMs to start | QA/product |
| Single parent vs shared guardians | Explicit multi-guardian grants in one family | Product/security |
| Raw retention | 7–30 days candidate, selectable where legally allowed | Product/legal |
| Derived history retention | 30–90 days candidate; may vary by subscription | Product/legal |
| Exact route detail mode | Time-limited explicit activation, not 24/7 | Product/Android |
| Stop dwell and proximity | Start 3–5 min walk, 5–10 min vehicle; accuracy adaptive | Geospatial/QA |
| Real-time latency target | Display latest qualified fix + timestamp, no fixed guarantee | Product/QA |
| API scaling threshold | DB queue initially, partitioned broker after bottleneck proof | Backend/ops |
| Roads API use | Off by default until commercial license and caching review | Legal/product |
| Hosting region & vendor | TBD; minimize data movement and select child-data safeguards | Security/legal |
| Subscription entitlement | Backend authoritative; no child-paid tier logic | Billing/security |
| App distribution model | Parent and child releases separately reviewed for Play | Policy/release |

## 19. Deliverable definition and out-of-scope work

This is a **technical design** suitable for implementation planning. It does **not** create executable C++ services, SQL migrations, Android apps, security certification, battery benchmarks, commercial Roads API license or actual Play Console approval. Those require the test artifacts and deliverables described in the roadmap.

Future design revisions must record an ADR/change log: description, reason, alternative, security/privacy effect, performance cost, migration plan and device evidence. Avoid making undocumented optimizations that change tracking truthfulness or parental access control.

---
**Document owner:** Madalasa–Alarka project architecture  
**Review status:** Awaiting implementation and device validation  
**Primary references:** official Android, Google Maps Platform, PostgreSQL/PostGIS, Drogon and OWASP sources linked in section 1.

## 20. Coordinating app usage, remote operations and subscription work at scale

Location is the highest-volume write path, but Madalasa–Alarka also needs application usage summaries, limited remote control commands, guardian access, subscription checks, and possibly Drive backup. **Do not execute all these in the same priority queue or database transaction.**

### 20.1 Priority and workload isolation

| Workload | Character | Preferred execution path | Throttling / isolation |
|---|---|---|---|
| Telemetry ingestion | High-volume small writes | Dedicated Drogon API handler + batched PostgreSQL commits | Device quotas, per-family budgets, bounded DB pool |
| Trip reconstruction | CPU-heavy, asynchronous | Separate worker queue keyed by device | Fixed CPU concurrency, catch-up SLO |
| App-usage aggregates | Moderate volume, delayed | Separate batch ingestion and scheduled C++ aggregation job | Coalesced daily intervals, no per-second usage updates |
| Parent map/history reads | Latency-sensitive | Parent read endpoint + latest position cache, indexed history | Pagination, per-family read budgets |
| Restriction policy application | Low volume, time-sensitive, device-dependent | Authenticated command queue; local Android DPC enforcement when eligible | Audited, TTL, idempotency, device capability validation |
| Subscription renewal and provider callbacks | Low volume, high integrity | Protected billing webhook inbox + entitlement worker | Signature validation and exactly-once business effect using idempotency |
| Media/Google Drive | Large payload, bandwidth intensive | Dedicated upload pipeline only for approved/authorized functionality | Separate bandwidth/object-size quotas, isolated transient storage |
| Retention and deletion | Expensive batch work | Scheduled protected maintenance queue | Rate-limited with privacy priority and deletion completion evidence |

### 20.2 Usage activity pipeline

The child UsageStats adapter obtains permitted coarse-grained per-package foreground duration and event timestamps after Usage Access is granted. It periodically constructs records of the form:

~~~json
{
  "device_id": "enrolled-device-uuid",
  "interval_start": "2026-10-25T00:00:00Z",
  "interval_end": "2026-10-25T01:00:00Z",
  "package_name": "org.example.app",
  "foreground_duration_ms": 123000,
  "collection_revision": 4
}
~~~

- Child locally coalesces intervals to limit network/CPU cost; avoid unnecessary 1-second polls.
- API validates device credentials and family/child ownership, timestamps, nonnegative durations, interval boundaries and idempotency.
- Server stores permitted usage aggregates in a separate table and aggregates day/week/month/year using the user's declared reporting timezone.
- Missing Usage Access or OS history is recorded as unavailable/partial, not **zero minutes**.
- Usage worker concurrency and database connection budget must not starve GPS event writes.

### 20.3 Remote command queues and fairness

- Parent submits only actions authorized for specific child/device mode and subscription.
- A command record contains actor, tenant, device, type, issue/expiry time, idempotency key, policy version and requested capability; route to a **separate** queue from trip analysis.
- Child confirms execution with status (QUEUED/ACCEPTED/COMPLETED/OS_REJECTED/UNSUPPORTED/etc.). Backend never marks operation successful on delivery alone.
- Restriction policies execute only via supported Android management APIs on properly managed devices; ordinary install cannot grant device-owner rights.
- Make policy execution idempotent and permit rollback; never suspend protected critical packages.
- Parent commands must not trigger expensive continuous GPS or unrelated child collection merely because a dashboard is open.

### 20.4 Workload budgets and fairness policy

A single family may own multiple devices or have multiple guardians watching. Enforce:
- Token bucket limits by device for telemetry, by guardian for reads/commands, and by family for total work.
- Limits on history date ranges, active SSE subscribers, named places, uploaded file size and queue depth.
- Fair work leasing across families so one large enterprise-sized family or a compromised device cannot starve smaller families.
- Privacy-critical revocation and credential invalidation take priority over nonessential historical recomputation.
- Report partial/degraded service rather than silently discarding accepted events.

### 20.5 Architecture review checklist

- [ ] Location ingestion cannot be blocked by app-usage aggregation or media upload.
- [ ] Subscription cancellation or guardian revocation is enforced on every authorized API call.
- [ ] API and worker SQL roles do not bypass each other's tenant rules accidentally.
- [ ] All queues are durable, bounded, retried and idempotent.
- [ ] Device ingestion returns committed receipts with accepted/duplicate/rejected counts.
- [ ] Redacted logs and deletion processes cover raw and derived tracking/usage information.
- [ ] Play Data safety reflects each released collection category and processor.

## 21. Feedback-derived reliability and product differentiation workstream (2026-10-25)

See [Market Feedback, Competitive Gaps & Feasible Differentiation](../../M0-foundation-and-approvals/02-market-and-feasibility/MARKET_FEEDBACK_GAPS_AND_DIFFERENTIATION_2026.md). Additive technical proposals include quality/explanation codes for GPS events, health snapshots with independent fix/receipt/reconstruction timestamps, revision audit for offline late-arriving tracks, per-child time-bounded guardian grants, low-noise commute-alert classifications and privacy access receipts. These fit the existing event-time C++ reconstruction, Drogon API and PostgreSQL/PostGIS architecture; they do not justify continuous extra child GPS sampling or bypass OS constraints. Status: **research proposals only**, requiring labeled route tests, tenant authorization security review and battery measurements.

## 2026-10-27 accepted server pipeline: PostgreSQL durable inbox + C++ BULK inserts (supersedes raw-at-HTTP-ACK-only example)

**Decision:** [MA-INGEST-ADR-004](POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) is the current target for FR-003/004/005/018/023/025/026. Alarka independently records battery-adaptive, OS-permitted GPS fixes into its encrypted on-device SQLite queue (up to **48-hour offline capacity target**, subject to storage/OS conditions); it targets authenticated JSON upload every **1–2 minutes where allowed**, rather than waking radios and GPS at the same interval. Bulk-upsize at the phone and independently at the server. Smartphone and Wear OS devices retain separate source IDs; a child is not a device.

**Two-stage durable pipeline:** (Tx A) Drogon validates paired device/tenant/batch_id/event_ids/sizes and commits **one inbox row per upload batch** to PostgreSQL before returning **HTTP 202 processing=QUEUED**. The ACK means **durably accepted in inbox**, not final raw GPS insert nor trip processing. (Tx B) independent C++ workers use short `SKIP LOCKED` leases, regroup queued observations (initial 100–500-point bulk target), atomically commit canonical `device_event_dedup`, partitioned `location_observations`, trip-reconstruction outbox and inbox PROCESSED status. Benchmark prepared multi-row `INSERT ... SELECT` vs `COPY FROM STDIN` into temp staging then validated/dedup insert. On crash/replay/out-of-order packets protect accepted IDs and re-lease; no long-running route algorithm on API event loop.

**Resource caveat:** This scheme adds temporary stored copies, WAL and worker I/O versus **direct raw bulk+dedup+outbox commit** on the API transaction. Run identical synthetic 1k/10k/100k device/load/outage benchmarks before freezing deployment economics or promising fewer resources. Default design remains inbox+bulk, Redis **not required**; optional read cache/broker only after evidence. Parent location reads committed latest/processed history and discloses last observed/ingested/reconstructed times; do not confuse queued data with live movement. Use existing Android 11+ location/FGS rules and WorkManager min 15-minute periodic floor; user-visible 1–2 min is a target, not a guarantee.

**The earlier sections in this document that show the direct raw+dedup+outbox DB commit during the API POST are retained only as the benchmark OPTION B**, not as the current preferred path. The raw-commit success claim is replaced by the explicit two-level inbox/worker commit semantics. T-ING-01…24 remain NOT_TESTED; India child-data and Google Play release gates still block real-minor pilots. [Editable GPS ingestion HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-2), [LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-60), [trade-off](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-126).
