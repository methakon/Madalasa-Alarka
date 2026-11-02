# Local database integration — LOCAL_BLOCKED

Historical interrupted-run checkpoint. The isolated full suite subsequently passed 140 tests; see [current re-verification](REVERIFICATION_2026-10-29.md). Canonical integration remains blocked for the separately recorded migration-lineage and logical-model reconciliation work.

Scope: synthetic-only PostgreSQL/PostGIS in the dedicated local Docker container. No production, Play, live-device or real-child operations.

Worktree: `Madalasa-Alarka-db` (local implementation checkout).
Branch: `feat/local-postgresql-physical-schema`
Baseline commit: `861ab6304841b3bc047909f5c1a4e94704376294`
Implementation remained uncommitted at this execution checkpoint; this is NOT a task PASS or a release-readiness attestation. Documentation may be committed separately without certifying the implementation. See the [package index](../../../docs/data-model/local-postgresql/README.md) and [current status](../../../docs/data-model/local-postgresql/STATUS.md).

## Executed

- Clean `./tools/database/db reset && ./tools/database/db create && ./tools/database/db migrate`: exit 0; all migrations 0001 through 0015 applied using the migration workflow.
- `.local-db/venv/bin/python tools/database/build_backend.py`: exit 0; actual C++20/Drogon backend built and native CTest 1/1 passed.
- Historical 0001 SHA-256: `e6014a2e2512a793efc320b39be8d0f1b5a4de8b9f7560d444d88aa2ffa5b3fe`, unchanged from pinned baseline.
- Direct fixture-target safety RED: one test/four failed subtests, exit 1. GREEN after enforcing exact loopback test target: one test passed, exit 0.
- Latest exclusive clean-replay/full-suite command timed out at 240 seconds, exit 124, during `test_backup_restore_preserves_schema_and_quarantines_runtime`.
- Programmatic parse of the latest partial `.local-db/full-test.log`: 69 completed passing test lines; zero completed ERROR/FAIL lines. This is a PARTIAL run, not 69/69 full-suite success. All six real HTTP integration tests completed successfully within that partial run, as did the device-key, authorization and ingestion cases reached before restore.

## Concurrency incident

An independent local test runner was running the same suite in the same worktree/database while migration and destructive restore tests were in progress. Earlier aggregate failures, including a duplicate restored migration-history table and missing constraints after interrupted restore, cannot establish an isolated result.

The owner explicitly selected pausing the competing runner for exclusive integration. Its exact process identity was validated before suspension; the observed process state was T. No unrelated process was terminated. Resume competing database work only after exclusive integration is complete.

## Current infrastructure blocker

The isolated rerun still stalled on host I/O, not a PostgreSQL lock graph: observed PostgreSQL wait was IO/WALSync and blocking PID arrays were empty. `/proc/pressure/io` full avg10 observations included 74.87%, 67.17%, and finally 76.31%. One terminal pre-execution identity probe also timed out before running its command. Do not disable fsync, loosen security, manufacture passing results, or launch another heavy replay while this pressure persists.

## Remaining before completion/commit

1. Obtain a complete isolated full suite, including actual backup/restore/newer-erasure suppression, premium viewer history, stacked refunds, account erasure and seven schema-completion database cases.
2. Confirm runtime state/quarantine after the interrupted lifecycle test and recover through the runner, never manually certify READY.
3. Replay historical 0001 upgrade and original isolation acceptance separately from the final V2 authorization schema; repeat migration checksum/idempotency checks.
4. Generate and verify actual final catalog, ERD, 120-concept normalization and operation/dependency mapping with `tools/database/export_schema.py`; do not reuse intermediate table/function/policy counts.
5. Finish runbook/evidence and roadmap status with real command exits and an actual implementation commit SHA; then perform the requested Git delivery.

Schema normalization is not implementation of every HTTP operation or Android screen. Only four read handlers are currently wired. Media/capture/provider/legal boundaries remain fail-closed; synthetic keys and billing fixtures do not verify real possession, Google identity, Play purchases, or lawful authority.
