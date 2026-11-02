-- Amar-Pola M1 migration v0001 -- PostgreSQL 15+.
-- SYNTHETIC DATA ONLY. Run as migration admin, not app. All M1 tables owned by ap_m1_owner.
-- Before real child data: India DPDP, guardian identity, retention and region signoffs.
BEGIN;
DO $roles$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ap_m1_owner') THEN
   CREATE ROLE ap_m1_owner NOLOGIN NOSUPERUSER NOBYPASSRLS;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ap_m1_api') THEN
   CREATE ROLE ap_m1_api NOLOGIN NOSUPERUSER NOBYPASSRLS;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ap_m1_auth') THEN
   -- Non-login, read-only auth helper function owner. This role bypasses RLS
   -- ONLY in audited SECURITY DEFINER lookup functions; app role never can.
   CREATE ROLE ap_m1_auth NOLOGIN NOSUPERUSER BYPASSRLS;
 END IF;
END $roles$;
CREATE SCHEMA IF NOT EXISTS ap_m1 AUTHORIZATION ap_m1_owner;
SET LOCAL ROLE ap_m1_owner;

CREATE TABLE ap_m1.families (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 label text NOT NULL CHECK (char_length(label) BETWEEN 1 AND 100),
 state text NOT NULL DEFAULT 'ACTIVE' CHECK (state IN ('ACTIVE','SUSPENDED')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE ap_m1.parent_principals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 oidc_issuer text NOT NULL CHECK (char_length(oidc_issuer) BETWEEN 4 AND 255),
 oidc_subject text NOT NULL CHECK (char_length(oidc_subject) BETWEEN 1 AND 255),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (oidc_issuer,oidc_subject)
);
CREATE TABLE ap_m1.guardian_memberships (
 family_id uuid NOT NULL REFERENCES ap_m1.families(id),
 principal_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 membership_role text NOT NULL CHECK (membership_role IN ('OWNER','GUARDIAN')),
 revoked_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (family_id,principal_id)
);
CREATE TABLE ap_m1.children (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL REFERENCES ap_m1.families(id),
 alias text NOT NULL CHECK (char_length(alias) BETWEEN 1 AND 80),
 state text NOT NULL DEFAULT 'ACTIVE' CHECK (state IN ('ACTIVE','SUSPENDED')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (family_id,id)
);
CREATE TABLE ap_m1.child_guardian_grants (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL,
 child_id uuid NOT NULL,
 principal_id uuid NOT NULL,
 scope text NOT NULL CHECK (scope IN
  ('VIEW_CHILD_PROFILE','VIEW_CHILD_DEVICES','PAIR_DEVICE','REVOKE_CHILD_DEVICE','MANAGE_CHILD_GRANTS')),
 expires_at timestamptz,
 revoked_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(family_id,child_id) REFERENCES ap_m1.children(family_id,id),
 FOREIGN KEY(family_id,principal_id) REFERENCES ap_m1.guardian_memberships(family_id,principal_id),
 UNIQUE (family_id,child_id,principal_id,scope)
);
CREATE INDEX grants_scope_idx ON ap_m1.child_guardian_grants
 (principal_id,child_id,scope) WHERE revoked_at IS NULL;
CREATE TABLE ap_m1.pairing_codes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL,
 child_id uuid NOT NULL,
 code_sha256 bytea NOT NULL UNIQUE,
 expires_at timestamptz NOT NULL,
 consumed_at timestamptz,
 issued_by uuid NOT NULL,
 attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count BETWEEN 0 AND 20),
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(family_id,child_id) REFERENCES ap_m1.children(family_id,id),
 FOREIGN KEY(family_id,issued_by) REFERENCES ap_m1.guardian_memberships(family_id,principal_id),
 CHECK(expires_at > created_at)
);
CREATE INDEX pairing_expiry_idx ON ap_m1.pairing_codes(expires_at);
CREATE TABLE ap_m1.devices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL,
 child_id uuid NOT NULL,
 enrollment_state text NOT NULL DEFAULT 'PENDING_PROOF'
  CHECK (enrollment_state IN ('PENDING_PROOF','ACTIVE','REVOKED')),
 spki_public_key bytea NOT NULL CHECK(octet_length(spki_public_key) BETWEEN 80 AND 4096),
 algorithm text NOT NULL DEFAULT 'ECDSA_P256_SHA256'
  CHECK (algorithm='ECDSA_P256_SHA256'),
 revoked_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(family_id,id),
 FOREIGN KEY(family_id,child_id) REFERENCES ap_m1.children(family_id,id)
);
CREATE TABLE ap_m1.enrollment_challenges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL UNIQUE REFERENCES ap_m1.devices(id),
 nonce_sha256 bytea NOT NULL,
 expires_at timestamptz NOT NULL,
 consumed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(expires_at > created_at)
);
CREATE TABLE ap_m1.device_key_records (
 key_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL REFERENCES ap_m1.devices(id),
 fingerprint_sha256 bytea NOT NULL UNIQUE,
 state text NOT NULL DEFAULT 'ACTIVE' CHECK(state IN ('ACTIVE','REVOKED')),
 revoked_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX device_one_active_key_idx
 ON ap_m1.device_key_records(device_id) WHERE state='ACTIVE';

CREATE TABLE ap_m1.capability_snapshots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL REFERENCES ap_m1.devices(id),
 observed_at timestamptz NOT NULL,
 received_at timestamptz NOT NULL DEFAULT now(),
 android_api integer NOT NULL CHECK(android_api BETWEEN 29 AND 45),
 device_mode text NOT NULL CHECK(device_mode IN ('STANDARD','MANAGED_DEVICE_OWNER','UNKNOWN')),
 is_device_owner boolean NOT NULL DEFAULT false,
 features jsonb NOT NULL DEFAULT '{}'::jsonb,
 CHECK (octet_length(features::text) <= 8192),
 CHECK (device_mode <> 'MANAGED_DEVICE_OWNER' OR is_device_owner)
);
CREATE INDEX capability_device_time_idx ON ap_m1.capability_snapshots(device_id,received_at DESC);
CREATE TABLE ap_m1.device_health (
 device_id uuid PRIMARY KEY REFERENCES ap_m1.devices(id),
 observed_at timestamptz NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT now(),
 battery_percent integer CHECK (battery_percent BETWEEN 0 AND 100),
 charging boolean,
 permission_revision integer NOT NULL DEFAULT 0 CHECK(permission_revision >= 0)
);
CREATE TABLE ap_m1.commands (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL,
 device_id uuid NOT NULL,
 created_by uuid NOT NULL,
 command_type text NOT NULL CHECK (command_type IN ('REFRESH_CAPABILITIES','MANAGED_TEST_SUSPEND','MANAGED_TEST_UNSUSPEND')),
 command_state text NOT NULL DEFAULT 'CREATED'
  CHECK(command_state IN ('CREATED','QUEUED','DELIVERED','COMPLETED','FAILED','EXPIRED','UNSUPPORTED','CANCELLED')),
 expires_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY (family_id,device_id) REFERENCES ap_m1.devices(family_id,id),
 FOREIGN KEY (family_id,created_by) REFERENCES ap_m1.guardian_memberships(family_id,principal_id)
);
CREATE TABLE ap_m1.command_results (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 command_id uuid NOT NULL REFERENCES ap_m1.commands(id),
 outcome text NOT NULL CHECK(outcome IN ('COMPLETED','FAILED','UNSUPPORTED','OS_REJECTED')),
 observed_at timestamptz NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE ap_m1.audit_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL REFERENCES ap_m1.families(id),
 actor_principal_id uuid REFERENCES ap_m1.parent_principals(id),
 actor_device_id uuid REFERENCES ap_m1.devices(id),
 action text NOT NULL CHECK(char_length(action) BETWEEN 1 AND 80),
 result_code text NOT NULL,
 observed_at timestamptz NOT NULL DEFAULT now(),
 CHECK(actor_principal_id IS NOT NULL OR actor_device_id IS NOT NULL)
);
CREATE TABLE ap_m1.revocation_epochs (
 family_id uuid PRIMARY KEY REFERENCES ap_m1.families(id),
 generation bigint NOT NULL DEFAULT 1 CHECK (generation > 0),
 updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE FUNCTION ap_m1.ctx_family() RETURNS uuid
 LANGUAGE sql STABLE AS $fn$
 SELECT NULLIF(current_setting('ap.family_id',true),'')::uuid;
 $fn$;
CREATE FUNCTION ap_m1.ctx_principal() RETURNS uuid
 LANGUAGE sql STABLE AS $fn$
 SELECT NULLIF(current_setting('ap.principal_id',true),'')::uuid;
 $fn$;
CREATE FUNCTION ap_m1.ctx_device() RETURNS uuid
 LANGUAGE sql STABLE AS $fn$
 SELECT NULLIF(current_setting('ap.device_id',true),'')::uuid;
 $fn$;

-- SECURITY DEFINER helper is owned by a non-login owner and checks BOTH
-- live family membership AND one child-specific grant, not family alone.
CREATE FUNCTION ap_m1.has_scope(target_family uuid, target_child uuid, wanted text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path = pg_catalog, ap_m1 AS $fn$
 SELECT EXISTS (
 SELECT 1
 FROM ap_m1.guardian_memberships m
 JOIN ap_m1.child_guardian_grants g
   ON g.family_id=m.family_id AND g.principal_id=m.principal_id
 WHERE m.family_id=target_family
   AND m.family_id=ap_m1.ctx_family()
   AND m.principal_id=ap_m1.ctx_principal()
   AND m.revoked_at IS NULL
   AND g.child_id=target_child AND g.scope=wanted
   AND g.revoked_at IS NULL
   AND (g.expires_at IS NULL OR g.expires_at > now())
 );
 $fn$;
CREATE FUNCTION ap_m1.family_owner(target_family uuid)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path=pg_catalog, ap_m1 AS $fn$
 SELECT EXISTS (
   SELECT 1 FROM ap_m1.guardian_memberships m
   WHERE m.family_id=target_family
     AND m.family_id=ap_m1.ctx_family()
     AND m.principal_id=ap_m1.ctx_principal()
     AND m.membership_role='OWNER'
     AND m.revoked_at IS NULL
 );
 $fn$;
CREATE FUNCTION ap_m1.owns_active_device(target_device uuid)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path=pg_catalog, ap_m1 AS $fn$
 SELECT EXISTS (
  SELECT 1 FROM ap_m1.devices d
  WHERE d.id=target_device
    AND d.id=ap_m1.ctx_device()
    AND d.enrollment_state='ACTIVE' AND d.revoked_at IS NULL
 );
 $fn$;

-- Defense in depth: every table uses forced RLS, even for table owner.
-- Admin/migrator users may bypass; never grant superuser/BYPASSRLS to runtime.
DO $policies$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'families','parent_principals','guardian_memberships','children',
  'child_guardian_grants','pairing_codes','devices','enrollment_challenges',
  'device_key_records','capability_snapshots','device_health','commands',
  'command_results','audit_events','revocation_epochs'
 ] LOOP
  EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
 END LOOP;
END $policies$;

-- Owner-managed family writes and child-specific reads.
CREATE POLICY families_r ON ap_m1.families FOR SELECT
 USING (id=ap_m1.ctx_family() AND ap_m1.family_owner(id));
CREATE POLICY families_i ON ap_m1.families FOR INSERT
 WITH CHECK (id=ap_m1.ctx_family());
CREATE POLICY parents_r ON ap_m1.parent_principals FOR SELECT
 USING (id=ap_m1.ctx_principal());
CREATE POLICY memberships_r ON ap_m1.guardian_memberships FOR SELECT
 USING (family_id=ap_m1.ctx_family() AND
       (principal_id=ap_m1.ctx_principal() OR ap_m1.family_owner(family_id)));
CREATE POLICY memberships_i ON ap_m1.guardian_memberships FOR INSERT
 WITH CHECK (family_id=ap_m1.ctx_family() AND
    (principal_id=ap_m1.ctx_principal() OR ap_m1.family_owner(family_id)));
CREATE POLICY children_r ON ap_m1.children FOR SELECT
 USING(family_id=ap_m1.ctx_family()
   AND ap_m1.has_scope(family_id,id,'VIEW_CHILD_PROFILE'));
CREATE POLICY children_i ON ap_m1.children FOR INSERT
 WITH CHECK (family_id=ap_m1.ctx_family() AND ap_m1.family_owner(family_id));
CREATE POLICY grants_r ON ap_m1.child_guardian_grants FOR SELECT
 USING (family_id=ap_m1.ctx_family() AND
 (principal_id=ap_m1.ctx_principal() OR ap_m1.family_owner(family_id)));
CREATE POLICY grants_i ON ap_m1.child_guardian_grants FOR INSERT
 WITH CHECK (family_id=ap_m1.ctx_family() AND ap_m1.family_owner(family_id));
CREATE POLICY grants_u ON ap_m1.child_guardian_grants FOR UPDATE
 USING (family_id=ap_m1.ctx_family() AND ap_m1.family_owner(family_id))
 WITH CHECK(family_id=ap_m1.ctx_family() AND ap_m1.family_owner(family_id));
CREATE POLICY pairing_r ON ap_m1.pairing_codes FOR SELECT
 USING(family_id=ap_m1.ctx_family()
  AND ap_m1.has_scope(family_id,child_id,'PAIR_DEVICE'));
CREATE POLICY pairing_i ON ap_m1.pairing_codes FOR INSERT
 WITH CHECK(family_id=ap_m1.ctx_family()
  AND issued_by=ap_m1.ctx_principal()
  AND ap_m1.has_scope(family_id,child_id,'PAIR_DEVICE'));
CREATE POLICY devices_r ON ap_m1.devices FOR SELECT
 USING (family_id=ap_m1.ctx_family()
  AND ap_m1.has_scope(family_id,child_id,'VIEW_CHILD_DEVICES'));
CREATE POLICY devices_u ON ap_m1.devices FOR UPDATE
 USING (family_id=ap_m1.ctx_family()
  AND ap_m1.has_scope(family_id,child_id,'REVOKE_CHILD_DEVICE'))
 WITH CHECK (family_id=ap_m1.ctx_family());
CREATE POLICY snapshots_r ON ap_m1.capability_snapshots FOR SELECT
 USING (EXISTS(SELECT 1 FROM ap_m1.devices d WHERE d.id=device_id
    AND d.family_id=ap_m1.ctx_family()
    AND ap_m1.has_scope(d.family_id,d.child_id,'VIEW_CHILD_DEVICES')));
CREATE POLICY snapshots_i ON ap_m1.capability_snapshots FOR INSERT
 WITH CHECK(ap_m1.owns_active_device(device_id));
CREATE POLICY health_r ON ap_m1.device_health FOR SELECT
 USING (EXISTS(SELECT 1 FROM ap_m1.devices d WHERE d.id=device_id
    AND d.family_id=ap_m1.ctx_family()
    AND ap_m1.has_scope(d.family_id,d.child_id,'VIEW_CHILD_DEVICES')));
CREATE POLICY health_i ON ap_m1.device_health FOR INSERT
 WITH CHECK(ap_m1.owns_active_device(device_id));
CREATE POLICY health_u ON ap_m1.device_health FOR UPDATE
 USING(ap_m1.owns_active_device(device_id))
 WITH CHECK(ap_m1.owns_active_device(device_id));
CREATE POLICY cmds_r ON ap_m1.commands FOR SELECT
 USING(family_id=ap_m1.ctx_family() AND
  EXISTS(SELECT 1 FROM ap_m1.devices d WHERE d.id=device_id
   AND ap_m1.has_scope(family_id,d.child_id,'VIEW_CHILD_DEVICES')));
CREATE POLICY audit_r ON ap_m1.audit_events FOR SELECT
 USING(family_id=ap_m1.ctx_family() AND ap_m1.family_owner(family_id));
CREATE POLICY revocation_r ON ap_m1.revocation_epochs FOR SELECT
 USING(family_id=ap_m1.ctx_family() AND ap_m1.family_owner(family_id));

-- New child enrollment code redeem, PoP challenge and key insertion
-- occur through a future separately reviewed SECURITY DEFINER enrollment function,
-- not through blanket direct M1 API table permissions.
RESET ROLE;
-- Force-RLS policy helpers need an independent lookup role to avoid RLS recursion.
-- The bypass role has NO LOGIN and only SELECT on the exact auth metadata tables.
GRANT USAGE ON SCHEMA ap_m1 TO ap_m1_auth;
GRANT SELECT ON ap_m1.guardian_memberships, ap_m1.child_guardian_grants,
 ap_m1.devices TO ap_m1_auth;
ALTER FUNCTION ap_m1.has_scope(uuid,uuid,text) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1.family_owner(uuid) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1.owns_active_device(uuid) OWNER TO ap_m1_auth;
GRANT USAGE ON SCHEMA ap_m1 TO ap_m1_api;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ap_m1 TO ap_m1_api;
GRANT SELECT ON ap_m1.families, ap_m1.parent_principals,
 ap_m1.guardian_memberships, ap_m1.children, ap_m1.child_guardian_grants,
 ap_m1.pairing_codes, ap_m1.devices, ap_m1.capability_snapshots,
 ap_m1.device_health, ap_m1.commands, ap_m1.audit_events,
 ap_m1.revocation_epochs TO ap_m1_api;
GRANT INSERT ON ap_m1.families, ap_m1.guardian_memberships,
 ap_m1.children, ap_m1.child_guardian_grants, ap_m1.pairing_codes,
 ap_m1.capability_snapshots, ap_m1.device_health TO ap_m1_api;
GRANT UPDATE ON ap_m1.child_guardian_grants, ap_m1.devices,
 ap_m1.device_health TO ap_m1_api;
COMMIT;

-- TODO before production: explicit transactional provisioning SQL function for
-- initial family+membership+owner grant; parent principal onboarding requires
-- validated OIDC identity, not an unguarded INSERT through application role.
-- IMPORTANT: application role must not expose arbitrary SQL or let clients set
-- ap.family_id, ap.principal_id, ap.device_id. Verified backend sets SET LOCAL.
