-- Supplemental M1 PR review: catalog invariants and rollback-only negative controls.
-- Run ONLY on a new disposable madalasa_pr9_review* database after original M1 0001..0005.
-- Do not apply to the separate namespaced V2 database. No real data or credentials.
\set ON_ERROR_STOP on
BEGIN;
DO $$ BEGIN
  IF current_database() !~ '^madalasa_pr9_review([_][a-z0-9]+)?$' THEN
    RAISE EXCEPTION 'Refusing catalog mutation controls outside the dedicated review database';
  END IF;
END $$;

CREATE FUNCTION pg_temp.assert_m1_security_catalog() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='ap_m1' AND c.relkind IN ('r','p')) <> 18 THEN
    RAISE EXCEPTION USING ERRCODE='P7501', MESSAGE='Historical M1 catalog must contain exactly 18 base tables';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='ap_m1' AND c.relkind IN ('r','p')
               AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity
                    OR pg_get_userbyid(c.relowner) <> 'ap_m1_owner')) THEN
    RAISE EXCEPTION USING ERRCODE='P7501', MESSAGE='All application tables require forced RLS and designated ownership';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ap_m1_api'
                 AND NOT rolsuper AND NOT rolbypassrls AND NOT rolcreaterole AND NOT rolcreatedb)
     OR EXISTS (SELECT 1 FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member
                WHERE r.rolname='ap_m1_api') THEN
    RAISE EXCEPTION USING ERRCODE='P7501', MESSAGE='Runtime API role must be restricted and have no inherited role membership';
  END IF;
  -- ap_m1_auth intentionally bypasses RLS for narrow SECURITY DEFINER functions.
  -- It is not a runtime login identity, and must never be represented as NOBYPASSRLS.
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ap_m1_auth' AND NOT rolcanlogin AND NOT rolsuper)
     OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ap_m1_owner' AND NOT rolcanlogin AND NOT rolsuper) THEN
    RAISE EXCEPTION USING ERRCODE='P7501', MESSAGE='Definer and owner roles must remain non-login, non-superuser';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='ap_m1' AND p.prosecdef
               AND (pg_get_userbyid(p.proowner) <> 'ap_m1_auth'
                    OR NOT COALESCE('search_path=pg_catalog, ap_m1'=ANY(p.proconfig),false))) THEN
    RAISE EXCEPTION USING ERRCODE='P7501', MESSAGE='Definer ownership/search_path drift';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl,acldefault('f',p.proowner))) a
             WHERE n.nspname='ap_m1' AND a.grantee=0 AND a.privilege_type='EXECUTE') THEN
    RAISE EXCEPTION USING ERRCODE='P7501', MESSAGE='PUBLIC must not execute application functions';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
             WHERE n.nspname='ap_m1' AND c.relkind IN ('r','p') AND a.grantee=0) THEN
    RAISE EXCEPTION USING ERRCODE='P7501', MESSAGE='PUBLIC must have no application table ACL';
  END IF;
END $$;

SELECT pg_temp.assert_m1_security_catalog();
DO $$
DECLARE detected boolean;
BEGIN
  detected := false;
  BEGIN
    ALTER TABLE ap_m1.children NO FORCE ROW LEVEL SECURITY;
    PERFORM pg_temp.assert_m1_security_catalog();
  EXCEPTION WHEN SQLSTATE 'P7501' THEN detected := true;
  END;
  IF NOT detected THEN RAISE EXCEPTION 'Negative control failed: missing FORCE RLS was accepted'; END IF;
  PERFORM pg_temp.assert_m1_security_catalog();

  detected := false;
  BEGIN
    GRANT EXECUTE ON FUNCTION ap_m1.create_family(text) TO PUBLIC;
    PERFORM pg_temp.assert_m1_security_catalog();
  EXCEPTION WHEN SQLSTATE 'P7501' THEN detected := true;
  END;
  IF NOT detected THEN RAISE EXCEPTION 'Negative control failed: PUBLIC execution was accepted'; END IF;
  PERFORM pg_temp.assert_m1_security_catalog();

  detected := false;
  BEGIN
    ALTER ROLE ap_m1_api BYPASSRLS;
    PERFORM pg_temp.assert_m1_security_catalog();
  EXCEPTION WHEN SQLSTATE 'P7501' THEN detected := true;
  END;
  IF NOT detected THEN RAISE EXCEPTION 'Negative control failed: runtime RLS bypass was accepted'; END IF;
  PERFORM pg_temp.assert_m1_security_catalog();
END $$;
ROLLBACK;
\echo 'M1 security catalog PASS: 18 forced-RLS tables, restricted runtime role, bounded definer role, PUBLIC lockdown; three negative controls detected and rolled back'
