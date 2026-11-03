-- Free-first child capacity: 108 admitted distinct children, FIFO waitlist.
-- Additive release policy; existing billing/trial/media tables are retained.
-- Runner owns migration transaction. All uses are synthetic pending legal/Play signoff.
CREATE TABLE ap_m1.free_child_admissions (
 child_id uuid PRIMARY KEY REFERENCES ap_m1.children(id) ON DELETE CASCADE,
 family_id uuid NOT NULL,
 admission_state text NOT NULL CHECK(admission_state IN ('ADMITTED','WAITLISTED','RELEASED')),
 queued_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 admitted_at timestamptz,
 released_at timestamptz,
 FOREIGN KEY(family_id,child_id) REFERENCES ap_m1.children(family_id,id) ON DELETE CASCADE,
 CHECK ((admission_state='ADMITTED' AND admitted_at IS NOT NULL AND released_at IS NULL) OR
        (admission_state='WAITLISTED' AND admitted_at IS NULL AND released_at IS NULL) OR
        (admission_state='RELEASED' AND released_at IS NOT NULL))
);
CREATE INDEX free_child_waitlist_fifo
 ON ap_m1.free_child_admissions(queued_at,child_id) WHERE admission_state='WAITLISTED';
CREATE INDEX free_child_admitted_count
 ON ap_m1.free_child_admissions(child_id) WHERE admission_state='ADMITTED';
ALTER TABLE ap_m1.free_child_admissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.free_child_admissions FORCE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.free_child_admissions OWNER TO ap_m1_owner;
CREATE POLICY admission_worker_rw ON ap_m1.free_child_admissions
 FOR ALL TO ap_db_executor USING(true) WITH CHECK(true);
-- Active owner status requires verified principal, not URL family or login text.
CREATE FUNCTION ap_m1.free_child_family_owner(p_family uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
 SELECT EXISTS(
  SELECT 1 FROM ap_m1.guardian_memberships m JOIN ap_m1.families f ON f.id=m.family_id
  WHERE m.family_id=p_family AND m.principal_id=ap_m1.ctx_principal()
    AND m.membership_role='OWNER' AND m.revoked_at IS NULL AND f.state='ACTIVE')
$fn$;
ALTER FUNCTION ap_m1.free_child_family_owner(uuid) OWNER TO ap_m1_auth;
REVOKE ALL ON FUNCTION ap_m1.free_child_family_owner(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.free_child_family_owner(uuid) TO ap_m1_api,ap_db_executor;

CREATE POLICY admission_owner_read ON ap_m1.free_child_admissions
 FOR SELECT TO ap_m1_api
 USING(ap_m1.free_child_family_owner(family_id) OR ap_m1.has_child_scope_v2(child_id,'VIEW_CHILD_PROFILE'));
GRANT SELECT,INSERT,UPDATE ON ap_m1.free_child_admissions TO ap_db_executor;
GRANT SELECT ON ap_m1.free_child_admissions TO ap_m1_api;

-- Owners must be able to review a newly created queued profile before
-- consent/guardian-grant approval; other guardians retain per-child RLS.
CREATE POLICY free_queue_owner_child_profile ON ap_m1.children
 FOR SELECT TO ap_m1_api USING(ap_m1.free_child_family_owner(family_id));

-- Backfill preexisting synthetic child profiles deterministically.
-- Historical child state is never rewritten, and deleted children occupy no slot.
WITH candidates AS (
 SELECT c.id, row_number() OVER (ORDER BY c.created_at,c.id) AS position
 FROM ap_m1.children c
 WHERE c.state='ACTIVE' AND c.deleted_at IS NULL AND c.deletion_requested_at IS NULL
 AND NOT EXISTS (SELECT 1 FROM ap_m1.child_erasure_tombstones t WHERE t.child_id=c.id)
)
INSERT INTO ap_m1.free_child_admissions(child_id,family_id,admission_state,queued_at,admitted_at,released_at)
SELECT c.id,c.family_id,
 CASE WHEN r.position BETWEEN 1 AND 108 THEN 'ADMITTED'
      WHEN r.position IS NOT NULL THEN 'WAITLISTED' ELSE 'RELEASED' END,
 c.created_at,
 CASE WHEN r.position BETWEEN 1 AND 108 THEN clock_timestamp() ELSE NULL END,
 CASE WHEN r.position IS NULL THEN clock_timestamp() ELSE NULL END
FROM ap_m1.children c LEFT JOIN candidates r ON r.id=c.id;

-- No request parameter, client state, number of guardians or number of phones
-- can alter the global counted slot limit. Lock serializes concurrent signup.
CREATE FUNCTION ap_m1._admit_new_free_child() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
DECLARE n integer; admitted boolean;
BEGIN
 PERFORM pg_catalog.pg_advisory_xact_lock(108,20261103);
 SELECT count(*) INTO n FROM ap_m1.free_child_admissions WHERE admission_state='ADMITTED';
 admitted:=n<108 AND NEW.state='ACTIVE' AND NEW.deleted_at IS NULL AND NEW.deletion_requested_at IS NULL;
 INSERT INTO ap_m1.free_child_admissions(child_id,family_id,admission_state,admitted_at)
 VALUES(NEW.id,NEW.family_id,
        CASE WHEN admitted THEN 'ADMITTED' ELSE 'WAITLISTED' END,
        CASE WHEN admitted THEN clock_timestamp() ELSE NULL END);
 RETURN NEW;
END $fn$;
ALTER FUNCTION ap_m1._admit_new_free_child() OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1._admit_new_free_child() FROM PUBLIC;
CREATE TRIGGER assign_free_child_slot AFTER INSERT ON ap_m1.children
 FOR EACH ROW EXECUTE FUNCTION ap_m1._admit_new_free_child();

-- Queue advances only when deletion creates a durable tombstone, not when
-- a device goes offline or a payment lapses. A new child still needs all
-- independently verified authority, consent and device checks afterward.
CREATE FUNCTION ap_m1._release_and_promote_free_child() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
DECLARE available integer; next_child uuid;
BEGIN
 PERFORM pg_catalog.pg_advisory_xact_lock(108,20261103);
 UPDATE ap_m1.free_child_admissions
 SET admission_state='RELEASED',released_at=clock_timestamp()
 WHERE child_id=NEW.child_id AND admission_state<>'RELEASED';
 SELECT greatest(0,108-count(*)) INTO available
 FROM ap_m1.free_child_admissions WHERE admission_state='ADMITTED';
 WHILE available>0 LOOP
   SELECT q.child_id INTO next_child
   FROM ap_m1.free_child_admissions q
   JOIN ap_m1.children c ON c.id=q.child_id
   WHERE q.admission_state='WAITLISTED'
     AND c.state='ACTIVE' AND c.deleted_at IS NULL AND c.deletion_requested_at IS NULL
     AND NOT EXISTS(SELECT 1 FROM ap_m1.child_erasure_tombstones t WHERE t.child_id=c.id)
   ORDER BY q.queued_at,q.child_id LIMIT 1 FOR UPDATE OF q;
   EXIT WHEN next_child IS NULL;
   UPDATE ap_m1.free_child_admissions
   SET admission_state='ADMITTED',admitted_at=clock_timestamp()
   WHERE child_id=next_child AND admission_state='WAITLISTED';
   available:=available-1;
   next_child:=NULL;
 END LOOP;
 RETURN NEW;
END $fn$;
ALTER FUNCTION ap_m1._release_and_promote_free_child() OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1._release_and_promote_free_child() FROM PUBLIC;
CREATE TRIGGER release_and_promote_free_child AFTER INSERT ON ap_m1.child_erasure_tombstones
 FOR EACH ROW EXECUTE FUNCTION ap_m1._release_and_promote_free_child();

CREATE FUNCTION ap_m1.child_free_admitted(p_child uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
 SELECT EXISTS(SELECT 1 FROM ap_m1.free_child_admissions
  WHERE child_id=p_child AND admission_state='ADMITTED')
 AND NOT ap_m1.child_deleted(p_child)
$fn$;
ALTER FUNCTION ap_m1.child_free_admitted(uuid) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.child_free_admitted(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.child_free_admitted(uuid) TO ap_m1_api,ap_auth_issuer,ap_db_executor;

-- Parent-only status: no cross-family aliases or queue identities are exposed.
-- Queue number is FIFO rank over all WAITLISTED records.
CREATE FUNCTION ap_m1.free_child_admission_status(p_child uuid)
 RETURNS TABLE(service_state text,queue_position bigint,max_children integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
DECLARE v ap_m1.free_child_admissions%ROWTYPE;
BEGIN
 SELECT * INTO v FROM ap_m1.free_child_admissions WHERE child_id=p_child;
 IF NOT FOUND OR NOT (ap_m1.free_child_family_owner(v.family_id)
          OR ap_m1.has_child_scope_v2(p_child,'VIEW_CHILD_PROFILE')) THEN
   RETURN;
 END IF;
 service_state:=v.admission_state;
 max_children:=108;
 IF v.admission_state='WAITLISTED' THEN
   SELECT count(*) INTO queue_position
   FROM ap_m1.free_child_admissions q WHERE q.admission_state='WAITLISTED'
   AND (q.queued_at,q.child_id)<=(v.queued_at,v.child_id);
 ELSE
   queue_position:=NULL;
 END IF;
 RETURN NEXT;
END $fn$;
ALTER FUNCTION ap_m1.free_child_admission_status(uuid) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.free_child_admission_status(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.free_child_admission_status(uuid) TO ap_m1_api;

-- Gate service operations at the storage layer so alternate HTTP handlers
-- cannot bypass the 108-slot cap. Guardian signup, status, consent and
-- erasure requests are intentionally NOT blocked.
CREATE FUNCTION ap_m1._require_free_child_admission() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
BEGIN
 IF NOT ap_m1.child_free_admitted(NEW.child_id) THEN
   RAISE EXCEPTION 'FREE_SERVICE_WAITLISTED' USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END $fn$;
ALTER FUNCTION ap_m1._require_free_child_admission() OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1._require_free_child_admission() FROM PUBLIC;

CREATE TRIGGER free_admission_pairing_gate BEFORE INSERT ON ap_m1.pairing_codes
 FOR EACH ROW EXECUTE FUNCTION ap_m1._require_free_child_admission();
CREATE TRIGGER free_admission_device_gate BEFORE INSERT OR UPDATE OF enrollment_state ON ap_m1.devices
 FOR EACH ROW EXECUTE FUNCTION ap_m1._require_free_child_admission();
CREATE TRIGGER free_admission_ingest_gate BEFORE INSERT ON ap_m1.location_ingest_batches
 FOR EACH ROW EXECUTE FUNCTION ap_m1._require_free_child_admission();
CREATE TRIGGER free_admission_observation_gate BEFORE INSERT ON ap_m1.location_observations
 FOR EACH ROW EXECUTE FUNCTION ap_m1._require_free_child_admission();
CREATE TRIGGER free_admission_latest_gate BEFORE INSERT OR UPDATE ON ap_m1.device_latest_positions
 FOR EACH ROW EXECUTE FUNCTION ap_m1._require_free_child_admission();

-- Restrictive policies are ANDed with the existing exact-child guardian
-- consent and scope policies: no queued child's location/history leaks.
DO $pol$
DECLARE tab text;
BEGIN
 FOREACH tab IN ARRAY ARRAY['location_observations','device_latest_positions','trips',
   'trip_revisions','trip_routepoints','named_places'] LOOP
 EXECUTE format('CREATE POLICY free_admission_read_gate ON ap_m1.%I AS RESTRICTIVE '
    'FOR SELECT TO ap_m1_api USING (ap_m1.child_free_admitted(child_id))',tab);
 END LOOP;
END $pol$;
