-- Historical M1 additive lifecycle serialization. Synthetic engineering defaults only.
-- Apply after exactly 0001..0005 as migration admin. Published SQL is unchanged.
-- Device -> key -> challenge -> credentials; sample wall clock only after waits.
BEGIN;
SET LOCAL ROLE ap_m1_owner;
ALTER TABLE ap_m1.device_credentials ADD COLUMN retention_hold boolean NOT NULL DEFAULT false;
ALTER TABLE ap_m1.credential_renewal_challenges ADD COLUMN retention_hold boolean NOT NULL DEFAULT false;
ALTER TABLE ap_m1.enrollment_challenges ADD COLUMN retention_hold boolean NOT NULL DEFAULT false;
ALTER TABLE ap_m1.pairing_codes ADD COLUMN retention_hold boolean NOT NULL DEFAULT false;
ALTER TABLE ap_m1.devices ADD COLUMN retention_hold boolean NOT NULL DEFAULT false;
REVOKE UPDATE ON ap_m1.devices FROM ap_m1_api;
GRANT UPDATE (id,family_id,child_id,enrollment_state,spki_public_key,algorithm,revoked_at,created_at)
 ON ap_m1.devices TO ap_m1_api;
REVOKE INSERT ON ap_m1.pairing_codes FROM ap_m1_api;
GRANT INSERT (id,family_id,child_id,code_sha256,expires_at,consumed_at,issued_by,attempt_count,created_at)
 ON ap_m1.pairing_codes TO ap_m1_api;
-- PostgreSQL row locking requires UPDATE on at least one column. This NOLOGIN
-- definer receives only key_id, not authority to change key state or retention holds.
GRANT UPDATE (key_id) ON ap_m1.device_key_records TO ap_m1_auth;
RESET ROLE;

-- CREATE OR REPLACE preserves each original function's owner and ACL.
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
 IF NOT FOUND THEN RETURN NULL; END IF;
 v_now := clock_timestamp();
 IF (SELECT count(*) FROM ap_m1.credential_renewal_challenges
     WHERE device_id=p_device AND consumed_at IS NULL AND expires_at>v_now)>=5 THEN RETURN NULL; END IF;
 INSERT INTO ap_m1.credential_renewal_challenges(device_id,key_id,nonce_sha256,created_at,expires_at)
  VALUES(p_device,v_key,p_nonce_sha256,v_now,v_now+make_interval(secs=>p_ttl_seconds)) RETURNING id INTO v_id;
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
 IF NOT FOUND THEN RETURN; END IF;
 SELECT * INTO ch FROM ap_m1.credential_renewal_challenges
  WHERE id=p_challenge AND device_id=p_device FOR UPDATE;
 v_now := clock_timestamp();
 IF NOT FOUND OR ch.key_id<>v_key OR ch.consumed_at IS NOT NULL OR ch.expires_at<=v_now THEN RETURN; END IF;
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
 IF NOT FOUND THEN RETURN NULL; END IF;
 SELECT * INTO ch FROM ap_m1.credential_renewal_challenges
  WHERE id=p_challenge AND device_id=p_device FOR UPDATE;
 IF NOT FOUND THEN RETURN NULL; END IF;
 -- Lock the credential set in stable order before sampling time; the device lock
 -- prevents another lifecycle writer from inserting a new row into this set.
 PERFORM c.id FROM ap_m1.device_credentials c
  WHERE c.device_id=p_device AND c.revoked_at IS NULL ORDER BY c.id FOR UPDATE;
 v_now := clock_timestamp();
 IF ch.key_id<>v_key OR ch.consumed_at IS NULL OR ch.redeemed_at IS NOT NULL
    OR ch.consumed_at<=v_now-interval '60 seconds' THEN RETURN NULL; END IF;
 UPDATE ap_m1.credential_renewal_challenges SET redeemed_at=v_now WHERE id=ch.id;
 UPDATE ap_m1.device_credentials SET revoked_at=v_now WHERE device_id=p_device AND revoked_at IS NULL;
 INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at)
  VALUES(p_device,ch.key_id,p_new_token_sha256,'RENEWAL',v_now,v_now+make_interval(secs=>p_lifetime_seconds))
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
 IF NOT FOUND OR pc.consumed_at IS NOT NULL OR pc.expires_at<=v_now OR pc.attempt_count>=20 THEN RETURN; END IF;
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
 IF NOT FOUND OR d.enrollment_state<>'PENDING_PROOF' OR d.revoked_at IS NOT NULL THEN RETURN; END IF;
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
 IF NOT FOUND OR d.enrollment_state<>'PENDING_PROOF' OR d.revoked_at IS NOT NULL THEN RETURN; END IF;
 -- A pending device has no existing active key to lock; new key insertion follows proof.
 SELECT * INTO ch FROM ap_m1.enrollment_challenges WHERE id=p_enrollment FOR UPDATE;
 v_now := clock_timestamp();
 IF NOT FOUND OR ch.device_id<>v_dev OR ch.consumed_at IS NULL OR ch.redeemed_at IS NOT NULL
    OR ch.consumed_at<=v_now-interval '60 seconds' THEN RETURN; END IF;
 UPDATE ap_m1.enrollment_challenges SET redeemed_at=v_now WHERE id=ch.id;
 UPDATE ap_m1.devices SET enrollment_state='ACTIVE' WHERE id=d.id;
 INSERT INTO ap_m1.device_key_records(device_id,fingerprint_sha256,created_at)
  VALUES(d.id,sha256(d.spki_public_key),v_now) RETURNING key_id INTO v_key;
 INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at)
  VALUES(d.id,v_key,p_new_token_sha256,'ENROLLMENT',v_now,v_now+make_interval(secs=>p_lifetime_seconds))
  RETURNING device_credentials.expires_at INTO v_exp;
 RETURN QUERY SELECT d.id,v_exp;
END $fn$;
-- Retention remains an engineering setting, not an approved legal schedule.
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
    AND NOT EXISTS(SELECT 1 FROM ap_m1.enrollment_challenges t WHERE t.device_id=x.id)
    AND NOT EXISTS(SELECT 1 FROM ap_m1.device_key_records t WHERE t.device_id=x.id)
    AND NOT EXISTS(SELECT 1 FROM ap_m1.device_credentials t WHERE t.device_id=x.id)
    AND NOT EXISTS(SELECT 1 FROM ap_m1.credential_renewal_challenges t WHERE t.device_id=x.id)
    AND NOT EXISTS(SELECT 1 FROM ap_m1.capability_snapshots t WHERE t.device_id=x.id)
    AND NOT EXISTS(SELECT 1 FROM ap_m1.device_health t WHERE t.device_id=x.id)
    AND NOT EXISTS(SELECT 1 FROM ap_m1.commands t WHERE t.device_id=x.id)
    AND NOT EXISTS(SELECT 1 FROM ap_m1.audit_events t WHERE t.actor_device_id=x.id);
  GET DIAGNOSTICS n=ROW_COUNT; e:=e+n;
 END LOOP;
 RETURN QUERY SELECT a,b,c,e;
END $fn$;

-- No default: an operator must supply an explicit synthetic engineering grace.
CREATE FUNCTION ap_m1.purge_pairing_codes(p_grace interval)
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
GRANT SELECT ON ap_m1.capability_snapshots, ap_m1.device_health,
 ap_m1.commands, ap_m1.audit_events TO ap_m1_auth;
GRANT DELETE ON ap_m1.pairing_codes TO ap_m1_auth;
ALTER FUNCTION ap_m1.purge_credential_artifacts(interval,interval,interval) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1.purge_pairing_codes(interval) OWNER TO ap_m1_auth;
REVOKE ALL ON FUNCTION ap_m1.purge_credential_artifacts(interval,interval,interval) FROM PUBLIC, ap_m1_api;
REVOKE ALL ON FUNCTION ap_m1.purge_pairing_codes(interval) FROM PUBLIC, ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.purge_credential_artifacts(interval,interval,interval) TO ap_m1_owner;
GRANT EXECUTE ON FUNCTION ap_m1.purge_pairing_codes(interval) TO ap_m1_owner;
COMMIT;
