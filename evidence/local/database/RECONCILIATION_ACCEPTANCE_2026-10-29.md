# Migration lineage reconciliation and PostgreSQL acceptance — 2026-10-29

Scope: synthetic local development/test databases only. No production connection, provider verification, Play action, real-child data or deployment.

Baseline reviewed: `beb85125935435ef9400264bb5fb0bc405575e74`. Executed source: `37704be9726750466ceadfa6922540586d44d294` plus the 0019 reconciliation, committed as `99f0914fb55eaf15b12436f8db9ed420880fb8b1`.

## Defects found, reproduced, then fixed

An independent read-only review of every SQL file (`22` migrations plus the compatibility adapter) and of the two lineage test modules reported four concrete defects. Each was reproduced against the installed 0018 schema before any fix existed; the RED output is kept in the ignored logs named below.

| # | Defect | RED evidence | Fix |
|---|---|---|---|
| 1 | `purge_expired_location` (0005) deleted `location_event_dedup` rows before the 0015 batch membership that references them, so retention aborted with `23503`; it also ignored that a retained newer batch may legitimately contain an older event | 2 failures, exit 1 (`test_reconciliation_lifecycle.py`) | 0019: trips → observations → expired batches (membership and outbox cascade) → event identity only when no retained observation **and** no retained membership references it |
| 2 | `request_account_erasure` (0014) passed one shared `request_key` to `withdraw_consent` for every GRANTED CORE consent, while `consent_decision_audit` is `UNIQUE(actor_id,request_id)`; the second child aborted the whole erasure with `23505` | 1 failure in the same run | 0019: deterministic per-`(request_key, consent)` audit key; replay-stable, no audit deletion, unique constraint untouched |
| 3 | Credential, challenge and 60-second issuance windows (0017) used `now()`, frozen at transaction start, so a transaction opened before a deadline — or one that only reached the check after a row-lock wait — could authenticate an expired credential or issue outside the window | 8 failures, exit 1 (`test_reconciliation_credentials_media.py`) | 0019: mutators sample `clock_timestamp()` after the lock they validate, re-sample after the second lock, and write that same instant; the read-only lookup stays `STABLE` on `statement_timestamp()` |
| 4 | `media_sessions(request_id)` and the quota/artifact rows (0009) did not constrain the child, so a valid identifier from another child could be associated with the wrong child | 1 failure in the same run | 0019: composite `(child_id,id)` keys plus composite FKs; preflight fails closed on any existing cross-child row, keeps every row, preserves a nullable `addon_id` and adds no cascade |

`0019_reconciliation_and_child_binding.sql` (SHA-256 `7089fe231c80046cfef7a9d984cc0ff176bf7d3a5b29e6f59011e0ce66b7ac7c`) is additive: it edits no published migration, changes no table shape or policy, and replaces only function bodies whose signatures, volatility, owners, `search_path` and ACLs stay identical.

## Executed acceptance

| Command | Actual result |
|---|---|
| `db test --pattern test_reconciliation_lifecycle.py` | RED: 5 tests, 3 failures. After 0019: **5 passed** |
| `db test --pattern test_reconciliation_credentials_media.py` | RED: 16 tests, 9 failures. After 0019: **16 passed** |
| `.local-db/venv/bin/python tools/database/verify_lineages.py` | Exit 0 — original M1 replay, 18-table live checkpoint, populated M1→V2 upgrade through 0019, historical inspection restore, restore upgrade held closed until erasure suppression, clean V2 with 19 entries, exact ledger adoption without mutating legacy history |
| `db test` (unfiltered discovery) | Exit 0 — **205 tests in 116.104s**, zero failures |
| `.local-db/venv/bin/python tools/database/build_backend.py` | Exit 0 — native build and CTest 1/1 |
| `export_schema.py` then `--check` | Exit 0 — 7 artifacts regenerated and byte-verified |
| `check_physical_catalog.py` + its 17 tests | Exit 0 — historical 18-table checkpoint unchanged |
| `lint_openapi_full.py`, `lint_openapi_m1.py`, `check_erd_references.py`, `check_document_structure.py`, `git diff --check` | All exit 0 |

Both databases now report PostgreSQL 16.9 / PostGIS 3.5.2, 139 application tables, 2 recovery tables, 2 ledgers, 7 views, **296** indexes, 82 policies, 127 functions, 19 applied migrations, FORCE RLS on every application and recovery base table.

## Schema equivalence now covers what the review said was missing

The previous checker compared columns, relation ACLs, constraints, indexes and function bodies. It now compares, between the upgraded M1 database and a fresh V2 database:

- tables, columns, types, defaults and nullability in `ap_m1` **and** `ma_recovery`;
- primary/foreign keys and CHECK constraints with validation state;
- indexes, view definitions, `reloptions` and RLS enable/force flags;
- every policy definition with roles and command;
- function identity arguments, full `pg_get_functiondef` body, volatility, `SECURITY DEFINER`, `search_path`, owner and ACL;
- relation and **column-level** ACLs, schema ACLs/owners, and the `ap_*`/`madalasa_*` role attributes and memberships.

Four rollback-only negative controls (`test_lineage_equivalence.py`) prove the comparison can fail: a new policy, a column-level grant, a role-membership change and a recovery-schema policy are each detected.

`load_migration_manifest`/`migration_plan` now also refuse a partially applied historical M1 chain before any DDL; two sub-cases in `test_migration_lineages.py` cover it.

## Physical catalog and logical model

The 120-entity canonical ERD keeps both corrected references (`location_batch_items.batch_id → location_ingest_batches`, `admin_role_permissions.permission_code → admin_permissions`); the 124-entity local proposal remains separate and explicitly unapproved. Derived mappings now distinguish a `DERIVED_VIEW` from a `NORMALIZED` or `FUNCTION` representation instead of labelling a view as `DIRECT`, verified by a new metadata test. Retention/ownership and typed-constraint exports were regenerated against the post-0019 catalog.

## GitHub integration status

Verified read-only: PR #5 is merged into PR #4's branch, **not** `main` (`976805d` is an ancestor of `ddbb25a`, not of `861ab630`); #3, #4 and #6 are open. This branch shares only `main=861ab630` with that stack and none of its commits are ancestors. The required order is #3 → #4 → #6, then a rebase of this branch that keeps the database-backed backend, the migration manifest and the adapted historical-catalog checker while adopting the stack's error catalog/request-ID handling and contract lint. That sequence is recorded in `docs/phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md`.

Remaining gaps, stated plainly: the M1 stack's API-convention/error-enum contract and the G-6 lint are not merged into this branch; no real OIDC exchange, admin HTTP handlers, provider, Play, Figma pixel or legal acceptance exists; `AGENTS.md` was not updated because writing that protected file needs owner approval.
