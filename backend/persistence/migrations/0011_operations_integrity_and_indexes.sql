-- Shared operational metadata. No raw GPS, media, credentials or purchase tokens.
-- Worker SQL is privileged by narrowly granted functions, not BYPASSRLS logins.
CREATE TABLE ap_m1.durable_event_inbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), source text NOT NULL CHECK(length(source) BETWEEN 1 AND 80),
 external_id_sha256 bytea NOT NULL CHECK(octet_length(external_id_sha256)=32),
 event_type text NOT NULL CHECK(length(event_type) BETWEEN 1 AND 80),
 resource_id uuid, state text NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','PROCESSING','DONE','FAILED','SUPPRESSED')),
 received_at timestamptz NOT NULL DEFAULT now(), processed_at timestamptz, attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0),
 UNIQUE(source,external_id_sha256)
);
CREATE TABLE ap_m1.processing_outbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), topic text NOT NULL CHECK(length(topic) BETWEEN 1 AND 80),
 resource_id uuid NOT NULL, event_revision bigint NOT NULL DEFAULT 1 CHECK(event_revision>0),
 state text NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','LEASED','DONE','FAILED','SUPPRESSED')),
 created_at timestamptz NOT NULL DEFAULT now(), available_at timestamptz NOT NULL DEFAULT now(),
 lease_owner uuid, lease_until timestamptz, fence bigint NOT NULL DEFAULT 0 CHECK(fence>=0),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0), last_error_code text CHECK(length(last_error_code)<=80),
 UNIQUE(topic,resource_id,event_revision), CHECK((state='LEASED')=(lease_owner IS NOT NULL AND lease_until IS NOT NULL))
);
CREATE INDEX processing_outbox_ready_idx ON ap_m1.processing_outbox(available_at,created_at,id) WHERE state IN ('PENDING','LEASED');
CREATE TABLE ap_m1.idempotency_claims (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 namespace text NOT NULL CHECK(length(namespace) BETWEEN 1 AND 100), key_sha256 bytea NOT NULL CHECK(octet_length(key_sha256)=32),
 request_sha256 bytea NOT NULL CHECK(octet_length(request_sha256)=32), resource_id uuid,
 state text NOT NULL DEFAULT 'CLAIMED' CHECK(state IN ('CLAIMED','COMPLETED','FAILED')),
 created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL DEFAULT now()+interval '24 hours',
 UNIQUE(actor_id,namespace,key_sha256), CHECK(expires_at>created_at)
);
CREATE TABLE ap_m1.worker_lease_fences (
 queue text PRIMARY KEY CHECK(length(queue) BETWEEN 1 AND 80), worker_id uuid NOT NULL,
 generation bigint NOT NULL DEFAULT 1 CHECK(generation>0), expires_at timestamptz NOT NULL,
 updated_at timestamptz NOT NULL DEFAULT now(), CHECK(expires_at>updated_at)
);
CREATE TABLE ap_m1.feature_release_gates (
 feature text PRIMARY KEY CHECK(length(feature) BETWEEN 1 AND 100),
 state text NOT NULL DEFAULT 'DISABLED' CHECK(state IN ('DISABLED','LOCAL_SYNTHETIC','APPROVED')),
 approval_reference_sha256 bytea CHECK(octet_length(approval_reference_sha256)=32),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(state<>'APPROVED' OR approval_reference_sha256 IS NOT NULL)
);
INSERT INTO ap_m1.feature_release_gates(feature) VALUES('real_child_location'),('real_child_usage'),('real_media_capture'),('live_google_play_verification');
CREATE TABLE ap_m1.external_service_accounts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), provider text NOT NULL CHECK(length(provider) BETWEEN 1 AND 80),
 environment text NOT NULL CHECK(environment IN ('LOCAL','SANDBOX','PRODUCTION')),
 secret_manager_reference text NOT NULL CHECK(length(secret_manager_reference) BETWEEN 1 AND 255),
 enabled boolean NOT NULL DEFAULT false, verified_at timestamptz, updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(provider,environment), CHECK(NOT enabled OR verified_at IS NOT NULL)
);
CREATE TABLE ap_m1.security_audit_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_id uuid REFERENCES ap_m1.parent_principals(id),
 action text NOT NULL CHECK(length(action) BETWEEN 1 AND 80), result_code text NOT NULL CHECK(length(result_code) BETWEEN 1 AND 80),
 resource_digest bytea CHECK(octet_length(resource_digest)=32), occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX security_audit_time_idx ON ap_m1.security_audit_events(occurred_at,id);
CREATE TABLE ap_m1.telemetry_aggregates (
 bucket_start timestamptz NOT NULL, service text NOT NULL CHECK(length(service) BETWEEN 1 AND 80),
 outcome text NOT NULL CHECK(length(outcome) BETWEEN 1 AND 80), event_count bigint NOT NULL DEFAULT 0 CHECK(event_count>=0),
 duration_ms bigint NOT NULL DEFAULT 0 CHECK(duration_ms>=0), updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(bucket_start,service,outcome)
);
CREATE TABLE ap_m1.cost_usage_snapshots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), period_start timestamptz NOT NULL, period_end timestamptz NOT NULL,
 service text NOT NULL CHECK(length(service) BETWEEN 1 AND 80), unit text NOT NULL CHECK(length(unit) BETWEEN 1 AND 40),
 quantity numeric(20,6) NOT NULL CHECK(quantity>=0), estimated_cost_minor bigint CHECK(estimated_cost_minor>=0),
 currency text NOT NULL DEFAULT 'INR' CHECK(currency ~ '^[A-Z]{3}$'), created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(period_start,period_end,service,unit), CHECK(period_end>period_start)
);
CREATE TABLE ap_m1.architecture_decisions (
 decision_key text PRIMARY KEY CHECK(length(decision_key) BETWEEN 1 AND 100),
 source_path text NOT NULL CHECK(length(source_path) BETWEEN 1 AND 512), source_sha256 bytea NOT NULL CHECK(octet_length(source_sha256)=32),
 state text NOT NULL CHECK(state IN ('PROPOSED','ACCEPTED','SUPERSEDED')), recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE ap_m1.service_incidents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), service text NOT NULL CHECK(length(service) BETWEEN 1 AND 80),
 reason_code text NOT NULL CHECK(length(reason_code) BETWEEN 1 AND 80),
 state text NOT NULL DEFAULT 'OPEN' CHECK(state IN ('OPEN','INVESTIGATING','RESOLVED')),
 started_at timestamptz NOT NULL DEFAULT now(), resolved_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), CHECK(resolved_at IS NULL OR resolved_at>=started_at)
);

CREATE FUNCTION ap_m1.claim_outbox(p_worker uuid,p_limit integer DEFAULT 10)
 RETURNS TABLE(event_id uuid,event_topic text,event_resource uuid,lease_fence bigint)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $fn$
BEGIN
 IF p_worker IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'invalid worker claim' USING ERRCODE='22023'; END IF;
 RETURN QUERY WITH candidates AS (
   SELECT id FROM ap_m1.processing_outbox WHERE available_at<=clock_timestamp()
    AND (state='PENDING' OR (state='LEASED' AND lease_until<clock_timestamp()))
   ORDER BY available_at,created_at,id FOR UPDATE SKIP LOCKED LIMIT p_limit
 ), claimed AS (
   UPDATE ap_m1.processing_outbox o SET state='LEASED',lease_owner=p_worker,
    lease_until=clock_timestamp()+interval '30 seconds',fence=fence+1,attempts=attempts+1
   FROM candidates c WHERE o.id=c.id RETURNING o.id,o.topic,o.resource_id,o.fence
 ) SELECT * FROM claimed;
END $fn$;
ALTER FUNCTION ap_m1.claim_outbox(uuid,integer) OWNER TO ap_db_executor;
CREATE FUNCTION ap_m1.complete_outbox(p_event uuid,p_worker uuid,p_fence bigint)
 RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $fn$
DECLARE n integer;
BEGIN
 UPDATE ap_m1.processing_outbox SET state='DONE',lease_owner=NULL,lease_until=NULL
 WHERE id=p_event AND state='LEASED' AND lease_owner=p_worker AND fence=p_fence AND lease_until>clock_timestamp();
 GET DIAGNOSTICS n=ROW_COUNT; RETURN n=1;
END $fn$;
ALTER FUNCTION ap_m1.complete_outbox(uuid,uuid,bigint) OWNER TO ap_db_executor;
CREATE FUNCTION ap_m1.claim_idempotency(p_namespace text,p_key text,p_request_hash bytea)
 RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
DECLARE existing ap_m1.idempotency_claims; actor uuid:=ap_m1.ctx_principal(); result_id uuid;
BEGIN
 IF actor IS NULL OR p_key IS NULL OR length(p_key) NOT BETWEEN 1 AND 200 OR octet_length(p_request_hash)<>32
 THEN RAISE EXCEPTION 'invalid authenticated idempotency claim' USING ERRCODE='22023'; END IF;
 INSERT INTO ap_m1.idempotency_claims(actor_id,namespace,key_sha256,request_sha256)
 VALUES(actor,p_namespace,public.digest(p_key,'sha256'),p_request_hash) ON CONFLICT DO NOTHING RETURNING id INTO result_id;
 IF result_id IS NOT NULL THEN RETURN result_id; END IF;
 SELECT * INTO STRICT existing FROM ap_m1.idempotency_claims WHERE actor_id=actor AND namespace=p_namespace AND key_sha256=public.digest(p_key,'sha256') FOR UPDATE;
 IF existing.request_sha256<>p_request_hash THEN RAISE EXCEPTION 'idempotency request conflict' USING ERRCODE='23505'; END IF;
 -- Expired claims are retained until an approved retention policy purges them;
 -- expiration never permits a payment or destructive request to be replayed.
 RETURN existing.id;
END $fn$;
ALTER FUNCTION ap_m1.claim_idempotency(text,text,bytea) OWNER TO ap_db_executor;

DO $rls$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['durable_event_inbox','processing_outbox','idempotency_claims','worker_lease_fences','feature_release_gates',
 'external_service_accounts','security_audit_events','telemetry_aggregates','cost_usage_snapshots','architecture_decisions','service_incidents'] LOOP
  EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE ap_m1.%I OWNER TO ap_m1_owner',t);
 END LOOP;
END $rls$;
CREATE POLICY idempotency_actor_read ON ap_m1.idempotency_claims FOR SELECT TO ap_m1_api USING(actor_id=ap_m1.ctx_principal());
GRANT SELECT ON ap_m1.idempotency_claims TO ap_m1_api;
GRANT SELECT,INSERT,UPDATE ON ap_m1.idempotency_claims,ap_m1.processing_outbox TO ap_db_executor;
GRANT USAGE ON SCHEMA ap_m1 TO ap_service_worker;
GRANT EXECUTE ON FUNCTION ap_m1.claim_outbox(uuid,integer),ap_m1.complete_outbox(uuid,uuid,bigint) TO ap_service_worker;
GRANT EXECUTE ON FUNCTION ap_m1.claim_idempotency(text,text,bytea) TO ap_m1_api;
-- Historical M1 granted PUBLIC execution implicitly; cut off every definer surface.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA ap_m1 FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA ap_m1 REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
