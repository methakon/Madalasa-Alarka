-- Madalasa-Alarka M1 migration v0003 -- enrollment flow, commit-safe renewal, cleanup, PUBLIC lockdown.
-- PostgreSQL 15+. Apply after 0001 and 0002, as the migration admin (not the app role).
-- SYNTHETIC DATA ONLY. Before real child data: India DPDP, guardian identity, retention and region signoffs.
--
-- What this closes (all were listed as open in docs/M1_DEVICE_CREDENTIAL_LIFECYCLE.md):
--  1. Every function in schema ap_m1 was executable by PUBLIC. Schema USAGE kept that harmless in
--     practice, but it is defense in depth we should not rely on. Revoked, and made the default
--     for future functions.
--  2. complete_credential_renewal() only burned a failed challenge if the CALLER committed. Replaced
--     by a two-step flow in which the burn commits BEFORE the signature is checked, so a rollback
--     can no longer un-burn a challenge.
--  3. The deferred enrollment flow: redeem a one-use pairing code, prove key possession, activate the
--     device and issue its FIRST credential.
--  4. Retention/cleanup of expired credentials, challenges and unused enrollments.
--
-- TWO-STEP PATTERN (enrollment and renewal), caller contract:
--   tx1: consume_*()            -> returns the nonce hash + public key; the challenge is now spent. COMMIT.
--   (backend, no transaction)   -> checks nonce equality and the ECDSA signature.
--   tx2: issue_*()/activate_*() -> only if tx1 happened < 60 s ago, once. On a failed proof just do not call it.
-- A rollback of tx2 fails closed (the device simply retries with a fresh challenge). Nothing a rollback
-- does can make a spent challenge usable again. NULL / zero rows never say why.
BEGIN;
SET LOCAL ROLE ap_m1_owner;

ALTER TABLE ap_m1.credential_renewal_challenges ADD COLUMN redeemed_at timestamptz;
ALTER TABLE ap_m1.enrollment_challenges ADD COLUMN redeemed_at timestamptz;
-- A challenge can only be redeemed after it was consumed.
ALTER TABLE ap_m1.credential_renewal_challenges
 ADD CONSTRAINT renewal_redeem_after_consume CHECK (redeemed_at IS NULL OR consumed_at IS NOT NULL);
ALTER TABLE ap_m1.enrollment_challenges
 ADD CONSTRAINT enrollment_redeem_after_consume CHECK (redeemed_at IS NULL OR consumed_at IS NOT NULL);
-- Enrollment challenges must also be short-lived (0001 only required expires_at > created_at).
ALTER TABLE ap_m1.enrollment_challenges
 ADD CONSTRAINT enrollment_challenge_max_ttl CHECK (expires_at <= created_at + interval '10 minutes');

-- ---------------------------------------------------------------- enrollment
-- POST /enrollment. Consumes the pairing code exactly once and creates a PENDING_PROOF device bound to
-- the presented public key (SPKI, DER). Returns no row for an unknown, expired, used or exhausted code.
CREATE FUNCTION ap_m1.redeem_pairing_code(
  p_code_sha256 bytea, p_spki bytea, p_nonce_sha256 bytea, p_ttl_seconds integer)
 RETURNS TABLE(enrollment_id uuid, device_id uuid)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE pc ap_m1.pairing_codes%ROWTYPE; v_dev uuid; v_enr uuid;
BEGIN
 IF p_ttl_seconds IS NULL OR p_ttl_seconds NOT BETWEEN 30 AND 600 THEN
  RAISE EXCEPTION 'enrollment challenge ttl must be 30..600 seconds' USING ERRCODE = '22023';
 END IF;
 IF p_spki IS NULL OR octet_length(p_spki) NOT BETWEEN 80 AND 4096
    OR p_nonce_sha256 IS NULL OR octet_length(p_nonce_sha256) <> 32 THEN
  RAISE EXCEPTION 'malformed enrollment input' USING ERRCODE = '22023';
 END IF;
 SELECT * INTO pc FROM ap_m1.pairing_codes WHERE code_sha256 = p_code_sha256 FOR UPDATE;
 IF NOT FOUND THEN RETURN; END IF;
 IF pc.consumed_at IS NOT NULL OR pc.expires_at <= now() OR pc.attempt_count >= 20 THEN RETURN; END IF;
 UPDATE ap_m1.pairing_codes SET consumed_at = now(), attempt_count = attempt_count + 1 WHERE id = pc.id;
 INSERT INTO ap_m1.devices(family_id, child_id, spki_public_key)
  VALUES (pc.family_id, pc.child_id, p_spki) RETURNING id INTO v_dev;
 INSERT INTO ap_m1.enrollment_challenges(device_id, nonce_sha256, expires_at)
  VALUES (v_dev, p_nonce_sha256, now() + make_interval(secs => p_ttl_seconds)) RETURNING id INTO v_enr;
 RETURN QUERY SELECT v_enr, v_dev;
END $fn$;

-- POST /enrollment/{id}/proof, step 1 (commit after this). Spends the challenge and returns what the
-- backend needs to verify the signature. Zero rows if unknown, spent, expired or the device is not PENDING_PROOF.
CREATE FUNCTION ap_m1.consume_enrollment_challenge(p_enrollment uuid)
 RETURNS TABLE(device_id uuid, nonce_sha256 bytea, spki_public_key bytea)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.enrollment_challenges%ROWTYPE;
BEGIN
 SELECT * INTO ch FROM ap_m1.enrollment_challenges WHERE id = p_enrollment FOR UPDATE;
 IF NOT FOUND OR ch.consumed_at IS NOT NULL OR ch.expires_at <= now() THEN RETURN; END IF;
 UPDATE ap_m1.enrollment_challenges SET consumed_at = now() WHERE id = ch.id;
 RETURN QUERY SELECT d.id, ch.nonce_sha256, d.spki_public_key FROM ap_m1.devices d
  WHERE d.id = ch.device_id AND d.enrollment_state = 'PENDING_PROOF' AND d.revoked_at IS NULL;
END $fn$;

-- Step 2, only after the backend verified the signature. Activates the device, records its key and issues
-- the first credential, atomically. Works once, within 60 s of step 1, on a still-PENDING_PROOF device.
CREATE FUNCTION ap_m1.activate_enrolled_device(
  p_enrollment uuid, p_new_token_sha256 bytea, p_lifetime_seconds integer)
 RETURNS TABLE(device_id uuid, expires_at timestamptz)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.enrollment_challenges%ROWTYPE; d ap_m1.devices%ROWTYPE; v_key uuid; v_exp timestamptz;
BEGIN
 IF p_lifetime_seconds IS NULL OR p_lifetime_seconds NOT BETWEEN 300 AND 86400 THEN
  RAISE EXCEPTION 'credential lifetime must be 300..86400 seconds' USING ERRCODE = '22023';
 END IF;
 SELECT * INTO ch FROM ap_m1.enrollment_challenges WHERE id = p_enrollment FOR UPDATE;
 IF NOT FOUND OR ch.consumed_at IS NULL OR ch.redeemed_at IS NOT NULL
    OR ch.consumed_at < now() - interval '60 seconds' THEN RETURN; END IF;
 SELECT * INTO d FROM ap_m1.devices WHERE id = ch.device_id FOR UPDATE;
 IF NOT FOUND OR d.enrollment_state <> 'PENDING_PROOF' OR d.revoked_at IS NOT NULL THEN RETURN; END IF;
 UPDATE ap_m1.enrollment_challenges SET redeemed_at = now() WHERE id = ch.id;
 UPDATE ap_m1.devices SET enrollment_state = 'ACTIVE' WHERE id = d.id;
 INSERT INTO ap_m1.device_key_records(device_id, fingerprint_sha256)
  VALUES (d.id, sha256(d.spki_public_key)) RETURNING key_id INTO v_key;
 INSERT INTO ap_m1.device_credentials(device_id, key_id, token_sha256, issued_via, expires_at)
  VALUES (d.id, v_key, p_new_token_sha256, 'ENROLLMENT', now() + make_interval(secs => p_lifetime_seconds))
  RETURNING device_credentials.expires_at INTO v_exp;
 RETURN QUERY SELECT d.id, v_exp;
END $fn$;

-- ---------------------------------------------------------------- renewal, commit-safe
DROP FUNCTION ap_m1.complete_credential_renewal(uuid,uuid,bytea,boolean,bytea,integer);

-- Step 1 (commit after this). Spends the challenge; returns the data to verify the signature.
CREATE FUNCTION ap_m1.consume_renewal_challenge(p_device uuid, p_challenge uuid)
 RETURNS TABLE(nonce_sha256 bytea, spki_public_key bytea)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.credential_renewal_challenges%ROWTYPE;
BEGIN
 SELECT * INTO ch FROM ap_m1.credential_renewal_challenges
  WHERE id = p_challenge AND device_id = p_device FOR UPDATE;
 IF NOT FOUND OR ch.consumed_at IS NOT NULL OR ch.expires_at <= now() THEN RETURN; END IF;
 UPDATE ap_m1.credential_renewal_challenges SET consumed_at = now() WHERE id = ch.id;
 RETURN QUERY SELECT ch.nonce_sha256, d.spki_public_key
  FROM ap_m1.devices d JOIN ap_m1.device_key_records k ON k.key_id = ch.key_id
  WHERE d.id = p_device AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL
    AND k.state = 'ACTIVE' AND k.revoked_at IS NULL;
END $fn$;

-- Step 2, only after the backend verified the signature. Once per challenge, within 60 s of step 1.
-- Revokes every earlier credential of the device (one live credential per device).
CREATE FUNCTION ap_m1.issue_renewal_credential(
  p_device uuid, p_challenge uuid, p_new_token_sha256 bytea, p_lifetime_seconds integer)
 RETURNS timestamptz
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.credential_renewal_challenges%ROWTYPE; v_exp timestamptz;
BEGIN
 IF p_lifetime_seconds IS NULL OR p_lifetime_seconds NOT BETWEEN 300 AND 86400 THEN
  RAISE EXCEPTION 'credential lifetime must be 300..86400 seconds' USING ERRCODE = '22023';
 END IF;
 SELECT * INTO ch FROM ap_m1.credential_renewal_challenges
  WHERE id = p_challenge AND device_id = p_device FOR UPDATE;
 IF NOT FOUND OR ch.consumed_at IS NULL OR ch.redeemed_at IS NOT NULL
    OR ch.consumed_at < now() - interval '60 seconds' THEN RETURN NULL; END IF;
 PERFORM 1 FROM ap_m1.devices d
  JOIN ap_m1.device_key_records k ON k.key_id = ch.key_id AND k.state = 'ACTIVE' AND k.revoked_at IS NULL
  WHERE d.id = p_device AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE ap_m1.credential_renewal_challenges SET redeemed_at = now() WHERE id = ch.id;
 UPDATE ap_m1.device_credentials SET revoked_at = now() WHERE device_id = p_device AND revoked_at IS NULL;
 INSERT INTO ap_m1.device_credentials(device_id, key_id, token_sha256, issued_via, expires_at)
  VALUES (p_device, ch.key_id, p_new_token_sha256, 'RENEWAL', now() + make_interval(secs => p_lifetime_seconds))
  RETURNING expires_at INTO v_exp;
 RETURN v_exp;
END $fn$;

-- ---------------------------------------------------------------- retention
-- Run by a scheduled job as ap_m1_owner (NOT executable by the API role). Hash-only rows hold no personal
-- data, but unbounded growth on anonymous endpoints is a denial-of-service risk, so they are trimmed.
-- Floors stop a bad config from erasing evidence needed to investigate an incident.
CREATE FUNCTION ap_m1.purge_credential_artifacts(
  p_credential_grace interval DEFAULT interval '30 days',
  p_challenge_grace interval DEFAULT interval '1 day',
  p_unused_enrollment_grace interval DEFAULT interval '7 days')
 RETURNS TABLE(credentials_deleted bigint, renewal_challenges_deleted bigint,
               enrollment_challenges_deleted bigint, abandoned_devices_deleted bigint)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE a bigint; b bigint; c bigint; e bigint;
BEGIN
 IF p_credential_grace < interval '1 day' OR p_challenge_grace < interval '1 hour'
    OR p_unused_enrollment_grace < interval '1 day' THEN
  RAISE EXCEPTION 'retention grace below the safety floor' USING ERRCODE = '22023';
 END IF;
 DELETE FROM ap_m1.device_credentials
  WHERE least(expires_at, coalesce(revoked_at, expires_at)) < now() - p_credential_grace;
 GET DIAGNOSTICS a = ROW_COUNT;
 DELETE FROM ap_m1.credential_renewal_challenges
  WHERE expires_at < now() - p_challenge_grace OR consumed_at < now() - p_challenge_grace;
 GET DIAGNOSTICS b = ROW_COUNT;
 -- Devices that never completed proof (still PENDING_PROOF, challenge long expired) and their challenges.
 DELETE FROM ap_m1.enrollment_challenges ec USING ap_m1.devices d
  WHERE d.id = ec.device_id AND d.enrollment_state = 'PENDING_PROOF'
    AND ec.expires_at < now() - p_unused_enrollment_grace;
 GET DIAGNOSTICS c = ROW_COUNT;
 DELETE FROM ap_m1.devices d WHERE d.enrollment_state = 'PENDING_PROOF'
  AND NOT EXISTS (SELECT 1 FROM ap_m1.enrollment_challenges ec WHERE ec.device_id = d.id)
  AND NOT EXISTS (SELECT 1 FROM ap_m1.device_key_records k WHERE k.device_id = d.id)
  AND d.created_at < now() - p_unused_enrollment_grace;
 GET DIAGNOSTICS e = ROW_COUNT;
 RETURN QUERY SELECT a, b, c, e;
END $fn$;

RESET ROLE;
-- The definer role needs exactly the rights these functions use, no more.
GRANT SELECT, UPDATE ON ap_m1.pairing_codes TO ap_m1_auth;
GRANT SELECT, INSERT, UPDATE, DELETE ON ap_m1.enrollment_challenges TO ap_m1_auth;
GRANT SELECT, INSERT, UPDATE, DELETE ON ap_m1.devices TO ap_m1_auth;
GRANT SELECT, INSERT ON ap_m1.device_key_records TO ap_m1_auth;
GRANT DELETE ON ap_m1.device_credentials, ap_m1.credential_renewal_challenges TO ap_m1_auth;

DO $own$
DECLARE f text;
BEGIN
 FOREACH f IN ARRAY ARRAY[
  'redeem_pairing_code(bytea,bytea,bytea,integer)','consume_enrollment_challenge(uuid)',
  'activate_enrolled_device(uuid,bytea,integer)','consume_renewal_challenge(uuid,uuid)',
  'issue_renewal_credential(uuid,uuid,bytea,integer)',
  'purge_credential_artifacts(interval,interval,interval)'] LOOP
  EXECUTE format('ALTER FUNCTION ap_m1.%s OWNER TO ap_m1_auth', f);
 END LOOP;
END $own$;

-- ---------------------------------------------------------------- PUBLIC lockdown
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA ap_m1 FROM PUBLIC;
-- Policy helpers are called by the invoker (ap_m1_api) and by definer functions (ap_m1_auth).
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ap_m1 TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.ctx_family(), ap_m1.ctx_principal(), ap_m1.ctx_device() TO ap_m1_auth;
-- The retention job is not an API operation.
REVOKE EXECUTE ON FUNCTION ap_m1.purge_credential_artifacts(interval,interval,interval) FROM ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.purge_credential_artifacts(interval,interval,interval) TO ap_m1_owner;
-- Future functions created by these roles start with NO PUBLIC execute.
ALTER DEFAULT PRIVILEGES FOR ROLE ap_m1_owner REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE ap_m1_auth REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
-- (No unscoped default: it would also change functions in unrelated schemas. Test CL_04 fails CI if any
--  ap_m1 function is ever left executable by PUBLIC, e.g. one created by the migration admin.)
COMMIT;
