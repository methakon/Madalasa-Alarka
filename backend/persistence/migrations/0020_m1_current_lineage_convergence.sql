-- Additive convergence after published V2 0019. Runner owns transaction.
-- Requires compat/m1_pre_v2_0017.sql BEFORE 0017 on BOTH paths.
-- Preserve published bytes; never reapply M1 0005/0006 over V2 authorization.
-- Synthetic engineering TTLs only. No production/legal release gate is changed.
DO $require_bridge$
BEGIN
 IF to_regclass('ap_m1.m1_renewal_hold_preservation') IS NULL THEN
  -- Already-converged histories ran published 0017 before this bridge existed,
  -- so their renewal holds were dropped by DDL and cannot be reconstructed.
  -- Never invent hold=true; record the limitation and continue with no snapshot.
  CREATE TABLE ap_m1.m1_renewal_hold_preservation (
   challenge_id uuid PRIMARY KEY,
   retention_hold boolean NOT NULL
  );
  ALTER TABLE ap_m1.m1_renewal_hold_preservation OWNER TO ap_m1_owner;
  ALTER TABLE ap_m1.m1_renewal_hold_preservation ENABLE ROW LEVEL SECURITY;
  ALTER TABLE ap_m1.m1_renewal_hold_preservation FORCE ROW LEVEL SECURITY;
  RAISE NOTICE 'pre-0017 hold bridge absent: no historical renewal hold snapshot can be restored on this converged history';
 END IF;
END $require_bridge$;
ALTER TABLE ap_m1.devices ADD COLUMN IF NOT EXISTS retention_hold boolean NOT NULL DEFAULT false;
ALTER TABLE ap_m1.device_credentials ADD COLUMN IF NOT EXISTS retention_hold boolean NOT NULL DEFAULT false;
ALTER TABLE ap_m1.credential_renewal_challenges ADD COLUMN IF NOT EXISTS retention_hold boolean NOT NULL DEFAULT false;
ALTER TABLE ap_m1.enrollment_challenges ADD COLUMN IF NOT EXISTS retention_hold boolean NOT NULL DEFAULT false;
ALTER TABLE ap_m1.pairing_codes ADD COLUMN IF NOT EXISTS retention_hold boolean NOT NULL DEFAULT false;
GRANT SELECT ON ap_m1.m1_renewal_hold_preservation TO ap_db_executor;
SET LOCAL ROLE ap_db_executor;
DO $restore_holds$
BEGIN
 IF EXISTS(SELECT 1 FROM ap_m1.m1_renewal_hold_preservation s
 LEFT JOIN ap_m1.credential_renewal_challenges ch ON ch.id=s.challenge_id WHERE ch.id IS NULL) THEN
  RAISE EXCEPTION 'historical renewal hold target missing; abort convergence';
 END IF;
 UPDATE ap_m1.credential_renewal_challenges ch SET retention_hold=s.retention_hold
 FROM ap_m1.m1_renewal_hold_preservation s WHERE ch.id=s.challenge_id;
END $restore_holds$;
RESET ROLE;
-- Keep the preservation oracle private, forced-RLS and read-only to executor.
REVOKE ALL ON ap_m1.m1_renewal_hold_preservation FROM PUBLIC,ap_m1_api,ap_m1_auth,ap_auth_issuer;

-- Existing verified-backend identity contract, restricted to issuer credential.
-- Does NOT mint authority, consent, synthetic verification, or a session.
CREATE OR REPLACE FUNCTION ap_m1.resolve_parent_principal(p_issuer text,p_subject text)
 RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER
 SET search_path=pg_catalog,ap_m1 AS $fn$
DECLARE v_id uuid;
BEGIN
 INSERT INTO ap_m1.parent_principals(oidc_issuer,oidc_subject) VALUES(p_issuer,p_subject)
 ON CONFLICT(oidc_issuer,oidc_subject) DO NOTHING;
 SELECT p.id INTO v_id FROM ap_m1.parent_principals p
 WHERE p.oidc_issuer=p_issuer AND p.oidc_subject=p_subject;
 RETURN v_id;
END $fn$;
CREATE OR REPLACE FUNCTION ap_m1.create_family(p_label text)
 RETURNS TABLE(id uuid,label text,state text)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $fn$
DECLARE v_principal uuid:=ap_m1.ctx_principal(); v_owned integer; f ap_m1.families%ROWTYPE;
BEGIN
 IF v_principal IS NULL THEN
  RAISE EXCEPTION 'no authenticated principal in the transaction' USING ERRCODE='28000';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('ap_m1.create_family:'||v_principal::text,0));
 -- Revalidate opaque session after cap-lock wait; never trust a UUID GUC.
 IF ap_m1.ctx_principal() IS DISTINCT FROM v_principal THEN
  RAISE EXCEPTION 'session no longer live' USING ERRCODE='28000';
 END IF;
 SELECT count(*) INTO v_owned FROM ap_m1.guardian_memberships m
 WHERE m.principal_id=v_principal AND m.membership_role='OWNER' AND m.revoked_at IS NULL;
 IF v_owned>=10 THEN RAISE EXCEPTION 'family limit reached for this account' USING ERRCODE='53400'; END IF;
 INSERT INTO ap_m1.families(label) VALUES(p_label) RETURNING * INTO f;
 INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES(f.id,v_principal,'OWNER');
 RETURN QUERY SELECT f.id,f.label,f.state;
END $fn$;

-- Device -> key -> challenge -> credential set: same order as M1 0006.
-- V2 authorization/binding is checked under those locks, before mutation.
CREATE OR REPLACE FUNCTION ap_m1.issue_credential_renewal_challenge(
 p_device uuid, p_key_fingerprint_sha256 bytea, p_nonce_sha256 bytea, p_ttl_seconds integer)
 RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER
 SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE d ap_m1.devices%ROWTYPE; v_key uuid; v_id uuid; v_now timestamptz;
BEGIN
 IF p_ttl_seconds IS NULL OR p_ttl_seconds NOT BETWEEN 30 AND 300 THEN
  RAISE EXCEPTION 'challenge ttl must be 30..300 seconds' USING ERRCODE='22023';
 END IF;
 SELECT * INTO d FROM ap_m1.devices WHERE id=p_device FOR UPDATE;
 IF NOT FOUND OR d.enrollment_state <> 'ACTIVE' OR d.revoked_at IS NOT NULL THEN RETURN NULL; END IF;
 SELECT key_id INTO v_key FROM ap_m1.device_key_records
  WHERE device_id=p_device AND state='ACTIVE' AND revoked_at IS NULL
   AND fingerprint_sha256=p_key_fingerprint_sha256 FOR UPDATE;
 IF NOT FOUND OR NOT ap_m1._m1_key_live(p_device,v_key) THEN RETURN NULL; END IF;
 v_now := clock_timestamp();
 IF (SELECT count(*) FROM ap_m1.credential_renewal_challenges
     WHERE device_id=p_device AND consumed_at IS NULL AND expires_at>v_now)>=5 THEN RETURN NULL; END IF;
 INSERT INTO ap_m1.credential_renewal_challenges(device_id,key_id,nonce_sha256,created_at,expires_at,bound_key_generation,bound_key_fingerprint_sha256)
  SELECT p_device,v_key,p_nonce_sha256,v_now,v_now+make_interval(secs=>p_ttl_seconds),k.generation,k.fingerprint_sha256
  FROM ap_m1.device_key_records k WHERE k.key_id=v_key RETURNING id INTO v_id;
 RETURN v_id;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.consume_renewal_challenge(p_device uuid,p_challenge uuid)
 RETURNS TABLE(nonce_sha256 bytea,spki_public_key bytea)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE d ap_m1.devices%ROWTYPE; ch ap_m1.credential_renewal_challenges%ROWTYPE;
 v_key uuid; v_now timestamptz;
BEGIN
 SELECT * INTO d FROM ap_m1.devices WHERE id=p_device FOR UPDATE;
 IF NOT FOUND OR d.enrollment_state<>'ACTIVE' OR d.revoked_at IS NOT NULL THEN RETURN; END IF;
 SELECT k.key_id INTO v_key FROM ap_m1.device_key_records k
  WHERE k.device_id=p_device AND k.state='ACTIVE' AND k.revoked_at IS NULL FOR UPDATE;
 IF NOT FOUND OR NOT ap_m1._m1_key_live(p_device,v_key) THEN RETURN; END IF;
 SELECT * INTO ch FROM ap_m1.credential_renewal_challenges
  WHERE id=p_challenge AND device_id=p_device FOR UPDATE;
 v_now := clock_timestamp();
 IF NOT FOUND OR ch.key_id<>v_key OR ch.consumed_at IS NOT NULL OR ch.expires_at<=v_now
 OR NOT EXISTS(SELECT 1 FROM ap_m1.device_key_records k WHERE k.key_id=v_key
 AND k.generation=ch.bound_key_generation AND k.fingerprint_sha256=ch.bound_key_fingerprint_sha256)
 THEN RETURN; END IF;
 UPDATE ap_m1.credential_renewal_challenges SET consumed_at=v_now WHERE id=ch.id;
 RETURN QUERY SELECT ch.nonce_sha256,d.spki_public_key;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.issue_renewal_credential(
 p_device uuid,p_challenge uuid,p_new_token_sha256 bytea,p_lifetime_seconds integer)
 RETURNS timestamptz LANGUAGE plpgsql VOLATILE SECURITY DEFINER
 SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE d ap_m1.devices%ROWTYPE; ch ap_m1.credential_renewal_challenges%ROWTYPE;
 v_key uuid; v_now timestamptz; v_exp timestamptz;
BEGIN
 IF p_lifetime_seconds IS NULL OR p_lifetime_seconds NOT BETWEEN 300 AND 86400 THEN
  RAISE EXCEPTION 'credential lifetime must be 300..86400 seconds' USING ERRCODE='22023';
 END IF;
 SELECT * INTO d FROM ap_m1.devices WHERE id=p_device FOR UPDATE;
 IF NOT FOUND OR d.enrollment_state<>'ACTIVE' OR d.revoked_at IS NOT NULL THEN RETURN NULL; END IF;
 SELECT key_id INTO v_key FROM ap_m1.device_key_records
  WHERE device_id=p_device AND state='ACTIVE' AND revoked_at IS NULL FOR UPDATE;
 IF NOT FOUND OR NOT ap_m1._m1_key_live(p_device,v_key) THEN RETURN NULL; END IF;
 SELECT * INTO ch FROM ap_m1.credential_renewal_challenges
  WHERE id=p_challenge AND device_id=p_device FOR UPDATE;
 IF NOT FOUND THEN RETURN NULL; END IF;
 -- Lock the credential set in stable order before sampling time; the device lock
 -- prevents another lifecycle writer from inserting a new row into this set.
 PERFORM c.id FROM ap_m1.device_credentials c
  WHERE c.device_id=p_device AND c.revoked_at IS NULL ORDER BY c.id FOR UPDATE;
 v_now := clock_timestamp();
 IF ch.key_id<>v_key OR ch.consumed_at IS NULL OR ch.redeemed_at IS NOT NULL
    OR ch.consumed_at<=v_now-interval '60 seconds' OR ch.expires_at<=v_now
    OR NOT EXISTS(SELECT 1 FROM ap_m1.device_key_records k WHERE k.key_id=v_key
      AND k.generation=ch.bound_key_generation AND k.fingerprint_sha256=ch.bound_key_fingerprint_sha256)
 THEN RETURN NULL; END IF;
 UPDATE ap_m1.credential_renewal_challenges SET redeemed_at=v_now WHERE id=ch.id;
 UPDATE ap_m1.device_credentials SET revoked_at=v_now WHERE device_id=p_device AND revoked_at IS NULL;
 INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at,bound_key_generation,bound_key_fingerprint_sha256)
  SELECT p_device,ch.key_id,p_new_token_sha256,'RENEWAL',v_now,v_now+make_interval(secs=>p_lifetime_seconds),k.generation,k.fingerprint_sha256
  FROM ap_m1.device_key_records k WHERE k.key_id=v_key
  RETURNING expires_at INTO v_exp;
 RETURN v_exp;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.redeem_pairing_code(
 p_code_sha256 bytea,p_spki bytea,p_nonce_sha256 bytea,p_ttl_seconds integer)
 RETURNS TABLE(enrollment_id uuid,device_id uuid)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE pc ap_m1.pairing_codes%ROWTYPE; v_dev uuid; v_enr uuid; v_now timestamptz;
BEGIN
 IF p_ttl_seconds IS NULL OR p_ttl_seconds NOT BETWEEN 30 AND 600 THEN
  RAISE EXCEPTION 'enrollment challenge ttl must be 30..600 seconds' USING ERRCODE='22023';
 END IF;
 IF p_spki IS NULL OR octet_length(p_spki) NOT BETWEEN 80 AND 4096
    OR p_nonce_sha256 IS NULL OR octet_length(p_nonce_sha256)<>32 THEN
  RAISE EXCEPTION 'malformed enrollment input' USING ERRCODE='22023';
 END IF;
 -- No device exists yet; pairing-code serialization precedes creation of a new device.
 SELECT * INTO pc FROM ap_m1.pairing_codes WHERE code_sha256=p_code_sha256 FOR UPDATE;
 v_now := clock_timestamp();
 IF NOT FOUND THEN RETURN; END IF;
 IF ap_m1.child_deleted(pc.child_id) OR NOT ap_m1.has_consent(pc.child_id,'CORE')
 OR NOT ap_m1._adult_has_scope(pc.child_id,pc.issued_by,'PAIR_DEVICE') THEN RETURN; END IF;
 IF pc.consumed_at IS NOT NULL OR pc.expires_at<=v_now OR pc.attempt_count>=20 THEN RETURN; END IF;
 UPDATE ap_m1.pairing_codes SET consumed_at=v_now,attempt_count=attempt_count+1 WHERE id=pc.id;
 INSERT INTO ap_m1.devices(family_id,child_id,spki_public_key,created_at)
  VALUES(pc.family_id,pc.child_id,p_spki,v_now) RETURNING id INTO v_dev;
 INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,created_at,expires_at)
  VALUES(v_dev,p_nonce_sha256,v_now,v_now+make_interval(secs=>p_ttl_seconds)) RETURNING id INTO v_enr;
 RETURN QUERY SELECT v_enr,v_dev;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.consume_enrollment_challenge(p_enrollment uuid)
 RETURNS TABLE(device_id uuid,nonce_sha256 bytea,spki_public_key bytea)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.enrollment_challenges%ROWTYPE; d ap_m1.devices%ROWTYPE; v_dev uuid; v_now timestamptz;
BEGIN
 -- Discover binding without a challenge lock, then confirm under device-first locks.
 SELECT ec.device_id INTO v_dev FROM ap_m1.enrollment_challenges ec WHERE ec.id=p_enrollment;
 IF NOT FOUND THEN RETURN; END IF;
 SELECT * INTO d FROM ap_m1.devices WHERE id=v_dev FOR UPDATE;
 IF NOT FOUND OR d.enrollment_state<>'PENDING_PROOF' OR d.revoked_at IS NOT NULL
 OR ap_m1.child_deleted(d.child_id) OR NOT ap_m1.has_consent(d.child_id,'CORE') THEN RETURN; END IF;
 SELECT * INTO ch FROM ap_m1.enrollment_challenges WHERE id=p_enrollment FOR UPDATE;
 v_now := clock_timestamp();
 IF NOT FOUND OR ch.device_id<>v_dev OR ch.consumed_at IS NOT NULL OR ch.expires_at<=v_now THEN RETURN; END IF;
 UPDATE ap_m1.enrollment_challenges SET consumed_at=v_now WHERE id=ch.id;
 RETURN QUERY SELECT d.id,ch.nonce_sha256,d.spki_public_key;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.activate_enrolled_device(
 p_enrollment uuid,p_new_token_sha256 bytea,p_lifetime_seconds integer)
 RETURNS TABLE(device_id uuid,expires_at timestamptz)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.enrollment_challenges%ROWTYPE; d ap_m1.devices%ROWTYPE;
 v_dev uuid; v_key uuid; v_exp timestamptz; v_now timestamptz;
BEGIN
 IF p_lifetime_seconds IS NULL OR p_lifetime_seconds NOT BETWEEN 300 AND 86400 THEN
  RAISE EXCEPTION 'credential lifetime must be 300..86400 seconds' USING ERRCODE='22023';
 END IF;
 SELECT ec.device_id INTO v_dev FROM ap_m1.enrollment_challenges ec WHERE ec.id=p_enrollment;
 IF NOT FOUND THEN RETURN; END IF;
 SELECT * INTO d FROM ap_m1.devices WHERE id=v_dev FOR UPDATE;
 IF NOT FOUND OR d.enrollment_state<>'PENDING_PROOF' OR d.revoked_at IS NOT NULL
 OR ap_m1.child_deleted(d.child_id) OR NOT ap_m1.has_consent(d.child_id,'CORE') THEN RETURN; END IF;
 -- A pending device has no existing active key to lock; new key insertion follows proof.
 SELECT * INTO ch FROM ap_m1.enrollment_challenges WHERE id=p_enrollment FOR UPDATE;
 v_now := clock_timestamp();
 IF NOT FOUND OR ch.device_id<>v_dev OR ch.consumed_at IS NULL OR ch.redeemed_at IS NOT NULL
    OR ch.consumed_at<=v_now-interval '60 seconds' OR ch.expires_at<=v_now THEN RETURN; END IF;
 UPDATE ap_m1.enrollment_challenges SET redeemed_at=v_now WHERE id=ch.id;
 UPDATE ap_m1.devices SET enrollment_state='ACTIVE' WHERE id=d.id;
 INSERT INTO ap_m1.device_key_records(device_id,fingerprint_sha256,created_at)
  VALUES(d.id,sha256(d.spki_public_key),v_now) RETURNING key_id INTO v_key;
 INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at,bound_key_generation,bound_key_fingerprint_sha256)
  SELECT d.id,v_key,p_new_token_sha256,'ENROLLMENT',v_now,v_now+make_interval(secs=>p_lifetime_seconds),k.generation,k.fingerprint_sha256
  FROM ap_m1.device_key_records k WHERE k.key_id=v_key
  RETURNING device_credentials.expires_at INTO v_exp;
 RETURN QUERY SELECT d.id,v_exp;
END $fn$;

-- Discover EVERY incoming device FK, including composite keys, CASCADE and
-- SET NULL. Do not delete dependent records or immortal audit/erasure evidence.
-- An unseen/private future dependent fails closed instead of being bypassed.
CREATE FUNCTION ap_m1._m1_device_has_dependents(p_device uuid) RETURNS boolean
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $fn$
DECLARE fk record; predicate text; present boolean;
BEGIN
 FOR fk IN SELECT conrelid,conkey,confkey FROM pg_constraint
 WHERE contype='f' AND confrelid='ap_m1.devices'::regclass LOOP
  IF NOT has_table_privilege(current_user,fk.conrelid,'SELECT') THEN RETURN true; END IF;
  SELECT string_agg(format('r.%I=d.%I',src.attname,dst.attname),' AND ' ORDER BY k.ordinality)
  INTO predicate FROM unnest(fk.conkey,fk.confkey) WITH ORDINALITY AS k(srcnum,dstnum,ordinality)
  JOIN pg_attribute src ON src.attrelid=fk.conrelid AND src.attnum=k.srcnum
  JOIN pg_attribute dst ON dst.attrelid='ap_m1.devices'::regclass AND dst.attnum=k.dstnum;
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM %s r JOIN ap_m1.devices d ON %s WHERE d.id=$1)',fk.conrelid::regclass,predicate)
   INTO present USING p_device;
  IF present THEN RETURN true; END IF;
 END LOOP;
 RETURN false;
END $fn$;
ALTER FUNCTION ap_m1._m1_device_has_dependents(uuid) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1._m1_device_has_dependents(uuid) FROM PUBLIC,ap_m1_api,ap_m1_auth,ap_auth_issuer,ap_m1_owner;
GRANT SELECT ON ap_m1.audit_events,ap_m1.capability_snapshots,ap_m1.device_health TO ap_db_executor;
GRANT DELETE ON ap_m1.devices,ap_m1.pairing_codes TO ap_db_executor;


CREATE OR REPLACE FUNCTION ap_m1.purge_credential_artifacts(
  p_credential_grace interval DEFAULT interval '30 days',
  p_challenge_grace interval DEFAULT interval '1 day',
  p_unused_enrollment_grace interval DEFAULT interval '7 days')
 RETURNS TABLE(credentials_deleted bigint, renewal_challenges_deleted bigint,
               enrollment_challenges_deleted bigint, abandoned_devices_deleted bigint)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE
 v_id uuid; d ap_m1.devices%ROWTYPE; ch record; cr ap_m1.device_credentials%ROWTYPE;
 v_now timestamptz; n bigint;
 a bigint := 0; b bigint := 0; c bigint := 0; e bigint := 0;
BEGIN
 IF p_credential_grace IS NULL OR p_challenge_grace IS NULL OR p_unused_enrollment_grace IS NULL
    OR NOT isfinite(p_credential_grace) OR NOT isfinite(p_challenge_grace)
    OR NOT isfinite(p_unused_enrollment_grace)
    OR p_credential_grace < interval '1 day' OR p_challenge_grace < interval '1 hour'
    OR p_unused_enrollment_grace < interval '1 day' THEN
  RAISE EXCEPTION 'retention grace must be finite and at least the engineering safety floor' USING ERRCODE = '22023';
 END IF;
 FOR v_id IN SELECT id FROM ap_m1.devices ORDER BY id LOOP
  SELECT * INTO d FROM ap_m1.devices WHERE id=v_id FOR UPDATE;
  IF NOT FOUND THEN CONTINUE; END IF;
  IF d.retention_hold THEN CONTINUE; END IF;
  FOR ch IN SELECT * FROM ap_m1.credential_renewal_challenges
            WHERE device_id=d.id ORDER BY id FOR UPDATE LOOP
   v_now := clock_timestamp();
   IF NOT ch.retention_hold
      AND (ch.expires_at < v_now-p_challenge_grace OR ch.consumed_at < v_now-p_challenge_grace)
      AND NOT (ch.redeemed_at IS NULL AND ch.consumed_at IS NOT NULL
               AND ch.consumed_at >= v_now-interval '60 seconds') THEN
    DELETE FROM ap_m1.credential_renewal_challenges WHERE id=ch.id AND NOT retention_hold;
    GET DIAGNOSTICS n=ROW_COUNT; b:=b+n;
   END IF;
  END LOOP;
  FOR ch IN SELECT * FROM ap_m1.enrollment_challenges
            WHERE device_id=d.id ORDER BY id FOR UPDATE LOOP
   v_now := clock_timestamp();
   IF NOT ch.retention_hold AND ch.expires_at < v_now-p_unused_enrollment_grace
      AND NOT (ch.redeemed_at IS NULL AND ch.consumed_at IS NOT NULL
               AND ch.consumed_at >= v_now-interval '60 seconds') THEN
    DELETE FROM ap_m1.enrollment_challenges WHERE id=ch.id AND NOT retention_hold;
    GET DIAGNOSTICS n=ROW_COUNT; c:=c+n;
   END IF;
  END LOOP;
  FOR cr IN SELECT * FROM ap_m1.device_credentials
            WHERE device_id=d.id ORDER BY id FOR UPDATE LOOP
   v_now := clock_timestamp();
   IF NOT cr.retention_hold
      AND least(cr.expires_at,coalesce(cr.revoked_at,cr.expires_at)) < v_now-p_credential_grace THEN
    DELETE FROM ap_m1.device_credentials WHERE id=cr.id AND NOT retention_hold;
    GET DIAGNOSTICS n=ROW_COUNT; a:=a+n;
   END IF;
  END LOOP;
  v_now := clock_timestamp();
  -- Keep all FK blockers, especially immutable audit/key/revocation evidence.
  DELETE FROM ap_m1.devices x
   WHERE x.id=d.id AND NOT x.retention_hold AND x.enrollment_state='PENDING_PROOF'
    AND x.created_at < v_now-p_unused_enrollment_grace
    AND NOT ap_m1._m1_device_has_dependents(x.id);
  GET DIAGNOSTICS n=ROW_COUNT; e:=e+n;
 END LOOP;
 RETURN QUERY SELECT a,b,c,e;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.purge_pairing_codes(p_grace interval)
 RETURNS bigint LANGUAGE plpgsql VOLATILE SECURITY DEFINER
 SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE pc ap_m1.pairing_codes%ROWTYPE; v_now timestamptz; n bigint; total bigint:=0;
BEGIN
 IF p_grace IS NULL OR NOT isfinite(p_grace) OR p_grace < interval '1 day' THEN
  RAISE EXCEPTION 'pairing retention grace must be finite and at least one engineering day' USING ERRCODE='22023';
 END IF;
 FOR pc IN SELECT * FROM ap_m1.pairing_codes ORDER BY id FOR UPDATE LOOP
  v_now:=clock_timestamp();
  IF NOT pc.retention_hold AND pc.expires_at < v_now-p_grace THEN
   DELETE FROM ap_m1.pairing_codes WHERE id=pc.id AND NOT retention_hold;
   GET DIAGNOSTICS n=ROW_COUNT; total:=total+n;
  END IF;
 END LOOP;
 RETURN total;
END $fn$;

-- Normalize the two historical provisioning mutators (0002's broad classifier
-- would otherwise leave them under the read-only bypass owner on M1 upgrades).
GRANT SELECT,INSERT ON ap_m1.parent_principals,ap_m1.families TO ap_db_executor;
GRANT SELECT,INSERT ON ap_m1.guardian_memberships TO ap_db_executor;
REVOKE INSERT,UPDATE,DELETE ON ap_m1.parent_principals,ap_m1.families,ap_m1.guardian_memberships FROM ap_m1_auth;
-- Table-wide revokes do NOT remove old column grants. Normalize those too.
-- V2 has retired direct device/pairing/key/credential/enrollment writes entirely.
DO $column_acl$
DECLARE t text; cols text;
BEGIN
 FOREACH t IN ARRAY ARRAY['devices','pairing_codes','device_key_records',
  'device_credentials','enrollment_challenges','credential_renewal_challenges'] LOOP
  EXECUTE format('REVOKE INSERT,UPDATE,DELETE ON ap_m1.%I FROM ap_m1_api,ap_m1_auth,ap_auth_issuer',t);
  SELECT string_agg(quote_ident(attname),',' ORDER BY attnum) INTO cols
   FROM pg_attribute WHERE attrelid=format('ap_m1.%I',t)::regclass AND attnum>0 AND NOT attisdropped;
  EXECUTE format('REVOKE INSERT (%s), UPDATE (%s), REFERENCES (%s) ON ap_m1.%I FROM PUBLIC,ap_m1_api,ap_m1_auth,ap_auth_issuer',cols,cols,cols,t);
 END LOOP;
END $column_acl$;
DO $owners$
DECLARE sig text;
BEGIN
 FOREACH sig IN ARRAY ARRAY[
 'resolve_parent_principal(text,text)','create_family(text)',
 'issue_credential_renewal_challenge(uuid,bytea,bytea,integer)',
 'consume_renewal_challenge(uuid,uuid)','issue_renewal_credential(uuid,uuid,bytea,integer)',
 'redeem_pairing_code(bytea,bytea,bytea,integer)','consume_enrollment_challenge(uuid)',
 'activate_enrolled_device(uuid,bytea,integer)',
 'purge_credential_artifacts(interval,interval,interval)','purge_pairing_codes(interval)'] LOOP
  EXECUTE format('ALTER FUNCTION ap_m1.%s OWNER TO ap_db_executor',sig);
  EXECUTE format('REVOKE ALL ON FUNCTION ap_m1.%s FROM PUBLIC,ap_m1_api,ap_m1_auth,ap_auth_issuer,ap_m1_owner',sig);
 END LOOP;
END $owners$;
-- Preserve the historical M1 provisioning contracts. resolve_parent_principal
-- keeps its existing ap_m1_api EXECUTE (V2 0002 already granted it to every
-- non-private helper) so main's current createFamily path is not broken by a
-- permission regression; tightening it to issuer-only belongs to the separate
-- opaque-session auth slice. No session is issued or validated here.
GRANT EXECUTE ON FUNCTION ap_m1.resolve_parent_principal(text,text) TO ap_auth_issuer, ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.create_family(text) TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.redeem_pairing_code(bytea,bytea,bytea,integer),
 ap_m1.consume_enrollment_challenge(uuid),ap_m1.activate_enrolled_device(uuid,bytea,integer),
 ap_m1.consume_renewal_challenge(uuid,uuid),ap_m1.issue_renewal_credential(uuid,uuid,bytea,integer),
 ap_m1.issue_credential_renewal_challenge(uuid,bytea,bytea,integer) TO ap_auth_issuer;
GRANT EXECUTE ON FUNCTION ap_m1.purge_credential_artifacts(interval,interval,interval),
 ap_m1.purge_pairing_codes(interval) TO ap_m1_owner;
-- No direct runtime access to the private preservation oracle or hold columns.
