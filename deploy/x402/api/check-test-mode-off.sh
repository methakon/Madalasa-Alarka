#!/usr/bin/env bash
# Release gate: the database test-mode switch must be OFF and the database must not carry a disposable name.
# Uses the standard libpq environment (PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD or PGSERVICE) with the runtime
# login, which can call ap_m1.test_mode_enabled(). Never prints credentials. Exit 0 only when it is proven off.
# A missing function (migration 0032 not applied), a failed connection or any other answer is a failure.
set -euo pipefail
command -v psql >/dev/null || { echo "FAIL: psql not installed; cannot prove the test-mode switch is off" >&2; exit 1; }
out=$(psql -X -At -v ON_ERROR_STOP=1 -c "SELECT ap_m1.test_mode_enabled()::text || '|' || current_database()" 2>/dev/null) || {
  echo "FAIL: could not read ap_m1.test_mode_enabled() (migration 0032 missing, wrong role, or database unreachable)" >&2; exit 1; }
flag=${out%%|*}
name=${out#*|}
case "$flag" in
  false) : ;;
  true) echo "FAIL: database test mode is ON; a deployable API refuses all traffic while it is on" >&2; exit 1 ;;
  *) echo "FAIL: unexpected answer from the test-mode probe" >&2; exit 1 ;;
esac
if printf '%s' "$name" | grep -Eq '^(madalasa_alarka_(dev|test)|ma_synthetic_[a-z0-9_]+)$'; then
  echo "FAIL: database name '$name' is reserved for disposable test databases; production must use another name" >&2; exit 1
fi
echo "PASS: test mode is off in database '$name'"
