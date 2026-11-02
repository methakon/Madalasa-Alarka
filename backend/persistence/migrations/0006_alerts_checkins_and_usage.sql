-- Alerts, explicit check-ins/SOS, and independent Usage Access intervals.
-- No provider request here constitutes delivery or human acknowledgement.
CREATE TABLE ap_m1.place_notification_rules (
 child_id uuid NOT NULL, place_id uuid NOT NULL,
 adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 arrival_enabled boolean NOT NULL DEFAULT false, departure_enabled boolean NOT NULL DEFAULT false,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(place_id,adult_id),
 FOREIGN KEY(child_id,place_id) REFERENCES ap_m1.named_places(child_id,id) ON DELETE CASCADE
);
CREATE TABLE ap_m1.child_signals (
 event_id uuid PRIMARY KEY, child_id uuid NOT NULL REFERENCES ap_m1.children(id), device_id uuid NOT NULL,
 kind text NOT NULL CHECK(kind IN ('SOS','IM_SAFE','PLEASE_CALL','NEED_PICKUP')),
 observed_at timestamptz NOT NULL CHECK(isfinite(observed_at)),
 accepted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(child_id,event_id), FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id),
 CHECK(observed_at<=accepted_at)
);
CREATE INDEX signals_child_time_idx ON ap_m1.child_signals(child_id,observed_at DESC);
CREATE TABLE ap_m1.alert_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 signal_event_id uuid, place_id uuid,
 kind text NOT NULL CHECK(kind IN ('SOS','CHECKIN','ARRIVE','EXIT','UNKNOWN')),
 observed_at timestamptz NOT NULL CHECK(isfinite(observed_at)), created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(child_id,id), UNIQUE(signal_event_id),
 FOREIGN KEY(child_id,signal_event_id) REFERENCES ap_m1.child_signals(child_id,event_id) ON DELETE CASCADE,
 FOREIGN KEY(child_id,place_id) REFERENCES ap_m1.named_places(child_id,id),
 CHECK((kind IN ('SOS','CHECKIN') AND signal_event_id IS NOT NULL AND place_id IS NULL)
 OR (kind IN ('ARRIVE','EXIT','UNKNOWN') AND signal_event_id IS NULL AND place_id IS NOT NULL)),
 CHECK(observed_at<=created_at)
);
CREATE TABLE ap_m1.alert_delivery_outbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, alert_id uuid NOT NULL,
 state text NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','DISPATCHED','FAILED','CANCELLED')),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0), next_attempt_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(alert_id),
 FOREIGN KEY(child_id,alert_id) REFERENCES ap_m1.alert_events(child_id,id) ON DELETE CASCADE
);
CREATE INDEX alert_delivery_pending_idx ON ap_m1.alert_delivery_outbox(next_attempt_at) WHERE state='PENDING';
CREATE TABLE ap_m1.notification_deliveries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, alert_id uuid NOT NULL,
 recipient_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 status text NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','SUBMITTED','DELIVERY_CONFIRMED','FAILED','UNKNOWN')),
 submitted_at timestamptz, delivered_at timestamptz, updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(child_id,id), UNIQUE(alert_id,recipient_id),
 FOREIGN KEY(child_id,alert_id) REFERENCES ap_m1.alert_events(child_id,id) ON DELETE CASCADE,
 CHECK(status<>'SUBMITTED' OR submitted_at IS NOT NULL),
 CHECK(status<>'DELIVERY_CONFIRMED' OR delivered_at IS NOT NULL)
);
CREATE TABLE ap_m1.alert_delivery_attempts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL, delivery_id uuid NOT NULL,
 attempt_no integer NOT NULL CHECK(attempt_no>0), channel text NOT NULL CHECK(channel IN ('PUSH','SMS','EMAIL')),
 outcome text NOT NULL CHECK(outcome IN ('SUBMITTED','DELIVERY_CONFIRMED','FAILED','UNKNOWN')),
 provider_reference text CHECK(length(provider_reference)<=200),
 attempted_at timestamptz NOT NULL DEFAULT clock_timestamp(), UNIQUE(delivery_id,attempt_no),
 FOREIGN KEY(child_id,delivery_id) REFERENCES ap_m1.notification_deliveries(child_id,id) ON DELETE CASCADE
);
CREATE TABLE ap_m1.signal_acknowledgements (
 child_id uuid NOT NULL, event_id uuid NOT NULL, adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 acknowledged_at timestamptz NOT NULL DEFAULT clock_timestamp(), PRIMARY KEY(event_id,adult_id),
 FOREIGN KEY(child_id,event_id) REFERENCES ap_m1.child_signals(child_id,event_id) ON DELETE CASCADE
);
CREATE TABLE ap_m1.parent_notification_read_receipts (
 child_id uuid NOT NULL, delivery_id uuid NOT NULL, adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 read_at timestamptz NOT NULL DEFAULT clock_timestamp(), PRIMARY KEY(delivery_id,adult_id),
 FOREIGN KEY(child_id,delivery_id) REFERENCES ap_m1.notification_deliveries(child_id,id) ON DELETE CASCADE
);

CREATE FUNCTION ap_m1.set_place_notification_rule(c uuid,p uuid,expected bigint,arrive boolean,depart boolean) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE v bigint;
BEGIN
 IF NOT ap_m1.has_child_scope_v2(c,'MANAGE_ALERTS') OR NOT ap_m1.has_consent(c,'LOCATION') OR ap_m1.child_deleted(c) THEN
 RAISE EXCEPTION 'CHILD_SCOPE_DENIED' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.named_places WHERE child_id=c AND id=p AND archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'PLACE_DENIED' USING ERRCODE='42501'; END IF;
 IF expected=0 THEN
 INSERT INTO ap_m1.place_notification_rules(child_id,place_id,adult_id,arrival_enabled,departure_enabled)
 VALUES(c,p,ap_m1.ctx_principal(),arrive,depart) RETURNING revision INTO v;
 ELSE
 UPDATE ap_m1.place_notification_rules SET arrival_enabled=arrive,departure_enabled=depart,revision=revision+1,updated_at=clock_timestamp()
 WHERE child_id=c AND place_id=p AND adult_id=ap_m1.ctx_principal() AND revision=expected RETURNING revision INTO v;
 IF NOT FOUND THEN RAISE EXCEPTION 'REVISION_CONFLICT' USING ERRCODE='40001'; END IF;
 END IF;
 RETURN v;
END $$;
CREATE FUNCTION ap_m1.record_child_signal(p_device uuid,eid uuid,p_kind text,t timestamptz) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE c uuid; old ap_m1.child_signals; alert uuid;
BEGIN
 c:=ap_m1.require_domain_device(p_device,'CORE');
 IF eid IS NULL OR t IS NULL OR NOT isfinite(t) OR t>clock_timestamp() OR t<clock_timestamp()-interval '48 hours' THEN
 RAISE EXCEPTION 'INVALID_SIGNAL_TIME' USING ERRCODE='22023'; END IF;
 SELECT * INTO old FROM ap_m1.child_signals WHERE event_id=eid;
 IF FOUND THEN
 IF old.device_id IS DISTINCT FROM p_device OR old.kind IS DISTINCT FROM p_kind OR old.observed_at IS DISTINCT FROM t THEN
 RAISE EXCEPTION 'SIGNAL_REPLAY_CONFLICT' USING ERRCODE='23505'; END IF;
 RETURN eid;
 END IF;
 INSERT INTO ap_m1.child_signals(event_id,child_id,device_id,kind,observed_at) VALUES(eid,c,p_device,p_kind,t);
 INSERT INTO ap_m1.alert_events(child_id,signal_event_id,kind,observed_at)
 VALUES(c,eid,CASE WHEN p_kind='SOS' THEN 'SOS' ELSE 'CHECKIN' END,t) RETURNING id INTO alert;
 INSERT INTO ap_m1.alert_delivery_outbox(child_id,alert_id) VALUES(c,alert);
 RETURN eid;
END $$;
CREATE FUNCTION ap_m1.acknowledge_child_signal(c uuid,eid uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
BEGIN
 IF NOT ap_m1.has_child_scope_v2(c,'VIEW_ALERTS') OR NOT ap_m1.has_consent(c,'CORE') OR ap_m1.child_deleted(c) THEN
 RAISE EXCEPTION 'CHILD_SCOPE_DENIED' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.signal_acknowledgements(child_id,event_id,adult_id) VALUES(c,eid,ap_m1.ctx_principal())
 ON CONFLICT(event_id,adult_id) DO NOTHING;
END $$;
CREATE FUNCTION ap_m1.mark_notification_read(c uuid,d uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
BEGIN
 IF NOT ap_m1.has_child_scope_v2(c,'VIEW_ALERTS') OR ap_m1.child_deleted(c) THEN
 RAISE EXCEPTION 'CHILD_SCOPE_DENIED' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.notification_deliveries WHERE id=d AND child_id=c AND recipient_id=ap_m1.ctx_principal();
 IF NOT FOUND THEN RAISE EXCEPTION 'DELIVERY_DENIED' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.parent_notification_read_receipts(child_id,delivery_id,adult_id) VALUES(c,d,ap_m1.ctx_principal()) ON CONFLICT DO NOTHING;
END $$;

-- Worker-only recipient lookup; grant/review/invite checked again at dispatch.
CREATE FUNCTION ap_m1.alert_recipient_authorized(c uuid,actor uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 SELECT NOT ap_m1.child_deleted(c) AND ap_m1.has_consent(c,'CORE') AND EXISTS(
 SELECT 1 FROM ap_m1.child_access_grants_v2 g JOIN ap_m1.consent_records r ON r.id=g.consent_record_id AND r.child_id=g.child_id
 WHERE g.child_id=c AND g.adult_id=actor AND g.scope='VIEW_ALERTS'
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
REVOKE ALL ON FUNCTION ap_m1.alert_recipient_authorized(uuid,uuid) FROM PUBLIC;
ALTER FUNCTION ap_m1.alert_recipient_authorized(uuid,uuid) OWNER TO ap_m1_auth;
GRANT EXECUTE ON FUNCTION ap_m1.alert_recipient_authorized(uuid,uuid) TO ap_db_executor;
CREATE FUNCTION ap_m1.record_alert_delivery_attempt(c uuid,alert uuid,recipient uuid,channel_value text,outcome_value text,provider_ref text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE delivery uuid; attempt integer;
BEGIN
 IF NOT ap_m1.alert_recipient_authorized(c,recipient) THEN RAISE EXCEPTION 'RECIPIENT_REVOKED' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.alert_events WHERE child_id=c AND id=alert
 AND (kind IN ('SOS','CHECKIN') OR ap_m1.has_consent(c,'LOCATION')) FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'ALERT_DENIED' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.notification_deliveries(child_id,alert_id,recipient_id) VALUES(c,alert,recipient)
 ON CONFLICT(alert_id,recipient_id) DO NOTHING;
 SELECT id INTO delivery FROM ap_m1.notification_deliveries WHERE child_id=c AND alert_id=alert AND recipient_id=recipient FOR UPDATE;
 SELECT coalesce(max(attempt_no),0)+1 INTO attempt FROM ap_m1.alert_delivery_attempts WHERE delivery_id=delivery;
 INSERT INTO ap_m1.alert_delivery_attempts(child_id,delivery_id,attempt_no,channel,outcome,provider_reference)
 VALUES(c,delivery,attempt,channel_value,outcome_value,provider_ref);
 UPDATE ap_m1.notification_deliveries SET status=outcome_value,
 submitted_at=CASE WHEN outcome_value IN ('SUBMITTED','DELIVERY_CONFIRMED') THEN coalesce(submitted_at,clock_timestamp()) ELSE submitted_at END,
 delivered_at=CASE WHEN outcome_value='DELIVERY_CONFIRMED' THEN coalesce(delivered_at,clock_timestamp()) ELSE delivered_at END,
 updated_at=clock_timestamp() WHERE id=delivery;
 UPDATE ap_m1.alert_delivery_outbox SET attempts=attempts+1,state=CASE WHEN outcome_value IN ('SUBMITTED','DELIVERY_CONFIRMED') THEN 'DISPATCHED' ELSE 'PENDING' END,
 next_attempt_at=clock_timestamp()+interval '1 minute' WHERE child_id=c AND alert_id=alert;
 RETURN delivery;
END $$;
REVOKE ALL ON FUNCTION ap_m1.record_alert_delivery_attempt(uuid,uuid,uuid,text,text,text) FROM PUBLIC;
ALTER FUNCTION ap_m1.record_alert_delivery_attempt(uuid,uuid,uuid,text,text,text) OWNER TO ap_db_executor;
GRANT SELECT,INSERT,UPDATE ON ap_m1.notification_deliveries TO ap_db_executor;
GRANT SELECT,INSERT ON ap_m1.alert_delivery_attempts TO ap_db_executor;
GRANT UPDATE ON ap_m1.alert_events,ap_m1.alert_delivery_outbox TO ap_db_executor;

CREATE TABLE ap_m1.app_usage_intervals (
 device_id uuid NOT NULL, event_id uuid NOT NULL, child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 package_name text NOT NULL CHECK(length(package_name) BETWEEN 3 AND 255 AND package_name ~ '^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$'),
 period_start timestamptz NOT NULL, period_end timestamptz NOT NULL,
 foreground_duration_ms bigint, coverage_quality text NOT NULL CHECK(coverage_quality IN ('UNKNOWN','NOT_COLLECTED','PARTIAL','COMPLETE')),
 received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(device_id,event_id), FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id),
 CHECK(isfinite(period_start) AND isfinite(period_end) AND period_end>period_start AND period_end<=received_at),
 CHECK((coverage_quality IN ('UNKNOWN','NOT_COLLECTED') AND foreground_duration_ms IS NULL)
 OR (coverage_quality IN ('PARTIAL','COMPLETE') AND foreground_duration_ms IS NOT NULL AND foreground_duration_ms>=0
 AND foreground_duration_ms<=extract(epoch FROM period_end-period_start)*1000))
);
CREATE INDEX usage_child_time_idx ON ap_m1.app_usage_intervals(child_id,period_start DESC);
CREATE INDEX usage_device_package_time_idx ON ap_m1.app_usage_intervals(device_id,package_name,period_start,period_end);
CREATE FUNCTION ap_m1.record_usage_interval(p_device uuid,eid uuid,package text,start_at timestamptz,end_at timestamptz,duration_ms bigint,coverage text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE c uuid; old ap_m1.app_usage_intervals;
BEGIN
 c:=ap_m1.require_domain_device(p_device,'USAGE');
 IF start_at IS NULL OR end_at IS NULL OR NOT isfinite(start_at) OR NOT isfinite(end_at) OR end_at<=start_at
 OR end_at>clock_timestamp() OR start_at<clock_timestamp()-interval '48 hours' THEN
 RAISE EXCEPTION 'INVALID_USAGE_TIME' USING ERRCODE='22023'; END IF;
 SELECT * INTO old FROM ap_m1.app_usage_intervals WHERE device_id=p_device AND event_id=eid;
 IF FOUND THEN
 IF old.package_name IS DISTINCT FROM package OR old.period_start IS DISTINCT FROM start_at OR old.period_end IS DISTINCT FROM end_at
 OR old.foreground_duration_ms IS DISTINCT FROM duration_ms OR old.coverage_quality IS DISTINCT FROM coverage THEN
 RAISE EXCEPTION 'USAGE_REPLAY_CONFLICT' USING ERRCODE='23505'; END IF;
 RETURN eid;
 END IF;
 -- Device row lock held by require_domain_device serializes overlap checks.
 IF EXISTS(SELECT 1 FROM ap_m1.app_usage_intervals WHERE device_id=p_device AND package_name=package
 AND tstzrange(period_start,period_end,'[)') && tstzrange(start_at,end_at,'[)')) THEN
 RAISE EXCEPTION 'USAGE_OVERLAP' USING ERRCODE='23505'; END IF;
 INSERT INTO ap_m1.app_usage_intervals(device_id,event_id,child_id,package_name,period_start,period_end,foreground_duration_ms,coverage_quality)
 VALUES(p_device,eid,c,package,start_at,end_at,duration_ms,coverage);
 RETURN eid;
END $$;
-- No proportional fake allocation across day/DST boundaries. Only intervals wholly
-- covered by a requested UTC window are summed; boundary crossings are PARTIAL.
CREATE FUNCTION ap_m1.usage_summary(c uuid,from_at timestamptz,to_at timestamptz)
RETURNS TABLE(device_id uuid,package_name text,observed_seconds bigint,coverage_quality text)
LANGUAGE sql STABLE SET search_path=pg_catalog,ap_m1,public AS $$
 SELECT u.device_id,u.package_name,
 CASE WHEN bool_or(u.foreground_duration_ms IS NOT NULL AND u.period_start>=from_at AND u.period_end<=to_at)
 THEN sum(CASE WHEN u.period_start>=from_at AND u.period_end<=to_at THEN u.foreground_duration_ms END)::bigint/1000 ELSE NULL END,
 CASE WHEN bool_and(u.coverage_quality='COMPLETE') AND min(u.period_start)=from_at AND max(u.period_end)=to_at
 AND sum(extract(epoch FROM u.period_end-u.period_start))=extract(epoch FROM to_at-from_at) THEN 'COMPLETE'
 WHEN bool_or(u.foreground_duration_ms IS NOT NULL) THEN 'PARTIAL' ELSE 'UNKNOWN' END
 FROM ap_m1.app_usage_intervals u WHERE u.child_id=c AND from_at<to_at AND to_at<=statement_timestamp()
 AND u.period_start<to_at AND u.period_end>from_at GROUP BY u.device_id,u.package_name
$$;
REVOKE ALL ON FUNCTION ap_m1.usage_summary(uuid,timestamptz,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.usage_summary(uuid,timestamptz,timestamptz) TO ap_m1_api;

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['place_notification_rules','child_signals','alert_events','alert_delivery_outbox','notification_deliveries','alert_delivery_attempts','signal_acknowledgements','parent_notification_read_receipts','app_usage_intervals'] LOOP
 EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['child_signals','alert_events','signal_acknowledgements'] LOOP
 EXECUTE format('CREATE POLICY scoped_read ON ap_m1.%I FOR SELECT TO ap_m1_api USING(ap_m1.has_child_scope_v2(child_id,''VIEW_ALERTS'') AND ap_m1.has_consent(child_id,''CORE'') AND NOT ap_m1.child_deleted(child_id))',t);
 END LOOP;
END $$;
CREATE POLICY preferences_read ON ap_m1.place_notification_rules FOR SELECT TO ap_m1_api USING(adult_id=ap_m1.ctx_principal() AND ap_m1.has_child_scope_v2(child_id,'VIEW_ALERTS') AND ap_m1.has_consent(child_id,'LOCATION'));
CREATE POLICY deliveries_read ON ap_m1.notification_deliveries FOR SELECT TO ap_m1_api USING(recipient_id=ap_m1.ctx_principal() AND ap_m1.has_child_scope_v2(child_id,'VIEW_ALERTS') AND NOT ap_m1.child_deleted(child_id));
CREATE POLICY read_receipts_read ON ap_m1.parent_notification_read_receipts FOR SELECT TO ap_m1_api USING(adult_id=ap_m1.ctx_principal() AND ap_m1.has_child_scope_v2(child_id,'VIEW_ALERTS') AND NOT ap_m1.child_deleted(child_id));
CREATE POLICY usage_read ON ap_m1.app_usage_intervals FOR SELECT TO ap_m1_api USING(ap_m1.has_child_scope_v2(child_id,'VIEW_USAGE') AND ap_m1.has_consent(child_id,'USAGE') AND NOT ap_m1.child_deleted(child_id));
GRANT SELECT ON ap_m1.place_notification_rules,ap_m1.child_signals,ap_m1.alert_events,ap_m1.notification_deliveries,ap_m1.signal_acknowledgements,ap_m1.parent_notification_read_receipts,ap_m1.app_usage_intervals TO ap_m1_api;
GRANT SELECT,INSERT ON ap_m1.child_signals,ap_m1.alert_events,ap_m1.alert_delivery_outbox,ap_m1.signal_acknowledgements,ap_m1.parent_notification_read_receipts,ap_m1.app_usage_intervals TO ap_db_executor;
GRANT SELECT,INSERT,UPDATE ON ap_m1.place_notification_rules TO ap_db_executor;
GRANT SELECT ON ap_m1.notification_deliveries TO ap_db_executor;
DO $$ DECLARE f regprocedure; BEGIN
 FOREACH f IN ARRAY ARRAY[
 'ap_m1.set_place_notification_rule(uuid,uuid,bigint,boolean,boolean)'::regprocedure,
 'ap_m1.record_child_signal(uuid,uuid,text,timestamptz)'::regprocedure,
 'ap_m1.acknowledge_child_signal(uuid,uuid)'::regprocedure,
 'ap_m1.mark_notification_read(uuid,uuid)'::regprocedure,
 'ap_m1.record_usage_interval(uuid,uuid,text,timestamptz,timestamptz,bigint,text)'::regprocedure] LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC',f);
 EXECUTE format('ALTER FUNCTION %s OWNER TO ap_db_executor',f);
 EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO ap_m1_api',f);
 END LOOP;
END $$;
