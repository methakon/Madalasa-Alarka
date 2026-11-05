-- Additive V2 issuer boundary; the runner owns the transaction.
-- Runtime retains SELECT only on pairing_codes. No raw secret or actor selector.
GRANT INSERT (family_id,child_id,code_sha256,expires_at,issued_by)
 ON ap_m1.pairing_codes TO ap_db_executor;

CREATE FUNCTION ap_m1.issue_device_pairing_code(child uuid, code_hash bytea, ttl integer)
RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $fn$
DECLARE actor uuid; child_family uuid; expiry timestamptz;
BEGIN
 IF child IS NULL OR code_hash IS NULL OR octet_length(code_hash)<>32
 OR ttl IS NULL OR ttl NOT BETWEEN 60 AND 600 THEN
  RAISE EXCEPTION 'invalid pairing request' USING ERRCODE='22023';
 END IF;
 -- A caller-controlled GUC identifying an adult is never an identity proof.
 actor:=ap_m1.ctx_principal();
 IF actor IS NULL OR ap_m1.ctx_device() IS NOT NULL
 OR NOT coalesce(ap_m1.has_child_scope_v2(child,'PAIR_DEVICE'),false) THEN
  RAISE EXCEPTION 'pairing denied' USING ERRCODE='42501';
 END IF;
 -- Serialize issuers for the exact child. Consent withdrawal, erasure and
 -- activation also fence this child; do not lock an existing device after it.
 SELECT c.family_id INTO child_family FROM ap_m1.children c WHERE c.id=child FOR UPDATE;
 IF NOT FOUND THEN
  RAISE EXCEPTION 'pairing denied' USING ERRCODE='42501';
 END IF;
 -- Re-resolve trusted context and exact scope AFTER waiting for the child lock.
 IF ap_m1.ctx_principal() IS DISTINCT FROM actor OR ap_m1.ctx_device() IS NOT NULL
 OR NOT EXISTS(SELECT 1 FROM ap_m1.trusted_sessions s
  WHERE s.token_sha256=public.digest(NULLIF(current_setting('ap.session_token',true),''),'sha256')
  AND s.principal_id=actor AND s.device_id IS NULL
  AND s.revoked_at IS NULL AND s.expires_at>clock_timestamp())
 OR NOT coalesce(ap_m1.has_child_scope_v2(child,'PAIR_DEVICE'),false)
 OR NOT ap_m1.child_free_admitted(child) THEN
  RAISE EXCEPTION 'pairing denied' USING ERRCODE='42501';
 END IF;
 IF EXISTS(SELECT 1 FROM ap_m1.devices d WHERE d.child_id=child
  AND d.enrollment_state='ACTIVE' AND d.revoked_at IS NULL) THEN
  RAISE EXCEPTION 'child already paired' USING ERRCODE='23505';
 END IF;
 IF EXISTS(SELECT 1 FROM ap_m1.pairing_codes p WHERE p.child_id=child
  AND p.consumed_at IS NULL AND p.expires_at>clock_timestamp()) THEN
  RAISE EXCEPTION 'active pairing code exists' USING ERRCODE='23505';
 END IF;
 expiry:=clock_timestamp()+make_interval(secs=>ttl);
 INSERT INTO ap_m1.pairing_codes(family_id,child_id,code_sha256,expires_at,issued_by)
 VALUES(child_family,child,code_hash,expiry,actor);
 RETURN expiry;
END $fn$;
ALTER FUNCTION ap_m1.issue_device_pairing_code(uuid,bytea,integer) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.issue_device_pairing_code(uuid,bytea,integer)
 FROM PUBLIC,ap_m1_auth,ap_auth_issuer,ap_m1_owner;
GRANT EXECUTE ON FUNCTION ap_m1.issue_device_pairing_code(uuid,bytea,integer) TO ap_m1_api;

-- Enrollment uses the separate issuer login; do not grant activation or direct
-- challenge-table reads to the runtime API role.
CREATE FUNCTION ap_m1.read_enrollment_challenge_expiry(challenge uuid)
RETURNS timestamptz LANGUAGE sql SECURITY DEFINER
SET search_path=pg_catalog,ap_m1 AS $$
 SELECT expires_at FROM ap_m1.enrollment_challenges WHERE id=challenge
$$;
ALTER FUNCTION ap_m1.read_enrollment_challenge_expiry(uuid) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.read_enrollment_challenge_expiry(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.read_enrollment_challenge_expiry(uuid) TO ap_auth_issuer;
GRANT EXECUTE ON FUNCTION ap_m1.store_pending_device_profile(uuid,text,text,integer,text,text)
 TO ap_auth_issuer;
