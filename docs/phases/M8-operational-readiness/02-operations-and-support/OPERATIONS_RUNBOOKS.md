# Operations Runbooks — Deploy, Rollback, Restore, Ingest Recovery

> **Document control:** M8 / 02-operations-and-support · Proposed owner: SRE + incident lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Status:** PROPOSED / NOT EXECUTED. No production OCI VM, C++ Drogon executable, APK or restored PostGIS database exists in this repository as verified on 2026-10-27. The instructions below are a design; run command examples only against an authorized, synthetic staging environment.

## 1. Pre-deployment gate
- Owner-approved hosting region (historical OCI Chicago vs candidate India still unresolved), controller/processor contract and Indian ICT-log residence.
- Named on-call and backup, secured OCI tenancy, restricted SSH/IAM, encryption, TLS, DB roles and forced child RLS.
- Tested complete off-host backup with RPO/RTO evidence, server monitoring and rotation procedures.
- Signed reproducible release artifact/SBOM, Git commit, API compatibility and migration status; India children's data/Play gates approved **before actual child telemetry**.
- Current M1 CI only checks JSON/OpenAPI structural contract and PostgreSQL 16 SQL tenant tests; it cannot certify any production backend or Android build.

## 2. Proposed deploy sequence
1. Record release id/commit/config fingerprint and approved scope; put the old release in an isolated rollback slot.
2. Take and VERIFY recoverable encrypted off-host backup; ensure backup region is authorized and restore-tested.
3. Run forward-only Postgres expand-compatible migration using migration role, **never** API superuser. Enforce RLS and negative child-scope checks. Do not use real children as fixtures.
4. Deploy signed Drogon/worker artifacts with least-privilege DB roles and secrets from private manager; verify health, auth denial and zero-PII logs.
5. If future batch inbox exists: pause intake or maintain compatible inbox schema, ensure pending/leased queue rows recover safely and no early HTTP 202 before Tx A commit.
6. Smoke test synthetic device handshake, one GPS queued 202, one worker Tx B raw+dedup+outbox commit, one trip projection, wrong-family denial, admin case scope and metrics.
7. Enable feature flags **only for allowed release cohort**; monitor error rates and rollback thresholds; reapprove further rollout.

## 3. Rollback
- Disable recently introduced capability/route first, never silently drop unsent Alarka GPS batches. Block unsafe API read/command path.
- Restore previous compatible application binary/config; preserve durable inbox Tx A rows and raw Tx B committals.
- Migration rollback is **not automatically safe**: prefer expand/contract and forward-fix. Do not run `DROP` against active child data.
- If token/permission issue, revoke grant/credential generations and block offline 48h replay. Revalidate RLS, pending leases, stale parent cache and outbox. Record evidence, owner and follow-up incident.

## 4. Backup and restore
- Data stores: M1 identity/child grants, later raw PostGIS location, temporary PostgreSQL ingest inbox, dedup/outbox, app usage, admin audit, payments and encryption-key metadata. Include backup/WAL/archive and secrets recovery separately.
- Prefer off-host encrypted backups, separately controlled credentials, PITR where justified and independent retention; same single VM backup alone is not resilience.
- On restore to isolated network: verify archive hash, DB engine/extensions, schema migration, post-restore RLS, canonical child scopes, encrypted secrets, and restore-point exact `received_at`/GPS ACK history. Apply current deletion tombstones and revoked enrollment generations **before** serving restored data.
- Actual `pg_dump`/restore commands for synthetic M1 test can be adapted from:
  `pg_dump -Fc --no-owner -f synthetic.dump amar_pola_m1`
  `createdb synthetic_restore`
  `pg_restore --no-owner --exit-on-error -d synthetic_restore synthetic.dump`
  Run in secure disposable environment; do not upload dumps to GitHub/CI and do not interpret logical backup as PITR.
- Document RPO (latest durable committed data lost) and RTO (time until authorized usable service, not VM boot); evidence template in BACKUP_RESTORE_TEST_EVIDENCE.md.

## 5. GPS inbox / worker backlog incident
- Observe oldest pending age, bytes, WAL free disk, lease expirations, quarantined records and parent latest location time. **A 202 only means committed inbox receipt; raw/trip work may lag.**
- If disk/worker overloaded, return 429/503 + Retry-After, preserve local child unacked batches, and slow uploader with jitter. Do not add Redis as unreviewed sole durability layer.
- Recover expired leases with fencing, then repopulate raw+dedup+outbox+processed atomically. Never reset dedup blindly or clear accepted inbox without proof of durable processing.
- Late 48-hour GPS backfill must be replayed by observation time; parent history marks gaps/late synchronization. Device deleted/revoked generation must not reintroduce child data.
- Quarantine malformed/poison batches and page security/support, do not expose raw coordinate payload to general admin dashboards.

## 6. Monitor and escalation
- Use MONITORING_ALERTING_SLO_SLA.md and SUPPORT_AND_ESCALATION_SOP.md.
- Confirm incident severity and CERT-In / future DPDP breach-clock applicability with India legal lead immediately.
- Record UTC+IST timestamps and links to secured synthetic drill evidence only, not real child data.

**Owner requirements before production:** assign duty rota, validate actual infrastructure commands, backup offsite keys, perform drill, approve policies. This file is not a deployment record.
