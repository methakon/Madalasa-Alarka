# Madalasa–Alarka — Free-first release with 108 admitted children
**Owner direction:** 2026-11-03 · **Status:** IMPLEMENTATION IN REVIEW; NOT published to Google Play; real-child release remains NO-GO pending independent legal/Play/operational gates.

## Decision
Launch a **free-only public build first**. Keep all previously built billing, 48-hour trial, founding-member pricing, viewer leases, add-ons and premium/media research in the repository and design system; **do not delete them**. Disable premium navigation/checkout/entitlement actions in both Android applications and the production API. BillDesk/provider verification can proceed once a lawful, approved live free app/site exists, but never treat public listing alone as merchant approval. A paid release is a later separately reviewed binary/API deployment after Google Play Billing and provider approvals.

The free entitlement remains **live last-known location** (moving collection target 10–15 minutes, not an Android timing promise), **most recent six hours of visible history**, and essential authenticated guardian/privacy controls. Six hours is NOT a data-retention schedule. No trial, paid history, live media, remote microphone/camera/screen or payment transaction is available in this release. SOS and app-usage monitoring are separately compliance-gated, not silently activated by this free entitlement.

## Capacity decision — exact 108 distinct children, not parents
The capacity is **108 admitted child profiles globally**, not 108 guardian accounts, not 108 devices and not 108 families. One family with three admitted children occupies three slots. Verified adults may complete identity and family signup when full; their additional child profiles are persisted as `WAITLISTED`, and **no location collection, history reading, pairing or device-service activation** is permitted for a queued child. A queued family remains able to see their signup result, queue status, support, notices, privacy and erasure requests. Never demand a purchase, credit card, payment details or second signup to enter the queue.

- `ADMITTED`: allocated one child slot, **not** proof of legal parent authority, consent, paired device or active monitoring.
- `WAITLISTED`: signup completed and child exists, but **zero child monitoring services**. An owner may refresh status; a displayed queue rank is an estimate and can change.
- `RELEASED`: slot freed after verified child-erasure tombstone; this child is never reactivated. An atomically selected waiting child is promoted to `ADMITTED`, ordered by queue timestamp and UUID.
- Never promise immediate activation or a date; the admitted family must still complete authority/consent/device setup. No push/email notification is claimed without an approved and implemented provider route.
- The 108 limit is a deployment safety cap, **not proof** that an unbenchmarked free OCI VM can safely support 108 simultaneously moving children.

### Customer-facing exact text
**On confirmed waitlisting:** “Your child’s registration is complete. You are in the service queue. All 108 free-service slots are currently allocated. We’ll allocate a slot when one becomes available. Tracking and other child services have not started. You can check your status here.”

**On admitted slot:** “A free-service slot has been allocated for this child. To start location sharing, complete the required guardian verification, consent and Android permissions. No tracking has started yet.”

**On unverified response or network failure:** “We couldn’t verify your child’s service status. Please refresh. Monitoring remains unavailable.” **Never** optimistically activate while offline.

## Server-side enforcement
Current work branch: `api` / PR #28 (contains unrelated unfinished Phase 10 experiments; review carefully).

- `backend/persistence/migrations/0023_free_first_108_child_admission.sql` is additive; its Postgres transactional advisory lock serializes child creation. Backfills existing eligible child profiles in creation order, allocates 108 total, then queues new child IDs. Child-erasure tombstone insert releases a slot and promotes the earliest eligible queued profile; queued rows survive app restarts.
- Existing **identity/authority/consent** checks are retained. Additional admission policy is an **AND** restriction, never an alternative to existing RLS.
- `POST /v1/families/{familyId}/children` preserves idempotent signup and returns `free_service_state`, `queue_position`, `slot_limit`, and a plain-language `message`.
- `GET /v1/families/{familyId}/children` and `GET /v1/children/{childId}` expose only authorized family/child admission information; no global waiting-list identities.
- `GET /v1/children/{childId}/location/latest` and `.../location/history` use verified parent sessions, exact-child authorization, SQL RLS, and an **explicit six-hour maximum**. Missing location is UNAVAILABLE, never 0,0.
- `MA_RELEASE_PROFILE=FREE_ONLY` is the startup default; premium catalog/trial HTTP routes are not registered. `PAID_VERIFIED` is an exceptional deliberate deployment latch requiring explicit independent owner, BillDesk and Play approvals; these environment variables do **not** prove those approvals actually happened. Premium media remains OFF.

## Android and Figma
Current work branch: `parent` / draft PR #30.

- Parent Google session proceeds to family signup → child nickname → server registration. Show the returned waitlist/admitted state **after successful signup**, not as a signup failure.
- A waitlisted child remains visible with its queue position and cannot be selected, paired or navigated into monitoring. Any missing/unverified state fails closed.
- No unverified dashboard dots, synthetic 0,0 coordinates, or fake location on real sessions. A configured HTTPS backend is mandatory; debug synthetic fixtures are labeled and isolated.
- Child `Alarka` production release must include real approved device enrollment and appropriate disclosure/Android permissions. Current synthetic child enrollment is not itself publishable.
- Editable design storyboard: [Figma — Free-first / 108 child slots](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=175-2). Existing premium screens remain intact but must be designated **disabled/not released**.

## New prioritized delivery checkpoints (do not falsify L00–L19 PASS counts)
| Stage | Required engineering evidence | Current status |
| --- | --- | --- |
| FF-01 | Paid/trial features fail closed in server, Android and Play product UI | Partial backend implementation, Android/pay UI audit outstanding |
| FF-02 | Account/child registration, 108/109 queue, refresh and exact child scopes | Implementation on branches, CI/negative concurrency tests required |
| FF-03 | Queue blocks enrollment, ingest, read, SOS/usage and all child service attempts | Partial DB policy; verify each V2 table and handler |
| FF-04 | Child Android approved pairing, foreground service/permission UX, actual GPS collection and offline queue | BLOCKED: live device/Android/legal work |
| FF-05 | Guardian dashboard latest location, six-hour history and privacy controls | Backend/Android read layer in review; independent HTTP/E2E required |
| FF-06 | Revoke/delete/free slot; restore and queue promotion safety | SQL trigger implemented; cross-store deletion tests required |
| FF-07 | 108 live-equivalent synthetic device benchmark, memory/CPU, battery, SQL, backups, failure drill | NOT RUN |
| FF-08 | Regional hosting, consent and retention signoff, legal pages, grievance/support and Play monitoring policy | EXTERNAL GATES OPEN |
| FF-09 | Signed parent + child AABs, Play listing, Data Safety, internal/closed tests, permissions review | NOT SUBMITTED; owner/Console action required |
| FF-10 | Play production access and actual free-only staged rollout | NO-GO pending FF-01 through FF-09 |
| PF-01 | BillDesk public listing/merchant KYC and provider approval | Application submitted; approval not confirmed |
| PF-02 | Google Play Billing sandbox, verified prepaid purchase/RTDN/refund/seat tests and country pricing | NOT VERIFIED |
| PF-03 | Separately signed paid build and reversible feature activation; verified media exclusions | FUTURE; requires approval + regression |

**Required release sequence:** design/code → disposable PostgreSQL + Android tests → legally reviewed live child-data flow → real device/closed testing → Play approval and free public release → BillDesk live-link/provider review → paid sandbox evidence and provider activation → paid update. Do **not** publish a nonfunctional monitoring claim merely to unlock the payment onboarding step.

## Merge and test policy
Work stays on `api` and `parent` branches and enters `dev` only through reviewed PRs with passing CI; then merge `dev` into `main`. Never erase subscription/entitlement tables or mark Phase 10/11 passed. A Play listing, app approval, BillDesk verification or public child-data operation must be evidenced in the owner-controlled Console/provider records; none is inferred here.

Regression list: 108th vs 109th child; concurrent createChild with distinct keys; idempotency replay doesn't consume two slots; cross-family/guardian access; queued pairing attempts; queued device ingest and offline replay; no paid trial/checkout route in FREE_ONLY; absence of paid UI entrypoints; 6h+1s history denial; tombstone release promotes first eligible waiter; deleted child never reappears from backup; no legal/Android consent bypass; Play listing disclosures correspond exactly to deployed binary.

Related source documents: [Commercial rules](../phases/M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md), [Play release gates](../phases/M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md), [Separate deployment plan](DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md), [task graph](LOCAL_TASK_GRAPH_2026-10-28.json), [privacy obligations](../phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md).
