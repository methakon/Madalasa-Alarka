#!/usr/bin/env bash
# End-to-end test of POST /v1/families against a real PostgreSQL: starts the backend built with -DMA_SYNTHETIC_AUTH=ON.
# Usage: integration_families.sh /path/to/ma_backend
# Needs psql and PG* env (a superuser that may create a database; the script creates and drops its own database).
# SYNTHETIC DATA ONLY. The synthetic authenticator exists only in this test build.
set -euo pipefail
BIN=${1:?usage: integration_families.sh /path/to/ma_backend}
HERE=$(cd "$(dirname "$0")" && pwd)
MIG="$HERE/../persistence/migrations"
DB=ma_it_$$
PORT=${MA_IT_PORT:-18081}; PORT2=$((PORT+1))
U=http://127.0.0.1:$PORT
fail() { echo "INTEGRATION FAILURE: $*" >&2; exit 1; }
psql_admin() { psql -X -q -At -v ON_ERROR_STOP=1 "$@"; }

CHILD_PIDS=()
OUT=""
DB_CREATED=false
cleanup() {
  local status=$? pid attempt
  trap - EXIT
  set +e
  for pid in "${CHILD_PIDS[@]}"; do
    # Only this script's successfully spawned children; never process group 0.
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || continue
    kill -TERM "$pid" 2>/dev/null
  done
  for attempt in {1..20}; do
    local alive=false
    for pid in "${CHILD_PIDS[@]}"; do
      [[ "$pid" =~ ^[1-9][0-9]*$ ]] || continue
      kill -0 "$pid" 2>/dev/null && alive=true
    done
    "$alive" || break
    sleep 0.05
  done
  for pid in "${CHILD_PIDS[@]}"; do
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || continue
    kill -KILL "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  done
  if "$DB_CREATED"; then
    psql_admin -d postgres -c "DROP DATABASE IF EXISTS $DB WITH (FORCE)" >/dev/null 2>&1 || true
  fi
  [[ -z "$OUT" ]] || rm -rf -- "$OUT"
  exit "$status"
}
trap cleanup EXIT
# mktemp honors the caller's project TMPDIR; logs and responses share its scope.
OUT=$(mktemp -d)
psql_admin -d postgres -c "CREATE DATABASE $DB" >/dev/null
DB_CREATED=true
# Explicit historical M1 order, never an alphabetical replay of unrelated SQL.
for name in 0001_m1_identity.sql 0002_m1_device_credentials.sql \
  0003_m1_enrollment_and_credential_hardening.sql 0004_m1_idempotency.sql \
  0005_m1_family_provisioning.sql 0006_m1_concurrency_and_retention_holds.sql; do
  psql_admin -d "$DB" -f "$MIG/$name" >/dev/null
done
# Roles are NOLOGIN in the migrations; a test environment lets the runtime role log in.
psql_admin -d $DB -c "ALTER ROLE ap_m1_api LOGIN PASSWORD 'synthetic_it_password'" >/dev/null
Q() { psql_admin -d $DB -c "$1"; }

MA_AUTH_MODE=synthetic_test MA_PARENT_AUTH_MODE=m1_direct_oidc MA_LISTEN_PORT=$PORT MA_PG_HOST=${PGHOST:-127.0.0.1} MA_PG_PORT=${PGPORT:-5432} MA_PG_DB=$DB \
  MA_PG_USER=ap_m1_api MA_PG_PASSWORD=synthetic_it_password "$BIN" >"$OUT/backend.log" 2>&1 & PID=$!
CHILD_PIDS+=("$PID")
for _ in $(seq 1 60); do curl -fs $U/healthz >/dev/null 2>&1 && break; sleep 0.2; done
curl -fs $U/healthz >/dev/null || { cat "$OUT/backend.log"; fail "backend did not start"; }

UUID_RE='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
newkey() { python3 -c 'import uuid;print(uuid.uuid4())'; }
# req NAME EXPECTED_STATUS [curl args...] ; leaves $OUT/NAME.{status,body,hdr}
req() {
  local name=$1 want=$2; shift 2
  curl -s -o "$OUT/$name.body" -D "$OUT/$name.hdr" -w '%{http_code}' "$@" >"$OUT/$name.status" || true
  [ "$(cat "$OUT/$name.status")" = "$want" ] || { echo "--- $name body:"; cat "$OUT/$name.body"; fail "$name: expected $want, got $(cat "$OUT/$name.status")"; }
  grep -qi '^x-request-id: ' "$OUT/$name.hdr" || fail "$name: no X-Request-Id header"
}
jget() { python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$OUT/$1.body" "$2"; }
assert_error() {  # name code retryable
  python3 -I - "$OUT/$1.body" "$OUT/$1.hdr" "$2" "$3" <<'PY' || fail "$1: error envelope wrong"
import json,re,sys
b=json.load(open(sys.argv[1])); h=open(sys.argv[2]).read()
rid=re.search(r'(?im)^x-request-id:\s*(\S+)',h).group(1)
assert set(b)=={"code","message","request_id","retryable"},b
assert b["code"]==sys.argv[3],b
assert b["retryable"]==(sys.argv[4]=="true"),b
assert b["request_id"]==rid,(b,rid)
assert len(b["message"])<=300
PY
}
H_JSON=(-H 'Content-Type: application/json')
AUTH() { echo "-H" "X-Synthetic-Subject: $1"; }
post() { # name status subject key body [extra curl args]
  local name=$1 want=$2 subj=$3 key=$4 body=$5; shift 5
  req "$name" "$want" -X POST "$U/v1/families" "${H_JSON[@]}" -H "X-Synthetic-Subject: $subj" -H "Idempotency-Key: $key" --data "$body" "$@"
}

# --- syntax errors come before authentication (rule 5.3.5): no subject header at all
req e_nokey 400 -X POST $U/v1/families "${H_JSON[@]}" --data '{"label":"x"}';                         assert_error e_nokey INVALID_REQUEST false
req e_badkey 400 -X POST $U/v1/families "${H_JSON[@]}" -H 'Idempotency-Key: not-a-uuid' --data '{"label":"x"}'; assert_error e_badkey INVALID_REQUEST false
K=$(newkey)
req e_ctype 400 -X POST $U/v1/families -H 'Content-Type: text/plain' -H "Idempotency-Key: $K" --data '{"label":"x"}'; assert_error e_ctype INVALID_REQUEST false
req e_json 400 -X POST $U/v1/families "${H_JSON[@]}" -H "Idempotency-Key: $K" --data '{"label":'; assert_error e_json INVALID_REQUEST false
req e_extra 400 -X POST $U/v1/families "${H_JSON[@]}" -H "Idempotency-Key: $K" --data '{"label":"x","admin":true}'; assert_error e_extra INVALID_REQUEST false
req e_type 400 -X POST $U/v1/families "${H_JSON[@]}" -H "Idempotency-Key: $K" --data '{"label":7}'; assert_error e_type INVALID_REQUEST false
req e_dup 400 -X POST $U/v1/families "${H_JSON[@]}" -H "Idempotency-Key: $K" --data '{"label":"a","label":"b"}'; assert_error e_dup INVALID_REQUEST false
req e_nul 400 -X POST $U/v1/families "${H_JSON[@]}" -H "Idempotency-Key: $K" --data '{"label":"a\u0000b"}'; assert_error e_nul INVALID_REQUEST false
python3 -c 'import sys;sys.stdout.write("{\"label\":\""+"a"*70000+"\"}")' > $OUT/big.json
python3 -c 'import sys;sys.stdout.write("{\"label\":\""+"a"*(1024*1024+10)+"\"}")' > $OUT/huge.json
# Over Drogon's own 1 MiB parser limit: bare 413 written by the framework (no envelope); status is still correct.
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST $U/v1/families "${H_JSON[@]}" -H "Idempotency-Key: $K" --data-binary @$OUT/huge.json)" = "413" ] || fail "a body over 1 MiB must be answered 413"
req e_big 413 -X POST $U/v1/families "${H_JSON[@]}" -H "Idempotency-Key: $K" --data-binary @$OUT/big.json; assert_error e_big PAYLOAD_TOO_LARGE false

# --- 401: well-formed but no identity
req e_noauth 401 -X POST $U/v1/families "${H_JSON[@]}" -H "Idempotency-Key: $K" --data '{"label":"x"}'; assert_error e_noauth UNAUTHENTICATED false

# --- 422: well-formed, out of range (after authentication)
post e_empty 422 it-a "$K" '{"label":""}'; assert_error e_empty VALIDATION_FAILED false
post e_long 422 it-a "$K" "{\"label\":\"$(python3 -c 'print("a"*101)')\"}"; assert_error e_long VALIDATION_FAILED false
[ "$(Q 'SELECT count(*) FROM ap_m1.families')" = "0" ] || fail "rejected requests must not create anything"
[ "$(Q 'SELECT count(*) FROM ap_m1.idempotency_keys')" = "0" ] || fail "rejected requests must not leave idempotency keys"

# --- 201 happy path
K1=$(newkey)
post ok1 201 it-a "$K1" '{"label":"Synthetic family"}'
[[ $(jget ok1 id) =~ $UUID_RE ]] || fail "id is not a uuid"
[ "$(jget ok1 label)" = "Synthetic family" ] && [ "$(jget ok1 status)" = "ACTIVE" ] || fail "unexpected 201 body: $(cat $OUT/ok1.body)"
python3 -I -c 'import json;assert set(json.load(open("'$OUT/ok1.body'")))=={"id","label","status"}' || fail "201 body has extra fields"
FID=$(jget ok1 id)
[ "$(Q "SELECT count(*) FROM ap_m1.families WHERE id='$FID'")" = "1" ] || fail "family row missing"
[ "$(Q "SELECT m.membership_role FROM ap_m1.guardian_memberships m JOIN ap_m1.parent_principals p ON p.id=m.principal_id WHERE m.family_id='$FID' AND p.oidc_subject='it-a'")" = "OWNER" ] || fail "creator is not OWNER"

# --- replay: identical response, no second row (also with a different JSON key order/whitespace)
post replay 201 it-a "$K1" '{ "label" : "Synthetic family" }'
[ "$(jget replay id)" = "$FID" ] || fail "replay returned a different family"
cmp -s $OUT/ok1.body $OUT/replay.body || fail "replay body differs from the original"
[ "$(Q "SELECT count(*) FROM ap_m1.families WHERE label='Synthetic family'")" = "1" ] || fail "replay created a second family"

# --- same key, different body
post reuse 409 it-a "$K1" '{"label":"Another label"}'; assert_error reuse IDEMPOTENCY_KEY_REUSED false
grep -q "$FID" $OUT/reuse.body && fail "mismatch response leaked the stored response"

# --- another principal with the same key is independent and cannot see the first family
post other 201 it-b "$K1" '{"label":"Synthetic family"}'
[ "$(jget other id)" != "$FID" ] || fail "two principals shared a family through one idempotency key"

# --- only hashes are stored, never the raw key
[ "$(Q "SELECT count(*) FROM ap_m1.idempotency_keys WHERE key_sha256 = sha256(convert_to('$K1','UTF8'))")" = "2" ] || fail "key hash rows missing (expected one per principal)"
Q "SELECT row_to_json(k)::text FROM ap_m1.idempotency_keys k" | grep -q "$K1" && fail "raw Idempotency-Key found in the database"

# --- concurrency: 8 parallel identical requests create exactly one family
KC=$(newkey)
PARS=()
for i in $(seq 1 8); do
  ( curl -s -o "$OUT/par$i.body" -w '%{http_code}' -X POST $U/v1/families "${H_JSON[@]}" -H 'X-Synthetic-Subject: it-par' -H "Idempotency-Key: $KC" --data '{"label":"Parallel"}' >"$OUT/par$i.status" ) &
  PARS+=($!)
done
wait "${PARS[@]}"  # only the curl jobs: a bare wait would also wait for the backend process
for i in $(seq 1 8); do [ "$(cat $OUT/par$i.status)" = "201" ] || { cat $OUT/par$i.body; fail "parallel request $i got $(cat $OUT/par$i.status)"; }; done
[ "$(cat $OUT/par*.body | python3 -I -c 'import sys,json,re;print(len(set(re.findall(r"\"id\":\"([0-9a-f-]{36})\"",sys.stdin.read()))))')" = "1" ] || fail "parallel requests returned different families"
[ "$(Q "SELECT count(*) FROM ap_m1.families WHERE label='Parallel'")" = "1" ] || fail "parallel requests created more than one family"

# --- cap: 10 families per account, the 11th is refused, a retry of an earlier success still replays
FIRST=""
for i in $(seq 1 10); do k=$(newkey); [ -z "$FIRST" ] && FIRST=$k; post cap$i 201 it-cap "$k" "{\"label\":\"Cap $i\"}"; done
post cap11 422 it-cap "$(newkey)" '{"label":"Cap 11"}'; assert_error cap11 VALIDATION_FAILED false
post cap_replay 201 it-cap "$FIRST" '{"label":"Cap 1"}'
[ "$(jget cap_replay label)" = "Cap 1" ] || fail "a replay must still work at the cap"

# GET /v1/families is now an authenticated frozen M1 route; no principal must fail closed.
req e_get 401 $U/v1/families; assert_error e_get UNAUTHENTICATED false
# Unknown route remains catalog-shaped.
req e_unknown 404 $U/v1/not-an-m1-route; assert_error e_unknown NOT_FOUND false

# --- second instance: no database configured and no synthetic mode
MA_LISTEN_PORT=$PORT2 "$BIN" >"$OUT/backend2.log" 2>&1 & PID2=$!
CHILD_PIDS+=("$PID2")
for _ in $(seq 1 60); do curl -fs http://127.0.0.1:$PORT2/healthz >/dev/null 2>&1 && break; sleep 0.2; done
U2=http://127.0.0.1:$PORT2
curl -s -o $OUT/p1.body -w '%{http_code}' -X POST $U2/v1/families "${H_JSON[@]}" -H 'X-Synthetic-Subject: it-a' -H "Idempotency-Key: $(newkey)" --data '{"label":"x"}' | grep -q '^401$' \
  || fail "synthetic header must be ignored unless the test build is switched on (expected 401)"

echo "families integration PASS: check order, 201 shape, replay, key reuse, principal isolation, hashed keys, 8-way concurrency, cap, catalog errors"
