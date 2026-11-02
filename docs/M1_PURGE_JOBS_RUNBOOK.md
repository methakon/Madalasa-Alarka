# M1 scheduled retention jobs: runbook

Status: **engineering baseline, tested against PostgreSQL 16, not deployed anywhere.** The repository has no environment
or infrastructure-as-code yet (hosting is still a decision), so nothing is scheduled until someone follows the install
steps below. Until then expired rows simply accumulate: harmless for correctness, but anonymous endpoints can grow the
challenge tables, so install the job before any non-synthetic exposure.

Files: `backend/scripts/run_purge.sh`, `backend/deploy/ma_purge_role.sql`, `backend/deploy/systemd/ma-purge.{service,timer}`,
tests `backend/tests/purge_job.sh` and `backend/tests/test_deploy_units.py`. The functions themselves are in migrations
historical0003/0004 with additive0006, tested by `m1_enrollment.sql` (EN_16 to EN_20), `m1_idempotency.sql` (ID_11), `m1_retention_holds.sql` and the concurrency suites.

## What runs and what it deletes
The undeployed timer is configured hourly. Two existing jobs always run; pairing cleanup is additionally enabled only when `MA_PURGE_PAIRING_GRACE` is explicitly configured. There is no implicit pairing grace or claim that it is legally approved. The script exits non-zero if an enabled job fails.

| Function | Deletes | Default grace | Floor (the database refuses less) |
|---|---|---|---|
| `purge_credential_artifacts` | device credentials, after expiry or revocation | 30 days | 1 day |
| | single-use renewal challenges | 1 day | 1 hour |
| | expired enrollment challenges for all device states, including completed ACTIVE/REVOKED enrollment; old abandoned PENDING_PROOF devices only without any FK reference | 7 days | 1 day |
| `purge_idempotency_keys` | idempotency keys, after they expired (keys live 24 h) | 1 hour | 1 minute |
| `purge_pairing_codes` | expired consumed or unconsumed pairing codes, excluding held codes | none; explicit `MA_PURGE_PAIRING_GRACE` required | 1 day |

Held artifacts and device-held artifacts are retained. Active devices, families, children, grants, audit events, key history and revocation epochs are never deleted by these functions. Every direct device FK blocks abandoned-device deletion; evidence is not deleted to remove blockers. Hashes linked to device/child/family IDs are not automatically anonymous. These are synthetic engineering values, not an approved legal retention schedule. Idempotency keys retain their separate policy and are not covered by the new hold columns.

## One-time setup (per environment)
1. **Owner-only future deployment, not performed by local remediation:** apply historical M1 through0006 explicitly. Create the login role with the least privilege it needs (EXECUTE on the three purge functions, no table/hold mutation privileges; not a member of `ap_m1_owner`):
   `psql -d <database> -v ON_ERROR_STOP=1 -v ma_purge_password="$(cat <generated-secret-file>)" -f backend/deploy/ma_purge_role.sql`
   Generate the secret with a password manager or `openssl rand -base64 32`. It never goes into git.
2. **OS user and files** on the host that runs jobs: user `ma-purge` (no login shell); `/etc/madalasa/purge.env` (mode 0640, owner root, group `ma-purge`) containing
   `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER=ma_purge`, `PGSSLMODE=verify-full` and `PGPASSFILE=/etc/madalasa/purge.pgpass` (mode 0600, owner `ma-purge`); the repository checked out or copied to `/opt/madalasa`.
3. **Install the units:** copy `ma-purge.service` and `ma-purge.timer` to `/etc/systemd/system/`, then `systemctl daemon-reload && systemctl enable --now ma-purge.timer`.
4. **First run by hand, only after owner deployment authorization:** `systemctl start ma-purge.service`, then `journalctl -u ma-purge -n 20`. Expect two JSON lines with `"status":"ok"`, or three when an explicit approved-for-that-environment `MA_PURGE_PAIRING_GRACE` is configured. A local synthetic test uses `1 day`; this is not a production/legal default.

If the hosting choice has no systemd (for example a managed scheduler), run `backend/scripts/run_purge.sh` from that scheduler with the same environment; it needs only `psql` and the `PG*` variables.

## Checking it works
- `systemctl list-timers ma-purge.timer` shows the next run; `systemctl --failed` must not list `ma-purge.service`.
- Each run prints `{"job":..., "status":"ok", ...counts}`. Zero counts are normal on a quiet system.
- **Alerting is not configured** (no alert channel is decided). Add `OnFailure=<your alert unit>` to the service when one exists. Until then someone has to look at `systemctl --failed`.

## When something goes wrong
| Symptom | Likely cause | Action |
|---|---|---|
| `"status":"failed"` with `permission denied` | role grants missing or recreated | re-run `ma_purge_role.sql` grants (the `GRANT` lines) |
| failed with `lock timeout` | another transaction held the same rows for over 10 s | harmless, the next hourly run retries; if it repeats, look for long transactions |
| failed with `statement timeout` (5 min) | very large backlog after a long outage | inspect backlog/locks before an owner-authorized retry; each enabled job is a transaction, and0006 takes device-first row locks; large-scale batching/benchmarking is not certified here |
| failed with `retention grace below the safety floor` | someone changed the call below a floor | restore the defaults |
| nothing deleted for days although old rows exist | timer disabled or host down | `systemctl status ma-purge.timer`; `Persistent=true` runs a missed job at boot |

To stop a future deployed job: `systemctl disable --now ma-purge.timer`, under the environment's owner/change controls. Expiry does not imply that evidence is no longer needed; preserve applicable holds and legal/incident retention decisions.

## Not done here
No hosting or IaC, no alert channel, no restore or backup policy for these tables, and no purge for tables that do not exist yet (M2 and later data
follows the retention schedule, which still has an open decision: GPS 14 vs 30 days).
