# MA-INGEST-ADR-004 — Adaptive GPS, 48-hour Alarka Offline Buffer, PostgreSQL Durable Inbox and C++ Bulk Inserts

> **Document control:** M2 / 01-location-collection-and-ingestion · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Date:** 2026-10-27. **Owner decision:** ACCEPTED AS ENGINEERING DESIGN.  
**State:** DESIGNED / NOT IMPLEMENTED / NOT MIGRATED / NOT LOAD-TESTED / NOT LEGALLY OR PLAY APPROVED.  
**Apps:** Madalasa parent; Alarka child Android/Wear OS when supported. **Backend:** C++20 Drogon, PostgreSQL/PostGIS, native C++ workers.  
**Related:** [Adaptive Movement Architecture](ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md), [Android runtime](TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md), [Data/authorization](../../M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md), [SRS](../../M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md), [whole-project API](../../../openapi.yaml).  
**Editable architecture:** [Figma HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-2), [Figma LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-60), [performance/trade-off design](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-126).

## 1. Owner-accepted implementation direction

1. Separate **GPS observation collection**, **encrypted local persistence**, and **network uploading**. Alarka should use low-power/passive/balanced/adaptive location and save every accepted observation to its bounded encrypted local queue before considering transmission. It should **target** an upload of accumulated JSON observations every **1–2 minutes only while an Android-authorized execution context and network permit**. Do not promise a 1–2 minute timer through WorkManager periodic tasks (minimum 15 minutes, subject to Doze and restrictions). The main Alarka Activity may close; any valid location foreground service and required visible notice follow Android rules.
2. Design an **up-to-48-hour offline observation buffer** on the child phone/watch with capacity monitoring and explicit failure/overflow policy. This is a storage **capacity target**, not a promise to collect GPS while powered off, force-stopped, without permission/provider fix, or after storage exhaustion. Actual retained history, local deletion and overflow behavior must respect user/legal retention decision. Store observation timestamp at capture time; never relabel historical fixes as fresh when uploaded later.
3. Alarka sends **bounded compressed JSON batches** using stable UUID batch/event IDs, authenticated device identity, optional compact scaled-integer coordinate/time wire representation under an explicitly versioned schema; per-point accuracy/provider/source (and optional speed) stay per observation. Device/account identifiers are not trusted simply because they appear in JSON.
4. **Initial server buffering choice:** PostgreSQL durable **inbox**, not Redis. C++20 Drogon validates/authenticates a complete incoming batch, inserts one **durable inbox batch row** atomically (or returns an authenticated verified duplicate receipt), then returns HTTP **202 with receipt processing=QUEUED only AFTER the PostgreSQL transaction COMMIT**. No HTTP ACK when data is merely on a socket, in process memory or in an uncommitted transaction. The device may free the specifically ACKed local batch after verified durable receipt; pending/rejected/uncertain batches remain retryable. The explicit receipt means **durably accepted for processing**, not that final location rows or derived trips already exist.
5. **Independent C++ bulk workers** lease multiple inbox records with bounded PostgreSQL queue leases and \`FOR UPDATE SKIP LOCKED\`, combine their observations into an efficient batch, deduplicate using existing stable \`(device_id,event_id)\` + hash ledger, and atomically insert into final **time-partitioned location_observations** and a reconstruction outbox. Update inbox status to PROCESSED within the same commit as raw+dedup+outbox; lease expiry, worker crashes, repeated records and same-event-different-payload conflicts require safe recovery.
6. **Bulk insert mandatory:** benchmark multi-row prepared INSERT / \`INSERT ... SELECT\` first; optionally \`COPY FROM STDIN\` into **temporary/staging** tables followed by an indexed \`INSERT ... SELECT\` dedup transaction, never assume COPY alone handles \`ON CONFLICT\`. Adapt chunk sizes (candidate 100–500 observations/transaction), and avoid doing GPS trip reconstruction inside Drogon HTTP event loop threads. PostgreSQL inbox stores incoming batch **once per HTTP upload**, not one inbox row per GPS fix.
7. **Direct bulk INSERT alternative remains an explicit benchmark control:** same endpoint contract can instead commit raw observations + dedup + outbox **directly** in a single transaction and acknowledge only after this commit. It may use **fewer WAL bytes/disk writes** because inbox temporarily doubles data writing. Benchmark reliability, p95/p99 ACK, error isolation, disk/WAL, load bursts and peak parent read latency. Owner-accepted **default design** is inbox+bulk workers; do not silently claim it always uses fewer resources or flip deployment mode without evidenced architecture decision.
8. **Redis not a required MVP dependency.** Later evaluate Redis for *nonauthoritative* latest-state caching or a properly durable broker only after performance/HA evidence. A vanilla Redis memory-only XADD cannot replace GPS durability. Retain one authoritative Postgres source of truth.
9. **App usage:** apply the same secure device-local capture + bounded batch + durable server-processing principle but with a **separate usage event/session endpoint, schema and worker/aggregates**, not raw GPS indexes or assumptions that UsageStats provides real-time exact foreground app. No always-on wakeup merely to report package use. Local usage events/session intervals must be legally/Play authorized, event-time reconciled, de-duplicated and kept separately from current-last-observed foreground app.
10. **Parent map/history** reads committed last verified location, observed route/stop summaries and freshness/lag. Parent opening a history screen does **not** trigger fresh sensor collection. Authorized Live Tracking is separate, time-limited and Android-context dependent. Offline/buffered/unprocessed raw events are not fabricated into live markers. 48-hour delayed packets are reconstructed by **original observed_at**, with gaps, revision notices and source device provenance preserved.
11. **Child law/Play gate:** no real minor GPS-history or app-usage ingestion until specific Indian DPDP children’s restrictions, guardian authority, storage region, Google Play background location/monitoring/usage disclosures and deletion/retention obligations have been resolved. Proposed architecture is not legal approval.

## 2. HLD and data flow

~~~text
Alarka Android / supported Wear OS
   ├─ Fused/LocationManager callback → eligible recorded GPS fix → encrypted local SQLite queue
   ├─ UsageStats authorized event/session adapter → separate encrypted usage queue
   └─ upload coalescer: device-verified 1–2min target where permitted, payload caps, retry/backoff/jitter
        ↓ HTTPS: POST /devices/{deviceId}/locations:batch (existing whole-project draft)
C++ Drogon API: auth device/tenant/child; validate ids/schema/positions/clocks/rate; bounded payload
        ↓ TX A: INSERT verified batch into PostgreSQL location_ingest_inbox; unique(device_id,batch_id)
        ↓ COMMIT
HTTP 202 processing=QUEUED  →  Alarka durably marks only accepted batch as ACKed; retry on ambiguity
        ↓
C++ inbox worker: short SKIP LOCKED claim + lease epoch; read multiple batches
        ↓ TX B: stage/multirow/COPY; dedup + raw partition INSERT + trip outbox + inbox PROCESSED
        ↓ COMMIT
PostgreSQL/PostGIS: location_observations + device_latest_location / reliable outbox
        ↓
Trip/stop/route worker (event-time; late offline backfill); separate usage aggregation worker
        ↓
Madalasa authorized child map/history and usage summary APIs; quality and last-verified timestamps
~~~

**Failure domains:** child queue protects device from intermittent connectivity; PostgreSQL inbox protects API from slow processing/worker downtime and gives a durable ACK boundary; Postgres transaction and dedup protect worker replay; outbox protects trip reconstruction after raw commit. Queueing does **not** create extra guaranteed GPS fixes on a device Android has stopped.

## 3. Suggested device and wire contract

Device storage uses an **actual encrypted local database** (e.g. audited SQLCipher or encrypted payload/envelope format with Android Keystore); Android default SQLite alone is **not** encrypted. Bounded by count, bytes, and approved retention, with crash-safe queue checkpoints. Mark each locally persisted record \`PENDING\`, \`IN_FLIGHT\`, \`DURABLE_ACKED\` or \`FAILED_POLICY\`; after an uncertain HTTP timeout, resend same stable batch_id/event_ids.

The **current whole-project public GPS OpenAPI** uses decimal \`latitude\`, \`longitude\`, RFC3339 \`observed_at\`. Keep it compatible. A future **explicit v2 compact transport profile** may support \`lat_e6\`, \`lon_e6\` int and \`t_ms\` Unix milliseconds, because these are unambiguous at negotiated schema version. Do **not** mix both representations without a schema discriminator or silently break M1/clients. Receiver always normalizes to canonical UTC/geospatial observations.

~~~json
{
  "batch_id": "f842e1ec-8d2b-4d66-aaf8-e1cc25d792ed",
  "events": [
    {
      "event_id": "6ea44448-97bd-44b8-ab13-5d775c8a50af",
      "observed_at": "2026-10-27T07:24:30Z",
      "latitude": 26.7123,
      "longitude": 88.4251,
      "accuracy_m": 12,
      "speed_mps": 8.2
    }
  ]
}
~~~

Per batch: device-authenticated, stable batch_id; per fix: stable event_id, observed_at, valid lat/lon, accuracy, optionally speed, source_device_id/provider and tracking mode. Limits candidate **100–500 observations plus strict compressed/uncompressed byte/decompression ratio caps**; use gzip only when it reduces bytes. Raw events remain correlated to original device even if one child carries a watch and phone. Reject precision/future timestamp cheats and duplicates with mismatched hashes.

**Device upload scheduling:** an eligible already-operating service may coalesce for 1–2 minutes; WorkManager can perform less frequent opportunistic fallback uploads (15min+ periodic floor). Do not use alarm abuse, wake locks or hidden OS behavior to force a timer. FGS cannot be started from every background state. Offline after 48h: retain bounded storage until policy-defined limit, degrade sampling if appropriate and clearly signal **UNSYNCED_HISTORY_AT_RISK** before any legal, explicit purge; no unbounded retry/backfill under data quota.

## 4. Durability and exact API receipt semantics

**Tx A (API):** verify authenticated device+child+grant and batch limits; canonical payload digest and event validation; \`INSERT location_ingest_inbox (device_id,batch_id,digest,payload,accepted_count,received_at,status='PENDING')\` with uniqueness. A repeated exact batch can receive the same receipt; same ID/different digest yields **409/CONFLICT**. Reject invalid coordinates before a successful receipt (or provide explicit per-event accepted/rejected counts and stable event errors; client must not delete rejected observations as if persisted). On a successful committed inbox row, return **202 {batch_id, accepted_count, duplicate_count, rejected_count, processing:'QUEUED'}**. For a duplicate fully durable inbox batch, return idempotent receipt. A 202 is NOT a final GPS table insert, map update, trip completion or promise of immediate user visibility.

**Tx B (worker):** claim and validate a bounded set of committed inbox rows; transform and merge GPS points; insert *new* event identities and data into dedup and partitioned raw tables; append/coalesce reconstruction outbox for affected device/event-time intervals; conditionally mark each inbox row PROCESSED. Keep those operations **in one DB transaction**, fencing stale leases. Crash before commit: nothing should be marked processed; claim again. Crash after commit: reprocessing must be idempotent. Do not hold queue row locks while doing slow CPU parsing; acquire short lease, then fence before commit. Server can apply 429/503 with Retry-After when queue storage/quota constrained, and child retains unsent queue.

**Explicit states**:
- Device: PENDING_LOCAL → IN_FLIGHT → DURABLE_ACKED; uncertain timeout → retry same IDs.
- Inbox: PENDING → LEASED → PROCESSED; on failure FAILED_RETRYABLE / QUARANTINED / DEAD_LETTER_PENDING_REVIEW (never silently discard accepted GPS before recovery/deletion policy).
- Location read: durable inbox queued ≠ raw committed ≠ routes reconstructed. Madalasa exposes last_location_observed_at, last_ingested_at and last_trip_processed_at separately with quality, never pretends the queue is a live path.

## 5. Conceptual PostgreSQL schema / migration design (NOT EXECUTED)

~~~sql
-- Concept only: adapt existing family/device FKs, UUIDs, RLS and partition strategy.
CREATE TABLE location_ingest_inbox (
  device_id UUID NOT NULL,
  batch_id UUID NOT NULL,
  family_id UUID NOT NULL,
  payload_digest BYTEA NOT NULL,
  payload JSONB NOT NULL,                 -- encrypted disk/backup controls; temporary GPS content
  event_count INTEGER NOT NULL CHECK (event_count BETWEEN 1 AND 500),
  status TEXT NOT NULL CHECK (status IN
    ('PENDING','LEASED','PROCESSED','FAILED_RETRYABLE','QUARANTINED')),
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  lease_owner TEXT,
  lease_epoch BIGINT NOT NULL DEFAULT 0,
  lease_expires_at TIMESTAMPTZ,
  attempts INTEGER NOT NULL DEFAULT 0,
  processed_at TIMESTAMPTZ,
  PRIMARY KEY (device_id,batch_id)
);
CREATE INDEX inbox_pending_lease_idx ON location_ingest_inbox
  (status, lease_expires_at, received_at);

-- Claim in a small transaction. Lease condition must be guarded against concurrent workers:
WITH chosen AS (
  SELECT device_id, batch_id
  FROM location_ingest_inbox
  WHERE status IN ('PENDING','FAILED_RETRYABLE')
     OR (status = 'LEASED' AND lease_expires_at < now())
  ORDER BY received_at,device_id,batch_id
  FOR UPDATE SKIP LOCKED
  LIMIT 40
)
UPDATE location_ingest_inbox i
SET status='LEASED', lease_owner=:worker_id,
    lease_epoch=i.lease_epoch+1,
    lease_expires_at=now()+interval '60 seconds',
    attempts=i.attempts+1
FROM chosen c
WHERE i.device_id=c.device_id AND i.batch_id=c.batch_id
RETURNING i.device_id,i.batch_id,i.lease_epoch,i.payload;
~~~

**Important production caveat:** This is a logical illustration. Real DDL must ensure proper FK+RLS, canonical normalized device identity, rejection of old revoked generations, timestamp/sentinel rules, scheduled partition creation for raw GPS, packet-size protection, dead letter recovery, and short retention of PROCESSED inbox payloads. Use \`FOR UPDATE SKIP LOCKED\` only for queue-claim work, not general-consistency reads. Claim fairness across tenants/devices. On worker completion, lock/check \`lease_epoch\` and \`lease_owner\` inside Tx B before committing to prevent stale workers from confirming an old lease.

**Bulk pattern:** Build bounded collection of raw observations from 1–N inbox batches. For modest loads, use parameterized multirow prepared insert or JSON-to-recordset and \`INSERT ... SELECT\` plus dedup. Benchmark \`COPY FROM STDIN\` to **temporary staging**, followed by \`INSERT ... SELECT\` into time-partitioned canonical raw with stable dedup. COPY does not directly offer the desired ON CONFLICT clause on the raw target. Avoid per-observation DB commits and 500-inbox-row locks for 500 GPS fixes.

**Dedup ledger:** Existing \`device_event_dedup (device_id,event_id,digest)\` remains authoritative across time partitions and retries. The partitioned raw primary key must include observed_at, so don't assume \`event_id\` globally unique by itself. Conflict with same event ID and different digest is quarantined/flagged; same digest replay is ignored. Event-time range and grant/retention checks apply equally to late 48-hour backfill. Tombstones prevent reingest after family/device deletion or revoke.

## 6. Option B: direct durable bulk insert (required benchmark, not default)

~~~text
Drogon receives device JSON batch
   → validate and auth
   → single DB transaction: dedup ledger + multirow raw INSERT + reconstruction outbox
   → COMMIT
   → durable API receipt to device
~~~

Option B can have lower WAL/disk I/O and no inbox payload duplication. But heavy partition/index locks and reconnect burst processing land on API request latency, creating resource contention. Test Option A vs B with identical payloads/device scales and failure injections, then present concrete resource/availability evidence before a final deployment switch. Do not add Redis or claim lower system resources based on anecdote.

## 7. Service limits, monitoring and operations

Initial *experiment* targets, to be tuned by tests:

| Parameter | Candidate (not guarantee) |
|---|---|
| GPS recording | adaptive to movement/speed/accuracy and Android power state; temporary Live Mode separately |
| Upload while allowed | 1–2 min target; batch by event count/time/bytes |
| Offline local queue | Up to 48-hour design capacity and explicit storage overflow policy |
| HTTP batch limit | 100–500 GPS points, plus strict bytes/decompression limits |
| Worker bulk transaction | 100–500 canonical points; dynamic based on DB transaction latency |
| Worker concurrency | 1–2 on tiny OCI instance, adjust with Postgres connection/WAL measurements |
| Durable server inbox | One row per authenticated JSON batch; no Redis required |
| Source truth | Event-time UTC; original device per child, watch/phone separate |
| Success | 202 after inbox commit; final table and trip processing async |

Metrics: queued inbox batches/bytes; oldest queued age; worker lease expiry and retries; dead-letter pending; batch 202 latency p50/p95/p99; response duplicates/conflicts; raw points/s; dedup/reject counts; WAL MB/s; Postgres CPU/connection/disk/IOPS; read query p95; GPS current/received/processed timestamp gap; device queue nearing 48h or capacity. Backpressure before full disk; data must not disappear after API confirms durability.

**Cost warning:** inbox **increases write amplification** because GPS content is temporarily stored twice. Use cleanup, partition management, correct WAL/backup estimates. At 10k/100k devices test morning commute sync skew, full 48h reconnect storms, watch+phone streams, weak network, worker halted, DB restarted and reconnection burst. No benchmark has run; old 300 observations/child/day figure was a pricing scenario, not a cap on moving children.

## 8. New acceptance tests (NOT IMPLEMENTED / NOT RUN)

- T-ING-01 adaptive GPS fix timestamps, independent network upload and no generated points in blocked states.
- T-ING-02 1–2min eligible upload and 15min+ WorkManager fallback; Android background/FGS restriction evidence.
- T-ING-03 48h offline buffer capacity at walking/vehicle rates; no queue loss on process/app restart, stable IDs.
- T-ING-04 local queue encrypted at rest with Android Keystore, tamper/replay handling.
- T-ING-05 exactly one durable Postgres inbox row per accepted batch and byte/event limit enforcement.
- T-ING-06 HTTP timeout after Tx A commit; retry batch ID returns same logical receipt.
- T-ING-07 API crash before Tx A commit must not return 202 or trigger local deletion.
- T-ING-08 lease SKIP LOCKED concurrency; concurrent workers do not silently double-commit.
- T-ING-09 worker crash before Tx B commit: raw+dedup+outbox rollback, inbox retryable.
- T-ING-10 worker crash after Tx B commit: idempotent replay, no double raw GPS/trip job.
- T-ING-11 stale lease fencing, invalid batch quarantine, reasoned dead-letter recovery.
- T-ING-12 prepared multirow vs COPY-stage inserts; accuracy and precision unchanged after normalization.
- T-ING-13 same event ID/different data conflict; audit and quarantine without overwriting raw history.
- T-ING-14 per-child/device/family RLS and revoked/deleted token preventing offline reingest.
- T-ING-15 long backlog event-time trip backfill, no fabricated straight road route, gap/revision UI.
- T-ING-16 usage events separate table, device and privilege scopes, event-time sessions not instant truth.
- T-ING-17 1k/10k/100k synthetic device load, normal cadence and 48h simultaneous reconnect storms.
- T-ING-18 compare Inbox+Bulk vs Direct+Bulk under same p95/p99 ACK, CPU, RAM, WAL, DB IOPS, loss/recovery.
- T-ING-19 429/503 backpressure + Retry-After + client jitter, no permanent disappearance.
- T-ING-20 Postgres disk quota, inbox cleanup, retention/purge, backups and failover restoration.
- T-ING-21 watch + phone separate source streams and proper per-device event dedup and source selection.
- T-ING-22 parent reads committed latest/history, not in-flight inbox, correct freshness and offline timestamps.
- T-ING-23 legal/Play child-location and usage data gates block real-minor collection in unreleased build.
- T-ING-24 verify no Redis dependency for phase-one cold start / full worker recovery, and safe future optional cache.

**All T-ING-01…24 status: PLANNED / NOT_IMPLEMENTED / NOT_TESTED.** Record OS/OEM/build, FGS eligibility, timestamp quality, Postgres commit mode, transactions, random seed/payload, 48h simulated clock and resource measurements.

## 9. References

- PostgreSQL SELECT … FOR UPDATE SKIP LOCKED: https://www.postgresql.org/docs/current/sql-select.html
- PostgreSQL COPY and binary/text bulk ingest: https://www.postgresql.org/docs/current/sql-copy.html
- PostgreSQL INSERT ON CONFLICT: https://www.postgresql.org/docs/current/sql-insert.html
- PostgreSQL partitioning: https://www.postgresql.org/docs/current/ddl-partitioning.html
- Android background-location limits: https://developer.android.com/about/versions/oreo/background-location-limits
- Android WorkManager minimum periodic interval: https://developer.android.com/reference/androidx/work/PeriodicWorkRequest
- Android foreground service background start: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start

**No migration, Android code, Drogon worker, performance result, India legal approval, Google Play approval or production rollout was performed by creating this document.**
