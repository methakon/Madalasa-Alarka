-- Amar-Pola M1 PostgreSQL 15+ regression: two-family AND two-child tenant leakage.
-- Run only on a fresh isolated CI database after 0001_m1_identity.sql.
-- Run as psql superuser for seed + SET ROLE ap_m1_api for realistic RLS checks.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO ap_m1.families(id,label) VALUES
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','synthetic A'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','synthetic B');
INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES
('a0000000-0000-4000-8000-000000000001','https://example.invalid','synthetic-parent-a'),
('b0000000-0000-4000-8000-000000000002','https://example.invalid','synthetic-parent-b');
INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a0000000-0000-4000-8000-000000000001','OWNER'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','b0000000-0000-4000-8000-000000000002','OWNER');
INSERT INTO ap_m1.children(id,family_id,alias) VALUES
('a1000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','A child permitted'),
('a2000000-0000-4000-8000-000000000002','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','A child NOT granted'),
('b1000000-0000-4000-8000-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','B child');
INSERT INTO ap_m1.child_guardian_grants(family_id,child_id,principal_id,scope) VALUES
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a1000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000001','VIEW_CHILD_PROFILE'),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a1000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000001','VIEW_CHILD_DEVICES'),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a1000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000001','PAIR_DEVICE'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','b1000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000002','VIEW_CHILD_PROFILE'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','b1000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000002','VIEW_CHILD_DEVICES');
INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state) VALUES
('a3000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a1000000-0000-4000-8000-000000000001',decode(repeat('a1',90),'hex'),'ACTIVE'),
('b3000000-0000-4000-8000-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','b1000000-0000-4000-8000-000000000001',decode(repeat('b1',90),'hex'),'ACTIVE');
INSERT INTO ap_m1.pairing_codes(family_id,child_id,code_sha256,expires_at,issued_by)
 VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
 'b1000000-0000-4000-8000-000000000001',decode(repeat('cd',32),'hex'),now()+interval '5 minutes','b0000000-0000-4000-8000-000000000002');
COMMIT;

-- Verify all sensitive tables are explicitly FORCE RLS, app role cannot bypass.
DO $assert$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace
 WHERE s.nspname='ap_m1' AND c.relkind='r'
   AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity);
 IF n<>0 THEN RAISE EXCEPTION 'M1_RLS_SCHEMA_FAILURE: % table(s) without FORCE RLS',n; END IF;
 IF (SELECT rolbypassrls FROM pg_roles WHERE rolname='ap_m1_api') THEN
   RAISE EXCEPTION 'M1_RLS_FAILURE runtime role bypasses RLS';
 END IF;
 IF (SELECT rolcanlogin FROM pg_roles WHERE rolname='ap_m1_auth') THEN
   RAISE EXCEPTION 'M1_RLS_FAILURE SECURITY DEFINER role has login';
 END IF;
END $assert$;

BEGIN;
SET LOCAL ROLE ap_m1_api;
SET LOCAL ap.family_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET LOCAL ap.principal_id = 'a0000000-0000-4000-8000-000000000001';
DO $assert$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM ap_m1.children;
 IF n<>1 THEN RAISE EXCEPTION 'RLS_01 expected exactly child A granted, got %',n; END IF;
 SELECT count(*) INTO n FROM ap_m1.children
 WHERE id='b1000000-0000-4000-8000-000000000001';
 IF n<>0 THEN RAISE EXCEPTION 'RLS_02 cross-family child B leaked'; END IF;
 SELECT count(*) INTO n FROM ap_m1.children
 WHERE id='a2000000-0000-4000-8000-000000000002';
 IF n<>0 THEN RAISE EXCEPTION 'RLS_03 same-family ungranted child leaked'; END IF;
 SELECT count(*) INTO n FROM ap_m1.devices;
 IF n<>1 THEN RAISE EXCEPTION 'RLS_04 expected only device A, got %',n; END IF;
 SELECT count(*) INTO n FROM ap_m1.pairing_codes;
 IF n<>0 THEN RAISE EXCEPTION 'RLS_05 hidden family-B pairing secret leaked'; END IF;
 SELECT count(*) INTO n FROM ap_m1.child_guardian_grants WHERE
 family_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
 IF n<>0 THEN RAISE EXCEPTION 'RLS_06 guardian grant of B leaked'; END IF;
END $assert$;
COMMIT;

-- Family spoof alone must NOT confer B's grants: B lacks principal-A membership.
BEGIN;
SET LOCAL ROLE ap_m1_api;
SET LOCAL ap.family_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
SET LOCAL ap.principal_id = 'a0000000-0000-4000-8000-000000000001';
DO $assert$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM ap_m1.children;
 IF n<>0 THEN RAISE EXCEPTION 'RLS_07 forged family context leaked child B'; END IF;
 SELECT count(*) INTO n FROM ap_m1.devices;
 IF n<>0 THEN RAISE EXCEPTION 'RLS_08 forged family context leaked device B'; END IF;
END $assert$;
COMMIT;

-- Negative write: app role with A context cannot INSERT a B child.
BEGIN;
SET LOCAL ROLE ap_m1_api;
SET LOCAL ap.family_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET LOCAL ap.principal_id = 'a0000000-0000-4000-8000-000000000001';
DO $assert$
DECLARE rejected boolean := false;
BEGIN
 BEGIN
  INSERT INTO ap_m1.children(id,family_id,alias) VALUES
  ('b2000000-0000-4000-8000-000000000002','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','bad insertion');
 EXCEPTION WHEN insufficient_privilege THEN rejected:=true;
 END;
 IF NOT rejected THEN RAISE EXCEPTION 'RLS_09 cross-family INSERT was not rejected'; END IF;
END $assert$;
ROLLBACK;

-- Revocation must remove grant without reopening another family or own child.
UPDATE ap_m1.child_guardian_grants SET revoked_at=now()
 WHERE child_id='a1000000-0000-4000-8000-000000000001'
  AND principal_id='a0000000-0000-4000-8000-000000000001'
  AND scope='VIEW_CHILD_PROFILE';
BEGIN;
SET LOCAL ROLE ap_m1_api;
SET LOCAL ap.family_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET LOCAL ap.principal_id = 'a0000000-0000-4000-8000-000000000001';
DO $assert$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM ap_m1.children;
 IF n<>0 THEN RAISE EXCEPTION 'RLS_10 revoked child A grant still provides visibility'; END IF;
 SELECT count(*) INTO n FROM ap_m1.devices;
 IF n<>1 THEN RAISE EXCEPTION 'RLS_11 unrelated device scope lost unexpectedly'; END IF;
END $assert$;
COMMIT;

\echo 'M1 SQL isolation PASS: forced RLS, cross-family deny, per-child deny, context spoofing, unauthorized insert, revoked scope'
