-- Madalasa-Alarka M1 migration v0004 -- idempotency keys for retryable creates.
-- PostgreSQL 15+. Apply after 0001..0003, as the migration admin (not the app role).
-- SYNTHETIC DATA ONLY.
--
-- Why: docs/API_CONVENTIONS_AND_ERROR_CATALOG.md section 6 requires an Idempotency-Key on createFamily,
-- createChild and issuePairingCode, so a retry after a lost response cannot create a duplicate.
-- This closes gap G-1 of that document.
--
-- DESIGN: claim, create and record happen in ONE database transaction.
--   BEGIN;
--   SET LOCAL lock_timeout = '5s';
--   outcome := idempotency_claim(actor, 'POST /families', sha256(key), sha256(canonical request body));
--     NEW      -> create the resource, then idempotency_record(actor, ns, key, 201, body), COMMIT.
--     REPLAY   -> return the stored status/body (or, if body_omitted, rebuild the response), ROLLBACK/COMMIT.
--     MISMATCH -> 409 IDEMPOTENCY_KEY_REUSED (same key, different request body).
--     PENDING  -> backend bug (a claim was committed without a result). Return 500 INTERNAL_ERROR and alert.
--   Any failure -> ROLLBACK: the claim disappears with the half-made resource, so the client may retry freely.
-- A concurrent duplicate blocks inside idempotency_claim until the first transaction ends, then sees its result
-- (REPLAY) or, if it rolled back, becomes the new owner. lock_timeout turns a long wait into 409 CONFLICT, retryable.
-- There is therefore no "in progress" state that a crash could leave stuck.
--
-- Differences from the logical ERD table idempotency_claims (docs/data-model): the primary key here includes the
-- ACTOR, so two callers can never collide on, or learn about, each other's keys; and the table stores the request
-- hash and the response so replays work. Reconcile the ERD when the physical catalog is written.
--
-- Secrets: only SHA-256 hashes of the key and request are stored. A response that contains a secret (the one-time
-- pairing code from issuePairingCode) MUST be stored with p_omit_body => true; on replay the backend rebuilds a
-- usable response instead of reading the secret back (open decision P-1 in docs/API_CONVENTIONS_AND_ERROR_CATALOG.md).
BEGIN;
SET LOCAL ROLE ap_m1_owner;

CREATE TABLE ap_m1.idempotency_keys (
 actor_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id) ON DELETE CASCADE,
 namespace text NOT NULL CHECK (namespace ~ '^(POST|PUT|PATCH|DELETE) /[A-Za-z0-9{}/_-]{1,90}$'),
 key_sha256 bytea NOT NULL CHECK (octet_length(key_sha256) = 32),
 request_sha256 bytea NOT NULL CHECK (octet_length(request_sha256) = 32),
 response_status integer CHECK (response_status BETWEEN 200 AND 299),
 response_body jsonb CHECK (response_body IS NULL OR octet_length(response_body::text) <= 8192),
 body_omitted boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz,
 expires_at timestamptz NOT NULL,
 PRIMARY KEY (actor_id, namespace, key_sha256),
 CHECK (expires_at > created_at),
 -- Hard ceiling regardless of backend configuration (API doc: keys are remembered for 24 hours).
 CHECK (expires_at <= created_at + interval '24 hours'),
 CHECK ((response_status IS NULL) = (completed_at IS NULL)),
 CHECK (NOT body_omitted OR response_body IS NULL)
);
CREATE INDEX idempotency_keys_expiry_idx ON ap_m1.idempotency_keys(expires_at);

ALTER TABLE ap_m1.idempotency_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.idempotency_keys FORCE ROW LEVEL SECURITY;

-- Claim a key. Must run in the same transaction as the create it protects (see header).
-- Returns exactly one row: outcome NEW | REPLAY | MISMATCH | PENDING.
CREATE FUNCTION ap_m1.idempotency_claim(
  p_actor uuid, p_namespace text, p_key_sha256 bytea, p_request_sha256 bytea,
  p_ttl_seconds integer DEFAULT 86400)
 RETURNS TABLE(outcome text, response_status integer, response_body jsonb, body_omitted boolean)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE r ap_m1.idempotency_keys%ROWTYPE; v_n integer;
BEGIN
 IF p_ttl_seconds IS NULL OR p_ttl_seconds NOT BETWEEN 60 AND 86400 THEN
  RAISE EXCEPTION 'idempotency ttl must be 60..86400 seconds' USING ERRCODE = '22023';
 END IF;
 -- An expired claim for this exact key is forgotten, so the key can be used again.
 DELETE FROM ap_m1.idempotency_keys k
  WHERE k.actor_id = p_actor AND k.namespace = p_namespace AND k.key_sha256 = p_key_sha256 AND k.expires_at <= now();
 -- If another transaction holds this key, this statement waits for it to finish (bounded by lock_timeout).
 INSERT INTO ap_m1.idempotency_keys(actor_id, namespace, key_sha256, request_sha256, expires_at)
  VALUES (p_actor, p_namespace, p_key_sha256, p_request_sha256, now() + make_interval(secs => p_ttl_seconds))
  ON CONFLICT DO NOTHING;
 GET DIAGNOSTICS v_n = ROW_COUNT;
 IF v_n = 1 THEN
  RETURN QUERY SELECT 'NEW'::text, NULL::integer, NULL::jsonb, false;
  RETURN;
 END IF;
 SELECT * INTO r FROM ap_m1.idempotency_keys k
  WHERE k.actor_id = p_actor AND k.namespace = p_namespace AND k.key_sha256 = p_key_sha256;
 IF NOT FOUND THEN
  -- Removed between the conflict and the read (purge). Safe to ask the caller to retry the whole request.
  RAISE EXCEPTION 'idempotency claim raced with cleanup' USING ERRCODE = '40001';
 END IF;
 IF r.request_sha256 <> p_request_sha256 THEN
  -- Never reveal the stored response to a request that does not match it.
  RETURN QUERY SELECT 'MISMATCH'::text, NULL::integer, NULL::jsonb, false;
 ELSIF r.completed_at IS NULL THEN
  RETURN QUERY SELECT 'PENDING'::text, NULL::integer, NULL::jsonb, false;
 ELSE
  RETURN QUERY SELECT 'REPLAY'::text, r.response_status, r.response_body, r.body_omitted;
 END IF;
END $fn$;

-- Record the result of the request that claimed the key, in the same transaction. Only 2xx results are stored.
-- Returns false if there is no open claim for the key (never claimed, already recorded, or expired).
CREATE FUNCTION ap_m1.idempotency_record(
  p_actor uuid, p_namespace text, p_key_sha256 bytea, p_status integer, p_body jsonb,
  p_omit_body boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE v_n integer;
BEGIN
 UPDATE ap_m1.idempotency_keys k
  SET response_status = p_status,
      response_body = CASE WHEN p_omit_body THEN NULL ELSE p_body END,
      body_omitted = coalesce(p_omit_body, false),
      completed_at = now()
  WHERE k.actor_id = p_actor AND k.namespace = p_namespace AND k.key_sha256 = p_key_sha256
    AND k.completed_at IS NULL AND k.expires_at > now();
 GET DIAGNOSTICS v_n = ROW_COUNT;
 RETURN v_n = 1;
END $fn$;

-- Retention job (owner role only, not the API role). Deletes keys that expired more than p_grace ago.
CREATE FUNCTION ap_m1.purge_idempotency_keys(p_grace interval DEFAULT interval '1 hour')
 RETURNS bigint
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE v_n bigint;
BEGIN
 IF p_grace < interval '1 minute' THEN
  RAISE EXCEPTION 'retention grace below the safety floor' USING ERRCODE = '22023';
 END IF;
 DELETE FROM ap_m1.idempotency_keys WHERE expires_at < now() - p_grace;
 GET DIAGNOSTICS v_n = ROW_COUNT;
 RETURN v_n;
END $fn$;

RESET ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON ap_m1.idempotency_keys TO ap_m1_auth;
ALTER FUNCTION ap_m1.idempotency_claim(uuid,text,bytea,bytea,integer) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1.idempotency_record(uuid,text,bytea,integer,jsonb,boolean) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1.purge_idempotency_keys(interval) OWNER TO ap_m1_auth;
REVOKE ALL ON FUNCTION ap_m1.idempotency_claim(uuid,text,bytea,bytea,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION ap_m1.idempotency_record(uuid,text,bytea,integer,jsonb,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ap_m1.purge_idempotency_keys(interval) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.idempotency_claim(uuid,text,bytea,bytea,integer) TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.idempotency_record(uuid,text,bytea,integer,jsonb,boolean) TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.purge_idempotency_keys(interval) TO ap_m1_owner;
COMMIT;
