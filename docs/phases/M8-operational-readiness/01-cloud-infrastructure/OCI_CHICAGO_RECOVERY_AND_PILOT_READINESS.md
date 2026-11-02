# Madalasa–Alarka — OCI Chicago Recovery, Backup and Pilot Readiness

> **Document control:** M8 / 01-cloud-infrastructure · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (guardian/parent), **Alarka** (child companion). GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka), renamed 2026-10-26. [Source story and naming contract](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Status:** Architecture decisions and test gates; no OCI tenancy, backup or failover has been deployed.  
**Reviewed:** 2026-10-26 | **Authority:** [OCI infrastructure plan](OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md), [security operations](../02-operations-and-support/SECURITY_AND_OPERATIONS.md), [data-erasure contract](../../M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md).

## 1. Single-VM risk is explicit

Current selected **single Ampere A1 VM** in Chicago may run PostgreSQL/PostGIS, HTTPS API and C++ workers in separate processes, but they **share the same failure domain**. Hardware loss, Oracle reclaiming Always Free resources, disk corruption, mistaken update, network interruption and security compromise can simultaneously remove current location, SOS ingestion, messages and history. A second systemd worker **is not high availability**; neither is a nightly backup. Do not market uninterrupted location or life-safety dispatch from this shape.

## 2. Candidate service tiers and objective definitions

- **RPO:** maximum time window of committed data that recovery may lose, measured from the moment of outage/last durable off-host copy; not the child's phone offline queue age.
- **RTO:** elapsed time from declared outage to a restored, authorized, functional API/DB at a known verified recovery point; not merely the time to start an empty VM.
- **Availability:** user-visible API/parent reads, child ingestion and SOS must be measured **separately**.

| Service tier | RPO *engineering target* | RTO *engineering target* | Technology and posture | Approval status |
|---|---|---|---|---|
| Internal development / synthetic data | 24 hours | 48 hours | Daily encrypted off-host backup, scripted rebuild and restore | **Proposed only; untested** |
| Limited approved non-emergency pilot with real children's data | ≤4 hours | ≤12 hours | Backups more frequent than once daily + safe off-host WAL/archive; tested private restore with current ACL/tombstones; availability disclosed | **NOT POSSIBLE TO CLAIM ON CURRENT UNTESTED BASELINE** |
| Paid production location service | Candidate ≤1 hour | Candidate ≤4 hours | Multi-domain deploy, independent standby/restore path, monitored replication or PITR; operations/on-call and funds | **UNFUNDED / NOT VALIDATED** |
| Any “guaranteed emergency SOS” product | Requires separate end-to-end acknowledgement and alternate ingress channel goals | Requires independently verified fallback path | Separate delivery plane and failover; see SOS design | **DO NOT OFFER** |

These are **engineering target proposals**, not contractual SLA, system uptime claims or evidence of actual performance. User must approve acceptable data loss and recovery, and tests must demonstrate them with representative volume. If cannot fund real-child pilot RPO/RTO, use **synthetic-only development** rather than quietly lowering promises.

## 3. Recovery reference architecture

**Dev (no minors)**:
- Oracle region Chicago target; eligible VM may run API, C++ workers and local PostgreSQL with private DB socket.
- Encrypted database logical backup on a protected schedule to **separate Object Storage**, separately encrypted and access-limited; backup alone not enough unless remote full restore succeeds and manifests survive VM loss.
- Test a full restore into clean, isolated VM; validate SQL migration version, two-family ACL, child-grant revocation and tombstone erasure after restoration.

**For real-data limited pilot if counsel approves**:
- Capture **recoverable** PostgreSQL base backups + archived WAL to off-host durable storage, with controlled retention, encryption and key rotation (PITR design). When using pg_basebackup or WAL-G/pgBackRest, make a documented tested ARM64 script/systemd unit, not “backups enabled” checkbox.
- Enable append-only deletion tombstone/erasure manifest and replay after restore to prevent deleted child events from reappearing; do not rely on a backup older than legal requests.
- Use separate least privilege operator service accounts, protected keys and an on-call contact; identify if OCI Always Free reclamation requires rebuilding in another available AD, another capacity type or account billing change.
- Recovery tooling tested independently from single VM's credentials and disk. Place secrets in protected off-machine vault, not just on the lost boot drive.
- Application status: STALE_LAST_KNOWN, SERVER_UNAVAILABLE, RECOVERING; don't show a backed-up prior position as current.

**For commercial service**:
- Choose architecture and pay for **independent failure domains**: more than one API ingress target, event acceptance/failover strategy, WAL shipping plus warm restore or replication/failover database, outbox/worker fencing and global auth/grant consistency.
- A load balancer on two API VMs with one PostgreSQL node is **not HA**; primary-DB failover must handle exactly-once ingest and no double-issued SOS.
- Independently test resync of offline Android queues after restored DB, dedup ledger persistence and notification idempotency.

## 4. Backup/restore checklist with measurable evidence

| Test | Fault or drill | Completion evidence |
|---|---|---|
| DR-01 | Destroy/disable primary VM after ingest committed | Timestamp of last recovered observation, measured RPO/RTO, incident report |
| DR-02 | Delete/rebuild PostgreSQL host while preserving external backups | Automated restore, schema/extension versions, secrets/key access, geospatial indexes |
| DR-03 | Crash API between DB COMMIT and HTTP 202 | Stable device event UUID dedupe after reconnect |
| DR-04 | Lose worker process during trip reconstruction | Monotonic lease fencing, bounded catch-up, no duplicate derived stop |
| DR-05 | Delete family then restore older backup | Tombstone reconciliation, no resurrected child/guardian records |
| DR-06 | Restore while parent SSE and client retries reconnect | Multi-tenant reads correctly reauthorize; stale sessions revoked |
| DR-07 | Off-site bucket unavailable or backup corrupt | Alert, documented rollback and honest service unavailable |
| DR-08 | Out-of-capacity A1 after primary loss | Real alternate capacity allocation/paid contingency and incident recovery elapsed |
| DR-09 | Delete/recover key material per rotation plan | Data protection and verified decrypt/no secrets in repo |
| DR-10 | OCI billing overrun or disk quota exhausted | Graceful ingest backpressure, no partial acceptance acknowledgement; budget alarms |

## 5. Budget and procurement blockers

- **DR-B01:** Owner approval of real-child pilot and paid-production RPO/RTO, including offline and SOS expectations.
- **DR-B02:** OCI credentials/account shape/quota access and actual second failure-domain hardware availability.
- **DR-B03:** Measured data change rate, retention and archive object size at representative child cadence; true annual storage/egress costs.
- **DR-B04:** Actual encryption, WAL/archive, full restore runbook and completed clocked failure drill.
- **DR-B05:** Funded standby/backup processing, independent monitoring and escalation on-call (none priced by free-VM baseline).
- **DR-B06:** Legal approval for Chicago US transfer, backup retention, erasure manifest and service availability advertising.
- **DR-B07:** Reconcile budgeted guardian support/service hours and incident procedures with team capacity.

**Cost caution:** The ₹0.20 per-child monthly Oracle priced-line model and ₹38.86/year per-child hosting allocation at 1,000 child seats **are not commercial HA quotes**. Separate any disaster-recovery/production-availability spend from historical raw Free Tier infrastructure estimates.

## 6. Go/no-go milestones

- **M0/M1:** synthetic fixtures only; design and observe backup/restore tests. Do not link real minors before legal gates.
- **M2:** actual device location features require fully proven Android data-collection permissions, legal purpose-specific approval, minimum RPO/RTO tests, real hardware and authorized privacy policy. Otherwise run simulated GPS.
- **Private pilot:** signed operator/data controller, consent/authority, live encrypted backup with independently tested restore, incident owner, measured batch reliability and limitations communicated to guardians.
- **Paid India public release:** tested topology matching the promised level of service, production on-call, actual paid/HA budget if needed, verified legal/Play approvals, support links and deletion tooling.
