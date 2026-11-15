-- E-03: honest ingestion receipts and stable duplicate/conflict error codes.
--
-- The published ingest path already deduplicates by (device_id,event_id) with a
-- payload digest, rejects conflicting replays and refuses a reused sequence. What
-- it could not tell a client was *what happened*: the HTTP receipt hard-coded
-- duplicate_count=0 and accepted_count=len(events), and every replay conflict
-- arrived as a generic 23505 "conflicting active record". This migration adds an
-- additive receipt wrapper and translates the three distinct replay failures into
-- their own SQLSTATEs. No published function is modified.
--
-- Custom SQLSTATE classes: MAB01 batch replay conflict, MAB02 event replay
-- conflict, MAB03 sequence reused by a different event.
CREATE FUNCTION ap_m1.ingest_location_batch_receipt(p_device uuid, p_batch uuid, p_events jsonb)
RETURNS TABLE(ingest_batch_id uuid, accepted_count integer, duplicate_count integer, replayed boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE
  existed boolean;
  new_events integer := 0;
  total integer;
  result uuid;
  message_text text;
BEGIN
  IF p_events IS NULL OR jsonb_typeof(p_events) <> 'array' THEN
    RAISE EXCEPTION 'INVALID_BATCH_SIZE' USING ERRCODE = '22023';
  END IF;
  total := jsonb_array_length(p_events);
  IF total NOT BETWEEN 1 AND 500 OR octet_length(p_events::text)>524288 THEN
    RAISE EXCEPTION 'INVALID_BATCH_SIZE' USING ERRCODE = '22023';
  END IF;

  -- Authenticate and serialize on the same device lock as the existing ingest
  -- BEFORE inspecting batches/dedup. Otherwise concurrent replays report new
  -- acceptance even though only one underlying ingestion inserts a row.
  PERFORM ap_m1.require_domain_device(p_device, 'LOCATION');

  SELECT EXISTS (
    SELECT 1 FROM ap_m1.location_ingest_batches WHERE id = p_batch AND device_id = p_device
  ) INTO existed;

  IF NOT existed THEN
    -- Count unique new identities, not array occurrences. Every additional
    -- occurrence (including an identical repeat in this batch) is a duplicate.
    SELECT count(*)::integer INTO new_events
    FROM (SELECT DISTINCT (e->>'event_id')::uuid AS event_id
          FROM jsonb_array_elements(p_events) e) incoming
    WHERE NOT EXISTS (SELECT 1 FROM ap_m1.location_event_dedup d
                      WHERE d.device_id=p_device AND d.event_id=incoming.event_id);
  END IF;

  BEGIN
    result := ap_m1.ingest_location_batch(p_device, p_batch, p_events);
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS message_text = MESSAGE_TEXT;
    IF message_text LIKE 'BATCH_REPLAY_CONFLICT%' THEN
      RAISE EXCEPTION 'BATCH_REPLAY_CONFLICT' USING ERRCODE = 'MAB01';
    ELSIF message_text LIKE 'EVENT_REPLAY_CONFLICT%' THEN
      RAISE EXCEPTION 'EVENT_REPLAY_CONFLICT' USING ERRCODE = 'MAB02';
    ELSIF message_text LIKE '%device_id_sequence_key%' THEN
      RAISE EXCEPTION 'SEQUENCE_REUSED' USING ERRCODE = 'MAB03';
    ELSE
      RAISE;
    END IF;
  END;

  ingest_batch_id := result;
  replayed := existed;
  IF existed THEN
    accepted_count := 0;
    duplicate_count := total;
  ELSE
    accepted_count := new_events;
    duplicate_count := total - new_events;
  END IF;
  RETURN NEXT;
END $fn$;

ALTER FUNCTION ap_m1.ingest_location_batch_receipt(uuid,uuid,jsonb) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.ingest_location_batch_receipt(uuid,uuid,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.ingest_location_batch_receipt(uuid,uuid,jsonb) TO ap_m1_api;

-- Ingestion observability: per-device queue depth and duplicate pressure without
-- exposing coordinates or payloads.
CREATE VIEW ap_m1.ingestion_health WITH (security_invoker = true) AS
  SELECT b.child_id,
         b.device_id,
         count(*)                                             AS batches,
         count(*) FILTER (WHERE NOT b.membership_complete)     AS incomplete_memberships,
         count(o.id) FILTER (WHERE o.state = 'PENDING')        AS pending_jobs,
         count(o.id) FILTER (WHERE o.state = 'FAILED')         AS failed_jobs,
         max(b.accepted_at)                                    AS last_batch_at
  FROM ap_m1.location_ingest_batches b
  LEFT JOIN ap_m1.ingestion_outbox o ON o.batch_id = b.id
  GROUP BY b.child_id, b.device_id;

-- View inherits the batch table's protections only if it is not owned by a
-- bypassing role; restrict it to the executor and the owner explicitly.
REVOKE ALL ON ap_m1.ingestion_health FROM PUBLIC;
GRANT SELECT ON ap_m1.ingestion_health TO ap_db_executor;
