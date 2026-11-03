# Free-first public release — first 108 child-service slots

**Decision date:** 2026-11-03 | **Owner direction:** Implement and publish a free-only version before merchant/BillDesk approval; preserve, but disable, all paid/preview functionality. **Engineering status:** partial implementation in PRs #28–31. **Real-child public release:** NO-GO until legal, Android and Google Play gates pass. Do not represent a code commit or Figma frame as publication.

The detailed engineering checkpoints, edge-case acceptance matrix and customer-facing alternate copy are recorded in [the 108-child implementation supplement](FREE_FIRST_108_CHILD_RELEASE_ROADMAP_2026-11-03.md). This page remains the release-sequencing source of truth.

## Child app is fully free; activation is parent-pairing-dependent

> **Optional hardware and Pingo comparison (2026-11-04):** The child implementation now scans available accelerometer, gyroscope, proximity, ambient light, GPS/network provider, battery, camera/microphone hardware and more without collecting sensor samples. Missing hardware disables only that optional module; GNSS NavIC support stays unknown until an approved satellite observation. Camera/microphone remain disabled, and their dangerous permissions are not requested in the public free manifest. Pingo's public Play listing is a useful architectural example, **not** proof of our eligibility. See [Pingo / optional hardware specification](PINGO_COMPARISON_OPTIONAL_DEVICE_HARDWARE_2026-11-04.md) and [editable Figma hardware screens](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=179-3).

> **Android 10–16 capability implementation (2026-11-03):** The child branch adds runtime hardware/manifest/permission observation, explicit per-API permission planning, user-tap-only Settings and OS runtime permission handlers, Android 10–16 JVM and device-test harnesses, and a debug-only visible service scaffold. Production location sensor/FGS/ingestion is **NOT** ready; default free public manifest remains sensor-free pending Google Play/Families/legal review. See [Android 10–16 release gates](ANDROID_10_TO_16_FREE_RELEASE_COMPATIBILITY_2026-11-03.md).

> **QR PRIMARY DESIGN (2026-11-03):** Alarka displays a short-lived server-issued invitation QR; Madalasa scans and a guardian explicitly approves. The 10-character one-time code remains a fallback. The backend enforces one active child device using additive V2 migration 0024, with minimized device-specification audit and privacy erasure. QR issuance/claim/polling and scanner UI are **not yet live**; see [QR pairing contract](QR_PAIRING_SINGLE_DEVICE_2026-11-03.md) and [editable QR storyboard](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=177-3). (owner decision 2026-11-03)

**Mandatory architecture boundary:** Alarka is a full, separately installable **free** Android child companion. Implement every compliant child-side screen, device integration, safety function and back-end protocol planned for the release; do **not** delete, defer, stub or paywall child-app engineering merely because billing is delayed. A child can download/install/open Alarka without a subscription, credit card or active parent device, and can view public setup, disclosure, privacy/permissions information, support and device compatibility locally.

**Activation is a separate state, not the installation state.** Before verified parent-initiated pairing, Alarka must NOT collect/upload child monitoring data, start monitoring foreground services, execute remote actions, request unneeded sensitive permissions or assert an approved guardian. Parent creates a child account, receives admission into one of the **108 service slots**, completes lawful guardian/consent checks, and issues a short-lived, one-time pairing code. The child installation enters that code, proves possession of a fresh Android Keystore P-256 private key to the backend, and accepts only a real backend-issued device credential. **Pairing is necessary but NOT sufficient** for monitoring: re-check server-side child admission, consent, legal/purpose gates, OS permissions and a visible disclosure notification at activation and on every resume/renewal/policy change. Offline, expired, revoked, waitlisted, unknown and partially configured states fail closed; unpair immediately stops monitoring and wipes device-side credentials, with server revocation tracked separately.

**Payment independence:** Alarka has no purchases, billing SDK, subscriptions, trial unlocks, paid gates or payment-profile dependencies. Later guardian-side paid plans may change backend entitlements after separate approval, but never prevent free installation/pairing setup, permission controls, privacy/deletion access or required safety visibility. The global 108 cap governs **admitted child services**, not installation/download count. A WAITLISTED child must not receive a usable pairing code; parent signup completes and status remains visible. Upon promotion, the guardian still has to initiate pairing.

**Required implementation evidence:** production release flavor uses HTTPS protocol `POST /v1/enrollment` and `POST /v1/enrollment/{enrollmentId}/proof` with exact backend **10-character** parent-issued pairing codes (not six-digit synthetic preview codes), hardware-backed key where available, cryptographic proof, encrypted credential storage, expiry/rotation/revocation; verified device/child binding; permission screens; accurate persistent monitoring disclosure; approved location delivery and offline queue; SOS/check-in only if independently cleared; local privacy controls; Play/Android/legal tests. Test negative pairing, replay, 108/109 cap, cross-child and cross-family attempts, uninstall/reinstall, offline, consent withdrawal and foreground-service restrictions. Existing synthetic scaffolding is NOT evidence of a completed production child app.

## 1. Release sequencing (new source of truth)

**Stage F0 — local / synthetic:** Merge approved PRs `api`, `parent`, `child`, `admin-web` via `dev` only after all GitHub CI/DB and Android tests pass. A new V2 migration 0023 enables global 108-child admission and FIFO waitlist. All premium code, database tables, SKU catalog, 48-hour Super Access, media and admin billing reporting remain in source; public endpoints and checkout actions default to **OFF**.

**Stage F1 — free-only production candidate:** Complete verified adult account login, family and child registration, exact-child authority/consent, Android child enrollment and visible tracking disclosure, the parent location API, 6-hour server-enforced history, essential account and guardian controls, child unpair, deletion and support. Implement transparent 10–15-minute *moving target* sampling (not a guaranteed OS delivery interval), offline queue, failed permission statuses and no remote media. No financial account/profile required for free-only signup. Release feature flags must be OFF by default and server-enforced, not just hidden in Compose.

**Stage F2 — limited rollout:** Operator and legal reviews, physical Android OEM tests, accurate Play declaration and Data Safety, final eligible target-audience positioning, app bundles/keys/listing and internal/closed testing where applicable. Begin with synthetic testers; real-child data only after compliance approval. Stage 108 active child slots; remaining successful registrations join the queue. The public app is **not** yet published; do not use production status until the Play Console provides evidence.

**Stage F3 — merchant/paid review in parallel:** During F2 operation, continue BillDesk submission/KYC/approval discussions, Google Play Billing and prepaid products, refund reconciliation, founding-user eligibility, verified Play pricing, trial, premium media conditional feasibility, concurrent-viewer add-ons, and paid security tests. **Do not assume BillDesk requires a public Play listing absent written provider instruction.** A live free listing is independent of merchant activation, but cannot bypass other release gates.

**Stage F4 — reviewed paid update:** Activate only after approved merchant/legal/Play gates and explicit release signoff. Publish as an app update with exact entitlements and Play-verified prices. No automatic migration from free to paid, no surprise subscription, no retroactive trial, and no lost child/guardian grants. Work requiring media/OS permission review stays disabled if its own gates remain closed.

## 2. Free-tier entitlement contract

| Capability | Initial F2 free release | Restriction / evidence |
|---|---|---|
| Verified adult signup / family registration / child profile | ON for all eligible adult guardians | Registration completes even when 108 slots are full |
| First 108 **distinct child profiles** | ADMITTED slot | Slot is not automatic consent/device enrollment |
| 109th and later | WAITLISTED | No tracking, device pairing/enrollment, location/history reads, child service ingestion |
| Child location tracking | ON **only after admission + independent authority/consent + supported OS permission + device proof** | Moving collection target 10–15 min; stationary slower; offline unknown |
| Visible location history | Last 6 hours only, server RLS | Physical retention separately approved, not implied by six-hour visibility |
| Parent account/support/privacy/consent/erasure | ON for signed-in authorized adult, including waiting family | Privacy rights do not depend on payment/slot |
| Payment checkout, prepaid SKU, 48h Super Access, coupons, additional viewer, media, paid usage controls | OFF in server and UI | Code retained for later review |
| SOS/check-in and other legacy proposed features | Not automatically declared free | Enable only after independent release, legal, safety and device test check |

**108 is an initial deliberately hard-coded operational service ceiling, not proof of a 108-device reliable/SLA capacity.** One child = one slot even if two parents or two devices. Reinstalls and repeated signups must not create duplicate service admissions to inflate supply. Adults may manage multiple child profiles: each is admitted/queued independently.

## 3. Queue behavior and data contract

- On an authenticated child profile creation, database serializes all concurrent placements with one advisory transaction lock, records ADMITTED when fewer than 108 eligible children occupy slots, and otherwise records WAITLISTED. The child profile is created either way.
- The registration response contains `free_service_state`, `slot_limit:108`, and a nullable positive `queue_position`. A replayed idempotency key must not create a second child or second queue entry.
- Queue order is `queued_at,child_id` ascending (stable tie-breaker). Exact place is a snapshot that may change after deletion/verification; no estimated date is promised.
- Copy: **“Signup complete. You are in the service queue. We'll allocate a child-service slot as soon as one becomes available. Your child's free services have not started.”** Optional “Current queue position: N” is shown only when the server verifies it.
- While WAITLISTED, guardian can sign in, see status, contact support and exercise child privacy/deletion rights, but **cannot** issue pairing codes, activate devices or receive child-service data.
- A new slot is released on a durable authorized child-erasure tombstone, not merely because a device went offline, a subscription lapsed or an administrator manually reduced a counter. Reallocation occurs atomically, FIFO; the promoted child then still requires lawful consent, device setup and Android permissions.
- Waitlist joining, leaving, and promotions must not send sensitive child aliases or queue data to unauthorized users. Queue aggregate counters need no public child identities.

## 4. Existing implementation anchors and truthful gaps

| Area | Existing/new code | Status |
|---|---|---|
| Admission | `backend/persistence/migrations/0023_free_first_108_child_admission.sql`; migration lineage | Implemented; DB regression pending fresh CI evidence |
| API | `backend/src/children_create.h`, `children_read.h`, `parent_reads.h` | Admission status in create/list/detail, server-scoped reads |
| Free location | `backend/src/free_location_reads.h`, `main.cc` | New latest and history routes, explicit six-hour SQL bounds; HTTP+real-device acceptance outstanding |
| Free release latch | `backend/src/release_profile.h`, `main.cc` | `MA_RELEASE_PROFILE=FREE_ONLY` default; billing and 48h trial paths not registered; production switch needs separately approved evidence |
| Parent UI | `android/madalasa/...` on `parent` branch | Signup, waitlist row and no pairing/selection for queued children; backed by HTTPS API only when configured |
| Child app | `android/alarka/...` on `child` branch | Debug-only synthetic enrollment retained; child work branch now includes an opt-in HTTPS/AndroidKeyStore P-256 challenge/proof adapter requiring a configured API origin, short-lived encrypted credentials, production 10-character parent codes, and a separate activation policy. Actual foreground monitoring/location collection, credential renewal, cross-device E2E, Play/legal approvals and device tests are still outstanding; **not real-child release ready** |
| Figma | Existing source file, new page `FREE FIRST • 108 Child Slots • 2026-11` | Editable frames: 01 signup, 02 queued, 03 admitted, 04 premium disabled |
| Admin | PR #29 and original admin designs | Role/security progress; queue operator reporting and safe support workflow outstanding |

## 5. Required tests before declaring 108 slots live

- 107→108→109 concurrent child creates across multiple families, 5–20 mixed concurrent requests, same-key idempotency, change of family, duplicate aliases, rollbacks, and restoration/reboot consistency.
- Postgres cap never exceeds 108 under races; exactly one admitted child per profile; queued child cannot create pairing, activate device, ingest location, read history, use SOS/commands or obtain media regardless of old premium entitlements. Verify all child-service endpoint families and RLS policies.
- Tombstone releases one slot and atomically promotes earliest queued; no promotion for heartbeat expiry or device offline; correct queue position for each authorized parent and none for cross-family attacker.
- Parent UI should show queue message only after HTTP 201 and refresh from server; no false “Connected” status. Child app must not have sensor grants before approved policy and OS permission path.
- Retention, consent withdrawal, backup restoration and status after parent logout/reinstall; account deletion when WAITLISTED.
- 108 admitted children load/battery/CPU/WAL/DB p95 tests, backup/restore, 6-hour history windows across timezone boundaries; fail-closed under unavailable server.
- Android release manifests, actual Google Play monitoring metadata, persistent notification, location permission declaration as applicable; Google Play audience/Families policy and India DPDP counsel signoff.
- Public release must have exact build/commit SHAs, green workflow evidence, approval owners and Play Console link. Do **not** auto-publish.

## 6. Roadmap dependency changes without deleting existing tasks

The canonical 262-task graph remains intact. Insert the **Free-First release gate F-108** before publication: prioritize L04 adult family/authorization, L05 child pairing and permissions, L06 telemetry, L07 free map/history, relevant L09 safety, L12 parent app, L13 child app, L14 support/security, L15 privacy, L17 hardening and L18 local acceptance. Add hard acceptance checks for 108 admission and queue UI. **Defer launch dependencies L10 (billing/trial), L11 (premium viewers) and conditional L16 (media).** They remain available in code and separate future paid delivery branches, not removed or marked PASS merely because free release does not include them.

### External release constraints

Google Play's monitoring policy requires visible disclosure, persistent notification, a unique monitoring icon and `isMonitoringTool` metadata. Its Families policy says apps solely targeting children may not request location permission or collect/transmit precise location; there is no automatic parental-monitoring exemption. Whether the intended child companion can lawfully and compliantly collect location in its target-audience distribution is a **publication blocker requiring policy review**; do not conceal its actual purpose or retarget audience misleadingly. Official references:

- https://support.google.com/googleplay/android-developer/answer/18265346
- https://support.google.com/googleplay/android-developer/answer/9893335
- https://support.google.com/googleplay/android-developer/answer/12955211
- https://support.google.com/googleplay/android-developer/answer/9799150
- https://support.google.com/googleplay/android-developer/answer/14151465

**Release verdict as of document revision:** source implementation underway; **NOT published to the Play Store**, **no production real-child tracking authorized**, and **no BillDesk/Play paid approval verified**.
