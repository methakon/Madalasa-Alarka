# Physical database schema deep audit and remediation specification — 2026-10-29

**Status:** audited conceptual relationships; design remediation specified, **not** migrated or deployed. **Baseline:** Figma ERD JSON V1 (120 unique entities / 11 domains), existing M1 SQL 0001 on main and 0001–0004 on the stacked PR line, 18 physical tables, 17 currently ERD-mapped, 1 physical-only. The 103 conceptual-only entities are not automatically missing tables. Owner direction: child-scoped V2 authorization, PostgreSQL, SOLID HMVC modules and independent workers.

## 1. Verified referential faults in the original ERD JSON

Scanning every `→ target` reference in `docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json` yielded **32 explicitly declared reference arrows; two point to nonexistent entity names**:

| Referring entity / field | Unresolved target | Resolution in next ERD revision | Physical migration rule |
|---|---|---|---|
| `location_batch_items.batch_id` | `ingest_batches` | Rename reference to **`location_ingest_batches`**, existing canonical logical entity | Use `batch_id` FK to the canonical ingest batch PK; enforce child/device consistency and rejection after erasure |
| `admin_role_permissions.permission_code` | `permissions` | Rename target to **`admin_permissions`**, existing canonical logical entity | FK references immutable/unique permission code; verify exact existing PK/unique key and type |

**Do not add shadow tables named `ingest_batches` or `permissions` solely to satisfy these references.** Update the Figma source and versioned ERD in a coordinated change with the mapping checker. This review has corrected the two dangling references in the version-controlled V1 ERD JSON (entity/column counts unchanged); the Figma canvas is **not yet synchronized**. The original errors remain recorded above for provenance. When V2 is published, recalculate `tableCount`, rerun `backend/tests/check_physical_catalog.py --write` and the 16 drift tests, and ensure the generated document changes atomically.

## 2. Incomplete definitions needing an explicit physical spec

- Logical ERD has **41 column-entry strings containing enum references** but no canonical enum value registry. Do not synthesize arbitrary values from names. Define allowed values from already executed M1 CHECK constraints for existing tables; for new types, add an explicit values/transition/unknown/retired policy and API mapping.
- Many temporal fields use informal `time`, `time?`, `time range` rather than SQL types. Convert event instants to `timestamptz` (UTC contract), true local time-of-day to `time with/without time zone` only where semantically justified, ranges to typed `tstzrange` or start/end instants with CHECKs.
- Entries such as `android_api, device_mode : int/enum` and `state, revoked_at : enum/time` are shorthand; expand to individually typed, nullable, indexed physical columns. Record JSONB payload schema/version/size limits and avoid treating narrative lines as columns.
- Figma V1 contains `credential_renewal_challenges` in M1 physical tables but **no equivalent conceptual ERD entity**; add it as a canonical security-lifecycle entity only when publishing the next ERD revision, and update `tableCount` and all derived artifacts together.
- `capability_snapshots.device_mode` is the confirmed physical equivalent of logical `management_mode`; keep current physical name, allowed values (`STANDARD`, `MANAGED_DEVICE_OWNER`, `UNKNOWN`) and `is_device_owner` consistency check. `os_reject_reasons` remains a recorded logical-only difference. `child_ref` discrepancies exposed by the corrected parser must remain explicit, not filtered.

## 3. Ownership / authorization closure

**Canonical authorization:** child_id is the unit of read permission; billing-family_id is ownership/commerce, not automatic sibling access. The M1 `guardian_memberships` FK on `child_guardian_grants` is incompatible with external co-parent sharing. V2 must use child-scoped invites, authority review, grants, scope, expiry and revocation epoch; RLS and every backend/worker path must fail closed. Preserve M1 migration checksum history until explicit safe baseline policy is adopted. There are already `0002`, `0003`, `0004` on a stacked branch: **do not reuse these migration numbers**.

**Indirect child entities requiring owner-consistency proof:** `command_results`, `trip_revisions`, `trip_legs`, `route_geometry`, `place_notification_rules`, `notification_deliveries`; also review `parent_notification_read_receipts` in the recipient's access context. Choose one of: (a) explicit `child_id` plus composite FK that proves the parent has the same child, or (b) immutable parent FK plus a tested RLS join to the parent child's key. Never add `child_id` without referential consistency. Admin notifications are staff operations data and do not automatically require child ownership.

**Every newly implemented child-associated table:** specify owner path, trusted principal derivation, policies for SELECT/INSERT/UPDATE/DELETE, RLS FORCE, admin/service role restrictions, negative sibling tests, revoked-grant behavior, and tombstone suppression for delayed uploads.

## 4. GPS model convergence

One canonical `location_observations` must record immutable `child_id`, `device_id`, enrollment/assignment provenance, per-device dedup key or monotonically validated sequence, `observed_at` and server `received_at`, location, accuracy/quality and source/version. Prefer server-received-time partitions for deterministic cleanup of inbox/ingest operations; preserve `observed_at` for actual event age/retention eligibility and trip reconstruction. Reject timestamps beyond the approved 48h offline delivery window plus bounded tolerance, including future-dated events. Do not conflate partition-drop time with legal observation-time retention: apply observation-time eligibility checks and retention scans within partitions. Check global uniqueness constraints on partitioned PostgreSQL tables; use a separate dedup ledger if global unique device-event keys cannot include partition key.

`route_geometry` must not duplicate raw per-point observations for every trip revision; store reference ranges or selective immutable compressed geometry with explicit storage/retention policy.

## 5. Overlap normalization / module ownership

- Audit: enumerate the currently described audit entities; distinguish security access audit, payment reconciliation audit and child/media access audit by retention/privacy; consolidate infrastructure only where compatible and never give admin general child-data read access.
- Inbox/outbox: shared durable envelope conventions (event_id, schema_version, child/device, received_at, dedup/idempotency, status, attempt, leasing, last error) with separate processing tables/queues where transaction and privacy boundaries require them. Do not treat in-memory retries as durable ACK.
- Admin `admin_principals` vs `admin_accounts`, and `support_cases` vs `support_tickets`: choose canonical entity or documented separate purpose, migrate references and eliminate duplicate authority/source of truth.
- Operational data such as `architecture_decisions`, `cost_usage_snapshots`, `feature_release_gates` belongs to restricted operational schema/ownership, not unrestricted child RLS; a separate physical database is optional, not a current prerequisite.
- HMVC schema ownership: identity, devices, GPS/trips, alerts, billing, privacy, admin. Each table has **one** write owner; cross-module reads use documented narrow interfaces/views, not arbitrary coupled writes.

## 6. Retention and deletion — required mapping rather than a guessed period

The current `DATA_RETENTION_SCHEDULE.md` explicitly leaves periods pending; GPS 14 versus 30 days is unresolved. **Never silently decide legal retention by assigning the free 6-hour visibility window as TTL.** Add a machine-readable per-physical-table manifest with fields: schema.table; module_owner; child_data boolean; retention_category; time_column; retention_clock (observed/received/closed/processed); candidate_period; approval_state; erasure_strategy; backup/restore effect; audit/legal-hold exception; partition policy. Include all base tables, materialized views, search projections, inbox/outbox payloads and relevant backups/WAL lifecycle. Default unresolved real-child collection to release gated OFF, but implement synthetic test fixtures and configurable nonproduction TTLs. Apply tombstones and revoke processing before purging so late device uploads cannot restore child data.

## 7. Implementation backlog and acceptance (no fake closure)

| Priority | Agent task | Exit evidence |
|---|---|---|
| P0 | Synchronize two corrected logical references to **Figma canvas** and add referential integrity lint | 0 broken targets, no new shadow entities, generated catalog and CI pass |
| P0 | Canonical typed column/enum registry; correct FK PK/type checks | every implemented physical field typed, enum values explicit, postgres migration executes |
| P0 | V2 child-scoped grants and SQL authorization; reconcile 0002–0004 first | cross-family A1 allowed, sibling A2 denied, revoke denied, no billing-family leakage |
| P0 | Canonical GPS ingestion/partition/dedup/enrollment | fresh/post-backfill SQL tests; accepted vs rejected late/future fixes; queue restart |
| P0 | Retention table manifest and deletion cascade design | 100% physical object coverage, purge/restore/tombstone tests |
| P1 | Normalize command/trip/delivery ownership FKs | negative cross-child FK and RLS tests |
| P1 | Resolve audit/queue/admin/support duplication before schema creation | canonical entity ownership and API references synchronized |
| P1 | Physical schema → OpenAPI operation matrix | each implemented operation lists writes/reads, owner module, permission and tests |

**No schema migration is claimed here.** Current physical catalog/checker describes M1 only; do not rewrite it to assert future entities exist. Implement in compatible, sequential Git work after stacked #3/#4 integration, respecting branch reuse and PR registry. Evidence must include actual `psql` result, non-superuser RLS tests, migration checksum, commit, CI and a reproducible local database.

## 2026-10-29 live Figma reconciliation and separate implementation branch discovery

**Figma edited directly (readback verified):** page `92:2`, node `94:130` now reads `FK batch_id → location_ingest_batches`; node `108:62` now reads `FK permission_code → admin_permissions`. The GitHub ERD JSON was corrected earlier; the canvas has now been synchronized for these two references. The `32` explicitly encoded arrows and `120` entity counts are unchanged. Do not create `ingest_batches` or `permissions` duplicates.

**Newly discovered existing branch:** `feat/local-postgresql-physical-schema` already implements a separate family of migrations `0002_child_scoped_cross_family_guardians.sql` through `0015_ingestion_membership_and_fences.sql`, with `backend/tests/database/test_schema_completion.py` and a logical-to-physical normalization registry. This work was not visible on `main` or in stacked PR #3/#4. Therefore the earlier assertion that the project has *only* 18 physical tables is valid for the #3/#4/#5 M1 line but NOT a verified description of this other development branch. Do not blindly generate all 103 ERD-only entities or overwrite the existing branch.

**Urgent merge/design conflict:** the active #3/#4 line uses versions 0002/0003 for device credentials and 0004 for idempotency, while `feat/local-postgresql-physical-schema` has distinct 0002/0003/0004 migrations for authorization, consent and billing. These histories are incompatible if applied under one migration number without checksum reconciliation. The local schema branch's 0002 references `ap_m1.device_key_records`, which is introduced by the M1 credential branch's 0002, demonstrating a dependency that is not represented by its own filename ordering if based on main. The first coding task is to compare branch ancestry and actual target database histories, select a single migration lineage, renumber/rebase dependent SQL on that lineage, and run clean and upgrade PG16 integration tests. Do not discard synthetic work or force-push other agents' branches.

**What is and is not completed:** logical FK name reconciliation + GitHub JSON + Figma text edits: DONE; ERD reference CI validation: authored on PR #2, pending full green CI confirmation. SQL V2 and substantial physical schema work: EXISTS ON A SEPARATE UNMERGED BRANCH, NOT FULLY VERIFIED OR INTEGRATED. Full 120-entity physical realization: NOT the objective; compare normalized aliases and explicit open gaps. No claim of actual runtime deployment, end-to-end security acceptance or signed retention policy.

**Follow-up documentation deliverables for the implementer:** publish per-table ownership/retention manifest generated from real PostgreSQL catalog (include table/view/partition, RLS, indexes, FK and worker read/write module), versioned typed schema source, migration collision resolution log, and CI evidence for both a fresh database and an upgrade database. Keep the legal 14-vs-30-day raw GPS retention period as owner/counsel-pending, not hardcoded.
