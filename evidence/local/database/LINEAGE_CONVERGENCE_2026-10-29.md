# Immutable migration-lineage convergence — executed evidence

Scope: synthetic local development/test databases only. No production, provider, Play or real-child acceptance.

Implementation commits: `4b4c4e85cebd3c35877d49e25fc2d7c11dc5f1a1` (lineages, compatibility, enhancement guards) and `50333c6dee6dfb45d6f56fd70501b8a4cb7a810f` (explicit restore-lineage routing and historical restore acceptance). Prior specification correction: `916a2bf`.

## Executed checks

| Command / check | Actual result |
|---|---|
| `python3 backend/tests/check_physical_catalog.py --write` | Exit 0; historical M1: 18 physical tables, 17 mapped to the 120-entity canonical ERD, one documented without a canonical entity |
| `python3 -m unittest discover -s backend/tests -p test_physical_catalog.py -v` | Exit 0; 17 tests, including duplicate-CREATE and mapping-drift negative controls |
| `.local-db/venv/bin/python -m unittest discover -s backend/tests/database -p test_migration_lineages.py -v` | Initially 15 tests passed; added restore-routing test reproduced a real ignored-CLI-option defect (one failure), then all 16 passed after repair |
| `.local-db/venv/bin/python tools/database/verify_lineages.py` | Exit 0; actual M1 replay, populated upgrade, historical restore selection, restore upgrade quarantine, clean V2 convergence and exact history adoption |
| Stable integration suite, excluding the separately authored `test_schema_export_metadata.py` | Exit 0; 168 tests in 54.753s, zero failures, including six real HTTP tests and both existing backup/restore regressions. This run preceded the additional restore-routing test; metadata acceptance remains separate |
| `.local-db/venv/bin/python tools/database/build_backend.py` | Exit 0; serial native build and CTest 1/1 passed using the configured rootless SDK environment |
| Bounded `db backup --database dev`, `db migrate --database dev`, `db verify --database dev` | All exit 0; persistent development advanced additively from 0015 to 0018 after a private checksum-bound backup; no development reset/restore |
| Published V2 source-byte comparison against `7123fd3` | All 16 existing migration files remain byte-identical |

Raw local logs: ignored `.local-db/lineage-replay.log`, `.local-db/lineage-full-tests.log`, `.local-db/restore-routing-red.log`, `.local-db/lineage-offline-green.log`. Private connection settings and dumps are excluded from Git.

## Actual upgrade and preservation acceptance

The acceptance tool resets only the exact synthetic test database, preserves the independent recovery ledger, bootstraps schema-role grants, then applies original M1 0001–0004 with the restricted migration login. Original tenant, credential, enrollment and idempotency SQL scripts execute; the original two-session idempotency shell regression verifies blocking/replay, rollback handover and bounded lock timeout. The live M1 table/column catalog equals the manifest-selected static 18-table checkpoint.

A separately seeded historical credential, renewal challenge and completed idempotency response are then preserved through V2 convergence. Exact renewal timestamps/digest/IDs and response fields survive; device/key IDs and active state are retained. Historical credential hashes remain recorded but are revoked rather than inventing proof/generation binding. Runtime and issuer denial tests run through restricted role connections.

Fresh V2 and upgraded M1 converge on identical ordered columns/defaults, normalized relation ACLs/owners/FORCE RLS, constraint definitions, indexes, function bodies/configuration/owners and function ACLs. This caught and repaired historical read grants and maintenance-function grants that source-only tests had not exposed. The namespaced ledger can be rebuilt by exact adoption without mutating any original numeric history row.

Historical `restore --lineage m1` now actually selects M1, restores 18 tables for inspection and deliberately leaves all runtime logins quarantined. Default/V2 restore upgrades the same historical backup while an in-process observer verifies CONNECT remains revoked after migration and before recovery suppression. Runtime opens only after independent-ledger suppression succeeds. M1 inspection restore is not a runtime-ready recovery mode.

## Repairs established by real replay

- FORCE RLS applies to migration-owner SELECT/DML too. Conversion checks, historical row merges and conservative credential revocation explicitly use the constrained executor role; they do not silently see zero rows and then drop the source table.
- Historical constraint names, not only the PK index name, must move out of the namespace before unchanged 0016 generates its FKs/checks. A real upgrade initially failed with SQLSTATE 42704; the unpublished pre-0016 bridge now renames every staging constraint.
- Metadata regressions first failed against 0016 and now pass with additive 0018: pickup metadata closes after child scope revocation; compliance case/family references cannot cross children.
- Bare `ctest` omitted the rootless SDK library path and failed to load `libtrantor.so.1`. The supported build wrapper supplies that environment; the actual native build/CTest then passed. No loader workaround or system install was introduced.

## Current physical checkpoint and remaining work

Both persistent development and isolated RAM-backed test now report PostgreSQL 16.9/PostGIS 3.5.2, 139 application tables, two recovery tables, two migration ledgers, seven views, 292 indexes and 82 policies. Application/recovery tables have verified ENABLE/FORCE RLS. Clean V2 uses 18 migration entries; the historical upgrade legitimately retains 22 original/namespaced history rows, including its bridge.

Migration-number collision and canonical-model count reconciliation are closed locally. Retention/typed-constraint metadata integration and an unfiltered final suite remain pending; no claim of complete admin API readiness is made at this checkpoint. The earlier persistent I/O timeout no longer blocks these bounded development operations, but no reboot/power-loss durability test is claimed. Visual Figma/provider/legal/device/production gates remain distinct and unaccepted.
