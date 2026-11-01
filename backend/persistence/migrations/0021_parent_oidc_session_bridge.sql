-- V2 0021: trusted ParentOIDC -> server-controlled opaque parent session bridge.
-- Runner owns the transaction. SYNTHETIC DATA ONLY until the legal/Play gates close.
--
-- Identity != guardian authority != child access:
--  * The C++ API verifies the Google ID token (RS256, iss/aud/azp/exp/iat/nbf).
--  * Only the separate ap_auth_issuer login may exchange a verified
--    (issuer, subject, one-time credential digest) for a session. The runtime
--    role ap_m1_api can neither mint sessions nor resolve arbitrary identities.
--  * The opaque token is generated HERE (256-bit CSPRNG); only SHA-256 is stored.
--  * A parent session carries ONLY the principal. Family context is a
--    per-request selector honoured only for a live membership in an ACTIVE
--    family. Child access stays has_child_scope_v2 (grant + consent + review).
--  * Historical LOCAL_TEST sessions (mint_session) keep their exact semantics.

ALTER TABLE ap_m1.trusted_sessions
 ADD COLUMN origin text NOT NULL DEFAULT 'LOCAL_TEST' CHECK(origin IN ('LOCAL_TEST','PARENT_OIDC')),
 ADD COLUMN oidc_issuer text,
 ADD COLUMN oidc_credential_sha256 bytea;
ALTER TABLE ap_m1.trusted_sessions ADD CONSTRAINT trusted_session_origin_shape CHECK(
 (origin='LOCAL_TEST' AND oidc_issuer IS NULL AND oidc_credential_sha256 IS NULL)
 OR (origin='PARENT_OIDC' AND principal_id IS NOT NULL AND family_id IS NULL AND device_id IS NULL
     AND oidc_issuer IS NOT NULL AND octet_length(oidc_credential_sha256)=32));
-- One verified ID token can be exchanged at most once (replay of a captured token fails).
CREATE UNIQUE INDEX trusted_sessions_oidc_credential_once
 ON ap_m1.trusted_sessions(oidc_credential_sha256) WHERE oidc_credential_sha256 IS NOT NULL;
CREATE INDEX trusted_sessions_parent_live_idx
 ON ap_m1.trusted_sessions(principal_id,created_at) WHERE origin='PARENT_OIDC' AND revoked_at IS NULL;

-- Issuer trust is code-reviewed here, not a runtime-writable table.
-- The synthetic issuer is honoured only while the database-local test opt-in is on.
CREATE FUNCTION ap_m1._parent_oidc_issuer_trusted(p_issuer text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT coalesce(p_issuer='https://accounts.google.com'
  OR (p_issuer='https://synthetic.invalid'
      AND EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled)),false);
$f$;

-- _session(): LOCAL_TEST branch is the verbatim 0002 rule. PARENT_OIDC branch
-- re-checks issuer trust and that the principal still holds the issuer it
-- logged in with (account erasure rewrites it), on EVERY resolution.
CREATE OR REPLACE FUNCTION ap_m1._session() RETURNS TABLE(principal_id uuid,family_id uuid,device_id uuid)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 WITH presented AS (
  SELECT t.* FROM ap_m1.trusted_sessions t
  WHERE t.token_sha256=public.digest(NULLIF(current_setting('ap.session_token',true),''),'sha256')
  AND t.expires_at>statement_timestamp() AND t.revoked_at IS NULL)
 SELECT s.principal_id,s.family_id,s.device_id FROM presented s
 WHERE s.origin='LOCAL_TEST'
 AND EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled)
 AND (s.principal_id IS NULL OR EXISTS(SELECT 1 FROM ap_m1.trusted_principal_verifications v
  WHERE v.principal_id=s.principal_id AND v.state='LOCAL_TEST_APPROVED' AND v.revoked_at IS NULL AND v.expires_at>statement_timestamp()))
 AND (s.family_id IS NULL OR EXISTS(SELECT 1 FROM ap_m1.guardian_memberships m JOIN ap_m1.families f ON f.id=m.family_id
  WHERE m.principal_id=s.principal_id AND m.family_id=s.family_id AND m.revoked_at IS NULL AND f.state='ACTIVE'))
 AND (s.device_id IS NULL OR EXISTS(SELECT 1 FROM ap_m1.devices d
  JOIN ap_m1.device_key_records k ON k.device_id=d.id AND k.key_id=s.bound_key_id
  WHERE d.id=s.device_id AND k.state='ACTIVE' AND k.revoked_at IS NULL
  AND k.generation=s.bound_key_generation AND k.fingerprint_sha256=s.bound_key_fingerprint_sha256
  AND k.fingerprint_sha256=public.digest(d.spki_public_key,'sha256')
  AND d.enrollment_state='ACTIVE' AND d.revoked_at IS NULL AND NOT ap_m1.child_deleted(d.child_id) AND ap_m1.has_consent(d.child_id,'CORE')))
 UNION ALL
 SELECT s.principal_id,
  -- CASE guarantees the uuid cast only runs on a well-formed selector.
  (SELECT m.family_id FROM ap_m1.guardian_memberships m JOIN ap_m1.families f ON f.id=m.family_id
   WHERE m.principal_id=s.principal_id AND m.revoked_at IS NULL AND f.state='ACTIVE'
   AND m.family_id=CASE WHEN current_setting('ap.family_id',true) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                        THEN current_setting('ap.family_id',true)::uuid END
   LIMIT 1),
  NULL::uuid
 FROM presented s
 WHERE s.origin='PARENT_OIDC' AND s.device_id IS NULL AND s.family_id IS NULL
 AND ap_m1._parent_oidc_issuer_trusted(s.oidc_issuer)
 AND EXISTS(SELECT 1 FROM ap_m1.parent_principals p WHERE p.id=s.principal_id AND p.oidc_issuer=s.oidc_issuer);
$f$;

CREATE FUNCTION ap_m1.exchange_parent_oidc_session(
 p_issuer text,p_subject text,p_credential_sha256 bytea,p_lifetime_seconds integer)
 RETURNS TABLE(session_token text,principal_id uuid,expires_at timestamptz)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
#variable_conflict use_column
DECLARE v_principal uuid; v_token text; v_expires timestamptz;
BEGIN
 -- Defence in depth on top of EXECUTE: only a dedicated issuer login that is
 -- NOT also the runtime role may exchange. Every denial has the same message.
 IF NOT pg_has_role(session_user,'ap_auth_issuer','MEMBER')
 OR pg_has_role(session_user,'ap_m1_api','MEMBER')
 OR p_issuer IS NULL OR NOT ap_m1._parent_oidc_issuer_trusted(p_issuer)
 OR p_subject IS NULL OR p_subject !~ '^[!-~]{1,255}$'
 OR p_credential_sha256 IS NULL OR octet_length(p_credential_sha256)<>32
 OR p_lifetime_seconds IS NULL OR p_lifetime_seconds NOT BETWEEN 300 AND 43200
 THEN RAISE EXCEPTION 'session denied' USING ERRCODE='42501'; END IF;
 -- Identity row only: no membership, grant, consent, review or verification.
 v_principal:=ap_m1.resolve_parent_principal(p_issuer,p_subject);
 -- Same row lock as request_account_erasure, so erasure and login serialize.
 PERFORM 1 FROM ap_m1.parent_principals p
  WHERE p.id=v_principal AND p.oidc_issuer=p_issuer AND p.oidc_subject=p_subject FOR NO KEY UPDATE;
 IF NOT FOUND OR EXISTS(SELECT 1 FROM ap_m1.adult_erasure_requests e WHERE e.principal_id=v_principal)
 THEN RAISE EXCEPTION 'session denied' USING ERRCODE='42501'; END IF;
 v_token:=encode(public.gen_random_bytes(32),'hex');
 v_expires:=statement_timestamp()+make_interval(secs=>p_lifetime_seconds);
 BEGIN
  INSERT INTO ap_m1.trusted_sessions(token_sha256,principal_id,expires_at,origin,oidc_issuer,oidc_credential_sha256)
  VALUES(public.digest(v_token,'sha256'),v_principal,v_expires,'PARENT_OIDC',p_issuer,p_credential_sha256);
 EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'session denied' USING ERRCODE='42501';
 END;
 -- Bound live sessions per adult: keep the newest 10, revoke the rest.
 UPDATE ap_m1.trusted_sessions t
  SET revoked_at=statement_timestamp(),revision=t.revision+1,updated_at=statement_timestamp()
  WHERE t.id IN (SELECT x.id FROM ap_m1.trusted_sessions x
   WHERE x.principal_id=v_principal AND x.origin='PARENT_OIDC' AND x.revoked_at IS NULL
   AND x.expires_at>statement_timestamp() ORDER BY x.created_at DESC,x.id DESC OFFSET 10);
 RETURN QUERY SELECT v_token,v_principal,v_expires;
END $f$;

-- Logout: possession of the presented token is sufficient to end it; nothing else.
CREATE FUNCTION ap_m1.revoke_current_parent_session() RETURNS boolean
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
DECLARE n integer;
BEGIN
 UPDATE ap_m1.trusted_sessions s
  SET revoked_at=statement_timestamp(),revision=s.revision+1,updated_at=statement_timestamp()
  WHERE s.token_sha256=public.digest(NULLIF(current_setting('ap.session_token',true),''),'sha256')
  AND s.origin='PARENT_OIDC' AND s.revoked_at IS NULL AND s.expires_at>statement_timestamp();
 GET DIAGNOSTICS n=ROW_COUNT;
 RETURN n=1;
END $f$;

ALTER FUNCTION ap_m1._parent_oidc_issuer_trusted(text) OWNER TO ap_m1_auth;
REVOKE ALL ON FUNCTION ap_m1._parent_oidc_issuer_trusted(text) FROM PUBLIC,ap_m1_api,ap_auth_issuer,ap_m1_owner;
GRANT EXECUTE ON FUNCTION ap_m1._parent_oidc_issuer_trusted(text) TO ap_db_executor;
ALTER FUNCTION ap_m1.exchange_parent_oidc_session(text,text,bytea,integer) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.exchange_parent_oidc_session(text,text,bytea,integer)
 FROM PUBLIC,ap_m1_api,ap_m1_auth,ap_auth_issuer,ap_m1_owner;
GRANT EXECUTE ON FUNCTION ap_m1.exchange_parent_oidc_session(text,text,bytea,integer) TO ap_auth_issuer;
ALTER FUNCTION ap_m1.revoke_current_parent_session() OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.revoke_current_parent_session() FROM PUBLIC,ap_m1_auth,ap_auth_issuer,ap_m1_owner;
GRANT EXECUTE ON FUNCTION ap_m1.revoke_current_parent_session() TO ap_m1_api;
-- _session() (owner ap_m1_auth) needs only these two identity columns.
GRANT SELECT(id,oidc_issuer) ON ap_m1.parent_principals TO ap_m1_auth;
-- 0020 deferred this to the opaque-session slice: the runtime may no longer
-- create or look up arbitrary (issuer, subject) identities.
REVOKE EXECUTE ON FUNCTION ap_m1.resolve_parent_principal(text,text) FROM ap_m1_api;
