# Backup/Restore Test Evidence — TEMPLATE ONLY

> **Document control:** M8 / 02-operations-and-support · Proposed owner: SRE + incident lead (not assigned) · Registry: TEMPLATE_OR_EVIDENCE_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Status (2026-10-30):** production/off-host drill NOT_EXECUTED. No verified OCI deployment, independently secured off-host archive or production RPO/RTO demonstration exists. This template is *not* proof of such a test. Earlier synthetic PostgreSQL V2 restore checks exist only on the separate database branch, and the [local upload-key recovery drill](../../M1-secure-platform-foundation/03-security-and-permissions/MADALASA_UPLOAD_KEY_SETUP_2026-10-30.md) verified local decryption/private-key possession but remains blocked on independent custody. Neither substitutes for the exercise below. PR9 CI has no backup/recovery test.

## Required execution record

| Field | Fill on actual authorized synthetic test |
|---|---|
| Exercise ID / incident link | [NOT RUN] |
| Date, UTC start / UTC end / IST | [NOT RUN] |
| Operator, witness and approving security reviewer | [UNASSIGNED] |
| Commit/version/API/DB migration | [NOT RUN] |
| OCI region and off-host storage region | [UNDECIDED] |
| Postgres/PostGIS versions and data size | [NOT RECORDED] |
| Data classes: identity, inbox, dedup, raw GPS, routes, admin log | [SYNTHETIC ONLY] |
| Backup type, encrypted location, key owner, checksum | [NOT AVAILABLE] |
| Last committed inbox 202 timestamp & receipt | [NOT RECORDED] |
| Simulated fault and intended recovery point | [NOT RUN] |
| RPO target / actual seconds or minutes | [TARGET TBD / NOT MEASURED] |
| RTO target / actual seconds or minutes | [TARGET TBD / NOT MEASURED] |
| Integrity checksum / restored row counts / RLS negative result | [NOT TESTED] |
| Tombstone/revoke after restore / old 48h GPS replay blocked | [NOT TESTED] |
| Owner signoff, defects/issues and follow-up | [PENDING] |

## Drill steps
1. Isolate a synthetic environment. Seed two families, sibling non-granted child, synthetic GPS location inbox and dedup/outbox, representative usage event and deletion tombstone.
2. Prove app-role read/RLS denial before fault. Record a **durable** 202 receipt in Tx A but block worker Tx B; optionally commit another batch fully.
3. Make an encrypted, hashed **off-host** backup / WAL archive; document its completed time and verification.
4. Destroy or disconnect disposable primary; start a separate restore target and restore to selected point. Reapply deletion tombstones/credential revocations before opening API.
5. Verify postrestore counts, inbox statuses, dedup/replay, no duplicate raw GPS, no deleted child resurrection, outbox trip rebuild, role grants, child scope and legal retention rules. Never use real minors.
6. Measure from fault declaration to validated usable API/DB (RTO), and largest committed accepted data not recovered (RPO). **An inbox ACK is still a committed data obligation even if Tx B was pending.**
7. Validate encrypted backup integrity, secret rotation, monitoring, regional constraints and offsite independence.
8. Enter results exactly, attach restricted artifacts by URI/hash, obtain second-person security signoff, open issues for failures.

**Go/No-Go:** Before real-child pilot, owner signs thresholds, at least one successful restore + failed recovery tests, independent off-host location, retained logs and documented on-call responsibility. Nothing in this file can substitute for the exercise.
