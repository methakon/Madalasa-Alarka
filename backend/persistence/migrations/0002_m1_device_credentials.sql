-- Madalasa-Alarka M1 migration v0002 -- device credential lifecycle + family listing.
-- PostgreSQL 15+. Apply after 0001_m1_identity.sql, as the migration admin (not the app role).
-- SYNTHETIC DATA ONLY. Before real child data: India DPDP, guardian identity, retention and region signoffs.
--
-- Why: openapi-m1.yaml issues a short-lived device credential at enrollment and now lets the
-- device renew it by proving possession of its Keystore key. 0001 had no table for issued
-- credentials, so "revoked device is denied on its next call" had nothing to check against.
--
-- Design (same pattern as 0001): the credential tables have FORCE ROW LEVEL SECURITY and NO
-- policies, so the runtime role ap_m1_api can never read or write them directly. Access is only
-- through the audited SECURITY DEFINER functions below, owned by the non-login ap_m1_auth role.
-- Only SHA-256 hashes of tokens and nonces are stored, never the secrets.
--
-- CALLER CONTRACT (also in docs/M1_DEVICE_CREDENTIAL_LIFECYCLE.md):
--  * The backend verifies the ECDSA signature itself (no crypto in SQL) and passes the result as
--    p_proof_verified. complete_credential_renewal() consumes the challenge on EVERY attempt, so a
--    failed attempt cannot be retried. The caller MUST COMMIT after a NULL return, or the
--    consumption is rolled back and the challenge could be tried again.
--  * A NULL return never says why (unknown device, revoked, bad nonce, expired, already used).
BEGIN;
SET LOCAL ROLE ap_m1_owner;

CREATE TABLE ap_m1.device_credentials (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL REFERENCES ap_m1.devices(id),
 key_id uuid NOT NULL REFERENCES ap_m1.device_key_records(key_id),
 token_sha256 bytea NOT NULL UNIQUE CHECK (octet_length(token_sha256)=32),
 issued_via text NOT NULL CHECK (issued_via IN ('ENROLLMENT','RENEWAL')),
 issued_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL,
 revoked_at timestamptz,
 CHECK (expires_at > issued_at),
 -- Hard ceiling regardless of backend configuration: a credential can never outlive a day.
 CHECK (expires_at <= issued_at + interval '24 hours')
);
CREATE INDEX device_credentials_active_idx ON ap_m1.device_credentials(device_id)
 WHERE revoked_at IS NULL;

CREATE TABLE ap_m1.credential_renewal_challenges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL REFERENCES ap_m1.devices(id),
 key_id uuid NOT NULL REFERENCES ap_m1.device_key_records(key_id),
 nonce_sha256 bytea NOT NULL CHECK (octet_length(nonce_sha256)=32),
 expires_at timestamptz NOT NULL,
 consumed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK (expires_at > created_at),
 CHECK (expires_at <= created_at + interval '5 minutes')
);
CREATE INDEX renewal_challenges_open_idx ON ap_m1.credential_renewal_challenges(device_id)
 WHERE consumed_at IS NULL;

ALTER TABLE ap_m1.device_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.device_credentials FORCE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.credential_renewal_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.credential_renewal_challenges FORCE ROW LEVEL SECURITY;

-- Resolve a presented token (already hashed by the backend) to the device it authenticates.
-- Returns no row unless the credential is unexpired and unrevoked AND the device is still ACTIVE
-- AND its key is still ACTIVE, so revoking a device (parent UPDATE on devices) takes effect on its
-- very next call without having to find and revoke each credential.
CREATE FUNCTION ap_m1.authenticate_device_credential(p_token_sha256 bytea)
 RETURNS TABLE(device_id uuid, family_id uuid, child_id uuid, credential_id uuid, expires_at timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
 SELECT d.id, d.family_id, d.child_id, c.id, c.expires_at
 FROM ap_m1.device_credentials c
 JOIN ap_m1.devices d ON d.id = c.device_id
 JOIN ap_m1.device_key_records k ON k.key_id = c.key_id
 WHERE c.token_sha256 = p_token_sha256
   AND c.revoked_at IS NULL AND c.expires_at > now()
   AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL
   AND k.state = 'ACTIVE' AND k.revoked_at IS NULL;
 $fn$;

-- Public key the backend verifies a renewal signature against. Public keys are not secret, but
-- the answer is still NULL for pending, revoked or unknown devices so they cannot be told apart.
CREATE FUNCTION ap_m1.device_public_key(p_device uuid)
 RETURNS bytea LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path = pg_catalog, ap_m1 AS $fn$
 SELECT d.spki_public_key
 FROM ap_m1.devices d
 JOIN ap_m1.device_key_records k ON k.device_id = d.id AND k.state = 'ACTIVE' AND k.revoked_at IS NULL
 WHERE d.id = p_device AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL;
 $fn$;

-- Step 1 of renewal. Stores only the nonce HASH. NULL when the device is unknown, not ACTIVE,
-- the fingerprint does not match its active key, or it already has too many open challenges.
CREATE FUNCTION ap_m1.issue_credential_renewal_challenge(
  p_device uuid, p_key_fingerprint_sha256 bytea, p_nonce_sha256 bytea, p_ttl_seconds integer)
 RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER
 SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE v_key uuid; v_id uuid;
BEGIN
 IF p_ttl_seconds IS NULL OR p_ttl_seconds NOT BETWEEN 30 AND 300 THEN
  RAISE EXCEPTION 'challenge ttl must be 30..300 seconds' USING ERRCODE = '22023';
 END IF;
 SELECT k.key_id INTO v_key
 FROM ap_m1.devices d
 JOIN ap_m1.device_key_records k ON k.device_id = d.id AND k.state = 'ACTIVE' AND k.revoked_at IS NULL
 WHERE d.id = p_device AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL
   AND k.fingerprint_sha256 = p_key_fingerprint_sha256;
 IF NOT FOUND THEN RETURN NULL; END IF;
 -- Bound unauthenticated table growth per device (the API also rate limits).
 IF (SELECT count(*) FROM ap_m1.credential_renewal_challenges
      WHERE device_id = p_device AND consumed_at IS NULL AND expires_at > now()) >= 5 THEN
  RETURN NULL;
 END IF;
 INSERT INTO ap_m1.credential_renewal_challenges(device_id, key_id, nonce_sha256, expires_at)
 VALUES (p_device, v_key, p_nonce_sha256, now() + make_interval(secs => p_ttl_seconds))
 RETURNING id INTO v_id;
 RETURN v_id;
END $fn$;

-- Step 2 of renewal. Returns the new credential's expiry, or NULL on any failure.
-- The challenge is consumed on every attempt that reaches a live, unused challenge for this
-- device -- including a failed proof or wrong nonce -- so it can never be guessed at.
-- On success every earlier credential of the device is revoked (one live credential per device).
CREATE FUNCTION ap_m1.complete_credential_renewal(
  p_device uuid, p_challenge uuid, p_nonce_sha256 bytea, p_proof_verified boolean,
  p_new_token_sha256 bytea, p_lifetime_seconds integer)
 RETURNS timestamptz LANGUAGE plpgsql VOLATILE SECURITY DEFINER
 SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.credential_renewal_challenges%ROWTYPE; v_expires timestamptz;
BEGIN
 IF p_lifetime_seconds IS NULL OR p_lifetime_seconds NOT BETWEEN 300 AND 86400 THEN
  RAISE EXCEPTION 'credential lifetime must be 300..86400 seconds' USING ERRCODE = '22023';
 END IF;
 SELECT * INTO ch FROM ap_m1.credential_renewal_challenges
  WHERE id = p_challenge AND device_id = p_device FOR UPDATE;
 IF NOT FOUND THEN RETURN NULL; END IF;
 IF ch.consumed_at IS NOT NULL OR ch.expires_at <= now() THEN RETURN NULL; END IF;
 UPDATE ap_m1.credential_renewal_challenges SET consumed_at = now() WHERE id = ch.id;
 IF p_proof_verified IS NOT TRUE OR ch.nonce_sha256 <> p_nonce_sha256 THEN RETURN NULL; END IF;
 PERFORM 1 FROM ap_m1.devices d
  JOIN ap_m1.device_key_records k ON k.key_id = ch.key_id AND k.state = 'ACTIVE' AND k.revoked_at IS NULL
  WHERE d.id = p_device AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE ap_m1.device_credentials SET revoked_at = now()
  WHERE device_id = p_device AND revoked_at IS NULL;
 INSERT INTO ap_m1.device_credentials(device_id, key_id, token_sha256, issued_via, expires_at)
 VALUES (p_device, ch.key_id, p_new_token_sha256, 'RENEWAL', now() + make_interval(secs => p_lifetime_seconds))
 RETURNING expires_at INTO v_expires;
 RETURN v_expires;
END $fn$;

-- GET /families. 0001's policies need a family in context, so they cannot answer "which
-- families am I in?" -- and a non-owner guardian cannot read the families row at all.
-- This lists only families where the signed-in principal (ap.principal_id) has a live membership.
CREATE FUNCTION ap_m1.list_my_families()
 RETURNS TABLE(id uuid, label text, status text, membership_role text)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
 SELECT f.id, f.label, f.state, m.membership_role
 FROM ap_m1.guardian_memberships m
 JOIN ap_m1.families f ON f.id = m.family_id
 WHERE m.principal_id = ap_m1.ctx_principal() AND m.revoked_at IS NULL
 ORDER BY f.created_at, f.id;
 $fn$;

RESET ROLE;
GRANT SELECT ON ap_m1.device_key_records, ap_m1.families TO ap_m1_auth;
GRANT SELECT, INSERT, UPDATE ON ap_m1.device_credentials,
 ap_m1.credential_renewal_challenges TO ap_m1_auth;
ALTER FUNCTION ap_m1.authenticate_device_credential(bytea) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1.device_public_key(uuid) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1.issue_credential_renewal_challenge(uuid,bytea,bytea,integer) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1.complete_credential_renewal(uuid,uuid,bytea,boolean,bytea,integer) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1.list_my_families() OWNER TO ap_m1_auth;
-- Functions are executable by PUBLIC unless revoked; these must only run as the API role.
REVOKE ALL ON FUNCTION ap_m1.authenticate_device_credential(bytea) FROM PUBLIC;
REVOKE ALL ON FUNCTION ap_m1.device_public_key(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION ap_m1.issue_credential_renewal_challenge(uuid,bytea,bytea,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ap_m1.complete_credential_renewal(uuid,uuid,bytea,boolean,bytea,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ap_m1.list_my_families() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.authenticate_device_credential(bytea) TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.device_public_key(uuid) TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.issue_credential_renewal_challenge(uuid,bytea,bytea,integer) TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.complete_credential_renewal(uuid,uuid,bytea,boolean,bytea,integer) TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.list_my_families() TO ap_m1_api;
COMMIT;

-- NOT in this migration (still open, see docs/M1_DEVICE_CREDENTIAL_LIFECYCLE.md):
--  * the INITIAL credential issued when enrollment proof succeeds (belongs to the enrollment
--    SECURITY DEFINER flow that 0001 already defers);
--  * retention/cleanup of expired credentials and consumed challenges;
--  * key rotation without full re-enrollment.
