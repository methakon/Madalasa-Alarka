-- Additive convergence of clean V2 and historical M1 + V2 lineages.
-- Runner owns transaction. SOURCE ONLY; parent replays in disposable local DB.
-- Cryptographic proof remains the trusted issuer's responsibility: the API may
-- neither consume proof nor activate/issue credentials. Commit consume before
-- verifying the signature; issue once within 60 seconds of consumption.
-- Historical credentials have no trustworthy generation snapshot: retain rows
-- but revoke them, requiring fresh proof. Never infer historical authorization.

-- Immutable 0016 used text key/digest fields. Fail closed on ANY invalid row,
-- including expired rows: do not drop data, invent UUIDs, or fabricate binding.
GRANT SELECT ON ap_m1.credential_renewal_challenges TO ap_db_executor;
SET LOCAL ROLE ap_db_executor;
DO $convert$
BEGIN
 IF EXISTS(SELECT 1 FROM ap_m1.credential_renewal_challenges ch
  LEFT JOIN ap_m1.device_key_records k ON k.key_id::text=ch.key_id AND k.device_id=ch.device_id
  WHERE k.key_id IS NULL OR ch.nonce_sha256 !~ '^[0-9a-fA-F]{64}$'
    OR ch.expires_at>ch.created_at+interval '5 minutes'
    OR (ch.redeemed_at IS NOT NULL AND ch.consumed_at IS NULL)) THEN
  RAISE EXCEPTION 'unconvertible V2 renewal challenge: valid device/key binding, hex digest and short TTL required';
 END IF;
END $convert$;
RESET ROLE;
-- Remove the text CHECKs before changing types; use a real UUID FK afterwards.
DO $checks$
DECLARE r record;
BEGIN
 FOR r IN SELECT conname FROM pg_constraint
 WHERE conrelid='ap_m1.credential_renewal_challenges'::regclass AND contype='c' LOOP
 EXECUTE format('ALTER TABLE ap_m1.credential_renewal_challenges DROP CONSTRAINT %I',r.conname);
 END LOOP;
END $checks$;
ALTER TABLE ap_m1.credential_renewal_challenges
 ALTER COLUMN key_id TYPE uuid USING key_id::uuid,
 ALTER COLUMN nonce_sha256 TYPE bytea USING decode(nonce_sha256,'hex'),
 ADD CONSTRAINT renewal_key_fk FOREIGN KEY(key_id) REFERENCES ap_m1.device_key_records(key_id),
 ADD CONSTRAINT renewal_digest_length CHECK(octet_length(nonce_sha256)=32),
 ADD CONSTRAINT renewal_positive_ttl CHECK(expires_at>created_at),
 ADD CONSTRAINT renewal_max_ttl CHECK(expires_at<=created_at+interval '5 minutes'),
 ADD CONSTRAINT renewal_redeem_after_consume CHECK(redeemed_at IS NULL OR consumed_at IS NOT NULL);
-- Only newly issued challenges have a trustworthy binding snapshot. Preserve
-- old challenge timestamps/state, but require a fresh challenge before issuance.
ALTER TABLE ap_m1.credential_renewal_challenges
 ADD COLUMN bound_key_generation bigint CHECK(bound_key_generation>0),
 ADD COLUMN bound_key_fingerprint_sha256 bytea CHECK(octet_length(bound_key_fingerprint_sha256)=32);
-- No cascading delete of device dependents. Purge inventory controls removal.
ALTER TABLE ap_m1.credential_renewal_challenges DROP CONSTRAINT credential_renewal_challenges_device_id_fkey;
ALTER TABLE ap_m1.credential_renewal_challenges ADD CONSTRAINT credential_renewal_challenges_device_id_fkey
 FOREIGN KEY(device_id) REFERENCES ap_m1.devices(id);
GRANT INSERT ON ap_m1.credential_renewal_challenges TO ap_db_executor;
DO $historical_grant$
BEGIN
 IF to_regclass('ap_m1.m1_historical_renewal_challenges') IS NOT NULL THEN
  GRANT SELECT ON ap_m1.m1_historical_renewal_challenges TO ap_db_executor;
 END IF;
END $historical_grant$;
SET LOCAL ROLE ap_db_executor;
DO $merge$
BEGIN
 IF to_regclass('ap_m1.m1_historical_renewal_challenges') IS NOT NULL THEN
 INSERT INTO ap_m1.credential_renewal_challenges(id,device_id,key_id,nonce_sha256,created_at,expires_at,consumed_at,redeemed_at)
 SELECT id,device_id,key_id,nonce_sha256,created_at,expires_at,consumed_at,redeemed_at
 FROM ap_m1.m1_historical_renewal_challenges;
 -- Collision/invalid data aborts the transaction, never ON CONFLICT DO NOTHING.
 END IF;
END $merge$;
RESET ROLE;
DROP TABLE IF EXISTS ap_m1.m1_historical_renewal_challenges;
CREATE INDEX IF NOT EXISTS renewal_challenges_open_idx ON ap_m1.credential_renewal_challenges(device_id) WHERE consumed_at IS NULL;

CREATE TABLE IF NOT EXISTS ap_m1.device_credentials (
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
ALTER TABLE ap_m1.device_credentials ADD COLUMN IF NOT EXISTS bound_key_generation bigint,
 ADD COLUMN IF NOT EXISTS bound_key_fingerprint_sha256 bytea;
GRANT SELECT,UPDATE ON ap_m1.device_credentials TO ap_db_executor;
SET LOCAL ROLE ap_db_executor;
UPDATE ap_m1.device_credentials SET revoked_at=coalesce(revoked_at,statement_timestamp())
 WHERE bound_key_generation IS NULL OR bound_key_fingerprint_sha256 IS NULL;
RESET ROLE;
ALTER TABLE ap_m1.device_credentials ADD CONSTRAINT credential_binding_snapshot CHECK(
 (bound_key_generation>0 AND octet_length(bound_key_fingerprint_sha256)=32
 AND bound_key_generation IS NOT NULL AND bound_key_fingerprint_sha256 IS NOT NULL) OR revoked_at IS NOT NULL);
CREATE INDEX IF NOT EXISTS device_credentials_active_idx ON ap_m1.device_credentials(device_id) WHERE revoked_at IS NULL;
ALTER TABLE ap_m1.enrollment_challenges ADD COLUMN IF NOT EXISTS redeemed_at timestamptz;
ALTER TABLE ap_m1.enrollment_challenges DROP CONSTRAINT IF EXISTS enrollment_redeem_after_consume;
ALTER TABLE ap_m1.enrollment_challenges ADD CONSTRAINT enrollment_redeem_after_consume CHECK(redeemed_at IS NULL OR consumed_at IS NOT NULL);
-- NOT VALID preserves preexisting rows without weakening new-write enforcement.
ALTER TABLE ap_m1.enrollment_challenges DROP CONSTRAINT IF EXISTS enrollment_challenge_max_ttl;
ALTER TABLE ap_m1.enrollment_challenges ADD CONSTRAINT enrollment_challenge_max_ttl
 CHECK(expires_at<=created_at+interval '10 minutes') NOT VALID;

-- One authoritative idempotency store: extend V2 claims and expose M1 as a view.
ALTER TABLE ap_m1.idempotency_claims ADD COLUMN response_status integer CHECK(response_status BETWEEN 200 AND 299),
 ADD COLUMN response_body jsonb CHECK(response_body IS NULL OR octet_length(response_body::text)<=8192),
 ADD COLUMN body_omitted boolean NOT NULL DEFAULT false,
 ADD COLUMN completed_at timestamptz,
 ADD CONSTRAINT idempotency_response_completion CHECK((response_status IS NULL)=(completed_at IS NULL)),
 ADD CONSTRAINT idempotency_omitted_body CHECK(NOT body_omitted OR response_body IS NULL);
DO $idempotency_grant$
BEGIN
 IF to_regclass('ap_m1.idempotency_keys') IS NOT NULL THEN
  GRANT SELECT ON ap_m1.idempotency_keys TO ap_db_executor;
 END IF;
END $idempotency_grant$;
GRANT INSERT ON ap_m1.idempotency_claims TO ap_db_executor;
SET LOCAL ROLE ap_db_executor;
DO $idem$
BEGIN
 IF to_regclass('ap_m1.idempotency_keys') IS NOT NULL THEN
 INSERT INTO ap_m1.idempotency_claims(actor_id,namespace,key_sha256,request_sha256,created_at,expires_at,
 state,response_status,response_body,body_omitted,completed_at)
 SELECT actor_id,namespace,key_sha256,request_sha256,created_at,expires_at,
 CASE WHEN completed_at IS NULL THEN 'CLAIMED' ELSE 'COMPLETED' END,
 response_status,response_body,body_omitted,completed_at FROM ap_m1.idempotency_keys;
 END IF;
END $idem$;
RESET ROLE;
DROP TABLE IF EXISTS ap_m1.idempotency_keys;
CREATE VIEW ap_m1.idempotency_keys WITH(security_invoker=true) AS
 SELECT actor_id,namespace,key_sha256,request_sha256,response_status,response_body,body_omitted,
 created_at,completed_at,expires_at FROM ap_m1.idempotency_claims;
ALTER VIEW ap_m1.idempotency_keys OWNER TO ap_m1_owner;

-- Shared, context-independent *lookup* of the current V2 authorization binding.
CREATE OR REPLACE FUNCTION ap_m1._m1_key_live(p_device uuid,p_key uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $fn$
 SELECT EXISTS(SELECT 1 FROM ap_m1.devices d JOIN ap_m1.device_key_records k ON k.device_id=d.id
 WHERE d.id=p_device AND k.key_id=p_key AND d.enrollment_state='ACTIVE' AND d.revoked_at IS NULL
 AND k.state='ACTIVE' AND k.revoked_at IS NULL AND k.generation>0
 AND k.fingerprint_sha256=public.digest(d.spki_public_key,'sha256')
 AND NOT ap_m1.child_deleted(d.child_id) AND ap_m1.has_consent(d.child_id,'CORE'));
$fn$;
CREATE OR REPLACE FUNCTION ap_m1.authenticate_device_credential(p_token_sha256 bytea)
 RETURNS TABLE(device_id uuid, family_id uuid, child_id uuid, credential_id uuid, expires_at timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
 SELECT d.id, d.family_id, d.child_id, c.id, c.expires_at
 FROM ap_m1.device_credentials c
 JOIN ap_m1.devices d ON d.id = c.device_id
 JOIN ap_m1.device_key_records k ON k.key_id = c.key_id
 WHERE c.token_sha256 = p_token_sha256
   AND c.revoked_at IS NULL AND c.expires_at > now()
   AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL
   AND k.state = 'ACTIVE' AND k.revoked_at IS NULL
   AND ap_m1._m1_key_live(d.id,k.key_id)
   AND c.bound_key_generation=k.generation
   AND c.bound_key_fingerprint_sha256=k.fingerprint_sha256;
 $fn$;

CREATE OR REPLACE FUNCTION ap_m1.device_public_key(p_device uuid)
 RETURNS bytea LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path = pg_catalog, ap_m1 AS $fn$
 SELECT d.spki_public_key
 FROM ap_m1.devices d
 JOIN ap_m1.device_key_records k ON k.device_id = d.id AND k.state = 'ACTIVE' AND k.revoked_at IS NULL
 WHERE d.id = p_device AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL AND ap_m1._m1_key_live(d.id,k.key_id);
 $fn$;

CREATE OR REPLACE FUNCTION ap_m1.issue_credential_renewal_challenge(
  p_device uuid, p_key_fingerprint_sha256 bytea, p_nonce_sha256 bytea, p_ttl_seconds integer)
 RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER
 SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE v_key uuid; v_generation bigint; v_fingerprint bytea; v_id uuid;
BEGIN
 IF p_ttl_seconds IS NULL OR p_ttl_seconds NOT BETWEEN 30 AND 300 THEN
  RAISE EXCEPTION 'challenge ttl must be 30..300 seconds' USING ERRCODE = '22023';
 END IF;
 SELECT k.key_id,k.generation,k.fingerprint_sha256 INTO v_key,v_generation,v_fingerprint
 FROM ap_m1.devices d
 JOIN ap_m1.device_key_records k ON k.device_id = d.id AND k.state = 'ACTIVE' AND k.revoked_at IS NULL
 WHERE d.id = p_device AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL
   AND k.fingerprint_sha256 = p_key_fingerprint_sha256 AND ap_m1._m1_key_live(d.id,k.key_id) FOR UPDATE OF d,k;
 IF NOT FOUND THEN RETURN NULL; END IF;
 -- Bound unauthenticated table growth per device (the API also rate limits).
 IF (SELECT count(*) FROM ap_m1.credential_renewal_challenges
      WHERE device_id = p_device AND consumed_at IS NULL AND expires_at > now()) >= 5 THEN
  RETURN NULL;
 END IF;
 INSERT INTO ap_m1.credential_renewal_challenges(device_id, key_id, nonce_sha256, expires_at,bound_key_generation,bound_key_fingerprint_sha256)
 VALUES (p_device, v_key, p_nonce_sha256, now() + make_interval(secs => p_ttl_seconds),v_generation,v_fingerprint)
 RETURNING id INTO v_id;
 RETURN v_id;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.list_my_families()
 RETURNS TABLE(id uuid, label text, status text, membership_role text)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
 SELECT f.id, f.label, f.state, m.membership_role
 FROM ap_m1.guardian_memberships m
 JOIN ap_m1.families f ON f.id = m.family_id
 WHERE m.principal_id = ap_m1.ctx_principal() AND m.revoked_at IS NULL AND f.state='ACTIVE'
 ORDER BY f.created_at, f.id;
 $fn$;

CREATE OR REPLACE FUNCTION ap_m1.redeem_pairing_code(
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
 IF ap_m1.child_deleted(pc.child_id) OR NOT ap_m1.has_consent(pc.child_id,'CORE')
 OR NOT ap_m1._adult_has_scope(pc.child_id,pc.issued_by,'PAIR_DEVICE') THEN RETURN; END IF;
 IF pc.consumed_at IS NOT NULL OR pc.expires_at <= now() OR pc.attempt_count >= 20 THEN RETURN; END IF;
 UPDATE ap_m1.pairing_codes SET consumed_at = now(), attempt_count = attempt_count + 1 WHERE id = pc.id;
 INSERT INTO ap_m1.devices(family_id, child_id, spki_public_key)
  VALUES (pc.family_id, pc.child_id, p_spki) RETURNING id INTO v_dev;
 INSERT INTO ap_m1.enrollment_challenges(device_id, nonce_sha256, expires_at)
  VALUES (v_dev, p_nonce_sha256, now() + make_interval(secs => p_ttl_seconds)) RETURNING id INTO v_enr;
 RETURN QUERY SELECT v_enr, v_dev;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.consume_enrollment_challenge(p_enrollment uuid)
 RETURNS TABLE(device_id uuid, nonce_sha256 bytea, spki_public_key bytea)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.enrollment_challenges%ROWTYPE;
BEGIN
 SELECT * INTO ch FROM ap_m1.enrollment_challenges WHERE id = p_enrollment FOR UPDATE;
 IF NOT FOUND OR ch.consumed_at IS NOT NULL OR ch.expires_at <= now() THEN RETURN; END IF;
 UPDATE ap_m1.enrollment_challenges SET consumed_at = now() WHERE id = ch.id;
 RETURN QUERY SELECT d.id, ch.nonce_sha256, d.spki_public_key FROM ap_m1.devices d
  WHERE d.id = ch.device_id AND d.enrollment_state = 'PENDING_PROOF' AND d.revoked_at IS NULL AND NOT ap_m1.child_deleted(d.child_id) AND ap_m1.has_consent(d.child_id,'CORE');
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.activate_enrolled_device(
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
 IF NOT FOUND OR d.enrollment_state <> 'PENDING_PROOF' OR d.revoked_at IS NOT NULL OR ch.expires_at<=now()
 OR ap_m1.child_deleted(d.child_id) OR NOT ap_m1.has_consent(d.child_id,'CORE') THEN RETURN; END IF;
 UPDATE ap_m1.enrollment_challenges SET redeemed_at = now() WHERE id = ch.id;
 UPDATE ap_m1.devices SET enrollment_state = 'ACTIVE' WHERE id = d.id;
 INSERT INTO ap_m1.device_key_records(device_id, fingerprint_sha256)
  VALUES (d.id, sha256(d.spki_public_key)) RETURNING key_id INTO v_key;
 INSERT INTO ap_m1.device_credentials(device_id, key_id, token_sha256, issued_via, expires_at, bound_key_generation, bound_key_fingerprint_sha256)
  VALUES (d.id, v_key, p_new_token_sha256, 'ENROLLMENT', now() + make_interval(secs => p_lifetime_seconds), 1, public.digest(d.spki_public_key,'sha256'))
  RETURNING device_credentials.expires_at INTO v_exp;
 RETURN QUERY SELECT d.id, v_exp;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.consume_renewal_challenge(p_device uuid, p_challenge uuid)
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
    AND k.state = 'ACTIVE' AND k.revoked_at IS NULL AND ap_m1._m1_key_live(d.id,k.key_id)
    AND k.generation=ch.bound_key_generation AND k.fingerprint_sha256=ch.bound_key_fingerprint_sha256;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.issue_renewal_credential(
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
    OR ch.expires_at<=now() OR ch.consumed_at < now() - interval '60 seconds' THEN RETURN NULL; END IF;
 PERFORM 1 FROM ap_m1.devices d
  JOIN ap_m1.device_key_records k ON k.key_id = ch.key_id AND k.state = 'ACTIVE' AND k.revoked_at IS NULL
  WHERE d.id = p_device AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL AND ap_m1._m1_key_live(d.id,k.key_id)
   AND k.generation=ch.bound_key_generation AND k.fingerprint_sha256=ch.bound_key_fingerprint_sha256 FOR UPDATE OF d,k;
 IF NOT FOUND THEN RETURN NULL; END IF;
 UPDATE ap_m1.credential_renewal_challenges SET redeemed_at = now() WHERE id = ch.id;
 UPDATE ap_m1.device_credentials SET revoked_at = now() WHERE device_id = p_device AND revoked_at IS NULL;
 INSERT INTO ap_m1.device_credentials(device_id, key_id, token_sha256, issued_via, expires_at, bound_key_generation, bound_key_fingerprint_sha256)
  SELECT p_device,ch.key_id,p_new_token_sha256,'RENEWAL',now()+make_interval(secs=>p_lifetime_seconds),k.generation,k.fingerprint_sha256 FROM ap_m1.device_key_records k WHERE k.key_id=ch.key_id AND k.device_id=p_device
  RETURNING expires_at INTO v_exp;
 RETURN v_exp;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.purge_credential_artifacts(
  p_credential_grace interval DEFAULT interval '30 days',
  p_challenge_grace interval DEFAULT interval '1 day',
  p_unused_enrollment_grace interval DEFAULT interval '7 days')
 RETURNS TABLE(credentials_deleted bigint, renewal_challenges_deleted bigint,
               enrollment_challenges_deleted bigint, abandoned_devices_deleted bigint)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE a bigint; b bigint; c bigint; e bigint;
BEGIN
 IF p_credential_grace IS NULL OR p_challenge_grace IS NULL OR p_unused_enrollment_grace IS NULL OR p_credential_grace < interval '1 day' OR p_challenge_grace < interval '1 hour'
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
 -- Retain pending anchors: V2 dependents are not proof of abandonment.
 e:=0;
 RETURN QUERY SELECT a, b, c, e;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.idempotency_claim(
  p_actor uuid, p_namespace text, p_key_sha256 bytea, p_request_sha256 bytea,
  p_ttl_seconds integer DEFAULT 86400)
 RETURNS TABLE(outcome text, response_status integer, response_body jsonb, body_omitted boolean)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE r ap_m1.idempotency_claims%ROWTYPE; v_n integer;
BEGIN
 IF p_actor IS NULL OR ap_m1.ctx_principal() IS NULL OR p_actor IS DISTINCT FROM ap_m1.ctx_principal() THEN
 RAISE EXCEPTION 'authenticated idempotency actor required' USING ERRCODE='42501'; END IF;
 IF p_ttl_seconds IS NULL OR p_ttl_seconds NOT BETWEEN 60 AND 86400 THEN
  RAISE EXCEPTION 'idempotency ttl must be 60..86400 seconds' USING ERRCODE = '22023';
 END IF;
 -- Preserve V2's non-reusable operation anchors even after expiry.
 -- If another transaction holds this key, this statement waits for it to finish (bounded by lock_timeout).
 INSERT INTO ap_m1.idempotency_claims(actor_id, namespace, key_sha256, request_sha256, expires_at)
  VALUES (p_actor, p_namespace, p_key_sha256, p_request_sha256, now() + make_interval(secs => p_ttl_seconds))
  ON CONFLICT DO NOTHING;
 GET DIAGNOSTICS v_n = ROW_COUNT;
 IF v_n = 1 THEN
  RETURN QUERY SELECT 'NEW'::text, NULL::integer, NULL::jsonb, false;
  RETURN;
 END IF;
 SELECT * INTO r FROM ap_m1.idempotency_claims k
  WHERE k.actor_id = p_actor AND k.namespace = p_namespace AND k.key_sha256 = p_key_sha256;
 IF NOT FOUND THEN
  -- Removed between the conflict and the read (purge). Safe to ask the caller to retry the whole request.
  RAISE EXCEPTION 'idempotency claim raced with cleanup' USING ERRCODE = '40001';
 END IF;
 IF r.request_sha256 <> p_request_sha256 THEN
  -- Never reveal the stored response to a request that does not match it.
  RETURN QUERY SELECT 'MISMATCH'::text, NULL::integer, NULL::jsonb, false;
 ELSIF r.completed_at IS NULL THEN
  RETURN QUERY SELECT 'PENDING'::text, NULL::integer, NULL::jsonb, false;
 ELSE
  RETURN QUERY SELECT 'REPLAY'::text, r.response_status, r.response_body, r.body_omitted;
 END IF;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.idempotency_record(
  p_actor uuid, p_namespace text, p_key_sha256 bytea, p_status integer, p_body jsonb,
  p_omit_body boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE v_n integer;
BEGIN
 IF p_actor IS NULL OR ap_m1.ctx_principal() IS NULL OR p_actor IS DISTINCT FROM ap_m1.ctx_principal() THEN
 RAISE EXCEPTION 'authenticated idempotency actor required' USING ERRCODE='42501'; END IF;
 UPDATE ap_m1.idempotency_claims k
  SET state='COMPLETED', response_status = p_status,
      response_body = CASE WHEN p_omit_body THEN NULL ELSE p_body END,
      body_omitted = coalesce(p_omit_body, false),
      completed_at = now()
  WHERE k.actor_id = p_actor AND k.namespace = p_namespace AND k.key_sha256 = p_key_sha256
    AND k.completed_at IS NULL AND k.expires_at > now();
 GET DIAGNOSTICS v_n = ROW_COUNT;
 RETURN v_n = 1;
END $fn$;

CREATE OR REPLACE FUNCTION ap_m1.purge_idempotency_keys(p_grace interval DEFAULT interval '1 hour')
 RETURNS bigint
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE v_n bigint;
BEGIN
 IF p_grace IS NULL OR p_grace < interval '1 minute' THEN
  RAISE EXCEPTION 'retention grace below the safety floor' USING ERRCODE = '22023';
 END IF;
 -- V2 claims are durable operation anchors; cleanup is blocked pending policy.
 RETURN 0;
 -- No broad delete of billing/destructive-operation deduplication state.
END $fn$;


-- Normalize owners/ACLs by explicit signature allowlists; NEVER replay M1
-- 0003's grant-all. The V2 0002 classifier misowned historical mutators.
REVOKE SELECT ON ap_m1.pairing_codes,ap_m1.enrollment_challenges FROM ap_m1_auth;
DO $acl$
DECLARE sig text; t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['pairing_codes','devices','device_key_records','enrollment_challenges',
 'device_credentials','credential_renewal_challenges','idempotency_claims'] LOOP
 EXECUTE format('REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON ap_m1.%I FROM ap_m1_auth',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['device_credentials','credential_renewal_challenges'] LOOP
 EXECUTE format('ALTER TABLE ap_m1.%I OWNER TO ap_m1_owner',t);
 EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON ap_m1.%I FROM PUBLIC,ap_m1_api,ap_auth_issuer',t);
 EXECUTE format('GRANT SELECT ON ap_m1.%I TO ap_m1_auth',t);
 EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON ap_m1.%I TO ap_db_executor',t);
 END LOOP;
 FOREACH sig IN ARRAY ARRAY[
 'redeem_pairing_code(bytea,bytea,bytea,integer)', 'consume_enrollment_challenge(uuid)',
 'activate_enrolled_device(uuid,bytea,integer)', 'consume_renewal_challenge(uuid,uuid)',
 'issue_renewal_credential(uuid,uuid,bytea,integer)',
 'issue_credential_renewal_challenge(uuid,bytea,bytea,integer)',
 'purge_credential_artifacts(interval,interval,interval)',
 'idempotency_claim(uuid,text,bytea,bytea,integer)',
 'idempotency_record(uuid,text,bytea,integer,jsonb,boolean)', 'purge_idempotency_keys(interval)'] LOOP
 EXECUTE format('ALTER FUNCTION ap_m1.%s OWNER TO ap_db_executor',sig);
 EXECUTE format('REVOKE ALL ON FUNCTION ap_m1.%s FROM PUBLIC,ap_m1_api,ap_m1_auth,ap_auth_issuer,ap_m1_owner',sig);
 END LOOP;
 FOREACH sig IN ARRAY ARRAY['_m1_key_live(uuid,uuid)','authenticate_device_credential(bytea)',
 'device_public_key(uuid)','list_my_families()'] LOOP
 EXECUTE format('ALTER FUNCTION ap_m1.%s OWNER TO ap_m1_auth',sig);
 EXECUTE format('REVOKE ALL ON FUNCTION ap_m1.%s FROM PUBLIC,ap_m1_api,ap_auth_issuer',sig);
 EXECUTE format('GRANT EXECUTE ON FUNCTION ap_m1.%s TO ap_db_executor',sig);
 END LOOP;
END $acl$;
GRANT EXECUTE ON FUNCTION ap_m1.authenticate_device_credential(bytea),ap_m1.device_public_key(uuid),ap_m1.list_my_families(),
 ap_m1.idempotency_claim(uuid,text,bytea,bytea,integer),ap_m1.idempotency_record(uuid,text,bytea,integer,jsonb,boolean) TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.redeem_pairing_code(bytea,bytea,bytea,integer),ap_m1.consume_enrollment_challenge(uuid),
 ap_m1.activate_enrolled_device(uuid,bytea,integer),ap_m1.consume_renewal_challenge(uuid,uuid),
 ap_m1.issue_renewal_credential(uuid,uuid,bytea,integer),
 ap_m1.issue_credential_renewal_challenge(uuid,bytea,bytea,integer) TO ap_auth_issuer;
GRANT SELECT,INSERT,UPDATE,DELETE ON ap_m1.enrollment_challenges TO ap_db_executor;
GRANT SELECT,INSERT,UPDATE ON ap_m1.devices,ap_m1.device_key_records TO ap_db_executor;
GRANT SELECT,UPDATE ON ap_m1.pairing_codes TO ap_db_executor;
GRANT DELETE ON ap_m1.idempotency_claims TO ap_db_executor;
REVOKE ALL ON ap_m1.idempotency_keys FROM PUBLIC,ap_m1_api,ap_m1_auth,ap_auth_issuer;
-- The read-only security-invoker compatibility view is intentionally private.
GRANT SELECT ON ap_m1.idempotency_keys TO ap_db_executor;
GRANT INSERT,UPDATE ON ap_m1.erasure_store_inventory TO ap_db_executor;
SET LOCAL ROLE ap_db_executor;
INSERT INTO ap_m1.erasure_store_inventory(table_name,key_kind,purge_order) VALUES
 ('device_credentials','DEVICE',405),('credential_renewal_challenges','DEVICE',406)
 ON CONFLICT(table_name) DO UPDATE SET key_kind=EXCLUDED.key_kind,purge_order=EXCLUDED.purge_order;
RESET ROLE;
REVOKE INSERT,UPDATE ON ap_m1.erasure_store_inventory FROM ap_db_executor;
