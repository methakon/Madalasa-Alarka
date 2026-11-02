# PostgreSQL V2 branch reconciliation — 2026-10-30

Status: **IN PROGRESS / NOT MERGE READY**. Tracking: [draft PR #11](https://github.com/methakon/Madalasa-Alarka/pull/11).

## Snapshot inspected
- Main: `80cfdb3a8e52f2e5fd4f81e80ecea37ba8da56d6`.
- Feature: `b507e5f47e78d453db2703d02a3d80dcb45fa1dc`.
- Merge base: `59125d402b07c20aaf6ecb13d69542997223bedf`.
- Feature ahead 14, behind 58. GitHub reports 102 changed files and draft PR not mergeable.
- `0001_m1_identity.sql` blob SHA is identical across both branches: `be501b33351daf25de32774598aafc0fcff2b380`.

## File-by-file reconciliation inventory (review groups)
1. Historical M1 migrations: `0001` equal; M1 `0002–0004` present in both branch histories; main additionally has published `0005_m1_family_provisioning.sql` and `0006_m1_concurrency_and_retention_holds.sql`. Feature branch migration-lineages manifest currently lists only historical M1 `0001–0004`. Before V2 use, reconcile both additional published M1 migrations with checksum-preserving, synthetic data-replay tests.
2. V2 migrations: retain distinctive `0002_child_scoped_cross_family_guardians.sql` through `0019_reconciliation_and_child_binding.sql` and `compat/m1_pre_v2_0016.sql` as candidate *published feature-branch lineage*. Do not modify their bytes; evaluate whether an **additional** versioned bridge migration is necessary.
3. C++ build/runtime: `backend/CMakeLists.txt` and `backend/src/main.cc` differ materially; main runs M1 family APIs + Google OIDC/JWKS, feature runs a separate database-backed application. Integration must add `Database.cc`/headers/test target to main without overwriting M1/OIDC, and decide whether an auxiliary database executable or a shared adapter is correct.
4. Existing catalog tooling: `backend/tests/check_physical_catalog.py` and `backend/tests/physical_schema.py` differ; preserve historical 18-table M1 catalog invariant while adding new separate converged-V2 catalog verification, not replacing the M1 contract.
5. Additional distinct work: `backend/tests/database/` fixtures/integration tests, `tools/database/`, local synthetic Docker Compose, physical ERD and retention/ownership metadata, exported catalogs, audit evidence and mapping registries. Review for current paths and safe generated-artifact reproduction.
6. Shared documentation and configuration: `.env.example`, `.gitignore`, docs index/roadmap/ERD, and lint scripts must be merged semantically, preserving newest owner and compliance decisions from main.

## Migration-by-migration sequence to verify
- M1 historical 0001 through 0004: exact SHA-256 manifest validation.
- M1 current 0005 and 0006: separately verify full published byte hashes, schema changes, function signatures and retention semantics.
- V2 0002 through 0016: fresh replay, populated M1 upgrade and family/child access/consent gates; verify no published SQL changed.
- V2 0017: re-review M1 lineage-compatibility functions against *new* M1 0005/0006; detect function overwrite/regression.
- V2 0018: schema enhancement guard assertions.
- V2 0019: purge FK, account erasure, credential clock and media cross-child binding regression cases.
- Compatibility bridge: explicitly test historical M1 snapshots and restore quarantine.
- Final schema equivalence: roles/owners/RLS/policies/ACLs, columns, constraints, indexes, function bodies and ledger adoption.

## Verification required before merge
- Clean PostgreSQL 16/PostGIS fixture and synthetic-only isolation.
- All original M1 SQL tenant, enrollment, family, credential, idempotency, retention/hold and purge concurrency suites.
- All V2 database unit/integration tests, both populated-upgrade and fresh-replay lineages, negative equivalence controls, backup/restore, erasure and retention.
- Native C++ CMake/CTest plus Google OIDC/JWKS tests; production auth must fail closed.
- Physical and ERD catalog verifiers, OpenAPI lint, document audit and `git diff --check`.
- Record commands, database and tool versions, exit statuses, new commit SHA, and CI workflow URLs.

### Evidence limitations
Feature-side `evidence/local/database/RECONCILIATION_ACCEPTANCE_2026-10-29.md` records **205 passing tests** against that feature snapshot; no test has yet been rerun on reconciled current main. This environment cannot access the user's local Docker/PostgreSQL and the repository cannot be cloned from this container. **Do not claim combined database tests have passed.**

### Preservation rules
No force push, no deletion of the feature branch, no direct wholesale merge while PR conflicts remain. Only integrate verified unique work after resolving the above gates. This is engineering preparation, not an authorization to process real-child data or deploy.
