# 2026-10-28 Figma Screen → API → Database Physical Schema Gap Review

**Status: PROPOSED PHYSICAL DESIGN ONLY; no migration executed.** Source: [187-screen audit](../audits/FIGMA_SCREEN_API_DB_AUDIT_2026-10-28.json), [OpenAPI 3.1 draft](../openapi.yaml), [Figma ERD11](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=121-2). **Current conceptual model: 120 candidate tables in 11 domains**, including 8 new screen-backed candidates added to the previous 112. **Executable database remains the older ap_m1 schema in migration 0001**, not all 120.

## Physical schema first principles

Never automatically generate 120 CREATE TABLE statements from Figma. Review existing `ap_m1` names, tenant keys, indexed lookups, transactional outbox, minimum legally approved retention, and actual capability/feature release. M1 tables are `ap_m1.parent_principals`, `ap_m1.devices`, `ap_m1.child_guardian_grants`, `ap_m1.guardian_memberships`, `ap_m1.children` — **not** the same names as conceptual `adult_accounts`/`child_devices`. New migrations must use actual canonical names with explicit compatibility views/rename strategy; don't create duplicate identity sources.

## Critical pre-existing schema / blended-family blocker (P0)

`backend/persistence/migrations/0001_m1_identity.sql` declares `ap_m1.child_guardian_grants` with `FOREIGN KEY(family_id,principal_id) REFERENCES ap_m1.guardian_memberships(family_id,principal_id)`. Its `has_scope()` joins family membership and child grant. This enforces a useful **exact-child authorization** rule, and the child RLS policy also checks `has_scope`; it does **not** automatically expose all siblings. But the design implicitly requires an external parent to become a **member of the child's billing/home family**, even when that adult belongs to a different family. Do not join or turn them into OWNER automatically, and do not assume a one-family-per-parent model. The later blended-family requirements demand a distinct child-specific parent authority relationship **independent of payer/home-family membership**.

**Migration design:** preserve M1 tests; introduce a dedicated `verified_child_parent_authorities(child_id, principal_id, evidence_method, evidence_ref_hash, state, verified_at, expiry, revoked_at)` and child-specific `external_child_guardian_grants` (or a carefully reviewed FK migration), with (a) successful external identity verification; (b) supported **child-specific** relationship evidence from an approved source (no verified Family Link third-party parent API at present, so feature OFF); (c) issuer-and-subject bound adult account; (d) exact child authorization scopes; (e) audit/revocation generation. Neither table confers family_OWNER, billing-seat transfer, sibling roster visibility, cross-family joins or super-admin child access. Rewrite `has_scope` and RLS under a new versioned migration with test fixtures below; do NOT alter past applied migration 0001 in place.

**Required SQL negative scenarios:** Family A with Child A1/A2; Family B with Child B1; Parent B has separate account in Family B, is verified for A1 only; Parent B sees A1 only under explicit child grant, never A2/home-family metadata/B1 unless separately authorized; removing A1 immediately stops all cached/signed URLs, viewer leases and late device sync. Reject guessed email, matching surname, self-declared co-parent or unverified invite. Verification remains external BLOCKED until supported method approved.

## Eight screen-backed proposed persistence additions

| Proposed table | Source screens / new API | Actual FK target / key constraints | RLS and retention tests |
|---|---|---|---|
| `parent_auth_sessions` | P-02..04, POST auth exchange, POST logout, GET sessions | `adult_id → ap_m1.parent_principals.id`; unique token **hash**; issued/expire/revoke/revocation_epoch | Only own sessions; logout/revoke kills token; only hash stored, short TTL |
| `device_permission_change_events` | C-06..10, CAP-A-21..24, CAP-P-16..21, GET permission-events | `device_id → ap_m1.devices.id`, child_id composite FK, observed/received timestamps, device key proof and revision monotonicity | Authorized adult only, unknown/denied is not false granted; privacy-defined TTL |
| `parent_notification_read_receipts` | P-17..20, P-50, parent notification list/read | `delivery_id → notification_deliveries.id`, parent_id FK; UNIQUE(delivery_id,parent_id), read_at UTC | Parent A cannot mark parent B's notification read; no child GPS in push |
| `commute_plans` | P-29/P-30, GET/POST commute-plans | plan_id UUID, child_id/FK, authorized creator, place ids, strict schedule/approval state, revision | STOP inferring exact route or arrival from a plan; no read without child grant |
| `commute_plan_revisions` | P-29/P-30 and trip revision states | composite(plan_id,revision), optimistic version, immutable changed_at | No lost edit by competing parent; latest version explicit |
| `tracking_policy_revisions` | P-51/P-60, C-12, adaptive GPS upload | child/device composite FK, effective_at, requested cadence, server version, device ack | Paid → free downgrade reduces cadence only after policy/device sync; acknowledge unknown |
| `service_incidents` | P-52, GET service/status | id, component, bounded public sanitized message, timestamps and public visibility | Public status contains **no** child data, internal IP, secrets or coordinates |
| `media_request_device_approvals` | P-57/58, C-20, CAP-A-11..18 | command_id FK to `media_command_requests`, device_id, OS/child-visible user decision, proof hash and timestamp | CONDITIONAL ONLY; denial/failure consumes no quota, cannot use prior permission to skip per-session required consent |

**Reuse rather than duplicate:** `trial_redemptions`, `trial_eligibility_checks`, `play_purchase_records`, `child_paid_entitlements`, `extra_viewer_purchases`, `premium_viewer_leases`, `media_quota_ledger`, `support_tickets`, `support_messages`, `admin_email_challenges`, `admin_access_requests`, `faq_entries/revisions`, `parent_service_usage_events`, `account_deletion_requests`, `erasure_jobs` already exist **conceptually**. No separate payment-card table, raw child media table, or all-children admin browser should ever be created.

## Migration implementation order (not executed)

1. `M1-TO-M2-001`: map `ap_m1` physical names vs conceptual, introduce approved principal-child external authorization and old-function compatibility; stop if parent proof unresolved.
2. `M1-TO-M2-002`: add `parent_auth_sessions` with token hash, expiry and forced RLS. No raw Google tokens in table.
3. `M1-TO-M2-003`: permission changes table with device key and child FK and device event idempotency.
4. `M3-001`: commute plans + immutable revisions, child-scoped RLS and bounded indexes.
5. `M3-002`: notification reads; guard delivery relationship and each adult.
6. `M4-001`: tracking policy revisions and device acknowledgement, free paid cadence exact state.
7. `M8-001`: sanitized public service incident status.
8. `P3-MEDIA-001`: conditional per-request device OS approval only if Play/Android/India legal and child privacy review pass. Default absent; no production migration while blocked.
9. Each migration has `BEGIN`/`COMMIT`, FK/PK/check/unique/index, `ENABLE ROW LEVEL SECURITY` and `FORCE ROW LEVEL SECURITY`, no `BYPASSRLS` app role, correct policy for read/write/child scope, signed-off retention. Tests must use real non-superuser role with `SET ROLE`, not migration superuser.
10. Validate append-only event versioning and concurrency with physical locks; run upgrade, failed-intermediate rollback, duplicate/late/revoked, egress/privacy audit and EXPLAIN on synthetic bulk data.

## Additional cross-domain physical blockers

- Current logical tables include multiple conceptual names that conflict or overlap with `ap_m1` production names. Define a naming map before any generated DTO/repository layer.
- **Foreign key correctness:** purchase/seat assignment must use child-scoped uniqueness and actual verified Google Play token hash; founding rank 1–1008 is **distinct paying family**, not counted per child. Extra-slot purchase one-time: independent 100 calendar days and 1800 seconds combined A/V; base paid expiry pauses use, never mutates purchased expiry.
- **View/retention separation:** last six hours visible to free users is an API authorization filter, *not* a signed legal retention rule. Current proposed account-lifetime history is externally blocked. Date partitions and backup/WAL TTL need counsel-approved policy.
- **Admin metadata:** child list should be projected through a minimal, purpose-restricted SQL view with masked child ID, alias only when approved, and seat state. Do not grant `ROOT_OWNER` raw `children`, `location_observations`, `media_sessions`, `usage_events` or filesystem private exports.
- **Media lifecycle:** don't interpret a prior child-app microphone/camera grant as permission for remote background capture; user-visible Android OS approval and Play monitoring declaration remain independent.
- **Missing code vs documentation:** a SQL design and C++ interface are NOT a working migration/handler; status remains PLANNED until disposable PostgreSQL replay and actual unit/negative tests pass.

## Linked audit and UI

[All 187 screens structured audit](../audits/FIGMA_SCREEN_API_DB_AUDIT_2026-10-28.json) · [Figma 187-row audit sheet](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=121-88) · [ERD11 eight candidate tables](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=121-2) · [Canonical 120 candidate logical table registry](MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json) · [Drogon API draft](../openapi.yaml).


### Post-audit, 2026-10-28 — 25 additional typed endpoint contracts

The latest `docs/openapi.yaml` now specifies 171 draft operations and 130 named schemas. New GETs for own applicant profile, owner roles/staff and access-summary, parent service totals, ticket conversations, masked family entitlements, addon 100-day state, child checkins and place recipient toggles **reuse** the conceptual admin/billing/safety schema above; none justify a duplicate adult/child/payment token table. Draft POST FAQ unpublish/restore and viewer voluntary takeover decision require optimistic revision/lease CAS and audit events. Draft conditional screen-time/child app-usage/media export endpoints stay **disabled** until explicit Android/Play/DPDP approval; database migrations must not silently enable them.

**Physical index/constraint checklist per approved migration:** `admin_accounts(google_issuer,google_sub)` UNIQUE; `admin_email_challenges(challenge_hash)` UNIQUE + expires_at index; `admin_access_requests(admin_id,status,submitted_at)` indexed and approval CAS; `support_messages(ticket_id,created_at,id)` cursor index; `faq_revisions(faq_id,revision_no)` UNIQUE; `parent_service_usage_events(parent_adult_id,started_at,service_code)` indexed with explicit retention; `extra_viewer_purchases(child_id,expires_at,state)` plus unique verified purchase token reference; `viewer_takeover_requests(child_id,active_lease_id,state,expires_at)` indexed; `place_notification_rules(place_id,adult_id)` UNIQUE; `child_checkins(child_id,checked_in_at)` bounded and indexed. Tenant+child ownership constraints and FORCE RLS mandatory on sensitive rows. A cross-family approved adult may receive *exact-child* access only through a new versioned verification/grant model, not by auto-insertion into the payer's family memberships.

**Migration test gate:** non-superuser RLS, duplicate/replay, cross-child and sibling invisibility, owner bootstrap, fake Play refund, user-visible media denial, 100-day base lapse resumption, free last-six-hour cursor filter, deleted-child offline sync replay, and account/backup erasure. These are proposed tests and not executed here. [Post-remediation screen audit](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/audits/POST_REMEDIATION_SCREEN_API_DB_REPORT_2026-10-28.md).

## 2026-10-29 schema audit update (supersedes unresolved reference names)

Read [the deep physical schema review](PHYSICAL_SCHEMA_DEEP_AUDIT_AND_REMEDIATION_2026-10-29.md) before generating further migrations. Two dangling references in the V1 ERD JSON were corrected: `location_batch_items.batch_id → location_ingest_batches` and `admin_role_permissions.permission_code → admin_permissions`. These are **existing logical entities**, not a reason to add duplicate tables. The Figma ERD canvas still requires synchronization. The current M1 physical catalog and stacked PR migration sequence (0001–0004) must be reconciled before creating V2 child-grant migrations. No physical tables were created by this audit.
