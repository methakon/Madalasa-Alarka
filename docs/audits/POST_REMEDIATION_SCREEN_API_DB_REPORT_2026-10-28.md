# Final Post-Remediation Figma Screen, API and Database Audit

**Date:** 2026-10-28 · **Status:** DESIGN AND DOCUMENTATION RECONCILED; **NO** C++/Kotlin/TypeScript handler, database migration, Android device tests, Google Play or legal approval claimed. This report supersedes earlier **API method counts** in the historical 146-operation snapshot, but does not delete its evidence.

## Verified coverage

| Measure | Result |
|---|---:|
| Figma screen or state records in all 9 catalogs | **187** |
| Figma nodes previously structurally checked | 187 |
| Separate direct Figma node recheck in this audit pass | 109 |
| Screens whose documented required route is absent from current draft | **0** |
| OpenAPI draft HTTP operations / paths | **171 / 155** |
| OpenAPI named request/response schemas | **130** |
| Figma logical tables/domains | **120 / 11** |
| Executable C++ handlers certified by this review | **0** |
| Newly considered route gaps documented in OpenAPI | **25 / 26** |
| Route intentionally rejected as unsafe/redudant | **1** |
| Coding-agent local backlog including additional GAP work | **316 task contracts**, none executed by this audit |

Full structured 187-row matrix: [POST_REMEDIATION_SCREEN_API_DB_COVERAGE_2026-10-28.json](POST_REMEDIATION_SCREEN_API_DB_COVERAGE_2026-10-28.json). Earlier [full frame-by-frame report](FINAL_FIGMA_SCREEN_BY_SCREEN_API_DB_REPORT_2026-10-28.md) contains original screen names, source URLs, intent and source table relationships. [Figma 187-row audit board](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=121-88) header updated to 171 operations. [Figma 11-domain ERD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=92-2) remains conceptual.

### Per-handoff screen status (one row per source catalog)

| Figma handoff source | Screen records | Linked to draft server contracts | Local-only | Explicitly gated | Independently rechecked this pass |
|---|---:|---:|---:|---:|---:|
| 01-parent-foundation | 18 | 16 | 2 | 0 | 0 |
| 02-parent-operations | 18 | 17 | 1 | 0 | 0 |
| 03-parent-governance-billing | 18 | 18 | 0 | 0 | 0 |
| 04-parent-conditional | 6 | 4 | 0 | 4 | 0 |
| 05-child-app | 21 | 10 | 7 | 4 | 0 |
| 06-capability-onboarding | 46 | 20 | 16 | 30 | 46 |
| 07-media-activity-audit | 28 | 28 | 0 | 28 | 28 |
| 09-theme-c-story-and-screens | 22 | 17 | 5 | 6 | 22 |
| 10-admin-back-office | 10 | 10 | 0 | 0 | 10 |

The counts by source are diagnostic; some screen variants use local Android APIs and existing API paths together. A direct Figma node check proves only that the design frame exists and is editable, not that an app screen is implemented or has passed screenshot/accessibility QA.

## API remediation performed in docs/openapi.yaml

1. **11 high-risk mutation bodies** changed from open-ended `payload:any` to named closed request schemas with server-derived caller identity, for viewer leases/heartbeat, takeover, parental verification, one-time trial, child data export, administrative media case/export, pairing, family creation and ticket status. Parent notification read body no longer claims arbitrary fields.
2. **25 additional screen-backed method/path proposals** added with explicit response shape, actor audience, required scope, negative statuses and conceptual DB references. This includes the administrator applicant profile/email status, owner role/staff review, ticket detail/messages, FAQ publish controls, subscriber entitlement summaries, parent usage totals, per-child viewer status/100-day add-ons, scoped notifications and check-ins.
3. Six conditional operations have **release gate OFF** for app-usage or managed-screen-time work until platform and child-data approvals. Draft paths are NOT functional permission grants.
4. A deliberately invalid `POST /admin/owner/access-requests/{requestId}/revoke` was **not** added. An access application is a historical approval/rejection decision, not the credential. Revoke approved **role grants and issued sessions** via existing owner grant-revocation flow, preserving the application and immutable audit.
5. Full-contract static validator [backend/tests/lint_openapi_full.py](https://github.com/methakon/Madalasa-Alarka/blob/main/backend/tests/lint_openapi_full.py) updated to reject open-ended mutation payloads and missing Figma route links. **Committing the validator is not evidence it has been run; execution and CI logs remain pending.**

### Screen-requested supplemental API outcomes

| Priority | Candidate route | Design outcome | Source screens |
|---|---|---|---|
| P0 | `GET /admin/owner/staff/{adminId}` | **Draft contract added** | BO-04,BO-09 |
| P0 | `POST /admin/owner/access-requests/{requestId}/revoke` | **Rejected — use role-grant revocation** | BO-04 |
| P0 | `GET /admin/owner/roles` | **Draft contract added** | BO-04 |
| P0 | `GET /admin/access/profile` | **Draft contract added** | BO-02 |
| P0 | `GET /admin/access/email-verification/status` | **Draft contract added** | BO-02,BO-02V |
| P0 | `GET /admin/owner/access-requests/summary` | **Draft contract added** | BO-09 |
| P1 | `POST /admin/faqs/{faqId}/unpublish` | **Draft contract added** | BO-05 |
| P1 | `POST /admin/faqs/{faqId}/restore` | **Draft contract added** | BO-05 |
| P1 | `GET /admin/support/tickets/{ticketId}` | **Draft contract added** | BO-06 |
| P1 | `GET /admin/support/tickets/{ticketId}/messages` | **Draft contract added** | BO-06 |
| P1 | `GET /admin/usage/parents/summary` | **Draft contract added** | BO-08 |
| P1 | `GET /admin/subscribers/{familyId}/entitlements` | **Draft contract added** | BO-07,BO-08 |
| P1 | `GET /admin/billing/reconciliation-status` | **Draft contract added** | BO-07 |
| P1 | `GET /children/{childId}/places/{placeId}/notifications` | **Draft contract added** | P-operations geofence |
| P1 | `PATCH /children/{childId}/screen-time-rules/{ruleId}` | **Draft contract added** | P-operations policy |
| P1 | `DELETE /children/{childId}/screen-time-rules/{ruleId}` | **Draft contract added** | P-operations policy |
| P1 | `GET /children/{childId}/viewer-takeover-requests/{requestId}` | **Draft contract added** | SH-03 |
| P1 | `POST /children/{childId}/viewer-takeover-requests/{requestId}/decision` | **Draft contract added** | SH-03 |
| P1 | `GET /children/{childId}/extra-viewer-addons` | **Draft contract added** | SH-04,SH-06 |
| P1 | `GET /parents/me/media-activity/export-requests/{id}` | **Draft contract added** | PA-media audit |
| P2 | `GET /children/{childId}/checkins` | **Draft contract added** | C-child check in |
| P2 | `GET /children/{childId}/usage/coverage` | **Draft contract added** | P-usage |
| P2 | `GET /families/{familyId}/members` | **Draft contract added** | P-family |
| P2 | `POST /children/{childId}/guardian-invitations/{inviteId}/cancel` | **Draft contract added** | P-family |
| P2 | `GET /children/{childId}/notification-rules` | **Draft contract added** | P-place notifications |
| P2 | `GET /admin/faqs/{faqId}/preview` | **Draft contract added** | BO-05 |

All newly specified operations have `x-implementation-status` design markers. No endpoint should return 200/201 before an authorized handler, database transaction, real session state and verified response exist. Unsupported media or parental relationships should return a typed denial.

## Database findings — what remains unimplemented

**120 named conceptual tables in 11 domains are NOT 120 migrated PostgreSQL tables.** Physical database still begins with `backend/persistence/migrations/0001_m1_identity.sql` and its `ap_m1` tables and forced-RLS test. The 8 additional screen-backed conceptual entities described in [physical schema review](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/data-model/FIGMA_SCREEN_GAP_PHYSICAL_SCHEMA_REVIEW_2026-10-28.md) are proposals only. Always map to actual `ap_m1` names before DDL; never duplicate adult or child identities.

**Critical blended-family blocker:** old `ap_m1.child_guardian_grants` requires matching `guardian_memberships` through FK `(family_id,principal_id)`, and `has_scope()` joins membership. This does enforce exact-child scope for current in-family grants but cannot represent a distinct co-parent from another family **without undesired home-family membership**. Draft a **versioned new migration** for independent, verified `(adult principal, exact child, scopes)` relationships, with forced RLS, hashed attestation reference, revocation epoch and cross-family negative tests. The service must remain FAIL-CLOSED until an independently supported child-specific Google parental verification source is approved. **Do not edit migration 0001 in place or force a co-parent into a billing family.**

Proposed precise physical acceptance tests:

| Area | Schema/constraint requirement | Mandatory negative test |
|---|---|---|
| Parental authority | `UNIQUE(child_id, principal_id, active grant)`; independent external authority, server-verified evidence, revoked_at epoch | Parent B of another family can see Child A only, not A's sibling or family roster |
| Admin applicants | `UNIQUE(google_issuer,google_sub)`, hashed email challenge, profile revision, FK owner decision/audit | Spoofed email/cross-account request cannot assign ROOT_OWNER or access subscribers |
| FAQ/support | Immutable FAQ revision pointer + version CAS; ticket-scoped messages and read audit | XSS/unauthorized ticket content/invalid revision rejected |
| Payments and seats | Play token hash UNIQUE, distinct founding families, child-seat capacity and +100-day add-on expiry | No twice-credited token, no cross-child purchased seat, base lapse does not delete addon |
| Viewer lease and A/V | Transactional child lease count, 1 included plus valid add-ons; pooled 1800 seconds per extra slot | Two parent races never exceed allowed count; refused OS capture costs 0 seconds |
| Parent service usage | Server-measured parent action `(parent, service, UTC start/end, outcome, duration)`, no child media/GPS payload | Admin API cannot infer raw child routes, app behavior or recorded content |
| GPS/retention | PostGIS partitioned observations; visibility policy independent of retention-policy approval; deleted-child replay tombstone | Free crafted cursor never reads >6h; offline stale GPS cannot resurrect erased child |
| Conditional Android controls | Per-device rule assignment and OS execution receipt with capability version | Standard phone never displays `OS_APPLIED` without device receipt |

## Blocking findings that intelligence alone cannot clear

- **P0 engineering:** no verified buildable full Android Gradle apps, running C++ Drogon API handlers or functioning administrator web flow; API design alone is not delivery.
- **P0 security:** physical SQL family-membership FK vs blended-family co-parent model, real RLS/negative test evidence and owner OIDC bootstrap.
- **P0 legal:** India child-data lawful purpose/consent, DPIA and history/backup retention (free 6-hour *visibility* ≠ legally approved indefinite storage).
- **P0 Google provider:** Family Link supports a second parent but no supported third-party exact-child role attestation integration has been confirmed; sharing remains blocked.
- **P0 Android/Play:** microphone/camera/screen/managed-device restrictions require observable OS grants, transparency, actual devices and Play review.
- **P0 commerce:** personal Play account eligibility, actual prepaid multi-child SKUs, first 1,008 paid-family offer, ₹100/100-day one-time SKU and billing settlement remain unverified.
- **P1 operations:** decide OCI India vs Chicago region and backup jurisdiction; reliable cost/TURN load test; email delivery, FAQ sanitization, support notification and PII-minimization.
- **P1 design:** legacy Amar-Pola screen branding and inconsistent Theme C on older handoffs need owner-approved visual normalization; editable presence does not guarantee final UI acceptance.

## Agent implementation sequence after this audit

1. Start from [AGENTS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/AGENTS.md); execute [262-task local DAG](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/roadmap/LOCAL_TASK_GRAPH_2026-10-28.json), then the [54-item API/DB remediation addendum](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/roadmap/FIGMA_SCREEN_API_DB_REMEDIATION_TASKS_2026-10-28.json) with graph dependencies and real evidence. **Combined backlog: 316 task contracts, NOT 316 completed tasks.**
2. Validate OpenAPI source and all 187 rows, then implement actual M1 auth/grants/SQL RLS and device proof. No source-of-truth duplication.
3. Build child GPS durable intake and private read path with synthetic data; add typed child-scoped parent routes and negative tests.
4. Implement admin applicant/owner, least-privileged FAQ/support/billing views and parent service metadata with denial tests.
5. Add prepaid family-child seat capacity, viewer lease and 100-day add-on state machine using a fake Play adapter, then real Play testing only through separate authorized release stream.
6. Keep conditional media, usage behavior and DPC paths disabled pending independent approval; do not permit coding agents to self-clear them.
7. Run actual clean-clone builds, SQL migration/RLS/restore tests, 187-screen implementation evidence, API handler audit, Android 29–36 physical/emulator tests, load/security/Play checks when authorized. Record unresolved items as BLOCKED, not PASS.

**Final outcome:** gaps have been documented and planned contracts filled where safe; **software implementation and external clearances remain open**. Do not deploy or collect real child data based on this audit.
