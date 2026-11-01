# Parent-app inactivity adaptive location policy — seven-day tiered economy

> Document control: M2 / 01-location-collection-and-ingestion. Owner-requested design decision 2026-11-01. Status: DESIGN APPROVED FOR PLANNING; NOT IMPLEMENTED, DEVICE-TESTED OR PLAY-APPROVED. All timing values are configurable **initial test targets** rather than Android delivery guarantees. Synthetic-data testing only until the applicable legal, consent and Play gates are passed.

## Decision and intent

If **no authorized guardian opens Madalasa in the foreground for seven consecutive days**, Alarka reduces the routine location *request frequency*, applying a more aggressive reduction to a free family than a subscribed family. An authenticated human-visible foreground event is required; passive sessions, push delivery, notification display, app process wakeups, background refreshes, bot polling and child-device connectivity are **not** evidence of parent engagement.

The policy minimizes battery use and unnecessary location handling while preserving verified consent, account security and important safety actions. **Subscription status must never override denial/revocation, Android OS permission, or legal restrictions.** A subscriber gets a higher requested sampling rate but no bypass of the OS.

## Proposed initial profile matrix

All values are adjustable within the hard server bounds below, subject to battery and platform constraints. Distance floors and motion hints remain governed by TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md.

| Entitlement and guardian inactivity | Moving requested fix interval | Stationary requested fix interval | Routine upload/batch target | Operational meaning |
|---|---:|---:|---:|---|
| FREE, last foreground <7d | 1–3 min | 10–15 min | 5–15 min | Default economic free tracking |
| PAID, last foreground <7d | 30–90 sec | 5–10 min | 1–5 min | Higher routine responsiveness |
| FREE, >=7d | 20 min | 60 min | 30–60 min | Deep economy; substantial history gaps |
| PAID, >=7d | 5 min | 20 min | 5–15 min | Economy but more frequent than free |

Avoid promised exact fresh-position SLAs. A location request interval is an Android hint; Doze, network absence, OEM throttling, approximate-only grants and permission restrictions can produce longer gaps. Motion mode unknown => select stationary/low-power until credible evidence arrives, not assumed continuous high-accuracy.

## Seven-day clock and multi-guardian semantics

1. Backend persists `family_last_authorized_parent_foreground_at` as UTC timestamp only from an authenticated, rate-limited **foreground event** associated with a live family membership and a valid family scope; server time is authoritative, not a caller-provided timestamp. No raw GPS required. Never interpret bearer renewal alone as user interaction.
2. The clock is per family, not per child device or per guardian; any live explicitly authorized guardian actually opening the app resets it for that family. Every child/device uses only the relevant family policy. For blended/cross-family children, a live authorized **child-level** viewer from another family must not be silently discounted: use latest valid viewer engagement for the child across their scoped family contexts without exposing identities or data across families.
3. At 168 hours (7x24h) without such an event enter `INACTIVE_ECONOMY`. **Never move to economy solely because the server lacks prior events**: use `UNKNOWN_ENGAGEMENT`, a documented conservative limited mode with setup grace, and request a policy resync. Prevent accidental suppression immediately after enrollment.
4. Reset to `ACTIVE_PROFILE` on the next verified guardian foreground event. Do not ask the parent to manually re-enable permitted tracking. Restrict duplicate presence events to one per session per 5 minutes and impose per-family rate limits.
5. Subscription tier must come from a verified backend entitlement snapshot (including validity and effective child seats), not UI hints, device flags or stale local paid receipts. Fail closed on paid-only privileges; on entitlement uncertainty use the safer authorized baseline, not a higher paid rate.
6. On each policy refresh, backend sends a **signed, versioned, expiring, device-bound** policy to Alarka. Child applies only a monotonic version for the correct device and checks expiry, permissions and consent locally. Suggested maximum online refresh age: 6 hours; evaluate implementation-specific offline grace and revoke channels before release. Offline cached policies must never re-enable a revoked collector.

## Adjustable server configuration — bounds

The operator may tune requested moving interval, stationary interval and routine upload target independently for FREE_ACTIVE, PAID_ACTIVE, FREE_INACTIVE and PAID_INACTIVE profiles, but MUST satisfy:
- Moving interval [30 sec, 60 min]; stationary interval [5 min, 120 min]; upload target [1 min, 120 min]. No zero/negative values.
- For corresponding ACTIVE/INACTIVE movement categories: `PAID_INACTIVE` must request more frequent fixes than `FREE_INACTIVE` (numerically smaller interval); likewise stationary. The active paid tier should normally be at least as responsive as active free.
- Inactivity must not increase routine sampling over the same entitlement's ACTIVE profile. Do not push values that exceed a device's evidenced battery budget or Play/OS eligibility.
- Parameter updates require server-side policy version increment, review/audit record, safe rollout, measurable rollback and client-side validation; neither an unauthenticated API caller nor the child device can choose a higher-frequency paid profile.
- `minimum_interval` must reflect chosen fastest callback bound; batching target must never be mislabeled as guaranteed delivery. Existing motion-mode residence/hysteresis applies. Limited car-detail mode, if allowed, remains separately time-bounded and is not automatically activated by family tier.

## Safeguards, emergency exceptions, revocation

- Non-negotiable priority order: **legal/Play eligibility → consent and child grant authority → OS permissions/lifecycle/service rules → device/user opt-outs → explicit time-limited safety workflow → tiered routine economy → battery/thermal lower-power adjustments**.
- Revocation, account erasure, consent expiry, device unlink and OS permission withdrawal stop collection as soon as the device receives or determines the state; asynchronous disconnection is never treated as permission. Persist revocation fences and never replay buffered points across invalid authorization.
- SOS initiated on the child device, if separately implemented, is not throttled by inactivity tier. Notifications, bounded last-known-location sharing and explicitly authorized safety workflows may use a separately limited, auditable eligible Android mode; do not silently force high-accuracy GPS or bypass denied permissions. No guarantee of emergency dispatch.
- A parent opening the app does **not** itself trigger fresh GPS. Parent reads cached last-qualified location until an independently authorized, bounded fresh-location request is available.
- Keep visible Alarka branding, monitoring notice where required, privacy indicators and authorized settings; never silently hide the app or suppress OS controls.
- Never drop authentication, TLS, key binding, anti-replay, RLS, encryption-at-rest, tenant scoping, rate limits, log redaction, idempotent inbox writes or revocation checks to meet power/network targets.
- Present **last observed**, source accuracy and `INACTIVE_ECONOMY` reason on the parent map; no stale point may be called LIVE. Inform a parent that routine updates were reduced, without coercive payments or misleading "child unsafe" claims.

## Architecture / delivery plan

### M2-A — backend policy and engagement
- Add an authenticated foreground-event endpoint (or extend a versioned session activity endpoint) with an explicit purpose; validate trusted parent session, guardian membership, child/family scope, event freshness, replay and abuse limits.
- Create a minimal engagement ledger with UTC last-valid-event, sanitized audit fields, retention/erasure ownership and RLS. No location or app-usage event collection is needed for this clock.
- Add versioned profile configuration and family/child derived policy resolution using server-side subscription entitlements. Use family/child scoped authority, including blended-family policy ambiguity tests.
- Add an authenticated device policy read/delivery protocol; signed payload includes device ID, policy version, entitlement profile, engagement state, issued/expiry times, min intervals, min distances, batch bounds and safety feature gates.
- Add observability on policy transitions and fix/upload counts by tier without exposing raw child routes.

### M2-B — Alarka Android
- Implement Kotlin `SamplingPolicyReducer` as a pure state machine: input signed policy, consent, permission, OS lifecycle, motion, battery, thermal, latest revocation and time; output requested eligible `LocationRequest` mode or STOPPED.
- Use `setIntervalMillis`, `setMinUpdateIntervalMillis`, `setMinUpdateDistanceMeters` and `setMaxUpdateDelayMillis` where supported, with stable motion hysteresis; do not repeatedly restart listeners for noisy motion signals.
- Preserve encrypted durable queue, authenticated batch uploads, backoff and provenance. Sparse points must yield GAP/UNKNOWN route segments, not invented trip geometry. Do not claim 48h buffer means ongoing capture is guaranteed.
- Add transparent child-visible readout of active routine policy and cause. Never use silent background location permission workarounds.

### M2-C — Madalasa Android
- Emit foreground engagement only after verified session and visible resumed Activity; throttle locally and server-side. No inferred user interest from background calls.
- Present last confirmed location timestamp, quality, lower-rate notice and explicit update limitations. Subscription and history access remain independently authorized.
- On successful foreground engagement, backend policy refresh can restore normal sampling asynchronously when device next connects; do not show restored until acknowledged by child.

### M2-D — synthetic QA and rollout gates
- Unit tests: 167h59m vs 168h, UTC clock skew, replay, duplicate events, multi-guardian and blended-family scope, free/paid expiry, fallback on unknown entitlement, signed policy expiry/reorder, revocation/permission wins over tier, emergency independent of inactivity.
- DB/HTTP tests: unauthorized household cannot reset clock; free caller cannot assert paid, RLS prevents cross-family reads; no raw location in telemetry; replay/idempotency.
- OEM matrix: Android versions, stationary/moving/Doze/reboots, app force-stop, OEM battery saver, coarse-only, dual-SIM/offline, FGS rejected, unauthorized background start; record battery drain, delivered fix p50/p95, stale-map rate and update/byte volume.
- Compare free inactive vs paid inactive delivered updates under matched eligible device conditions; do not fake proof from requested intervals. Gate rollout behind policy/legal/Play approvals and a reversible remote configuration switch.
- Suggested graduation: synthetic tests → adult-owned lab devices with opted-in test accounts → compliance review → staged pilot only when lawful/eligible → production monitoring.

## Official technical references (reviewed 2026-11-01)

- Android background location and battery: https://developer.android.com/develop/sensors-and-location/location/battery
- Android LocationRequest builder: https://developers.google.com/android/reference/com/google/android/gms/location/LocationRequest.Builder
- Android background location limits: https://developer.android.com/about/versions/oreo/background-location-limits

The existing M2 adaptive motion rates remain relevant; this document defines an additional **commercially tiered, foreground-engagement-dependent ceiling/profile** for routine collection, not replacement of emergency, consent, security, history retention or Android OS constraints.
