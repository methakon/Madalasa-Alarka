#!/usr/bin/env bash
# M1 retention jobs: credential artifacts, idempotency keys, optional pairing codes (0006).
# Run on a schedule (hourly; see backend/deploy/systemd and docs/M1_PURGE_JOBS_RUNBOOK.md) as the dedicated login role
# created by backend/deploy/ma_purge_role.sql. It can execute exactly three purge functions,
# with no direct table access or retention-hold mutation authority.
#
# Connection comes from the standard PG* variables (PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD or PGPASSFILE).
# One JSON line per job on stdout (journald-friendly). The original two jobs always run;
# a third runs only when MA_PURGE_PAIRING_GRACE is explicitly set. Any failed job
# produces a non-zero exit. Deleting is idempotent: a re-run deletes nothing.
set -uo pipefail
: "${PGUSER:?set PGUSER to the purge login role (ma_purge)}"
: "${PGDATABASE:?set PGDATABASE}"
# Bounded waits: never hold locks or run unbounded against the live database.
export PGOPTIONS="-c lock_timeout=${MA_PURGE_LOCK_TIMEOUT:-10s} -c statement_timeout=300000 -c application_name=ma-purge ${PGOPTIONS:-}"

rc=0
run_job() {
  local job=$1 sql=$2 out
  if out=$(psql -X -q -At -v ON_ERROR_STOP=1 -c "$sql" 2>&1); then
    printf '%s\n' "$out"
  else
    rc=1
    # The database message goes to stderr for the operator; stdout stays machine-readable.
    printf '{"job":"%s","status":"failed"}\n' "$job"
    printf '%s job failed: %s\n' "$job" "$out" >&2
  fi
}

run_job purge_credential_artifacts \
  "SELECT json_build_object('job','purge_credential_artifacts','status','ok','at',now(),
     'credentials_deleted',credentials_deleted,'renewal_challenges_deleted',renewal_challenges_deleted,
     'enrollment_challenges_deleted',enrollment_challenges_deleted,'abandoned_devices_deleted',abandoned_devices_deleted)::text
   FROM ap_m1.purge_credential_artifacts()"
run_job purge_idempotency_keys \
  "SELECT json_build_object('job','purge_idempotency_keys','status','ok','at',now(),
     'keys_deleted',ap_m1.purge_idempotency_keys())::text"
# Deliberately no default pairing TTL. Even an explicitly empty value fails
# closed in PostgreSQL rather than silently selecting an implicit schedule.
if [[ ${MA_PURGE_PAIRING_GRACE+x} ]]; then
  if out=$(psql -X -q -At -v ON_ERROR_STOP=1 \
      -v pairing_grace="$MA_PURGE_PAIRING_GRACE" 2>&1 <<'SQL'
SELECT json_build_object('job','purge_pairing_codes','status','ok','at',now(),
  'pairing_codes_deleted',ap_m1.purge_pairing_codes(:'pairing_grace'::interval))::text;
SQL
  ); then
    printf '%s\n' "$out"
  else
    rc=1
    printf '{"job":"purge_pairing_codes","status":"failed"}\n'
    printf 'purge_pairing_codes job failed: %s\n' "$out" >&2
  fi
fi
exit $rc
