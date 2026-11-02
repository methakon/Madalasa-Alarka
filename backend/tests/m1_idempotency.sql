-- Madalasa-Alarka M1 PostgreSQL 15+ regression: idempotency keys (migration 0004).
-- Run on a FRESH isolated CI database after migrations 0001..0004 (may follow the other SQL tests; own fixtures,
-- UUID prefix 1d). Concurrency is covered separately by m1_idempotency_concurrency.sh.
-- SYNTHETIC DATA ONLY. Every assertion raises on failure; ON_ERROR_STOP makes psql exit non-zero.
\set ON_ERROR_STOP on

CREATE FUNCTION public.ap_m1_test_expect(cond boolean, msg text) RETURNS void
 LANGUAGE plpgsql AS $f$
BEGIN
 IF cond IS NOT TRUE THEN RAISE EXCEPTION 'M1_IDEMPOTENCY_TEST_FAILURE: %', msg; END IF;
END $f$;

\set actA '1d000000-0000-4000-8000-00000000000a'
\set actB '1d000000-0000-4000-8000-00000000000b'
INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES
 (:'actA','https://example.invalid','idem-actor-a'),(:'actB','https://example.invalid','idem-actor-b');

-- ------------------------------------------- ID_01 table and function boundaries
DO $t$
DECLARE n integer; refused boolean := false;
BEGIN
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace
  WHERE s.nspname='ap_m1' AND c.relname='idempotency_keys' AND c.relrowsecurity AND c.relforcerowsecurity;
 PERFORM public.ap_m1_test_expect(n=1,'ID_01 idempotency_keys must have forced RLS');
 SELECT count(*) INTO n FROM pg_policies WHERE schemaname='ap_m1' AND tablename='idempotency_keys';
 PERFORM public.ap_m1_test_expect(n=0,'ID_01 deny-all: no policies expected');
 PERFORM public.ap_m1_test_expect(NOT (has_table_privilege('ap_m1_api','ap_m1.idempotency_keys','SELECT')
   OR has_table_privilege('ap_m1_api','ap_m1.idempotency_keys','INSERT')
   OR has_table_privilege('ap_m1_api','ap_m1.idempotency_keys','UPDATE')
   OR has_table_privilege('ap_m1_api','ap_m1.idempotency_keys','DELETE')),'ID_01 app role must have no direct table access');
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace JOIN pg_roles o ON o.oid=p.proowner
  WHERE s.nspname='ap_m1' AND p.proname IN ('idempotency_claim','idempotency_record','purge_idempotency_keys')
    AND p.prosecdef AND o.rolname='ap_m1_auth' AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%');
 PERFORM public.ap_m1_test_expect(n=3,'ID_01 all 3 functions SECURITY DEFINER, owned by ap_m1_auth, pinned search_path');
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
  WHERE s.nspname='ap_m1' AND (p.proacl IS NULL OR EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee=0));
 PERFORM public.ap_m1_test_expect(n=0,'ID_01 no ap_m1 function may be executable by PUBLIC, found '||n);
 PERFORM public.ap_m1_test_expect(NOT has_function_privilege('ap_m1_api','ap_m1.purge_idempotency_keys(interval)','EXECUTE'),
   'ID_01 the purge must not be executable by the API role');
END $t$;

SET ROLE ap_m1_api;
DO $t$
DECLARE refused boolean := false;
BEGIN
 BEGIN PERFORM 1 FROM ap_m1.idempotency_keys; EXCEPTION WHEN insufficient_privilege THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'ID_01 app role must not read the table');
 refused := false;
 BEGIN PERFORM ap_m1.purge_idempotency_keys(); EXCEPTION WHEN insufficient_privilege THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'ID_01 app role must not run the purge');
END $t$;

-- ------------------------------------------- ID_02 new, record, replay
SELECT public.ap_m1_test_expect((SELECT outcome FROM ap_m1.idempotency_claim(:'actA','POST /families',sha256('k1'::bytea),sha256('req1'::bytea)))='NEW',
 'ID_02 first claim is NEW');
SELECT public.ap_m1_test_expect(ap_m1.idempotency_record(:'actA','POST /families',sha256('k1'::bytea),201,'{"id":"f1"}'::jsonb),
 'ID_02 recording the result succeeds');
SELECT public.ap_m1_test_expect(
 (SELECT outcome||response_status||response_body::text||body_omitted FROM ap_m1.idempotency_claim(:'actA','POST /families',sha256('k1'::bytea),sha256('req1'::bytea)))
 = 'REPLAY201{"id": "f1"}false','ID_02 same key and body replays the stored status and body');
SELECT public.ap_m1_test_expect(NOT ap_m1.idempotency_record(:'actA','POST /families',sha256('k1'::bytea),201,'{"id":"other"}'::jsonb),
 'ID_02 a result cannot be recorded twice');
SELECT public.ap_m1_test_expect((SELECT response_body->>'id' FROM ap_m1.idempotency_claim(:'actA','POST /families',sha256('k1'::bytea),sha256('req1'::bytea)))='f1',
 'ID_02 the first recorded result stays');

-- ------------------------------------------- ID_03 changed body is a mismatch and reveals nothing
SELECT public.ap_m1_test_expect(
 (SELECT outcome||coalesce(response_status::text,'null')||coalesce(response_body::text,'null')
    FROM ap_m1.idempotency_claim(:'actA','POST /families',sha256('k1'::bytea),sha256('DIFFERENT'::bytea)))='MISMATCHnullnull',
 'ID_03 same key with a different body must be MISMATCH and must not return the stored response');

-- ------------------------------------------- ID_04 scoped by actor and by route
SELECT public.ap_m1_test_expect((SELECT outcome FROM ap_m1.idempotency_claim(:'actB','POST /families',sha256('k1'::bytea),sha256('req1'::bytea)))='NEW',
 'ID_04 another actor using the same key gets NEW (no cross-actor collision or oracle)');
SELECT public.ap_m1_test_expect((SELECT outcome FROM ap_m1.idempotency_claim(:'actA','POST /children',sha256('k1'::bytea),sha256('req1'::bytea)))='NEW',
 'ID_04 the same key on another route gets NEW');

-- ------------------------------------------- ID_05 rollback leaves nothing behind
BEGIN;
SELECT public.ap_m1_test_expect((SELECT outcome FROM ap_m1.idempotency_claim(:'actA','POST /families',sha256('k-rb'::bytea),sha256('r'::bytea)))='NEW','ID_05 claim inside tx');
ROLLBACK;
SELECT public.ap_m1_test_expect((SELECT outcome FROM ap_m1.idempotency_claim(:'actA','POST /families',sha256('k-rb'::bytea),sha256('r'::bytea)))='NEW',
 'ID_05 after a rollback the key is free again');
SELECT ap_m1.idempotency_record(:'actA','POST /families',sha256('k-rb'::bytea),201,'{}'::jsonb) AS _ \gset

-- ------------------------------------------- ID_06 secret-bearing responses are not stored
SELECT public.ap_m1_test_expect((SELECT outcome FROM ap_m1.idempotency_claim(:'actA','POST /children/{childId}/pairing-codes',sha256('k-pc'::bytea),sha256('r'::bytea)))='NEW','ID_06 claim');
SELECT public.ap_m1_test_expect(ap_m1.idempotency_record(:'actA','POST /children/{childId}/pairing-codes',sha256('k-pc'::bytea),201,'{"pairing_code":"SECRET123"}'::jsonb,true),
 'ID_06 record with the body omitted');
SELECT public.ap_m1_test_expect(
 (SELECT outcome||response_status||coalesce(response_body::text,'null')||body_omitted FROM ap_m1.idempotency_claim(:'actA','POST /children/{childId}/pairing-codes',sha256('k-pc'::bytea),sha256('r'::bytea)))
 = 'REPLAY201nulltrue','ID_06 replay reports body_omitted and returns no body');
RESET ROLE;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.idempotency_keys WHERE response_body::text LIKE '%SECRET123%')=0,
 'ID_06 the secret must not be present anywhere in the table');
SET ROLE ap_m1_api;

-- ------------------------------------------- ID_07 a committed claim with no result is PENDING (backend bug signal)
SELECT public.ap_m1_test_expect((SELECT outcome FROM ap_m1.idempotency_claim(:'actA','POST /families',sha256('k-pend'::bytea),sha256('r'::bytea)))='NEW','ID_07 claim, no record');
SELECT public.ap_m1_test_expect((SELECT outcome FROM ap_m1.idempotency_claim(:'actA','POST /families',sha256('k-pend'::bytea),sha256('r'::bytea)))='PENDING',
 'ID_07 an unfinished committed claim is reported as PENDING');

-- ------------------------------------------- ID_08 expiry frees the key
RESET ROLE;
UPDATE ap_m1.idempotency_keys SET created_at = now() - interval '2 days', expires_at = now() - interval '1 day' - interval '1 hour'
 WHERE actor_id = :'actA'::uuid AND key_sha256 = sha256('k1'::bytea) AND namespace = 'POST /families';
SET ROLE ap_m1_api;
SELECT public.ap_m1_test_expect((SELECT outcome FROM ap_m1.idempotency_claim(:'actA','POST /families',sha256('k1'::bytea),sha256('brand-new-body'::bytea)))='NEW',
 'ID_08 an expired key can be reused, even with a different body');
SELECT public.ap_m1_test_expect(ap_m1.idempotency_record(:'actA','POST /families',sha256('k1'::bytea),201,'{"id":"f2"}'::jsonb),'ID_08 and recorded again');

-- ------------------------------------------- ID_09 bounds
DO $t$
DECLARE bad integer; refused boolean;
BEGIN
 FOREACH bad IN ARRAY ARRAY[0,59,86401,10000000] LOOP
  refused := false;
  BEGIN PERFORM ap_m1.idempotency_claim('1d000000-0000-4000-8000-00000000000a','POST /families',sha256('k-b'::bytea),sha256('r'::bytea),bad);
  EXCEPTION WHEN invalid_parameter_value THEN refused := true; END;
  PERFORM public.ap_m1_test_expect(refused,'ID_09 ttl '||bad||' must be refused');
 END LOOP;
 refused := false;
 BEGIN PERFORM ap_m1.idempotency_claim('1d000000-0000-4000-8000-00000000000a','POST /families','short'::bytea,sha256('r'::bytea));
 EXCEPTION WHEN check_violation THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'ID_09 a key hash that is not 32 bytes must be refused');
 refused := false;
 BEGIN PERFORM ap_m1.idempotency_claim('1d000000-0000-4000-8000-00000000000a','get /families',sha256('k-c'::bytea),sha256('r'::bytea));
 EXCEPTION WHEN check_violation THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'ID_09 a malformed namespace must be refused');
 refused := false;
 BEGIN PERFORM ap_m1.idempotency_claim(gen_random_uuid(),'POST /families',sha256('k-d'::bytea),sha256('r'::bytea));
 EXCEPTION WHEN foreign_key_violation THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'ID_09 an unknown actor must be refused');
 PERFORM ap_m1.idempotency_claim('1d000000-0000-4000-8000-00000000000a','POST /families',sha256('k-e'::bytea),sha256('r'::bytea));
 refused := false;
 BEGIN PERFORM ap_m1.idempotency_record('1d000000-0000-4000-8000-00000000000a','POST /families',sha256('k-e'::bytea),301,'{}'::jsonb);
 EXCEPTION WHEN check_violation THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'ID_09 only 2xx results may be stored');
 refused := false;
 BEGIN PERFORM ap_m1.idempotency_record('1d000000-0000-4000-8000-00000000000a','POST /families',sha256('k-e'::bytea),201,
        jsonb_build_object('pad', repeat('x', 9000)));
 EXCEPTION WHEN check_violation THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'ID_09 a body over 8 KiB must be refused');
END $t$;
SELECT public.ap_m1_test_expect(NOT ap_m1.idempotency_record(:'actA','POST /families',sha256('never-claimed'::bytea),201,'{}'::jsonb),
 'ID_09 recording without a claim returns false');

-- ------------------------------------------- ID_10 erasure: deleting a principal removes their keys
RESET ROLE;
INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES ('1d000000-0000-4000-8000-00000000000c','https://example.invalid','idem-actor-c');
SELECT count(*) AS c FROM ap_m1.idempotency_claim('1d000000-0000-4000-8000-00000000000c','POST /families',sha256('k-er'::bytea),sha256('r'::bytea)) \gset
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.idempotency_keys WHERE actor_id='1d000000-0000-4000-8000-00000000000c')=1,'ID_10 key exists');
DELETE FROM ap_m1.parent_principals WHERE id='1d000000-0000-4000-8000-00000000000c';
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.idempotency_keys WHERE actor_id='1d000000-0000-4000-8000-00000000000c')=0,
 'ID_10 erasing a principal removes their idempotency keys');

-- ------------------------------------------- ID_11 retention purge
UPDATE ap_m1.idempotency_keys SET created_at = now() - interval '3 days', expires_at = now() - interval '2 days'
 WHERE actor_id = :'actB'::uuid AND namespace = 'POST /children';
INSERT INTO ap_m1.idempotency_keys(actor_id,namespace,key_sha256,request_sha256,expires_at,created_at)
 VALUES (:'actB','POST /families',sha256('old'::bytea),sha256('r'::bytea),now()-interval '2 days',now()-interval '3 days');
INSERT INTO ap_m1.idempotency_keys(actor_id,namespace,key_sha256,request_sha256,expires_at,created_at)
 VALUES (:'actB','POST /families',sha256('recent'::bytea),sha256('r'::bytea),now()-interval '10 minutes',now()-interval '1 day');
DO $t$
DECLARE refused boolean := false;
BEGIN
 BEGIN PERFORM ap_m1.purge_idempotency_keys(interval '10 seconds'); EXCEPTION WHEN invalid_parameter_value THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'ID_11 a grace below one minute must be refused');
END $t$;
SET ROLE ap_m1_owner;
SELECT ap_m1.purge_idempotency_keys() AS purged \gset
RESET ROLE;
SELECT public.ap_m1_test_expect(:purged >= 1,'ID_11 the purge deletes keys expired more than the grace ago');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.idempotency_keys WHERE key_sha256=sha256('old'::bytea))=0,'ID_11 old key gone');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.idempotency_keys WHERE key_sha256=sha256('recent'::bytea))=1,'ID_11 recently expired key kept within the grace');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.idempotency_keys WHERE key_sha256=sha256('k-pc'::bytea))=1,'ID_11 live keys are never purged');

DROP FUNCTION public.ap_m1_test_expect(boolean,text);
\echo 'M1 idempotency PASS: deny-all table, replay, mismatch, per-actor scope, rollback, omitted secrets, pending, expiry, bounds, erasure, purge'
