-- L10-001: family trial abuse/privacy policy, against the V2 billing schema (0001..0004). SYNTHETIC DATA ONLY.
-- Run as migration admin in a disposable database that has the V2 lineage applied and an empty fixture set.
-- Everything runs in one transaction and rolls back.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='30s';
CREATE FUNCTION pg_temp.ok(c boolean, label text) RETURNS void LANGUAGE plpgsql AS
$$ BEGIN IF c IS DISTINCT FROM true THEN RAISE EXCEPTION 'trial policy assertion: %', label; END IF; END $$;
-- Tries a statement as the runtime role with a synthetic session; returns the SQLSTATE or 'OK'.
CREATE FUNCTION pg_temp.as_parent(principal uuid, family uuid, stmt text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE tok text; st text;
BEGIN
  SET LOCAL ROLE ap_auth_issuer;
  tok := ap_m1.mint_session(principal, family, NULL, interval '1 hour');
  RESET ROLE;
  PERFORM set_config('ap.session_token', tok, true);
  SET LOCAL ROLE ap_m1_api;
  BEGIN EXECUTE stmt; st := 'OK';
  EXCEPTION WHEN OTHERS THEN st := SQLSTATE || ':' || SQLERRM; END;
  RESET ROLE;
  RETURN st;
END $$;

INSERT INTO ap_m1.local_test_settings(singleton,enabled) VALUES(true,true) ON CONFLICT (singleton) DO UPDATE SET enabled=true;
DO $$
DECLARE a uuid; b uuid; c uuid; f1 uuid; f2 uuid; f3 uuid; r text; n int;
BEGIN
  INSERT INTO ap_m1.parent_principals(oidc_issuer,oidc_subject) VALUES('https://synthetic.invalid','trial-a') RETURNING id INTO a;
  INSERT INTO ap_m1.parent_principals(oidc_issuer,oidc_subject) VALUES('https://synthetic.invalid','trial-b') RETURNING id INTO b;
  INSERT INTO ap_m1.parent_principals(oidc_issuer,oidc_subject) VALUES('https://synthetic.invalid','trial-c') RETURNING id INTO c;
  INSERT INTO ap_m1.trusted_principal_verifications(principal_id,state) SELECT unnest(ARRAY[a,b,c]),'LOCAL_TEST_APPROVED';
  INSERT INTO ap_m1.families(label) VALUES('synthetic trial family 1') RETURNING id INTO f1;
  INSERT INTO ap_m1.families(label) VALUES('synthetic trial family 2') RETURNING id INTO f2;
  INSERT INTO ap_m1.families(label) VALUES('synthetic trial family 3') RETURNING id INTO f3;
  INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES(f1,a,'OWNER'),(f2,a,'OWNER'),(f3,b,'OWNER'),(f1,c,'GUARDIAN');
  INSERT INTO ap_m1.children(family_id,alias) VALUES(f1,'synthetic child');

  -- TP_01 a fresh owner is eligible; the check itself starts nothing.
  r := pg_temp.as_parent(a, f1, format('SELECT ap_m1.check_trial_eligibility(%L)', f1));
  PERFORM pg_temp.ok(r='OK', 'TP_01 eligibility check runs ('||r||')');
  PERFORM pg_temp.ok((SELECT count(*) FROM ap_m1.trial_redemptions)=0, 'TP_01 eligibility does not start a trial');

  -- TP_02 only an owner can start; a plain member is refused with 42501 (the API maps it to 404).
  r := pg_temp.as_parent(c, f1, format('SELECT ap_m1.start_family_trial(%L,true)', f1));
  PERFORM pg_temp.ok(r LIKE '42501:%', 'TP_02 non-owner refused ('||r||')');
  -- TP_03 acknowledgement is mandatory.
  r := pg_temp.as_parent(a, f1, format('SELECT ap_m1.start_family_trial(%L,false)', f1));
  PERFORM pg_temp.ok(r LIKE '42501:%', 'TP_03 missing acknowledgement refused ('||r||')');
  PERFORM pg_temp.ok((SELECT count(*) FROM ap_m1.trial_redemptions)=0, 'TP_03 nothing written on refusal');

  -- TP_04 owner starts exactly one 48 hour trial covering the family's active children.
  r := pg_temp.as_parent(a, f1, format('SELECT ap_m1.start_family_trial(%L,true)', f1));
  PERFORM pg_temp.ok(r='OK', 'TP_04 trial starts ('||r||')');
  PERFORM pg_temp.ok((SELECT expires_at-started_at FROM ap_m1.trial_redemptions WHERE family_id=f1)=interval '48 hours', 'TP_04 duration is 48h');
  PERFORM pg_temp.ok((SELECT count(*) FROM ap_m1.trial_child_entitlements)=1, 'TP_04 active child covered');

  -- TP_05 same family cannot restart.
  r := pg_temp.as_parent(a, f1, format('SELECT ap_m1.start_family_trial(%L,true)', f1));
  PERFORM pg_temp.ok(r LIKE 'P0001:%already used%', 'TP_05 repeat in same family refused ('||r||')');

  -- TP_06 the same PAYER cannot get a second trial by creating another family (the second-signup case).
  r := pg_temp.as_parent(a, f2, format('SELECT ap_m1.start_family_trial(%L,true)', f2));
  PERFORM pg_temp.ok(r LIKE 'P0001:%already used%', 'TP_06 same payer, new family refused ('||r||')');

  -- TP_07 a different payer with their own family is still eligible: no cross-account blocking.
  r := pg_temp.as_parent(b, f3, format('SELECT ap_m1.start_family_trial(%L,true)', f3));
  PERFORM pg_temp.ok(r='OK', 'TP_07 different payer allowed ('||r||')');

  -- TP_08 the policy keeps only account facts: no device, network or advertising identifier is stored.
  SELECT count(*) INTO n FROM information_schema.columns
   WHERE table_schema='ap_m1' AND table_name IN ('trial_redemptions','trial_eligibility_checks','trial_child_entitlements')
     AND column_name ~* '(device|imei|android|advert|ip_|_ip$|fingerprint|mac_|ssaid|hardware)';
  PERFORM pg_temp.ok(n=0, 'TP_08 no persistent device or network identifier columns ('||n||')');

  -- TP_09 the runtime role cannot write trials directly, only through the guarded functions.
  r := pg_temp.as_parent(a, f1, format('INSERT INTO ap_m1.trial_redemptions(family_id,payer_id,started_at,expires_at) VALUES(%L,%L,now(),now()+interval ''48 hours'')', f2, a));
  PERFORM pg_temp.ok(r <> 'OK', 'TP_09 direct insert refused ('||r||')');

  -- TP_10 the eligibility check (GET path) reports a result and audits it; it stores a verdict, not an identifier.
  -- Note: a refused start_family_trial raises, so its own audit insert rolls back with the statement; only the
  -- separate eligibility call is durable. Recorded in docs/FRICTION_LOG-style follow-up, not hidden.
  r := pg_temp.as_parent(a, f2, format('SELECT ap_m1.check_trial_eligibility(%L)', f2));
  PERFORM pg_temp.ok(r='OK', 'TP_10 check runs ('||r||')');
  PERFORM pg_temp.ok((SELECT count(*) FROM ap_m1.trial_eligibility_checks WHERE family_id=f2 AND risk_result='ALREADY_REDEEMED')=1, 'TP_10 refusal verdict audited');
END $$;
ROLLBACK;
\echo m1 trial policy PASS (all fixtures rolled back)
