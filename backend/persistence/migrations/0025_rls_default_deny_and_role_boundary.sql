-- E-01: explicit default-deny intent and a runtime role-boundary assertion.
-- This is an inspection/acceptance gate, not a guard against future DBA changes.
--
-- Additive only: no existing policy, grant, table or definer function is altered.
--
-- Every ap_m1 table already carries ENABLE + FORCE ROW LEVEL SECURITY. 63 of them
-- are reachable exclusively through SECURITY DEFINER functions and therefore carry
-- no explicit policy. "No policy" means deny for non-bypassing roles, which is the
-- behaviour we want, but it is invisible in the catalog and its safety silently
-- depends on the BYPASSRLS definer roles. This migration states the intent:
-- a permissive USING(false) policy is OR-ed with any future permissive policy, so
-- it documents deny-by-default without blocking a later real policy.
DO $deny$
DECLARE t text;
BEGIN
  FOR t IN
    SELECT c.relname
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'ap_m1' AND c.relkind = 'r' AND c.relrowsecurity
      AND NOT EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = c.oid)
    ORDER BY c.relname
  LOOP
    EXECUTE format(
      'CREATE POLICY deny_direct_access ON ap_m1.%I AS PERMISSIVE FOR ALL TO PUBLIC '
      'USING (false) WITH CHECK (false)', t);
  END LOOP;
END $deny$;

-- Auditable posture: table -> RLS flags, policy count and the grants held by the
-- runtime/definer roles. Used by tests and by operators before/after any change.
CREATE FUNCTION ap_m1.rls_posture()
RETURNS TABLE(table_name text, rls_enabled boolean, force_rls boolean,
              policy_count integer, runtime_grants text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
  SELECT c.relname::text,
         c.relrowsecurity,
         c.relforcerowsecurity,
         (SELECT count(*)::integer FROM pg_policy p WHERE p.polrelid = c.oid),
         coalesce((
           SELECT string_agg(g.grantee || ':' || g.privilege_type, ',' ORDER BY g.grantee, g.privilege_type)
           FROM information_schema.role_table_grants g
           WHERE g.table_schema = 'ap_m1' AND g.table_name = c.relname
             AND g.grantee IN ('ap_m1_api','ap_db_executor','ap_m1_auth','madalasa_dev','madalasa_auth')
         ), '')
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'ap_m1' AND c.relkind = 'r'
  ORDER BY c.relname
$fn$;

-- Service-role boundary: BYPASSRLS may exist only on NOLOGIN definer bridges, and
-- application runtime and login roles must remain unprivileged (no SUPERUSER, BYPASSRLS,
-- CREATEROLE, CREATEDB, REPLICATION, or privileged memberships/SET ROLE).
CREATE FUNCTION ap_m1.assert_role_boundary()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, ap_m1 AS $fn$
BEGIN
  -- 1. Application login roles must remain unprivileged and cannot hold privileged memberships
  IF EXISTS (
    SELECT 1 FROM pg_auth_members am
    JOIN pg_roles m ON m.oid = am.member
    JOIN pg_roles r ON r.oid = am.roleid
    WHERE m.rolcanlogin AND (am.inherit_option OR am.set_option)
      AND r.rolname IN ('ap_m1_api','ap_auth_issuer','ap_billing_verifier',
                       'ap_privacy_worker','ap_service_worker',
                       'madalasa_dev','madalasa_auth','madalasa_billing')
      AND (m.rolsuper OR m.rolbypassrls OR m.rolcreaterole OR m.rolcreatedb OR m.rolreplication
           OR EXISTS (
             SELECT 1 FROM pg_auth_members am2
             JOIN pg_roles priv ON priv.oid = am2.roleid
             WHERE am2.member = m.oid AND (am2.inherit_option OR am2.set_option)
               AND (priv.rolsuper OR priv.rolbypassrls OR priv.rolcreaterole OR priv.rolcreatedb
                    OR priv.rolreplication OR priv.rolname IN ('ap_m1_owner','ap_db_executor','ap_m1_auth'))
           ))
  ) THEN
    RAISE EXCEPTION 'RLS boundary violation: application login role holds administrative privileges or privileged membership'
      USING ERRCODE = '42501';
  END IF;

  -- 2. Explicit application login roles must remain unprivileged even if unassigned
  IF EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname IN ('ap_m1_api_user','ap_auth_issuer_user','ap_billing_user',
                     'ap_privacy_user','ap_worker_user',
                     'madalasa_dev','madalasa_auth','madalasa_billing')
      AND (rolsuper OR rolbypassrls OR rolcreaterole OR rolcreatedb OR rolreplication)
  ) THEN
    RAISE EXCEPTION 'RLS boundary violation: application login role holds administrative privileges'
      USING ERRCODE = '42501';
  END IF;

  -- 3. Definer bridges: must remain NOLOGIN and maintain BYPASSRLS
  IF EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname IN ('ap_db_executor','ap_m1_auth') AND (rolcanlogin OR NOT rolbypassrls)
  ) THEN
    RAISE EXCEPTION 'RLS boundary violation: a definer bridge role is now login-capable or lost BYPASSRLS'
      USING ERRCODE = '42501';
  END IF;

  -- 4. Schema owner: must remain NOLOGIN, NOSUPERUSER, NOBYPASSRLS
  IF EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname = 'ap_m1_owner' AND (rolcanlogin OR rolsuper OR rolbypassrls)
  ) THEN
    RAISE EXCEPTION 'RLS boundary violation: ap_m1_owner is login-capable or holds SUPERUSER/BYPASSRLS'
      USING ERRCODE = '42501';
  END IF;

  -- 5. Runtime group roles: must remain unprivileged and cannot assume definer or owner roles
  IF EXISTS (
    SELECT 1 FROM pg_roles r
    WHERE r.rolname IN ('ap_m1_api','ap_auth_issuer','ap_billing_verifier',
                       'ap_privacy_worker','ap_service_worker',
                       'madalasa_dev','madalasa_auth','madalasa_billing')
      AND (r.rolsuper OR r.rolbypassrls OR r.rolcreaterole OR r.rolcreatedb
           OR r.rolreplication OR EXISTS (
             SELECT 1 FROM pg_roles privileged
             WHERE (privileged.rolsuper OR privileged.rolbypassrls
                    OR privileged.rolcreaterole OR privileged.rolcreatedb
                    OR privileged.rolreplication OR privileged.rolname='ap_m1_owner')
                AND pg_has_role(r.oid, privileged.oid, 'MEMBER')))
  ) THEN
    RAISE EXCEPTION 'RLS boundary violation: runtime role can assume privileged authority'
      USING ERRCODE = '42501';
  END IF;
END $fn$;

REVOKE ALL ON FUNCTION ap_m1.rls_posture() FROM PUBLIC;
REVOKE ALL ON FUNCTION ap_m1.assert_role_boundary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.rls_posture() TO ap_m1_owner;
GRANT EXECUTE ON FUNCTION ap_m1.assert_role_boundary() TO ap_m1_owner;
SELECT ap_m1.assert_role_boundary();
