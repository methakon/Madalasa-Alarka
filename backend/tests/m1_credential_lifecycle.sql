-- Madalasa-Alarka M1 PostgreSQL 15+ regression: device credential lifecycle + family listing.
-- Run on a FRESH isolated CI database, after migrations 0001, 0002 and 0003.
-- Runs as the psql superuser for fixtures and SET ROLE ap_m1_api for realistic checks.
-- SYNTHETIC DATA ONLY. Every assertion raises on failure; ON_ERROR_STOP makes psql exit non-zero.
\set ON_ERROR_STOP on

CREATE FUNCTION public.ap_m1_test_expect(cond boolean, msg text) RETURNS void
 LANGUAGE plpgsql AS $f$
BEGIN
 IF cond IS NOT TRUE THEN RAISE EXCEPTION 'M1_CREDENTIAL_TEST_FAILURE: %', msg; END IF;
END $f$;

-- Emulates the backend: step 1 consume, verify (nonce + signature result), step 2 issue.
CREATE FUNCTION public.t_renew(dev uuid, ch uuid, nonce bytea, proof boolean, tok bytea, life integer)
 RETURNS timestamptz LANGUAGE plpgsql AS $f$
DECLARE r record;
BEGIN
 SELECT * INTO r FROM ap_m1.consume_renewal_challenge(dev, ch);
 IF NOT FOUND THEN RETURN NULL; END IF;
 IF proof IS NOT TRUE OR r.nonce_sha256 <> nonce THEN RETURN NULL; END IF;
 RETURN ap_m1.issue_renewal_credential(dev, ch, tok, life);
END $f$;

\set famC 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
\set famD 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
\set parC1 'c0000000-0000-4000-8000-000000000001'
\set parC2 'c0000000-0000-4000-8000-000000000002'
\set parC3 'c0000000-0000-4000-8000-000000000003'
\set parC9 'c0000000-0000-4000-8000-000000000009'
\set parD1 'd0000000-0000-4000-8000-000000000001'
\set chC 'c1000000-0000-4000-8000-000000000001'
\set chD 'd1000000-0000-4000-8000-000000000001'
\set devA 'c3000000-0000-4000-8000-000000000001'
\set devR 'c3000000-0000-4000-8000-000000000002'
\set devP 'c3000000-0000-4000-8000-000000000003'
\set devV 'c3000000-0000-4000-8000-000000000004'
\set devD 'd3000000-0000-4000-8000-000000000001'
\set devC 'c3000000-0000-4000-8000-000000000005'

-- ---------------------------------------------------------------- fixtures
BEGIN;
INSERT INTO ap_m1.families(id,label) VALUES (:'famC','synthetic C'),(:'famD','synthetic D');
INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES
 (:'parC1','https://example.invalid','cl-parent-c1'),(:'parC2','https://example.invalid','cl-parent-c2'),
 (:'parC3','https://example.invalid','cl-parent-c3'),(:'parC9','https://example.invalid','cl-parent-c9'),
 (:'parD1','https://example.invalid','cl-parent-d1');
INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role,revoked_at) VALUES
 (:'famC',:'parC1','OWNER',NULL),(:'famC',:'parC2','GUARDIAN',NULL),
 (:'famC',:'parC3','GUARDIAN',now()),(:'famD',:'parD1','OWNER',NULL);
INSERT INTO ap_m1.children(id,family_id,alias) VALUES
 (:'chC',:'famC','C child'),(:'chD',:'famD','D child');
INSERT INTO ap_m1.child_guardian_grants(family_id,child_id,principal_id,scope) VALUES
 (:'famC',:'chC',:'parC1','VIEW_CHILD_DEVICES'),(:'famC',:'chC',:'parC1','REVOKE_CHILD_DEVICE'),
 (:'famD',:'chD',:'parD1','VIEW_CHILD_DEVICES'),(:'famD',:'chD',:'parD1','REVOKE_CHILD_DEVICE');
INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state,revoked_at) VALUES
 (:'devA',:'famC',:'chC',decode(repeat('a1',90),'hex'),'ACTIVE',NULL),
 (:'devR',:'famC',:'chC',decode(repeat('a2',90),'hex'),'ACTIVE',NULL),
 (:'devP',:'famC',:'chC',decode(repeat('a3',90),'hex'),'PENDING_PROOF',NULL),
 (:'devV',:'famC',:'chC',decode(repeat('a4',90),'hex'),'REVOKED',now()),
 (:'devD',:'famD',:'chD',decode(repeat('d1',90),'hex'),'ACTIVE',NULL),
 (:'devC',:'famC',:'chC',decode(repeat('a5',90),'hex'),'ACTIVE',NULL);
INSERT INTO ap_m1.device_key_records(device_id,fingerprint_sha256,state,revoked_at)
 SELECT id, sha256(spki_public_key), 'ACTIVE', NULL FROM ap_m1.devices
 WHERE id IN (:'devA',:'devR',:'devD',:'devC');
INSERT INTO ap_m1.device_key_records(device_id,fingerprint_sha256,state,revoked_at)
 SELECT id, sha256(spki_public_key), 'REVOKED', now() FROM ap_m1.devices WHERE id=:'devV';
-- Initial credentials (issued at enrollment by a flow this migration does not define).
INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at,revoked_at)
 SELECT d.id,k.key_id,sha256(convert_to(t.tok,'UTF8')),'ENROLLMENT',t.issued,t.expires,t.revoked
 FROM (VALUES
  ('c3000000-0000-4000-8000-000000000001'::uuid,'tok-a-valid',     now(),                 now()+interval '1 hour',  NULL::timestamptz),
  ('c3000000-0000-4000-8000-000000000001'::uuid,'tok-a-expired',   now()-interval '2 hours', now()-interval '1 hour', NULL),
  ('c3000000-0000-4000-8000-000000000001'::uuid,'tok-a-revoked',   now(),                 now()+interval '1 hour',  now()),
  ('c3000000-0000-4000-8000-000000000002'::uuid,'tok-r-valid',     now(),                 now()+interval '1 hour',  NULL),
  ('d3000000-0000-4000-8000-000000000001'::uuid,'tok-d-valid',     now(),                 now()+interval '1 hour',  NULL)
 ) AS t(dev,tok,issued,expires,revoked)
 JOIN ap_m1.devices d ON d.id=t.dev
 JOIN ap_m1.device_key_records k ON k.device_id=d.id AND k.state='ACTIVE';
COMMIT;

-- ------------------------------------------- CL_01..04 schema and privilege boundaries
DO $t$
DECLARE n integer; r text;
BEGIN
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace
  WHERE s.nspname='ap_m1' AND c.relname IN ('device_credentials','credential_renewal_challenges')
    AND c.relrowsecurity AND c.relforcerowsecurity;
 PERFORM public.ap_m1_test_expect(n=2,'CL_01 both credential tables must have forced RLS');
 SELECT count(*) INTO n FROM pg_policies WHERE schemaname='ap_m1'
  AND tablename IN ('device_credentials','credential_renewal_challenges');
 PERFORM public.ap_m1_test_expect(n=0,'CL_01 credential tables are deny-all: no policies expected');
 FOREACH r IN ARRAY ARRAY['device_credentials','credential_renewal_challenges'] LOOP
  PERFORM public.ap_m1_test_expect(NOT (has_table_privilege('ap_m1_api','ap_m1.'||r,'SELECT')
    OR has_table_privilege('ap_m1_api','ap_m1.'||r,'INSERT')
    OR has_table_privilege('ap_m1_api','ap_m1.'||r,'UPDATE')
    OR has_table_privilege('ap_m1_api','ap_m1.'||r,'DELETE')),'CL_02 app role has direct access to '||r);
 END LOOP;
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
  JOIN pg_roles o ON o.oid=p.proowner
  WHERE s.nspname='ap_m1' AND p.proname IN ('authenticate_device_credential','device_public_key',
   'issue_credential_renewal_challenge','consume_renewal_challenge','issue_renewal_credential',
   'list_my_families','redeem_pairing_code','consume_enrollment_challenge','activate_enrolled_device',
   'purge_credential_artifacts')
   AND p.prosecdef AND o.rolname='ap_m1_auth'
   AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%');
 PERFORM public.ap_m1_test_expect(n=10,'CL_03 all 10 functions must be SECURITY DEFINER, owned by ap_m1_auth, with pinned search_path');
 -- Generic: NO function in the schema (including future ones) may be executable by PUBLIC.
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
  WHERE s.nspname='ap_m1'
   AND (p.proacl IS NULL OR EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee=0));
 PERFORM public.ap_m1_test_expect(n=0,'CL_04 every ap_m1 function must be revoked from PUBLIC, found '||n);
 PERFORM public.ap_m1_test_expect(has_function_privilege('ap_m1_api','ap_m1.consume_renewal_challenge(uuid,uuid)','EXECUTE')
  AND has_function_privilege('ap_m1_api','ap_m1.redeem_pairing_code(bytea,bytea,bytea,integer)','EXECUTE'),
  'CL_04 the API role must be able to run the credential and enrollment functions');
 PERFORM public.ap_m1_test_expect(NOT has_function_privilege('ap_m1_api','ap_m1.purge_credential_artifacts(interval,interval,interval)','EXECUTE'),
  'CL_04 the retention job must not be executable by the API role');
END $t$;

-- Hard ceilings in the table itself, whatever the backend configures.
DO $t$
DECLARE refused boolean;
BEGIN
 refused:=false;
 BEGIN
  INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at)
  SELECT d.id,k.key_id,sha256('too-long'::bytea),'RENEWAL',now(),now()+interval '25 hours'
  FROM ap_m1.devices d JOIN ap_m1.device_key_records k ON k.device_id=d.id
  WHERE d.id='c3000000-0000-4000-8000-000000000001' AND k.state='ACTIVE';
 EXCEPTION WHEN check_violation THEN refused:=true; END;
 PERFORM public.ap_m1_test_expect(refused,'CL_05 a 25-hour credential must be refused by CHECK');
 refused:=false;
 BEGIN
  INSERT INTO ap_m1.credential_renewal_challenges(device_id,key_id,nonce_sha256,expires_at)
  SELECT d.id,k.key_id,sha256('x'::bytea),now()+interval '10 minutes'
  FROM ap_m1.devices d JOIN ap_m1.device_key_records k ON k.device_id=d.id
  WHERE d.id='c3000000-0000-4000-8000-000000000001' AND k.state='ACTIVE';
 EXCEPTION WHEN check_violation THEN refused:=true; END;
 PERFORM public.ap_m1_test_expect(refused,'CL_05 a 10-minute challenge must be refused by CHECK');
END $t$;

-- ------------------------------------------- CL_06..08 runtime role: no direct table access
SET ROLE ap_m1_api;
DO $t$
DECLARE refused boolean;
BEGIN
 refused:=false;
 BEGIN PERFORM 1 FROM ap_m1.device_credentials; EXCEPTION WHEN insufficient_privilege THEN refused:=true; END;
 PERFORM public.ap_m1_test_expect(refused,'CL_06 app role must not SELECT credentials');
 refused:=false;
 BEGIN INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,expires_at)
  VALUES (gen_random_uuid(),gen_random_uuid(),sha256('x'::bytea),'RENEWAL',now()+interval '1 hour');
 EXCEPTION WHEN insufficient_privilege THEN refused:=true; END;
 PERFORM public.ap_m1_test_expect(refused,'CL_07 app role must not INSERT credentials');
 refused:=false;
 BEGIN PERFORM 1 FROM ap_m1.credential_renewal_challenges; EXCEPTION WHEN insufficient_privilege THEN refused:=true; END;
 PERFORM public.ap_m1_test_expect(refused,'CL_08 app role must not SELECT challenges');
END $t$;

-- ------------------------------------------- CL_09..12 authenticate_device_credential
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-a-valid','UTF8'))))=1,
 'CL_09 valid token must authenticate exactly one device');
SELECT public.ap_m1_test_expect((SELECT device_id FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-a-valid','UTF8'))))=:'devA'
 AND (SELECT family_id FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-a-valid','UTF8'))))=:'famC',
 'CL_09 token must resolve to its own device and family');
SELECT public.ap_m1_test_expect((SELECT family_id FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-d-valid','UTF8'))))=:'famD',
 'CL_10 family D token must resolve to family D, never family C');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-a-expired','UTF8'))))=0,
 'CL_11 expired token must not authenticate');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-a-revoked','UTF8'))))=0,
 'CL_11 revoked token must not authenticate');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('never-issued','UTF8'))))=0,
 'CL_12 unknown token must not authenticate');

-- ------------------------------------------- CL_13 device_public_key
SELECT public.ap_m1_test_expect(ap_m1.device_public_key(:'devA')=decode(repeat('a1',90),'hex'),'CL_13 active device returns its public key');
SELECT public.ap_m1_test_expect(ap_m1.device_public_key(:'devP') IS NULL,'CL_13 pending device returns NULL');
SELECT public.ap_m1_test_expect(ap_m1.device_public_key(:'devV') IS NULL,'CL_13 revoked device returns NULL');
SELECT public.ap_m1_test_expect(ap_m1.device_public_key(gen_random_uuid()) IS NULL,'CL_13 unknown device returns NULL');

-- ------------------------------------------- CL_14 issue_credential_renewal_challenge negatives
SELECT public.ap_m1_test_expect(ap_m1.issue_credential_renewal_challenge(:'devA',sha256('wrong-key'::bytea),sha256('n'::bytea),120) IS NULL,
 'CL_14 wrong key fingerprint must not yield a challenge');
SELECT public.ap_m1_test_expect(ap_m1.issue_credential_renewal_challenge(gen_random_uuid(),sha256(decode(repeat('a1',90),'hex')),sha256('n'::bytea),120) IS NULL,
 'CL_14 unknown device must not yield a challenge');
SELECT public.ap_m1_test_expect(ap_m1.issue_credential_renewal_challenge(:'devP',sha256(decode(repeat('a3',90),'hex')),sha256('n'::bytea),120) IS NULL,
 'CL_14 pending device must not yield a challenge');
SELECT public.ap_m1_test_expect(ap_m1.issue_credential_renewal_challenge(:'devV',sha256(decode(repeat('a4',90),'hex')),sha256('n'::bytea),120) IS NULL,
 'CL_14 revoked device must not yield a challenge');
DO $t$
DECLARE issued integer := 0; got uuid;
BEGIN
 LOOP
  got := ap_m1.issue_credential_renewal_challenge('c3000000-0000-4000-8000-000000000005',
          sha256(decode(repeat('a5',90),'hex')), sha256(convert_to('cap-'||issued,'UTF8')), 120);
  EXIT WHEN got IS NULL OR issued >= 20;
  issued := issued + 1;
 END LOOP;
 PERFORM public.ap_m1_test_expect(issued=5,'CL_14 open challenges per device must be capped at 5, got '||issued);
END $t$;

-- ------------------------------------------- CL_15 argument bounds
DO $t$
DECLARE bad integer; refused boolean;
BEGIN
 FOREACH bad IN ARRAY ARRAY[0,10,301,100000] LOOP
  refused:=false;
  BEGIN PERFORM ap_m1.issue_credential_renewal_challenge('c3000000-0000-4000-8000-000000000001',
        sha256(decode(repeat('a1',90),'hex')),sha256('n'::bytea),bad);
  EXCEPTION WHEN invalid_parameter_value THEN refused:=true; END;
  PERFORM public.ap_m1_test_expect(refused,'CL_15 challenge ttl '||bad||' must be refused');
 END LOOP;
 FOREACH bad IN ARRAY ARRAY[0,30,299,86401,1000000] LOOP
  refused:=false;
  BEGIN PERFORM ap_m1.issue_renewal_credential('c3000000-0000-4000-8000-000000000001',
        gen_random_uuid(),sha256(convert_to('b'||bad,'UTF8')),bad);
  EXCEPTION WHEN invalid_parameter_value THEN refused:=true; END;
  PERFORM public.ap_m1_test_expect(refused,'CL_15 credential lifetime '||bad||' must be refused');
 END LOOP;
END $t$;

-- ------------------------------------------- CL_16..18 renewal happy path and rotation
SELECT ap_m1.issue_credential_renewal_challenge(:'devA',sha256(decode(repeat('a1',90),'hex')),sha256(convert_to('nonce-1','UTF8')),120) AS ch1 \gset
SELECT public.ap_m1_test_expect(:'ch1' <> '','CL_16 valid fingerprint must yield a challenge');
SELECT public.ap_m1_test_expect(
 public.t_renew(:'devA',:'ch1',sha256(convert_to('nonce-1','UTF8')),true,sha256(convert_to('tok-a-renewed','UTF8')),3600)
  > now()+interval '59 minutes','CL_16 renewal must return an expiry about one hour out');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-a-renewed','UTF8'))))=1,
 'CL_17 renewed token must authenticate');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-a-valid','UTF8'))))=0,
 'CL_17 the previous credential must be revoked by renewal');
RESET ROLE;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.device_credentials WHERE device_id=:'devA' AND revoked_at IS NULL AND expires_at>now())=1,
 'CL_18 exactly one live credential per device after renewal');
SET ROLE ap_m1_api;

-- ------------------------------------------- CL_19 single use
SELECT public.ap_m1_test_expect(
 public.t_renew(:'devA',:'ch1',sha256(convert_to('nonce-1','UTF8')),true,sha256(convert_to('tok-a-second','UTF8')),3600) IS NULL,
 'CL_19 a used challenge must not be accepted again');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-a-second','UTF8'))))=0,
 'CL_19 a replayed challenge must not mint a credential');

-- ------------------------------------------- CL_20 failed proof burns the challenge
SELECT ap_m1.issue_credential_renewal_challenge(:'devA',sha256(decode(repeat('a1',90),'hex')),sha256(convert_to('nonce-2','UTF8')),120) AS ch2 \gset
SELECT public.ap_m1_test_expect(
 public.t_renew(:'devA',:'ch2',sha256(convert_to('nonce-2','UTF8')),false,sha256(convert_to('tok-bad-proof','UTF8')),3600) IS NULL,
 'CL_20 failed signature must return NULL');
SELECT public.ap_m1_test_expect(
 public.t_renew(:'devA',:'ch2',sha256(convert_to('nonce-2','UTF8')),true,sha256(convert_to('tok-after-bad','UTF8')),3600) IS NULL,
 'CL_20 a challenge that saw a failed proof must be burned');

-- ------------------------------------------- CL_21 wrong nonce burns the challenge
SELECT ap_m1.issue_credential_renewal_challenge(:'devA',sha256(decode(repeat('a1',90),'hex')),sha256(convert_to('nonce-3','UTF8')),120) AS ch3 \gset
SELECT public.ap_m1_test_expect(
 public.t_renew(:'devA',:'ch3',sha256(convert_to('not-the-nonce','UTF8')),true,sha256(convert_to('tok-wrong-nonce','UTF8')),3600) IS NULL,
 'CL_21 wrong nonce must return NULL');
SELECT public.ap_m1_test_expect(
 public.t_renew(:'devA',:'ch3',sha256(convert_to('nonce-3','UTF8')),true,sha256(convert_to('tok-after-wrong','UTF8')),3600) IS NULL,
 'CL_21 a challenge that saw a wrong nonce must be burned');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-after-wrong','UTF8'))))=0,
 'CL_21 no credential may exist after burned challenges');

-- ------------------------------------------- CL_22 spent challenge cannot be revived; step 2 is safe to retry
-- Step 1 commits on its own (autocommit), so the burn is durable before any signature is checked.
SELECT ap_m1.issue_credential_renewal_challenge(:'devA',sha256(decode(repeat('a1',90),'hex')),sha256(convert_to('nonce-4','UTF8')),120) AS ch4 \gset
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.consume_renewal_challenge(:'devA',:'ch4'))=1,'CL_22 first consume returns the nonce hash and key');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.consume_renewal_challenge(:'devA',:'ch4'))=0,'CL_22 a second consume must return nothing');
-- Step 2 inside a transaction that rolls back: the challenge is still consumed (committed), and the issue can be retried.
BEGIN;
SELECT public.ap_m1_test_expect(ap_m1.issue_renewal_credential(:'devA',:'ch4',sha256(convert_to('tok-x','UTF8')),3600) IS NOT NULL,'CL_22 issue inside tx');
ROLLBACK;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.consume_renewal_challenge(:'devA',:'ch4'))=0,'CL_22 a rolled-back step 2 must not make the challenge consumable again');
SELECT public.ap_m1_test_expect(ap_m1.issue_renewal_credential(:'devA',:'ch4',sha256(convert_to('tok-after-rollback','UTF8')),3600) IS NOT NULL,
 'CL_22 step 2 is retryable within 60 s after a rollback (signature was already verified)');
SELECT public.ap_m1_test_expect(ap_m1.issue_renewal_credential(:'devA',:'ch4',sha256(convert_to('tok-twice','UTF8')),3600) IS NULL,
 'CL_22 a redeemed challenge must not issue a second credential');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-twice','UTF8'))))=0,
 'CL_22 no credential from a second redemption');
-- Step 2 without step 1 must fail.
SELECT ap_m1.issue_credential_renewal_challenge(:'devA',sha256(decode(repeat('a1',90),'hex')),sha256(convert_to('nonce-5','UTF8')),120) AS ch5 \gset
SELECT public.ap_m1_test_expect(ap_m1.issue_renewal_credential(:'devA',:'ch5',sha256(convert_to('tok-skip','UTF8')),3600) IS NULL,
 'CL_22 issuing without consuming first must fail');

-- Step 2 more than 60 s after step 1 must fail (the signature check cannot be allowed to sit forever).
SELECT ap_m1.issue_credential_renewal_challenge(:'devA',sha256(decode(repeat('a1',90),'hex')),sha256(convert_to('nonce-6','UTF8')),120) AS ch6 \gset
SELECT count(*) AS c FROM ap_m1.consume_renewal_challenge(:'devA',:'ch6') \gset
RESET ROLE;
UPDATE ap_m1.credential_renewal_challenges SET consumed_at = now() - interval '2 minutes' WHERE id = :'ch6';
SET ROLE ap_m1_api;
SELECT public.ap_m1_test_expect(ap_m1.issue_renewal_credential(:'devA',:'ch6',sha256(convert_to('tok-stale-renew','UTF8')),3600) IS NULL,
 'CL_22 issuing more than 60 s after the signature check must fail');

-- ------------------------------------------- CL_23 expired challenge
RESET ROLE;
INSERT INTO ap_m1.credential_renewal_challenges(device_id,key_id,nonce_sha256,expires_at,created_at)
 SELECT d.id,k.key_id,sha256(convert_to('nonce-old','UTF8')),now()-interval '1 minute',now()-interval '6 minutes'
 FROM ap_m1.devices d JOIN ap_m1.device_key_records k ON k.device_id=d.id AND k.state='ACTIVE'
 WHERE d.id=:'devA' RETURNING id AS chold \gset
SET ROLE ap_m1_api;
SELECT public.ap_m1_test_expect(
 public.t_renew(:'devA',:'chold',sha256(convert_to('nonce-old','UTF8')),true,sha256(convert_to('tok-from-expired','UTF8')),3600) IS NULL,
 'CL_23 an expired challenge must not be accepted');

-- ------------------------------------------- CL_24 a challenge is bound to its device
SELECT ap_m1.issue_credential_renewal_challenge(:'devD',sha256(decode(repeat('d1',90),'hex')),sha256(convert_to('nonce-d','UTF8')),120) AS chdev \gset
SELECT public.ap_m1_test_expect(
 public.t_renew(:'devA',:'chdev',sha256(convert_to('nonce-d','UTF8')),true,sha256(convert_to('tok-cross','UTF8')),3600) IS NULL,
 'CL_24 family D challenge presented for device A in family C must fail');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-cross','UTF8'))))=0,
 'CL_24 no credential may be minted across devices');
SELECT public.ap_m1_test_expect(
 public.t_renew(:'devD',:'chdev',sha256(convert_to('nonce-d','UTF8')),true,sha256(convert_to('tok-d-renewed','UTF8')),3600) IS NOT NULL,
 'CL_24 control: the same challenge works for its own device');

-- ------------------------------------------- CL_25..27 parent revocation cuts off the device
SET ap.family_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
SET ap.principal_id = 'd0000000-0000-4000-8000-000000000001';
DO $t$
DECLARE n integer;
BEGIN
 UPDATE ap_m1.devices SET enrollment_state='REVOKED', revoked_at=now()
  WHERE id='c3000000-0000-4000-8000-000000000001';
 GET DIAGNOSTICS n = ROW_COUNT;
 PERFORM public.ap_m1_test_expect(n=0,'CL_25 parent of family D must not be able to revoke a family C device');
END $t$;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-after-rollback','UTF8'))))=1,
 'CL_25 device A (newest credential, from CL_22) must be unaffected by the foreign revoke attempt');
SET ap.family_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
SET ap.principal_id = 'c0000000-0000-4000-8000-000000000001';
SELECT ap_m1.issue_credential_renewal_challenge(:'devR',sha256(decode(repeat('a2',90),'hex')),sha256(convert_to('nonce-r','UTF8')),120) AS chr \gset
DO $t$
DECLARE n integer;
BEGIN
 UPDATE ap_m1.devices SET enrollment_state='REVOKED', revoked_at=now()
  WHERE id='c3000000-0000-4000-8000-000000000002';
 GET DIAGNOSTICS n = ROW_COUNT;
 PERFORM public.ap_m1_test_expect(n=1,'CL_26 the owner with REVOKE_CHILD_DEVICE must be able to revoke device R');
END $t$;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256(convert_to('tok-r-valid','UTF8'))))=0,
 'CL_26 a revoked device must not authenticate, though its credential row is unexpired');
SELECT public.ap_m1_test_expect(ap_m1.issue_credential_renewal_challenge(:'devR',sha256(decode(repeat('a2',90),'hex')),sha256('n'::bytea),120) IS NULL,
 'CL_27 a revoked device must not receive a new challenge');
SELECT public.ap_m1_test_expect(
 public.t_renew(:'devR',:'chr',sha256(convert_to('nonce-r','UTF8')),true,sha256(convert_to('tok-r-after-revoke','UTF8')),3600) IS NULL,
 'CL_27 a challenge issued before revocation must not renew a revoked device');
SELECT public.ap_m1_test_expect(ap_m1.device_public_key(:'devR') IS NULL,'CL_27 a revoked device exposes no public key');

-- ------------------------------------------- CL_28..32 list_my_families
RESET ap.family_id;
SET ap.principal_id = 'c0000000-0000-4000-8000-000000000001';
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.list_my_families())=1
 AND (SELECT id FROM ap_m1.list_my_families())=:'famC' AND (SELECT membership_role FROM ap_m1.list_my_families())='OWNER',
 'CL_28 owner sees exactly their own family with role OWNER');
SET ap.principal_id = 'c0000000-0000-4000-8000-000000000002';
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.list_my_families())=1
 AND (SELECT membership_role FROM ap_m1.list_my_families())='GUARDIAN',
 'CL_29 a guardian with no child grants still sees the family, as GUARDIAN');
SET ap.principal_id = 'c0000000-0000-4000-8000-000000000003';
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.list_my_families())=0,'CL_30 a revoked membership must not list the family');
SET ap.principal_id = 'd0000000-0000-4000-8000-000000000001';
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.list_my_families())=1
 AND (SELECT id FROM ap_m1.list_my_families())=:'famD','CL_31 parent D sees only family D');
SET ap.principal_id = 'c0000000-0000-4000-8000-000000000009';
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.list_my_families())=0,'CL_32 a principal with no membership sees nothing');
RESET ap.principal_id;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.list_my_families())=0,'CL_32 no principal context must list nothing');

RESET ROLE;
DROP FUNCTION public.t_renew(uuid,uuid,bytea,boolean,bytea,integer);
DROP FUNCTION public.ap_m1_test_expect(boolean,text);
\echo 'M1 credential lifecycle PASS: deny-all tables, definer-only access, auth, renewal, single use, burn on failure, device binding, revocation, family listing'
