-- Synthetic disposable database only. Run as migration admin with ON_ERROR_STOP.
-- Each fixture and helper is transaction-local; success and failure leave no committed data.
\set ON_ERROR_STOP on
DO $$ BEGIN
 IF current_database() <> 'amar_pola_m1' AND current_database() NOT LIKE 'ma_pr9_retention_%' THEN
  RAISE EXCEPTION 'retention matrix requires a dedicated synthetic retention database';
 END IF;
 IF EXISTS (SELECT 1 FROM ap_m1.families) OR EXISTS (SELECT 1 FROM ap_m1.parent_principals) THEN
  RAISE EXCEPTION 'retention matrix requires an empty fixture database; use a fresh isolated replay';
 END IF;
END $$;
BEGIN;
SET LOCAL statement_timeout = '30s';
CREATE FUNCTION pg_temp.check_ok(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'retention assertion: %',label; END IF; END $$;

-- Baseline regression deliberately does not depend on the new hold columns.
DO $$
DECLARE f uuid; c uuid; d uuid; n bigint;
BEGIN
 INSERT INTO ap_m1.families(label) VALUES ('synthetic retention regression') RETURNING id INTO f;
 INSERT INTO ap_m1.children(family_id,alias) VALUES(f,'synthetic') RETURNING id INTO c;
 INSERT INTO ap_m1.devices(family_id,child_id,spki_public_key,enrollment_state)
 VALUES(f,c,decode(repeat('aa',80),'hex'),'ACTIVE') RETURNING id INTO d;
 INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,created_at,expires_at,consumed_at,redeemed_at)
 VALUES(d,sha256('old enrollment'::bytea),now()-interval '10 days',now()-interval '10 days'+interval '1 minute',now()-interval '10 days',now()-interval '10 days');
 SELECT enrollment_challenges_deleted INTO n FROM ap_m1.purge_credential_artifacts();
 PERFORM pg_temp.check_ok(n=1,'completed ACTIVE enrollment expires after existing seven-day grace');
END $$;
ROLLBACK;

BEGIN;
SET LOCAL statement_timeout = '30s';
CREATE FUNCTION pg_temp.check_ok(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'retention assertion: %',label; END IF; END $$;
CREATE TEMP TABLE fixtures(label text PRIMARY KEY, id uuid NOT NULL);
CREATE FUNCTION pg_temp.device(label text, state text DEFAULT 'PENDING_PROOF', held boolean DEFAULT false)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE d uuid; f uuid; c uuid;
BEGIN
 SELECT id INTO f FROM fixtures WHERE fixtures.label='family';
 SELECT id INTO c FROM fixtures WHERE fixtures.label='child';
 INSERT INTO ap_m1.devices(family_id,child_id,spki_public_key,enrollment_state,retention_hold,created_at)
 VALUES(f,c,decode(repeat('ab',80),'hex'),state,held,now()-interval '90 days') RETURNING id INTO d;
 INSERT INTO fixtures VALUES(label,d); RETURN d;
END $$;
DO $$
DECLARE f uuid; c uuid; p uuid; d uuid; k uuid; i integer; r record; n bigint; v interval;
 before_a jsonb; before_k jsonb; before_e jsonb;
BEGIN
 INSERT INTO ap_m1.families(label) VALUES('synthetic retention comprehensive') RETURNING id INTO f;
 INSERT INTO ap_m1.children(family_id,alias) VALUES(f,'synthetic') RETURNING id INTO c;
 INSERT INTO ap_m1.parent_principals(oidc_issuer,oidc_subject) VALUES('https://example.invalid','retention') RETURNING id INTO p;
 INSERT INTO ap_m1.guardian_memberships VALUES(f,p,'OWNER',NULL,now());
 INSERT INTO fixtures VALUES('family',f),('child',c);
 INSERT INTO ap_m1.revocation_epochs(family_id,generation) VALUES(f,9);

 -- Enrollment: expired completed ACTIVE/REVOKED/PENDING, unconsumed pending,
 -- individually held, device-held, recent and still-live challenges.
 FOR i IN 1..8 LOOP
  d:=pg_temp.device('enrollment-'||i,CASE WHEN i=1 THEN 'ACTIVE' WHEN i=2 THEN 'REVOKED' ELSE 'PENDING_PROOF' END,i=6);
  INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,created_at,expires_at,consumed_at,redeemed_at,retention_hold)
  VALUES(d,sha256(i::text::bytea),
   CASE WHEN i=8 THEN now() ELSE now()-make_interval(days=>CASE WHEN i=7 THEN 2 ELSE 20 END) END,
   CASE WHEN i=8 THEN now()+interval '5 minutes' ELSE now()-make_interval(days=>CASE WHEN i=7 THEN 2 ELSE 20 END)+interval '5 minutes' END,
   CASE WHEN i<=3 THEN now()-interval '20 days' END,
   CASE WHEN i<=3 THEN now()-interval '20 days' END,i=5);
 END LOOP;
 -- One device with no references is also removable; a device hold alone prevents it.
 PERFORM pg_temp.device('empty'); PERFORM pg_temp.device('held-empty','PENDING_PROOF',true);

 d:=pg_temp.device('credentials','ACTIVE');
 INSERT INTO ap_m1.device_key_records(device_id,fingerprint_sha256) VALUES(d,sha256('cred key'::bytea)) RETURNING key_id INTO k;
 -- Old expired, old revoked, recent revoked, valid, individual hold.
 FOR i IN 1..5 LOOP
  INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at,revoked_at,retention_hold)
  VALUES(d,k,sha256(('cred'||i)::bytea),'ENROLLMENT',
    CASE WHEN i=4 THEN now() ELSE now()-interval '60 days' END,
    CASE WHEN i=4 THEN now()+interval '1 hour' ELSE now()-interval '60 days'+interval '1 hour' END,
    CASE WHEN i IN(2,5) THEN now()-interval '60 days' WHEN i=3 THEN now()-interval '1 hour' END,i=5);
 END LOOP;
 -- Recent revoked row must actually have recent expiry/issuance too: the existing
 -- policy uses the earlier of expiry and revocation, not the later event.
 UPDATE ap_m1.device_credentials SET issued_at=now()-interval '2 hours',expires_at=now()+interval '1 hour'
 WHERE token_sha256=sha256('cred3'::bytea);
 -- Old expired renewal, old consumed renewal, individually held renewal, recent,
 -- and an old expiry with a fresh unredeemed 60-second completion opportunity.
 FOR i IN 1..5 LOOP
  INSERT INTO ap_m1.credential_renewal_challenges(device_id,key_id,nonce_sha256,created_at,expires_at,consumed_at,redeemed_at,retention_hold)
  VALUES(d,k,sha256(('renew'||i)::bytea),
    CASE WHEN i=4 THEN now() ELSE now()-interval '20 days' END,
    CASE WHEN i=4 THEN now()+interval '2 minutes' ELSE now()-interval '20 days'+interval '2 minutes' END,
    CASE WHEN i=2 THEN now()-interval '20 days' WHEN i=5 THEN clock_timestamp() END,NULL,i=3);
 END LOOP;
 -- Device-held credential and renewal must survive even without individual holds.
 d:=pg_temp.device('held-artifacts','ACTIVE',true);
 INSERT INTO ap_m1.device_key_records(device_id,fingerprint_sha256) VALUES(d,sha256('held key'::bytea)) RETURNING key_id INTO k;
 INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at)
 VALUES(d,k,sha256('held credential'::bytea),'ENROLLMENT',now()-interval '60 days',now()-interval '60 days'+interval '1 hour');
 INSERT INTO ap_m1.credential_renewal_challenges(device_id,key_id,nonce_sha256,created_at,expires_at)
 VALUES(d,k,sha256('held renewal'::bytea),now()-interval '60 days',now()-interval '60 days'+interval '1 minute');

 -- Every direct device FK blocker: enrollment above; key, credential, renewal,
 -- capability, health, command and audit separately. Deliberately link credential/
 -- renewal to a different device's key so the key blocker cannot mask those checks.
 SELECT key_id INTO k FROM ap_m1.device_key_records WHERE fingerprint_sha256=sha256('cred key'::bytea);
 d:=pg_temp.device('block-key');
 INSERT INTO ap_m1.device_key_records(device_id,fingerprint_sha256,state,revoked_at)
 VALUES(d,sha256('block key'::bytea),'REVOKED',now());
 d:=pg_temp.device('block-credential');
 INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,expires_at)
 VALUES(d,k,sha256('block credential'::bytea),'ENROLLMENT',now()+interval '1 hour');
 d:=pg_temp.device('block-renewal');
 INSERT INTO ap_m1.credential_renewal_challenges(device_id,key_id,nonce_sha256,expires_at)
 VALUES(d,k,sha256('block renewal'::bytea),now()+interval '1 minute');
 d:=pg_temp.device('block-capability');
 INSERT INTO ap_m1.capability_snapshots(device_id,observed_at,android_api,device_mode) VALUES(d,now(),35,'STANDARD');
 d:=pg_temp.device('block-health');
 INSERT INTO ap_m1.device_health(device_id,observed_at) VALUES(d,now());
 d:=pg_temp.device('block-command');
 INSERT INTO ap_m1.commands(family_id,device_id,created_by,command_type,expires_at) VALUES(f,d,p,'REFRESH_CAPABILITIES',now()+interval '1 hour');
 d:=pg_temp.device('block-audit');
 INSERT INTO ap_m1.audit_events(family_id,actor_device_id,action,result_code) VALUES(f,d,'synthetic-retention','OK');
 SELECT jsonb_agg(to_jsonb(a) ORDER BY id) INTO before_a FROM ap_m1.audit_events a;
 SELECT jsonb_agg(to_jsonb(a) ORDER BY key_id) INTO before_k FROM ap_m1.device_key_records a;
 SELECT jsonb_agg(to_jsonb(a) ORDER BY family_id) INTO before_e FROM ap_m1.revocation_epochs a;

 SELECT * INTO r FROM ap_m1.purge_credential_artifacts();
 PERFORM pg_temp.check_ok(r.credentials_deleted=2 AND r.renewal_challenges_deleted=2
  AND r.enrollment_challenges_deleted=4 AND r.abandoned_devices_deleted=3,'exact credential/enrollment/device counts');
 PERFORM pg_temp.check_ok(NOT EXISTS(SELECT 1 FROM fixtures x LEFT JOIN ap_m1.devices d ON d.id=x.id
  WHERE x.label LIKE 'block-%' AND d.id IS NULL),'each direct device FK blocker preserved');
 PERFORM pg_temp.check_ok((SELECT count(*) FROM ap_m1.enrollment_challenges)=4,'held/recent/live enrollment preserved');
 PERFORM pg_temp.check_ok((SELECT count(*) FROM ap_m1.device_credentials)=5,'held/recent/valid credentials preserved');
 PERFORM pg_temp.check_ok((SELECT count(*) FROM ap_m1.credential_renewal_challenges)=5,'held/recent/live and 60-second opportunity preserved');
 FOR i IN 1..5 LOOP
  PERFORM pg_temp.check_ok((EXISTS(SELECT 1 FROM ap_m1.device_credentials WHERE token_sha256=sha256(('cred'||i)::bytea)))=(i>=3),'credential survivor identity '||i);
  PERFORM pg_temp.check_ok((EXISTS(SELECT 1 FROM ap_m1.credential_renewal_challenges WHERE nonce_sha256=sha256(('renew'||i)::bytea)))=(i>=3),'renewal survivor identity '||i);
 END LOOP;
 FOR i IN 1..8 LOOP
  PERFORM pg_temp.check_ok((EXISTS(SELECT 1 FROM ap_m1.enrollment_challenges ec JOIN fixtures x ON x.id=ec.device_id WHERE x.label='enrollment-'||i))=(i>=5),'enrollment survivor identity '||i);
 END LOOP;
 PERFORM pg_temp.check_ok(EXISTS(SELECT 1 FROM ap_m1.devices d JOIN fixtures x ON x.id=d.id WHERE x.label='held-empty'),'device hold without artifacts preserved');
 PERFORM pg_temp.check_ok(EXISTS(SELECT 1 FROM ap_m1.device_credentials WHERE token_sha256=sha256('held credential'::bytea))
  AND EXISTS(SELECT 1 FROM ap_m1.credential_renewal_challenges WHERE nonce_sha256=sha256('held renewal'::bytea)),'device hold preserves all artifact types');
 PERFORM pg_temp.check_ok(before_a IS NOT DISTINCT FROM (SELECT jsonb_agg(to_jsonb(a) ORDER BY id) FROM ap_m1.audit_events a),'audit immutable');
 PERFORM pg_temp.check_ok(before_k IS NOT DISTINCT FROM (SELECT jsonb_agg(to_jsonb(a) ORDER BY key_id) FROM ap_m1.device_key_records a),'keys immutable');
 PERFORM pg_temp.check_ok(before_e IS NOT DISTINCT FROM (SELECT jsonb_agg(to_jsonb(a) ORDER BY family_id) FROM ap_m1.revocation_epochs a),'revocation epochs immutable');
 SELECT * INTO r FROM ap_m1.purge_credential_artifacts();
 PERFORM pg_temp.check_ok(r.credentials_deleted=0 AND r.renewal_challenges_deleted=0
  AND r.enrollment_challenges_deleted=0 AND r.abandoned_devices_deleted=0,'idempotent rerun');

 FOR i IN 1..6 LOOP
  INSERT INTO ap_m1.pairing_codes(family_id,child_id,code_sha256,issued_by,created_at,expires_at,consumed_at,retention_hold)
  VALUES(f,c,sha256(('pair'||i)::bytea),p,
   CASE WHEN i=6 THEN now() ELSE now()-interval '10 days' END,
   CASE WHEN i=6 THEN now()+interval '1 minute' WHEN i=5 THEN now()-interval '1 hour' ELSE now()-interval '9 days' END,
   CASE WHEN i IN(2,4) THEN now()-interval '9 days' END,i IN(3,4));
 END LOOP;
 n:=ap_m1.purge_pairing_codes(interval '1 day');
 PERFORM pg_temp.check_ok(n=2,'expired consumed and unconsumed pairing exact counts');
 PERFORM pg_temp.check_ok((SELECT count(*) FROM ap_m1.pairing_codes)=4,'held consumed/unconsumed and recent/live pairing retained');
 PERFORM pg_temp.check_ok(ap_m1.purge_pairing_codes(interval '1 day')=0,'pairing idempotence');

 -- Cross a grace boundary inside one transaction: transaction-frozen now()
 -- would incorrectly retain these rows. This is not a multi-session lock test.
 d:=pg_temp.device('clock','ACTIVE');
 INSERT INTO ap_m1.device_key_records(device_id,fingerprint_sha256) VALUES(d,sha256('clock key'::bytea)) RETURNING key_id INTO k;
 INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at)
 VALUES(d,k,sha256('clock credential'::bytea),'ENROLLMENT',clock_timestamp()-interval '30 days 1 hour'+interval '400 milliseconds',clock_timestamp()-interval '30 days'+interval '400 milliseconds');
 INSERT INTO ap_m1.credential_renewal_challenges(device_id,key_id,nonce_sha256,created_at,expires_at)
 VALUES(d,k,sha256('clock renewal'::bytea),clock_timestamp()-interval '1 day 1 minute'+interval '400 milliseconds',clock_timestamp()-interval '1 day'+interval '400 milliseconds');
 INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,created_at,expires_at)
 VALUES(d,sha256('clock enrollment'::bytea),clock_timestamp()-interval '7 days 1 minute'+interval '400 milliseconds',clock_timestamp()-interval '7 days'+interval '400 milliseconds');
 INSERT INTO ap_m1.pairing_codes(family_id,child_id,code_sha256,issued_by,created_at,expires_at)
 VALUES(f,c,sha256('clock pairing'::bytea),p,clock_timestamp()-interval '1 day 1 minute'+interval '400 milliseconds',clock_timestamp()-interval '1 day'+interval '400 milliseconds');
 PERFORM pg_sleep(0.6);
 SELECT * INTO r FROM ap_m1.purge_credential_artifacts();
 PERFORM pg_temp.check_ok(r.credentials_deleted=1 AND r.renewal_challenges_deleted=1
  AND r.enrollment_challenges_deleted=1 AND r.abandoned_devices_deleted=0,'post-start wall-clock artifact grace');
 PERFORM pg_temp.check_ok(ap_m1.purge_pairing_codes(interval '1 day')=1,'post-start wall-clock pairing grace');

 -- Validate NULL, below-floor, negative, zero and nonfinite input.
 -- PostgreSQL 16 rejects interval infinity during type input; newer engines may
 -- represent it. Either way the purge cannot succeed with a nonfinite grace.
 FOR i IN 1..2 LOOP
  BEGIN
   EXECUTE format('SELECT ap_m1.purge_pairing_codes(%L::interval)',CASE WHEN i=1 THEN 'infinity' ELSE '-infinity' END);
   RAISE EXCEPTION 'pairing accepted infinite interval';
  EXCEPTION WHEN invalid_parameter_value OR invalid_datetime_format OR datetime_field_overflow THEN NULL; END;
  FOR n IN 1..3 LOOP
   BEGIN
    EXECUTE format('SELECT * FROM ap_m1.purge_credential_artifacts(%s,%s,%s)',
     CASE WHEN n=1 THEN quote_literal(CASE WHEN i=1 THEN 'infinity' ELSE '-infinity' END)||'::interval' ELSE 'interval ''30 days''' END,
     CASE WHEN n=2 THEN quote_literal(CASE WHEN i=1 THEN 'infinity' ELSE '-infinity' END)||'::interval' ELSE 'interval ''1 day''' END,
     CASE WHEN n=3 THEN quote_literal(CASE WHEN i=1 THEN 'infinity' ELSE '-infinity' END)||'::interval' ELSE 'interval ''7 days''' END);
    RAISE EXCEPTION 'credential accepted infinite interval';
   EXCEPTION WHEN invalid_parameter_value OR invalid_datetime_format OR datetime_field_overflow THEN NULL; END;
  END LOOP;
 END LOOP;
 FOREACH v IN ARRAY ARRAY[NULL::interval,interval '0',interval '-1 day',interval '23 hours'] LOOP
  BEGIN PERFORM ap_m1.purge_pairing_codes(v); RAISE EXCEPTION 'pairing accepted bad grace'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 END LOOP;
 FOR i IN 1..3 LOOP
  FOREACH v IN ARRAY ARRAY[NULL::interval,interval '0',interval '-1 day'] LOOP
   BEGIN
    PERFORM ap_m1.purge_credential_artifacts(CASE WHEN i=1 THEN v ELSE interval '30 days' END,
     CASE WHEN i=2 THEN v ELSE interval '1 day' END,CASE WHEN i=3 THEN v ELSE interval '7 days' END);
    RAISE EXCEPTION 'credential accepted bad grace';
   EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  END LOOP;
 END LOOP;
 BEGIN PERFORM ap_m1.purge_credential_artifacts(interval '23 hours',interval '1 day',interval '7 days'); RAISE EXCEPTION 'credential floor'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM ap_m1.purge_credential_artifacts(interval '30 days',interval '59 minutes',interval '7 days'); RAISE EXCEPTION 'renewal floor'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN PERFORM ap_m1.purge_credential_artifacts(interval '30 days',interval '1 day',interval '23 hours'); RAISE EXCEPTION 'enrollment floor'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM * FROM ap_m1.purge_credential_artifacts(interval '1 day',interval '1 hour',interval '1 day');
END $$;

-- Assert catalog and actual API denial, not only superuser successful execution.
SELECT pg_temp.check_ok(NOT has_function_privilege('ap_m1_api','ap_m1.purge_credential_artifacts(interval,interval,interval)','EXECUTE'),'API credential purge denied');
SELECT pg_temp.check_ok(NOT has_function_privilege('ap_m1_api','ap_m1.purge_pairing_codes(interval)','EXECUTE'),'API pairing purge denied');
SELECT pg_temp.check_ok(has_function_privilege('ap_m1_owner','ap_m1.purge_pairing_codes(interval)','EXECUTE'),'owner pairing purge allowed');
SELECT pg_temp.check_ok((SELECT pronargdefaults=0 FROM pg_proc WHERE oid='ap_m1.purge_pairing_codes(interval)'::regprocedure),'pairing grace has no default');
SELECT pg_temp.check_ok(NOT EXISTS(SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
 WHERE p.oid IN('ap_m1.purge_pairing_codes(interval)'::regprocedure,'ap_m1.purge_credential_artifacts(interval,interval,interval)'::regprocedure)
 AND a.grantee=0 AND a.privilege_type='EXECUTE'),'PUBLIC no execute');
SET LOCAL ROLE ap_m1_api;
DO $$ BEGIN
 BEGIN PERFORM ap_m1.purge_credential_artifacts(); RAISE EXCEPTION 'API credential purge allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM ap_m1.purge_pairing_codes(interval '1 day'); RAISE EXCEPTION 'API pairing purge allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET LOCAL ROLE ap_m1_owner;
SELECT * FROM ap_m1.purge_credential_artifacts();
SELECT ap_m1.purge_pairing_codes(interval '1 day');
RESET ROLE;
SELECT pg_temp.check_ok((SELECT bool_and(p.prosecdef AND pg_get_userbyid(p.proowner)='ap_m1_auth'
 AND p.proconfig @> ARRAY['search_path=pg_catalog, ap_m1']) FROM pg_proc p
 WHERE p.oid IN('ap_m1.purge_pairing_codes(interval)'::regprocedure,'ap_m1.purge_credential_artifacts(interval,interval,interval)'::regprocedure)), 'fixed search_path and auth definer');
SELECT pg_temp.check_ok(has_table_privilege('ap_m1_auth','ap_m1.pairing_codes','DELETE'),'auth pairing delete granted');
SELECT pg_temp.check_ok(NOT has_table_privilege('ap_m1_auth','ap_m1.audit_events','DELETE')
 AND NOT has_table_privilege('ap_m1_auth','ap_m1.device_key_records','DELETE')
 AND NOT has_table_privilege('ap_m1_auth','ap_m1.revocation_epochs','DELETE'),'no evidence delete grants');
-- These tables have no direct API mutation even before the sibling lifecycle
-- slice narrows legacy devices UPDATE / pairing INSERT column privileges.
SET LOCAL ROLE ap_m1_api;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['device_credentials','credential_renewal_challenges','enrollment_challenges'] LOOP
  BEGIN EXECUTE format('UPDATE ap_m1.%I SET retention_hold=true',t);
   RAISE EXCEPTION 'API hold mutation allowed: %',t;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
END $$;
RESET ROLE;
-- Full hold ACL test is an integration gate for the sibling 0006 grant narrowing,
-- not a claim that five test-only ADD COLUMN operations fix legacy broad grants.
-- Invoke psql -v retention_check_hold_acl=1 after integration.
\if :{?retention_check_hold_acl}
SELECT pg_temp.check_ok(NOT EXISTS(
 SELECT 1 FROM unnest(ARRAY['devices','pairing_codes','device_credentials','credential_renewal_challenges','enrollment_challenges']) t
 WHERE has_column_privilege('ap_m1_api','ap_m1.'||t,'retention_hold','UPDATE')
    OR has_column_privilege('ap_m1_api','ap_m1.'||t,'retention_hold','INSERT')),'API no hold INSERT/UPDATE column privileges');
SELECT pg_temp.check_ok(NOT EXISTS(
 SELECT 1 FROM pg_roles r CROSS JOIN unnest(ARRAY['devices','pairing_codes','device_credentials','credential_renewal_challenges','enrollment_challenges']) t
 WHERE r.rolname='ma_purge' AND (has_column_privilege(r.oid,('ap_m1.'||t)::regclass,'retention_hold','UPDATE')
    OR has_column_privilege(r.oid,('ap_m1.'||t)::regclass,'retention_hold','INSERT'))),'purge login no hold mutation if provisioned');
SET LOCAL ROLE ap_m1_api;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['devices','pairing_codes','device_credentials','credential_renewal_challenges','enrollment_challenges'] LOOP
  BEGIN EXECUTE format('UPDATE ap_m1.%I SET retention_hold=true',t);
   RAISE EXCEPTION 'API hold mutation allowed: %',t;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
 BEGIN
  INSERT INTO ap_m1.pairing_codes(family_id,child_id,code_sha256,expires_at,issued_by,retention_hold)
  VALUES(gen_random_uuid(),gen_random_uuid(),sha256('denied'::bytea),now()+interval '1 minute',gen_random_uuid(),true);
  RAISE EXCEPTION 'API pairing hold insertion allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
\endif
ROLLBACK;
\echo retention holds PASS (all fixtures rolled back)
