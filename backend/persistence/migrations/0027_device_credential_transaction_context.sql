-- DeviceBearer -> V2 transaction context; no session mint, identity selector,
-- new durable proof, or runtime credential-table privilege.
-- The API binds the SHA-256 of the actual presented bearer as 64 lower-case
-- hex characters in ap.device_credential_sha256 using set_config(...,true).
-- Treat this digest as bearer-equivalent sensitive data: never log it.
-- Every resolution reuses the authoritative STABLE credential lookup (0019):
-- active device/key, generation/fingerprint binding, expiry at statement time,
-- credential/device/key revocation, child deletion and live CORE consent.
-- Mixed opaque-session + device credentials fail closed (no identity ambiguity).
-- Existing parent OIDC / LOCAL_TEST branches below are otherwise unchanged.
-- CREATE OR REPLACE retains _session's signature, owner ap_m1_auth, STABLE,
-- SECURITY DEFINER, fixed search_path and ACL. No extra GRANT is needed: this
-- same owner already owns authenticate_device_credential(bytea).
-- Visibility remains PostgreSQL READ COMMITTED, per-statement revalidation;
-- require_domain_device retains its device/child/consent locks. No cached
-- authentication result can survive a committed revocation on the next statement.
CREATE OR REPLACE FUNCTION ap_m1._session() RETURNS TABLE(principal_id uuid,family_id uuid,device_id uuid)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 WITH presented AS (
  SELECT t.* FROM ap_m1.trusted_sessions t
  WHERE NULLIF(current_setting('ap.device_credential_sha256',true),'') IS NULL
  AND t.token_sha256=public.digest(NULLIF(current_setting('ap.session_token',true),''),'sha256')
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
 AND EXISTS(SELECT 1 FROM ap_m1.parent_principals p WHERE p.id=s.principal_id AND p.oidc_issuer=s.oidc_issuer)
 UNION ALL
 SELECT NULL::uuid,c.family_id,c.device_id
 FROM ap_m1.authenticate_device_credential(
  CASE WHEN current_setting('ap.device_credential_sha256',true) ~ '^[0-9a-f]{64}$'
       AND NULLIF(current_setting('ap.session_token',true),'') IS NULL
       THEN decode(current_setting('ap.device_credential_sha256',true),'hex') END) c;
$f$;

-- Health writes remain revoked as required by v2:0007. This migration does not
-- widen device-health table access; its HTTP write path is a separate repair.
