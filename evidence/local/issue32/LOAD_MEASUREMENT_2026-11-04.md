# Issue #32 — synthetic ingestion load measurement

**Status:** MEASURED, synthetic-only, single deliberately capped instance.
**Not** a 108-device capacity certificate, not HTTP, not Android, not the target deployment.

## Reproduce

Source at `backend/tests/load/` (checkout `e8781e5`, harness commit `e84307e`).
Fixture is generated append-only by `backend/tests/load/make_fixture.py` into an
owner-only private file; the measurement below used 108 synthetic children/devices
under one synthetic family with `LOCAL_TEST_APPROVED` authority/consent (synthetic
opt-in, not legal approval).

```sh
.venv/bin/python backend/tests/load/load.py check-source
.venv/bin/python tools/database/manage.py reset      # disposable synthetic DB only
.venv/bin/python tools/database/manage.py migrate
.venv/bin/python backend/tests/load/make_fixture.py --devices 108 \
  --output .local-db/issue32-queued-load/fixture.private.json
.venv/bin/python backend/tests/load/load.py run \
  --fixture .local-db/issue32-queued-load/fixture.private.json \
  --container madalasa-memory-test-postgres \
  --confirm SYNTHETIC_APPEND_ONLY \
  --clients 108 --pool 8 --ramp 1,8,32,108 \
  --batches-per-device 3 --batch-size 1 --interval-ms 50 \
  --max-seconds 180 \
  --output .local-db/issue32-queued-load/metrics.actual.json
```

Exit 0; 11 harness self-tests pass offline (`backend/tests/load/test_load.py`).

## Environment actually measured

| Item | Value |
|---|---|
| Database | PostgreSQL 16.9, PostGIS 3.5.2, container `madalasa-memory-test-postgres` |
| Limits | 1.0 CPU (`NanoCpus=1e9`), 512 MiB RAM, tmpfs data, `fsync=on`, `synchronous_commit=on` |
| Settings | `max_connections=24`, `shared_buffers=32MB`, `work_mem=2MB` |
| Client | Python 3.12.3, psycopg 3.3.6, 40 logical host CPUs (single-host generator) |
| Interface | Direct SQL `ap_m1.ingest_location_batch_receipt` under the 0027 credential GUC — **not HTTP** |
| Workload | 108 logical clients, 8 pooled connections, ramp 1→8→32→108, 3 batches/device/stage |

## Results (stage with 108 concurrent clients)

| Metric | Value |
|---|---|
| Attempts / successes / errors | 324 / 324 / 0 |
| Committed batches | 38.88 per second |
| Committed events | 38.88 per second |
| Attempt latency p50 / p95 / p99 | 2642.7 / 2850.7 / 2944.8 ms |
| DB transaction p50 / p95 / p99 | 199.9 / 295.2 / 302.1 ms |
| Pool queue wait p50 / p95 | 2443.0 / 2653.4 ms (peak 100 waiters) |
| Container CPU | 8.36 s over 8.33 s wall ≈ 99.2 % of one core |
| Readback | 324 batches / 324 events verified for this run |
| Whole run | 1296 batches and 1296 observations persisted across 4 stages |

## Honest interpretation

- One vCPU saturated at ~39 batches/s. The dominant delay is **connection-pool
  queueing** (8 connections, 108 clients), not slow SQL (DB p50 ≈ 200 ms).
- This measures *concurrent connectivity and ingest throughput*, not the free-tier
  product cadence. A 108-device fleet at a 10–15 minute cadence needs roughly
  0.12–0.18 events/s aggregate, far below the measured ceiling; that arithmetic is
  a planning note, **not** a capacity certificate.
- Zero errors here says nothing about packet loss, background restrictions, retry
  storms, or multi-tenant abuse.
- **NOT RUN:** Android battery/background behaviour, physical devices, HTTP/WebSocket
  edge, worker drain of `ingestion_outbox`, network partition, N-host deployment,
  and the actual production VM. `108` remains a policy cap until those are measured.

## Residual risks

Tmpfs acceptance does not prove disk/reboot durability. Container CPU/network are
cgroup counters including harness overhead, not per-query attribution. The harness
refuses foreign containers, unspecified targets and ambient libpq settings; it never
substitutes synthetic numbers for measurements.
