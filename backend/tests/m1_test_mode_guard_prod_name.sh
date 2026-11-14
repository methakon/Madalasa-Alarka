#!/usr/bin/env bash
# The trigger must refuse to enable test mode in a database whose name is not disposable. Copies the current database
# (which already has migration 0032) to a production-like name, tries to enable the switch there, then drops the copy.
# Needs an admin session in PG* env vars and CREATEDB rights. SYNTHETIC DATA ONLY.
set -euo pipefail
SRC=${PGDATABASE:?}
COPY=madalasa_prod_guard_probe
cleanup() { psql -X -q -d postgres -c "DROP DATABASE IF EXISTS $COPY" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
psql -X -q -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE $COPY TEMPLATE $SRC"
set +e
out=$(psql -X -q -d "$COPY" -v ON_ERROR_STOP=1 -c "UPDATE ap_m1.local_test_settings SET enabled=true WHERE singleton" 2>&1)
rc=$?
set -e
[ $rc -ne 0 ] || { echo "FAIL: enabling test mode succeeded in $COPY" >&2; exit 1; }
echo "$out" | grep -q "disposable database" || { echo "FAIL: unexpected refusal text: $out" >&2; exit 1; }
# Switching it off (or leaving it off) is always allowed.
psql -X -q -d "$COPY" -v ON_ERROR_STOP=1 -c "UPDATE ap_m1.local_test_settings SET enabled=false WHERE singleton"
echo "PASS: production-named database cannot enable test mode"
