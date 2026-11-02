-- Extend existing M1 devices, capability_snapshots and commands; never shadow them.
ALTER TABLE ap_m1.devices ADD COLUMN enrollment_generation bigint NOT NULL DEFAULT 1 CHECK(enrollment_generation>0);
ALTER TABLE ap_m1.capability_snapshots ADD COLUMN report_version bigint;
ALTER TABLE ap_m1.capability_snapshots ADD COLUMN enrollment_generation bigint;
ALTER TABLE ap_m1.capability_snapshots ADD COLUMN payload_digest bytea;
CREATE UNIQUE INDEX capabilities_generation_version_idx ON ap_m1.capability_snapshots(device_id,enrollment_generation,report_version);
REVOKE INSERT,UPDATE ON ap_m1.capability_snapshots,ap_m1.device_health FROM ap_m1_api;
REVOKE UPDATE ON ap_m1.devices FROM ap_m1_api;

CREATE TABLE ap_m1.permission_snapshots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, device_id uuid NOT NULL,
 enrollment_generation bigint NOT NULL CHECK(enrollment_generation>0), revision bigint NOT NULL CHECK(revision>0),
 observed_at timestamptz NOT NULL CHECK(isfinite(observed_at)), received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 permissions jsonb NOT NULL CHECK(jsonb_typeof(permissions)='object' AND octet_length(permissions::text)<=8192),
 payload_digest bytea NOT NULL CHECK(octet_length(payload_digest)=32),
 UNIQUE(device_id,enrollment_generation,revision), UNIQUE(child_id,id),
 FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id), CHECK(observed_at<=received_at)
);
CREATE TABLE ap_m1.device_permission_change_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, device_id uuid NOT NULL,
 snapshot_id uuid NOT NULL, permission_key text NOT NULL CHECK(length(permission_key) BETWEEN 1 AND 64),
 old_state text, new_state text NOT NULL,
 observed_at timestamptz NOT NULL, received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id),
 FOREIGN KEY(child_id,snapshot_id) REFERENCES ap_m1.permission_snapshots(child_id,id) ON DELETE CASCADE,
 UNIQUE(snapshot_id,permission_key)
);
CREATE INDEX permission_device_time_idx ON ap_m1.permission_snapshots(device_id,received_at DESC);
CREATE TABLE ap_m1.device_reenrollment_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, old_device_id uuid NOT NULL, replacement_device_id uuid,
 requested_by uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 reason_code text NOT NULL CHECK(length(reason_code) BETWEEN 1 AND 100),
 revoked_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(child_id,old_device_id) REFERENCES ap_m1.devices(child_id,id),
 FOREIGN KEY(child_id,replacement_device_id) REFERENCES ap_m1.devices(child_id,id),
 CHECK(replacement_device_id IS NULL OR replacement_device_id<>old_device_id)
);

-- Permit an expressly authorized cross-household parent without billing membership.
ALTER TABLE ap_m1.commands DROP CONSTRAINT commands_family_id_created_by_fkey;
ALTER TABLE ap_m1.commands ADD CONSTRAINT commands_creator_fk FOREIGN KEY(created_by) REFERENCES ap_m1.parent_principals(id);
ALTER TABLE ap_m1.commands ADD COLUMN child_id uuid;
UPDATE ap_m1.commands c SET child_id=d.child_id FROM ap_m1.devices d WHERE c.device_id=d.id;
ALTER TABLE ap_m1.commands ALTER COLUMN child_id SET NOT NULL;
ALTER TABLE ap_m1.commands ADD CONSTRAINT commands_exact_child_fk FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id);
ALTER TABLE ap_m1.commands ADD CONSTRAINT commands_child_id_id_key UNIQUE(child_id,id);
ALTER TABLE ap_m1.commands ADD COLUMN last_receipt_version bigint NOT NULL DEFAULT 0 CHECK(last_receipt_version>=0);
ALTER TABLE ap_m1.commands ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE ap_m1.commands ADD COLUMN reason_code text;
ALTER TABLE ap_m1.commands DROP CONSTRAINT commands_command_type_check;
ALTER TABLE ap_m1.commands ADD CONSTRAINT commands_command_type_check CHECK(command_type IN ('REFRESH_CAPABILITIES','FIND_DEVICE_RING','APPLY_ELIGIBLE_POLICY','REVOKE_ELIGIBLE_POLICY','MANAGED_TEST_SUSPEND','MANAGED_TEST_UNSUSPEND'));
ALTER TABLE ap_m1.commands DROP CONSTRAINT commands_command_state_check;
ALTER TABLE ap_m1.commands ADD CONSTRAINT commands_command_state_check CHECK(command_state IN ('CREATED','QUEUED','DELIVERED','ACCEPTED','COMPLETED','FAILED','EXPIRED','UNSUPPORTED','PERMISSION_REQUIRED','OS_REJECTED','USER_ACTION_REQUIRED','DEVICE_OFFLINE','CANCELLED'));
CREATE INDEX commands_device_pending_idx ON ap_m1.commands(device_id,expires_at) WHERE command_state IN ('QUEUED','DELIVERED','ACCEPTED');
CREATE TABLE ap_m1.command_receipts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, command_id uuid NOT NULL,
 version bigint NOT NULL CHECK(version>0), state text NOT NULL,
 reason_code text NOT NULL CHECK(length(reason_code) BETWEEN 1 AND 100),
 observed_at timestamptz NOT NULL CHECK(isfinite(observed_at)), received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(command_id,version),
 FOREIGN KEY(child_id,command_id) REFERENCES ap_m1.commands(child_id,id) ON DELETE CASCADE,
 CHECK(observed_at<=received_at), CHECK(state IN ('DELIVERED','ACCEPTED','COMPLETED','FAILED','UNSUPPORTED','OS_REJECTED','PERMISSION_REQUIRED','USER_ACTION_REQUIRED'))
);
-- The existing results ledger remains the terminal execution ledger.
ALTER TABLE ap_m1.command_results ADD CONSTRAINT command_results_one_per_command UNIQUE(command_id);
CREATE TABLE ap_m1.screen_time_rules (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 created_by uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 package_name text NOT NULL CHECK(length(package_name) BETWEEN 3 AND 255),
 daily_limit_seconds integer NOT NULL CHECK(daily_limit_seconds BETWEEN 0 AND 86400),
 schedule jsonb NOT NULL CHECK(jsonb_typeof(schedule)='object' AND octet_length(schedule::text)<=4096),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 legal_gate text NOT NULL DEFAULT 'BLOCKED' CHECK(legal_gate IN ('BLOCKED','SYNTHETIC_ONLY')),
 updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(child_id,id)
);
CREATE TABLE ap_m1.rule_assignments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, rule_id uuid NOT NULL, device_id uuid NOT NULL,
 rule_revision bigint NOT NULL CHECK(rule_revision>0),
 state text NOT NULL DEFAULT 'REQUESTED' CHECK(state IN ('REQUESTED','OS_APPLIED','OS_REJECTED','DISABLED')),
 effective_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL,
 updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(child_id,id),
 FOREIGN KEY(child_id,rule_id) REFERENCES ap_m1.screen_time_rules(child_id,id),
 FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id), CHECK(expires_at>effective_at)
);
CREATE TABLE ap_m1.policy_execution_receipts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, assignment_id uuid NOT NULL,
 outcome text NOT NULL CHECK(outcome IN ('OS_APPLIED','OS_REJECTED','UNSUPPORTED','PERMISSION_REQUIRED')),
 reason_code text NOT NULL CHECK(length(reason_code) BETWEEN 1 AND 100),
 observed_at timestamptz NOT NULL CHECK(isfinite(observed_at)), received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(assignment_id), FOREIGN KEY(child_id,assignment_id) REFERENCES ap_m1.rule_assignments(child_id,id) ON DELETE CASCADE,
 CHECK(observed_at<=received_at)
);

CREATE FUNCTION ap_m1.report_permissions(d uuid,generation bigint,v bigint,t timestamptz,p jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE c uuid; old ap_m1.permission_snapshots; prior jsonb; sid uuid; k text; value text;
BEGIN
 c:=ap_m1.require_domain_device(d,'CORE');
 IF generation IS DISTINCT FROM (SELECT enrollment_generation FROM ap_m1.devices WHERE id=d) THEN
 RAISE EXCEPTION 'ENROLLMENT_GENERATION_CONFLICT' USING ERRCODE='22023'; END IF;
 IF t IS NULL OR NOT isfinite(t) OR t>clock_timestamp() OR t<clock_timestamp()-interval '48 hours' OR v IS NULL OR v<1
 OR p IS NULL OR jsonb_typeof(p)<>'object' OR octet_length(p::text)>8192 THEN
 RAISE EXCEPTION 'INVALID_REPORT' USING ERRCODE='22023'; END IF;
 FOR k,value IN SELECT * FROM jsonb_each_text(p) LOOP
 IF k NOT IN ('location','background_location','usage','notifications','camera','microphone','screen_capture','media')
 OR value IS NULL OR value NOT IN ('GRANTED','DENIED','REVOKED','UNKNOWN','PARTIAL','NOT_REQUESTED','NOT_REQUIRED','TEMPORARY') THEN
 RAISE EXCEPTION 'INVALID_PERMISSION' USING ERRCODE='22023'; END IF;
 END LOOP;
 SELECT * INTO old FROM ap_m1.permission_snapshots WHERE device_id=d AND enrollment_generation=generation ORDER BY revision DESC LIMIT 1;
 IF FOUND AND v<=old.revision THEN
 IF v=old.revision AND old.payload_digest=public.digest(p::text,'sha256') AND old.observed_at=t THEN RETURN old.id; END IF;
 RAISE EXCEPTION 'REPORT_VERSION_CONFLICT' USING ERRCODE='23505'; END IF;
 prior:=coalesce(old.permissions,'{}'::jsonb);
 IF old.id IS NOT NULL AND t<old.observed_at THEN RAISE EXCEPTION 'REPORT_TIME_REGRESSION' USING ERRCODE='22023'; END IF;
 INSERT INTO ap_m1.permission_snapshots(child_id,device_id,enrollment_generation,revision,observed_at,permissions,payload_digest)
 VALUES(c,d,generation,v,t,p,public.digest(p::text,'sha256')) RETURNING id INTO sid;
 FOR k,value IN SELECT * FROM jsonb_each_text(p) LOOP
 IF prior->>k IS DISTINCT FROM value THEN
 INSERT INTO ap_m1.device_permission_change_events(child_id,device_id,snapshot_id,permission_key,old_state,new_state,observed_at)
 VALUES(c,d,sid,k,prior->>k,value,t); END IF;
 END LOOP;
 RETURN sid;
END $$;
CREATE FUNCTION ap_m1.report_capabilities(d uuid,generation bigint,v bigint,t timestamptz,api integer,mode text,features_value jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE c uuid; old ap_m1.capability_snapshots; sid uuid; h bytea; k text; feature jsonb;
BEGIN
 c:=ap_m1.require_domain_device(d,'CORE');
 IF generation IS DISTINCT FROM (SELECT enrollment_generation FROM ap_m1.devices WHERE id=d) OR v IS NULL OR v<1
 OR t IS NULL OR NOT isfinite(t) OR t>clock_timestamp() OR t<clock_timestamp()-interval '48 hours'
 OR features_value IS NULL OR jsonb_typeof(features_value)<>'object' OR octet_length(features_value::text)>8192 THEN
 RAISE EXCEPTION 'INVALID_CAPABILITY_REPORT' USING ERRCODE='22023'; END IF;
 -- Reported features are observations, NEVER a server legal-release override.
 FOR k,feature IN SELECT * FROM jsonb_each(features_value) LOOP
 IF k NOT IN ('location','background_location','usage','notifications','camera','microphone','screen_capture','media','find_device_ring','managed_policy')
 OR jsonb_typeof(feature)<>'object' OR NOT(feature ?& ARRAY['hardware','permission','runtime','release','checked_at'])
 OR coalesce(feature->>'hardware','') NOT IN ('SUPPORTED','UNSUPPORTED','UNKNOWN')
 OR coalesce(feature->>'permission','') NOT IN ('NOT_REQUIRED','NOT_REQUESTED','GRANTED','DENIED','PARTIAL','TEMPORARY','REVOKED','UNKNOWN')
 OR coalesce(feature->>'runtime','') NOT IN ('AVAILABLE','AVAILABLE_WITHIN_SCOPE','CONDITIONAL','ACTION_REQUIRED','UNAVAILABLE','UNKNOWN')
 OR coalesce(feature->>'release','') NOT IN ('ENABLED','RESEARCH_DISABLED','LEGAL_BLOCKED','NOT_IN_BUILD')
 OR feature->>'checked_at' IS NULL OR NOT isfinite((feature->>'checked_at')::timestamptz) OR (feature->>'checked_at')::timestamptz>clock_timestamp()
 OR EXISTS(SELECT 1 FROM jsonb_object_keys(feature) a(key) WHERE key NOT IN ('hardware','permission','scope','runtime','release','reason_code','checked_at')) THEN
 RAISE EXCEPTION 'INVALID_CAPABILITY_FEATURE' USING ERRCODE='22023'; END IF;
 END LOOP;
 h:=public.digest(jsonb_build_array(t,api,mode,features_value)::text,'sha256');
 SELECT * INTO old FROM ap_m1.capability_snapshots WHERE device_id=d AND enrollment_generation=generation ORDER BY report_version DESC LIMIT 1;
 IF FOUND AND v<=old.report_version THEN
 IF v=old.report_version AND old.payload_digest=h THEN RETURN old.id; END IF;
 RAISE EXCEPTION 'REPORT_VERSION_CONFLICT' USING ERRCODE='23505'; END IF;
 INSERT INTO ap_m1.capability_snapshots(device_id,observed_at,android_api,device_mode,is_device_owner,features,report_version,enrollment_generation,payload_digest)
 VALUES(d,t,api,mode,mode='MANAGED_DEVICE_OWNER',features_value,v,generation,h) RETURNING id INTO sid;
 RETURN sid;
END $$;
CREATE FUNCTION ap_m1.request_device_command(c uuid,d uuid,cmd uuid,kind text,deadline timestamptz) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE f uuid; old ap_m1.commands;
BEGIN
 IF NOT ap_m1.has_child_scope_v2(c,'MANAGE_COMMANDS') OR ap_m1.child_deleted(c) OR NOT ap_m1.has_consent(c,'CORE') THEN
 RAISE EXCEPTION 'CHILD_SCOPE_DENIED' USING ERRCODE='42501'; END IF;
 SELECT family_id INTO f FROM ap_m1.devices WHERE id=d AND child_id=c AND enrollment_state='ACTIVE' AND revoked_at IS NULL FOR NO KEY UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'DEVICE_DENIED' USING ERRCODE='42501'; END IF;
 IF kind IS NULL OR kind<>'REFRESH_CAPABILITIES' THEN
 -- Actual ringing/DPC actions need platform and release approval; no false success.
 RAISE EXCEPTION 'FEATURE_NOT_RELEASED' USING ERRCODE='42501'; END IF;
 IF deadline IS NULL OR NOT isfinite(deadline) OR deadline<=clock_timestamp() OR deadline>clock_timestamp()+interval '1 hour' THEN
 RAISE EXCEPTION 'INVALID_COMMAND_EXPIRY' USING ERRCODE='22023'; END IF;
 SELECT * INTO old FROM ap_m1.commands WHERE id=cmd;
 IF FOUND THEN
 IF old.child_id IS DISTINCT FROM c OR old.device_id IS DISTINCT FROM d OR old.command_type IS DISTINCT FROM kind
 OR old.created_by IS DISTINCT FROM ap_m1.ctx_principal() OR old.expires_at IS DISTINCT FROM deadline THEN
 RAISE EXCEPTION 'COMMAND_REPLAY_CONFLICT' USING ERRCODE='23505'; END IF;
 RETURN cmd; END IF;
 INSERT INTO ap_m1.commands(id,family_id,child_id,device_id,created_by,command_type,command_state,expires_at)
 VALUES(cmd,f,c,d,ap_m1.ctx_principal(),kind,'QUEUED',deadline);
 RETURN cmd;
END $$;
CREATE FUNCTION ap_m1.command_origin_authorized(c uuid,actor uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 SELECT NOT ap_m1.child_deleted(c) AND ap_m1.has_consent(c,'CORE') AND EXISTS(
 SELECT 1 FROM ap_m1.child_access_grants_v2 g JOIN ap_m1.consent_records r ON r.id=g.consent_record_id AND r.child_id=g.child_id
 WHERE g.child_id=c AND g.adult_id=actor AND g.scope='MANAGE_COMMANDS'
 AND g.revoked_at IS NULL AND (g.expires_at IS NULL OR g.expires_at>statement_timestamp())
 AND ap_m1._review_live(g.authority_review_id) AND r.purpose='CORE' AND r.status='GRANTED'
 AND r.revoked_at IS NULL AND r.withdrawn_at IS NULL AND (r.expires_at IS NULL OR r.expires_at>statement_timestamp())
 AND ap_m1._review_live(r.authority_review_id)
 AND (r.legal_state='APPROVED' OR r.legal_state='LOCAL_TEST_APPROVED' AND EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled))
 AND (g.origin_invite_id IS NULL AND g.issued_by=g.adult_id AND g.legacy_grant_id IS NULL
 OR EXISTS(SELECT 1 FROM ap_m1.child_access_invites i WHERE i.id=g.origin_invite_id AND i.child_id=g.child_id
 AND i.intended_adult_id=g.adult_id AND i.accepted_by_adult_id=g.adult_id AND i.accepted_at IS NOT NULL
 AND i.state='ACCEPTED' AND i.revoked_at IS NULL AND g.scope=ANY(i.requested_scopes))))
$$;
REVOKE ALL ON FUNCTION ap_m1.command_origin_authorized(uuid,uuid) FROM PUBLIC;
ALTER FUNCTION ap_m1.command_origin_authorized(uuid,uuid) OWNER TO ap_m1_auth;
GRANT EXECUTE ON FUNCTION ap_m1.command_origin_authorized(uuid,uuid) TO ap_db_executor;

CREATE FUNCTION ap_m1.record_command_receipt(d uuid,cmd uuid,v bigint,next_state text,t timestamptz,reason text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE c uuid; command ap_m1.commands; old ap_m1.command_receipts; rid uuid;
BEGIN
 c:=ap_m1.require_domain_device(d,'CORE');
 SELECT * INTO command FROM ap_m1.commands WHERE id=cmd AND device_id=d AND child_id=c FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'COMMAND_DENIED' USING ERRCODE='42501'; END IF;
 IF t IS NULL OR NOT isfinite(t) OR t>clock_timestamp() OR t<command.created_at-interval '10 seconds' OR v IS NULL OR v<1 THEN
 RAISE EXCEPTION 'INVALID_RECEIPT' USING ERRCODE='22023'; END IF;
 SELECT * INTO old FROM ap_m1.command_receipts WHERE command_id=cmd AND version=v;
 IF FOUND THEN
 IF old.state IS DISTINCT FROM next_state OR old.observed_at IS DISTINCT FROM t OR old.reason_code IS DISTINCT FROM reason THEN
 RAISE EXCEPTION 'RECEIPT_REPLAY_CONFLICT' USING ERRCODE='23505'; END IF;
 RETURN old.id; END IF;
 IF command.expires_at<=clock_timestamp() OR NOT ap_m1.has_consent(c,'CORE') THEN
 RAISE EXCEPTION 'COMMAND_EXPIRED_OR_REVOKED' USING ERRCODE='42501'; END IF;
 -- Recheck originating guardian scope using read-only helper, not billing family.
 IF NOT ap_m1.command_origin_authorized(c,command.created_by) THEN
 RAISE EXCEPTION 'COMMAND_ACTOR_REVOKED' USING ERRCODE='42501'; END IF;
 IF v<=command.last_receipt_version OR NOT (
 (command.command_state='QUEUED' AND next_state='DELIVERED') OR
 (command.command_state='DELIVERED' AND next_state IN ('ACCEPTED','OS_REJECTED','UNSUPPORTED','USER_ACTION_REQUIRED')) OR
 (command.command_state='ACCEPTED' AND next_state IN ('COMPLETED','FAILED','OS_REJECTED','PERMISSION_REQUIRED','USER_ACTION_REQUIRED'))) THEN
 RAISE EXCEPTION 'INVALID_COMMAND_TRANSITION' USING ERRCODE='22023'; END IF;
 INSERT INTO ap_m1.command_receipts(child_id,command_id,version,state,observed_at,reason_code)
 VALUES(c,cmd,v,next_state,t,reason) RETURNING id INTO rid;
 UPDATE ap_m1.commands SET command_state=next_state,last_receipt_version=v,reason_code=reason,updated_at=clock_timestamp() WHERE id=cmd;
 IF next_state IN ('COMPLETED','FAILED','UNSUPPORTED','OS_REJECTED') THEN
 INSERT INTO ap_m1.command_results(command_id,outcome,observed_at) VALUES(cmd,next_state,t);
 END IF;
 RETURN rid;
END $$;
CREATE FUNCTION ap_m1.revoke_domain_device(c uuid,d uuid,replacement uuid DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE rid uuid;
BEGIN
 IF NOT ap_m1.has_child_scope_v2(c,'REVOKE_CHILD_DEVICE') OR ap_m1.child_deleted(c) THEN
 RAISE EXCEPTION 'CHILD_SCOPE_DENIED' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.devices WHERE id=d AND child_id=c FOR NO KEY UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'DEVICE_DENIED' USING ERRCODE='42501'; END IF;
 IF replacement IS NOT NULL THEN
 PERFORM 1 FROM ap_m1.devices WHERE id=replacement AND child_id=c AND enrollment_state='ACTIVE' AND revoked_at IS NULL;
 IF NOT FOUND OR replacement=d THEN RAISE EXCEPTION 'REPLACEMENT_DENIED' USING ERRCODE='42501'; END IF;
 END IF;
 UPDATE ap_m1.devices SET enrollment_state='REVOKED',revoked_at=coalesce(revoked_at,clock_timestamp()) WHERE id=d;
 UPDATE ap_m1.device_key_records SET state='REVOKED',revoked_at=coalesce(revoked_at,clock_timestamp()) WHERE device_id=d;
 UPDATE ap_m1.commands SET command_state='CANCELLED',updated_at=clock_timestamp() WHERE device_id=d AND command_state IN ('CREATED','QUEUED','DELIVERED','ACCEPTED','DEVICE_OFFLINE');
 UPDATE ap_m1.rule_assignments SET state='DISABLED',updated_at=clock_timestamp() WHERE device_id=d;
 INSERT INTO ap_m1.device_reenrollment_events(child_id,old_device_id,replacement_device_id,requested_by,reason_code)
 VALUES(c,d,replacement,ap_m1.ctx_principal(),'PARENT_REVOKED') RETURNING id INTO rid;
 -- Replacement must be freshly enrolled with normal M1 proof; old identity/key
 -- cannot be reactivated and old token is denied by owns_active_device.
 RETURN rid;
END $$;

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['permission_snapshots','device_permission_change_events','device_reenrollment_events','command_receipts','screen_time_rules','rule_assignments','policy_execution_receipts'] LOOP
 EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
 EXECUTE format('CREATE POLICY scoped_read ON ap_m1.%I FOR SELECT TO ap_m1_api USING(ap_m1.has_child_scope_v2(child_id,''VIEW_CHILD_DEVICES'') AND ap_m1.has_consent(child_id,''CORE'') AND NOT ap_m1.child_deleted(child_id))',t);
 END LOOP;
END $$;
DROP POLICY cmds_r ON ap_m1.commands;
CREATE POLICY cmds_r ON ap_m1.commands FOR SELECT TO ap_m1_api USING(
 (ap_m1.has_child_scope_v2(child_id,'MANAGE_COMMANDS') OR (ap_m1.owns_active_device(device_id) AND expires_at>statement_timestamp()))
 AND ap_m1.has_consent(child_id,'CORE') AND NOT ap_m1.child_deleted(child_id));
GRANT SELECT ON ap_m1.permission_snapshots,ap_m1.device_permission_change_events,ap_m1.device_reenrollment_events,ap_m1.command_receipts,ap_m1.screen_time_rules,ap_m1.rule_assignments,ap_m1.policy_execution_receipts TO ap_m1_api;
GRANT SELECT,INSERT ON ap_m1.permission_snapshots,ap_m1.device_permission_change_events,ap_m1.device_reenrollment_events,ap_m1.command_receipts,ap_m1.command_results TO ap_db_executor;
GRANT SELECT,INSERT,UPDATE ON ap_m1.commands,ap_m1.capability_snapshots TO ap_db_executor;
GRANT SELECT,UPDATE ON ap_m1.rule_assignments,ap_m1.device_key_records TO ap_db_executor;
CREATE FUNCTION ap_m1.save_screen_time_rule(c uuid,r uuid,expected bigint,package text,seconds integer,plan jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
BEGIN
 IF NOT ap_m1.has_child_scope_v2(c,'MANAGE_COMMANDS') OR NOT ap_m1.has_consent(c,'USAGE') OR ap_m1.child_deleted(c) THEN
 RAISE EXCEPTION 'CHILD_SCOPE_DENIED' USING ERRCODE='42501'; END IF;
 IF package IN ('com.android.phone','com.android.server.telecom','com.android.dialer','com.google.android.dialer','android') THEN
 RAISE EXCEPTION 'CRITICAL_PACKAGE_DENIED' USING ERRCODE='22023'; END IF;
 IF expected=0 THEN
 INSERT INTO ap_m1.screen_time_rules(id,child_id,created_by,package_name,daily_limit_seconds,schedule)
 VALUES(r,c,ap_m1.ctx_principal(),package,seconds,plan);
 ELSE
 UPDATE ap_m1.screen_time_rules SET package_name=package,daily_limit_seconds=seconds,schedule=plan,revision=revision+1,updated_at=clock_timestamp(),legal_gate='BLOCKED'
 WHERE id=r AND child_id=c AND revision=expected;
 IF NOT FOUND THEN RAISE EXCEPTION 'REVISION_CONFLICT' USING ERRCODE='40001'; END IF;
 UPDATE ap_m1.rule_assignments SET state='DISABLED',updated_at=clock_timestamp() WHERE child_id=c AND rule_id=r;
 END IF;
 RETURN r;
END $$;
CREATE FUNCTION ap_m1.assign_screen_time_rule(c uuid,d uuid,r uuid,deadline timestamptz) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE rule ap_m1.screen_time_rules; rid uuid;
BEGIN
 IF NOT ap_m1.has_child_scope_v2(c,'MANAGE_COMMANDS') OR NOT ap_m1.has_consent(c,'USAGE') OR ap_m1.child_deleted(c) THEN
 RAISE EXCEPTION 'CHILD_SCOPE_DENIED' USING ERRCODE='42501'; END IF;
 SELECT * INTO rule FROM ap_m1.screen_time_rules WHERE id=r AND child_id=c FOR SHARE;
 IF NOT FOUND OR rule.legal_gate<>'SYNTHETIC_ONLY' OR NOT EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled) THEN
 RAISE EXCEPTION 'FEATURE_NOT_RELEASED' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.devices WHERE id=d AND child_id=c AND enrollment_state='ACTIVE' AND revoked_at IS NULL FOR NO KEY UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'DEVICE_DENIED' USING ERRCODE='42501'; END IF;
 IF deadline IS NULL OR NOT isfinite(deadline) OR deadline<=clock_timestamp() OR deadline>clock_timestamp()+interval '1 day' THEN
 RAISE EXCEPTION 'INVALID_POLICY_EXPIRY' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS(SELECT 1 FROM ap_m1.capability_snapshots s WHERE s.id=(SELECT id FROM ap_m1.capability_snapshots WHERE device_id=d ORDER BY received_at DESC LIMIT 1)
 AND s.device_mode='MANAGED_DEVICE_OWNER' AND s.is_device_owner AND s.received_at>clock_timestamp()-interval '15 minutes') THEN
 RAISE EXCEPTION 'MANAGED_CAPABILITY_REQUIRED' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.rule_assignments(child_id,device_id,rule_id,rule_revision,expires_at)
 VALUES(c,d,r,rule.revision,deadline) RETURNING id INTO rid;
 RETURN rid;
END $$;
CREATE FUNCTION ap_m1.record_policy_execution(d uuid,assignment uuid,outcome_value text,t timestamptz,reason text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE c uuid; a ap_m1.rule_assignments; old ap_m1.policy_execution_receipts; rid uuid;
BEGIN
 c:=ap_m1.require_domain_device(d,'USAGE');
 SELECT * INTO a FROM ap_m1.rule_assignments WHERE id=assignment AND device_id=d AND child_id=c FOR UPDATE;
 IF NOT FOUND OR a.expires_at<=clock_timestamp() OR a.state='DISABLED' THEN
 RAISE EXCEPTION 'ASSIGNMENT_DENIED' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM ap_m1.screen_time_rules r WHERE r.id=a.rule_id AND r.child_id=c AND r.revision=a.rule_revision AND r.legal_gate='SYNTHETIC_ONLY') THEN
 RAISE EXCEPTION 'RULE_REVOKED' USING ERRCODE='42501'; END IF;
 IF t IS NULL OR NOT isfinite(t) OR t>clock_timestamp() OR t<a.effective_at THEN
 RAISE EXCEPTION 'INVALID_POLICY_TIME' USING ERRCODE='22023'; END IF;
 SELECT * INTO old FROM ap_m1.policy_execution_receipts WHERE assignment_id=assignment;
 IF FOUND THEN
 IF old.outcome=outcome_value AND old.observed_at=t AND old.reason_code=reason THEN RETURN old.id; END IF;
 RAISE EXCEPTION 'POLICY_RECEIPT_CONFLICT' USING ERRCODE='23505'; END IF;
 INSERT INTO ap_m1.policy_execution_receipts(child_id,assignment_id,outcome,observed_at,reason_code)
 VALUES(c,assignment,outcome_value,t,reason) RETURNING id INTO rid;
 UPDATE ap_m1.rule_assignments SET state=CASE WHEN outcome_value='OS_APPLIED' THEN 'OS_APPLIED' ELSE 'OS_REJECTED' END,updated_at=clock_timestamp() WHERE id=assignment;
 RETURN rid;
END $$;
GRANT SELECT,INSERT,UPDATE ON ap_m1.screen_time_rules,ap_m1.rule_assignments TO ap_db_executor;
GRANT SELECT,INSERT ON ap_m1.policy_execution_receipts TO ap_db_executor;
GRANT SELECT ON ap_m1.local_test_settings TO ap_db_executor;

DO $$ DECLARE f regprocedure; BEGIN
 FOREACH f IN ARRAY ARRAY[
 'ap_m1.save_screen_time_rule(uuid,uuid,bigint,text,integer,jsonb)'::regprocedure,
 'ap_m1.assign_screen_time_rule(uuid,uuid,uuid,timestamptz)'::regprocedure,
 'ap_m1.record_policy_execution(uuid,uuid,text,timestamptz,text)'::regprocedure,
 'ap_m1.report_permissions(uuid,bigint,bigint,timestamptz,jsonb)'::regprocedure,
 'ap_m1.report_capabilities(uuid,bigint,bigint,timestamptz,integer,text,jsonb)'::regprocedure,
 'ap_m1.request_device_command(uuid,uuid,uuid,text,timestamptz)'::regprocedure,
 'ap_m1.record_command_receipt(uuid,uuid,bigint,text,timestamptz,text)'::regprocedure,
 'ap_m1.revoke_domain_device(uuid,uuid,uuid)'::regprocedure] LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC',f);
 EXECUTE format('ALTER FUNCTION %s OWNER TO ap_db_executor',f);
 EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO ap_m1_api',f);
 END LOOP;
END $$;
