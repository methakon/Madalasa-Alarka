# Six-gate decision and evidence handoff — 2026-10-29

**Status:** consolidated owner direction and implementation acceptance criteria; NOT executed code, verified Figma live audit, Play sandbox test, deployment approval, or legal sign-off. This document supplements the existing source ADRs and preserves their canonical status.

## 1. Blended family: M1 authorization V2 (coding blocker)

**Canonical:** [V2 ADR](../phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md). Existing `0001_m1_identity.sql` includes `child_guardian_grants(family_id, principal_id) -> guardian_memberships(family_id, principal_id)`. It binds child visibility to a payer-family membership, unsafe for cross-household co-parents. Preserve v0001 historical migration; implement v0002 with child-specific adult grants independent of payer membership, one-time invite, legal authority review, consent record, scope, expiration and revocation epoch. The billing family/owner remains separate; a second adult's grant never creates a paid seat or billing right.

**Agent acceptance:** migrate 0001 -> 0002 in disposable Postgres; backfill conservatively, verify, cut over and contract in stages; inspect every cross-family RLS join and helper function, indexes, session GUC trust and downstream API. Negative cases: co-parent Child A cannot enumerate sibling Child B, family revenue, devices or events; invite replay, disputed custody, consent withdrawal, cached/signed URL reuse, revocation races, cross-tenant SQL all fail closed. Use no real child data until legal gate.

## 2. Google Family Link relationship lookup: DROP (approved design decision)

**Drop only** Google-specific *technical* verification of parent/child relationship as dependency for invitations and app access. Google Family Link's interface for adding a second parent documents a family-manager UI, not a publicly documented developer-signed relationship claim: https://support.google.com/families/answer/7295768 . Standard Google ID token verification describes `iss`, `aud`, `exp`, `sub`, email, and `hd`, not a claim attesting parenthood of another Google subject: https://developers.google.com/identity/gsi/web/guides/verify-google-id-token . We found **no documented public consumer API** for a signed (adult subject, child subject, lawful parent) statement. This is evidence of no supported integration identified, **not proof of universal API nonexistence**.

**Keep:** adult account authentication, non-Google legally approved parent/guardian authority verification, child-specific consent, transparent disclosure, OS permission/Play gates. Google sign-in **is not** legal relationship evidence. Under unresolved India legal policy, use synthetic LOCAL_TEST_APPROVED fixtures only and deny real processing.

## 3. Implementation proof (coding and CI blocker, not merely docs)

**Canonical:** [evidence checklist](IMPLEMENTATION_PROOF_AND_PLAY_SANDBOX_HANDOFF_2026-10-28.md). For each completion attach commit SHA, dependency/toolchain versions, build/test commands and actual exit code, redacted CI log and artifact digest, reviewer and reproducible synthetic test data. Required:
- Drogon C++20: source controllers/routes and middleware, buildable CMake target, CTest output, running local server, HTTP OpenAPI positive/negative contract checks, Google token audience/issuer, scope, rate limit, idempotency, RLS denial tests.
- Android Madalasa and Alarka: checked-in Gradle wrapper, manifests and full build graph, assembleDebug/testDebugUnitTest instrumentation result, AAB/APK checksum, emulator/device OS matrix; permission deny/revoke, reboot, offline/reconnect, background limitations and child transparency.
- Admin: actual UI/module and runtime API integrations, production build/test with lockfile, operator RBAC, denied unapproved login, masked child/billing information, support-ticket tenant isolation and XSS security tests.
- Postgres: versioned migrations run, RLS query/tests as restricted app role (not superuser), upgrade/rollback strategy, erase and restore tombstone tests.
- Figma: screenshot/state comparison of all impacted live screens and interaction conditions; static frames or exported JSON are evidence of design, not working UI.
**Evidence not yet validated by this documentation update**; no runtime tests were performed.

## 4. India child data consent, retention and deletion (owner/legal release blocker)

**Canonical:** [India action brief](../phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_CHILD_CONSENT_RETENTION_DELETION_ACTION_BRIEF_2026-10-28.md). DPDP Act 2023 section 9 and the DPDP Rules 2025 must be assessed against their staggered commencement (key child provisions scheduled for 13 May 2027 under the cited commencement notification) and the feature's data fiduciary/purpose/exception, not assumed exempt just because parents request tracking. Independent India privacy counsel must approve lawful authority validation, under-18 consent, precise GPS, route history, app-usage/behaviour, media/screen, parent controls and rights flows. Android/Google Play policies apply separately now.

**Implement locally now:** versioned purpose-specific consent ledger and notice; guardian revoke/dispute freeze; minimum necessary category-specific TTL and backup/WAL deletion plan; deletion request->deny ingest->revoke sessions->erase source/derived/queues/caches->backup suppression and testable erasure evidence. FREE six-hour visible history is **not** authority to physically retain everything until account closure. Do not invent a universal retention period; owner/counsel must approve a schedule for raw location, trips, usage, media, billing, support, audit, backups and exception holds. Keep all real child-data flags OFF pending written signoff. Avoid Aadhaar uploads and raw sensitive identity evidence unless a defensible legally approved process exists.

## 5. Google Play prepaid and multi-child billing (sandbox release blocker)

**Canonical:** [safe setup](PLAY_BILLING_SANDBOX_ACCESS_CHECKLIST_NO_SECRETS_2026-10-29.md). Owner-approved design targets: ₹99/month or ₹999/year per paid child, first 1,008 distinct successfully paying family accounts qualify for ₹50/month or ₹500/year across eligible children including children added later, prepaid manual top-up only, no auto-renew, separate ₹100 repeatable extra-viewer entitlement for 100 calendar days (backend governed). Actual Play catalog/offer and extra-seat capacity support **unverified**. Never assume a single purchase token covers multiple children; record a child seat allocation ledger, unique transaction ledger, package/product/basePlan/offer and purchased capacity, server verification and refunds. Test repeated child purchases, founding qualification concurrency, cross-family shared same child no double-purchase, reassign/restore/expiry/replay/refund and pending payments, tax/price display. An extra viewer's 30 *combined* A/V minutes are feature gated by Android/legal/Play feasibility.

**Owner to retrieve (safe to share only nonsecrets):** from Play Console apps/packages, Monetize > Products > Subscriptions & One-time products (draft/active SKUs, prepaid base plans/offers), Settings > License testing (configured yes/no), Testing > Internal testing (track state); from Cloud Console project ID, Google Play Developer API enabled yes/no, IAM & Admin > Service Accounts email; from Play Console Users and permissions, app-scoped service-account access yes/no. Do **not** share passwords, OTP, developer account ID, service-account JSON/private key, real purchase tokens, card or child data. Run license tester / Play Billing Lab test card flow using owner-held protected access. https://developer.android.com/google/play/billing/test ; https://developers.google.com/android-publisher/getting_started

## 6. Hosting region and bandwidth — DEFER to deployment, NOT coding blocker

**Canonical:** [separate deployment plan](DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md). Do not force Chicago vs Mumbai, cloud provider, WAN/egress forecasts or TURN cost figures into local backend/Android acceptance. Build portable environment config, object-store/queue/provider adapters, telemetry counters and representative load scenarios now. Region, processors/DPA, backup jurisdiction, actual throughput/concurrency, bandwidth, costs and SLA are **D-03 deployment approval** before staging with real data/production, not a prerequisite for synthetic coding. Historic Chicago price estimates are not a deployment approval.

## Figma handoff and review status

[Live editable Figma file](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=6-2) and [screen API/DB audit](../audits/FINAL_FIGMA_SCREEN_BY_SCREEN_API_DB_REPORT_2026-10-28.md). Focus UI revalidation: guardian access P-39 and related invitation/revoke/dispute flows, consent/deletion, prepaid P-48 and capacity/addon/expiry, admin owner approval and child disclosure. The repository has recorded prior Figma readbacks and audits, but this handoff has **not** freshly inspected native live frames.

## Gate summary

| Gate | Coding agent may proceed with synthetic data? | Real child production allowed now? |
|---|---|---|
| Blended family v2 | Yes, migration, RLS, tests | No, until tests + legal |
| Google Family Link integration | Removed, no coding dependency | Not an authority bypass |
| Drogon / Android / admin executable evidence | Yes | No, until proven |
| India consent, retention, deletion | Yes, fail-closed scaffolding | No, counsel/controller sign-off |
| Play prepaid multi-child payments | Yes, fake provider and contracts | No, sandbox/Console verification |
| Hosting and egress economics | Yes, portable coding | Deployment decision later |

**Audit principle:** a documented decision is not an implemented feature; a test plan is not a passed test; a Figma frame is not an executable screen.
