-- Madalasa-Alarka M1 PostgreSQL 15+ regression: enrollment flow, first credential, retention purge.
-- Run on a FRESH isolated CI database after migrations 0001, 0002 and 0003 (may follow the other two
-- SQL tests in the same database: it uses its own fixtures, UUID prefix e).
-- SYNTHETIC DATA ONLY. Every assertion raises on failure; ON_ERROR_STOP makes psql exit non-zero.
\set ON_ERROR_STOP on

CREATE FUNCTION public.ap_m1_test_expect(cond boolean, msg text) RETURNS void
 LANGUAGE plpgsql AS $f$
BEGIN
 IF cond IS NOT TRUE THEN RAISE EXCEPTION 'M1_ENROLLMENT_TEST_FAILURE: %', msg; END IF;
END $f$;

\set famE 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'
\set famF 'ffffffff-ffff-4fff-8fff-ffffffffffff'
\set parE 'e0000000-0000-4000-8000-000000000001'
\set parF 'f0000000-0000-4000-8000-000000000001'
\set chE 'e1000000-0000-4000-8000-000000000001'
\set chF 'f1000000-0000-4000-8000-000000000001'

BEGIN;
INSERT INTO ap_m1.families(id,label) VALUES (:'famE','synthetic E'),(:'famF','synthetic F');
INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES
 (:'parE','https://example.invalid','en-parent-e'),(:'parF','https://example.invalid','en-parent-f');
INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES
 (:'famE',:'parE','OWNER'),(:'famF',:'parF','OWNER');
INSERT INTO ap_m1.children(id,family_id,alias) VALUES (:'chE',:'famE','E child'),(:'chF',:'famF','F child');
INSERT INTO ap_m1.pairing_codes(family_id,child_id,code_sha256,expires_at,consumed_at,issued_by,attempt_count,created_at) VALUES
 (:'famE',:'chE',sha256('code-valid'::bytea),     now()+interval '10 minutes',NULL,:'parE',0, now()),
 (:'famE',:'chE',sha256('code-valid-2'::bytea),   now()+interval '10 minutes',NULL,:'parE',0, now()),
 (:'famE',:'chE',sha256('code-valid-3'::bytea),   now()+interval '10 minutes',NULL,:'parE',0, now()),
 (:'famE',:'chE',sha256('code-expired'::bytea),   now()-interval '1 minute',  NULL,:'parE',0, now()-interval '11 minutes'),
 (:'famE',:'chE',sha256('code-used'::bytea),      now()+interval '10 minutes',now(),:'parE',1, now()),
 (:'famE',:'chE',sha256('code-exhausted'::bytea), now()+interval '10 minutes',NULL,:'parE',20,now()),
 (:'famF',:'chF',sha256('code-family-f'::bytea),  now()+interval '10 minutes',NULL,:'parF',0, now());
COMMIT;

SET ROLE ap_m1_api;

-- ------------------------------------------- EN_01..05 redeem_pairing_code
SELECT enrollment_id AS enr, device_id AS dev
 FROM ap_m1.redeem_pairing_code(sha256('code-valid'::bytea), decode(repeat('e1',90),'hex'), sha256('nonce-e1'::bytea), 300) \gset
SELECT public.ap_m1_test_expect(:'enr' <> '' AND :'dev' <> '','EN_01 a valid code must yield an enrollment id and device id');
RESET ROLE;
SELECT public.ap_m1_test_expect(
  (SELECT count(*) FROM ap_m1.devices WHERE id=:'dev' AND family_id=:'famE' AND child_id=:'chE'
     AND enrollment_state='PENDING_PROOF' AND spki_public_key=decode(repeat('e1',90),'hex'))=1,
  'EN_01 device must be PENDING_PROOF in the code''s own family and child, with the presented key');
SELECT public.ap_m1_test_expect((SELECT consumed_at IS NOT NULL FROM ap_m1.pairing_codes WHERE code_sha256=sha256('code-valid'::bytea)),
  'EN_02 the code must be consumed by redemption');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.device_key_records WHERE device_id=:'dev')=0,
  'EN_01 no key record and no credential before the proof');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.device_credentials WHERE device_id=:'dev')=0,
  'EN_01 no credential before the proof');
SET ROLE ap_m1_api;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.redeem_pairing_code(sha256('code-valid'::bytea), decode(repeat('e2',90),'hex'), sha256('n'::bytea), 300))=0,
  'EN_02 a code must work exactly once');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.redeem_pairing_code(sha256('code-expired'::bytea), decode(repeat('e3',90),'hex'), sha256('n'::bytea), 300))=0,
  'EN_03 expired code must not redeem');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.redeem_pairing_code(sha256('code-used'::bytea), decode(repeat('e3',90),'hex'), sha256('n'::bytea), 300))=0,
  'EN_03 already-used code must not redeem');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.redeem_pairing_code(sha256('code-exhausted'::bytea), decode(repeat('e3',90),'hex'), sha256('n'::bytea), 300))=0,
  'EN_03 attempt-exhausted code must not redeem');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.redeem_pairing_code(sha256('never-issued'::bytea), decode(repeat('e3',90),'hex'), sha256('n'::bytea), 300))=0,
  'EN_03 unknown code must not redeem');
DO $t$
DECLARE refused boolean;
BEGIN
 refused:=false; BEGIN PERFORM ap_m1.redeem_pairing_code(sha256('code-valid-2'::bytea), decode('abcd','hex'), sha256('n'::bytea), 300);
 EXCEPTION WHEN invalid_parameter_value THEN refused:=true; END;
 PERFORM public.ap_m1_test_expect(refused,'EN_04 a too-short public key must be refused');
 refused:=false; BEGIN PERFORM ap_m1.redeem_pairing_code(sha256('code-valid-2'::bytea), decode(repeat('e4',90),'hex'), 'short'::bytea, 300);
 EXCEPTION WHEN invalid_parameter_value THEN refused:=true; END;
 PERFORM public.ap_m1_test_expect(refused,'EN_04 a malformed nonce hash must be refused');
 refused:=false; BEGIN PERFORM ap_m1.redeem_pairing_code(sha256('code-valid-2'::bytea), decode(repeat('e4',90),'hex'), sha256('n'::bytea), 86400);
 EXCEPTION WHEN invalid_parameter_value THEN refused:=true; END;
 PERFORM public.ap_m1_test_expect(refused,'EN_04 a one-day enrollment challenge must be refused');
 -- Refusing bad input must not have consumed the code.
 PERFORM public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.redeem_pairing_code(sha256('code-valid-2'::bytea), decode(repeat('e4',90),'hex'), sha256('n'::bytea), 300))=1,
  'EN_04 malformed attempts must not burn a valid code');
END $t$;
RESET ROLE;
SELECT public.ap_m1_test_expect((SELECT family_id FROM ap_m1.devices WHERE id=:'dev')=:'famE',
  'EN_05 device stays in family E');
RESET ROLE;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.devices WHERE family_id=:'famF')=0,
  'EN_05 nothing may be created in family F by redeeming family E codes');
SET ROLE ap_m1_api;

-- ------------------------------------------- EN_06..08 proof step 1 (consume)
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.activate_enrolled_device(:'enr', sha256('tok-skip'::bytea), 3600))=0,
  'EN_06 activation without consuming the challenge first must fail');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.consume_enrollment_challenge(gen_random_uuid()))=0,
  'EN_06 unknown enrollment id must return nothing');
SELECT public.ap_m1_test_expect(
  (SELECT nonce_sha256 FROM ap_m1.consume_enrollment_challenge(:'enr'))=sha256('nonce-e1'::bytea),
  'EN_07 first consume returns the stored nonce hash (and spends the challenge)');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.consume_enrollment_challenge(:'enr'))=0,
  'EN_08 a spent enrollment challenge must not be consumed twice');

-- ------------------------------------------- EN_09..13 proof step 2 (activate)
DO $t$
DECLARE bad integer; refused boolean;
BEGIN
 FOREACH bad IN ARRAY ARRAY[0,299,86401] LOOP
  refused:=false;
  BEGIN PERFORM ap_m1.activate_enrolled_device(gen_random_uuid(), sha256('x'::bytea), bad);
  EXCEPTION WHEN invalid_parameter_value THEN refused:=true; END;
  PERFORM public.ap_m1_test_expect(refused,'EN_09 credential lifetime '||bad||' must be refused');
 END LOOP;
END $t$;
SELECT public.ap_m1_test_expect((SELECT expires_at FROM ap_m1.activate_enrolled_device(:'enr', sha256('tok-first'::bytea), 3600)) > now()+interval '59 minutes',
  'EN_10 activation returns the first credential expiry');
SELECT public.ap_m1_test_expect((SELECT device_id FROM ap_m1.authenticate_device_credential(sha256('tok-first'::bytea)))=:'dev',
  'EN_10 the first credential authenticates the new device');
SELECT public.ap_m1_test_expect(ap_m1.device_public_key(:'dev')=decode(repeat('e1',90),'hex'),'EN_10 the device now exposes its active key');
RESET ROLE;
SELECT public.ap_m1_test_expect(
  (SELECT count(*) FROM ap_m1.device_key_records WHERE device_id=:'dev' AND state='ACTIVE'
     AND fingerprint_sha256=sha256(decode(repeat('e1',90),'hex')))=1,
  'EN_11 exactly one active key record, fingerprint = SHA-256 of the SPKI');
SELECT public.ap_m1_test_expect(
  (SELECT count(*) FROM ap_m1.device_credentials WHERE device_id=:'dev' AND issued_via='ENROLLMENT' AND revoked_at IS NULL)=1,
  'EN_11 exactly one live ENROLLMENT credential');
SET ROLE ap_m1_api;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.activate_enrolled_device(:'enr', sha256('tok-again'::bytea), 3600))=0,
  'EN_12 an enrollment can be activated once');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256('tok-again'::bytea)))=0,
  'EN_12 a second activation must not mint a credential');

-- The new device can renew right away: ties enrollment to the renewal flow end to end.
SELECT ap_m1.issue_credential_renewal_challenge(:'dev', sha256(decode(repeat('e1',90),'hex')), sha256('nonce-r1'::bytea), 120) AS rch \gset
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.consume_renewal_challenge(:'dev',:'rch'))=1,'EN_13 enrolled device can start a renewal');
SELECT public.ap_m1_test_expect(ap_m1.issue_renewal_credential(:'dev',:'rch',sha256('tok-renewed-e'::bytea),3600) IS NOT NULL,'EN_13 and finish it');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.authenticate_device_credential(sha256('tok-first'::bytea)))=0,
  'EN_13 renewal revokes the enrollment credential');

-- ------------------------------------------- EN_14 stale step 1 / revoked in between
SELECT enrollment_id AS enr2, device_id AS dev2
 FROM ap_m1.redeem_pairing_code(sha256('code-valid-3'::bytea), decode(repeat('e5',90),'hex'), sha256('nonce-e5'::bytea), 300) \gset
SELECT count(*) AS c FROM ap_m1.consume_enrollment_challenge(:'enr2') \gset
RESET ROLE;
UPDATE ap_m1.enrollment_challenges SET consumed_at = now() - interval '2 minutes' WHERE id = :'enr2';
SET ROLE ap_m1_api;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.activate_enrolled_device(:'enr2', sha256('tok-stale'::bytea), 3600))=0,
  'EN_14 activation more than 60 s after the signature check must fail');
RESET ROLE;
SELECT public.ap_m1_test_expect((SELECT enrollment_state FROM ap_m1.devices WHERE id=:'dev2')='PENDING_PROOF',
  'EN_14 the device must stay PENDING_PROOF');
-- Parent revokes the pending device between step 1 and step 2.
INSERT INTO ap_m1.pairing_codes(family_id,child_id,code_sha256,expires_at,issued_by)
 VALUES (:'famE',:'chE',sha256('code-valid-4'::bytea),now()+interval '10 minutes',:'parE');
SET ROLE ap_m1_api;
SELECT enrollment_id AS enr3, device_id AS dev3
 FROM ap_m1.redeem_pairing_code(sha256('code-valid-4'::bytea), decode(repeat('e6',90),'hex'), sha256('n'::bytea), 300) \gset
SELECT count(*) AS c FROM ap_m1.consume_enrollment_challenge(:'enr3') \gset
RESET ROLE;
UPDATE ap_m1.devices SET enrollment_state='REVOKED', revoked_at=now() WHERE id=:'dev3';
SET ROLE ap_m1_api;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.activate_enrolled_device(:'enr3', sha256('tok-revoked'::bytea), 3600))=0,
  'EN_15 a device revoked between steps must not be activated');
RESET ROLE;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.device_credentials WHERE device_id=:'dev3')=0,
  'EN_15 no credential for a revoked pending device');

-- ------------------------------------------- EN_16..20 retention purge
-- Old/new credentials for the active device, and an abandoned pending enrollment.
INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at,revoked_at)
 SELECT :'dev', k.key_id, sha256(convert_to(t.tok,'UTF8')), 'RENEWAL', t.iss, t.exp, t.rev
 FROM ap_m1.device_key_records k,
 (VALUES ('purge-old-expired', now()-interval '40 days', now()-interval '39 days', NULL::timestamptz),
         ('purge-old-revoked', now()-interval '50 days', now()-interval '49 days' - interval '1 hour', now()-interval '49 days' - interval '12 hours'),
         ('purge-recent-expired', now()-interval '2 days', now()-interval '1 day', NULL)
 ) AS t(tok,iss,exp,rev)
 WHERE k.device_id=:'dev' AND k.state='ACTIVE';
INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state,created_at) VALUES
 ('e3000000-0000-4000-8000-0000000000aa',:'famE',:'chE',decode(repeat('e7',90),'hex'),'PENDING_PROOF',now()-interval '10 days');
INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,expires_at,created_at)
 VALUES ('e3000000-0000-4000-8000-0000000000aa',sha256('n'::bytea),now()-interval '10 days'+interval '5 minutes',now()-interval '10 days');
INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state,created_at) VALUES
 ('e3000000-0000-4000-8000-0000000000bb',:'famE',:'chE',decode(repeat('e8',90),'hex'),'PENDING_PROOF',now()-interval '1 hour');
INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,expires_at,created_at)
 VALUES ('e3000000-0000-4000-8000-0000000000bb',sha256('n'::bytea),now()+interval '5 minutes',now());

DO $t$
DECLARE refused boolean;
BEGIN
 refused:=false; BEGIN PERFORM ap_m1.purge_credential_artifacts(interval '1 hour'); EXCEPTION WHEN invalid_parameter_value THEN refused:=true; END;
 PERFORM public.ap_m1_test_expect(refused,'EN_16 a credential grace below one day must be refused');
 refused:=false; BEGIN PERFORM ap_m1.purge_credential_artifacts(interval '30 days', interval '1 minute'); EXCEPTION WHEN invalid_parameter_value THEN refused:=true; END;
 PERFORM public.ap_m1_test_expect(refused,'EN_16 a challenge grace below one hour must be refused');
END $t$;
SET ROLE ap_m1_api;
DO $t$
DECLARE refused boolean := false;
BEGIN
 BEGIN PERFORM ap_m1.purge_credential_artifacts(); EXCEPTION WHEN insufficient_privilege THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'EN_17 the API role must not be able to run the purge');
END $t$;
RESET ROLE;
SET ROLE ap_m1_owner;
SELECT * FROM ap_m1.purge_credential_artifacts() \gset
RESET ROLE;
SELECT public.ap_m1_test_expect(:credentials_deleted >= 2,'EN_18 old expired and old revoked credentials are deleted');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.device_credentials WHERE token_sha256 IN
  (sha256('purge-old-expired'::bytea), sha256('purge-old-revoked'::bytea)))=0,'EN_18 the two old credentials are gone');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.device_credentials WHERE token_sha256 IN
  (sha256('purge-recent-expired'::bytea), sha256('tok-renewed-e'::bytea)))=2,
  'EN_19 recently expired and live credentials are kept');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.devices WHERE id='e3000000-0000-4000-8000-0000000000aa')=0,
  'EN_20 an abandoned pending enrollment is deleted');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.devices WHERE id='e3000000-0000-4000-8000-0000000000bb')=1,
  'EN_20 a recent pending enrollment is kept');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.devices WHERE id=:'dev' AND enrollment_state='ACTIVE')=1,
  'EN_20 an ACTIVE device is never deleted by the purge');

DROP FUNCTION public.ap_m1_test_expect(boolean,text);
\echo 'M1 enrollment PASS: one-use codes, challenge spend-before-verify, activation, first credential, revoke-in-between, retention purge'
