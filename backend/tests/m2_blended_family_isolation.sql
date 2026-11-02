-- Executable V2 smoke/negative test; disposable local DB, privileged test login.
-- psql -X -v ON_ERROR_STOP=1 -f backend/tests/m2_blended_family_isolation.sql
-- All mutations roll back, including protected LOCAL TEST opt-in. No bearer logs.
\set ON_ERROR_STOP on
BEGIN;
UPDATE ap_m1.local_test_settings SET enabled=true WHERE singleton;
INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES
 ('02000000-0000-4000-8000-000000000001','https://sql.synthetic.invalid','adult-a'),
 ('02000000-0000-4000-8000-000000000002','https://sql.synthetic.invalid','adult-b'),
 ('02000000-0000-4000-8000-000000000003','https://sql.synthetic.invalid','adult-c');
INSERT INTO ap_m1.trusted_principal_verifications(principal_id,state)
 SELECT id,'LOCAL_TEST_APPROVED' FROM ap_m1.parent_principals WHERE oidc_issuer='https://sql.synthetic.invalid';
INSERT INTO ap_m1.families(id,label) VALUES
 ('02000000-0000-4000-8000-000000000010','synthetic payer A'),
 ('02000000-0000-4000-8000-000000000020','synthetic payer B');
INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES
 ('02000000-0000-4000-8000-000000000010','02000000-0000-4000-8000-000000000001','OWNER'),
 ('02000000-0000-4000-8000-000000000020','02000000-0000-4000-8000-000000000002','OWNER');
INSERT INTO ap_m1.children(id,family_id,alias) VALUES
 ('02000000-0000-4000-8000-000000000100','02000000-0000-4000-8000-000000000010','synthetic shared child'),
 ('02000000-0000-4000-8000-000000000200','02000000-0000-4000-8000-000000000010','synthetic unshared sibling');
INSERT INTO ap_m1.child_authority_reviews(id,child_id,adult_id,state,lawful_basis_version,method_code,reviewed_at,expires_at) VALUES
 ('02000000-0000-4000-8000-000000001001','02000000-0000-4000-8000-000000000100','02000000-0000-4000-8000-000000000001','LOCAL_TEST_APPROVED','synthetic-v1','SYNTHETIC_FIXTURE',statement_timestamp(),statement_timestamp()+interval '1 day'),
 ('02000000-0000-4000-8000-000000001002','02000000-0000-4000-8000-000000000100','02000000-0000-4000-8000-000000000002','LOCAL_TEST_APPROVED','synthetic-v1','SYNTHETIC_FIXTURE',statement_timestamp(),statement_timestamp()+interval '1 day');
INSERT INTO ap_m1.consent_records(id,child_id,adult_id,purpose,status,legal_state,authority_review_id,notice_version,expires_at) VALUES
 ('02000000-0000-4000-8000-000000002001','02000000-0000-4000-8000-000000000100','02000000-0000-4000-8000-000000000001','CORE','GRANTED','LOCAL_TEST_APPROVED','02000000-0000-4000-8000-000000001001','synthetic-v1',statement_timestamp()+interval '1 day');
INSERT INTO ap_m1.child_access_grants_v2(child_id,adult_id,scope,issued_by,consent_record_id,authority_review_id)
 SELECT '02000000-0000-4000-8000-000000000100','02000000-0000-4000-8000-000000000001',s,'02000000-0000-4000-8000-000000000001','02000000-0000-4000-8000-000000002001','02000000-0000-4000-8000-000000001001'
 FROM unnest(ARRAY['VIEW_CHILD_PROFILE','MANAGE_CHILD_GRANTS']) s;
SET LOCAL ROLE ap_m1_api;
SET LOCAL ap.principal_id='02000000-0000-4000-8000-000000000001';
SET LOCAL ap.family_id='02000000-0000-4000-8000-000000000010';
DO $test$
BEGIN
 IF ap_m1.ctx_principal() IS NOT NULL OR EXISTS(SELECT 1 FROM ap_m1.children) THEN RAISE EXCEPTION 'V2 UUID GUC impersonation'; END IF;
 BEGIN
  PERFORM ap_m1.mint_session('02000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'V2 API minted session';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES('02000000-0000-4000-8000-000000000010','02000000-0000-4000-8000-000000000003','OWNER');
  RAISE EXCEPTION 'V2 self membership escalation';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
SET LOCAL ROLE ap_auth_issuer;
SELECT ap_m1.mint_session('02000000-0000-4000-8000-000000000001','02000000-0000-4000-8000-000000000010') AS owner_token \gset
SELECT ap_m1.mint_session('02000000-0000-4000-8000-000000000002','02000000-0000-4000-8000-000000000020') AS coparent_token \gset
SELECT ap_m1.mint_session('02000000-0000-4000-8000-000000000003') AS outsider_token \gset
SET LOCAL ROLE ap_m1_api;
SELECT set_config('ap.session_token',:'owner_token',true) AS bound \gset
DO $test$
BEGIN
 IF (SELECT count(*) FROM ap_m1.children WHERE id IN ('02000000-0000-4000-8000-000000000100','02000000-0000-4000-8000-000000000200'))<>1 THEN RAISE EXCEPTION 'V2 same family sibling leak'; END IF;
END $test$;
SELECT ap_m1.issue_child_invite('02000000-0000-4000-8000-000000000100','02000000-0000-4000-8000-000000000002',ARRAY['VIEW_CHILD_PROFILE']) AS invite_token \gset
SELECT set_config('ap.session_token',:'outsider_token',true) AS bound \gset
SELECT set_config('ap.test_invite',:'invite_token',true) AS test_bound \gset
DO $test$
BEGIN
 BEGIN
  PERFORM ap_m1.accept_child_invite(current_setting('ap.test_invite'));
  RAISE EXCEPTION 'V2 unintended principal accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
SELECT set_config('ap.session_token',:'coparent_token',true) AS bound \gset
SELECT ap_m1.accept_child_invite(:'invite_token') AS accepted_child \gset
DO $test$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM ap_m1.children WHERE id='02000000-0000-4000-8000-000000000100') THEN RAISE EXCEPTION 'V2 exact child missing'; END IF;
 IF EXISTS(SELECT 1 FROM ap_m1.children WHERE id='02000000-0000-4000-8000-000000000200') THEN RAISE EXCEPTION 'V2 sibling leaked'; END IF;
 IF EXISTS(SELECT 1 FROM ap_m1.families WHERE id='02000000-0000-4000-8000-000000000010') OR EXISTS(SELECT 1 FROM ap_m1.guardian_memberships WHERE family_id='02000000-0000-4000-8000-000000000010') THEN RAISE EXCEPTION 'V2 billing family leaked'; END IF;
 BEGIN
  PERFORM ap_m1.accept_child_invite(current_setting('ap.test_invite'));
  RAISE EXCEPTION 'V2 invitation replay accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $test$;
RESET ROLE;
SELECT id AS invite_id FROM ap_m1.child_access_invites WHERE one_time_secret_hash=public.digest(:'invite_token','sha256') \gset
SET LOCAL ROLE ap_m1_api;
SELECT set_config('ap.session_token',:'owner_token',true) AS bound \gset
SELECT ap_m1.revoke_child_invite(:'invite_id') AS revoked \gset
SELECT set_config('ap.session_token',:'coparent_token',true) AS bound \gset
DO $test$
BEGIN
 IF EXISTS(SELECT 1 FROM ap_m1.children WHERE id='02000000-0000-4000-8000-000000000100') THEN RAISE EXCEPTION 'V2 revoked grant still visible'; END IF;
END $test$;
ROLLBACK;
\echo 'M2 blended-family SQL PASS: opaque context, issuer-only mint, exact principal, replay, sibling/billing isolation, live revoke'
