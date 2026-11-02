# PR11 PostgreSQL V2 reconciliation — local acceptance record

**Date:** 2026-10-30
**Repository:** `methakon/Madalasa-Alarka`
**Pull request:** [#11](https://github.com/methakon/Madalasa-Alarka/pull/11) (`feat/local-postgresql-physical-schema` → `main`)
**Source reviewed:** `b507e5f47e78d453db2703d02a3d80dcb45fa1dc`, merged with `main` `4a1fda5f0f9f2735ba078e13c48c4755ee92c6b9`
**Environment:** isolated PostgreSQL **16.9** + PostGIS **3.5.2** container `madalasa-pr11-test-postgres` (image pinned by digest `sha256:7ef69963…d920bc`), loopback `127.0.0.1:15434`, 384 MB tmpfs data directory, 512 MB / 1 CPU limit
**Status:** engineering acceptance for the reconciled branch. **Not** deployment, Play, legal or real-child approval.

## 1. Integration strategy

The existing branch and PR were used; **no new branch was created** and `main` was not rewritten.

| Conflict | Decision |
|---|---|
| `backend/CMakeLists.txt` | Kept `main`'s production targets verbatim and added one opt-in block: `MA_LOCAL_DB_READ_PROBE` (default `OFF`) building `ma_local_database`, `ma_local_db_read_probe` and `database_config_test`. The probe library is never linked into `ma_backend`. |
| `backend/src/main.cc` | Kept `main`'s production entrypoint **byte-identical** (verified by `git diff`); the feature branch's database application was preserved as `backend/src/local_db_read_probe.cc`. |
| Physical catalog tooling | Combined: the branch's manifest-pinned, schema-scoped parser and duplicate-`CREATE` guard plus `main`'s six-migration M1 coverage (`common:0001` + `m1:0002–0006`), with `checkpoint='0004'` as the only frozen-source alternative. |
| Catalog JSON / report | Retained `main`'s current through-0006 report **including the 0006 retention-hold mappings**; the branch's through-0004 mapping bytes were archived verbatim under `docs/data-model/historical-m1/` and labelled frozen, not a second current report. |
| Branch register | Kept `main`'s completed consolidation rows; the V2 row now records PR11 as the active integration instead of instructing replacement of the production backend. |

Two design questions were resolved deliberately rather than by picking a side:

1. **No production V2 session issuance was invented.** `ap_m1.mint_session` / `_session` remain gated by `local_test_settings.enabled` + `LOCAL_TEST_APPROVED`, so a verified Google OIDC identity cannot lawfully obtain a V2 opaque session in production. A proposed `issue_verified_parent_session()` was rejected because minting a new production session authority is a security-contract change outside this reconciliation. Production `ma_backend` therefore stays on the historical M1 `resolve_parent_principal` / `ap.principal_id` path, and V2 is exercised only through the synthetic harness. **This remains an explicit blocker for V2-backed production authentication.**
2. **Alternate/CI configuration surfaces are bounded.** `MA_LOCAL_DB_DIR` accepts only unset/`.local-db`/`.local-db/pr11-runtime`; port 15434 is accepted only for `madalasa_alarka_test` on the labelled PR11 container; CI mode (`MA_LOCAL_DB_CI=1` + `GITHUB_ACTIONS=true` + `MA_CI_SYNTHETIC=1`) replaces `docker inspect` with a server-side identity proof and allows only port 5432 for that same database.

## 2. Migrations

27 manifest entries, all checksum-pinned (`.local-db/pr11-immutability.json`): **0 pin mismatches**, and every M1 migration that also exists on `main` is **byte-identical** to `origin/main`. Published V2 `0002–0019` and `compat/m1_pre_v2_0016` were not modified.

Added (both new files, pinned, `published: true` so any later edit fails the runner):

| Identity | File | Purpose |
|---|---|---|
| `compat:m1_pre_v2_0017` | `backend/persistence/migrations/compat/m1_pre_v2_0017.sql` | Captures `credential_renewal_challenges.retention_hold` into the private, forced-RLS `ap_m1.m1_renewal_hold_preservation` **before** published `0017` renames and drops `m1_historical_renewal_challenges`. No runtime/issuer grant; no-op on fresh V2 and 0004 origins. |
| `v2:0020` | `backend/persistence/migrations/0020_m1_current_lineage_convergence.sql` | Restores preserved holds; re-adds hold columns on clean V2; normalizes `resolve_parent_principal`/`create_family` ownership to `ap_db_executor` with table **and column** ACL cleanup; `create_family` revalidates the live session after the cap advisory lock; credential/enrollment/pairing mutators restored on M1 0006's device→key→challenge→credential order with `clock_timestamp()` sampled after the final lock; catalog-driven `_m1_device_has_dependents` replaces `0017`'s `e:=0` stub so dependent devices/audit rows are preserved but abandoned devices can be purged; hold-aware `purge_pairing_codes` restored. |

`backend/persistence/migration-lineages.json` now covers `m1:0005`/`m1:0006`; the runner preflights every pending bridge before adoption writes, rejects unsupported/gapped histories instead of repairing them, and releases restore quarantine **only** when `v2:0020` is applied.

## 3. Executed acceptance

All commands ran in `/home/swarna-sekhar-dhar/projects/mypola/Madalasa-Alarka-db` with `MA_LOCAL_DB_DIR=.local-db/pr11-runtime`. Existing `.local-db/connection.json`, the 15432/15433 databases and the `ma_recovery` erasure ledger were never touched.

| # | Check | Command | Result |
|---|---|---|---|
| 1 | Container/PG/PostGIS | `docker exec … psql -c 'SELECT version()'` | 16.9 / PostGIS 3.5.2 |
| 2 | Fresh V2 replay | `manage.py create && manage.py migrate` | exit 0 — `0001, v2:0002–0019, 0020` applied in order |
| 3 | Fresh V2 verify | `manage.py verify` | exit 0 — 144 tables, 297 indexes, 82 policies, 131 functions, forced RLS on all |
| 4 | Fresh V2 regression | `manage.py test` | **232 tests OK** (includes 6 real HTTP→Drogon→PostgreSQL probe tests) |
| 5 | Probe HTTP acceptance | `manage.py test --pattern test_http_integration.py` | 6/6 OK: forged actor denied, profile = session identity, sibling hidden, pagination/family separation, consent schema, pooled context isolation |
| 6 | Historical M1 replay | `psql 0001…0006` on `amar_pola_m1` | exit 0 |
| 7 | M1 SQL suites | isolation, credential lifecycle, enrollment, idempotency, family provisioning | all exit 0 |
| 8 | Retention hold matrix | `m1_retention_holds.sql` (dedicated empty DB) | exit 0 — holds, device holds, ACL negative control |
| 9 | M1 security catalog | `m1_security_catalog_acceptance.sql` (`madalasa_pr9_review`) | exit 0 — 18 forced-RLS tables, 3 negative controls detected/rolled back |
| 10 | Purge job | `bash backend/tests/purge_job.sh` | exit 0 — least privilege, bounded waits, hold preservation |
| 11 | Credential concurrency | `m1_credential_concurrency.py --migration 0006…` | exit 0, all cases pass |
| 12 | Purge concurrency | `m1_purge_concurrency.py` | exit 0, all cases pass |
| 13 | **0006 → V2 upgrade** | `reset; migrate --lineage m1; seed holds; migrate` | exit 0 — held `true` and `false` both preserved; `m1_renewal_hold_preservation` populated |
| 14 | Hold-aware purge after upgrade | `purge_credential_artifacts('1 day','1 hour','1 day')` | held row survived, expired unheld row removed |
| 15 | Upgrade suites (0006 origin) | convergence + compatibility + lineage equivalence | **24 tests OK** |
| 16 | **0004 → V2 upgrade** | `reset; migrate --lineage m1 --through 0004; migrate` | exit 0, 27 ledger rows, forced RLS |
| 17 | Upgrade suites (0004 origin) | convergence + compatibility + equivalence + export metadata | **32 tests OK** |
| 18 | Backup / restore | `backup; insert tombstone; restore --file` | exit 0 — checksum verified, quarantine during restore, tombstone preserved, recovery ledger imported, reopened only after suppression completed |
| 19 | Catalog/ERD static | `check_physical_catalog.py` / `check_erd_references.py` | 18 tables, 17 mapped to the 120-entity ERD, 1 without entity; 30 tests OK |
| 20 | OpenAPI lints | `lint_openapi_m1.py`, `lint_openapi_full.py` | 14 M1 operations / 171 draft operations — contract only |
| 21 | Documentation | `check_document_structure.py`, `docs/tools/check_documentation.py` | 72 canonical docs; 253 files, 1,937 local links, 0 errors |
| 22 | Native build + CTest (probe ON) | cmake/ctest | 6/6: core, oidc, jwks, jwks_fetch, oidc_http, database_config |
| 23 | Native builds (probe OFF) | production (`MA_SYNTHETIC_AUTH=OFF`) and synthetic (`ON`) | 5/5 CTest each; marker gate PASS; HTTP smoke PASS |
| 24 | Family provisioning over HTTP | `integration_families.sh build-syn/ma_backend` | exit 0 — order/length checks, 201 shape, replay, key reuse, principal isolation, hashed keys, 8-way concurrency, cap, catalog errors |
| 25 | Authenticated DB failure matrix | `integration_db_failures.py build-syn/ma_backend --case all` | exit 0 — all cases PASS |
| 26 | CI-equivalent run (loopback 5432, service-style DB) | `MA_LOCAL_DB_CI=1 … ci-config/create/migrate/verify/test` | 224 tests OK, 7 documented skips (container-driven restore drill, absent review fragments) |
| 27 | Catalog export drift | `export_schema.py` + `--check` | 7 artifacts exported and verified against the recorded instance |

CI-mode skips are deliberate and named: the two container-driven backup/restore tests (the executed drill is row 18) and the fragment-source guards whose reviewed SQL lives only in the untracked working directory (its guarantees are carried by published `0019`/`0020` and the manifest checksum gate). Byte-level catalog drift stays a local gate: `pg_get_constraintdef` renders nested `AND` groups differently on separate clusters, so byte equality across a different cluster is not a valid CI assertion.

Failed attempts are preserved, not hidden: the first fresh-V2 suite run had 1 failure + 4 errors, all caused by tests inheriting the suite's own `MA_LOCAL_DB_DIR` (fixed by pinning default-config assertions and by giving CI precedence over alternate config in the fixture validator); the first restore attempt failed because `reset` re-created `ap_m1` before `pg_restore` (fixed by splitting schema bootstrap from reset and opting the restore path out); the first probe HTTP run failed because `connectionInfoFromEnvironment` rejected port 15434, and a subsequent run hit a `TIME_WAIT` bind (fixed by allowing only the exact test database on 15434 and by `SO_REUSEADDR`).

## 4. Remaining blockers and limits

1. **V2 production session issuance for verified Google OIDC is unimplemented.** `mint_session` remains synthetic-gated; no production-safe contract was invented. V2 cannot yet back production parent authentication.
2. **`ap_db_executor` bypass posture is assumed, not separately certified.** Every definer function and the device-dependency census assume it bypasses RLS; the purge tests assert real deletions, so a change would fail loudly rather than silently no-op.
3. **The 0017→0020 window is only safe inside one transaction.** Published `0017` still installs a hold-blind purge; `0020` restores it. The runner applies the range atomically — a split replay would be unsafe.
4. **Histories already converged before this bridge existed cannot recover destroyed renewal holds.** `0020` emits a `NOTICE` and never invents `hold = true`.
5. **tmpfs acceptance** does not certify disk/reboot durability; the container is deliberately volatile.
6. Evidence is synthetic only. No production database, real child data, deployment, Play Console action or legal approval is implied.

## 5. Reproduction

```sh
# isolated instance (fresh, private config; never the default .local-db)
MA_LOCAL_CHECKOUT="$PWD" docker compose -f infra/local/compose.reconciliation-test.yaml up -d --wait
export MA_LOCAL_DB_DIR=.local-db/pr11-runtime
python3 tools/database/manage.py create
python3 tools/database/manage.py migrate
python3 tools/database/manage.py verify
python3 tools/database/manage.py test
MA_DB_DEPS_PREFIX=… bash .local-db/pr11-builds-auth.sh   # production + synthetic variants, marker gate
```
