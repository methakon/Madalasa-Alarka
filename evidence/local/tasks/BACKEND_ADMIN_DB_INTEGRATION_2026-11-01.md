# Evidence — Backend/Admin DB Integration Test Run (synthetic, local)

- **Scope:** backend + admin V2 database integration suite (not a single DAG task; cross-cutting E-01/E-02/E-08/E-09 and the admin P0/P1 workstream)
- **Branch:** `api` (backend/API/SQL worktree Amar-Pola @ 18a5f90)
- **UTC run timestamp:** 2026-11-01T14:25Z
- **Environment:** Linux x86_64; Python 3.12 venv with psycopg[binary]==3.3.6; Docker RAM-backed Postgres (postgis/postgis:16-3.5) on 127.0.0.1:15433; JDK not required
- **Privacy class:** SYNTHETIC_DATA_ONLY (disposable loopback test DB `madalasa_alarka_test`; synthetic fixtures; no real data; no secrets printed)
- **Release gate:** CONDITIONAL_HUMAN_SIGNOFF
- **Verification type:** AUTOMATED_TEST_REQUIRED

## Pre-work synchronization (HARD GATE)

`bash docs/tools/sync_work_branch.sh api` →
`PREWORK_SYNC_OK branch=api main=98907842e4c2b40a6c2b49fa9a8bacafaf5803eb dev=5379acb87670d63e1bac5c7eb958d780a87907b5 head=18a5f90a90d06b61fa94061a54d088ce012b276d utc=2026-11-01T14:10:44Z`
Clean worktree; origin/main then origin/dev merged into api.

## Setup (via the project's own runner, not hand-rolled)

- `pip install psycopg[binary]==3.3.6` into `.venv` (pinned; bundles libpq, no system libpq needed).
- `tools/database/manage.py start-memory-test` → RAM-backed test DB healthy on 127.0.0.1:15433 (loopback only); PostGIS + pgcrypto installed.
- `tools/database/manage.py migrate --database test --lineage v2` → exit `0`; all V2 migrations applied including `0021_parent_oidc_session_bridge.sql` and `0022_admin_session_bridge_and_back_office.sql`.

## Verification — executed

`tools/database/manage.py test --database test` → exit code `0`.

- **Ran 254 tests in 85.169s.**
- **Result: `OK (skipped=10)`** — 244 ok, 10 skipped, **0 failures, 0 errors**.
- Admin/auth-related tests included and passing (35): admin identity/RBAC, admin session bridge, parent OIDC session bridge, back-office, support/FAQ, privacy-admin.
- Representative passing areas: forced RLS + runtime-no-direct-mutation, schema completion/export metadata (fail-closed on missing owner), billing prepaid entitlements + stacked refunds (contiguous terms, deterministic compaction, refund cannot reopen expired predecessor), erasure/authority ledger, device key binding, ingestion pipeline.

## Acceptance mapping

This exercises the backend/admin integration with real SQL behavior under non-superuser separate logins (RLS enforced, not SET ROLE). It provides formal, reproducible test evidence that the V2 schema + admin session/RBAC bridge behave correctly on synthetic data. It does NOT certify the C++ Drogon HTTP handlers (those need the backend compile, still BLOCKED on system dev headers) and grants no legal/Play/release permission.

## Figma design alignment

Billing refund/term tests align with SH-04/SH-06 (100-day add-on, dormant-on-lapse) commercial invariants; admin RBAC tests align with the BO-01..BO-09 admin back-office screens (owner approval, FAQ, support) with least-privilege (no child-private data to owner).

## Result

- **State: PASS** (254 tests, OK, exit 0). Disposable test DB; teardown performed after the run.
- Open: C++ backend compile + HTTP-level integration remain BLOCKED_ENVIRONMENT (system dev headers / sudo); recorded under L01-005.
- Reviewer: NOT YET ASSIGNED. Status-ledger update deferred to `main`.
