#!/usr/bin/env bash
# M1 idempotency concurrency regression (migration 0004). Needs PG* env vars and a database with 0001..0004 applied.
# Scenario 1: session 1 holds a claim; session 2 (same key, same body) must BLOCK, then get REPLAY with the stored body.
# Scenario 2: session 1 rolls back; session 2 must become the new owner (NEW).
# Scenario 3: lock_timeout turns an over-long wait into an error (SQLSTATE 55P03) instead of hanging.
# SYNTHETIC DATA ONLY.
set -euo pipefail
P="psql -X -q -t -A -v ON_ERROR_STOP=1"
ACT=1d000000-0000-4000-8000-0000000000c1
$P -c "INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES ('$ACT','https://example.invalid','idem-conc') ON CONFLICT DO NOTHING"
fail() { echo "M1_IDEMPOTENCY_CONCURRENCY_FAILURE: $*" >&2; exit 1; }
S1=$(mktemp); S2=$(mktemp); trap 'rm -f "$S1" "$S2"' EXIT

# --- scenario 1: commit
( $P <<SQL
SET ROLE ap_m1_api; BEGIN;
SELECT outcome FROM ap_m1.idempotency_claim('$ACT','POST /families',sha256('conc1'::bytea),sha256('r'::bytea));
SELECT pg_sleep(3);
SELECT ap_m1.idempotency_record('$ACT','POST /families',sha256('conc1'::bytea),201,'{"id":"winner"}'::jsonb);
COMMIT;
SQL
) >"$S1" &
PID1=$!
sleep 1
T0=$(date +%s)
$P >"$S2" <<SQL
SET ROLE ap_m1_api; BEGIN; SET LOCAL lock_timeout='10s';
SELECT outcome||'|'||response_status||'|'||(response_body->>'id') FROM ap_m1.idempotency_claim('$ACT','POST /families',sha256('conc1'::bytea),sha256('r'::bytea));
COMMIT;
SQL
T1=$(date +%s); wait $PID1
grep -q '^NEW$' "$S1" || fail "session 1 should have been NEW: $(cat "$S1")"
grep -q 'REPLAY|201|winner' "$S2" || fail "session 2 should REPLAY the winner, got: $(cat "$S2")"
[ $((T1-T0)) -ge 1 ] || fail "session 2 did not block on the in-flight claim"

# --- scenario 2: rollback hands ownership to the waiter
( $P <<SQL
SET ROLE ap_m1_api; BEGIN;
SELECT outcome FROM ap_m1.idempotency_claim('$ACT','POST /families',sha256('conc2'::bytea),sha256('r'::bytea));
SELECT pg_sleep(3);
ROLLBACK;
SQL
) >"$S1" &
PID1=$!
sleep 1
$P >"$S2" <<SQL
SET ROLE ap_m1_api; BEGIN; SET LOCAL lock_timeout='10s';
SELECT outcome FROM ap_m1.idempotency_claim('$ACT','POST /families',sha256('conc2'::bytea),sha256('r'::bytea));
COMMIT;
SQL
wait $PID1
grep -q '^NEW$' "$S2" || fail "after a rollback the waiter should be NEW, got: $(cat "$S2")"

# --- scenario 3: bounded wait
( $P <<SQL
SET ROLE ap_m1_api; BEGIN;
SELECT outcome FROM ap_m1.idempotency_claim('$ACT','POST /families',sha256('conc3'::bytea),sha256('r'::bytea));
SELECT pg_sleep(4);
COMMIT;
SQL
) >"$S1" &
PID1=$!
sleep 1
set +e
$P >"$S2" 2>&1 <<SQL
SET ROLE ap_m1_api; BEGIN; SET LOCAL lock_timeout='1s';
SELECT outcome FROM ap_m1.idempotency_claim('$ACT','POST /families',sha256('conc3'::bytea),sha256('r'::bytea));
SQL
set -e
wait $PID1
grep -qi 'lock timeout' "$S2" || fail "lock_timeout should abort the waiter, got: $(cat "$S2")"

echo "M1 idempotency concurrency PASS: waiter blocks then replays, rollback hands over ownership, lock_timeout bounds the wait"
