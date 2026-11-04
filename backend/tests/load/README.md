# Issue 32 / queued FF07 synthetic load preparation

**Preparation only. No database load has been executed by this handoff.** This is a
PostgreSQL/PostGIS ingestion-function harness, not an HTTP, worker-drain, Android,
battery, real-world GPS, production-environment or 108-device capacity benchmark.
There are no SQLite substitutes or populated example measurements.

## Safe offline commands

From the repository root:

```sh
.venv/bin/python .local-db/issue32-queued-load/load.py
.venv/bin/python .local-db/issue32-queued-load/load.py check-source
```

Default invocation runs stdlib unittest only; importing `load.py` does not import
psycopg, contact Docker, read a connection file or open a database. `check-source`
only reads published manifest/source checksums. Missing/unpublished/drifting
`v2:0025`, `v2:0026` or `v2:0027` is an explicit NOT_RUN refusal. The database must
also pass the repository's current full manifest/history validator with the chain
APPLIED; merely adding SQL files is insufficient.

## Parent-owned fixture preparation (not implemented here)

Do **not** run init, fresh, reset, restore, seed_core, DROP, TRUNCATE, migrations,
erasure cleanup or fixture deletion to use this harness. Parent owns additive
fixture population and must preserve all existing data and migration/erasure
ledgers. Reuse dedicated precreated synthetic child/device enrollments with valid
active keys, credentials, CORE and LOCATION authority/consent, and enabled
collection policies. Use 108 distinct children/devices for the default run; child
aliases must start with lowercase `synthetic`. No real child identifiers or GPS.

Parent supplies an owner-readable-only regular JSON file (0600, no symlink, at
most 1 MiB) at `.local-db/issue32-queued-load/fixture.private.json`. It is never
printed or copied into reports. Its exact keys are:

- `synthetic_only`: literal true, explicit operator attestation.
- `runtime_dsn`: explicit libpq DSN, user `madalasa_dev`.
- `proof_dsn`: same endpoint/database, user `madalasa_migrator`, used only with
  `default_transaction_read_only=on`. It reads migration/fixture proof; it uses
  `SET LOCAL ROLE ap_db_executor` for RLS-protected inspection, never ingestion.
- `device_guc`: exactly `ap.device_credential_sha256`, as implemented by actual
  migration 0027 and `backend/src/device_auth.h` (not an invented UUID selector).
- `devices`: exactly `--clients` objects, each containing only canonical UUID
  strings `device_id`, `child_id`, a precreated synthetic bearer string
  `credential`, and a positive integer `sequence_start` above the existing device
  dedup maximum. Parent must exclusively reserve these device sequence ranges.

DSNs must explicitly specify numeric loopback host (`127.0.0.1` or `::1`), port
15432/15433/15434, database `madalasa_alarka_test`, exact user and password.
An optional hostaddr must equal host. Only sslmode disable/require is allowed.
No inherited PG* variables, services, passfiles, arbitrary connection options,
dev database, remote target or unspecified endpoint is accepted. No config file
from other test runners is silently loaded. Proof and runtime DSNs must identify
the same endpoint. The provided passwords/bearers/digests are never logged.

Docker ownership is independently checked using selected non-secret inspect
fields: known container name, running state, synthetic label, this checkout's
root label or exact pgdata mount, and only loopback bindings to the selected port.
The repository's actual `manage.validate_target` guard is also applied. Port
15434 automatically selects the existing isolated PR11 path rule in-process.
The CI bypass is intentionally unsupported. No Config.Env inspection occurs.

Each transaction clears `ap.session_token`, hashes the supplied bearer to 64
lowercase hex characters, binds that digest transaction-locally to the **actual
0027 GUC**, and requires ctx_device to match the intended device and ctx_principal
to be null. Preflight resolves every credential and tests a deliberately invalid
credential. There is no issuer/session mint fallback. The write uses the actual
0026 `ingest_location_batch_receipt` contract and checks the fresh-batch receipt.

## Authorized real run — NOT executed here

Only after parent validates the published 0025..0027 chain, prepares the private
fixture non-destructively, and explicitly authorizes append-only synthetic load:

```sh
.venv/bin/python .local-db/issue32-queued-load/load.py run \
  --fixture .local-db/issue32-queued-load/fixture.private.json \
  --container madalasa-pr11-test-postgres \
  --confirm SYNTHETIC_APPEND_ONLY \
  --clients 108 --pool 8 --ramp 1,8,32,108 \
  --batches-per-device 10 --batch-size 1 --interval-ms 100 \
  --max-seconds 120 \
  --output .local-db/issue32-queued-load/metrics.actual.json
```

This exact command assumes the private input targets the checkout-owned PR11
container on 15434. For the original checkout-owned database, explicitly choose
`madalasa-local-postgres` and its matching 15432/15433 private DSNs instead; do not
silently fall back. Reruns require a new output filename and fresh exclusively
reserved sequence ranges from parent. Existing output is never overwritten.

## Bounds and meaning of metrics

- Maximum 108 logical clients, 16 PostgreSQL pool connections, 8 strictly increasing
  concurrency stages, 100 batches/device/stage, 500 events/batch, 100000 total
  events. Pool connections are reused but transaction-local identities are not.
- Each stage schedules all logical devices through at most its configured number
  of executor workers. Each logical device sends its bounded batch count at the
  configured interval. This is a closed-loop bounded workload, **not** an open-loop
  fixed-QPS saturation claim. Per-device work is never concurrently duplicated.
- Global load scheduling budget at most 300 seconds, default 120. Setup, telemetry,
  draining in-flight SQL, and final readback add overhead. Deadline is not an
  operating-system hard kill. Connection timeout 5s, SQL timeout 3s, lock timeout
  1s, pool acquisition at most 5s, TCP user timeout 5s. No automatic retry storm.
- All generated events use invented coordinates (0.125, 0.25), provider SYNTHETIC,
  fresh event/batch UUIDs, current time minus two seconds, and reserved sequences.
  Raw coordinates/events, UUIDs, credentials and DSNs never appear in reports.
- Latency p50/p95/p99 uses linear interpolation at rank `(n-1)*p/100`, with null
  for no observations. Attempt latency includes pool wait, bind, database work,
  commit/rollback; success latency excludes failed attempts. Transaction latency
  begins after acquisition. Executor admission wait is reported separately.
  There is no load warmup subtraction. Throughput is successfully committed
  batches/events divided by actual stage wall time, including pacing/drain.
- Error counters are SQLSTATE or exception-class names only; messages/SQL
  parameters are suppressed. Successful transaction acknowledgements are followed
  by read-only count/item-count readback of exactly this run's private batch IDs
  after pool closure. Those IDs are removed before report serialization.
- Generator CPU is actual process CPU time per stage; RSS is process-lifetime
  peak, not a stage-specific peak. Container CPU is cgroup-v2 cumulative usage,
  reported as endpoint delta and percent of one core (can exceed 100%). Container
  memory and PostgreSQL PID1 RSS are endpoint observations, not aggregate DB RSS
  peaks. Missing cgroup counters are NOT_RUN, never filled with zeros.
- Container network bytes sum interfaces including loopback, are container-wide,
  and include control/telemetry or unrelated traffic; they are **not** precise
  application payload bytes or per-process attribution. CPU/network snapshots
  bracket each stage but include sampler overhead. Use an otherwise idle dedicated
  target and record that environment when interpreting results.
- Environment records checkout SHA, tracked diff digest, harness digest, Python,
  psycopg, kernel/platform, CPU model/count/affinity, host RAM, image/content ID,
  container CPU/RAM limits, PostgreSQL/PostGIS versions, relevant DB settings,
  and migration checksums. No secrets or container environment variables.
- JSON output is 0600, new-file only, restricted to this queued directory.
  `metrics-dashboard.template.json` maps aggregate metric paths to panel labels;
  it has null/empty measurements and is not a deployed dashboard.

Exit codes: 0 = selftests/source check successful or complete synthetic-only
measurement; 1 = selftest failure or partial synthetic run; 2 = refused/aborted
run or absent source chain. A refusal/abort is not evidence of rollback of earlier
committed synthetic batches. Preserve them and allocate new sequence ranges; never
reset the database to obtain a prettier run.

**Physical Android battery: NOT_RUN. Target-environment device capacity: NOT_RUN.**
FF07 remains queued; no task/release/capacity completion claim is made.
