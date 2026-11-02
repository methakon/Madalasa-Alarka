# Madalasa–Alarka — M1 Technical Architecture and Implementation Contract

> **Document control:** M1 / 01-requirements-and-architecture · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Product names:** **Madalasa** (parent app), **Alarka** (child app). Desired repository name **Madalasa-Alarka** is **completed GitHub repository rename**. Use the verified new repository URL for all current documentation and integrations. [Naming rationale](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Revision:** 1.0, 2026-10-25  
**Status:** Design/proposed implementation, **not implemented or device-tested**  
**Constraints confirmed:** managed-device provisioning available; older and newer Android devices; native parent Android app; low battery/CPU/RAM priority; transparent monitoring; Kotlin + C++ NDK child; C++ backend.

**Canonical related docs:** [SRS](SRS.md), [Technical Specification](TECHNICAL_SPECIFICATION.md), [Feasibility](../../M0-foundation-and-approvals/02-market-and-feasibility/WHOLE_PROJECT_FEASIBILITY_GATE_2026.md), [Data/Authorization/Recovery](../03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md), [Android/Algorithms](../../M2-location-collection/01-location-collection-and-ingestion/TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md), [Test Traceability](REQUIREMENTS_TRACEABILITY.md).

## 1. Architecture selection

~~~text
Native Parent Android                           Child Android (STANDARD or managed DPC)
 Kotlin + Compose/Maps                           Kotlin Activities + PermissionRegistry
 OIDC/PKCE account                               Android Keystore enrollment keys
 Family, child, device list                      Capability probes + monitoring disclosure
 App-use/location dashboard (M2+)                Location service + UsageStats (M2+)
        |                                        Android DevicePolicyManager adapter (M1)
        |                                        Thin JNI adapter → C++20 portable core
        |                                                    |
        +---------------- HTTPS ------------------------------+
                             |
                      TLS / rate limits
                             |
                    C++20 Drogon API
                 Auth + pairing + authorization
                 Device capabilities + commands
                 Typed execution results + audit
                             |
                     PostgreSQL
                  family / child / device
                  grants / credentials / commands
                  outbox / audit + PostGIS (M2)
                             |
              Separate C++ reconstruction workers (M2+)
                     trips / stops / quality
                             |
                     parent maps/history API
~~~

**Rationale:**
- Android OS services, permissions, notification/FGS and device policies must be implemented via Kotlin (or Java), not pure NDK.
- C++20 NDK is useful for portable bounded DTO validation, event handling and later reusable pure algorithms; do not use permanent native sensor poll loops.
- C++20 Drogon API supports asynchronous network handling. CPU-heavy geospatial analysis must run in separate C++ workers, not HTTP I/O threads.
- PostgreSQL stores durable family/device state; PostGIS supplies proximity and route support later.
- Parent map opens read existing data; multiple viewers must never each wake up child GPS.
- Minimal cloud architecture initially: one API service + PostgreSQL + worker, scale replicas independently after observed load.

## 2. Application modules

| Component | Owner/language | M1 deliverable | Later work |
|---|---|---|---|
| parent-app | Kotlin/Compose | login, child profile, pairing UI and device status | Google Maps, trips, app usage, subscriptions |
| child-app | Kotlin Android | transparent setup, Keystore ID, pairing, capability snapshot | low-power compliant location, Usage Access and child SOS |
| child managed DPC | Kotlin DeviceAdminReceiver | owner role probe and test app suspend/restore | schedules, safely blocked packages, rollback |
| shared-core | Portable C++20/CMake + NDK/JNI | domain DTOs, parser limits and unit tests | event serialization, queue helpers |
| backend-api | C++20 Drogon | parent/device authentication and onboarding/health API | ingestion and read endpoints, notifications |
| persistence | PostgreSQL | normalized family/guardian/child/device/keys/grants and commands | raw GPS partitioning, PostGIS, usage aggregates |
| worker | C++20 worker process | compileable worker skeleton | trip/stop event-time reconstruction and job leases |
| operations | CI + test infrastructure | build/test, migration, secrecy checks | alerts, backup restore, scaling/benchmarks |

Proposed layout:

~~~text
android/parent-app/
android/child-app/
android/child-app/src/main/cpp/
shared/core/include/
shared/core/src/
shared/core/tests/
backend/api/src/
backend/domain/include/
backend/persistence/migrations/
backend/worker/
backend/tests/
infra/compose.dev.yaml
.github/workflows/
docs/
~~~

Use current compatible Android Gradle Plugin, Kotlin, NDK r28+ with verified 16 KB shared-library alignment, and CMake/CTest. Pin exact versions in code lockfiles, not merely in this specification.

## 3. Standard vs managed device architecture

| Capability | STANDARD installed app | Fully managed DPC device-owner mode |
|---|---|---|
| Secure setup, capability report, parent device status | Available | Available |
| Location while properly permitted | Allowed under Android location/FGS rules | Allowed under those rules; documented DPC exceptions may help service starts |
| App usage reports | Separate Usage Access or allowed mechanism | Same unless a specifically validated management policy applies |
| Package suspension/restrictions | **No universal enforceability** | DevicePolicyManager.setPackagesSuspended on eligible packages |
| App-limit schedules | Advisory if no authority | Eligible local device policy enforcement and audit |
| Protected system apps | Cannot arbitrarily block | Many critical/active apps remain unsuspendable |
| Private app data, hidden camera/microphone | Not enabled | **Still not generally granted** by device-owner status |

Fully managed provisioning is a **separate** lifecycle: appropriately prepared device, often factory reset, enterprise-style enrollment (e.g. QR). ADB set-device-owner is a lab-only procedure, not a consumer onboarding shortcut. Runtime app must verify isDeviceOwnerApp before invoking privileged policy APIs, and inspect the returned unsuspendable packages. A managed profile is not equivalent to whole-device owner status.

### Managed owner proof (M1)
1. Prepare a **consented expendable test handset**; back up/erase beforehand. Confirm supported provisioning path for device model/API.
2. Provision test DPC as owner (document whether QR or lab ADB), verify role programmatically and save non-sensitive evidence.
3. Choose a harmless installed third-party **test package**; do not target the launcher, DPC, dialer, emergency, permission controller or OS-critical packages.
4. Apply setPackagesSuspended using verified DeviceAdminReceiver, record returned packages/errors and check actual target state.
5. Restore the package and verify it can launch.
6. Repeat on ordinary STANDARD install: return UNSUPPORTED_MODE or OS_REJECTED, not fake success.
7. Record exact model, manufacturer, build fingerprint, API, targetSdk and evidence ID.

Managed enrollment availability is a development assumption; **actual DPC authority and distribution path remain empirical gates**.

## 4. Android version and permission plan

**minSdk=29 (Android 10)** is a proposed candidate until available test devices are specified. Compile/target new standard Play builds at **API 36+** under the 2026 policy; a future separate Wear OS app follows its own **API 35+** requirement. Device API level must be probed dynamically.

| Device API/OS | Major change | Implementation outcome |
|---|---|---|
| 29 Android 10 | Background location may be granted via dialog; location typed foreground service | Permission onboarding branch |
| 30 Android 11 | Background-location grant generally via settings | Guided settings with refusal option |
| 31–32 Android 12/12L | Background foreground-service start restrictions, approximate location | Catch unsupported service starts |
| 33 Android 13 | POST_NOTIFICATIONS runtime state | Device reports actual notification state |
| 34 Android 14 | Foreground-service type permissions and while-in-use start checks | Check actual lifecycle, catch SecurityException |
| 35 Android 15 | Additional service background/boot restrictions | Explicit reboot/lifecycle test |
| 36 Android 16 | Latest Play target, newer devices | New API behavior and native page-size test |

A foreground location service is **not** the same as an Activity that stays open. Child Activity may close after onboarding, but required monitoring notification/app icon/disclosure remain. A runtime location permission does not alone guarantee starting a new service from background; Android 14+ can reject startup at creation. Device-owner exception applies only in qualified documented circumstances.

## 5. Low resource design

**No persistent parent-to-child socket; no map tiles on child; no per-second polling; no permanent NDK worker loops.** Report permissions/health on enrollment and sparse synchronized heartbeats.

M2 location defaults to test, not performance claims:
- STILL/PASSIVE: opportunistic or requested 5–15 min.
- WALKING: 30–90 sec at balanced accuracy.
- MOVING CAR (balanced): 30–60 sec.
- TIME-LIMITED DETAILED CAR: 5–15 sec only where user-authorized, OS permitted and battery acceptable.
- Low-battery: downgrade priority/sample rate and communicate reduced coverage.
- Local queue: encrypted SQLite/SQLCipher or reviewed equivalent with Android Keystore-wrapped key; default SQLite alone is not encrypted.
- Upload: bounded batches through WorkManager with backoff, do not send each observation separately; backend ACKs only after durable commit.
- Capture CPU/PSS, network bytes, GPS fix frequency, wakeups, charge deltas and source device metadata for later measurements.

The above intervals are **requested hints** and can be throttled; do not guarantee street-perfect route reconstruction from sparse points.

## 6. Pairing and identity implementation

**Parent:** OIDC Authorization Code + PKCE with test identity provider in M1; production provider approval remains a separate decision. Backend validates issuer, audience, expiry, child action grant and tenant scope.

**Child setup sequence:**
1. Authenticated parent creates family/child and a short-lived one-use pairing code/QR (candidate lifetime 10 min).
2. Child displays monitoring disclosure; generates new private/public key in Android Keystore; private key never exported.
3. Child submits pairing code + public key + app version. Backend atomically consumes code and binds device to family/child.
4. Server returns enrollment ID and cryptographic challenge; device signs challenge with Keystore key.
5. Server validates signature; issues revocable short-lived device credential, bound to enrolled device ID.
6. Device posts timestamped capability snapshot (API, managed role, access grants). Parent sees device mode and last seen.
7. Device revoke disables its key and future telemetry; reinstallation/key loss requires approved re-enrollment.

**M1 interface contract:** The draft [OpenAPI](../../../openapi.yaml) now includes /enrollment/{enrollmentId}/proof for device proof-of-possession and DELETE /devices/{deviceId}/pairing for guardian-authorized revoke. Their handlers, cryptographic validation, formal OpenAPI lint and generated Kotlin/C++ DTOs are **not implemented or tested**.

**Security tests:** reused code, expired code, forged public key/nonce, wrong family, mismatched device ID, revoked key, read across families, spoofed capability status, role-changing attacks, request flooding and logs without secrets.

## 7. Core database and authorization

M1 tables: families, parent_principals, children, guardian_memberships, child_guardian_grants, pairing_codes, devices, device_key_records, capability_snapshots, commands, command_results, audit_events and revocation epochs.

Required constraints:
- Child belongs to exactly one canonical family.
- Device belongs to a valid family+child FK; one active enrolled key per device unless rotation workflow explicitly allows grace.
- Parent family membership alone does not grant every child. Child-specific action scope + expiry + revocation must be checked per endpoint.
- A device credential may only report **its own** capabilities and accept commands for its own enrolled device.
- PostgreSQL app SQL role is non-owner/no BYPASSRLS; transaction-local verified family context is defense in depth, not replacement for server child-level authorization.
- Log actor/operation/result, not precise location or auth material.
- Use unique one-use pairing code verifier, rate limits and audit for failed enrollments.

See [Data/Authorization/Recovery](../03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md) for SQL/RLS and deletion ordering.

## 8. First implementation milestone: M1 — Secure Foundation and Managed Capability Proof

**Goal:** Pair one authorized child phone to the native Android parent app through C++ backend, report real capabilities, and verify eligible device-owner package suspend/restore on one provisioned test device. Full continuous tracking and app usage reports are **M2/M3**, not M1 acceptance.

| ID | Work item | Deliverable | Exit condition |
|---|---|---|---|
| M1-01 | Monorepo build | Gradle parent/child debug builds, C++20 core CMake/CTest, Drogon CMake server and CI | All build/test jobs run with locked deps |
| M1-02 | SQL migration | Versioned family/child/guardian/device/key/pairing/capability/command/audit migrations and RLS | Clean migrate/rollback + cross-family negative queries |
| M1-03 | Parent OIDC | Compose sign-in, family/child setup, device list | Correct child-scoped auth, no static auth secrets |
| M1-04 | Enrollment API | Issue/redeem one-use code, PoP challenge/signature completion, revoke | Replay/expired/forged device rejected |
| M1-05 | Child Setup | Onboarding disclosure, app icon, Keystore identity, code scan/entry | Parent physically pairs test device; main Activity may close |
| M1-06 | CapabilityRegistry | Actual permission states, API, managed mode, app version, heartbeat | Last-observed timestamp and truthful support states |
| M1-07 | Managed DPC proof | Test DPC provisioning, owner check, safe test package suspend and restore | Result verified and rollback successful |
| M1-08 | Shared C++ NDK core | Versioned DTO parsing/bounds and JNI smoke test | CTest and Android instrumentation pass |
| M1-09 | API security/observability | Auth filters, child scope, rate limits, typed errors and redacted audit | No cross-family access in controlled tests |
| M1-10 | Verification artifacts | Evidence register, Android matrix and resource idle baseline | Exact build/device/test result referenced |

### Acceptance tests

| ID | Scenario | Must demonstrate |
|---|---|---|
| T-M1-01 | Parent A pairs child device | Authenticated parent device list shows correct child and device |
| T-M1-02 | Parent B guesses Parent A child ID | Forbidden; no metadata/location access |
| T-M1-03 | One-time code reused/expired | Refused; no second enrollment |
| T-M1-04 | Enrolled key lost or challenge spoofed | Invalid proof refused; re-enrollment required |
| T-M1-05 | Parent revokes a device | Next authenticated device heartbeat denied |
| T-M1-06 | Ordinary installed child app | Reports STANDARD, no claim to universal suspension |
| T-M1-07 | Real owner-provisioned child device | Verified MANAGED_DEVICE_OWNER after OS check |
| T-M1-08 | Managed safe package suspend/restore | Target becomes inaccessible then restored, audit records results |
| T-M1-09 | Attempt suspension on standard/protected package | Safe UNSUPPORTED/OS_REJECTED and no OS damage |
| T-M1-10 | Close setup Activity | Child monitoring identity persists; no Activity kept permanently open |
| T-M1-11 | Invalid/huge JSON or unauthorized repeated calls | Bounded response, 4xx/429, service doesn't crash |
| T-M1-12 | Older and newer OS probes | Correct permission/state distinctions, no invented capability |
| T-M1-13 | NDK native .so packaging | Verified 16 KB ELF/zip alignment and native smoke test |
| T-M1-14 | No user data in debug logs | Tokens, pairing code and raw location absent from normal logs |

**Definition of Done:** M1-01–10 implemented and T-M1-01–14 passing in test environments; physical managed-device proof recorded. If a managed test device cannot be safely provisioned, mark **M1-DPC BLOCKED**, not passed. Final product publishing requires separate security/privacy/Play gates.

## 9. Follow-on work

- **M2:** Location runtime + encrypted queue + server durable batch ingest, last-position map and Android background-service evidence.
- **M3:** C++ event-time stop/trip reconstruction, PostGIS named places, segmented observed routes, late offline recovery.
- **M4:** Usage Access and day/week/month/year analytics; SOS, check-ins, health/reliability.
- **M5:** Managed scheduling with protected app exclusions, C++ policy preview and full rollback.
- **M6:** Multi-guardian time-limited scope, privacy audit/erasure, commercial subscription and supported Drive integration.
- **M7:** Real battery/load/security tests, Wear/tablet expansion as warranted, Play release compliance. Defer visible authorized media research separately.

## 10. Project decisions and remaining blockers

The owner has now supplied these design constraints:
- B-05: **Managed-device provisioning available** → design dedicated child DPC path, but actual role/provisioning proof still open.
- B-10: **Mixed old/new Android** → version-aware adapters; exact minimum and supported OEM models still open.
- B-19: **Native Android parent** → no browser frontend in first implementation.
- B-03: **Transparent permission-based monitoring prioritized** → visible disclosures/icon and notification are release invariants.

Still need operator identity and launch countries/ages, retention, hosting region/provider, target OEM test fleet, Wear priority, guardian-sharing rules, subscription approach and available engineering budget. See [Blockers](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md). No owner decision overrides Android technical restrictions or child privacy policy.

## 11. Official sources

- Android Enterprise fully managed provisioning: https://developer.android.com/work/dpc/dedicated-devices
- Android DPM suspension: https://developer.android.com/reference/android/app/admin/DevicePolicyManager
- Android background FGS/while-in-use restrictions: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- Android background location consent flow: https://developer.android.com/develop/sensors-and-location/location/permissions/background
- Fused LocationRequest batching: https://developers.google.com/android/reference/com/google/android/gms/location/LocationRequest.Builder
- Play 2026 API targets: https://support.google.com/googleplay/android-developer/answer/11926878
- Native 16 KB page sizing: https://developer.android.com/guide/practices/page-sizes
- Play parental-monitoring manifest flag: https://support.google.com/googleplay/android-developer/answer/12955211

**M1 is a planned milestone, not a delivered build.**

## 12. M1 deployment target: Oracle Chicago

The confirmed **planning** cloud choice is OCI US Midwest Chicago (us-chicago-1), with Ampere A1 ARM64 VM.Standard.A1.Flex **2 OCPU / 12 GB** under free-only eligibility, **50 GB boot + 100 GB DB disk**, a single VM for C++ Drogon API + C++ worker + PostgreSQL/PostGIS, and secured HTTPS/OCI monitoring. The selected deployment/financial model is [OCI Chicago Deployment and Financial Plan](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md).

M1 acceptance must add: actual OCI account/home-region evidence; A1 shape successfully allocated; ARM64 backend binary+PostGIS installed; RLS migrations and two-family negative tests; SSL/private DB; backup+restore and cost alarms. If A1 is out of capacity, mark OCI provisioning **BLOCKED**, do not assert a running service or silently upgrade payment mode. Publisher identity, US child-data hosting law, payment/price and retention remain decisions. All cost-per-child figures are forecasts, not observed AWS/OCI bills.

## 13. M1 blocked inputs, login decision candidate and managed hardware proof (2026-10-26)

**M1 provisional auth engineering decision (OCI-06):** use **Google Sign-In via Android Credential Manager**, verify Google ID tokens on Drogon backend with issuer/audience/expiry/replay controls, issue narrowly scoped server sessions, maintain recoverable family link and device Keystore proof. This is a **technical candidate**, not approved provider selection or a verifiable adult/guardian-identity check. Legal child authority verification is a separate process and required before real minors' data. SMS/login fallback is disabled until priced/approved.

**Device hardware gate (HW-01):** owner must provide actual model/API/OEM list and a **spare phone whose factory reset the owner explicitly permits after backup**. Emulator can prove DTO and API flow, not device-owner eligibility. No factory reset performed by this documentation. Validate factory-provisioned DPC identity, protected packages, rollback, reboot, enrollment revocation and standard-mode fallback on real hardware. **M1 MANAGED acceptance fails** without resettable device proof.

**Cross-milestone barriers:** India DPDP legal entity/counsel+Chicago transfer before real child pairing, B-09/B-18 guardian policy before security SQL signoff, B-07 retention before real data ingest, and staffed QA/security owner before any public release. See [M0/M1 blockers](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md), [India DPDP](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md), [Staffing/devices](../../M7-commercial-integrations/01-commercial-plans-and-costing/PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md). M2 location/pilot also requires disaster recovery [readiness](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_RECOVERY_AND_PILOT_READINESS.md).

## 14. Master roadmap, India region and executable M1 artifact precedence

This detailed M1 design remains a technical annex; the **master [M0–M9 plan](../../M0-foundation-and-approvals/01-project-governance/MASTER_MILESTONE_IMPLEMENTATION_AND_RELEASE_PLAN.md)** supersedes its old M1–M7 follow-on numbering. OCI **Mumbai preferred**, Hyderabad fallback; Chicago is historical cost study only ([India-region gate](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_REGION_AND_M0_OWNER_DECISION_GATE.md)). The authoritative API contract for M1 is now [openapi-m1.yaml](../../../openapi-m1.yaml), not every endpoint in the whole-project draft. Migration [0001_m1_identity.sql](../../../../backend/persistence/migrations/0001_m1_identity.sql), [SQL two-family test](../../../../backend/tests/m1_tenant_isolation.sql), [all 14 test cases](../../../../backend/tests/M1_ACCEPTANCE_TEST_CASES.md) and [CI](../../../../.github/workflows/m1-contract-and-tenant.yml) are checked in. No Postgres CI success or Android device test is yet evidenced; do not mark T-M1-01–14 passed.

## 2026-10-27 discovery and Android permission wizard design bridge to M1

M1 still implements the **narrow** `openapi-m1.yaml` Capabilities payload (location, usage_access, notifications, managed_package_suspend), a device-bound `POST /devices/{deviceId}/capabilities`, pairing/Keystore proof, and 14 separate M1 tests; these schema/test contracts are **not silently revised**. The expanded owner-accepted design in [MA-CAP-ADR-002](../03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) introduces first-run read-only OS/sensor inventory, detailed stepwise explanatory Android permissions, local OS recheck after dialog/Settings, device report_version/enrollment_generation, revision conflicts, durable ACK and child-scoped parent capability GET in **whole-project draft** `openapi.yaml`. This is a **future explicitly versioned contract increment**, not an M1 implementation claim or an implicit change to linted M1.

For M1 Kotlin: keep `OnboardingCoordinator` and minimal `CapabilityReporter` abstractions extensible, differentiate `LOCAL_VERIFIED`, `SERVER_ACKED`, and `PARENT_FRESH`, protect assigned Keystore identity and handle denied, conditional, stale/offline cases. Add T-CAP-01…24 as future test catalog; do not add undeclared permissions or media capture to M1 release. Figma [Alarka wizard](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-2) and [HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=27-2) are implementation handoff, not code.
