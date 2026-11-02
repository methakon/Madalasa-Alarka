# Madalasa–Alarka — Consolidated Software Requirements Specification (SRS)

> **Document control:** M1 / 01-requirements-and-architecture · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Product names:** **Madalasa** (parent app), **Alarka** (child app). Desired repository name **Madalasa-Alarka** is **completed GitHub repository rename**. Use the verified new repository URL for all current documentation and integrations. [Naming rationale](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Document:** AP-SRS-001  
**Revision:** 1.0 integrated design baseline  
**Date:** 2026-10-25  
**Status:** Approved for engineering design; no implementation, Android hardware results or Google Play approval is implied.  
**Companion specifications:** [Whole-project Feasibility Gate](../../M0-foundation-and-approvals/02-market-and-feasibility/WHOLE_PROJECT_FEASIBILITY_GATE_2026.md), [Consolidated Technical Specification](TECHNICAL_SPECIFICATION.md), [Detailed C++ Architecture](../../M2-location-collection/01-location-collection-and-ingestion/ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md), [Route, Stop & Battery Design](../../M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md), [Privacy and Play](../../M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md).

## 1. Purpose, scope and definitions

Build a **transparent, parent-authorized Android family-safety and child-device-management platform** with the **Madalasa parent application** and **Alarka child companion**:

1. **Child Android agent** running its ordinary tracking functions after one-time parent setup without requiring the main Activity to stay open, while complying with system notifications and user-visible monitoring disclosures.
2. **Parent Android app** showing the latest observed location, quality, routes, saved named places, multiple trips/stops, usage history, permitted controls, subscriptions and family/guardian access management.
3. **C++20 Drogon backend** with PostgreSQL/PostGIS for family-scoped data, secure pairing, durable telemetry, versioned trip reconstruction, command processing, usage analytics, privacy/deletion and billing integration.
4. **Optional Wear OS/tablet and managed-device capabilities** whose support depends on actual hardware and enrollment mode.
5. **Optional clearly authorized Google Drive media backup and future media workflows**, without bypassing Android storage/privacy boundaries.

**Terms:** A **location observation** is a dated device-reported fix, not proof that the child was physically present. An **observed route** connects only trustworthy observations; missing spans are gaps. A **stop** is an accuracy-aware dwell inference. A **named place** is a parent-defined location/title. **Managed mode** requires proper Android device-owner/profile-owner provisioning, not ordinary permissions. A **guardian grant** is a revocable child-specific authorization.

## 2. Product goals and measurable outcomes

- Trustworthy safety experience: always identify observed time, location accuracy, connectivity state and source device, never claim a stale point is live.
- Reduce unnecessary child GPS/radio use with motion-adaptive sampling, local batching and server-side analysis; **numeric battery benefit must be measured**.
- Securely support many families, each with multiple guardians, children and enrolled devices, without cross-family data leakage.
- Provide understandable screen-time activity and conditional device controls, not universal block/camera/other-app-private-file promises.
- Allow parent and authorized guardian account removal/permission revocation with clear effect, restricted retention and supportable audit.
- Obtain applicable Play Console approval before releasing functionality to Play audiences; no stealth tracking.

## 3. Users, roles and enrollment modes

| Actor | Allowed responsibilities | Exclusions |
|---|---|---|
| Family owner/parent | Create child profiles, pair/revoke devices, approve guardians, manage plans/retention, view authorized reports | Cannot bypass Android system access or laws |
| Guardian | Child-specific view/notifications/actions explicitly granted by owner | No implicit access to all children or billing/admin |
| Time-limited pickup viewer | Limited current or recent location for one child until expiry | No app history, media, block controls or unlimited history |
| Child device user | View monitoring identity and enabled monitoring, optional SOS/check-in/time remaining and relevant Android Settings | Child-facing interactivity not required for every background function |
| Service operator/support | Securely administer infrastructure, limited redacted support | No default access to live location or raw media |
| Enrolled device identity | Upload its own authorized observations/status and receive authorized policies | Never view siblings/parents/other devices |

**Standard mode:** permission-based personal device. **Managed mode:** separately provisioned DPC with only actually permitted APIs. The UI and server **shall not** treat them as equivalent.

## 4. Requirement priority/status vocabulary

- **P0:** non-negotiable foundational safety/security/product infrastructure, or inclusion in the first practical engineering slice.
- **P1:** core product release/useful features after their dependencies.
- **P2:** optional expansion with measured benefit.
- **P3:** research-only, no launch commitment.
- **C:** conditional on named Android/hardware/permission/policy criteria.
- **D:** explicitly deferred/restricted.
- **NOT_TESTED:** no device or integration evidence. All project requirements are currently design-only unless a later evidence record says otherwise.

All features shall carry **DESIGNED → IMPLEMENTED → DEVICE_VERIFIED → SECURITY_VERIFIED → POLICY_VERIFIED → RELEASE_ENABLED** gates. Approval of this SRS is not implementation approval of every conditional option.

## 5. Functional requirements — foundations and device management

### FR-001 Secure parent-child pairing — P0
Use a short-lived, single-use enrollment code/QR issued by an authenticated parent. Device generates unique revocable credentials bound to an authorized child profile; no separate child username/password required for basic enrollment. Server rate-limits and audits enroll/revoke, blocks reused/expired codes, and prevents cross-family device claims.

**Acceptance:** replay/expired code rejected; revoked child credential cannot ingest; parent account cannot pair over another family's existing device without approved transfer flow.

### FR-002 Transparent permission onboarding — P0
Explain monitored data in an app-visible disclosure before relevant Android permission requests, then guide parent through runtime grants and special-access settings. Track each feature's current permission status and revocation. On-device monitoring identity/icon and required persistent notification remain visible when applicable.

**Acceptance:** permission denied, later revoked and service restricted produce truthful statuses; no false completion; no stealth mode.

### FR-003 Location observations — P1 / C
Collect UTC timestamp, lat/lon, reported accuracy, source ID and optional speed/bearing/accuracy. Respect background location permission, location FGS type, FGS-start restrictions, OS power state and device capabilities. Prefer adaptive collection with user-visible purpose; no promise of guaranteed second-by-second updates.

**Acceptance:** tests cover walking, stationary, screen off, offline, approximate location, force-stop and revocation; UI identifies last observation time/accuracy.

### FR-004 Travel and route history — P1
Persist observed positions under configured retention and display sorted trips and segments, mileage estimate with quality notes, start/end, multiple intermediate stops and explicit unobserved gaps; raw observed track is authoritative.

**Acceptance:** no directions-route substitution for unobserved roads; gaps aren't joined as certain travel; trip source device is identified.

### FR-005 Usage statistics — P1 / C
After Usage Access, collect available per-app foreground usage interval information. Backend aggregates by day/week/month/year using defined reporting timezone. Missing historical coverage is recorded as UNKNOWN or PARTIAL, not zero. Enforce limits on collection frequency/retention.

**Acceptance:** long-term report derives from stored observations; access revocation stops future collection and updates status.

### FR-006 Authenticated remote commands — P0/P1
Only authorized guardians with feature-specific grants may request time-bounded device commands. Server validates target, subscription and capability; child rechecks current Android state. States distinguish CREATED, QUEUED, DELIVERED, ACCEPTED, COMPLETED, EXPIRED, DEVICE_OFFLINE, PERMISSION_REQUIRED, USER_ACTION_REQUIRED, OS_REJECTED, UNSUPPORTED, FAILED and CANCELLED.

**Acceptance:** a delivered command is not reported as completed; stale/replayed/expired requests cannot execute.

### FR-007 Scheduled screen-time restrictions — P2 / C managed
Support schedules and eligible per-app restrictions with visible reasons and safe exceptions. Enforce package suspension **only** through public supported device-policy APIs for correctly enrolled authorized DPC; preserve critical apps and allow reliable rollback. Standard mode does not advertise universal blocking.

**Acceptance:** safe suspend/restore on managed test phone; excluded system apps never blocked; ordinary app returns UNSUPPORTED_POLICY.

### FR-008 File/media access — P2 / C
List, preview and transfer only app-owned or appropriately authorized MediaStore/Storage Access Framework files. Never promise arbitrary other-app private directories, password extraction, or OS sandbox bypass.

**Acceptance:** authorized URI works; revoked grant and other app-private paths fail securely.

### FR-009 Authorized photo/video request — P3 / D
Parent UI may present **only certified, policy-approved, clearly authorized visible** capture workflows. Backend checks device/version/capability before dispatch and child verifies actual OS execution permissions; privacy indicators remain intact. Feature is disabled by default and never marks a command complete absent verified persisted media.

### FR-010 Authorized audio capture — P3 / D
Same transparency, lifecycle, permissions, child rights and truthful status principles as FR-009. No covert listening, hidden mic indicator or unrestricted background recording promise.

### FR-011 Google Drive backup — P2 / C
Parent separately enables OAuth with narrow scopes for explicitly authorized media. Secure token lifecycle, resumable transfer, checksum, cancellation, revoke and distinct deletion responsibilities are required.

### FR-012 Subscription entitlements — P1 commercial
Use required Google Play Billing flow for applicable digital purchases; backend verifies provider events/purchase tokens and implements active, grace, hold, cancellation, expiry, refunds and restoration. Do not imply payment grants Android privileges.

### FR-013 Privacy, retention and deletion — P0
Provide device unpair, guardian revoke, purpose-specific enablement, account export/deletion, integration revoke, bounded retention, encrypted sensitive fields/backups and supported public web deletion request. Deleting a family prevents late event reingest and removes authorized histories/derived material according to the published policy.

### FR-014 Operational status and notifications — P1
Parent shows last_seen, last_fix, accuracy, tracking mode and reasoned device status; alerts for requested high-value events, not uncontrolled repeats. Sensitive lockscreen details are minimized; alert acknowledgement/delivery states are recorded.

## 6. Functional requirements — maps, routes, multi-device scaling

### FR-015 Parent-defined named places — P1
Add/edit/delete titled coordinates by long-press, search or dragging marker. Title, category, optional description, radius, visibility and child/family ownership. Markers render from stored parent/backend data without waking child GPS merely because the map opens.

### FR-016 Observed route reconstruction — P1
Render chronological segmented Google Maps polylines from source observations with accuracy/gap legends, playback and historical time selectors. Optional Roads API only after licensing/cost/retention/coverage checks; do not treat suggested directions as history.

### FR-017 Multiple trip legs and stops — P1
C++ pipeline detects trips, walking/vehicle pauses and accuracy-aware dwell points, using configurable thresholds and hysteresis. Stop labels only match parent named places when evidence supports dwell; near-passing does not imply visit.

### FR-018 Adaptive power-aware tracking — P1
Implement low-power, balanced and bounded detailed tracking modes; use Android supported fused/passive fixes and optional Activity Transition hints. Sampling policy reacts to movement, accuracy, power constraints and permission; parent viewing does not automatically increase child sampling.

### FR-019 Optional map matching — P2 / C
Only eligible dense vehicle route segments are optionally road-matched by backend respecting provider licensing, quotas, point limits and content caching rules. Sparse or uncertain segments fall back to observed route with honest gaps.

### FR-020 Phone/tablet/Wear provenance — P1 data model / P2 watch support
Preserve per-device source of each observation; show approximate accuracy/hardware capability. No unverified splicing of watch and phone data; optional explicitly logged source switch. Detect no-GNSS and paired-device dependence.

### FR-021 Selected named-place alerts — P1 / C
Support opt-in enter/exit/dwell and arrival/departure event candidates using server proximity analysis and, where eligible, a **limited** subset of Android geofences. No immediate-entry guarantee; confidence, delay and hysteresis displayed.

### FR-022 Child-specific family/guardian permissions — P0
Authenticated roles and fine-grained child grants; no implicit data sharing with all parents. Model child owner, approved guardian, restricted viewer, and device identity. On grant revocation terminate sessions/streams and invalidate cached access.

### FR-023 Durable idempotent ingestion — P0
Event IDs survive device retransmits; accepted telemetry is acknowledged **only after durable server transaction**; offline queue survives process restarts, sends bounded batches; backend prevents duplicated trips or distances.

### FR-024 Event-time reconstruction and revision — P1
Derived trips/stops follow observation timestamps and may be revised by late offline batches; use processing version and provisional/updated labels. No fabricated observations or retroactively false live history.

### FR-025 C++ workload isolation — P0
C++ Drogon ingress, trip worker, usage worker, command worker, billing/deletion and parent map queries operate with bounded concurrency and per-family limits; historical recomputation cannot block secure ingestion or urgent SOS.

### FR-026 Map view independent of child GPS demand — P1
Opening map and multiple parent viewers fetches latest stored qualified fixes/history. Requesting more frequent observation is a separate feature flag that must respect Android lifecycle and battery policy, and is never automatically repeated per viewer.

### FR-027 Scoped retention/revocation across all storage — P0
Family deletion/revocation covers primary history, derived trips/stops, caches/streams, queues, backups under published retention; cross-family permission revocation takes immediate effect in reads.

### FR-028 Quality-aware map interpretation — P1
Every displayed trip/stop includes observed time, data provenance, confidence class/accuracy and gap status; route distances/arrival times clearly estimates if not measured.

### FR-029 Scalable capacity and access verification — P0/P1
Synthetic 1k/10k/100k-device load plans, latency/backpressure controls, per-tenant quotas and full API/RLS/SSE/caches cross-family security tests. Performance figures only promoted when benchmarked.

## 7. Functional requirements — new research-backed improvements D01–D14

| Requirement | Candidate | Priority | Required behavior and acceptance | Conditions |
|---|---|---|---|---|
| FR-030 | **D01 Evidence layer** | **P0** | Expose OBSERVED/APPROXIMATE/GAP/STOP_CONFIRMED reason codes and map legend; parent may flag derived stop interpretation, raw events remain immutable | Labeled GPS data accuracy evaluation |
| FR-031 | **D02 Reliability Center** | **P0** | Distinguish last device heartbeat, last observed GPS, last received, last trip processed, permission state, UNKNOWN causes; show actionable diagnostics | Cannot infer unseen current settings from a silent device |
| FR-032 | **D03 Offline revision history** | **P0** | Present reconstructed late trips with revision reason/time, dedupe correction notices and source event references | C++ event-time recompute + race/replay tests |
| FR-033 | **D04 Commute confidence** | **P1 C** | Schedule Home/School trips, arrival window, missing location vs confirmed elsewhere vs confirmed arrival, bounded notification escalation | Verified low false-alarm rates, timezones/holidays |
| FR-034 | **D05 Expiring guardian access** | **P1** | Verified guardian pickup invitation with one-child limited scope and explicit TTL; revoke token and active SSE in bounded time | Strict security threat model, no unverified raw-link sharing |
| FR-035 | **D06 Access ledger** | **P1** | Show permitted child-specific guardian roles and significant access/export/grant events without logging raw coordinates; retained/deleted per policy | Identity and audit privacy validation |
| FR-036 | **D07 Battery/coverage** | **P1 C** | Present measured power profiles and credible tracking coverage formula, not invented battery savings; background errors exposed | OEM/watch baseline benchmarks and accuracy labels |
| FR-037 | **D08 Policy preview & rollback** | **P1 C managed** | Dry-run 7-day block schedules and next transitions, timezone/DST rules, essential app exception, safe revert and actual per-device execution states | Tested managed DPC with eligible packages |
| FR-038 | **D09 Source handoff explanations** | **P2 C** | Show phone/watch/tablet provenance, last source and uncertainty/conflicting sources; don't claim source equals child's person | Real watch/phone handoff validation |
| FR-039 | **D10 Capability before purchase** | **P1** | Explain per-device supported/requires permission/managed-only/unavailable features before subscription purchase; reflect later revocation and renewal | Entitlement server verification and UI accuracy |
| FR-040 | **D11 Support diagnostic packet** | **P1/P2** | Explicit parent-approved redacted diagnostic export with timestamps/errors; no raw GPS/media/tokens by default; short TTL | Support access control and redaction tests |
| FR-041 | **D12 Transparency center** | **P0/P1** | Child-accessible monitoring summary with enabled data categories, recognized guardians and OS permission guidance; main Activity need not stay open | Age-appropriate UX, monitoring notice, jurisdictional review |
| FR-042 | **D13 Corridor deviation** | **P3 research** | If separately approved, compare supported observations to known permitted corridor; uncertainty/alternate routes must prevent false emergency claims | Labeled field evidence, false alert threshold and map license |
| FR-043 | **D14 Schedule-aware sampling** | **P2 C** | Versioned school/commute monitoring profile schedule controls fix-quality targets within Android limits and reports downgrade | Battery/Android lifecycle and alert-quality validation |

The descriptions above **include** all 14 features even when deferred. This is not a statement that FR-042 or restricted media will be in the first commercial release.

## 8. Additional cross-feature safety/coordination requirements

### FR-044 Emergency SOS (P1)
Child-initiated visible SOS/wearable/notification action (where supported) records last known fix and time, safe optional fresh fix, high-priority durable alert to permitted guardians with receipt/acknowledge; never claims dispatch to emergency services. Offline state is “queued,” not “guardian notified.”

### FR-045 Find-device signal (P1 C)
Authenticated bounded ring/sound request, child-visible purpose and time-limited command; DND/audio restriction and permission state yield truthful error.

### FR-046 Family quick check-in (P1 optional child UI)
A visible action or widget sends “I'm safe”, “Please call”, or “Need pickup” with delivery/ack receipt and narrow notification, without any microphone requirement.

### FR-047 Screen-time safe rules and optional tasks (P1/P2 C)
Display remaining time and school/night rules where supported. Protect emergency and OS-critical packages. Optional tasks/parent-approved time-credit ledger are P2 and must not manipulate children into excessive tracking or recording.

### FR-048 Device health (P1)
Attach battery/charging and connectivity/permission snapshot to existing sync heartbeat; avoid high-frequency status polling.

### FR-049 Alert deduplication and quiet hours (P1)
Deduplicate geofence/SOS/commute alerts by idempotent event ID; rate-limit recurring ordinary notifications; SOS follows distinct high-priority policy, retaining delivery uncertainty.

## 9. Non-functional requirements

| ID | Area | Mandatory verifiable criterion |
|---|---|---|
| NFR-001 | Battery | Measure actual incremental drain stationary/walking/vehicle/wear against baseline; adaptively reduce GNSS/network wakeups; no fixed savings claim before tests |
| NFR-002 | Performance | Bounded worker pools, memory queues, network batches, per-tenant quotas; no busy loops or unbounded queries |
| NFR-003 | Durability | Acknowledged ingest survives API/worker crash; queue/replay idempotency; retention/deletion runs recover after restart |
| NFR-004 | Security | TLS, Keystore device credential, parent OIDC/PKCE, per-device/family-child authorization, redacted audit, encrypted at-rest data/backups |
| NFR-005 | Child privacy | Data minimization, explicit disclosure, visible monitoring identity and required notification, retention and deletion controls |
| NFR-006 | Android compatibility | Track OS/OEM/build, management mode, grants and actual feature-test evidence; denied permissions never silently bypassed |
| NFR-007 | Accessibility & clarity | Clear labels, screen reader support, accessible error explanations, local timezones and localization; uncertain data visibly distinct |
| NFR-008 | Maintainability | Stable Kotlin/JNI/C++ boundaries, versioned OpenAPI, migration code, testable pure C++ algorithms, configuration/ADR change log |
| NFR-009 | Capacity | Load test staged 1k/10k/100k **synthetic** devices; report measured p95 writes/reads/queue-lag, WAL/retention and cost before SLA |
| NFR-010 | Access-control isolation | All API, cache, SSE, export, commands and worker tables have cross-family negative test; expected leak count zero |
| NFR-011 | Accuracy | Quantify stop false positives/negatives, observed route gaps and commute uncertain/missed classifications on labeled routes |
| NFR-012 | Operational resilience | Health metrics, signed builds, staging, backups/recovery, alerts, rolling deploy and incident response, privacy-safe diagnostic logging |
| NFR-013 | Honest statuses | Device offline, app permission loss, queue delay, OS rejection and stale location surfaced without false completion |
| NFR-014 | Billing and provider | Server-side entitlement, webhook replay safety, OAuth Drive revoke, Google Maps API restrictions and expense quotas |
| NFR-015 | Native packaging | C++ shared libraries support 16 KB memory-page devices, release AAB signed and security scanned |
| NFR-016 | Deletion integrity | Data delete across partitions, derived tracks, queues, caches and backups according to disclosed schedule, with no reingest after revoke |

## 10. External interfaces and artifacts

- Android: permissions/special access, FusedLocationProvider or tested LocationManager, Activity Transition API, UsageStatsManager, location foreground service, optional GeofencingClient, optional DPC, notification/Widget/Wear APIs.
- Parent: Maps SDK markers/polylines; optional Places search; Google Play Billing; parent authentication.
- Backend: C++ Drogon HTTPS endpoints; PostgreSQL/PostGIS; optional durable broker/Redis; push provider if approved; separate Google Drive OAuth integration.
- Documentation: canonical [technical specification](TECHNICAL_SPECIFICATION.md), [detailed route and battery](../../M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md), [C++ multi-tenant](../../M2-location-collection/01-location-collection-and-ingestion/ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md), [API draft](../../../openapi.yaml), [release plan](../../M8-operational-readiness/03-quality-and-evidence/VALIDATION_AND_RELEASE_PLAN.md).

## 11. Acceptance & security test matrix

| Group | Representative must-pass tests |
|---|---|
| Pairing | Reuse, expiration, stolen device credential, cross-family enroll and revoke |
| GPS | Screen off, doze, offline, moving/still, background permission revoke, battery fallback, Wear lacking GNSS |
| Reconstruction | Traffic signal not visit; 6-min dwell; trip multiple stops; accuracy jitter; GPS tunnel gap; 3-hour late batch; duplicate after retry; partial history |
| Parent map | Named places marker persist; open two viewers doesn't add child requests; source and accuracy shown; alternate time zones |
| Usage | Special access granted/revoked, data continuity, daily-to-yearly time boundaries |
| Managed restriction | Device owner/provision, eligible package suspension, protected apps, schedule DST/reboot, rollback |
| Trust D01–D03 | Explainable observed/gap/uncertain, diagnostics UNKNOWN path, revision update with algorithm version |
| Privacy D05–D06 | Expired invite/stream, scope denied, no GPS in ledger, denied other family |
| Commute D04/D13 | Missing fix vs genuinely not arrived; quantified false alerts; corridor remains disabled until validation |
| Billing D10 | Server entitlement, renewal/hold/refund/revoke, eligibility shown before purchase |
| Support D11/D12 | Redacted packet opt-in, child transparency visible, no covert features |
| Performance | Synthetic 1k/10k/100k workload, bounded queue, API/worker crash, DB restore, finite retention |
| Release | Play 2026 target API, background-location disclosure/declaration/video, monitoring metadata, 16 KB C++ libs, privacy/deletion URL, Data safety and real screenshots |

## 12. Delivery plan and official product acceptance

| Phase | Engineering outcome | Gate |
|---|---|---|
| M0 | Feasibility, product/privacy decisions, target devices, canonical requirements and threat model | Reviewed design, no unsupported promises |
| M1 | C++ backend skeleton, auth, pairing, PostgreSQL schema, secure Android enrollment | Cross-family and pairing tests |
| M2 | Encrypted child event queue, adaptive compliant GPS, durable ingest | Offline/dedupe tests, real Android battery and service lifecycle |
| M3 | C++ trip/stop engine, named places, parent Map, route quality | Annotated-trip accuracy, GPS gap correctness |
| M4 | Usage reporting, SOS/device health/alerts, D01–D03 trust features | Reports and failure-state tests |
| M5 | Guardian time-limited grants/privacy ledger, capability pre-purchase, support/child transparency | Security/redaction/expiry tests |
| M6 | Conditional commute/battery UX, managed policy/simulation, Wear device handoff | Named devices and false-alert, DPC and power test evidence |
| M7 | Drive, commercial billing, account/data deletion, operational scaling | Provider and penetration/performance tests |
| M8 | Optional research: route corridor, media (only authorized visible) and other deferred features | Never shipped without legal/OS/policy evidence |
| M9 | Play launch package, target API and native compliance, privacy pages, form/declaration, staged rollout | Play approval and complete evidence |

## 13. Exclusions and conflict-resolution decisions

- The child main Activity normally remains closed after setup; optional SOS/check-in/rewards **may** provide small child-visible UI, notifications or widgets. A child-facing action is not hidden monitoring.
- No remote microphone/camera bypass, covert background capture, suppressing Android indicators or universal other-app private file access.
- No fake “live” map data, precise street history, real-time ETA, medical/crash/emergency service guarantee, or promised battery percentage without evidence.
- Parent permission grant alone does not give device-owner privileges or defeat background restrictions.
- Research feature D13 and restricted media are explicitly non-launch until their independent gates pass.
- Existing v0.1 discussion and specialized technical papers remain useful historical/context references; **this SRS v1.0 is the current project-wide requirements source**.

## 14. Change log and references

**v1.0:** Consolidates original FR-001–FR-029 with D01–D14 as FR-030–FR-043, SOS/check-in/health as FR-044–FR-049, and adds security/operations/battery/release requirements. Feasibility criteria in [gate](../../M0-foundation-and-approvals/02-market-and-feasibility/WHOLE_PROJECT_FEASIBILITY_GATE_2026.md) govern each conditional feature.

Official verification:
- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://developer.android.com/about/versions/14/changes/fgs-types-required
- https://developer.android.com/reference/android/app/admin/DevicePolicyManager
- https://developer.android.com/develop/sensors-and-location/location/geofencing
- https://support.google.com/googleplay/android-developer/answer/9888380
- https://support.google.com/googleplay/android-developer/answer/9799150
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://developer.android.com/guide/practices/page-sizes

## 15. Documentation implementation contracts and open approval gates (2026-10-25)

All 49 functional and 16 non-functional requirements now have planned module/owner/test assignments in [Requirements Traceability](REQUIREMENTS_TRACEABILITY.md). The new canonical [Technical Specification v1.0](TECHNICAL_SPECIFICATION.md) links each implementation group to [Data/Authorization/Recovery](../03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md), [Android Runtime and Algorithm Contract](../../M2-location-collection/01-location-collection-and-ingestion/TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md), [Command/SOS/Usage/Queue Contract](../../M4-usage-health-sos/01-usage-health-and-sos/COMMAND_SOS_USAGE_QUEUE_CONTRACT.md), and the expanded [OpenAPI 3.1 draft](../../../openapi.yaml).

**Approval is conditional:** See [Blockers and Owner Decisions](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) for unresolved launch markets, legal publisher, guardianship, retention, managed mode, hardware support and subscription scope; [Audit Remediation Status](../../M0-foundation-and-approvals/01-project-governance/AUDIT_REMEDIATION_STATUS.md) separates completed documentation from missing binaries, migrations, tests and Play policy review. No FR is certified implemented by this SRS.

## 16. India DPDP and pilot release constraints (2026-10-26)

This section is a **binding specification/release gate** for all existing FRs/NFRs, not a claim about current legal compliance. No real minors' data in any build/test environment until required purpose-by-purpose legal authority is verified. The source of legal interpretation and scope gating is [India DPDP Child Privacy and US Transfer](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md), covering DPDP Act s.9, s.16, Rules 10/12, narrow real-time safety exemption and 2027 phased commencement. **Live location safety, historic route history and app usage are NOT automatically covered by the same exception.**

- **FR-003/004/015–018/024/028/033:** observed live location must separately pass India child-purpose + Chicago data-transfer consent/legal review; trip/stops/commute/history **OFF** for minors until explicitly signed scope.
- **FR-005/047:** app usage and behavioural monitoring **OFF** in India minor pilots pending a specifically favorable legal assessment, regardless of Android Usage Access being granted.
- **FR-013/027:** product owner and counsel approve data-category retention and backup/deletion including replay of erased offline event streams. Raw 14d / derived 90d / audit 365d / backup 30d are **unapproved planning candidates**, never user-facing published policies.
- **FR-022/034/035:** only verified owner is provisional inviter/revoker; new guardians never inherit children automatically; temporary pickup limited to one child, time and current view only; parent identity must be verified beyond a mere account when required.
- **FR-044:** **no emergency-grade SOS claim** until backup channel, independent failure-domain design and actual guardian acknowledgement/fault-injection evidence exist. FCM send success is not guardian receipt. A limited best-effort check-in may be separately released with truthful state and permissions. [SOS contract](../../M4-usage-health-sos/01-usage-health-and-sos/SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md).
- **NFR-003/012 and readiness:** single Always Free VM cannot meet a production high-availability claim. Need signed target and measured RPO/RTO; proposed synthetic-only 24h/48h, reviewed pilot 4h/12h, production 1h/4h **targets**, not current capacity. [Disaster Recovery](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_RECOVERY_AND_PILOT_READINESS.md).
- **Commercial FR-012:** current proposed ₹50/month / ₹500/year per child; ₹149 historic only. Full break-even must include tax, Play fees, real API, HA, staff, support and acquisition. [Financial viability](../../M7-commercial-integrations/01-commercial-plans-and-costing/PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md).
- **M1 acceptance:** requires at least one actual owner-approved resettable DPC-capable spare and physical API/OEM test device; otherwise M1 hardware portion remains BLOCKED while emulator tasks may proceed.
- **M2/pilot:** no real GPS/usage collection until legal entity, child-purpose, guardian policy, consent/verification, US hosting review, RPO/RTO backup tests, device hardware evidence and support owner pass signoff.

All are mandatory go/no-go gates; implementing synthetic-data algorithms is allowed before legal signoff.

## 2026-10-26 FR-008/009/010 clarification: accepted conditional media and failure reasons

The product owner accepts conditional engineering research of FR-009 remote live camera/front-rear snapshots/video and flash-off where supported; FR-010 one-way live microphone listening and encrypted parent-local recording; and FR-008 scoped app-owned/shared MediaStore/SAF file listing and transfer. These are **not** current production entitlements and require execution-time permission, platform context, child transparency, guardian scope, legal and Play gating. The Alarka main Activity normally remains closed after setup; required monitoring notification and system sensor indicators remain. STANDARD and genuine MANAGED_DEVICE_OWNER must be tested separately. Android MediaProjection live screen view requires a fresh child-device system consent **per capture session** and cannot be permanently granted at installation.

For every unavailable request, Madalasa **SHALL report actual command state, verified reason code, and safe next action**, including user/device permission revoked, Android background sensor-start restriction, child interaction needed, managed-only setup, device offline/unknown, unavailable sensor, file-scope rejection, network interruption, and timeout. Server delivery/FCM acceptance is not capture completion. A snapshot/recording requires real file/capture receipt; live media has authenticated session-established/streaming/stopped substates. Never infer a specific sensor defect from a stale/offline device.

These are testable design requirements, not implementation evidence. FR-009/010 remain research P3 and feature-flagged off in commercial builds pending device certification, security, India legal and Play release gates. [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md) defines reasons and T-MEDIA-01–18.

## 2026-10-27 FR-001/002/006/014/039 amendment — verified capability discovery, grants and parent read API

**New owner-accepted design requirements (not implementation or product approval):** Alarka SHALL run a read-only hardware/OS/public sensor-capability scan at initial launch **without capturing private media or child location**; cache a local supported/unsupported/unknown feature inventory with actual Android API/enrollment mode. After FR-001 device-bound pairing it SHALL upload a **bounded, versioned, authenticated** capability report. Before each FR-002 permission request it SHALL explain purpose, scope, recipients and opt-out; Android owns the grant UI or special Settings/SAF chooser. It SHALL re-check the **actual OS result**, not trust button clicks, and persist a higher report revision only on real state change.

The C++ backend SHALL authenticate device ownership, validate schema/monotonic version/clock skew, durably store latest capability and minimal audit changes and offer **child-scoped authenticated parent GET**. Madalasa SHALL display separate **hardware support / permission grant or selected scope / runtime eligibility / feature-release flag / freshness**, clear change confirmation after server ACK, and safe verified cause/next action when unavailable. Color-only indication is insufficient: green `GRANTED` describes the **permission only**; green `READY` describes actual eligible approved feature. Amber indicates conditional/partial/temporary/action-needed; red verified denied/revoked/unsupported/release-blocked; grey stale/unknown/offline/pending. Pending FCM or queued sync never becomes green solely from a parent click.

After revocation or regrant Alarka SHALL discover changes on its **next legitimate execution** (onResume, grant result, safe scheduled sync or before command execution), stop invalid operations, upload newer version and notify through durable server update; **immediate detection is NOT guaranteed** after OS kills process, Doze, force-stop or network loss. A stale parent screen SHALL say "last confirmed" rather than asserting revocation. Android 11+ foreground location must precede background location separately; MediaProjection requires fresh consent per session. STANDARD and truly managed-owner execution differ. Protected P3 camera/mic and child data remain release-OFF pending Play/India counsel.

**New acceptance catalog:** T-CAP-01…24 in [MA-CAP-ADR-002](../03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md); complete status NOT_IMPLEMENTED/NOT_TESTED. Covers secure pairing/feature-read permissions, one-time/selected grants, Settings, revision races, offline revocation, parent color accuracy, and OS/Play restriction. FR-002/039 preserve their existing IDs; no invented FR number.

## 2026-10-27 Owner additions — FR-050 media activity metadata, FR-051 restricted admin console

### FR-050 — Media activity metadata audit, parent history and reasons — P3 research / release gated

Madalasa–Alarka SHALL design a metadata-only lifecycle audit of each authorized media request (AUDIO / IMAGE / VIDEO_AV / SCREEN_SHARE) without storing audio, photos, AV video, screen captures, thumbnails, filenames, file paths or transcripts on the VPS. A request/result record SHALL preserve child ID, guardian actor ID, device/session/command correlations, media/action type, actual start/end if verified, actual active duration if known, measured file size only on confirmed stored media (NULL for view-only), network bytes as a separate measurement, historical viewed-only vs parent-local saved receipt vs save-unknown, failure status and only evidence-grounded reason codes (camera busy, camera resource limit, mic interrupted/silenced, permission/OS start denied, child offline, network/relay and save failures). Never infer 'child on a call' from generic audio errors or claim viewed/saved from delivery/queued status.

The parent SHALL see paginated server-filtered media activity across *only currently authorized children*, using names+masked child IDs in dropdown, child selection, date range, media kind/action/outcome/failure code, next/previous paging, detail/empty/offline/error states. Parent history reads SHALL NOT wake Alarka, expose any other family, or provide VPS media downloads. UTC event times and localized dates are distinguished; unavailable actual durations/sizes are NULL/Not confirmed. No real-minor media capture/research pilot is approved by this requirement.

**Acceptance:** T-AUD-01–14, 18–22; non-implemented, no media files stored. See [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md).

### FR-051 — Case-scoped administrator media audit and operations panel — P3 research / release gated

A separate authenticated, least-privilege administrator web console SHALL provide media activity metadata search with *parent name/ID autocomplete, child name/ID autocomplete constrained by parent*, date range, media kind/action, outcome, failure reason and server-side pagination. Generic support operators SHALL see anonymized/restricted aggregates only; **named child log access** requires independently approved limited case purpose, role scope, expiry, step-up MFA and server-side enforcement. Every admin detailed query, suggestion, detail view and export attempt SHALL write a separate access audit; failure of that audit store MUST fail closed for sensitive reads. Root operator identity does not automatically confer access. Parent, child and named records are never universally searchable by default.

Admin panel design scope covers sign-in/MFA, aggregate overview, case approval, case-scoped search/autocomplete, log detail, verified error reasons, paging, empty/denied/offline, separate access audit, retention/legal controls, expiring sessions and export approval. No admin microphone/camera activation, streaming, live view or access to parent-local recordings is authorized by this panel. Retention periods and commercial permissions stay open to Indian counsel/Play/owner gates.

**Acceptance:** T-ADM-01–14 and T-AUD-15–22; NOT_IMPLEMENTED / NOT_TESTED. Source: [Administrator Console Specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md); whole-project OpenAPI draft has design-only endpoints; M1 stays unchanged.

**M0–M9 boundary:** FR-050/051 are additional planned requirements beyond prior FR-001–049 baseline, not silently added to released or signed-off M1–M9 scope. Exact release requires separate owner/engineering/security/privacy decisions; media P3 remains OFF.

## 2026-10-27 approved architecture amendment to FR-003 / FR-004 / FR-005 / FR-018 / FR-023 / FR-025 / FR-026

**Owner accepts as a design requirement, not tested deployment:** Alarka SHALL separate Android location observation acquisition and **encrypted on-device local persistence** from network transmission. Subject to Android service permissions and legal feature release flags, it SHALL target **1–2-minute JSON batch upload** while eligible, with bounded 100–500 point/byte caps, stable event IDs, exponential backoff+jitter and **up to 48 hours offline queue capacity**, respecting user-visible local overflow/loss conditions. The target does not promise location when powered off, denied or force-stopped; periodic WorkManager cannot guarantee 1–2minute intervals. Android app-usage sessions require their own permission-gated event adapter and separate batch/aggregation path, not an always-on live-foreground app claim.

**FR-023 durable ingestion implementation choice:** default C++20 Drogon validates device-bound batch, writes **one PostgreSQL durable inbox record per complete authenticated JSON batch (Tx A)** and returns 202 `QUEUED` only AFTER COMMIT. This durable acknowledgment allows Alarka to retire specifically ACKed local batches; it **does not** mean the actual GPS location table or route geometry was updated. C++ workers SHALL lease queued inbox batches, regroup observations and use **bulk insert** (multirow/INSERT SELECT, optionally COPY staging), in a second atomic Tx B with event dedup ledger, time-partitioned GPS rows, reconstruction outbox and inbox PROCESSED. Separate trip/usage workers process derived data. Workers recover safely from crashes and stale leases; parent maps display last observed/ingested/reconstructed timestamps and actual gaps.

Redis is **not required** for initial ingest. Direct bulk GPS insert + dedup + outbox in an API transaction is a mandatory resource/performance benchmark alternative: Postgres inbox costs extra writes/WAL and is not presumed cheaper. Accept all T-ING-01–24 as *planned/not implemented/not tested*; no old NFR capacity/battery figures are device-proven. Canonical [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md), [native editable HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-2), [LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-60), [performance decision diagram](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-126). Real Indian-minor GPS history/usage collection is not authorized until the existing DPDP/Play assessment is resolved.


## 2026-10-27 owner commercial/UI direction — supersedes conflicting historical proposals

**State: owner-approved design direction, NOT deployed, legally signed off, or Play Console/device tested.** Launch is India-first, **manual-renewal Google Play prepaid only**. No automatic renewal, background charge, or charge triggered by opening premium feature; parents explicitly confirm each purchase/top-up in Play. At verified prepaid expiry, downgrade to free: live tracking at a reduced adaptive GPS interval (moving design target approximately 10–15 minutes, slower stationary; no Android timing guarantee), most recent **six hours of visible location history**, and no paid media. Premium requests show payment review instead of silently charging. Deleting the account revokes child/guardian access and future ingest, and cannot generate an auto-renewal; handle any legacy auto-renewing purchase independently if ever issued.

**Price targets per paid child:** public ₹99/month or ₹999/year; founding ₹50/month or ₹500/year for the first **1,008 distinct successfully paying families** counted once each. All eligible paid children in a founding family, including added later, qualify. Founding eligibility persists through prepaid lapses when lawfully recognizable. Automatic eligible early-access offer, no coupon entry, subject to real Play prepaid products/offer support, taxes, fee confirmation and purchase-screen amount. Trial activation does not count as a paying founding family.

**Introductory experience:** once per eligible verified family, 48 hours of conditional Super Access with no auto-conversion, independently server timed. Across the FULL trial per eligible child, shared between authorized guardians: 5 audio minutes (3 min max/session), 2 video minutes (1 min/session), 3 successful photo snapshots, 2 screen-view minutes (1 min/session). Paid Balanced per paid child per month: 60 audio minutes (5 min max/session), 20 video minutes (2 min/session), 30 photos, 10 screen-view minutes (2 min/session). Count confirmed delivered session consumption, not failed OS attempts. Media remains **OFF / P3 conditional research** until Android, legal, Google Play, safety and device gates permit. No implied covert or guaranteed background sensor access.

**No repeated trial:** verify adult parent identity and prior redeemed or paid eligibility server-side, with a minimized bounded lawful anti-abuse ledger; optional Play Integrity/Device Recall subject to availability and review. Reinstall, logout, closure/recreation, or adding a child never restarts a lawfully recognized trial. Do not store child routes, images, microphone recordings, Aadhaar or IMEI to enforce eligibility. Legitimate families incorrectly blocked require review; permanent matching of an erased identity is not guaranteed.

**Storage vs visibility:** six-hour free history is an access limit, NOT a retention authorization. Earlier child location data can only remain for independently approved purpose-specific periods, not automatically until account closure. Deletion revokes token access, cuts off late offline uploads, and erases eligible data including backups as policy dictates. Legal retention, deletion exceptions, guardian authority and cross-border processing remain open gates.

**Parent UI:** replace oversized purple 48h hero with compact off-white/teal-style dismissible trial strip/pill (around 48–64 dp): “✦ Super Access · 47h left” plus accessible close X. The close dismisses marketing banner for the current in-app navigation session, NOT trial entitlement/countdown; a small plan/status entry remains visible. No flashing, support reduced motion. The opening welcome announcement may show once, then small strip; real countdown derives from backend. Trial-ended messaging clearly explains free tracking and manual prepaid upgrade.

**Costing:** existing OCI 1,000-child allocation (~₹3,238/month) explicitly excluded media. Provisional separate ₹3,000/month testing reserve is NOT a TURN/WebRTC provider quote, nor a production capacity promise; measure concurrency, relay ratio, bandwidth, storage, taxes, prepaid Play fees and full operating expenses. Older ₹50/₹500 as universal public pricing, auto-renewing products, 15% auto-renew fee cases, and corresponding revenue scenarios in preceding sections are HISTORICAL and need a full prepaid recalculation. Confirm Play Console purchase/top-up/seat-count/offer behavior before enabling billing.

**Screen consistency and traceability:** base UI source [existing 81-screen Figma handoff](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=6-2) (off-white/teal parent visuals). Update dashboard/map/history trial strip and billing screens P-47/P-48/P-49 plus deletion P-44, capabilities P-46, trial eligibility and media views to show this rule. Do not claim static Figma designs are working Android screens.


## 2026-10-28 owner UI/theme design extension (not release-ready)

Five optional/replayable ST-01–ST-05 narrative pages explain Madalasa/Alarka using an original illustrated Purāṇa style with literary-source attribution, English-only for initial release, extensible string resources for future localization, Skip, Back/Next and progress. No acceptance of monitoring consent follows from viewing or skipping them. Parent screen samples P-05 dashboard/map, P-15/24 history, P-28 per-place alerts, P-39 guardian invitation, P-48 manual prepaid checkout, P-58 conditional audio and child transparency C-02 preserve existing functional/security contracts. Theme colors and illustrations cannot obscure source timestamps, uncertainty, permission denial, opt-out, SOS or payment amounts. Compact closable trial notice is presentational only; trial entitlements remain server authoritative. [Design contract](../../../ui/MADALASA_ALARKA_THEME_C_STORY_AND_UI_CONTRACT_2026.md).



## Authoritative owner correction — 2026-10-28 (overrides any earlier regional/language wording)

**Source & visual identity:** Madalasa and Alarka belong to the **Mārkaṇḍeya Purāṇa** narrative, part of a pan-Indian Sanskrit Puranic tradition. Do **not** describe the narrative or the project's theme as a Bengali regional folk tale, or position regional patachitra as its required style. Chosen Theme C means an **original pan-Indian Puranic illustrated storybook**—classical manuscript/miniature/mural influences without claiming historical authenticity or monopolizing any one regional tradition. Original lotus, ring, tree and court/forest motifs are optional decorative inspiration; all monitoring UI remains modern and clear.

**Launch language is ENGLISH ONLY:** English headings, body copy, app controls, trial/banner, billing, child transparency and story pages. **No Bengali script and no language selector** in current prototype/release screens. Future multilingual enhancement remains planned technically (resource-keyed UI strings, flexible components, Unicode/font fallback, locale-safe dates/numbers, translation QA), but translated screens/content must not be implied ready or implemented.

**Preserve the user-provided screenshots and prior feature discussion:** See [reference workflow register](../../../ui/REFERENCE_SCREENSHOTS_FEATURE_WORKFLOWS_2026.md) (relative link should be resolved from docs/ui when applicable). These supplied third-party screenshots are **functional references only**, capturing map/satellite style selection, collapsible/expanded dashboard, parent/child enrollment, place-specific toggles, timeline, route segments, quota-based sound, usage charts and managed-only restrictions. Copy neither imagery nor exact UI. Do not treat inferred third-party capabilities as certified Madalasa features.


## Launch-language and source clarification — 2026-10-28

**Madalasa–Alarka is based on the Markandeya Purana's pan-Indian narrative, not on a regional Bengali folk tale.** UI, story onboarding and screenshots are **English only in this launch stage**. No Bengali text or language switcher appears in current released designs. Future multilingual support remains an architectural extension: translation keys in Android resources, layout growth and Unicode/fonts, locale-aware dates/amounts, reviewed translations and optional user language settings when implemented. Theme C art remains original pan-Indian Puranic illustration; it never changes child-monitoring permissions, Android/Play feasibility, or the underlying commercial terms. Feature behavior inspiration from the user-supplied screenshots is captured at [Screenshot functional workflow register](../../../ui/REFERENCE_SCREENSHOTS_FEATURE_WORKFLOWS_2026.md), without copying competitor designs.


## 2026-10-28 — Two parents, one child payment; select paid children (supersedes conflicting assumptions)

**Owner working decision:** one verified prepaid **paid child entitlement** may be used by *both separately signed-in, explicitly authorized parent accounts* within the same Madalasa family. Second parent does **not** buy a second plan for the same child. Primary billing adult selects which child IDs are covered by N paid seats; nonselected siblings stay on free features. Permissions remain scoped per adult-child grant, shared quotas meter per child across both parents, and co-parent access is revoked independently of purchase. One family is counted once for first-1,008 founding-family eligibility. Prepaid/manual renewal only, no auto debit; when expired both parents revert to the child's free tracking/reduced frequency/six-hour visible history. Other rules unchanged.

**Google verification:** [Family Link supports a second adult parent](https://support.google.com/families/answer/7295768) but does NOT automatically authorize Madalasa or expose a verified public parent-relationship API to this app. [India does not support new Play Family Library/family payment signups](https://support.google.com/googleplay/answer/16719923), and [family payment methods exclude subscriptions](https://support.google.com/googleplay/answer/15775614). Google Play purchases stay with the paying Play account; backend verifies and binds unique purchase tokens to family capacities/child entitlements, NOT guardian devices. [Play prepaid add-ons are unavailable](https://developer.android.com/google/play/billing/subscription-with-addons) because add-ons are currently auto-renew-only. Play Console sandbox must prove suitable N-seat prepaid SKUs, explicit seat reassignment, upgrades, top-ups and founding offers before any launch pricing promise.

**Canonical implementation design:** [Two-parent Shared Child Entitlements and Seat Selection](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/TWO_PARENT_SHARED_CHILD_PREPAID_ENTITLEMENTS_2026.md) (use an appropriate relative path from each document). Figma added [P-47 family child seats](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-179) and [P-49 covered by family](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-201), editable mockups only. Media and other restrictive Android features remain gated.

## 2026-10-28 requirements addition — explicit child/co-parent access and concurrent viewers

**FR-040 (P0, privacy):** Separate *paid child selection* from *adult-specific child sharing*. Default share none. Main payer can authorize a co-parent **only** for selected eligible child and approved features, not all children or family groups. Each parent logs into their own verified Google account. Official Family Link may designate second parent but no verified supported API returns the child-specific relationship to a third-party app; hard-block sharing pending an authoritative verification/legal method, rather than equate login/email/invitation with proof. Prevent cross-child leakage, blended-family relationship crossover and persisted access after revocation.

**FR-041 (P1, optional commercial):** one simultaneous paid *premium monitor viewer* per active paid child included; same adult switching tabs doesn't use another slot. Every additional concurrent viewer needs a verified child-scoped optional paid slot, ₹100 once for 100 calendar days, independent of base plan expiry; dormant on base lapse and restored on renewal before day 100. Each slot grants +30 **combined shared** audio/video minutes to the same child; no extra media capability if Android/legal Play feature flag OFF. Free live location and safety-critical behavior not blocked by premium lease. Multiple authorized parents share a **single child usage pool** and total viewer slots.

**FR-042 (P0, security):** Drogon backend issues short-lived atomic viewer leases with authenticated adult-device session, child grant, paid expiry and concurrent-slot capacity checked on every acquisition/renewal. Reject concurrent oversubscription race, cross-child replay, revoked grants, refunded tokens, stale tabs. Offer retry, consensual takeover request and payer-only one-time add-on checkout (only if supported). Add telemetry for no double charging, no double quota deduction and no hidden session. See [canonical design](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md); no Android/backend implementation completed.

## Owner decision (2026-10-28): Google-only super-admin bootstrap and staff application; supersedes narrow module scope above

**Accepted for technical design, not implemented.** Initial sole administration-approval authority is the exact Google/Gmail account **swarna.s.jobs@gmail.com**. Successful Google login does **not** grant admin privileges by itself: protect initial ROOT_OWNER binding using validated Google OIDC `iss/sub/aud/exp/email_verified` and MFA plus secure out-of-band bootstrap; subsequent application approvals are ONLY owner actions. A new Google account without approved role is restricted to its own request form/status. The request form captures name, postal address, DOB, gender, and contact email; **Request Access** stays disabled until required profile fields and a verified contact email are confirmed server-side. If same authoritative verified Gmail address, provider `email_verified` can satisfy contact confirmation; different email uses hashed expiring one-time challenge. Full DOB, gender and address collection/retention must pass data-minimization review before production. Submitted requests trigger minimal notification to the owner Gmail address and appear in an owner-only **Access Requests** queue. Owner reviews verified applicant profile and chooses Approve (least-privileged role selection) or Reject (audited reason), with instant role/session revocation support.

Expanded back-office modules: (1) FAQ read/create/edit/revision/publish; (2) support request queue and audited customer replies; (3) subscriber/family, prepaid child-seat statuses, masked Google Play payments and refunds; (4) minimal per-subscriber child aliases/masked IDs, count and seat status **without private child data**; (5) routine **parent service-usage metadata** (parent, service code, UTC time, measured duration, outcome, quota debit), NOT child app/behavior logs and NOT underlying GPS, routes, photos, audio/video/screen payloads, messages or files. All staff receive explicit scoped roles; owner can do all administrative operations but does not bypass child privacy wall or case-scoped media audit, even with ROOT_OWNER. New routes require admin audience, server authorization/RLS, MFA/step-up, audit and pagination. Existing ADM-01..17 restricted media audit screens remain case-scoped.

**Canonical workflow and PostgreSQL model:** [owner admin specification](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md). **New Figma page:** [back-office admin screens](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=105-2), with [access requests](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=107-2), [FAQ editor](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=107-44), [support](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=107-85), [subscriber ledger](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=107-123) and [parent service-usage metadata](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=107-161). [ERD-10 admin database](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=108-2). All Figma frames are **editable static prototypes**, not working OAuth forms or backend API.


## OWNER SUPERSESSION — 2026-10-28: drop Google Family Link parental-role API dependency

**New decision overrides every older claim in this document that a co-parent may be invited ONLY if Google's Family Link parental role is programmatically verified, or that no sharing is possible until a public Family Link attestation API appears.** Google sign-in still verifies each adult independently (`iss/aud/sub/exp`). Madalasa's backend uses an exact-child single-use invitation, separately accepted and revocable scoped grants, device/child transparency, dispute hold, no sibling disclosure and security/authorization tests. **Legal verification of adult parental/lawful guardian authority and valid child-data consent is a distinct mandatory compliance gate, NOT waived**; synthetic local tests may use controlled fixtures, real child processing requires approved lawful method. A paid family seat is never a guardian permission and a second adult never inherits the entire family's children. See [V2 ADR](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md) and [India legal brief](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_CHILD_CONSENT_RETENTION_DELETION_ACTION_BRIEF_2026-10-28.md). Use new versioned DB migration, do not mutate M1 baseline. This is design only; no verified runtime has been built.
