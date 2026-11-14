#!/usr/bin/env bash
# Deployable (non-synthetic) binary + a V2 database: when ap_m1.local_test_settings.enabled is true the API must answer
# 503 to everything except /healthz, and recover once it is switched off. SYNTHETIC DATA ONLY; the database is a
# disposable one and the flag is restored on exit.
#   usage: integration_test_mode_guard.sh <ma_backend (no MA_SYNTHETIC_AUTH)> <admin psql args as env PG*>
# Needs: PGHOST/PGPORT/PGUSER/PGDATABASE for an admin session; MA_GUARD_RUNTIME_LOGIN (a login role that is a member
# of ap_m1_api) and its password in MA_GUARD_RUNTIME_PASSWORD; MA_GUARD_PORT (default 18091).
set -euo pipefail
BIN=${1:?path to deployable ma_backend}
# CI convenience: derive the admin session and the runtime login from the private connection config.
if [ -n "${MA_LOCAL_DB_CONFIG:-}" ] && [ -z "${MA_GUARD_RUNTIME_LOGIN:-}" ]; then
  eval "$(python3 - <<'PY'
import json, os, shlex
cfg = json.load(open(os.environ["MA_LOCAL_DB_CONFIG"]))["test"]
def parse(c): return dict(t.split("=", 1) for t in c.split())
a, r = parse(cfg["admin"]), parse(cfg["runtime"])
for k, v in {"PGHOST": a["host"], "PGPORT": a["port"], "PGUSER": a["user"], "PGPASSWORD": a["password"],
             "PGDATABASE": a["dbname"], "MA_GUARD_RUNTIME_LOGIN": r["user"], "MA_GUARD_RUNTIME_PASSWORD": r["password"]}.items():
    print(f"export {k}={shlex.quote(v)}")
PY
)"
fi
PORT=${MA_GUARD_PORT:-18091}
LOGIN=${MA_GUARD_RUNTIME_LOGIN:?runtime login role}
PASS=${MA_GUARD_RUNTIME_PASSWORD:?runtime login password}
fail() { echo "FAIL: $*" >&2; exit 1; }
status() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$PORT$1" || true; }
setflag() { psql -X -q -v ON_ERROR_STOP=1 -c "UPDATE ap_m1.local_test_settings SET enabled=$1 WHERE singleton"; }
trap 'setflag false >/dev/null 2>&1 || true; kill "${BACKEND_PID:-0}" 2>/dev/null || true' EXIT

setflag true
MA_LISTEN_ADDR=127.0.0.1 MA_LISTEN_PORT=$PORT MA_PG_HOST=${PGHOST_TCP:-127.0.0.1} MA_PG_PORT=${PGPORT:-5432} MA_PG_DB=$PGDATABASE \
  MA_PG_USER=$LOGIN MA_PG_PASSWORD=$PASS "$BIN" >/tmp/ma_guard_backend.log 2>&1 &
BACKEND_PID=$!
for _ in $(seq 1 40); do [ "$(status /healthz)" = 200 ] && break; sleep 0.25; done
[ "$(status /healthz)" = 200 ] || fail "backend never answered /healthz"

# 1. switch ON at start-up: blocked within the first check
for _ in $(seq 1 20); do [ "$(status /v1/faqs)" = 503 ] && break; sleep 0.25; done
[ "$(status /v1/faqs)" = 503 ] || fail "route not blocked while test mode is ON"
[ "$(status /v1/families)" = 503 ] || fail "authenticated route not blocked"
[ "$(status /healthz)" = 200 ] || fail "/healthz must stay reachable for the supervisor"
grep -q "refusing all routes" /tmp/ma_guard_backend.log || fail "no fatal log line"

# 2. switch OFF: recovers on the next 30 s poll
setflag false
for _ in $(seq 1 45); do [ "$(status /v1/faqs)" != 503 ] && break; sleep 1; done
[ "$(status /v1/faqs)" != 503 ] || fail "routes did not recover after the switch went off"

# 3. switch turned ON while serving: blocked again
setflag true
for _ in $(seq 1 45); do [ "$(status /v1/faqs)" = 503 ] && break; sleep 1; done
[ "$(status /v1/faqs)" = 503 ] || fail "late enable not detected"
echo "PASS: test-mode guard blocks, recovers and re-blocks"
