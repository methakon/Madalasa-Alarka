# Local PostgreSQL re-verification checkpoint

Implementation commit: `3d3e285cbf92f0583749cb239d9e3c0bd74e903f`.
Branch: `feat/local-postgresql-physical-schema`.
Scope: synthetic test database only. Persistent development storage was not reset or moved for this checkpoint.

## Executed results

| Command / check | Result |
|---|---|
| Native build/configuration regression before enabling the isolated test port | RED: native CTest failed; build script exit 1 |
| `.local-db/venv/bin/python tools/database/build_backend.py` after the fix | exit 0; native CTest 1/1 passed |
| `./tools/database/db start-memory-test` | exit 0; separate PostgreSQL/PostGIS instance on loopback port 15433 |
| `./tools/database/db migrate` on the fresh memory-backed database | exit 0; all 16 committed migrations applied |
| `./tools/database/db test` | exit 0; 140 tests passed in 54.445 seconds |
| Repeat `./tools/database/db migrate` | exit 0; all 16 migrations UNCHANGED |
| `./tools/database/db verify` | exit 0; actual catalog and runtime-role checks passed |
| `.local-db/venv/bin/python tools/database/export_schema.py` followed by `--check` | both exit 0; five artifacts exported/read back against the actual catalog |
| `SHOW fsync`, `SHOW synchronous_commit`, `SHOW full_page_writes` | all `on` |
| Filesystem probe inside the test container | `tmpfs` |
| `git diff --check` | exit 0 |

The 140-test result includes six actual HTTP→Drogon→restricted PostgreSQL tests, both actual dump/restore tests, newer-erasure suppression, live device-key revocation, premium history lease/session boundaries, stacked refunds, adult/child erasure, admin SQL denial cases and screen-dependency SQL tests. It is not implementation of all documented HTTP operations.

Catalog snapshot: PostgreSQL 16.9, PostGIS 3.5.2; 138 application tables (141 including migration/recovery tables), 287 indexes, 82 policies, six views, 113 application/recovery functions, 16 applied migrations. Application/recovery base tables have ENABLE/FORCE RLS; checked runtime roles are NOSUPERUSER/NOBYPASSRLS.

## Repairs and evidence limits

The earlier persistent test instance had a checksum mismatch for migration 0016. It was not waved through or repaired by changing a recorded checksum: the committed source was replayed into a fresh isolated database. Host I/O pressure remained high, so the new instance uses bounded volatile storage: one CPU, 512 MiB container limit, 384 MiB data tmpfs. This proves local PostgreSQL behavior, not persistent-disk durability, performance or reboot recovery. Backups and independent erasure ledgers remain private project-local artifacts.

A shared synthetic child had been tombstoned by an identity test. Deleting only the application tombstone could not remove the independent recovery ledger, correctly causing later restores to suppress that child. The test now uses its own child, keeps recovery suppression intact, and proves the other child remains visible. Fixture namespaces are unique per run and can be fixed with `MA_TEST_NAMESPACE`; domain fixture cloning excludes revoked historical grants. No authorization assertion was weakened.

## Still open — no overall LOCAL_READY claim

- The full OpenAPI/screen lint was executed and failed: the recently changed logical model reports 124 entities while the approved audit summary/lint baseline remains 120. Reconcile provenance and required artifacts; do not merely relax the count assertion.
- Existing stacked M1 work already owns different migrations 0002–0004. Resolve lineage/compatibility without rewriting published SQL or blindly applying old broad function grants after V2.
- Review the new enhancement migration's semantics and add targeted acceptance before claiming pickup-pass or compliance-export functionality. Tables are not implemented handlers.
- Finish per-table retention/ownership metadata and persistent-development upgrade verification.
- Synthetic metadata-only admin API coding is permitted, but a verified admin HTTP module, Google token adapter, contract/security tests and normal review/CI remain to be delivered. No raw child-data owner bypass is authorized.

[Current status](../../../docs/data-model/local-postgresql/STATUS.md) · [Runbook](../../../docs/data-model/local-postgresql/RUNBOOK.md) · [Historical I/O-blocked checkpoint](INTEGRATION_PENDING_2026-10-29.md).
