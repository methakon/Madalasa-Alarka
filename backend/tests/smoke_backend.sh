#!/usr/bin/env bash
# HTTP smoke test for the backend skeleton. Usage: smoke_backend.sh /path/to/ma_backend
set -euo pipefail
BIN=${1:?usage: smoke_backend.sh /path/to/ma_backend}
PORT=${MA_SMOKE_PORT:-18080}
MA_LISTEN_PORT=$PORT "$BIN" >/dev/null 2>&1 & PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
for _ in $(seq 1 50); do curl -fs "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1 && break; sleep 0.2; done
fail() { echo "SMOKE FAILURE: $*" >&2; exit 1; }
U=http://127.0.0.1:$PORT
UUID='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

H=$(curl -si "$U/healthz"); echo "$H" | head -1 | grep -q ' 200' || fail "healthz not 200"
RID=$(echo "$H" | tr -d '\r' | sed -n 's/^[Xx]-[Rr]equest-[Ii]d: //p'); [[ $RID =~ $UUID ]] || fail "healthz X-Request-Id not a uuid: '$RID'"

# client-supplied request id must be ignored
H=$(curl -si -H 'X-Request-Id: attacker-chosen' "$U/healthz")
RID2=$(echo "$H" | tr -d '\r' | sed -n 's/^[Xx]-[Rr]equest-[Ii]d: //p'); [[ $RID2 =~ $UUID ]] || fail "client request id was echoed: '$RID2'"

# unknown route -> catalog 404 with the same id in header and body
R=$(curl -si "$U/v1/nope"); echo "$R" | head -1 | grep -q ' 404' || fail "unknown route not 404"
HID=$(echo "$R" | tr -d '\r' | sed -n 's/^[Xx]-[Rr]equest-[Ii]d: //p')
BODY=$(echo "$R" | tr -d '\r' | sed -n '/^{/p')
python3 -I - "$HID" "$BODY" <<'PY' || fail "404 envelope wrong"
import json,sys
hid,body=sys.argv[1],json.loads(sys.argv[2])
assert set(body)=={"code","message","request_id","retryable"},body
assert body["code"]=="NOT_FOUND" and body["retryable"] is False and body["request_id"]==hid and len(body["message"])<=300
PY
echo "backend smoke PASS: healthz, server-generated request id, catalog-format 404"
