-- Synthetic-local physical location slice. Runner owns transaction.
-- Intake processes raw rows synchronously, atomically with durable inbox and outbox.
-- A returned receipt is NOT a commit: HTTP must acknowledge only AFTER outer COMMIT.
ALTER TABLE ap_m1.devices ADD CONSTRAINT devices_child_id_id_key UNIQUE(child_id,id);

-- Separate physical retention/collection authorization from six-hour UI visibility.
-- No default policy: collection is disabled until an authorized policy is installed.
CREATE TABLE ap_m1.location_collection_policies (
 child_id uuid PRIMARY KEY REFERENCES ap_m1.children(id),
 enabled boolean NOT NULL DEFAULT false,
 retain_for interval NOT NULL CHECK(retain_for > interval '0' AND retain_for <= interval '365 days'),
 max_upload_age interval NOT NULL DEFAULT interval '48 hours'
  CHECK(max_upload_age > interval '0' AND max_upload_age <= interval '48 hours'),
 policy_reference text NOT NULL CHECK(length(policy_reference) BETWEEN 1 AND 200),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE ap_m1.location_ingest_batches (
 id uuid PRIMARY KEY,
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 device_id uuid NOT NULL,
 payload_digest bytea NOT NULL CHECK(octet_length(payload_digest)=32),
 item_count integer NOT NULL CHECK(item_count BETWEEN 1 AND 500),
 accepted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 state text NOT NULL CHECK(state IN ('PROCESSED')),
 FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id),
 UNIQUE(child_id,device_id,id)
);
CREATE TABLE ap_m1.location_event_dedup (
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 device_id uuid NOT NULL,
 sequence bigint NOT NULL CHECK(sequence>0),
 event_id uuid NOT NULL,
 payload_digest bytea NOT NULL CHECK(octet_length(payload_digest)=32),
 first_seen_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(device_id,event_id),
 UNIQUE(device_id,sequence),
 UNIQUE(child_id,device_id,event_id),
 FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id)
);
CREATE TABLE ap_m1.location_observations (
 child_id uuid NOT NULL,
 device_id uuid NOT NULL,
 event_id uuid NOT NULL,
 sequence bigint NOT NULL CHECK(sequence>0),
 observed_at timestamptz NOT NULL CHECK(isfinite(observed_at)),
 received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 latitude double precision NOT NULL CHECK(latitude BETWEEN -90 AND 90),
 longitude double precision NOT NULL CHECK(longitude BETWEEN -180 AND 180),
 position public.geography(Point,4326) NOT NULL,
 accuracy_m double precision NOT NULL CHECK(accuracy_m BETWEEN 0 AND 100000),
 speed_mps double precision CHECK(speed_mps BETWEEN 0 AND 1000),
 provider text NOT NULL CHECK(length(provider) BETWEEN 1 AND 64),
 quality text NOT NULL CHECK(quality IN ('QUALIFIED','COARSE')),
 PRIMARY KEY(device_id,event_id),
 UNIQUE(child_id,device_id,event_id),
 FOREIGN KEY(child_id,device_id,event_id) REFERENCES ap_m1.location_event_dedup(child_id,device_id,event_id),
 CHECK(observed_at<=received_at)
);
CREATE INDEX location_child_time_idx ON ap_m1.location_observations(child_id,observed_at DESC,event_id);
CREATE INDEX location_device_time_idx ON ap_m1.location_observations(device_id,observed_at DESC);
CREATE INDEX location_position_gist ON ap_m1.location_observations USING gist(position);
CREATE TABLE ap_m1.device_latest_positions (
 device_id uuid PRIMARY KEY,
 child_id uuid NOT NULL,
 event_id uuid NOT NULL,
 observed_at timestamptz NOT NULL,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(child_id,device_id,event_id) REFERENCES ap_m1.location_observations(child_id,device_id,event_id) ON DELETE CASCADE
);
CREATE TABLE ap_m1.ingestion_outbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL,
 device_id uuid NOT NULL,
 batch_id uuid NOT NULL,
 kind text NOT NULL DEFAULT 'RECONSTRUCT_TRIPS' CHECK(kind='RECONSTRUCT_TRIPS'),
 state text NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','PROCESSED','FAILED')),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(child_id,device_id,batch_id) REFERENCES ap_m1.location_ingest_batches(child_id,device_id,id) ON DELETE CASCADE,
 UNIQUE(batch_id,kind)
);
CREATE INDEX ingestion_pending_idx ON ap_m1.ingestion_outbox(created_at) WHERE state='PENDING';

-- Shared, constrained device authentication; UUID GUCs never authorize writes.
CREATE FUNCTION ap_m1.require_domain_device(p_device uuid,p_purpose text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE c uuid;
BEGIN
 SELECT child_id INTO c FROM ap_m1.devices WHERE id=p_device FOR NO KEY UPDATE;
 IF c IS NULL OR ap_m1.owns_active_device(p_device) IS NOT TRUE THEN
  RAISE EXCEPTION 'DEVICE_DENIED' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.children WHERE id=c AND state='ACTIVE' FOR SHARE;
 IF NOT FOUND OR ap_m1.child_deleted(c) THEN
  RAISE EXCEPTION 'CHILD_DENIED' USING ERRCODE='42501'; END IF;
 -- Serialize against consent withdrawal and authority changes for this transaction.
 PERFORM 1 FROM ap_m1.consent_records WHERE child_id=c FOR SHARE;
 IF NOT ap_m1.has_consent(c,'CORE') OR NOT ap_m1.has_consent(c,p_purpose) THEN
  RAISE EXCEPTION 'CONSENT_REQUIRED' USING ERRCODE='42501'; END IF;
 RETURN c;
END $$;
REVOKE ALL ON FUNCTION ap_m1.require_domain_device(uuid,text) FROM PUBLIC;
ALTER FUNCTION ap_m1.require_domain_device(uuid,text) OWNER TO ap_db_executor;
GRANT SELECT,UPDATE ON ap_m1.devices TO ap_db_executor;
GRANT SELECT ON ap_m1.children,ap_m1.consent_records TO ap_db_executor;
-- Row-lock clauses require UPDATE permission; no callable generic updater exists.
GRANT UPDATE ON ap_m1.children,ap_m1.consent_records TO ap_db_executor;
GRANT USAGE ON SCHEMA ap_m1,public TO ap_db_executor;
GRANT EXECUTE ON FUNCTION ap_m1.ctx_device(),ap_m1.ctx_principal(),ap_m1.owns_active_device(uuid),ap_m1.child_deleted(uuid),ap_m1.has_consent(uuid,text),ap_m1.has_child_scope_v2(uuid,text),ap_m1.has_paid_access(uuid) TO ap_db_executor;

-- The client-instance UUID accepted by acquire_viewer_lease is NOT an identity.
-- Resolve the opaque bearer to the server-owned session row, with all the existing
-- _session()/ctx_principal() verification and family/device revocation checks.
CREATE FUNCTION ap_m1._trusted_viewer_session() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 SELECT s.id FROM ap_m1.trusted_sessions s
 WHERE s.token_sha256=public.digest(nullif(current_setting('ap.session_token',true),''),'sha256')
 AND s.principal_id=ap_m1.ctx_principal()
 AND s.revoked_at IS NULL AND s.expires_at>statement_timestamp()
$$;
REVOKE ALL ON FUNCTION ap_m1._trusted_viewer_session() FROM PUBLIC;
ALTER FUNCTION ap_m1._trusted_viewer_session() OWNER TO ap_db_executor;
GRANT SELECT ON ap_m1.trusted_sessions TO ap_db_executor;

-- Late-bound: 0009 defines media leases/capacity after this migration. No paid
-- history is available until that schema AND its trusted-session binding exist.
-- Count all live premium screens against the one shared child-specific capacity;
-- surplus leases lose access immediately on addon expiry/refund, without waiting
-- for heartbeat or relying on the client to call a release endpoint.
CREATE FUNCTION ap_m1._has_premium_history_lease(c uuid) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE session_id uuid;
BEGIN
 session_id:=ap_m1._trusted_viewer_session();
 IF session_id IS NULL OR NOT ap_m1.has_paid_access(c)
 OR NOT ap_m1.has_child_scope_v2(c,'VIEW_HISTORY') THEN RETURN false; END IF;
 RETURN EXISTS (
  SELECT 1 FROM (
   SELECT l.adult_id,l.trusted_session_id,l.screen_kind,
    row_number() OVER (ORDER BY l.created_at,l.id) AS slot
   FROM ap_m1.premium_viewer_leases l
   JOIN ap_m1.trusted_sessions s ON s.id=l.trusted_session_id AND s.principal_id=l.adult_id
   WHERE l.child_id=c AND l.revoked_at IS NULL AND l.expires_at>statement_timestamp()
   AND s.revoked_at IS NULL AND s.expires_at>statement_timestamp()
   AND ap_m1._media_actor_live(c,l.adult_id,
    CASE WHEN l.screen_kind='PREMIUM_MAP' THEN 'VIEW_HISTORY' ELSE 'REQUEST_MEDIA' END)
   AND (l.screen_kind<>'AUTHORIZED_MEDIA' OR ap_m1.has_consent(c,'MEDIA'))
  ) live
  WHERE live.adult_id=ap_m1.ctx_principal() AND live.trusted_session_id=session_id
  AND live.screen_kind='PREMIUM_MAP' AND live.slot<=ap_m1.viewer_capacity(c)
 );
EXCEPTION WHEN undefined_table OR undefined_column OR undefined_function THEN
 RETURN false;
END $$;
REVOKE ALL ON FUNCTION ap_m1._has_premium_history_lease(uuid) FROM PUBLIC;
ALTER FUNCTION ap_m1._has_premium_history_lease(uuid) OWNER TO ap_db_executor;
GRANT EXECUTE ON FUNCTION ap_m1._has_premium_history_lease(uuid) TO ap_m1_api;

CREATE FUNCTION ap_m1.can_read_location_history(c uuid,t timestamptz) RETURNS boolean
LANGUAGE sql STABLE SET search_path=pg_catalog,ap_m1,public AS $$
 SELECT ap_m1.has_child_scope_v2(c,'VIEW_HISTORY') AND ap_m1.has_consent(c,'LOCATION')
 AND NOT ap_m1.child_deleted(c) AND isfinite(t) AND t<=statement_timestamp()
 AND CASE WHEN t>=statement_timestamp()-interval '6 hours' THEN true
          ELSE ap_m1._has_premium_history_lease(c) END
$$;
REVOKE ALL ON FUNCTION ap_m1.can_read_location_history(uuid,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.can_read_location_history(uuid,timestamptz) TO ap_m1_api,ap_db_executor;

CREATE FUNCTION ap_m1.ingest_location_batch(p_device uuid,p_batch uuid,p_events jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE c uuid; policy ap_m1.location_collection_policies; e jsonb; eid uuid; seq bigint;
 t timestamptz; lat double precision; lon double precision; acc double precision;
 speed double precision; provider_name text; h bytea; old_hash bytea; batch_hash bytea;
BEGIN
 c:=ap_m1.require_domain_device(p_device,'LOCATION');
 SELECT * INTO policy FROM ap_m1.location_collection_policies WHERE child_id=c FOR SHARE;
 IF NOT FOUND OR NOT policy.enabled THEN RAISE EXCEPTION 'COLLECTION_POLICY_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_batch IS NULL OR p_events IS NULL OR jsonb_typeof(p_events)<>'array' THEN
  RAISE EXCEPTION 'INVALID_BATCH' USING ERRCODE='22023'; END IF;
 IF jsonb_array_length(p_events) NOT BETWEEN 1 AND 500 OR octet_length(p_events::text)>524288 THEN
  RAISE EXCEPTION 'INVALID_BATCH_SIZE' USING ERRCODE='22023'; END IF;
 batch_hash:=public.digest(p_events::text,'sha256');
 SELECT payload_digest INTO old_hash FROM ap_m1.location_ingest_batches WHERE id=p_batch;
 IF FOUND THEN
  IF old_hash<>batch_hash OR NOT EXISTS(SELECT 1 FROM ap_m1.location_ingest_batches WHERE id=p_batch AND device_id=p_device AND child_id=c) THEN
   RAISE EXCEPTION 'BATCH_REPLAY_CONFLICT' USING ERRCODE='23505'; END IF;
  RETURN p_batch;
 END IF;
 INSERT INTO ap_m1.location_ingest_batches(id,child_id,device_id,payload_digest,item_count,state)
 VALUES(p_batch,c,p_device,batch_hash,jsonb_array_length(p_events),'PROCESSED');
 FOR e IN SELECT value FROM jsonb_array_elements(p_events) LOOP
  IF jsonb_typeof(e)<>'object' OR NOT(e ?& ARRAY['event_id','sequence','observed_at','latitude','longitude','accuracy_m'])
   OR (e ? 'source_device_id' AND (e->>'source_device_id')::uuid IS DISTINCT FROM p_device) THEN
   RAISE EXCEPTION 'INVALID_LOCATION_EVENT' USING ERRCODE='22023'; END IF;
  eid:=(e->>'event_id')::uuid; seq:=(e->>'sequence')::bigint;
  t:=(e->>'observed_at')::timestamptz; lat:=(e->>'latitude')::double precision;
  lon:=(e->>'longitude')::double precision; acc:=(e->>'accuracy_m')::double precision;
  speed:=(e->>'speed_mps')::double precision; provider_name:=coalesce(e->>'provider','UNKNOWN');
  IF eid IS NULL OR seq IS NULL OR seq<=0 OR t IS NULL OR NOT isfinite(t) OR t>clock_timestamp()
   OR t<clock_timestamp()-policy.max_upload_age OR t<clock_timestamp()-policy.retain_for
   OR lat IS NULL OR NOT(lat BETWEEN -90 AND 90) OR lon IS NULL OR NOT(lon BETWEEN -180 AND 180)
   OR acc IS NULL OR NOT(acc BETWEEN 0 AND 100000) OR (speed IS NOT NULL AND NOT(speed BETWEEN 0 AND 1000)) THEN
   RAISE EXCEPTION 'INVALID_GPS' USING ERRCODE='22023'; END IF;
  h:=public.digest(e::text,'sha256');
  SELECT payload_digest INTO old_hash FROM ap_m1.location_event_dedup WHERE device_id=p_device AND event_id=eid;
  IF FOUND THEN
   IF old_hash<>h THEN RAISE EXCEPTION 'EVENT_REPLAY_CONFLICT' USING ERRCODE='23505'; END IF;
   CONTINUE;
  END IF;
  -- Sequence is a persistent per-enrollment event identity, NOT arrival order.
  -- Late offline events may arrive out of order; reused sequence is forbidden.
  INSERT INTO ap_m1.location_event_dedup(child_id,device_id,sequence,event_id,payload_digest) VALUES(c,p_device,seq,eid,h);
  INSERT INTO ap_m1.location_observations(child_id,device_id,event_id,sequence,observed_at,latitude,longitude,position,accuracy_m,speed_mps,provider,quality)
   VALUES(c,p_device,eid,seq,t,lat,lon,public.ST_SetSRID(public.ST_MakePoint(lon,lat),4326)::public.geography,acc,speed,provider_name,CASE WHEN acc<=100 THEN 'QUALIFIED' ELSE 'COARSE' END);
  IF acc<=100 THEN
   INSERT INTO ap_m1.device_latest_positions(device_id,child_id,event_id,observed_at) VALUES(p_device,c,eid,t)
   ON CONFLICT(device_id) DO UPDATE SET event_id=EXCLUDED.event_id,observed_at=EXCLUDED.observed_at,updated_at=clock_timestamp()
   WHERE EXCLUDED.observed_at>ap_m1.device_latest_positions.observed_at;
  END IF;
 END LOOP;
 INSERT INTO ap_m1.ingestion_outbox(child_id,device_id,batch_id) VALUES(c,p_device,p_batch);
 RETURN p_batch;
END $$;
REVOKE ALL ON FUNCTION ap_m1.ingest_location_batch(uuid,uuid,jsonb) FROM PUBLIC;
ALTER FUNCTION ap_m1.ingest_location_batch(uuid,uuid,jsonb) OWNER TO ap_db_executor;
GRANT EXECUTE ON FUNCTION ap_m1.ingest_location_batch(uuid,uuid,jsonb) TO ap_m1_api;

-- SECURITY INVOKER deliberately preserves direct-table RLS on every page.
CREATE FUNCTION ap_m1.location_history(p_child uuid,p_from timestamptz,p_to timestamptz,p_limit integer DEFAULT 500)
RETURNS SETOF ap_m1.location_observations LANGUAGE plpgsql STABLE
SET search_path=pg_catalog,ap_m1,public AS $$
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR NOT isfinite(p_from) OR NOT isfinite(p_to)
 OR p_to<p_from OR p_to>statement_timestamp() OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN
  RAISE EXCEPTION 'INVALID_HISTORY_RANGE' USING ERRCODE='22023'; END IF;
 RETURN QUERY SELECT * FROM ap_m1.location_observations WHERE child_id=p_child
 AND observed_at>=p_from AND observed_at<=p_to ORDER BY observed_at,event_id LIMIT p_limit;
END $$;
REVOKE ALL ON FUNCTION ap_m1.location_history(uuid,timestamptz,timestamptz,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.location_history(uuid,timestamptz,timestamptz,integer) TO ap_m1_api;

CREATE TABLE ap_m1.trips (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 device_id uuid NOT NULL, first_observed_at timestamptz NOT NULL, last_observed_at timestamptz NOT NULL,
 current_revision integer NOT NULL CHECK(current_revision>0),
 state text NOT NULL CHECK(state IN ('PROVISIONAL','CONFIRMED','UPDATED','INCOMPLETE')),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(child_id,id), UNIQUE(child_id,device_id,id),
 FOREIGN KEY(child_id,device_id) REFERENCES ap_m1.devices(child_id,id),
 CHECK(isfinite(first_observed_at) AND isfinite(last_observed_at) AND last_observed_at>=first_observed_at)
);
CREATE INDEX trips_child_time_idx ON ap_m1.trips(child_id,first_observed_at DESC);
CREATE TABLE ap_m1.trip_revisions (
 child_id uuid NOT NULL, trip_id uuid NOT NULL, revision integer NOT NULL CHECK(revision>0),
 evidence_start timestamptz NOT NULL, evidence_end timestamptz NOT NULL,
 provisional boolean NOT NULL DEFAULT true, algorithm_version text NOT NULL CHECK(length(algorithm_version) BETWEEN 1 AND 100),
 reason text NOT NULL CHECK(length(reason) BETWEEN 1 AND 200), recomputed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(trip_id,revision), UNIQUE(child_id,trip_id,revision),
 FOREIGN KEY(child_id,trip_id) REFERENCES ap_m1.trips(child_id,id) ON DELETE CASCADE,
 CHECK(isfinite(evidence_start) AND isfinite(evidence_end) AND evidence_end>=evidence_start)
);
ALTER TABLE ap_m1.trips ADD CONSTRAINT trips_current_revision_fk FOREIGN KEY(child_id,id,current_revision)
 REFERENCES ap_m1.trip_revisions(child_id,trip_id,revision) DEFERRABLE INITIALLY DEFERRED;
CREATE TABLE ap_m1.trip_routepoints (
 child_id uuid NOT NULL, device_id uuid NOT NULL, trip_id uuid NOT NULL, revision integer NOT NULL,
 point_no integer NOT NULL CHECK(point_no>=0), observed_at timestamptz NOT NULL,
 point_kind text NOT NULL CHECK(point_kind IN ('OBSERVED','INFERRED','GAP')),
 position public.geography(Point,4326), source_event_id uuid,
 PRIMARY KEY(trip_id,revision,point_no),
 FOREIGN KEY(child_id,trip_id,revision) REFERENCES ap_m1.trip_revisions(child_id,trip_id,revision) ON DELETE CASCADE,
 FOREIGN KEY(child_id,device_id,trip_id) REFERENCES ap_m1.trips(child_id,device_id,id) ON DELETE CASCADE,
 FOREIGN KEY(child_id,device_id,source_event_id) REFERENCES ap_m1.location_observations(child_id,device_id,event_id) ON DELETE CASCADE,
 CHECK(isfinite(observed_at)),
 CHECK((point_kind='OBSERVED' AND source_event_id IS NOT NULL AND position IS NOT NULL)
 OR (point_kind='INFERRED' AND source_event_id IS NULL AND position IS NOT NULL)
 OR (point_kind='GAP' AND source_event_id IS NULL AND position IS NULL))
);
CREATE TABLE ap_m1.named_places (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 created_by uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 100),
 position public.geography(Point,4326) NOT NULL,
 radius_m integer NOT NULL CHECK(radius_m BETWEEN 50 AND 2000),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), archived_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(child_id,id)
);
CREATE INDEX named_places_spatial_idx ON ap_m1.named_places USING gist(position);
CREATE FUNCTION ap_m1.save_named_place(c uuid,p uuid,expected bigint,title_value text,lat double precision,lon double precision,radius integer) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
BEGIN
 IF NOT ap_m1.has_child_scope_v2(c,'MANAGE_TRIPS') OR NOT ap_m1.has_consent(c,'LOCATION') OR ap_m1.child_deleted(c) THEN
  RAISE EXCEPTION 'CHILD_SCOPE_DENIED' USING ERRCODE='42501'; END IF;
 IF lat IS NULL OR NOT(lat BETWEEN -90 AND 90) OR lon IS NULL OR NOT(lon BETWEEN -180 AND 180) THEN
  RAISE EXCEPTION 'INVALID_COORDINATES' USING ERRCODE='22023'; END IF;
 IF expected=0 THEN
  INSERT INTO ap_m1.named_places(id,child_id,created_by,title,position,radius_m)
  VALUES(p,c,ap_m1.ctx_principal(),title_value,public.ST_SetSRID(public.ST_MakePoint(lon,lat),4326)::public.geography,radius);
 ELSE
  UPDATE ap_m1.named_places SET title=title_value,position=public.ST_SetSRID(public.ST_MakePoint(lon,lat),4326)::public.geography,
   radius_m=radius,revision=revision+1,updated_at=clock_timestamp()
  WHERE id=p AND child_id=c AND revision=expected AND archived_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'REVISION_CONFLICT' USING ERRCODE='40001'; END IF;
 END IF;
 RETURN p;
END $$;
REVOKE ALL ON FUNCTION ap_m1.save_named_place(uuid,uuid,bigint,text,double precision,double precision,integer) FROM PUBLIC;
ALTER FUNCTION ap_m1.save_named_place(uuid,uuid,bigint,text,double precision,double precision,integer) OWNER TO ap_db_executor;
GRANT EXECUTE ON FUNCTION ap_m1.save_named_place(uuid,uuid,bigint,text,double precision,double precision,integer) TO ap_m1_api;

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['location_collection_policies','location_ingest_batches','location_event_dedup','location_observations','device_latest_positions','ingestion_outbox','trips','trip_revisions','trip_routepoints','named_places'] LOOP
 EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
 END LOOP;
END $$;
CREATE POLICY history_read ON ap_m1.location_observations FOR SELECT TO ap_m1_api USING(ap_m1.can_read_location_history(child_id,observed_at));
CREATE POLICY latest_read ON ap_m1.device_latest_positions FOR SELECT TO ap_m1_api USING(
 ap_m1.has_child_scope_v2(child_id,'VIEW_LOCATION') AND ap_m1.has_consent(child_id,'LOCATION') AND NOT ap_m1.child_deleted(child_id)
 AND observed_at BETWEEN statement_timestamp()-interval '6 hours' AND statement_timestamp());
CREATE POLICY trips_read ON ap_m1.trips FOR SELECT TO ap_m1_api USING(ap_m1.can_read_location_history(child_id,first_observed_at) AND last_observed_at<=statement_timestamp());
CREATE POLICY revisions_read ON ap_m1.trip_revisions FOR SELECT TO ap_m1_api USING(ap_m1.can_read_location_history(child_id,evidence_start) AND evidence_end<=statement_timestamp());
CREATE POLICY routepoints_read ON ap_m1.trip_routepoints FOR SELECT TO ap_m1_api USING(ap_m1.can_read_location_history(child_id,observed_at));
CREATE POLICY places_read ON ap_m1.named_places FOR SELECT TO ap_m1_api USING(ap_m1.has_child_scope_v2(child_id,'VIEW_LOCATION') AND ap_m1.has_consent(child_id,'LOCATION') AND NOT ap_m1.child_deleted(child_id));
GRANT SELECT ON ap_m1.location_observations,ap_m1.device_latest_positions,ap_m1.trips,ap_m1.trip_revisions,ap_m1.trip_routepoints,ap_m1.named_places TO ap_m1_api;
GRANT SELECT,INSERT ON ap_m1.location_ingest_batches,ap_m1.location_event_dedup,ap_m1.location_observations,ap_m1.ingestion_outbox TO ap_db_executor;
GRANT SELECT,INSERT,UPDATE ON ap_m1.device_latest_positions,ap_m1.named_places TO ap_db_executor;
GRANT SELECT,UPDATE ON ap_m1.location_collection_policies TO ap_db_executor;

-- Internal reconstruction operation. No runtime grant: a privileged worker may
-- publish only genuine source observations from one exact child/device.
CREATE FUNCTION ap_m1.publish_observed_trip(c uuid,d uuid,trip uuid,expected integer,event_ids uuid[],why text) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE n integer; first_at timestamptz; last_at timestamptz; v integer; point integer:=0;
 source ap_m1.location_observations; previous_time timestamptz;
BEGIN
 PERFORM 1 FROM ap_m1.devices WHERE id=d AND child_id=c AND enrollment_state='ACTIVE' AND revoked_at IS NULL FOR NO KEY UPDATE;
 IF NOT FOUND OR ap_m1.child_deleted(c) OR NOT ap_m1.has_consent(c,'LOCATION') THEN
 RAISE EXCEPTION 'RECONSTRUCTION_DENIED' USING ERRCODE='42501'; END IF;
 IF event_ids IS NULL OR cardinality(event_ids) NOT BETWEEN 2 AND 500 THEN
 RAISE EXCEPTION 'INVALID_EVIDENCE' USING ERRCODE='22023'; END IF;
 SELECT count(*),min(observed_at),max(observed_at) INTO n,first_at,last_at FROM ap_m1.location_observations
 WHERE child_id=c AND device_id=d AND event_id=ANY(event_ids) AND quality='QUALIFIED';
 IF n<>cardinality(event_ids) OR last_at>clock_timestamp() THEN RAISE EXCEPTION 'EVIDENCE_DENIED' USING ERRCODE='22023'; END IF;
 v:=expected+1;
 IF expected=0 THEN
 INSERT INTO ap_m1.trips(id,child_id,device_id,first_observed_at,last_observed_at,current_revision,state)
 VALUES(trip,c,d,first_at,last_at,v,'PROVISIONAL');
 ELSE
 UPDATE ap_m1.trips SET first_observed_at=first_at,last_observed_at=last_at,current_revision=v,state='UPDATED',updated_at=clock_timestamp()
 WHERE id=trip AND child_id=c AND device_id=d AND current_revision=expected;
 IF NOT FOUND THEN RAISE EXCEPTION 'TRIP_REVISION_CONFLICT' USING ERRCODE='40001'; END IF;
 END IF;
 INSERT INTO ap_m1.trip_revisions(child_id,trip_id,revision,evidence_start,evidence_end,algorithm_version,reason)
 VALUES(c,trip,v,first_at,last_at,'observed-only-v1',why);
 FOR source IN SELECT * FROM ap_m1.location_observations WHERE child_id=c AND device_id=d AND event_id=ANY(event_ids) ORDER BY observed_at,event_id LOOP
 IF previous_time IS NOT NULL AND source.observed_at-previous_time>interval '5 minutes' THEN
 INSERT INTO ap_m1.trip_routepoints(child_id,device_id,trip_id,revision,point_no,observed_at,point_kind)
 VALUES(c,d,trip,v,point,previous_time+interval '1 microsecond','GAP'); point:=point+1;
 END IF;
 INSERT INTO ap_m1.trip_routepoints(child_id,device_id,trip_id,revision,point_no,observed_at,point_kind,position,source_event_id)
 VALUES(c,d,trip,v,point,source.observed_at,'OBSERVED',source.position,source.event_id);
 point:=point+1; previous_time:=source.observed_at;
 END LOOP;
 RETURN v;
END $$;
REVOKE ALL ON FUNCTION ap_m1.publish_observed_trip(uuid,uuid,uuid,integer,uuid[],text) FROM PUBLIC;
ALTER FUNCTION ap_m1.publish_observed_trip(uuid,uuid,uuid,integer,uuid[],text) OWNER TO ap_db_executor;
GRANT SELECT,INSERT,UPDATE ON ap_m1.trips TO ap_db_executor;
GRANT SELECT,INSERT ON ap_m1.trip_revisions,ap_m1.trip_routepoints TO ap_db_executor;

CREATE FUNCTION ap_m1.archive_named_place(c uuid,p uuid,expected bigint) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
BEGIN
 IF NOT ap_m1.has_child_scope_v2(c,'MANAGE_TRIPS') OR NOT ap_m1.has_consent(c,'LOCATION') OR ap_m1.child_deleted(c) THEN
 RAISE EXCEPTION 'CHILD_SCOPE_DENIED' USING ERRCODE='42501'; END IF;
 UPDATE ap_m1.named_places SET archived_at=clock_timestamp(),revision=revision+1,updated_at=clock_timestamp()
 WHERE child_id=c AND id=p AND revision=expected AND archived_at IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'REVISION_CONFLICT' USING ERRCODE='40001'; END IF;
END $$;
REVOKE ALL ON FUNCTION ap_m1.archive_named_place(uuid,uuid,bigint) FROM PUBLIC;
ALTER FUNCTION ap_m1.archive_named_place(uuid,uuid,bigint) OWNER TO ap_db_executor;
GRANT EXECUTE ON FUNCTION ap_m1.archive_named_place(uuid,uuid,bigint) TO ap_m1_api;

-- Internal maintenance only. Six-hour visibility never drives physical deletion.
CREATE FUNCTION ap_m1.purge_expired_location(c uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE cutoff timestamptz; n bigint;
BEGIN
 SELECT clock_timestamp()-retain_for INTO cutoff FROM ap_m1.location_collection_policies WHERE child_id=c FOR SHARE;
 IF cutoff IS NULL THEN RAISE EXCEPTION 'RETENTION_POLICY_REQUIRED' USING ERRCODE='22023'; END IF;
 DELETE FROM ap_m1.trips WHERE child_id=c AND first_observed_at<cutoff;
 DELETE FROM ap_m1.location_observations WHERE child_id=c AND observed_at<cutoff;
 GET DIAGNOSTICS n=ROW_COUNT;
 DELETE FROM ap_m1.location_event_dedup d WHERE child_id=c AND first_seen_at<cutoff
 AND NOT EXISTS(SELECT 1 FROM ap_m1.location_observations o WHERE o.device_id=d.device_id AND o.event_id=d.event_id);
 DELETE FROM ap_m1.location_ingest_batches WHERE child_id=c AND accepted_at<cutoff;
 RETURN n;
END $$;
REVOKE ALL ON FUNCTION ap_m1.purge_expired_location(uuid) FROM PUBLIC;
ALTER FUNCTION ap_m1.purge_expired_location(uuid) OWNER TO ap_db_executor;
GRANT DELETE ON ap_m1.trips,ap_m1.location_observations,ap_m1.location_event_dedup,ap_m1.location_ingest_batches TO ap_db_executor;
