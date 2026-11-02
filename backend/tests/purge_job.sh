#!/usr/bin/env bash
# Tests the scheduled retention job: backend/scripts/run_purge.sh run as the least-privilege role from backend/deploy/ma_purge_role.sql.
# Needs psql and PG* env for a superuser (creates and drops its own database and the ma_purge / ma_nobody roles).
# The functions' own behaviour (floors, what is deleted) is covered by m1_enrollment.sql and m1_idempotency.sql; this checks the plumbing.
# SYNTHETIC DATA ONLY.
set -euo pipefail
# Default compatibility is tested regardless of the caller's optional setting.
unset MA_PURGE_PAIRING_GRACE
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT="$HERE/../.."
DB=ma_purge_it_$$
PW=synthetic_purge_password
fail() { echo "PURGE JOB FAILURE: $*" >&2; exit 1; }
adm() { psql -X -q -At -v ON_ERROR_STOP=1 "$@"; }
cleanup() { adm -d postgres -c "DROP DATABASE IF EXISTS $DB WITH (FORCE)" >/dev/null 2>&1 || true
            adm -d postgres -c "DROP ROLE IF EXISTS ma_purge" -c "DROP ROLE IF EXISTS ma_nobody" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
adm -d postgres -c "CREATE DATABASE $DB" >/dev/null
for migration in \
  0001_m1_identity.sql \
  0002_m1_device_credentials.sql \
  0003_m1_enrollment_and_credential_hardening.sql \
  0004_m1_idempotency.sql \
  0005_m1_family_provisioning.sql \
  0006_m1_concurrency_and_retention_holds.sql; do
  adm -d "$DB" -f "$ROOT/backend/persistence/migrations/$migration" >/dev/null
done
adm -d $DB -v ma_purge_password="$PW" -f "$ROOT/backend/deploy/ma_purge_role.sql" >/dev/null
adm -d postgres -c "CREATE ROLE ma_nobody LOGIN PASSWORD '$PW'" >/dev/null
adm -d $DB -c "GRANT USAGE ON SCHEMA ap_m1 TO ma_nobody" >/dev/null

# --- fixtures: an abandoned pending enrollment (old) and a recent one; an old and a recent idempotency key
adm -d $DB >/dev/null <<'SQL'
INSERT INTO ap_m1.families(id,label) VALUES ('9a000000-0000-4000-8000-000000000001','synthetic');
INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES ('9a000000-0000-4000-8000-000000000002','https://example.invalid','purge-job');
INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES ('9a000000-0000-4000-8000-000000000001','9a000000-0000-4000-8000-000000000002','OWNER');
INSERT INTO ap_m1.children(id,family_id,alias) VALUES ('9a000000-0000-4000-8000-000000000003','9a000000-0000-4000-8000-000000000001','synthetic child');
INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state,created_at) VALUES
 ('9a000000-0000-4000-8000-0000000000a1','9a000000-0000-4000-8000-000000000001','9a000000-0000-4000-8000-000000000003',decode(repeat('a1',90),'hex'),'PENDING_PROOF',now()-interval '10 days'),
 ('9a000000-0000-4000-8000-0000000000a2','9a000000-0000-4000-8000-000000000001','9a000000-0000-4000-8000-000000000003',decode(repeat('a2',90),'hex'),'PENDING_PROOF',now()-interval '1 hour');
INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,expires_at,created_at) VALUES
 ('9a000000-0000-4000-8000-0000000000a1',sha256('n1'::bytea),now()-interval '10 days'+interval '5 minutes',now()-interval '10 days'),
 ('9a000000-0000-4000-8000-0000000000a2',sha256('n2'::bytea),now()+interval '5 minutes',now());
INSERT INTO ap_m1.idempotency_keys(actor_id,namespace,key_sha256,request_sha256,expires_at,created_at) VALUES
 ('9a000000-0000-4000-8000-000000000002','POST /families',sha256('old'::bytea),sha256('r'::bytea),now()-interval '2 days',now()-interval '3 days'),
 ('9a000000-0000-4000-8000-000000000002','POST /families',sha256('recent'::bytea),sha256('r'::bytea),now()+interval '1 hour',now());
SQL
count() { adm -d $DB -c "$1"; }

run_as() { local user=$1; shift; PGUSER=$user PGPASSWORD=$PW PGDATABASE=$DB "$@"; }

# --- 1. the job deletes what it should, as JSON lines, exit 0
OUT=$(run_as ma_purge bash "$ROOT/backend/scripts/run_purge.sh") || fail "run_purge.sh failed as ma_purge: $OUT"
echo "$OUT" | python3 -I -c '
import json,sys
lines=[json.loads(l) for l in sys.stdin.read().splitlines()]
assert [l["job"] for l in lines]==["purge_credential_artifacts","purge_idempotency_keys"],lines
assert all(l["status"]=="ok" for l in lines),lines
c,k=lines
assert c["abandoned_devices_deleted"]==1 and c["enrollment_challenges_deleted"]==1,c
assert k["keys_deleted"]==1,k
' || fail "unexpected job output: $OUT"
[ "$(count "SELECT count(*) FROM ap_m1.devices WHERE id='9a000000-0000-4000-8000-0000000000a1'")" = "0" ] || fail "abandoned device not purged"
[ "$(count "SELECT count(*) FROM ap_m1.devices WHERE id='9a000000-0000-4000-8000-0000000000a2'")" = "1" ] || fail "recent pending device must be kept"
[ "$(count "SELECT count(*) FROM ap_m1.idempotency_keys WHERE key_sha256=sha256('old'::bytea)")" = "0" ] || fail "old idempotency key not purged"
[ "$(count "SELECT count(*) FROM ap_m1.idempotency_keys WHERE key_sha256=sha256('recent'::bytea)")" = "1" ] || fail "recent idempotency key must be kept"

# --- 2. idempotent: a second run deletes nothing and still exits 0
OUT2=$(run_as ma_purge bash "$ROOT/backend/scripts/run_purge.sh") || fail "second run failed"
echo "$OUT2" | python3 -I -c '
import json,sys
c,k=[json.loads(l) for l in sys.stdin.read().splitlines()]
assert c["abandoned_devices_deleted"]==0 and c["credentials_deleted"]==0 and k["keys_deleted"]==0,(c,k)
' || fail "second run should delete nothing: $OUT2"

# --- 3. least privilege: the purge role can do nothing else
for sql in "SELECT 1 FROM ap_m1.families" "SELECT 1 FROM ap_m1.idempotency_keys" "SELECT ap_m1.create_family('x')" \
           "SELECT ap_m1.idempotency_claim('9a000000-0000-4000-8000-000000000002','POST /x',sha256('a'::bytea),sha256('b'::bytea))" \
           "SET ROLE ap_m1_owner" "SET ROLE ap_m1_auth" "DELETE FROM ap_m1.families"; do
  if run_as ma_purge psql -X -q -At -c "$sql" >/dev/null 2>&1; then fail "ma_purge must NOT be able to run: $sql"; fi
done
for table in devices device_credentials credential_renewal_challenges enrollment_challenges pairing_codes; do
  if run_as ma_purge psql -X -q -At -v ON_ERROR_STOP=1 \
      -c "UPDATE ap_m1.$table SET retention_hold=false" >/dev/null 2>&1; then
    fail "ma_purge must not mutate retention holds on $table"
  fi
done
# direct privileges, from the catalog (an RLS policy can hide a table grant from a behavioural probe)
[ "$(count "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='ap_m1' AND c.relkind IN ('r','p','v','m','S') AND (has_table_privilege('ma_purge',c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') OR has_any_column_privilege('ma_purge',c.oid,'SELECT,INSERT,UPDATE,REFERENCES'))")" = "0" ] \
  || fail "ma_purge must have no privilege on any ap_m1 table, view or sequence"
[ "$(count "SELECT string_agg(p.proname, ',' ORDER BY p.proname) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='ap_m1' AND has_function_privilege('ma_purge',p.oid,'EXECUTE')")" = "purge_credential_artifacts,purge_idempotency_keys,purge_pairing_codes" ] \
  || fail "ma_purge must be able to execute exactly the three purge functions"
[ "$(count "SELECT rolinherit::text||rolbypassrls::text||rolsuper::text||rolcreaterole::text FROM pg_roles WHERE rolname='ma_purge'")" = "falsefalsefalsefalse" ] || fail "ma_purge must be NOINHERIT, NOBYPASSRLS, not superuser, cannot create roles"
[ "$(count "SELECT count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member WHERE r.rolname='ma_purge'")" = "0" ] || fail "ma_purge must not be a member of any role"

# --- 4. fail closed: a role without the grant gets a non-zero exit and a machine-readable failure line
set +e
OUT3=$(run_as ma_nobody bash "$ROOT/backend/scripts/run_purge.sh" 2>/dev/null); RC3=$?
set -e
[ $RC3 -ne 0 ] || fail "a role without EXECUTE must make the job fail"
[ "$(echo "$OUT3" | grep -c '"status":"failed"')" = "2" ] || fail "both jobs should report failure: $OUT3"
# unreachable database -> non-zero too
set +e; PGUSER=ma_purge PGPASSWORD=$PW PGDATABASE=$DB PGHOST=127.0.0.1 PGPORT=1 bash "$ROOT/backend/scripts/run_purge.sh" >/dev/null 2>&1; RC4=$?; set -e
[ $RC4 -ne 0 ] || fail "an unreachable database must make the job fail"
# missing configuration -> non-zero
set +e; env -u PGUSER -u PGDATABASE bash "$ROOT/backend/scripts/run_purge.sh" >/dev/null 2>&1; RC5=$?; set -e
[ $RC5 -ne 0 ] || fail "missing PGUSER/PGDATABASE must make the job fail"

# --- 5. bounded waits: a row held by another transaction makes the job fail at lock_timeout instead of hanging, then recovers
adm -d $DB -c "INSERT INTO ap_m1.idempotency_keys(actor_id,namespace,key_sha256,request_sha256,expires_at,created_at) VALUES ('9a000000-0000-4000-8000-000000000002','POST /families',sha256('held'::bytea),sha256('r'::bytea),now()-interval '2 days',now()-interval '3 days')" >/dev/null
( adm -d $DB >/dev/null <<'SQL'
BEGIN;
SELECT 1 FROM ap_m1.idempotency_keys WHERE key_sha256 = sha256('held'::bytea) FOR UPDATE;
SELECT pg_sleep(8);
COMMIT;
SQL
) & HOLD=$!
sleep 2
set +e
T0=$(date +%s); OUT6=$(MA_PURGE_LOCK_TIMEOUT=1s run_as ma_purge bash "$ROOT/backend/scripts/run_purge.sh" 2>/dev/null); RC6=$?; T1=$(date +%s)
set -e
[ $RC6 -ne 0 ] || fail "a locked row must make the job fail at lock_timeout, not wait it out"
[ $((T1-T0)) -le 5 ] || fail "the job waited $((T1-T0))s although lock_timeout was 1s"
echo "$OUT6" | grep -q '"job":"purge_idempotency_keys","status":"failed"' || fail "the locked job should report failure: $OUT6"
wait $HOLD
OUT7=$(run_as ma_purge bash "$ROOT/backend/scripts/run_purge.sh") || fail "job should succeed once the lock is released"
[ "$(count "SELECT count(*) FROM ap_m1.idempotency_keys WHERE key_sha256=sha256('held'::bytea)")" = "0" ] || fail "the released key should be purged on the next run"

# --- explicit pairing grace: no default TTL; old unheld only, count and replay
adm -d "$DB" >/dev/null <<'SQL'
INSERT INTO ap_m1.pairing_codes(id,family_id,child_id,issued_by,code_sha256,created_at,expires_at,retention_hold) VALUES
 ('9a000000-0000-4000-8000-0000000000b1','9a000000-0000-4000-8000-000000000001','9a000000-0000-4000-8000-000000000003','9a000000-0000-4000-8000-000000000002',sha256('pair-old'::bytea),now()-interval '10 days',now()-interval '9 days',false),
 ('9a000000-0000-4000-8000-0000000000b2','9a000000-0000-4000-8000-000000000001','9a000000-0000-4000-8000-000000000003','9a000000-0000-4000-8000-000000000002',sha256('pair-held'::bytea),now()-interval '10 days',now()-interval '9 days',true),
 ('9a000000-0000-4000-8000-0000000000b3','9a000000-0000-4000-8000-000000000001','9a000000-0000-4000-8000-000000000003','9a000000-0000-4000-8000-000000000002',sha256('pair-recent'::bytea),now(),now()+interval '5 minutes',false);
SQL
# Unset mode must neither emit a third line nor delete any pairing fixture.
OUTP=$(env -u MA_PURGE_PAIRING_GRACE PGUSER=ma_purge PGPASSWORD="$PW" PGDATABASE="$DB" bash "$ROOT/backend/scripts/run_purge.sh")
printf '%s\n' "$OUTP" | python3 -I -c 'import json,sys; r=[json.loads(l) for l in sys.stdin]; assert [x["job"] for x in r]==["purge_credential_artifacts","purge_idempotency_keys"]'
[ "$(count "SELECT count(*) FROM ap_m1.pairing_codes")" = 3 ] || fail "unset grace deleted pairing codes"
for expected in 1 0; do
  OUTP=$(MA_PURGE_PAIRING_GRACE='1 day' run_as ma_purge bash "$ROOT/backend/scripts/run_purge.sh") || fail "explicit pairing run failed"
  printf '%s\n' "$OUTP" | python3 -I -c '
import json,sys
r=[json.loads(l) for l in sys.stdin]
assert [x["job"] for x in r]==["purge_credential_artifacts","purge_idempotency_keys","purge_pairing_codes"],r
assert all(x["status"]=="ok" for x in r),r
assert r[2]["pairing_codes_deleted"]==int(sys.argv[1]),r
' "$expected" || fail "pairing count/idempotence: $OUTP"
done
[ "$(count "SELECT string_agg(id::text,',' ORDER BY id) FROM ap_m1.pairing_codes")" = "9a000000-0000-4000-8000-0000000000b2,9a000000-0000-4000-8000-0000000000b3" ] || fail "held/recent pairing fixtures changed"
for grace in '' '0 seconds' '-1 day' 'infinity' "1 day'); DELETE FROM ap_m1.pairing_codes; --"; do
  set +e
  OUTP=$(MA_PURGE_PAIRING_GRACE="$grace" run_as ma_purge bash "$ROOT/backend/scripts/run_purge.sh" 2>/dev/null); RCP=$?
  set -e
  [ "$RCP" -ne 0 ] || fail "invalid pairing grace accepted: $grace"
  printf '%s\n' "$OUTP" | python3 -I -c '
import json,sys
r=[json.loads(l) for l in sys.stdin]
assert len(r)==3 and all(x["status"]=="ok" for x in r[:2]),r
assert r[2]=={"job":"purge_pairing_codes","status":"failed"},r
' || fail "invalid grace must fail only the explicit pairing job: $OUTP"
  [ "$(count "SELECT count(*) FROM ap_m1.pairing_codes")" = 2 ] || fail "invalid grace changed pairing fixtures"
done

echo "purge job PASS: default two-job compatibility, explicit pairing grace, held/recent preservation, idempotence, exact-three-function least privilege, fail closed, bounded lock wait"
