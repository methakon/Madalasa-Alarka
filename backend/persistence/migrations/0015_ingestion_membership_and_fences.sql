-- Persist exact accepted batch membership and fenced reconstruction work.
-- Historical hashes alone cannot reconstruct old batch membership: mark those
-- batches incomplete until the original authenticated payload is replayed.
ALTER TABLE ap_m1.location_ingest_batches ADD COLUMN membership_complete boolean NOT NULL DEFAULT false;
CREATE TABLE ap_m1.location_batch_items (
 child_id uuid NOT NULL, device_id uuid NOT NULL, batch_id uuid NOT NULL,
 item_no integer NOT NULL CHECK(item_no BETWEEN 1 AND 500), event_id uuid NOT NULL,
 decode_state text NOT NULL DEFAULT 'VALIDATED' CHECK(decode_state='VALIDATED'),
 PRIMARY KEY(batch_id,item_no),
 FOREIGN KEY(child_id,device_id,batch_id) REFERENCES ap_m1.location_ingest_batches(child_id,device_id,id) ON DELETE CASCADE,
 FOREIGN KEY(child_id,device_id,event_id) REFERENCES ap_m1.location_event_dedup(child_id,device_id,event_id)
);
CREATE INDEX batch_items_event_idx ON ap_m1.location_batch_items(child_id,device_id,event_id);
ALTER TABLE ap_m1.location_batch_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.location_batch_items FORCE ROW LEVEL SECURITY;
GRANT SELECT,INSERT,DELETE ON ap_m1.location_batch_items TO ap_db_executor;
GRANT UPDATE ON ap_m1.location_ingest_batches,ap_m1.ingestion_outbox TO ap_db_executor;
-- Preserve the tested atomic parser/ingester, but remove its direct runtime
-- entry point so callers cannot bypass the new receipt-membership transaction.
ALTER FUNCTION ap_m1.ingest_location_batch(uuid,uuid,jsonb) RENAME TO _ingest_location_rows;
REVOKE ALL ON FUNCTION ap_m1._ingest_location_rows(uuid,uuid,jsonb) FROM PUBLIC,ap_m1_api;
CREATE FUNCTION ap_m1.ingest_location_batch(p_device uuid,p_batch uuid,p_events jsonb) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $fn$
DECLARE result_id uuid; child uuid;
BEGIN
 result_id:=ap_m1._ingest_location_rows(p_device,p_batch,p_events);
 SELECT child_id INTO STRICT child FROM ap_m1.location_ingest_batches WHERE id=result_id AND device_id=p_device;
 INSERT INTO ap_m1.location_batch_items(child_id,device_id,batch_id,item_no,event_id)
 SELECT child,p_device,result_id,ordinality::integer,(value->>'event_id')::uuid
 FROM jsonb_array_elements(p_events) WITH ORDINALITY ON CONFLICT(batch_id,item_no) DO NOTHING;
 IF (SELECT count(*) FROM ap_m1.location_batch_items WHERE batch_id=result_id)<>jsonb_array_length(p_events)
 THEN RAISE EXCEPTION 'batch membership conflict' USING ERRCODE='23505'; END IF;
 UPDATE ap_m1.location_ingest_batches SET membership_complete=true WHERE id=result_id;
 UPDATE ap_m1.ingestion_outbox SET affected_start=q.first_at,affected_end=q.last_at
 FROM (SELECT min(o.observed_at) first_at,max(o.observed_at) last_at FROM ap_m1.location_batch_items i
       JOIN ap_m1.location_observations o USING(child_id,device_id,event_id) WHERE i.batch_id=result_id) q
 WHERE batch_id=result_id;
 RETURN result_id;
END $fn$;
-- These fields exist before the new wrapper is ever callable (one transaction).
ALTER TABLE ap_m1.ingestion_outbox
 ADD COLUMN lease_owner uuid, ADD COLUMN lease_until timestamptz,
 ADD COLUMN fence bigint NOT NULL DEFAULT 0 CHECK(fence>=0),
 ADD COLUMN affected_start timestamptz, ADD COLUMN affected_end timestamptz,
 ADD COLUMN last_error_code text CHECK(length(last_error_code)<=80),
 ADD CONSTRAINT ingestion_lease_pair CHECK((lease_owner IS NULL)=(lease_until IS NULL)),
 ADD CONSTRAINT ingestion_range_order CHECK(affected_start IS NULL OR affected_end>=affected_start);
ALTER FUNCTION ap_m1.ingest_location_batch(uuid,uuid,jsonb) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.ingest_location_batch(uuid,uuid,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.ingest_location_batch(uuid,uuid,jsonb) TO ap_m1_api;
CREATE FUNCTION ap_m1.claim_ingestion_jobs(worker uuid,batch_limit integer DEFAULT 10)
 RETURNS TABLE(job_id uuid,child_id uuid,device_id uuid,batch_id uuid,lease_fence bigint)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $fn$
BEGIN
 IF worker IS NULL OR batch_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'invalid job claim' USING ERRCODE='22023'; END IF;
 RETURN QUERY WITH candidates AS (
  SELECT o.id FROM ap_m1.ingestion_outbox o JOIN ap_m1.location_ingest_batches b ON b.id=o.batch_id
  WHERE o.state='PENDING' AND b.membership_complete
   AND (o.lease_until IS NULL OR o.lease_until<clock_timestamp())
  ORDER BY o.created_at,o.id FOR UPDATE OF o SKIP LOCKED LIMIT batch_limit
 ), claimed AS (
  UPDATE ap_m1.ingestion_outbox o SET lease_owner=worker,lease_until=clock_timestamp()+interval '30 seconds',
   fence=o.fence+1,attempts=o.attempts+1 FROM candidates c WHERE o.id=c.id
  RETURNING o.id,o.child_id,o.device_id,o.batch_id,o.fence
 ) SELECT * FROM claimed;
END $fn$;
CREATE FUNCTION ap_m1.complete_ingestion_job(job uuid,worker uuid,expected_fence bigint) RETURNS boolean
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $fn$
DECLARE changed integer;
BEGIN
 UPDATE ap_m1.ingestion_outbox SET state='PROCESSED',lease_owner=NULL,lease_until=NULL
 WHERE id=job AND state='PENDING' AND lease_owner=worker AND fence=expected_fence AND lease_until>clock_timestamp();
 GET DIAGNOSTICS changed=ROW_COUNT; RETURN changed=1;
END $fn$;
ALTER FUNCTION ap_m1.claim_ingestion_jobs(uuid,integer) OWNER TO ap_db_executor;
ALTER FUNCTION ap_m1.complete_ingestion_job(uuid,uuid,bigint) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.claim_ingestion_jobs(uuid,integer),ap_m1.complete_ingestion_job(uuid,uuid,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.claim_ingestion_jobs(uuid,integer),ap_m1.complete_ingestion_job(uuid,uuid,bigint) TO ap_service_worker;
GRANT INSERT ON ap_m1.erasure_store_inventory TO ap_db_executor;
SET LOCAL ROLE ap_db_executor;
INSERT INTO ap_m1.erasure_store_inventory(table_name,key_kind,purge_order) VALUES('location_batch_items','CHILD',225);
RESET ROLE;
REVOKE INSERT ON ap_m1.erasure_store_inventory FROM ap_db_executor;
