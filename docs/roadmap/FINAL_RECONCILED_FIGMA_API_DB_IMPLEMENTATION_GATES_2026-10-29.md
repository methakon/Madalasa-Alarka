# 2026-10-29 Final Figma-to-API-to-DB Reconciliation and Agent Blockers

**Evidence class:** live read-only Figma audit page metadata plus current repository document reconciliation. This is a **contract/design** audit, NOT 187 individual screenshot reviews, executed API tests, migrations, compilations or child-data approval. Do not call static designs "implemented."

## Primary scope and corrected baseline

- Live Figma file `TKiZXwjkWdkponF1zNsfli` accessible on 2026-10-29; page `121:88` named `API & DATABASE AUDIT • 187 Figma Screens • 2026-10-28` was retrieved. Its cover labels **187 screen/state entries**, **171 drafted OpenAPI operations**, **120 logical entities**; the cover itself warns no handlers or approvals.
- The authoritative post-remediation GitHub report is `docs/audits/POST_REMEDIATION_SCREEN_API_DB_REPORT_2026-10-28.md`, not the older `docs/roadmap/SCREEN_MISSING_API_AND_DB_GAPS_2026-10-28.md`. Historical numbers (134 paths/26 gaps or 146 operations/58 original paths) are pre-remediation snapshots and **must not** be used to create duplicate route tasks.
- Post-remediation recorded coverage: **187/187 registry entries have planned coverage**, **171 draft HTTP operations over 155 paths**, **130 named schemas**, **120 conceptual entities in 11 domains**. Of 26 follow-up route candidates, 25 were drafted; one `POST /admin/owner/access-requests/{requestId}/revoke` was correctly rejected. **0 known absent documented routes is NOT 0 implementation gaps.**
- Source: `docs/audits/POST_REMEDIATION_SCREEN_API_DB_COVERAGE_2026-10-28.json` (187 rows), `docs/audits/FINAL_FIGMA_SCREEN_BY_SCREEN_API_DB_REPORT_2026-10-28.md` (actual screen node links), `docs/ui/figma-functional-handoff/*.json` (user interaction and acceptance), `docs/openapi.yaml` (design contracts). Live individual screenshots, accessibility and native interaction quality **not revalidated** in this pass.

## Per-screen audit coverage grouped by the exact nine source catalogs

| Source | Records | Focus | Agent evidence needed |
|---|---:|---|---|
| 01 parent foundation P-01…P-18 | 18 | Google identity, authorized child listing, pairing, consent, reliability | login negative tests, child-scope filtering, pairing replay and permissions |
| 02 parent operations P-19…P-36 | 18 | alerts, map/history/trip, places, usage and managed controls | pagination, GPS quality, FREE six-hour *read* gate, OS-supported status |
| 03 parent governance/billing P-37…P-54 | 18 | guardian invitation, erasure, parent billing, support | cross-household V2, revoke, deletion tombstones, Play token/seat ledger |
| 04 parent conditional P-55…P-60 | 6 | Drive, camera, mic, watch and schedule | OFF by default; no implied covert media |
| 05 child app C-01…C-21 | 21 | disclosure, enrollment, capabilities, offline queue, SOS | visible consent/permissions, device-bound PoP, offline revocation |
| 06 capability onboarding | 46 | Android capability variations and failure states | return capability evidence/OS rejection, no fake success |
| 07 media activity audit | 28 | parent and admin media access traceability | sensitive data masking, authorization and release gate OFF |
| 09 Theme C story and screens | 22 | story, map, history, billing, disclosures | UI accessibility and real device screenshots, use existing contracts |
| 10 admin back office | 10 | owner bootstrap, approvals, FAQs, support, billing | staff RBAC, email, immutable review and masked operations |
| **Total** | **187** | **Registry path coverage recorded** | **No execution evidence certified** |

Source catalogs overlap logical actions but are separate visual/state entries. Audit every listed row during implementation using stable Figma IDs and JSON source references; no API is needed for purely narrative or local Android UI. For each row: frame ID, user action, exact HTTP method/path or local state, authorization scope, request schema, response/error states, owner table, migration, tests, compiled handler, UI screenshot, approval gate and result `PASS/FAIL/BLOCKED`.

## Concrete remaining coding blockers (P0)

1. **V2 blended-family access:** v0001 child_guardian_grants family membership FK must not be rewritten in place. Implement versioned `0002` migration with child-specific invites, adult legal authority review, consent and grants separate from billing family; audit all RLS and API routes. Cross-family adult sees only granted child; disputed/revoked grant tears down leases/signed URLs.
2. **No execution evidence:** Drogon C++ controllers, complete parent/child Gradle build graphs and admin runtime must compile, start and pass authorization/contract/device tests. Source-only mockups, SQL files and OpenAPI are not proof.
3. **Logical-to-physical DB gap:** 120 logical Figma entities are NOT 120 deployed tables. Establish physical schema ownership by milestone; prefer incremental migrations, constraints/RLS/indexes, retention classes, backfill/rollback and tenant-isolation tests; do not instantiate one SQL table for every design card.
4. **Consent/retention/deletion gate:** Implement versioned child-purpose consent, owner authorization review, per-category TTL, erasure tombstones, offline message rejection, restore suppression. Real child usage/media/history OFF pending Indian legal approval; do not conflate six-hour free visibility with physical data lifetime.
5. **Play billing real test:** per-child prepaid seat purchase ledger, founding family uniqueness/count concurrency, provider-verified receipt, pending/expired/refund/replay, one child shared across multiple authorized parents, 100-day extra viewer additive validity. Catalog, offer and independent child top-up support require owner-run Play Console sandbox verification; not credentials in Git.
6. **Admin owner authority:** cold-start owner provisioning, restricted staff approval, role revocation, MFA/reauth policy, ticket redaction, audit log and FAQ revision concurrency. A review decision is immutable; revoke role grant rather than historical access request.

## Schema implementation ownership by screen domain

| Domain | Suggested versioned relational model / essential invariants |
|---|---|
| Identity and child scopes | `parent_principals`, `families`, `guardian_memberships` for billing; `child_access_invites`, `child_authority_reviews`, `child_access_grants_v2` for child scopes; accepted invite, no sibling enumeration; scoped indexes and revocation epochs |
| Pairing and Android | `devices`, `enrollment_challenges`, `device_key_records`, `capability_snapshots`, `permission_snapshots`, `device_command_receipts`; device possession proofs, nonce uniqueness, epoch invalidation |
| GPS/maps/trips/places | `location_observations`, `gps_ingest_inbox`, `trips`, `trip_revisions`, `named_places`, `place_notification_rules`; child indexes/time partition/TTL; read-time entitlements independent of retention |
| Alert/SOS/usage | `alerts`, `alert_receipts`, `checkins`, `usage_permission_checks`, `usage_period_summaries`; don't report unknown as zero; delivery isn't acknowledgement |
| Consent/erasure | `consent_records`, `retention_policy_versions`, `erasure_requests`, `erasure_jobs`, `child_erasure_tombstones`, `backup_erasure_manifests`; delete/revoke first, stop late offline uploads |
| Prepaid commercial | `play_purchase_events`, `purchase_token_registry`, `child_paid_entitlements`, `child_seat_assignments`, `founding_family_awards`, `extra_viewer_purchases`; unique token, exactly-once allocation, immutable purchase history |
| Viewer/media conditional | `premium_viewer_leases`, `viewer_takeover_requests`, `media_quota_ledger`, `media_access_audit`; atomic lease CAS, max concurrent seats, audit without content, feature OFF until approval |
| Admin and support | `admin_profiles`, `admin_access_requests`, `admin_role_grants`, `admin_action_audit`, `faq_entries`, `faq_revisions`, `support_tickets`, `support_messages`, `parent_service_usage_events`; least privilege and PII masking |

Names above are logical implementation candidates: compare against versioned existing SQL before writing a migration; avoid duplicate existing tables. Every child-associated table needs well-defined RLS/function access and denial tests; admin read models must never leak raw child routes or other children.

## Contract-specific follow-ups, not duplicate path work

- For every drafted operation, establish executable Drogon route mapping, typed C++ request/response validators, generated Kotlin/TypeScript clients and tests against `docs/openapi.yaml`; requests must derive principal ID server-side, not from client body.
- For list endpoints use opaque cursors, bounded page sizes, stable UTC ordering and per-child authorization. For actions use idempotency keys, optimistic version fields, rate limiting, explicit 401/403/404/409/422/429 and redacted audit.
- Parent P-39 and related guardian views must distinguish **billing family member** vs **child-specific authorized adult**; old UI that conflates these is a required visual/UX correction.
- Admin BO-04 review revoke UX: approved access requests are historical; route to **active role grant revoke** (not rejected POST on request). Show immutable decision history.
- Conditional C/P usage, managed device control, media: capability/approval status and typed `UNSUPPORTED_OS`, `PERMISSION_DENIED`, `POLICY_NOT_APPROVED` rather than success.
- Prepaid screens: Play-confirmed real tax-inclusive checkout amount, manual renewal and child seat allocation; no automatic coupon promise without verified offer behavior.
- Correct stale older docs and design labels that still claim Google parent-role API is required. OAuth identity is not statutory parental authority.

## Precise execution gate to close each screen

For each matrix row write a CI-attached evidence record: `screen_id`, `figma_node_id`, `method_path`, `db_migration`, `handler_source`, `ui_source`, `scope`, `positive_case`, `negative_case`, `device_or_browser_case`, `result`, `commit_sha`, `log_or_artifact_digest`, `reviewer`. `DESIGNED` or `DOCUMENTED` may never be promoted directly to `PASS`.

## Deferred decisions

Hosting-region selection (Chicago/Mumbai/other), OCI deployment topology and real bandwidth/TURN operating economics are **deployment-only** decisions, not local coding blockers. Build portable interfaces and metrics now. Play Console merchant/catalog and India real-child data signoff are release gates. No secret keys or purchase tokens may be committed.

## Official design references

- [Live Figma audit board](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=121-88)
- [Full 187-row coverage](../audits/POST_REMEDIATION_SCREEN_API_DB_COVERAGE_2026-10-28.json)
- [Post-remediation result](../audits/POST_REMEDIATION_SCREEN_API_DB_REPORT_2026-10-28.md)
- [Current OpenAPI contract](../openapi.yaml)
- [Blended-family V2 ADR](../phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md)
