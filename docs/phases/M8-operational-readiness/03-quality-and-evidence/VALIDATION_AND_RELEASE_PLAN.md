# Verification, Test Evidence, and Release Roadmap

> **Document control:** M8 / 03-quality-and-evidence · Proposed owner: QA + security (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (guardian/parent), **Alarka** (child companion). GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka), renamed 2026-10-26. [Source story and naming contract](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Madalasa–Alarka | 2026-10-25 | Plan — no tests executed**

## 1. Feature quality gates

A feature moves through:

`DESIGNED -> UNIT_TESTED -> INTEGRATION_TESTED -> DEVICE_VERIFIED -> SECURITY_REVIEWED -> POLICY_REVIEWED -> RELEASE_ENABLED`.

Each status is stored against the exact build, Android version and device model. Do not mark API support as a device pass. Mark unsupported conditional features disabled rather than silently simulating success.

## 2. Supported hardware matrix

First pass: Pixel (AOSP-like) + Samsung or other high-use OEM, Android API 29, 30, 31, 32, 33, 34, 35, 36 where possible. Test **standard** and **properly provisioned device-owner** enrollment separately. Final support list to be narrowed based on real evidence.

Evidence record per test:

```text
Test ID:
Requirement:
App commit SHA / signed build:
Parent/child package versions:
Phone make/model/build / security patch:
Android API, targetSdk, management mode:
Runtime permissions / special access / notification state:
Battery optimization and connectivity state:
Steps, expected result, actual result:
Screenshot / logs (redacted):
Status: NOT_TESTED | PASS | PASS_WITH_CONDITIONS | FAIL
Tester / date:
Bug / resolution:
```

## 3. Traceability and acceptance cases

| Requirement | Tests | Ship requirement |
|---|---|---|
| FR-001 Pairing | Unique one-time code, expiry, replay, code brute-force, revoke, parental account isolation | Zero cross-account device access |
| FR-002 Permissions | Onboard, deny/revoke, special access, app restart, manufacturer permission paths | Degraded status correct; no fake reporting |
| FR-003/004 Location/history | Screen off, move, stationary, offline, airplane mode, restart, low battery, imprecise grant, route gaps | Points timestamped/accurate; no invented live state |
| FR-005 Usage | Usage Access grant/revoke, aggregation, timezone, day/weekly/monthly/yearly boundaries | Reports reproducible from recorded data |
| FR-006 Commands | Offline, stale capability, expired TTL, retries, duplicate, reboot, fake device token | Terminal status truthful and idempotent |
| FR-007 Restriction | Managed enrollment, suspend eligible package, unsuspend, unsuspendable app, timezone reboot, expiry | Eligibility and rollback demonstrable |
| FR-008 Storage | Owned file, granted SAF file, revoked URI grant, unauthorized app-private path | No protected-path access |
| FR-009/010 Capture | Appropriate user-visible authorization and OS-permitted context, denial, session failure, privacy indicator | No unapproved or hidden capture; OS denial surfaced |
| FR-011 Drive | Parent OAuth, selective scope, access revoked, interrupted/resumable upload, duplicate | Uploaded bytes/checksum and deletion rules verified |
| FR-012 Subscription | Trial, renewal, grace, hold, refund, revoke, purchase replay | Backend entitlement authoritative |
| FR-013 Privacy | Account deletion, device disconnect, Drive unlink, backup queue/deletion, export | Retention and access tested |
| FR-014 Alerts | Connectivity, stale position, sensitive lockscreen details | Correct status with minimal disclosure |

## 4. Security verification

- Threat-model data flows between child, parent, backend, processors.
- Test IDOR/BOLA on every path containing a device ID.
- Validate JWT/OIDC audience and expiry, device signature/revocation, OAuth CSRF/PKCE as applicable.
- Device re-pairing hijack, brute-force enrollment, replay/duplicate command, token theft.
- SQL injection, oversized requests, malformed JSON, sensitive telemetry in logs.
- Backup restore, key rotation, secrets scanner, dependency scanning, privacy data deletion and least-privilege access.
- DPC policy rollback and avoidance of suspending critical system packages.

## 5. Performance verification

Benchmarks on real devices:
- 24-hour baseline idle battery and monitored stationary battery.
- Two-hour walking and vehicle movement reporting.
- 24-hour Wi-Fi versus mobile and unavailable-network queue growth.
- P50/P95 CPU, process PSS, network bytes/day, wakeups, crash/ANR.
- Policy scheduler while offline; process restarted and device rebooted.

Numeric thresholds become an engineering decision **after** measurement. Do not market an unsupported percentage of battery savings.

## 6. Play review evidence pack

| Artifact | Owner | Status |
|---|---|---|
| Production AAB(s), target API evidence | Build engineer | NOT STARTED |
| 16 KB native alignment checks | Android engineer | NOT STARTED |
| Child app identifiable icon and monitoring notification proof | Android engineer | NOT STARTED |
| Disclosure + background-location permission short video | Product/Android | NOT STARTED |
| Privacy policy public URL and data safety signoff | Privacy/legal | NOT STARTED |
| Account deletion in-app and web URL demonstration | Backend/product | NOT STARTED |
| Reviewer credentials, pairing/setup directions | Release owner | NOT STARTED |
| Policy declarations, target audience, content rating and ads | Release owner | NOT STARTED |
| Package visibility/FGS/other permission declarations if applicable | Android/release | NOT STARTED |
| Closed testing results + production access if required | QA/release | NOT STARTED |
| Subscription products and test payments | Billing engineer | NOT STARTED |
| Device/OS compatibility and security signoff | QA/security | NOT STARTED |

## 7. Roadmap tasks by milestone

### M0 — Architecture/policy approval
Freeze release features, use cases, desired mode(s), `minSdk`, available test devices, package IDs, publisher identity, hosting location and retention. Review whether the child agent distribution strategy qualifies under Google Play monitoring policy. Deliver approved document set and issue backlog.

### M1 — Secure foundation
Create Gradle multi-app, shared C++ CMake library, CI, Drogon server skeleton, PostgreSQL migrations. Implement parent auth, short-lived one-time pairing, device keys, revocation and secure audit. Exit: reliable authenticated enrollment, negative security tests.

### M2 — Location MVP
Onboard permissions, persistent transparent monitoring notification, location collector with compliant lifecycle, local encrypted queue, server ingest and parent map/history; adaptive movement updates, speed optional. Exit: device movement/stationary/offline tests, stale UI.

### M3 — Usage reports
Usage Access setup and collection, aggregation jobs, per-app duration reports by requested periods, permission revocation and retention enforcement. Exit: tests across time boundaries.

### M4 — Managed control module
Separate DPC build/provisioning runbook and device compatibility list. Implement eligible package suspension/restore and local time-based policy evaluation with audit and rollback. Exit: test evidence for managed device; standard UI does not offer unsupported promises.

### M5 — Commercial foundations
Play Billing entitlement service, backend validation, purchase/refund lifecycle; Google Drive OAuth/backup if required for MVP. Exit: provider sandbox and security tests.

### M6 — Optional media research
Only evaluate clearly disclosed, authorized, permitted capture workflows on real device matrix. Verify all privacy indicators, lifecycle/service limitations, policy eligibility and distribution constraints. If these cannot be met, omit capture permissions and features from release.

### M7 — Publication
Freeze dependency/SDK inventory; complete Data safety from actual app, privacy/deletion live pages, store graphics/screenshots, declarations and reviewer demonstration; app signing/AAB 16 KB checks; testing tracks and rollout readiness; fix Play review findings.

## 8. Rollout and incident response

- Use internal testing, then closed testing, then staged production percentage as appropriate.
- Monitor crash/ANR, device sync failures, unauthorized API errors, location staleness, queue depth and subscription state.
- Establish kill switches for unsafe/misbehaving modules, server rollback and DB migration rollback/backups.
- Security incident path: triage, credential revoke, access audit, required regulatory/user notices, fix, retest and postmortem.

## 9. Release approval table

```text
Release:
Parent AAB:
Child AAB:
Backend build:
SRS traceability completed:
Security signoff:
Privacy/legal signoff:
Google Play policy declarations completed:
Device matrix signoff:
Billing/Drive verification:
Release manager approval:
Actual Play Console review status:
```

Anything left blank is a blocker for claims that the corresponding area is complete.

## 10. Additional M0/M1/M2 Indian-law, emergency and recovery go/no-go (2026-10-26)

| Gate | Required signoff and actual evidence | Stop condition |
|---|---|---|
| **M0-LAW** | India publisher, age scope, DPDP sections 9/16 and Rule 12 interpretation from India lawyer; consent/parent verification procedure; Chicago cross-border review | Synthetic data only until signed |
| **M0-POLICY** | Real owner authorizes B-07/B-09/B-18 retention and child guardian access; backend enforces scoped grants | No child-data onboarding |
| **M1-AUTH** | Google Sign-In/Credential Manager candidate independently verified; identity/person-age review separate | No production identity |
| **M1-DEVICE** | Older and newer Android real phones plus approved resettable DPC spare, manifest/FGS and device-owner actual evidence | Cannot claim M1 hardware ready |
| **M1-TEAM** | Named Android/C++/QA/security/SRE owner, legal counsel and support staffing cash budget | No delivery or release commitment |
| **M2-PRIVACY** | Separate lawful scope for current location, history, usage, geofences, SOS, apps; privacy notices and deletion tests | Location/usage for real minors OFF |
| **M2-SOS** | Tested guardian ACK and optional SMS + independent fallback path; or explicit **best-effort check-in** only | No emergency SOS promise |
| **M2-DR** | Approved, clocked RPO/RTO from failed-VM/restore tests, backup erasure and active on-call | No real child pilot |
| **COMMERCIAL** | 50/500 actual tax-inclusive-or-exclusive Play prices, real settlement, staff/support/HA, refund and churn break-even | No profitability assertion or paid launch |

Evidence docs: [India DPDP](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md), [SOS](../../M4-usage-health-sos/01-usage-health-and-sos/SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md), [DR](../01-cloud-infrastructure/OCI_CHICAGO_RECOVERY_AND_PILOT_READINESS.md), [Staffing/unit economics](../../M7-commercial-integrations/01-commercial-plans-and-costing/PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md), [Owner decisions](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md). Never close a gate with this table alone.

## 11. Canonical M0–M9 and M1 test/CI authority

Use [single master milestones M0–M9](../../M0-foundation-and-approvals/01-project-governance/MASTER_MILESTONE_IMPLEMENTATION_AND_RELEASE_PLAN.md) over the old M0–M7 table above. In particular M1 must pass [M1 OpenAPI](../../../openapi-m1.yaml) structural lint, [migrations](../../../../backend/persistence/migrations/0001_m1_identity.sql), [two-family negative RLS test](../../../../backend/tests/m1_tenant_isolation.sql), and [T-M1-01…14 detailed cases](../../../../backend/tests/M1_ACCEPTANCE_TEST_CASES.md). A [GitHub Actions CI](../../../../.github/workflows/m1-contract-and-tenant.yml) defines a PostgreSQL 16 execution environment. Real phone/DPC, backend handlers, legal under-18 authority and actual OCI India tenancy remain blocked.

## Media research and failure-reason tests added (2026-10-26)

Owner accepts conditional audio/camera/snapshot/video/file access engineering objectives and Madalasa parent-visible unavailability explanations; **not released**. Add `T-MEDIA-01–18` defined in [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md): on-device STANDARD vs true MANAGED_DEVICE_OWNER service start; initial permission then revocation; system camera/mic indicators; front/rear flash-off; continued valid session after Alarka main Activity closes; audio/video live and encrypted parent-local recording; Android 14+ MediaProjection consent **every capture session**; secure screen protection; MediaStore/SAF grant rejection; parent status and exact reason/next action; offline/stale capability distinction; concurrent revoke; TURN/P2P failover, device impersonation, endpoint loss, and no VPS media files.

**Pass/Fail:** No permission/sensor inference from an offline device; no `COMPLETED` on FCM delivery; specific `reason_code` and safe UI action visible for every unavailable request. Child-facing notification and OS sensor indicator remain intact. All media test evidence is NOT STARTED until real builds, actual devices, legal counsel, security audit and Play gates permit it. Synthetic/adult test data only before approved child-data pilot. M0–M9 release scope not changed.

## 2026-10-27 capability onboarding and synchronization acceptance plan (design only)

Add [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) T-CAP-01…24: baseline local read-only hardware discovery, no sensitive capture, secure pairing/PoP, guarded device POST, parent child-scoped GET, per-permission explanation and Android-owned grant window, separate foreground/background location (11+), denied/don't-ask-again, approximate/temporary grants, partial photos/SAF, Usage Access special settings, notifications, true vs false DPC, camera/mic runtime FGS restrictions, MediaProjection per-session consent, accepted server revision, stale/reordered/duplicate reports, offline/revoked/regrant, cache/SSE cross-family grants and accessible parent explanations.

**Acceptance for each grant:** Android actual permission state witnessed → authenticated Alarka revision generated → server durable ACK → parent reflects last verified state and time; never turn operational green for blocked or unreleased feature. A permission revoke may terminate process; without fresh child proof, parent shows UNKNOWN/STALE. Negative cases include wrong-family viewer, forged parent 'granted', outdated green resurrection, force-stop, no network and release-flag OFF. Capture Android API/OEM/device, screenshots, OS logs, backend request IDs and build SHA. Figma A-01…A-24/P-01…P-22 are mockups only; no runtime tests passed. Keep minor data/media disabled until India legal and Play clearance.

## 2026-10-27 media activity/audited administrator test plan (design only)

Add T-AUD-01–22 from [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md) and T-ADM-01–14 from [Administrator Console Specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md) to planned QA catalog. Android: camera in use/resource limit, audio silenced with no speculative phone-call cause, permission/background service rejection, screen-share per-session consent, parent-view display and local-save evidence, UTC-active-duration/null file-size and no media binaries on VPS. Backend: device/parent actor-binding, dedup/replay/out-of-order receipts, command vs stream status, offline unknown, normalized reason codes, encrypted transit, append-only events and durable projection. Parent: child name/ID dropdown limited to currently linked children, date range inclusive/exclusive timezone, media/outcome/reason, empty/permission error/last verified, stable keyset pagination and child-change cursor reset.

Admin: MFA case/purpose expiry, support aggregate only, parent/child name+ID autocomplete scoped to case, child constrained by selected parent, pagination stable under filters, restricted detail and no direct media URL, access audit for lookup/suggestion/export attempt, fail closed when audit write fails, break glass dual control and retention/delete integration. Adversarial cases: parent from another family, forged cursor, out-of-case autocomplete, insider admin enumeration, expired case, app-reported false VIEWED, unknown file size and phone-call attribution from generic failure. Include 500/1000-child load estimates and Postgres index EXPLAIN. All tests remain NOT_TESTED; no legal/Play approval or real-minor capture granted. Figma designs [28 audit screens](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-2) are UI handoff only.

## 2026-10-27 accepted PostgreSQL inbox + C++ bulk ingestion validation suite

[MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) adds **T-ING-01…24 (ALL NOT_TESTED)** across child device, API, DB workers and parent history. On supported Android/Watch OS devices test adaptive sampling vs independent eligible 1–2min upload attempts, WorkManager 15min periodic floor, correctly started location FGS and monitoring notice, encrypted local SQLite capacity for 48h when network unavailable, stable timestamps/event IDs/rounding, overflow and restart. Verify API Tx A: device/family authentication, 100–500 point+compressed byte limits, duplicate same batch+digest, different digest 409, **202 QUEUED after PostgreSQL durable inbox commit**, not in-memory/socket receipt.

Simulate process kill/API response lost between commit and ACK, worker crash before/after Tx B, lease expiry/races with fencing, queue backlog and poison batch quarantine without silent ACKed data loss. Tx B must atomically commit dedup ledger, raw PostGIS/time partition rows, reconstruction outbox and inbox PROCESSED with prepared multirow or COPY staging + INSERT SELECT, including correct event-time late 48h trip revisions and revoked-child tombstones. Measure 1k/10k/100k synthetic load (normal, school commute rush, simultaneous 48h reconnect), p95/p99 ACK, write amplification/WAL/storage/CPU/memory/DB locks/parent read p95, and **direct raw bulk vs inbox bulk** under equal data and failure conditions. Test separate app usage session data, parent latest location and "pending/raw/processed" quality labels. Release gates: child GPS and behavior monitoring India DPDP/Play decision, guardian scopes, deletion and monitoring identity. Figma [HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-2) / [LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-60) are not runtime proof.
