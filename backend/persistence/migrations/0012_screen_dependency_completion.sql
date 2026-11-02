-- Screen dependencies, not an HTTP implementation or permission to collect real data.
-- Runner owns transaction. Existing 0002 trusted context and consent remain authoritative.
-- All writable operations below use exact-child scope or a trusted active device.
-- Two logical session entities share one explicitly typed, issuer-only store.
ALTER TABLE ap_m1.trusted_sessions ADD COLUMN session_kind text GENERATED ALWAYS AS
 (CASE WHEN principal_id IS NOT NULL THEN 'PARENT' ELSE 'DEVICE' END) STORED;
ALTER TABLE ap_m1.trusted_sessions ADD CONSTRAINT trusted_session_single_audience
 CHECK(num_nonnulls(principal_id,device_id)=1);

CREATE TABLE ap_m1.commute_plans (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 created_by uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 start_place_id uuid, end_place_id uuid,
 description text NOT NULL DEFAULT '' CHECK(length(description)<=500),
 status text NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT','ARCHIVED')),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 legal_history_gate text NOT NULL DEFAULT 'BLOCKED' CHECK(legal_history_gate='BLOCKED'),
 updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(child_id,id),
 FOREIGN KEY(child_id,start_place_id) REFERENCES ap_m1.named_places(child_id,id),
 FOREIGN KEY(child_id,end_place_id) REFERENCES ap_m1.named_places(child_id,id)
);
CREATE TABLE ap_m1.commute_plan_revisions (
 child_id uuid NOT NULL, plan_id uuid NOT NULL, revision bigint NOT NULL CHECK(revision>0),
 supersedes_revision bigint,
 start_place_id uuid, end_place_id uuid,
 timezone text NOT NULL CHECK(length(timezone) BETWEEN 1 AND 100),
 days_of_week smallint[] NOT NULL CHECK(cardinality(days_of_week) BETWEEN 1 AND 7
 AND days_of_week <@ ARRAY[1,2,3,4,5,6,7]::smallint[] AND array_position(days_of_week,NULL) IS NULL),
 expected_arrival_from time NOT NULL, expected_arrival_to time NOT NULL,
 expected_window tstzrange CHECK(expected_window IS NULL OR
 (NOT isempty(expected_window) AND NOT lower_inf(expected_window) AND NOT upper_inf(expected_window)
 AND isfinite(lower(expected_window)) AND isfinite(upper(expected_window)))),
 change_reason text NOT NULL CHECK(length(change_reason) BETWEEN 1 AND 200),
 edited_by uuid NOT NULL REFERENCES ap_m1.parent_principals(id), created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(plan_id,revision), UNIQUE(child_id,plan_id,revision),
 FOREIGN KEY(child_id,plan_id) REFERENCES ap_m1.commute_plans(child_id,id) ON DELETE CASCADE,
 FOREIGN KEY(child_id,plan_id,supersedes_revision) REFERENCES ap_m1.commute_plan_revisions(child_id,plan_id,revision),
 FOREIGN KEY(child_id,start_place_id) REFERENCES ap_m1.named_places(child_id,id),
 FOREIGN KEY(child_id,end_place_id) REFERENCES ap_m1.named_places(child_id,id),
 CHECK((revision=1 AND supersedes_revision IS NULL) OR (revision>1 AND supersedes_revision IS NOT NULL AND supersedes_revision=revision-1)),
 CHECK(expected_arrival_to>expected_arrival_from)
);
ALTER TABLE ap_m1.commute_plans ADD CONSTRAINT commute_current_revision_fk
 FOREIGN KEY(child_id,id,revision) REFERENCES ap_m1.commute_plan_revisions(child_id,plan_id,revision)
 DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX commute_child_idx ON ap_m1.commute_plans(child_id,updated_at DESC);

CREATE FUNCTION ap_m1.save_commute_plan(c uuid,p uuid,expected bigint,start_place uuid,end_place uuid,schedule jsonb,reason text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE v bigint; zone text; days smallint[]; arrival_from time; arrival_to time;
BEGIN
 IF ap_m1.has_child_scope_v2(c,'MANAGE_TRIPS') IS NOT TRUE OR NOT ap_m1.has_consent(c,'LOCATION') OR ap_m1.child_deleted(c) THEN
 RAISE EXCEPTION 'CHILD_SCOPE_DENIED' USING ERRCODE='42501'; END IF;
 IF p IS NULL OR expected IS NULL OR expected<0 OR schedule IS NULL OR jsonb_typeof(schedule)<>'object'
 OR octet_length(schedule::text)>2048 OR NOT (schedule ?& ARRAY['timezone','days_of_week','expected_arrival_from','expected_arrival_to'])
 OR jsonb_typeof(schedule->'days_of_week')<>'array'
 OR jsonb_typeof(schedule->'timezone')<>'string'
 OR jsonb_typeof(schedule->'expected_arrival_from')<>'string' OR jsonb_typeof(schedule->'expected_arrival_to')<>'string'
 THEN RAISE EXCEPTION 'INVALID_SCHEDULE' USING ERRCODE='22023'; END IF;
 zone:=schedule->>'timezone';
 IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=zone)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(schedule->'days_of_week') e WHERE jsonb_typeof(e)<>'number' OR e::text !~ '^[1-7]$')
 OR (schedule->>'expected_arrival_from') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 OR (schedule->>'expected_arrival_to') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 THEN RAISE EXCEPTION 'INVALID_SCHEDULE' USING ERRCODE='22023'; END IF;
 SELECT array_agg(DISTINCT value::smallint ORDER BY value::smallint) INTO days FROM jsonb_array_elements_text(schedule->'days_of_week');
 IF cardinality(days) IS NULL OR cardinality(days)<>jsonb_array_length(schedule->'days_of_week') THEN
 RAISE EXCEPTION 'INVALID_DAYS' USING ERRCODE='22023'; END IF;
 arrival_from:=(schedule->>'expected_arrival_from')::time; arrival_to:=(schedule->>'expected_arrival_to')::time;
 -- Lock both referenced places, deterministic order; archived places cannot be used.
 PERFORM 1 FROM ap_m1.named_places WHERE child_id=c AND id IN (start_place,end_place) AND archived_at IS NULL ORDER BY id FOR SHARE;
 IF (start_place IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ap_m1.named_places WHERE child_id=c AND id=start_place AND archived_at IS NULL))
 OR (end_place IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ap_m1.named_places WHERE child_id=c AND id=end_place AND archived_at IS NULL)) THEN
 RAISE EXCEPTION 'PLACE_DENIED' USING ERRCODE='42501'; END IF;
 IF expected=0 THEN
 INSERT INTO ap_m1.commute_plans(id,child_id,created_by,start_place_id,end_place_id)
 VALUES(p,c,ap_m1.ctx_principal(),start_place,end_place) RETURNING revision INTO v;
 ELSE
 UPDATE ap_m1.commute_plans SET start_place_id=start_place,end_place_id=end_place,revision=revision+1,updated_at=clock_timestamp()
 WHERE id=p AND child_id=c AND revision=expected AND status='DRAFT' RETURNING revision INTO v;
 IF NOT FOUND THEN RAISE EXCEPTION 'REVISION_CONFLICT' USING ERRCODE='40001'; END IF;
 END IF;
 INSERT INTO ap_m1.commute_plan_revisions(child_id,plan_id,revision,supersedes_revision,start_place_id,end_place_id,
 timezone,days_of_week,expected_arrival_from,expected_arrival_to,change_reason,edited_by)
 VALUES(c,p,v,CASE WHEN v=1 THEN NULL ELSE v-1 END,start_place,end_place,zone,days,arrival_from,arrival_to,reason,ap_m1.ctx_principal());
 RETURN v;
END $$;

CREATE TABLE ap_m1.usage_categories (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), category_key text NOT NULL UNIQUE CHECK(category_key ~ '^[A-Z][A-Z0-9_]{0,63}$'),
 classification_source text NOT NULL CHECK(classification_source IN ('CURATED','DEVICE_REPORTED','UNKNOWN')),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE ap_m1.installed_app_inventory (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, device_id uuid NOT NULL,
 package_name text NOT NULL CHECK(length(package_name) BETWEEN 3 AND 255 AND package_name ~ '^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$'),
 category_id uuid REFERENCES ap_m1.usage_categories(id), observed_at timestamptz NOT NULL CHECK(isfinite(observed_at)),
 received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 visibility_mode text NOT NULL CHECK(visibility_mode IN ('PARTIAL','OS_VISIBLE','UNKNOWN')),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(device_id,package_name), FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id), CHECK(observed_at<=received_at)
);
CREATE INDEX inventory_child_idx ON ap_m1.installed_app_inventory(child_id,device_id);
CREATE FUNCTION ap_m1.report_installed_app(p_device uuid,package text,category uuid,visibility text,t timestamptz)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE c uuid; v bigint;
BEGIN
 c:=ap_m1.require_domain_device(p_device,'USAGE');
 IF t IS NULL OR NOT isfinite(t) OR t>clock_timestamp() OR t<clock_timestamp()-interval '48 hours' THEN
 RAISE EXCEPTION 'INVALID_INVENTORY_TIME' USING ERRCODE='22023'; END IF;
 INSERT INTO ap_m1.installed_app_inventory(child_id,device_id,package_name,category_id,observed_at,visibility_mode)
 VALUES(c,p_device,package,category,t,visibility)
 ON CONFLICT(device_id,package_name) DO UPDATE SET category_id=EXCLUDED.category_id,observed_at=EXCLUDED.observed_at,
 visibility_mode=EXCLUDED.visibility_mode,revision=ap_m1.installed_app_inventory.revision+1,updated_at=clock_timestamp()
 WHERE ap_m1.installed_app_inventory.observed_at<EXCLUDED.observed_at RETURNING revision INTO v;
 IF v IS NULL THEN
 SELECT revision INTO v FROM ap_m1.installed_app_inventory WHERE device_id=p_device AND package_name=package;
 END IF;
 RETURN v;
END $$;

-- Equal source windows only. No invented daily apportionment, zeros or completeness.
CREATE VIEW ap_m1.usage_period_summaries WITH(security_invoker=true) AS
 SELECT child_id,device_id,package_name,period_start,period_end,
 CASE WHEN bool_and(foreground_duration_ms IS NOT NULL) THEN sum(foreground_duration_ms)/1000 END AS observed_seconds,
 CASE WHEN bool_and(coverage_quality='COMPLETE') THEN 'COMPLETE'
 WHEN bool_or(foreground_duration_ms IS NOT NULL) THEN 'PARTIAL'
 WHEN bool_and(coverage_quality='NOT_COLLECTED') THEN 'NOT_COLLECTED' ELSE 'UNKNOWN' END AS coverage_quality
 FROM ap_m1.app_usage_intervals GROUP BY child_id,device_id,package_name,period_start,period_end;
-- Route points remain points: never connect across a gap or map-match an invented road.
CREATE VIEW ap_m1.route_geometry WITH(security_invoker=true) AS
 SELECT r.child_id,r.device_id,r.trip_id,r.revision,r.point_no,r.observed_at,
 o.position AS geom,r.point_kind AS observed_or_inferred,r.source_event_id AS source_event_ref
 FROM ap_m1.trip_routepoints r JOIN ap_m1.location_observations o
 ON (o.child_id,o.device_id,o.event_id)=(r.child_id,r.device_id,r.source_event_id)
 WHERE r.point_kind='OBSERVED';
-- Policy projection, not another configurable retention mechanism. Paid/trial range
-- still requires stored evidence, RLS, consent and retention; NULL is not infinity.
CREATE VIEW ap_m1.history_visibility_rules WITH(security_invoker=true) AS
 SELECT 'FREE'::text AS tier,6 AS visible_hours,'can_read_location_history'::text AS enforcement
 UNION ALL SELECT 'PAID',NULL,'can_read_location_history'
 UNION ALL SELECT 'TRIAL',NULL,'can_read_location_history';

CREATE TABLE ap_m1.scheduled_child_tasks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id), device_id uuid,
 kind text NOT NULL CHECK(kind IN ('CHECKIN_REMINDER','SCREEN_TIME_GOAL')),
 goal text NOT NULL CHECK(length(goal) BETWEEN 1 AND 500),
 schedule jsonb NOT NULL CHECK(jsonb_typeof(schedule)='object' AND octet_length(schedule::text)<=2048),
 status text NOT NULL DEFAULT 'DISABLED' CHECK(status IN ('DISABLED','CANCELLED','COMPLETED_SYNTHETIC')),
 completed_at timestamptz, revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id),
 CHECK((status='COMPLETED_SYNTHETIC')=(completed_at IS NOT NULL))
);
CREATE INDEX scheduled_child_idx ON ap_m1.scheduled_child_tasks(child_id);
CREATE TABLE ap_m1.tracking_policy_revisions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, device_id uuid NOT NULL,
 policy_version bigint NOT NULL CHECK(policy_version>0),
 frequency_class text NOT NULL CHECK(frequency_class IN ('DISABLED','FREE','PAID','TRIAL')),
 sample_interval_seconds integer CHECK(sample_interval_seconds BETWEEN 5 AND 86400),
 effective_at timestamptz NOT NULL CHECK(isfinite(effective_at)), expires_at timestamptz NOT NULL CHECK(isfinite(expires_at)),
 device_ack_at timestamptz, legal_gate text NOT NULL DEFAULT 'BLOCKED' CHECK(legal_gate='BLOCKED'),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(device_id,policy_version),
 FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id),
 CHECK(expires_at>effective_at), CHECK(device_ack_at IS NULL OR (isfinite(device_ack_at) AND device_ack_at>=effective_at)),
 CHECK((frequency_class='DISABLED' AND sample_interval_seconds IS NULL) OR (frequency_class<>'DISABLED' AND sample_interval_seconds IS NOT NULL))
);
CREATE INDEX tracking_child_idx ON ap_m1.tracking_policy_revisions(child_id);
-- Bind to the same request, device AND child. A UI approval never releases capture.
ALTER TABLE ap_m1.media_command_requests ADD CONSTRAINT media_request_child_device_key UNIQUE(child_id,device_id,id);
ALTER TABLE ap_m1.media_command_requests ADD CONSTRAINT media_request_device_child_fk
 FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id);
CREATE TABLE ap_m1.media_request_device_approvals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, request_id uuid NOT NULL UNIQUE, device_id uuid NOT NULL,
 device_ui_consent_state text NOT NULL DEFAULT 'NOT_REQUESTED'
 CHECK(device_ui_consent_state IN ('NOT_REQUESTED','DENIED','APPROVED_SYNTHETIC','OS_REJECTED')),
 requested_at timestamptz NOT NULL DEFAULT now(), decided_at timestamptz,
 os_decision_reason text NOT NULL CHECK(os_decision_reason IN ('FEATURE_NOT_RELEASED','USER_DENIED','OS_REJECTED','SYNTHETIC_FIXTURE')),
 real_capture_enabled boolean NOT NULL DEFAULT false CHECK(NOT real_capture_enabled),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(child_id,device_id,request_id) REFERENCES ap_m1.media_command_requests(child_id,device_id,id) ON DELETE CASCADE,
 FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id),
 CHECK((device_ui_consent_state='NOT_REQUESTED' AND decided_at IS NULL) OR
 (device_ui_consent_state<>'NOT_REQUESTED' AND decided_at IS NOT NULL AND isfinite(decided_at) AND decided_at>=requested_at)),
 CHECK(device_ui_consent_state<>'APPROVED_SYNTHETIC' OR os_decision_reason='SYNTHETIC_FIXTURE')
);

-- Observed leg/stop annotations are not representable as a trip's two timestamps.
-- Endpoints must be OBSERVED routepoints in this exact child/device/trip/revision.
ALTER TABLE ap_m1.trip_routepoints ADD CONSTRAINT routepoint_observed_binding_key
 UNIQUE(child_id,device_id,trip_id,revision,point_no,point_kind);
CREATE TABLE ap_m1.trip_legs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, device_id uuid NOT NULL,
 trip_id uuid NOT NULL, revision integer NOT NULL, leg_no integer NOT NULL CHECK(leg_no>=0),
 first_point_no integer NOT NULL, last_point_no integer NOT NULL,
 evidence_kind text NOT NULL DEFAULT 'OBSERVED' CHECK(evidence_kind='OBSERVED'),
 mode_inference text NOT NULL DEFAULT 'UNKNOWN' CHECK(mode_inference IN ('UNKNOWN','STATIONARY','WALKING','VEHICLE')),
 confidence numeric(4,3) NOT NULL CHECK(confidence BETWEEN 0 AND 1), gaps_present boolean NOT NULL DEFAULT true,
 observed_distance_m numeric CHECK(observed_distance_m>=0),
 UNIQUE(trip_id,revision,leg_no), CHECK(last_point_no>first_point_no),
 FOREIGN KEY(child_id,trip_id,revision) REFERENCES ap_m1.trip_revisions(child_id,trip_id,revision) ON DELETE CASCADE,
 FOREIGN KEY(child_id,device_id,trip_id,revision,first_point_no,evidence_kind)
 REFERENCES ap_m1.trip_routepoints(child_id,device_id,trip_id,revision,point_no,point_kind) ON DELETE CASCADE,
 FOREIGN KEY(child_id,device_id,trip_id,revision,last_point_no,evidence_kind)
 REFERENCES ap_m1.trip_routepoints(child_id,device_id,trip_id,revision,point_no,point_kind) ON DELETE CASCADE
);
CREATE INDEX legs_child_idx ON ap_m1.trip_legs(child_id);
CREATE TABLE ap_m1.stops (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, device_id uuid NOT NULL,
 trip_id uuid NOT NULL, revision integer NOT NULL,
 first_point_no integer NOT NULL, last_point_no integer NOT NULL,
 evidence_kind text NOT NULL DEFAULT 'OBSERVED' CHECK(evidence_kind='OBSERVED'),
 confidence numeric(4,3) NOT NULL CHECK(confidence BETWEEN 0 AND 1),
 name_source text NOT NULL DEFAULT 'UNKNOWN' CHECK(name_source IN ('UNKNOWN','NAMED_PLACE')),
 place_id uuid, UNIQUE(trip_id,revision,first_point_no,last_point_no), CHECK(last_point_no>first_point_no),
 FOREIGN KEY(child_id,place_id) REFERENCES ap_m1.named_places(child_id,id),
 FOREIGN KEY(child_id,trip_id,revision) REFERENCES ap_m1.trip_revisions(child_id,trip_id,revision) ON DELETE CASCADE,
 FOREIGN KEY(child_id,device_id,trip_id,revision,first_point_no,evidence_kind)
 REFERENCES ap_m1.trip_routepoints(child_id,device_id,trip_id,revision,point_no,point_kind) ON DELETE CASCADE,
 FOREIGN KEY(child_id,device_id,trip_id,revision,last_point_no,evidence_kind)
 REFERENCES ap_m1.trip_routepoints(child_id,device_id,trip_id,revision,point_no,point_kind) ON DELETE CASCADE,
 CHECK((name_source='NAMED_PLACE')=(place_id IS NOT NULL))
);
CREATE INDEX stops_child_idx ON ap_m1.stops(child_id);

-- Need-to-know case metadata ONLY: no payload, evidence URL, arbitrary field list,
-- GPS/media scope, support message body, or authorization hook into child policies.
CREATE TABLE ap_m1.admin_cases (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 assigned_admin_id uuid NOT NULL REFERENCES ap_m1.admin_accounts(id),
 approver_id uuid NOT NULL REFERENCES ap_m1.admin_accounts(id),
 purpose text NOT NULL CHECK(purpose IN ('SUPPORT_METADATA','ERASURE_METADATA','BILLING_METADATA')),
 reason_code text NOT NULL CHECK(reason_code ~ '^[A-Z0-9_]{1,80}$'),
 case_status text NOT NULL DEFAULT 'PENDING' CHECK(case_status IN ('PENDING','APPROVED_METADATA','CLOSED','EXPIRED')),
 opened_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(child_id,id), CHECK(isfinite(expires_at) AND expires_at>opened_at), CHECK(assigned_admin_id<>approver_id)
);
CREATE TABLE ap_m1.admin_case_scopes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, case_id uuid NOT NULL,
 admin_id uuid NOT NULL REFERENCES ap_m1.admin_accounts(id),
 second_approver_id uuid NOT NULL REFERENCES ap_m1.admin_accounts(id),
 permitted_field text NOT NULL CHECK(permitted_field IN ('CASE_STATUS','REASON_CODE','CASE_TIMESTAMPS')),
 valid_from timestamptz NOT NULL DEFAULT now(), valid_until timestamptz NOT NULL,
 revoked_at timestamptz, UNIQUE(case_id,admin_id,permitted_field),
 FOREIGN KEY(child_id,case_id) REFERENCES ap_m1.admin_cases(child_id,id) ON DELETE CASCADE,
 CHECK(isfinite(valid_from) AND isfinite(valid_until) AND valid_until>valid_from), CHECK(admin_id<>second_approver_id)
);
CREATE INDEX cases_child_idx ON ap_m1.admin_cases(child_id);
CREATE INDEX case_scopes_child_idx ON ap_m1.admin_case_scopes(child_id);

-- Global category preferences cannot be encoded by a per-place arrival/exit row.
-- NULL child is account-global; it never grants access to any child's alerts.
CREATE TABLE ap_m1.notification_preferences (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 child_id uuid REFERENCES ap_m1.children(id),
 alert_type text NOT NULL CHECK(alert_type IN ('ALL','SOS','CHECKIN','PLACE','DEVICE_HEALTH','BILLING')),
 enabled boolean NOT NULL DEFAULT false,
 quiet_schedule jsonb NOT NULL DEFAULT '{}' CHECK(jsonb_typeof(quiet_schedule)='object' AND octet_length(quiet_schedule::text)<=1024),
 channel_policy jsonb NOT NULL DEFAULT '{}' CHECK(jsonb_typeof(channel_policy)='object' AND octet_length(channel_policy::text)<=1024),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE NULLS NOT DISTINCT(adult_id,child_id,alert_type)
);
CREATE INDEX notification_preferences_child_idx ON ap_m1.notification_preferences(child_id);

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['commute_plans','commute_plan_revisions','installed_app_inventory','usage_categories',
 'scheduled_child_tasks','media_request_device_approvals','tracking_policy_revisions','trip_legs','stops',
 'admin_cases','admin_case_scopes','notification_preferences'] LOOP
 EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON TABLE ap_m1.%I FROM PUBLIC,ap_m1_api',t);
 EXECUTE format('GRANT SELECT ON TABLE ap_m1.%I TO ap_m1_api',t);
 EXECUTE format('GRANT SELECT,DELETE ON TABLE ap_m1.%I TO ap_db_executor',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['commute_plans','commute_plan_revisions'] LOOP
 EXECUTE format('CREATE POLICY exact_child_read ON ap_m1.%I FOR SELECT TO ap_m1_api USING(ap_m1.has_child_scope_v2(child_id,''MANAGE_TRIPS'') AND ap_m1.has_consent(child_id,''LOCATION'') AND NOT ap_m1.child_deleted(child_id))',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['trip_legs','stops'] LOOP
 EXECUTE format('CREATE POLICY observed_history_read ON ap_m1.%I FOR SELECT TO ap_m1_api USING(EXISTS(SELECT 1 FROM ap_m1.trip_revisions r WHERE r.child_id=%I.child_id AND r.trip_id=%I.trip_id AND r.revision=%I.revision))',t,t,t,t);
 END LOOP;
END $$;
CREATE POLICY inventory_read ON ap_m1.installed_app_inventory FOR SELECT TO ap_m1_api
 USING(ap_m1.has_child_scope_v2(child_id,'VIEW_USAGE') AND ap_m1.has_consent(child_id,'USAGE') AND NOT ap_m1.child_deleted(child_id));
CREATE POLICY categories_read ON ap_m1.usage_categories FOR SELECT TO ap_m1_api USING(ap_m1.ctx_principal() IS NOT NULL);
CREATE POLICY tasks_read ON ap_m1.scheduled_child_tasks FOR SELECT TO ap_m1_api
 USING(adult_id=ap_m1.ctx_principal() AND ap_m1.has_child_scope_v2(child_id,'MANAGE_COMMANDS') AND NOT ap_m1.child_deleted(child_id));
CREATE POLICY tracking_read ON ap_m1.tracking_policy_revisions FOR SELECT TO ap_m1_api
 USING(NOT ap_m1.child_deleted(child_id) AND ap_m1.has_consent(child_id,'LOCATION') AND
 (ap_m1.has_child_scope_v2(child_id,'VIEW_CHILD_DEVICES') OR ap_m1.owns_active_device(device_id)));
CREATE POLICY approval_read ON ap_m1.media_request_device_approvals FOR SELECT TO ap_m1_api
 USING(NOT ap_m1.child_deleted(child_id) AND ap_m1.has_consent(child_id,'MEDIA') AND
 (ap_m1.has_child_scope_v2(child_id,'VIEW_MEDIA') OR ap_m1.owns_active_device(device_id)));
CREATE POLICY case_metadata_read ON ap_m1.admin_cases FOR SELECT TO ap_m1_api
 USING(assigned_admin_id=ap_m1.ctx_admin() AND ap_m1.has_admin_permission('SUPPORT_REPLY') AND expires_at>statement_timestamp());
CREATE POLICY case_scope_metadata_read ON ap_m1.admin_case_scopes FOR SELECT TO ap_m1_api
 USING(admin_id=ap_m1.ctx_admin() AND ap_m1.has_admin_permission('SUPPORT_REPLY') AND revoked_at IS NULL
 AND valid_from<=statement_timestamp() AND valid_until>statement_timestamp()
 AND EXISTS(SELECT 1 FROM ap_m1.admin_cases c WHERE c.id=case_id AND c.child_id=admin_case_scopes.child_id AND c.case_status='APPROVED_METADATA'));
CREATE POLICY personal_notification_read ON ap_m1.notification_preferences FOR SELECT TO ap_m1_api
 USING(adult_id=ap_m1.ctx_principal() AND (child_id IS NULL OR
 (ap_m1.has_child_scope_v2(child_id,'VIEW_ALERTS') AND NOT ap_m1.child_deleted(child_id))));
GRANT SELECT ON ap_m1.usage_period_summaries,ap_m1.route_geometry,ap_m1.history_visibility_rules TO ap_m1_api;
GRANT SELECT,INSERT,UPDATE ON ap_m1.commute_plans,ap_m1.installed_app_inventory TO ap_db_executor;
GRANT INSERT ON ap_m1.commute_plan_revisions TO ap_db_executor;
GRANT SELECT,UPDATE ON ap_m1.named_places TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.save_commute_plan(uuid,uuid,bigint,uuid,uuid,jsonb,text) FROM PUBLIC;
ALTER FUNCTION ap_m1.save_commute_plan(uuid,uuid,bigint,uuid,uuid,jsonb,text) OWNER TO ap_db_executor;
GRANT EXECUTE ON FUNCTION ap_m1.save_commute_plan(uuid,uuid,bigint,uuid,uuid,jsonb,text) TO ap_m1_api;
REVOKE ALL ON FUNCTION ap_m1.report_installed_app(uuid,text,uuid,text,timestamptz) FROM PUBLIC;
ALTER FUNCTION ap_m1.report_installed_app(uuid,text,uuid,text,timestamptz) OWNER TO ap_db_executor;
GRANT EXECUTE ON FUNCTION ap_m1.report_installed_app(uuid,text,uuid,text,timestamptz) TO ap_m1_api;

-- Inventory is FORCE RLS; the migration login cannot discover its existing rows.
-- Literal upserts under the existing bounded executor role, never conditional DDL.
GRANT INSERT,UPDATE,DELETE ON ap_m1.erasure_store_inventory TO ap_db_executor;
SET LOCAL ROLE ap_db_executor;
-- Derived views and normalized aliases are not independent erasure stores.
DELETE FROM ap_m1.erasure_store_inventory WHERE table_name IN
 ('usage_period_summaries','sos_events','sos_acknowledgements','child_checkins','app_usage_events','geofence_events');
-- Revisions/plans MUST precede named_places (60), not their old placeholder 140/150.
INSERT INTO ap_m1.erasure_store_inventory(table_name,key_kind,purge_order) VALUES
 ('trip_legs','CHILD',1),('stops','CHILD',2),('admin_case_scopes','CHILD',3),('admin_cases','CHILD',4),
 ('commute_plan_revisions','CHILD',53),('commute_plans','CHILD',54),
 ('notification_preferences','CHILD',120),('scheduled_child_tasks','CHILD',155),
 ('installed_app_inventory','CHILD',190),('tracking_policy_revisions','CHILD',280),
 ('media_request_device_approvals','CHILD',290)
 ON CONFLICT(table_name) DO UPDATE SET key_kind=EXCLUDED.key_kind,purge_order=EXCLUDED.purge_order;
RESET ROLE;
REVOKE INSERT,UPDATE,DELETE ON ap_m1.erasure_store_inventory FROM ap_db_executor;
