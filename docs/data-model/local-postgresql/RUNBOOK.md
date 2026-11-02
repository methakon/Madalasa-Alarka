# Local PostgreSQL development

**Status:** LOCAL_READY for synthetic database/API development; migration lineages, exports and the unfiltered 205-test suite are verified. Read the [package index](README.md) and [current status](STATUS.md) before executing these commands. Use the explicit manifest/runner, never directory-wide SQL replay: historical M1 and V2 intentionally preserve different published files numbered 0002–0004.

This runbook is for the dedicated synthetic development instance, never production. It binds PostgreSQL to `127.0.0.1:15432`, leaving any host installation on port 5432 untouched. Docker Compose limits it to one CPU and 512 MiB, with no automatic restart or system-service installation.

## Prerequisites

### Preserved historical migration lineages

`backend/persistence/migration-lineages.json` selects immutable paths/checksums; default `--lineage v2` converges clean V2 or upgrades a tracked historical M1 database. `migrate --lineage m1` selects only original 0001–0004 on an appropriately bootstrapped historical target; it cannot downgrade V2. `--through` is scoped to the selected lineage. Never repair a checksum row or renumber either published chain.

Run `.local-db/venv/bin/python tools/database/verify_lineages.py` for destructive replay acceptance on the exact labelled synthetic test database only. It preserves the independent recovery ledger, exercises original SQL/concurrency checks, compares the live 18-table M1 checkpoint, tests populated upgrade/restore and compares clean/upgraded schema/ACLs. Do not run it concurrently with another test/reset/restore process.

Default `restore --lineage v2 --file <ignored-backup.dump>` upgrades historical archives while recovery stays closed through erasure suppression. `restore --lineage m1` is inspection-only: it intentionally leaves runtime/issuer/verifier CONNECT revoked. Restore the same archive with `--lineage v2` to complete suppression and reopen. A successful historical inspection is not a runtime-ready restore.

### Tooling

Ubuntu/Linux with Docker Engine, Docker Compose v2, Python 3.12+, and either `uv` or Python `venv`/`pip`. The database image is pinned by digest in `infra/local/compose.yaml`; it contains PostgreSQL, PostGIS, `psql`, `pg_dump`, and `pg_restore`. `tools/database/requirements.txt` pins the libpq-backed Python migration/test driver. No MySQL or SQLite server is installed.

Run these commands from the repository root:

```sh
chmod +x tools/database/db
./tools/database/db init
./tools/database/db start
./tools/database/db create
./tools/database/db migrate --database dev
./tools/database/db migrate --database test
./tools/database/db verify --database dev
./tools/database/db verify --database test
./tools/database/db seed --database dev
./tools/database/db seed --database test
```

`init` securely generates secrets and stores them only under ignored `.local-db/` (directory 0700; credentials 0600). It preserves existing credentials on repeated runs. `.env.example` contains placeholders, not working passwords. Runtime, migration, authentication issuer and purchase verifier use separate logins. The runtime role cannot mint sessions, approve legal authority, verify payments, change release gates or inherit a bypass/function-owner role. `ap_m1_auth` is a read-only, NOLOGIN lookup role; `ap_db_executor` is a NOLOGIN owner of explicitly granted mutation functions, not an application login.

## Migration and upgrade rules

`backend/persistence/migrations/0001_m1_identity.sql` remains byte-for-byte historical. The runner verifies its pinned checksum. New migrations run in numbered order inside individual transactions with a session-level advisory lock. Version, filename, SHA256, execution time, APPLIED/FAILED status and SQLSTATE are recorded in `ma_migrations.history`; DDL and APPLIED tracking commit atomically. Repeating `migrate` verifies checksums and does not replay applied DDL. Never edit a published migration; append a new version.

To exercise the historical baseline before upgrading, use only the isolated test database:

```sh
./tools/database/db reset --database test
./tools/database/db create
./tools/database/db migrate --database test --through 0001
./tools/database/db legacy-test
./tools/database/db migrate --database test
./tools/database/db psql --database test < backend/tests/m2_blended_family_isolation.sql
```

The old M1 SQL tests demonstrate the historical schema only. The latest Python tests additionally prove that arbitrary principal/family/device GUC values cannot impersonate a session. Trusted identity now comes from a hash-checked, expiring, issuer-minted opaque session; context is transaction-local. Google OIDC validation/session exchange is a separate, not-yet-implemented adapter. A Google identity is not lawful parenthood evidence, and Family Link lookup is not a dependency.

## Build and test

For a disk-constrained workstation, `./tools/database/db start-memory-test` provisions a separate bounded test instance at `127.0.0.1:15433` and updates only the private test connections. It does not reset or relocate persistent development storage at port 15432. The test instance uses tmpfs (384 MiB), a 512 MiB container limit and one CPU; fsync, synchronous commit and full-page writes remain enabled. Its database is intentionally volatile across container recreation/reboot. Private backups and independent erasure ledgers remain under `.local-db/`; persistent-disk recovery requires separate evidence.

Synthetic fixture IDs are stable within a test process and unique across runs to avoid resurrecting identities already present in the independent erasure ledger. Set `MA_TEST_NAMESPACE` to a UUID to reproduce an exact fixture namespace. Do not clear recovery ledgers or weaken revocation merely to reuse a deleted fixture.

```sh
.local-db/venv/bin/python tools/database/build_backend.py
./tools/database/db test
python3 backend/tests/lint_openapi_full.py
python3 backend/tests/lint_openapi_m1.py docs/openapi-m1.yaml
python3 backend/tests/check_document_structure.py
git diff --check
```

The build script uses an existing SDK selected with `DB_SDK_PREFIX`, an ignored local SDK-prefix record, or the checksum-pinned Ubuntu amd64 rootless SDK lock. Rootless extraction uses `dpkg-deb`, not `sudo` or system package installation. Builds are single-job, nice/idle-I/O priority. Packaged Drogon needs SQLite/MariaDB *client development libraries* in its CMake dependency graph; the backend connects only to PostgreSQL.

`db test` runs real PostgreSQL tests, restricted-role/RLS tests, concurrency tests and actual HTTP→Drogon→PostgreSQL tests; it does not substitute a mock HTTP server. The lifecycle tests reset/restore only `madalasa_alarka_test`. Run test suites serially: independent migration or fixture writers must not share a schema concurrently. Synthetic review/consent fixtures explicitly enable a protected database-local test setting; no runtime API can enable it.

To run the local backend in the foreground:

```sh
.local-db/venv/bin/python tools/database/build_backend.py --run --database dev
```

It listens only at `127.0.0.1:18080`, uses two restricted runtime connections, a bounded two-worker queue and transaction-local authentication. Four read routes are connected: `GET /v1/parents/me`, `GET /v1/children/{childId}`, `GET /v1/families/{familyId}/children`, and `GET /v1/children/{childId}/consents`. Tokens are minted only by the protected issuer in synthetic integration fixtures; no public login endpoint or successful Google exchange is claimed. Never place a bearer in a committed command, URL or log. Other OpenAPI operations remain separately tracked, not implicitly implemented because their tables exist.

## Backup, restore and reset

```sh
./tools/database/db backup --database dev
# Use the exact ignored .dump path printed by backup:
./tools/database/db restore --database test --file "$PWD/.local-db/backups/<printed-file>.dump"
./tools/database/db verify --database test
# Destructive synthetic development reset requires an explicit target flag:
./tools/database/db reset --database dev --allow-dev
./tools/database/db create
./tools/database/db migrate --database dev
./tools/database/db seed --database dev
./tools/database/db stop
```

Backup archives and checksum metadata stay under ignored `.local-db/backups`. Restore accepts only those checked paths and verifies SHA256 before changing the database. It revokes CONNECT for runtime/issuer/verifier logins on the exact target and terminates their existing target-database sessions before restoring. Migration/admin access remains available for recovery. A failure deliberately leaves the target quarantined; `create` does not silently reopen it. Correct the underlying error and rerun restore. Opening a partially restored database is not an accepted recovery procedure.

An independent `ma_recovery` tombstone ledger survives application-schema resets and is excluded from application dumps. Restore merges newer destination tombstones, reruns actual child-store purge and revocation, upgrades the snapshot schema while closed, and only then reopens runtime access. The private JSON ledger is an additional local recovery artifact, not a claim that remote backups or other devices were erased. Fresh-host recovery still requires transferring the current protected erasure ledger along with approved backups; do not treat an old application snapshot as that ledger.

No real GPS, app usage, media, purchases, identity documents or child identities may be seeded. Default real-data/capture/provider release gates remain disabled. Six-hour free history is a visibility rule, not a physical retention schedule. Retention policies are configurable and unapproved periods are not silently adopted. Physical partitioning is deferred until measured volume justifies it; child/time and spatial indexes exist without fabricated scale benchmarks.
