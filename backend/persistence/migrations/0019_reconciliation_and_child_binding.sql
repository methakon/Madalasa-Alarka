-- Additive reconciliation after 0018. No published migration, table shape, policy
-- or grant is rewritten here: every change is CREATE OR REPLACE on an existing
-- function, or a key/foreign key that makes an existing relationship exact.
--
-- Four defects were reproduced by backend/tests/database/test_reconciliation_*.py
-- before this migration existed:
--
--  1. 0005+0015: purge_expired_location deleted location_event_dedup rows while
--     location_batch_items still referenced them, so physical retention aborted
--     with SQLSTATE 23503. It also ignored that a retained, newer batch may
--     legitimately contain an older event (late upload inside max_upload_age).
--     Deletion now follows the FK graph: trips -> observations -> expired batches
--     (membership and outbox cascade) -> event identity only when no surviving
--     observation AND no membership of a retained batch refers to it.
--  2. 0014: request_account_erasure passed one shared erasure request_key to
--     withdraw_consent for every GRANTED CORE consent, while
--     consent_decision_audit is UNIQUE(actor_id,request_id). The second child
--     aborted the whole request with SQLSTATE 23505. Each consent now derives a
--     deterministic key from (erasure request key, consent id): replay of the
--     same erasure request maps to the same audit identities, nothing is deleted
--     and no unique constraint is weakened.
--  3. 0017: credential, challenge and 60-second issuance windows were measured
--     with now(), which PostgreSQL freezes at transaction start. A transaction
--     opened before a deadline, or one that only reached the check after waiting
--     on the row lock, could consume an expired challenge or issue outside the
--     window. Mutators now sample clock_timestamp() after acquiring the row they
--     validate (and re-sample after the second lock), then use that one instant
--     for every decision and every written timestamp. The read-only lookup stays
--     LANGUAGE sql STABLE and uses statement_timestamp(). Signatures, volatility,
--     owners, search_path and ACLs are unchanged, so no GRANT/ALTER is repeated.
--  4. 0009: media_sessions(request_id) and the quota/artifact rows did not
--     constrain the child, so a valid identifier from another child could be
--     associated with the wrong child. Composite (child_id,id) keys plus
--     composite foreign keys make exact-child binding structural. Existing rows
--     are never deleted or rewritten: the preflight raises and the migration
--     fails closed. MATCH SIMPLE keeps a NULL addon_id legal, and nothing
--     cascades (0010 already purges children first).

-- ---------------------------------------------------------------------------
-- 3a. Read-only credential lookup: unfrozen clock, still STABLE, no lock.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ap_m1.authenticate_device_credential(p_token_sha256 bytea)
 RETURNS TABLE(device_id uuid, family_id uuid, child_id uuid, credential_id uuid, expires_at timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
 SELECT d.id, d.family_id, d.child_id, c.id, c.expires_at
 FROM ap_m1.device_credentials c
 JOIN ap_m1.devices d ON d.id = c.device_id
 JOIN ap_m1.device_key_records k ON k.key_id = c.key_id
 WHERE c.token_sha256 = p_token_sha256
   AND c.revoked_at IS NULL AND c.expires_at > statement_timestamp()
   AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL
   AND k.state = 'ACTIVE' AND k.revoked_at IS NULL
   AND ap_m1._m1_key_live(d.id,k.key_id)
   AND c.bound_key_generation=k.generation
   AND c.bound_key_fingerprint_sha256=k.fingerprint_sha256;
 $fn$;

-- ---------------------------------------------------------------------------
-- 3b. Renewal challenge issuance: rate bound and TTL start at the real clock.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ap_m1.issue_credential_renewal_challenge(
  p_device uuid, p_key_fingerprint_sha256 bytea, p_nonce_sha256 bytea, p_ttl_seconds integer)
 RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER
 SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE v_key uuid; v_generation bigint; v_fingerprint bytea; v_id uuid; v_at timestamptz;
BEGIN
 IF p_ttl_seconds IS NULL OR p_ttl_seconds NOT BETWEEN 30 AND 300 THEN
  RAISE EXCEPTION 'challenge ttl must be 30..300 seconds' USING ERRCODE = '22023';
 END IF;
 SELECT k.key_id,k.generation,k.fingerprint_sha256 INTO v_key,v_generation,v_fingerprint
 FROM ap_m1.devices d
 JOIN ap_m1.device_key_records k ON k.device_id = d.id AND k.state = 'ACTIVE' AND k.revoked_at IS NULL
 WHERE d.id = p_device AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL
   AND k.fingerprint_sha256 = p_key_fingerprint_sha256 AND ap_m1._m1_key_live(d.id,k.key_id) FOR UPDATE OF d,k;
 IF NOT FOUND THEN RETURN NULL; END IF;
 v_at := clock_timestamp();
 -- Bound unauthenticated table growth per device (the API also rate limits).
 IF (SELECT count(*) FROM ap_m1.credential_renewal_challenges
      WHERE device_id = p_device AND consumed_at IS NULL AND expires_at > v_at) >= 5 THEN
  RETURN NULL;
 END IF;
 INSERT INTO ap_m1.credential_renewal_challenges(device_id, key_id, nonce_sha256, created_at, expires_at,bound_key_generation,bound_key_fingerprint_sha256)
 VALUES (p_device, v_key, p_nonce_sha256, v_at, v_at + make_interval(secs => p_ttl_seconds),v_generation,v_fingerprint)
 RETURNING id INTO v_id;
 RETURN v_id;
END $fn$;

-- ---------------------------------------------------------------------------
-- 3c. Renewal challenge consumption: expiry checked after the row lock.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ap_m1.consume_renewal_challenge(p_device uuid, p_challenge uuid)
 RETURNS TABLE(nonce_sha256 bytea, spki_public_key bytea)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.credential_renewal_challenges%ROWTYPE; v_at timestamptz;
BEGIN
 SELECT * INTO ch FROM ap_m1.credential_renewal_challenges
  WHERE id = p_challenge AND device_id = p_device FOR UPDATE;
 IF NOT FOUND THEN RETURN; END IF;
 v_at := clock_timestamp();
 IF ch.consumed_at IS NOT NULL OR ch.expires_at <= v_at THEN RETURN; END IF;
 UPDATE ap_m1.credential_renewal_challenges SET consumed_at = v_at WHERE id = ch.id;
 RETURN QUERY SELECT ch.nonce_sha256, d.spki_public_key
  FROM ap_m1.devices d JOIN ap_m1.device_key_records k ON k.key_id = ch.key_id
  WHERE d.id = p_device AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL
    AND k.state = 'ACTIVE' AND k.revoked_at IS NULL AND ap_m1._m1_key_live(d.id,k.key_id)
    AND k.generation=ch.bound_key_generation AND k.fingerprint_sha256=ch.bound_key_fingerprint_sha256;
END $fn$;

-- ---------------------------------------------------------------------------
-- 3d. Renewal issuance: the 60 s window closes on the real clock and is
--     re-checked after the device/key lock wait.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ap_m1.issue_renewal_credential(
  p_device uuid, p_challenge uuid, p_new_token_sha256 bytea, p_lifetime_seconds integer)
 RETURNS timestamptz
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.credential_renewal_challenges%ROWTYPE; v_exp timestamptz; v_at timestamptz;
BEGIN
 IF p_lifetime_seconds IS NULL OR p_lifetime_seconds NOT BETWEEN 300 AND 86400 THEN
  RAISE EXCEPTION 'credential lifetime must be 300..86400 seconds' USING ERRCODE = '22023';
 END IF;
 SELECT * INTO ch FROM ap_m1.credential_renewal_challenges
  WHERE id = p_challenge AND device_id = p_device FOR UPDATE;
 IF NOT FOUND THEN RETURN NULL; END IF;
 v_at := clock_timestamp();
 IF ch.consumed_at IS NULL OR ch.redeemed_at IS NOT NULL
    OR ch.expires_at<=v_at OR ch.consumed_at < v_at - interval '60 seconds' THEN RETURN NULL; END IF;
 PERFORM 1 FROM ap_m1.devices d
  JOIN ap_m1.device_key_records k ON k.key_id = ch.key_id AND k.state = 'ACTIVE' AND k.revoked_at IS NULL
  WHERE d.id = p_device AND d.enrollment_state = 'ACTIVE' AND d.revoked_at IS NULL AND ap_m1._m1_key_live(d.id,k.key_id)
   AND k.generation=ch.bound_key_generation AND k.fingerprint_sha256=ch.bound_key_fingerprint_sha256 FOR UPDATE OF d,k;
 IF NOT FOUND THEN RETURN NULL; END IF;
 v_at := clock_timestamp();
 IF ch.expires_at<=v_at OR ch.consumed_at < v_at - interval '60 seconds' THEN RETURN NULL; END IF;
 UPDATE ap_m1.credential_renewal_challenges SET redeemed_at = v_at WHERE id = ch.id;
 UPDATE ap_m1.device_credentials SET revoked_at = v_at WHERE device_id = p_device AND revoked_at IS NULL;
 INSERT INTO ap_m1.device_credentials(device_id, key_id, token_sha256, issued_via, issued_at, expires_at, bound_key_generation, bound_key_fingerprint_sha256)
  SELECT p_device,ch.key_id,p_new_token_sha256,'RENEWAL',v_at,v_at+make_interval(secs=>p_lifetime_seconds),k.generation,k.fingerprint_sha256 FROM ap_m1.device_key_records k WHERE k.key_id=ch.key_id AND k.device_id=p_device
  RETURNING expires_at INTO v_exp;
 RETURN v_exp;
END $fn$;

-- ---------------------------------------------------------------------------
-- 3e. Enrollment challenge consumption: expiry checked after the row lock.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ap_m1.consume_enrollment_challenge(p_enrollment uuid)
 RETURNS TABLE(device_id uuid, nonce_sha256 bytea, spki_public_key bytea)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.enrollment_challenges%ROWTYPE; v_at timestamptz;
BEGIN
 SELECT * INTO ch FROM ap_m1.enrollment_challenges WHERE id = p_enrollment FOR UPDATE;
 IF NOT FOUND THEN RETURN; END IF;
 v_at := clock_timestamp();
 IF ch.consumed_at IS NOT NULL OR ch.expires_at <= v_at THEN RETURN; END IF;
 UPDATE ap_m1.enrollment_challenges SET consumed_at = v_at WHERE id = ch.id;
 RETURN QUERY SELECT d.id, ch.nonce_sha256, d.spki_public_key FROM ap_m1.devices d
  WHERE d.id = ch.device_id AND d.enrollment_state = 'PENDING_PROOF' AND d.revoked_at IS NULL AND NOT ap_m1.child_deleted(d.child_id) AND ap_m1.has_consent(d.child_id,'CORE');
END $fn$;

-- ---------------------------------------------------------------------------
-- 3f. Enrollment activation: 60 s window on the real clock, re-checked after the
--     device lock, with real issued_at/expires_at timestamps.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ap_m1.activate_enrolled_device(
  p_enrollment uuid, p_new_token_sha256 bytea, p_lifetime_seconds integer)
 RETURNS TABLE(device_id uuid, expires_at timestamptz)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE ch ap_m1.enrollment_challenges%ROWTYPE; d ap_m1.devices%ROWTYPE; v_key uuid; v_exp timestamptz; v_at timestamptz;
BEGIN
 IF p_lifetime_seconds IS NULL OR p_lifetime_seconds NOT BETWEEN 300 AND 86400 THEN
  RAISE EXCEPTION 'credential lifetime must be 300..86400 seconds' USING ERRCODE = '22023';
 END IF;
 SELECT * INTO ch FROM ap_m1.enrollment_challenges WHERE id = p_enrollment FOR UPDATE;
 IF NOT FOUND THEN RETURN; END IF;
 v_at := clock_timestamp();
 IF ch.consumed_at IS NULL OR ch.redeemed_at IS NOT NULL
    OR ch.consumed_at < v_at - interval '60 seconds' THEN RETURN; END IF;
 SELECT * INTO d FROM ap_m1.devices WHERE id = ch.device_id FOR UPDATE;
 IF NOT FOUND OR d.enrollment_state <> 'PENDING_PROOF' OR d.revoked_at IS NOT NULL
 OR ap_m1.child_deleted(d.child_id) OR NOT ap_m1.has_consent(d.child_id,'CORE') THEN RETURN; END IF;
 v_at := clock_timestamp();
 IF ch.expires_at<=v_at OR ch.consumed_at < v_at - interval '60 seconds' THEN RETURN; END IF;
 UPDATE ap_m1.enrollment_challenges SET redeemed_at = v_at WHERE id = ch.id;
 UPDATE ap_m1.devices SET enrollment_state = 'ACTIVE' WHERE id = d.id;
 INSERT INTO ap_m1.device_key_records(device_id, fingerprint_sha256)
  VALUES (d.id, sha256(d.spki_public_key)) RETURNING key_id INTO v_key;
 INSERT INTO ap_m1.device_credentials(device_id, key_id, token_sha256, issued_via, issued_at, expires_at, bound_key_generation, bound_key_fingerprint_sha256)
  VALUES (d.id, v_key, p_new_token_sha256, 'ENROLLMENT', v_at, v_at + make_interval(secs => p_lifetime_seconds), 1, public.digest(d.spki_public_key,'sha256'))
  RETURNING device_credentials.expires_at INTO v_exp;
 RETURN QUERY SELECT d.id, v_exp;
END $fn$;

-- ---------------------------------------------------------------------------
-- 3g. Pairing-code redemption: code expiry and the enrollment TTL start on the
--     actual clock read after the code row lock.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ap_m1.redeem_pairing_code(
  p_code_sha256 bytea, p_spki bytea, p_nonce_sha256 bytea, p_ttl_seconds integer)
 RETURNS TABLE(enrollment_id uuid, device_id uuid)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, ap_m1 AS $fn$
DECLARE pc ap_m1.pairing_codes%ROWTYPE; v_dev uuid; v_enr uuid; v_at timestamptz;
BEGIN
 IF p_ttl_seconds IS NULL OR p_ttl_seconds NOT BETWEEN 30 AND 600 THEN
  RAISE EXCEPTION 'enrollment challenge ttl must be 30..600 seconds' USING ERRCODE = '22023';
 END IF;
 IF p_spki IS NULL OR octet_length(p_spki) NOT BETWEEN 80 AND 4096
    OR p_nonce_sha256 IS NULL OR octet_length(p_nonce_sha256) <> 32 THEN
  RAISE EXCEPTION 'malformed enrollment input' USING ERRCODE = '22023';
 END IF;
 SELECT * INTO pc FROM ap_m1.pairing_codes WHERE code_sha256 = p_code_sha256 FOR UPDATE;
 IF NOT FOUND THEN RETURN; END IF;
 v_at := clock_timestamp();
 IF ap_m1.child_deleted(pc.child_id) OR NOT ap_m1.has_consent(pc.child_id,'CORE')
 OR NOT ap_m1._adult_has_scope(pc.child_id,pc.issued_by,'PAIR_DEVICE') THEN RETURN; END IF;
 IF pc.consumed_at IS NOT NULL OR pc.expires_at <= v_at OR pc.attempt_count >= 20 THEN RETURN; END IF;
 UPDATE ap_m1.pairing_codes SET consumed_at = v_at, attempt_count = attempt_count + 1 WHERE id = pc.id;
 INSERT INTO ap_m1.devices(family_id, child_id, spki_public_key)
  VALUES (pc.family_id, pc.child_id, p_spki) RETURNING id INTO v_dev;
 INSERT INTO ap_m1.enrollment_challenges(device_id, nonce_sha256, created_at, expires_at)
  VALUES (v_dev, p_nonce_sha256, v_at, v_at + make_interval(secs => p_ttl_seconds)) RETURNING id INTO v_enr;
 RETURN QUERY SELECT v_enr, v_dev;
END $fn$;

-- ---------------------------------------------------------------------------
-- 4. Media exact-child binding. Preflight first: fail closed, keep every row.
-- ---------------------------------------------------------------------------
DO $media_guard$
BEGIN
 IF EXISTS (SELECT 1 FROM ap_m1.media_sessions s
   JOIN ap_m1.media_command_requests r ON r.id = s.request_id
   WHERE r.child_id <> s.child_id) THEN
  RAISE EXCEPTION 'media_sessions row binds a request of another child';
 END IF;
 IF EXISTS (SELECT 1 FROM ap_m1.media_quota_ledger l
   JOIN ap_m1.child_media_quota_pools p ON p.id = l.pool_id
   WHERE p.child_id <> l.child_id) THEN
  RAISE EXCEPTION 'media_quota_ledger row binds a pool of another child';
 END IF;
 IF EXISTS (SELECT 1 FROM ap_m1.media_quota_ledger l
   JOIN ap_m1.media_sessions s ON s.id = l.media_session_id
   WHERE s.child_id <> l.child_id) THEN
  RAISE EXCEPTION 'media_quota_ledger row binds a session of another child';
 END IF;
 IF EXISTS (SELECT 1 FROM ap_m1.media_quota_ledger l
   JOIN ap_m1.extra_viewer_purchases a ON a.id = l.addon_id
   WHERE a.child_id <> l.child_id) THEN
  RAISE EXCEPTION 'media_quota_ledger row binds an addon of another child';
 END IF;
 IF EXISTS (SELECT 1 FROM ap_m1.capture_artifact_refs f
   JOIN ap_m1.media_sessions s ON s.id = f.media_session_id
   WHERE s.child_id <> f.child_id) THEN
  RAISE EXCEPTION 'capture_artifact_refs row binds a session of another child';
 END IF;
END $media_guard$;

-- Referenced keys. (child_id, id) cannot fail: id is already the primary key.
ALTER TABLE ap_m1.media_command_requests ADD CONSTRAINT media_request_child_id_id_key UNIQUE(child_id,id);
ALTER TABLE ap_m1.media_sessions ADD CONSTRAINT media_session_child_id_id_key UNIQUE(child_id,id);
ALTER TABLE ap_m1.child_media_quota_pools ADD CONSTRAINT media_pool_child_id_id_key UNIQUE(child_id,id);
ALTER TABLE ap_m1.extra_viewer_purchases ADD CONSTRAINT media_addon_child_id_id_key UNIQUE(child_id,id);

-- Exact-child references. Default MATCH SIMPLE / NO ACTION: a nullable addon_id is
-- skipped, and no delete cascades (0010 child purge deletes children first).
ALTER TABLE ap_m1.media_sessions ADD CONSTRAINT media_session_request_child_fk
 FOREIGN KEY(child_id,request_id) REFERENCES ap_m1.media_command_requests(child_id,id);
ALTER TABLE ap_m1.media_quota_ledger
 ADD CONSTRAINT media_ledger_pool_child_fk FOREIGN KEY(child_id,pool_id)
  REFERENCES ap_m1.child_media_quota_pools(child_id,id),
 ADD CONSTRAINT media_ledger_session_child_fk FOREIGN KEY(child_id,media_session_id)
  REFERENCES ap_m1.media_sessions(child_id,id),
 ADD CONSTRAINT media_ledger_addon_child_fk FOREIGN KEY(child_id,addon_id)
  REFERENCES ap_m1.extra_viewer_purchases(child_id,id);
ALTER TABLE ap_m1.capture_artifact_refs ADD CONSTRAINT capture_artifact_session_child_fk
 FOREIGN KEY(child_id,media_session_id) REFERENCES ap_m1.media_sessions(child_id,id);

-- ---------------------------------------------------------------------------
-- 1. Retention purge in FK/erasure-inventory order.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ap_m1.purge_expired_location(c uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE cutoff timestamptz; n bigint;
BEGIN
 SELECT clock_timestamp()-retain_for INTO cutoff FROM ap_m1.location_collection_policies WHERE child_id=c FOR SHARE;
 IF cutoff IS NULL THEN RAISE EXCEPTION 'RETENTION_POLICY_REQUIRED' USING ERRCODE='22023'; END IF;
 -- Trip structure must go first: revisions/legs/routepoints cascade from here.
 DELETE FROM ap_m1.trips WHERE child_id=c AND first_observed_at<cutoff;
 DELETE FROM ap_m1.location_observations WHERE child_id=c AND observed_at<cutoff;
 GET DIAGNOSTICS n=ROW_COUNT;
 -- Expired batches take their exact accepted membership with them
 -- (location_batch_items.batch_id ... ON DELETE CASCADE) and any queued outbox
 -- row. Doing this BEFORE the event-identity delete removes the membership rows
 -- that would otherwise block it and leaves retained batches intact.
 DELETE FROM ap_m1.location_ingest_batches WHERE child_id=c AND accepted_at<cutoff;
 -- An event identity is deletable only when no surviving child row points at it:
 -- no retained observation, and no membership item of a batch that has not
 -- expired yet. A newer retained batch may hold an older event; that reference is
 -- preserved and a later purge deletes it once that batch also expires.
 DELETE FROM ap_m1.location_event_dedup d WHERE child_id=c AND first_seen_at<cutoff
 AND NOT EXISTS(SELECT 1 FROM ap_m1.location_observations o
                WHERE o.child_id=c AND o.device_id=d.device_id AND o.event_id=d.event_id)
 AND NOT EXISTS(SELECT 1 FROM ap_m1.location_batch_items i
                WHERE i.child_id=c AND i.device_id=d.device_id AND i.event_id=d.event_id);
 RETURN n;
END $$;
REVOKE ALL ON FUNCTION ap_m1.purge_expired_location(uuid) FROM PUBLIC;
ALTER FUNCTION ap_m1.purge_expired_location(uuid) OWNER TO ap_db_executor;
GRANT DELETE ON ap_m1.trips,ap_m1.location_observations,ap_m1.location_event_dedup,ap_m1.location_ingest_batches TO ap_db_executor;

-- ---------------------------------------------------------------------------
-- 2. Account erasure must withdraw CORE consent in every child.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION ap_m1.request_account_erasure(request_key uuid) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $fn$
DECLARE actor uuid:=ap_m1.ctx_principal(); existing uuid; result_id uuid; consent uuid; audit_key uuid;
 identity_row ap_m1.parent_principals;
BEGIN
 IF actor IS NULL OR request_key IS NULL THEN RAISE EXCEPTION 'authenticated account required' USING ERRCODE='42501'; END IF;
 -- Serialize account removal while retaining nonidentifying FK anchors for
 -- separately governed billing, child-authority and audit retention jobs.
 SELECT * INTO STRICT identity_row FROM ap_m1.parent_principals WHERE id=actor FOR NO KEY UPDATE;
 SELECT id INTO existing FROM ap_m1.adult_erasure_requests WHERE principal_id=actor;
 IF FOUND THEN RETURN existing; END IF;
 INSERT INTO ap_m1.adult_erasure_requests(principal_id,request_key) VALUES(actor,request_key) RETURNING id INTO result_id;
 -- Use the same device->child lock order and withdrawal fence as GPS.
 -- One erasure request may withdraw CORE consent in several children, but
 -- consent_decision_audit is UNIQUE(actor_id,request_id): a single shared key
 -- aborts on the second consent. Derive one deterministic key per
 -- (erasure request key, consent) instead of deleting audit or weakening the
 -- unique constraint, so replaying the same request stays idempotent.
 FOR consent IN SELECT id FROM ap_m1.consent_records WHERE adult_id=actor AND purpose='CORE' AND status='GRANTED' ORDER BY child_id LOOP
   audit_key:=md5(request_key::text||':consent-withdrawal:'||consent::text)::uuid;
   PERFORM ap_m1.withdraw_consent(consent,audit_key);
 END LOOP;
 UPDATE ap_m1.trusted_sessions SET revoked_at=COALESCE(revoked_at,clock_timestamp()),revision=revision+1,updated_at=clock_timestamp()
 WHERE principal_id=actor;
 UPDATE ap_m1.child_access_grants_v2 SET revoked_at=COALESCE(revoked_at,clock_timestamp()),revision=revision+1,updated_at=clock_timestamp()
 WHERE adult_id=actor;
 UPDATE ap_m1.guardian_memberships SET revoked_at=COALESCE(revoked_at,clock_timestamp()) WHERE principal_id=actor;
 UPDATE ap_m1.trusted_principal_verifications SET revoked_at=COALESCE(revoked_at,clock_timestamp()),revision=revision+1,updated_at=clock_timestamp() WHERE principal_id=actor;
 UPDATE ap_m1.admin_sessions SET revoked_at=COALESCE(revoked_at,clock_timestamp())
 WHERE admin_id IN (SELECT id FROM ap_m1.admin_accounts WHERE principal_id=actor);
 UPDATE ap_m1.admin_role_grants SET revoked_at=COALESCE(revoked_at,clock_timestamp())
 WHERE admin_id IN (SELECT id FROM ap_m1.admin_accounts WHERE principal_id=actor);
 DELETE FROM ap_m1.admin_email_challenges WHERE admin_id IN (SELECT id FROM ap_m1.admin_accounts WHERE principal_id=actor);
 UPDATE ap_m1.admin_profiles SET full_name='Erased account',contact_email='erased+'||actor::text||'@example.invalid',contact_verified_at=NULL,
 revision=revision+1,updated_at=clock_timestamp() WHERE admin_id IN (SELECT id FROM ap_m1.admin_accounts WHERE principal_id=actor);
 UPDATE ap_m1.admin_accounts SET verified_email='erased+'||actor::text||'@example.invalid',state='REVOKED',
 session_revocation_epoch=session_revocation_epoch+1,revision=revision+1,updated_at=clock_timestamp() WHERE principal_id=actor;
 DELETE FROM ap_m1.owner_identity_allowlist WHERE issuer=identity_row.oidc_issuer AND subject=identity_row.oidc_subject;
 UPDATE ap_m1.support_messages SET body='[Content removed at account erasure]'
 WHERE ticket_id IN (SELECT id FROM ap_m1.support_tickets WHERE requester_id=actor);
 UPDATE ap_m1.support_tickets SET subject='Erased account',revision=revision+1,updated_at=clock_timestamp() WHERE requester_id=actor;
 UPDATE ap_m1.parent_principals SET oidc_issuer='https://erased.example.invalid',oidc_subject='erased:'||actor::text WHERE id=actor;
 INSERT INTO ap_m1.adult_erasure_jobs(request_id,category)
 SELECT result_id,category FROM unnest(ARRAY['FINANCIAL','SUPPORT','SECURITY_AUDIT','BACKUPS','CHILD_AUTHORITY']) category;
 UPDATE ap_m1.adult_erasure_requests SET state='BLOCKED_POLICY',primary_minimized_at=clock_timestamp(),revision=revision+1,updated_at=clock_timestamp() WHERE id=result_id;
 RETURN result_id;
END $fn$;
ALTER FUNCTION ap_m1.request_account_erasure(uuid) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.request_account_erasure(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.request_account_erasure(uuid) TO ap_m1_api;
