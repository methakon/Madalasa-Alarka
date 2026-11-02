-- Madalasa-Alarka M1 migration v0005 -- family provisioning (closes the TODO at the end of 0001).
-- PostgreSQL 15+. Apply after 0001..0004, as the migration admin (not the app role).
-- SYNTHETIC DATA ONLY.
--
-- Why: the runtime role may not insert parent principals (an unguarded INSERT would let any caller invent
-- identities), and creating a family needs the family row and its OWNER membership together. Both become
-- SECURITY DEFINER functions owned by the non-login BYPASSRLS role ap_m1_auth.
--
-- resolve_parent_principal(issuer, subject): the backend calls this ONLY after it has validated the OIDC token.
--   It is idempotent and returns the stable principal id. Possession of the function is therefore trust in the
--   backend; the database cannot verify a token itself.
-- create_family(label): creates the family and the caller's OWNER membership in one statement. The caller is the
--   principal the backend placed in the transaction with SET LOCAL ap.principal_id (never an argument), so one
--   principal cannot create a family on behalf of another. A principal may own at most 10 live families; the 11th
--   raises SQLSTATE 53400, which the backend maps to 422 VALIDATION_FAILED (engineering default, owner may change).
BEGIN;
SET LOCAL ROLE ap_m1_owner;

CREATE FUNCTION ap_m1.resolve_parent_principal(p_issuer text, p_subject text)
 RETURNS uuid
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE v_id uuid;
BEGIN
 INSERT INTO ap_m1.parent_principals(oidc_issuer, oidc_subject) VALUES (p_issuer, p_subject)
  ON CONFLICT (oidc_issuer, oidc_subject) DO NOTHING;
 SELECT p.id INTO v_id FROM ap_m1.parent_principals p
  WHERE p.oidc_issuer = p_issuer AND p.oidc_subject = p_subject;
 RETURN v_id;
END $fn$;

CREATE FUNCTION ap_m1.create_family(p_label text)
 RETURNS TABLE(id uuid, label text, state text)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE v_principal uuid := ap_m1.ctx_principal(); v_owned integer; f ap_m1.families%ROWTYPE;
BEGIN
 IF v_principal IS NULL THEN
  RAISE EXCEPTION 'no authenticated principal in the transaction' USING ERRCODE = '28000';
 END IF;
 -- Serialize per principal so two parallel creates cannot both pass the cap.
 PERFORM pg_advisory_xact_lock(hashtextextended('ap_m1.create_family:' || v_principal::text, 0));
 SELECT count(*) INTO v_owned FROM ap_m1.guardian_memberships m
  WHERE m.principal_id = v_principal AND m.membership_role = 'OWNER' AND m.revoked_at IS NULL;
 IF v_owned >= 10 THEN
  RAISE EXCEPTION 'family limit reached for this account' USING ERRCODE = '53400';
 END IF;
 INSERT INTO ap_m1.families(label) VALUES (p_label) RETURNING * INTO f;
 INSERT INTO ap_m1.guardian_memberships(family_id, principal_id, membership_role)
  VALUES (f.id, v_principal, 'OWNER');
 RETURN QUERY SELECT f.id, f.label, f.state;
END $fn$;

RESET ROLE;
GRANT SELECT, INSERT ON ap_m1.parent_principals TO ap_m1_auth;
GRANT SELECT, INSERT ON ap_m1.families TO ap_m1_auth;
GRANT INSERT ON ap_m1.guardian_memberships TO ap_m1_auth;
ALTER FUNCTION ap_m1.resolve_parent_principal(text,text) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1.create_family(text) OWNER TO ap_m1_auth;
REVOKE ALL ON FUNCTION ap_m1.resolve_parent_principal(text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ap_m1.create_family(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.resolve_parent_principal(text,text) TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.create_family(text) TO ap_m1_api;
COMMIT;
