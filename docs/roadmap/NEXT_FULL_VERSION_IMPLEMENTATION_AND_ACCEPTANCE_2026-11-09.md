# Next full-version implementation and acceptance plan

**Prepared:** 2026-11-09 (Asia/Kolkata)  
**State:** ENGINEERING_PLAN / NOT A FEATURE OR PUBLIC-RELEASE APPROVAL  
**Baseline:** Free V1 Android internal-testing candidate v0.1.0; `dev` integration PR #60; GitHub evidence reconciliation in [the dated audit](../audits/RELEASE_AND_NEXT_VERSION_IMPLEMENTATION_AUDIT_2026-11-09.md).  
**Product scope:** Expand Madalasa (guardian), Alarka (child), C++ Drogon, PostgreSQL RLS, admin, Figma and QA as one *controlled* product train. Version number beyond 0.1.0 must be explicitly selected from available Play version codes; do not assume 1.0 public release.

## Immutable boundaries

- **FREE_ONLY** until separately approved payments and merchant/Play flows. ₹99/month and ₹999/year are **future preview prices**, not active offers; Alarka has no billing SDK.
- No real-minor monitoring, background-location collection, app usage surveillance, media capture, remote commands or paid services until feature-specific lawful basis, parent authority, Google Play/Android permission and release authorization are recorded.
- Child installation without guardian account is allowed for transparent local onboarding; pairing, monitored data ingestion and sharing require all independent eligibility checks. One active device per child; no cross-family fallback.
- Never claim automatic emergency detection or guaranteed delivery. Manual SOS is best-effort, and server receipt is not human acknowledgment. Offline recovery is manual retry unless a separately tested design says otherwise.
- x402 is a constrained staging host (~954 MiB), shared with OpenSMTPD/Dovecot. No colocated PostgreSQL/PostGIS, heavy builds, new paid infrastructure or broad load without explicit approval.
- Canonical planning/docs only on `main`. Application code in permanent `parent`, `child`, `api`, `admin-web` branches; review PR → `dev`; exact-head integration CI; owner-reviewed `dev → main`. Start each workstream with clean-worktree `bash docs/tools/sync_work_branch.sh <branch>`, capture before/after SHA, and do not force-push. Coordinate open PR #60 and no automatic merge.

## Release train and sequence

| Gate | Slice | Required before progression | State at plan creation |
|---|---|---|---|
| T0 | Complete Free V1 Play Internal Testing acceptance | Actual signed/Play-installed bundle configs, production SHA/OAuth, two-phone manual SOS/ACK/outbox and negative tests; owner-approved adult synthetic devices | **P0 OPEN — Issue #61** |
| T1 | Consent, child authority and 10-character enrollment, robust pairing fallback | Backend issue/replay/revoke tests, parent guardian scope, child Keystore evidence, no waitlisted pairing | **Partially implemented; full release acceptance missing** |
| T2 | QR-first child-device pairing and admission/waitlist UX | T1, server-issued expiring QR/claim/poll, replay/wrong-family denial, accessible camera permission or safe manual fallback | **Design-only QR in 2026-11-03 roadmap** |
| T3 | Privacy lifecycle, guardian roles, export/erasure, support & child unpair | Retention/custody decisions, RLS, external backup propagation, revocation, deletion and hold test | **Partial controls, external signoff blocked** |
| T4 | Transparent, consented location runtime + secure ingestion | T1–T3 legal/Play gates, visible permission/FGS, battery/OS matrix, Tx A durable 202 + Tx B lease/replay, offline/revoke guards | **Release-gated OFF** |
| T5 | Guardian latest location/history, accurate uncertainty and limited retention | T4, 108 active/admission cap and 109th waitlist, no guessed map/time, 6h visible history per free-tier contract | **Read components partly present; not accepted as a live release** |
| T6 | Trips/stops/places and multi-guardian authority | T4–T5 and separate product/privacy signoff; scoped access RLS, revision/correction tests | **Future feature work** |
| T7 | Usage stats, managed-device controls, premium, media | Individual legal/OS/Google Play/merchant authorizations, DPC eligibility where relevant, pricing/consent/security reviews | **CONDITIONAL / OFF** |
| T8 | Scale, recovery, operational and Play review | Synthetic load and fault tests, backup+restore quarantine, staffing, support, disclosure/metadata and actual Console review | **Not cleared for public release** |

Feature gates are dependencies, not blanket permissions. If legal/Play approval blocks T4, continue T2/T3 work with synthetic data; do not silently turn on location.

## Implementation work packages (small, independently reviewable)

Each task requires: source/requirement reference; actual branch/source SHA; tests with command+exit status; negative authorization cases; redacted screenshots where UI; PR into `dev`; linked implementation-to-Figma/API/DB trace; report PASS/FAIL/BLOCKED. No test may be marked PASS solely because code compiles or a Figma frame exists.

### P0 — Free V1 foundation and evidence repair

**NF-01 / `parent` + `child` + QA:** Resolve [Issue #61](https://github.com/methakon/Madalasa-Alarka/issues/61). Verify signed AAB values **as built**, including both HTTPS API origins, parent Web Google OAuth client ID, package ID, uploaded version code, release signing lineage, actual Play app SHA and `FREE_ONLY`. Parent BuildConfig/strings may default empty intentionally; if actual bundle has empty origin, choose a distinct authorized rebuild with higher unused version code, not an in-place edit to an accepted Play version. **Exit:** report exact two-AAB SHA256, source SHA, nonsecret build settings, app-installed versions, parent login and independent SOS test.

**NF-02 / `parent` + `child` branch governance:** Synchronize permanent workstream branches with latest `main` and `dev` per mandated preflight. Observe `parent` and `child` old synthetic Gradle configs against `dev` production ID settings. Prevent accidental regression of `applicationId`, `versionCode`, `app_name`, adaptive icon and `@drawable/ic_launcher_face` (generated/checked-in `drawable-nodpi` portraits). **Exit:** release identity/manifest test on both variants; no snapshot regression; no force rewrite.

**NF-03 / `dev` + QA:** Review [PR #60](https://github.com/methakon/Madalasa-Alarka/pull/60) current **187-file/396-commit** source difference by slice (snapshot only); re-run exact-head CI, Android release lint/unit/instrumented, database RLS, C++ CTest/integration, admin web, license/secret/security scan. The current PR description's 393/185 values must be refreshed. Promotion requires explicit owner action; all external gates remain separate. **Exit:** independently reviewable cumulative diff, known skipped tests and signed owner review; no automatic merge.

### P1 — Parent–child identity, admission and pairing

**NF-04 / `api` + `parent` + `child`:** Complete production two-stage Keystore P-256 challenge/proof enrollment with 10-character expiring one-time code. Ensure parent creates/authorizes the exact child, one active device, custody disputes fail closed, no automatic sibling authority; implement parent-side issuer UI and child-side verified status. Test replay, concurrent claims, expired invite, wrong family, revoked parent, lost phone, unpair and re-enrollment. Gate pair issuance on 108 admitted slots and valid consent; the 109th can register/waitlist but cannot activate services. **Evidence:** API integration + disposable Postgres RLS tests + signed Android two-device acceptance.

**NF-05 / `api` + `parent` + `child`:** QR-first flow specified in `docs/roadmap/QR_PAIRING_SINGLE_DEVICE_2026-11-03.md`. Parent-initiated scoped invitation, short-lived server-issued token QR and child scanner/claim/poll; manual 10-char fallback must remain available without camera hardware. Reject photographed replay, stale QR, wrong child, conflicting owner, background acceptance, and waitlisted child. Do not add Android camera permission to release until OS/Play/consent review. **Evidence:** Figma QR nodes `177:2`, E2E and accessibility, 320dp/200% fonts.

### P1 — Privacy, security and user support

**NF-06 / `api` + `parent` + `child` + `admin-web`:** Finish consent status, guardian grants/revocation, child unpair, account export/erasure/holds and privacy UI. Use actual migrations `0028_child_erasure_dependency_order.sql` and `0029_guardian_revocation_and_invite_validation.sql`, not inaccurate historical names. Implement category-specific retention only after owner/counsel numeric TTL decision; six-hour UI visibility is not a data retention order. Test external archive/backup propagation, device queue flush, RLS even with stale session, no resurrection after restore, and case admin least privilege. **Evidence:** disposable DB plus end-to-end revocation/erasure/restore.

**NF-07 / `admin-web` + `api`:** Verify public support/FAQ, secure ticket ownership, admin OIDC roles/MFA, child privacy wall, CSRF session logout, audit logs and real support/grievance contact reachability. Maintain x402 CSP/HSTS and Nginx-mail continuity. **Evidence:** synthetic account role matrix and live HTTPS sanitized logs; do not claim legal signoff from posted pages.

### P2 — Location observation (approval-gated)

**NF-08 / `child` + `api`:** On a separately authorized release variant only, implement foreground-visible and correctly permissioned location collection with honest Android 9–16 state matrix. Consent per purpose, explicit user initiated action, FGS/notification/disclosure, battery/doze and permission denial states. No stealth collection or mandatory background permission assumption. Use encrypted persistent local queue, no stale/revoked replay, idempotent event/batch identity, Tx A committed inbox 202 and Tx B leased bulk insertion with kill/restart/full-disk/recovery tests. Do not weaken `alarka_location_release_approved=false` in current Free V1 builds. **Evidence:** 2+ owner-operated devices plus broader emulator/OEM coverage, external security/privacy approval.

**NF-09 / `parent` + `api`:** Honest latest position and free last-six-hour history with event/received timestamps, precision/unknown/stale states, map provider availability, retrieval limit and partial pagination labels. Only admitted, authorized, consented child; no fallback to first child or guessed map trail. Tie visibility to actual enabled T4 capability and retention policy. Test 109th waitlist, lost network, wrong-family and sibling scope. **Evidence:** SQL/API plus parent Compose UI/accessibility.

### Conditional / future milestones, not auto-enabled

**NF-10 / `api` + `parent`:** Event-time trips/stops/places and corrected late data with known gaps, server revisioning and maps budget; separately approved historical location purposes.

**NF-11 / `parent` + `child` + `api`:** Scoped multi-guardian approvals and check-in, then separate usage stats/device-owner DPC research. Ordinary Android installation must never advertise device-owner powers or usage/screen capture without permissions and approval.

**NF-12 / `api` + `admin-web` + `parent`:** Paid/premium domain only after Play Billing/merchant/India tax/refund/legal acceptance; never enable checkout, orders, trial, promo grants or remote camera/microphone/screens by copying preview designs. Keep media deferred and opt-in/gated even after billing approval.

### M8/M9 cross-cutting QA and operations

**NF-13 / QA + `api`:** Capacity/safety tests: 108 admitted vs 109th waitlist under concurrency; 2-family IDOR/role, pairing replay, device credential revocation, SOS event idempotency/ACK, worker retry, resource budgets. Synthetic load may not run on the x402 mail VM if disruptive. Define realistic SLOs with the owner; no 108 concurrent device guarantee from DB synthetic benchmark alone.

**NF-14 / QA + operations:** Secure off-host backup, isolated restore, per-child tombstone replay, no erased-data resurrection, revocation after restore, incident escalation, cert renewal, monitoring and documented rollback, mail continuity. Perform restore only in isolated approved environment; no production child fixtures. Record measured RPO/RTO instead of inventing them.

**NF-15 / release governance + UI:** Cross-check 187 design-state records to actual navigable Compose/admin screens, live route inventory vs 171 *draft* OpenAPI operations, and physical DB vs conceptual Figma 120-table model. Record independently verified implementation for each **in-scope** screen; mark future gated screens DRAFT. Build Figma screenshot regression for high-risk onboarding, code/QR pairing, SOS, parent ACK, privacy, support and price preview. Compare English copy with screenshots, TalkBack, 200% font, 320dp, high contrast.

## Evidence / accept criteria matrix

| Test ID | Pass requires | Negative / failure proof |
|---|---|---|
| FULL-RC-01 | Play-installed Madalasa Google account → backend 201 with correct package/signing audience | wrong certificate, missing Web client, network outage cannot create access |
| FULL-RC-02 | Play-installed Alarka 10-char pairing (when admitted) → verified backend device credential | expired/reused code, 109th child, wrong family, revoke all deny |
| FULL-RC-03 | Child manual SOS 201 event UUID → guardian GET/ACK → child acknowledged → outbox clear | submission alone never clears, wrong family 403, offline preserves event UUID |
| FULL-RC-04 | Local outbox ciphertext and manual retry survive force-stop/restart | revoked token 401 stops submission; no dishonest delivered UI |
| FULL-RC-05 | 108/109 cap with concurrent admission and FIFO | no waitlist bypass, no paid priority |
| FULL-RC-06 | Deletion/withdrawal across devices, DB, cache/backup/restore | old outbox/session cannot resurrect erased records |
| FULL-RC-07 | Android permission/FGS + legal signoffs for any location-enabled candidate | denied/OS kill/no consent never collects or fabricates location |
| FULL-RC-08 | Cross-family RLS for all enabled child resource categories | guessed child IDs, stale actor role, sibling grant and admin role denied |
| FULL-RC-09 | Play Console listing/permissions/Data Safety and build certificate provenance | no synthetic debug key, prohibited module or undocumented feature |
| FULL-RC-10 | Incident/restore runbook with actual environment proof | rollback/restart preserves x402 mail and isolates failed recovery |
| FULL-RC-11 | UI high-risk Figma screens implemented and tested in current release | draft frame or OpenAPI operation is NOT treated as a shipped feature |

## Work allocation and stop rules

1. **Now:** Issue #61 (signed/Play-installed config), then NF-02 workstream sync, then owner review PR #60. These are prerequisites for truthful internal-testing acceptance.
2. **Next without external approvals:** NF-04/NF-05 protocol and UI with synthetic fixtures, NF-06 privacy/retention **without inventing TTL**, NF-07 support audit, NF-15 Figma trace/QA, NF-13 safe isolated synthetic tests. Tasks may advance in parallel if their graph dependencies pass.
3. **Blocked until decisions:** location collection and DPC (NF-08/09/11), retention/custody policy-dependent enforcement, paid/media (NF-12), live minors, production/public Play submission.
4. Every implementation must keep off-by-default gates, use no real-minor data, add dedicated negative tests, record exact branch and commit, and coordinate existing Issues [#32](https://github.com/methakon/Madalasa-Alarka/issues/32), [#33](https://github.com/methakon/Madalasa-Alarka/issues/33), [#42](https://github.com/methakon/Madalasa-Alarka/issues/42), [#52](https://github.com/methakon/Madalasa-Alarka/issues/52), [#54](https://github.com/methakon/Madalasa-Alarka/issues/54), [#61](https://github.com/methakon/Madalasa-Alarka/issues/61) and [PR #60](https://github.com/methakon/Madalasa-Alarka/pull/60) rather than duplicating feature branches.

## Decisions owner or independent reviewer must still supply

- Intended eligible target audience and product-specific Google Play policies for child-directed location/monitoring.
- Purpose-by-purpose lawful consent/guardian verification and custody conflict response; India counsel review; exact per-category retention/deletion and notices.
- Approved data/backup region, processors, budget, support/grievance contacts, on-call and RPO/RTO objectives.
- Map/notification provider, permissions, battery and error-status promises; clear expectations that SOS is not guaranteed emergency response.
- Production release identity/version and owner-reviewed PR #60 disposition. Internal testing owner approval does not automatically approve any next full-version capability.

**Outcome labels:** SOURCE_PRESENT / IMPLEMENTED_TESTED_SYNTHETIC / VERIFIED_PLAY_BUILD / BLOCKED_EXTERNAL / NOT_STARTED. A phase or issue closes only when its exact evidence exists. No blanket declaration of full-product completion is authorized by this plan.
