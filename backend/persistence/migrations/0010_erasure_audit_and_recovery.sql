-- Erasure is a transactionally fenced primary purge plus independently evidenced stores.
-- Backups/remote guardian devices are NOT claimed erased by a primary database delete.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ap_privacy_worker') THEN
 CREATE ROLE ap_privacy_worker NOLOGIN NOSUPERUSER NOBYPASSRLS;
 END IF;
END $$;
GRANT USAGE ON SCHEMA ap_m1 TO ap_privacy_worker;
CREATE TABLE ap_m1.account_deletion_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), requested_by uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id), request_key uuid NOT NULL,
 scope text NOT NULL DEFAULT 'CHILD' CHECK(scope='CHILD'),
 state text NOT NULL DEFAULT 'REQUESTED' CHECK(state IN ('REQUESTED','ACCESS_REVOKED','DELETING','PRIMARY_ERASED','COMPLETED','FAILED_RETRYABLE')),
 received_at timestamptz NOT NULL DEFAULT now(), primary_erased_at timestamptz, completed_at timestamptz,
 deadline timestamptz, revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(requested_by,request_key)
);
CREATE UNIQUE INDEX one_child_deletion ON ap_m1.account_deletion_requests(child_id);
CREATE TABLE ap_m1.erasure_jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), request_id uuid NOT NULL REFERENCES ap_m1.account_deletion_requests(id),
 target_store text NOT NULL CHECK(target_store IN ('PRIMARY','BACKUP','EXTERNAL_REFERENCE')),
 state text NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','PROCESSING','VERIFIED','FAILED_RETRYABLE','BLOCKED_POLICY')),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0), completed_at timestamptz,
 last_error_code text CHECK(last_error_code ~ '^[A-Z0-9_]{1,80}$'),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(request_id,target_store), CHECK(state<>'VERIFIED' OR completed_at IS NOT NULL)
);
CREATE TABLE ap_m1.erasure_job_targets (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), job_id uuid NOT NULL REFERENCES ap_m1.erasure_jobs(id),
 category text NOT NULL CHECK(length(category) BETWEEN 1 AND 100),
 completed_at timestamptz, proof_sha256 bytea CHECK(octet_length(proof_sha256)=32),
 rows_removed bigint CHECK(rows_removed>=0), UNIQUE(job_id,category),
 CHECK(completed_at IS NULL OR proof_sha256 IS NOT NULL)
);
CREATE TABLE ap_m1.erasure_evidence (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), job_id uuid NOT NULL REFERENCES ap_m1.erasure_jobs(id),
 evidence_kind text NOT NULL CHECK(evidence_kind IN ('PRIMARY_PURGE','BACKUP_EXPIRY','RESTORE_SUPPRESSION','EXTERNAL_ACK')),
 proof_sha256 bytea NOT NULL CHECK(octet_length(proof_sha256)=32), created_at timestamptz NOT NULL DEFAULT now(),
 retention_policy_id uuid REFERENCES ap_m1.retention_policy_versions(id), UNIQUE(job_id,evidence_kind,proof_sha256)
);
CREATE TABLE ap_m1.backup_inventory (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), backup_ref uuid NOT NULL UNIQUE,
 completed_at timestamptz NOT NULL, expires_at timestamptz, destroyed_at timestamptz,
 retention_policy_id uuid REFERENCES ap_m1.retention_policy_versions(id),
 CHECK(expires_at IS NULL OR expires_at>completed_at)
);
CREATE TABLE ap_m1.backup_erasure_manifests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), request_id uuid NOT NULL REFERENCES ap_m1.account_deletion_requests(id),
 backup_id uuid NOT NULL REFERENCES ap_m1.backup_inventory(id), child_id uuid NOT NULL,
 state text NOT NULL DEFAULT 'SUPPRESS_ON_RESTORE' CHECK(state IN ('SUPPRESS_ON_RESTORE','PURGED','EXPIRED_VERIFIED')),
 purge_by timestamptz, verified_at timestamptz, proof_sha256 bytea CHECK(octet_length(proof_sha256)=32),
 UNIQUE(backup_id,child_id), CHECK(state='SUPPRESS_ON_RESTORE' OR (verified_at IS NOT NULL AND proof_sha256 IS NOT NULL))
);
CREATE TABLE ap_m1.restore_runs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), backup_id uuid NOT NULL REFERENCES ap_m1.backup_inventory(id),
 state text NOT NULL DEFAULT 'QUARANTINED' CHECK(state IN ('QUARANTINED','REPLAYING','READY','FAILED')),
 started_at timestamptz NOT NULL DEFAULT now(), suppressed_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE ap_m1.restore_suppression_receipts (
 restore_id uuid NOT NULL REFERENCES ap_m1.restore_runs(id), child_id uuid NOT NULL REFERENCES ap_m1.child_erasure_tombstones(child_id),
 suppressed_at timestamptz NOT NULL DEFAULT now(), proof_sha256 bytea NOT NULL CHECK(octet_length(proof_sha256)=32),
 PRIMARY KEY(restore_id,child_id)
);
CREATE TABLE ap_m1.restore_ledger_imports (
 restore_id uuid PRIMARY KEY REFERENCES ap_m1.restore_runs(id),
 checkpoint_sha256 bytea NOT NULL CHECK(octet_length(checkpoint_sha256)=32),
 tombstone_count bigint NOT NULL CHECK(tombstone_count>=0),
 source_reference_sha256 bytea NOT NULL CHECK(octet_length(source_reference_sha256)=32),
 imported_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ap_m1.export_jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), requester_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id), policy_id uuid NOT NULL REFERENCES ap_m1.retention_policy_versions(id),
 state text NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','PROCESSING','READY','EXPIRED','REVOKED','FAILED')),
 requested_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL,
 delivery_ref_encrypted bytea, revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(expires_at>requested_at), CHECK(state<>'READY' OR delivery_ref_encrypted IS NOT NULL)
);
-- Private allowlist and dependency order; never accept a table/column string from runtime.
CREATE TABLE ap_m1.erasure_store_inventory (
 table_name text PRIMARY KEY, key_kind text NOT NULL CHECK(key_kind IN ('CHILD','DEVICE','COMMAND','MEDIA_SESSION')),
 purge_order integer NOT NULL UNIQUE
);
INSERT INTO ap_m1.erasure_store_inventory VALUES
 ('trip_routepoints','CHILD',10),('trip_revisions','CHILD',20),('trips','CHILD',30),
 ('place_notification_rules','CHILD',40),('alert_delivery_attempts','CHILD',41),
 ('parent_notification_read_receipts','CHILD',42),('notification_deliveries','CHILD',43),
 ('alert_delivery_outbox','CHILD',44),('signal_acknowledgements','CHILD',45),
 ('alert_events','CHILD',50),('child_signals','CHILD',51),('geofence_events','CHILD',52),('named_places','CHILD',60),
 ('sos_acknowledgements','CHILD',90),
 ('sos_events','CHILD',100),('child_checkins','CHILD',110),('notification_preferences','CHILD',120),
 ('commute_plan_revisions','CHILD',140),('commute_plans','CHILD',150),
 ('policy_execution_receipts','CHILD',151),('rule_assignments','CHILD',152),
 ('screen_time_rules','CHILD',160),('app_usage_events','CHILD',170),('app_usage_intervals','CHILD',171),('usage_period_summaries','CHILD',180),
 ('installed_app_inventory','CHILD',190),('usage_permission_checks','CHILD',200),
 ('device_latest_positions','CHILD',210),('ingestion_outbox','CHILD',220),('location_observations','CHILD',230),
 ('location_event_dedup','CHILD',240),('location_ingest_batches','CHILD',250),('location_collection_policies','CHILD',260),
 ('device_permission_change_events','CHILD',270),('permission_snapshots','CHILD',271),
 ('device_reenrollment_events','CHILD',272),('command_receipts','CHILD',273),('tracking_policy_revisions','CHILD',280),
 ('media_request_device_approvals','CHILD',290),('capture_artifact_refs','CHILD',300),
 ('media_export_requests','CHILD',301),('media_access_audit','CHILD',310),
 ('media_quota_ledger','CHILD',320),('media_lifecycle_events','MEDIA_SESSION',330),
 ('media_sessions','CHILD',340),('media_command_requests','CHILD',350),('viewer_takeover_requests','CHILD',360),
 ('premium_viewer_leases','CHILD',370),('child_media_quota_pools','CHILD',380),
 ('capability_snapshots','DEVICE',390),('device_health','DEVICE',400),('enrollment_challenges','DEVICE',410),
 ('command_results','COMMAND',420),('commands','DEVICE',430),('pairing_codes','CHILD',440);

CREATE FUNCTION ap_m1._purge_child_data(target uuid, primary_job uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE store record; removed bigint;
BEGIN
 PERFORM 1 FROM ap_m1.devices WHERE child_id=target ORDER BY id FOR UPDATE;
 PERFORM 1 FROM ap_m1.children WHERE id=target FOR UPDATE;
 -- Persistent tombstone deliberately has no FK requiring resurrection of child identity.
 INSERT INTO ap_m1.child_erasure_tombstones(child_id,reason_code) VALUES(target,'AUTHORIZED_ERASURE') ON CONFLICT(child_id) DO NOTHING;
 UPDATE ap_m1.children SET deletion_requested_at=coalesce(deletion_requested_at,clock_timestamp()),
 deleted_at=coalesce(deleted_at,clock_timestamp()),alias='Deleted child',state='SUSPENDED' WHERE id=target;
 UPDATE ap_m1.devices SET enrollment_state='REVOKED',revoked_at=coalesce(revoked_at,clock_timestamp()),
 spki_public_key=decode(repeat('00',80),'hex') WHERE child_id=target;
 UPDATE ap_m1.trusted_sessions SET revoked_at=coalesce(revoked_at,clock_timestamp()),revision=revision+1,updated_at=clock_timestamp()
 WHERE device_id IN (SELECT id FROM ap_m1.devices WHERE child_id=target);
 UPDATE ap_m1.device_key_records SET state='REVOKED',revoked_at=coalesce(revoked_at,clock_timestamp())
 WHERE device_id IN (SELECT id FROM ap_m1.devices WHERE child_id=target);
 UPDATE ap_m1.consent_records SET status='WITHDRAWN',withdrawn_at=coalesce(withdrawn_at,clock_timestamp()),
 revision=revision+1,updated_at=clock_timestamp() WHERE child_id=target;
 UPDATE ap_m1.child_access_grants_v2 SET revoked_at=coalesce(revoked_at,clock_timestamp()),
 revision=revision+1,revocation_epoch=revocation_epoch+1,updated_at=clock_timestamp() WHERE child_id=target;
 UPDATE ap_m1.child_guardian_grants SET revoked_at=coalesce(revoked_at,clock_timestamp()) WHERE child_id=target;
 UPDATE ap_m1.child_access_invites SET state='REVOKED',revoked_at=coalesce(revoked_at,clock_timestamp()),
 revision=revision+1,updated_at=clock_timestamp() WHERE child_id=target;
 UPDATE ap_m1.child_authority_reviews SET state='REVOKED',revoked_at=coalesce(revoked_at,clock_timestamp()),
 evidence_pointer_encrypted_nullable=NULL,claimed_relationship='ERASED',revision=revision+1,updated_at=clock_timestamp() WHERE child_id=target;
 UPDATE ap_m1.export_jobs SET state='REVOKED',delivery_ref_encrypted=NULL,revision=revision+1,updated_at=clock_timestamp() WHERE child_id=target;
 PERFORM ap_m1.revoke_child_capabilities(target);
 -- All configured live stores must be purged; absent future tables alone are skipped.
 -- If an existing store lacks its declared scope column, abort instead of false completion.
 FOR store IN SELECT * FROM ap_m1.erasure_store_inventory ORDER BY purge_order LOOP
 IF to_regclass('ap_m1.'||store.table_name) IS NULL THEN CONTINUE; END IF;
 IF store.key_kind='CHILD' THEN
 IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass('ap_m1.'||store.table_name)
 AND attname='child_id' AND NOT attisdropped) THEN
 RAISE EXCEPTION 'erasure inventory key missing: %',store.table_name;
 END IF;
 EXECUTE format('DELETE FROM ap_m1.%I WHERE child_id=$1',store.table_name) USING target;
 ELSIF store.key_kind='DEVICE' THEN
 EXECUTE format('DELETE FROM ap_m1.%I WHERE device_id IN (SELECT id FROM ap_m1.devices WHERE child_id=$1)',store.table_name) USING target;
 ELSIF store.key_kind='MEDIA_SESSION' THEN
 EXECUTE format('DELETE FROM ap_m1.%I WHERE media_session_id IN (SELECT id FROM ap_m1.media_sessions WHERE child_id=$1)',store.table_name) USING target;
 ELSE
 EXECUTE format('DELETE FROM ap_m1.%I WHERE command_id IN (SELECT c.id FROM ap_m1.commands c JOIN ap_m1.devices d ON d.id=c.device_id WHERE d.child_id=$1)',store.table_name) USING target;
 END IF;
 GET DIAGNOSTICS removed=ROW_COUNT;
 IF primary_job IS NOT NULL THEN
 INSERT INTO ap_m1.erasure_job_targets(job_id,category,completed_at,proof_sha256,rows_removed)
 VALUES(primary_job,store.table_name,clock_timestamp(),public.digest(target::text||':'||store.table_name||':'||removed::text,'sha256'),removed)
 ON CONFLICT(job_id,category) DO UPDATE SET completed_at=EXCLUDED.completed_at,proof_sha256=EXCLUDED.proof_sha256,rows_removed=EXCLUDED.rows_removed;
 END IF;
 END LOOP;
END $$;
CREATE FUNCTION ap_m1.request_child_erasure(target uuid, request_key uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE actor uuid:=ap_m1.ctx_principal(); existing ap_m1.account_deletion_requests; rid uuid; jid uuid;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'parent required' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.devices WHERE child_id=target ORDER BY id FOR UPDATE;
 PERFORM 1 FROM ap_m1.children WHERE id=target FOR UPDATE;
 SELECT * INTO existing FROM ap_m1.account_deletion_requests WHERE requested_by=actor AND account_deletion_requests.request_key=request_child_erasure.request_key;
 IF FOUND THEN
 IF existing.child_id<>target THEN RAISE EXCEPTION 'request key conflict' USING ERRCODE='40001'; END IF;
 RETURN existing.id;
 END IF;
 -- Voluntary withdrawal does not remove a lawful adult's erasure rights.
 -- Billing ownership or a historical consent alone is never sufficient: the
 -- actor must have withdrawn their own consent and retain live undisputed
 -- child-specific authority. Revoked grants with still-granted consent do not
 -- enter this fallback, nor do revoked/expired/disputed authority reviews.
 IF NOT ap_m1.has_child_scope_v2(target,'MANAGE_CONSENT') AND NOT EXISTS(
 SELECT 1 FROM ap_m1.children c JOIN ap_m1.consent_records cr ON cr.child_id=c.id AND cr.adult_id=actor
 JOIN ap_m1.child_authority_reviews ar ON ar.id=cr.authority_review_id AND ar.child_id=cr.child_id AND ar.adult_id=actor
 WHERE c.id=target AND cr.purpose='CORE' AND cr.status='WITHDRAWN'
 AND cr.withdrawn_at IS NOT NULL AND cr.revoked_at IS NULL
 AND ap_m1._review_live(ar.id) AND ap_m1.family_owner(c.family_id)
 AND EXISTS(SELECT 1 FROM ap_m1.consent_decision_audit ca
   JOIN ap_m1.consent_records withdrawn ON withdrawn.id=ca.consent_id
   WHERE withdrawn.child_id=target AND ca.actor_id=actor AND ca.action='WITHDRAWN'))
 THEN RAISE EXCEPTION 'child erasure denied' USING ERRCODE='42501'; END IF;
 IF EXISTS(SELECT 1 FROM ap_m1.account_deletion_requests WHERE child_id=target) THEN
 RAISE EXCEPTION 'erasure already requested' USING ERRCODE='40001'; END IF;
 INSERT INTO ap_m1.account_deletion_requests(requested_by,child_id,request_key,state)
 VALUES(actor,target,request_key,'DELETING') RETURNING id INTO rid;
 INSERT INTO ap_m1.erasure_jobs(request_id,target_store,state,attempts) VALUES(rid,'PRIMARY','PROCESSING',1) RETURNING id INTO jid;
 INSERT INTO ap_m1.erasure_jobs(request_id,target_store,state) VALUES(rid,'BACKUP','BLOCKED_POLICY'),(rid,'EXTERNAL_REFERENCE','BLOCKED_POLICY');
 PERFORM ap_m1._purge_child_data(target,jid);
 INSERT INTO ap_m1.erasure_evidence(job_id,evidence_kind,proof_sha256)
 VALUES(jid,'PRIMARY_PURGE',public.digest(target::text||':'||rid::text,'sha256'));
 UPDATE ap_m1.erasure_jobs SET state='VERIFIED',completed_at=clock_timestamp(),revision=revision+1,updated_at=clock_timestamp() WHERE id=jid;
 INSERT INTO ap_m1.backup_erasure_manifests(request_id,backup_id,child_id,purge_by)
 SELECT rid,b.id,target,b.expires_at FROM ap_m1.backup_inventory b WHERE b.destroyed_at IS NULL ON CONFLICT(backup_id,child_id) DO NOTHING;
 UPDATE ap_m1.account_deletion_requests SET state='PRIMARY_ERASED',primary_erased_at=clock_timestamp(),revision=revision+1,updated_at=clock_timestamp() WHERE id=rid;
 RETURN rid;
END $$;
-- Checkpoint source is outside the restored application snapshot. Missing source
-- returns no checkpoint; it is never confused with a legitimately empty ledger.
CREATE FUNCTION ap_m1._restore_ledger_checkpoint() RETURNS TABLE(checksum bytea,tombstone_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
BEGIN
 IF to_regclass('ma_recovery.erasure_ledger') IS NULL THEN RETURN; END IF;
 RETURN QUERY SELECT public.digest(COALESCE(jsonb_agg(
   jsonb_build_array(child_id,extract(epoch FROM erased_at),reason_code) ORDER BY child_id),'[]'::jsonb)::text,'sha256'),count(*)
 FROM ma_recovery.erasure_ledger;
END $$;
CREATE FUNCTION ap_m1.import_restore_ledger(target uuid,source_reference bytea) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE checkpoint record;
BEGIN
 PERFORM 1 FROM ap_m1.restore_runs WHERE id=target FOR UPDATE;
 IF NOT FOUND OR source_reference IS NULL OR octet_length(source_reference)<>32
 THEN RAISE EXCEPTION 'invalid ledger import' USING ERRCODE='42501'; END IF;
 SELECT * INTO checkpoint FROM ap_m1._restore_ledger_checkpoint();
 IF NOT FOUND THEN RAISE EXCEPTION 'independent erasure ledger unavailable' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.child_erasure_tombstones(child_id,erased_at,reason_code)
 SELECT child_id,erased_at,reason_code FROM ma_recovery.erasure_ledger ON CONFLICT(child_id) DO NOTHING;
 INSERT INTO ap_m1.restore_ledger_imports(restore_id,checkpoint_sha256,tombstone_count,source_reference_sha256)
 VALUES(target,checkpoint.checksum,checkpoint.tombstone_count,source_reference)
 ON CONFLICT(restore_id) DO UPDATE SET checkpoint_sha256=EXCLUDED.checkpoint_sha256,
 tombstone_count=EXCLUDED.tombstone_count,source_reference_sha256=EXCLUDED.source_reference_sha256,imported_at=clock_timestamp();
END $$;
CREATE FUNCTION ap_m1._restore_ledger_matches(target uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
 SELECT EXISTS(SELECT 1 FROM ap_m1.restore_ledger_imports i CROSS JOIN ap_m1._restore_ledger_checkpoint() c
 WHERE i.restore_id=target AND i.checkpoint_sha256=c.checksum AND i.tombstone_count=c.tombstone_count);
$$;
CREATE FUNCTION ap_m1.restore_can_open(target uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
 SELECT EXISTS(SELECT 1 FROM ap_m1.restore_runs r WHERE r.id=target AND r.state='READY')
 AND ap_m1._restore_ledger_matches(target)
 AND NOT EXISTS(SELECT 1 FROM ap_m1.child_erasure_tombstones t WHERE NOT EXISTS(
 SELECT 1 FROM ap_m1.restore_suppression_receipts s WHERE s.restore_id=target AND s.child_id=t.child_id AND s.suppressed_at>=t.erased_at))
 AND NOT EXISTS(SELECT 1 FROM ap_m1.children c JOIN ap_m1.child_erasure_tombstones t ON t.child_id=c.id
 WHERE c.deleted_at IS NULL OR c.deletion_requested_at IS NULL OR c.alias<>'Deleted child' OR c.state<>'SUSPENDED')
$$;
CREATE FUNCTION ap_m1.suppress_restore(target uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE tomb record; total bigint:=0;
BEGIN
 PERFORM 1 FROM ap_m1.restore_runs WHERE id=target FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'unknown restore'; END IF;
 IF NOT ap_m1._restore_ledger_matches(target) THEN
 RAISE EXCEPTION 'current independent ledger import required' USING ERRCODE='42501'; END IF;
 UPDATE ap_m1.restore_runs SET state='REPLAYING',revision=revision+1,updated_at=clock_timestamp() WHERE id=target;
 FOR tomb IN SELECT * FROM ap_m1.child_erasure_tombstones ORDER BY child_id LOOP
 PERFORM ap_m1._purge_child_data(tomb.child_id);
 INSERT INTO ap_m1.restore_suppression_receipts(restore_id,child_id,suppressed_at,proof_sha256)
 VALUES(target,tomb.child_id,clock_timestamp(),public.digest(target::text||':'||tomb.child_id::text,'sha256'))
 ON CONFLICT(restore_id,child_id) DO UPDATE SET suppressed_at=EXCLUDED.suppressed_at,proof_sha256=EXCLUDED.proof_sha256;
 total:=total+1;
 END LOOP;
 UPDATE ap_m1.restore_runs SET state='READY',suppressed_at=clock_timestamp(),revision=revision+1,updated_at=clock_timestamp() WHERE id=target;
 RETURN total;
END $$;
CREATE FUNCTION ap_m1.request_child_export(target uuid, policy uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE result uuid; expiry timestamptz;
BEGIN
 IF NOT ap_m1.has_child_scope_v2(target,'MANAGE_CONSENT') THEN RAISE EXCEPTION 'export denied' USING ERRCODE='42501'; END IF;
 SELECT now()+make_interval(days=>period_days) INTO expiry FROM ap_m1.retention_policy_versions
 WHERE id=policy AND category='DATA_SUBJECT_EXPORT' AND state='APPROVED' AND effective_from<=now();
 IF expiry IS NULL THEN RAISE EXCEPTION 'approved export retention required' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.export_jobs(requester_id,child_id,policy_id,expires_at) VALUES(ap_m1.ctx_principal(),target,policy,expiry) RETURNING id INTO result;
 RETURN result;
END $$;
CREATE TABLE ap_m1.retention_holds (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), category text NOT NULL CHECK(length(category) BETWEEN 1 AND 100),
 subject_ref uuid, legal_reference text NOT NULL CHECK(length(legal_reference) BETWEEN 1 AND 200),
 review_by timestamptz NOT NULL, released_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(review_by>created_at)
);
CREATE FUNCTION ap_m1.purge_expired_privacy_audit() RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE removed bigint:=0; n bigint;
BEGIN
 -- Absence of approved category policy evaluates to NULL, never to forever/zero.
 -- Reviewed holds are protected migration/worker metadata, not a support override.
 DELETE FROM ap_m1.admin_action_audit a WHERE ap_m1.retention_deadline('ADMIN_AUDIT',a.occurred_at)<=statement_timestamp()
 AND NOT EXISTS(SELECT 1 FROM ap_m1.retention_holds h WHERE h.category='ADMIN_AUDIT' AND h.released_at IS NULL
 AND (h.subject_ref IS NULL OR h.subject_ref=a.target_ref));
 GET DIAGNOSTICS n=ROW_COUNT; removed:=removed+n;
 DELETE FROM ap_m1.admin_support_read_audit a WHERE ap_m1.retention_deadline('SUPPORT_ACCESS_AUDIT',a.accessed_at)<=statement_timestamp()
 AND NOT EXISTS(SELECT 1 FROM ap_m1.retention_holds h WHERE h.category='SUPPORT_ACCESS_AUDIT' AND h.released_at IS NULL
 AND (h.subject_ref IS NULL OR h.subject_ref=a.ticket_id));
 GET DIAGNOSTICS n=ROW_COUNT; removed:=removed+n;
 DELETE FROM ap_m1.consent_decision_audit a WHERE ap_m1.retention_deadline('CONSENT_AUDIT',a.occurred_at)<=statement_timestamp()
 AND NOT EXISTS(SELECT 1 FROM ap_m1.retention_holds h WHERE h.category='CONSENT_AUDIT' AND h.released_at IS NULL
 AND (h.subject_ref IS NULL OR h.subject_ref=a.consent_id));
 GET DIAGNOSTICS n=ROW_COUNT; removed:=removed+n;
 DELETE FROM ap_m1.erasure_evidence a WHERE ap_m1.retention_deadline('ERASURE_AUDIT',a.created_at)<=statement_timestamp()
 AND NOT EXISTS(SELECT 1 FROM ap_m1.retention_holds h WHERE h.category='ERASURE_AUDIT' AND h.released_at IS NULL
 AND (h.subject_ref IS NULL OR h.subject_ref=a.job_id));
 GET DIAGNOSTICS n=ROW_COUNT; RETURN removed+n;
END $$;
CREATE FUNCTION ap_m1.verify_erasure_store(target_job uuid, proof bytea) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE j ap_m1.erasure_jobs; kind text;
BEGIN
 SELECT * INTO STRICT j FROM ap_m1.erasure_jobs WHERE id=target_job FOR UPDATE;
 IF proof IS NULL OR octet_length(proof)<>32 OR j.target_store='PRIMARY' THEN RAISE EXCEPTION 'invalid store evidence'; END IF;
 IF j.target_store='BACKUP' THEN
 IF EXISTS(SELECT 1 FROM ap_m1.backup_erasure_manifests WHERE request_id=j.request_id AND state='SUPPRESS_ON_RESTORE')
 THEN RAISE EXCEPTION 'backup expiry or purge evidence still required'; END IF;
 kind:='BACKUP_EXPIRY';
 ELSE kind:='EXTERNAL_ACK'; END IF;
 -- Worker attests actual provider evidence; no ordinary runtime permission.
 INSERT INTO ap_m1.erasure_evidence(job_id,evidence_kind,proof_sha256) VALUES(target_job,kind,proof) ON CONFLICT DO NOTHING;
 UPDATE ap_m1.erasure_jobs SET state='VERIFIED',completed_at=statement_timestamp(),attempts=attempts+1,
 revision=revision+1,updated_at=statement_timestamp() WHERE id=target_job;
 IF NOT EXISTS(SELECT 1 FROM ap_m1.erasure_jobs WHERE request_id=j.request_id AND state<>'VERIFIED') THEN
 UPDATE ap_m1.account_deletion_requests SET state='COMPLETED',completed_at=statement_timestamp(),
 revision=revision+1,updated_at=statement_timestamp() WHERE id=j.request_id;
 END IF;
END $$;
CREATE POLICY own_deletion ON ap_m1.account_deletion_requests FOR SELECT USING(requested_by=ap_m1.ctx_principal());
CREATE POLICY own_export ON ap_m1.export_jobs FOR SELECT USING(requester_id=ap_m1.ctx_principal() AND
 ap_m1.has_child_scope_v2(child_id,'MANAGE_CONSENT') AND expires_at>now());
GRANT SELECT ON ap_m1.account_deletion_requests TO ap_m1_api;
-- Export read excludes encrypted delivery pointer; delivery requires a separate reviewed handler.
GRANT SELECT(id,requester_id,child_id,policy_id,state,requested_at,expires_at,revision,updated_at) ON ap_m1.export_jobs TO ap_m1_api;
GRANT SELECT,INSERT,UPDATE ON ap_m1.account_deletion_requests,ap_m1.erasure_jobs,ap_m1.erasure_job_targets,
 ap_m1.backup_erasure_manifests,ap_m1.restore_runs,ap_m1.restore_suppression_receipts,ap_m1.export_jobs TO ap_db_executor;
GRANT SELECT,INSERT ON ap_m1.erasure_evidence,ap_m1.child_erasure_tombstones TO ap_db_executor;
GRANT SELECT ON ap_m1.backup_inventory,ap_m1.erasure_store_inventory,ap_m1.retention_policy_versions TO ap_db_executor;
GRANT SELECT ON ap_m1.consent_decision_audit TO ap_db_executor;
GRANT EXECUTE ON FUNCTION ap_m1._review_live(uuid) TO ap_db_executor;
GRANT SELECT,UPDATE ON ap_m1.devices,ap_m1.device_key_records,ap_m1.trusted_sessions,ap_m1.child_authority_reviews,
 ap_m1.child_guardian_grants,ap_m1.child_access_invites TO ap_db_executor;
-- Exact allowlisted stores only; do not grant runtime any write/owner/bypass role.
DO $$ DECLARE store record; BEGIN
 FOR store IN SELECT table_name FROM ap_m1.erasure_store_inventory LOOP
 IF to_regclass('ap_m1.'||store.table_name) IS NOT NULL THEN
 EXECUTE format('GRANT SELECT,DELETE ON ap_m1.%I TO ap_db_executor',store.table_name);
 IF store.table_name IN ('premium_viewer_leases','media_sessions','media_command_requests','media_request_device_approvals') THEN
 EXECUTE format('GRANT UPDATE ON ap_m1.%I TO ap_db_executor',store.table_name); END IF;
 END IF;
 END LOOP;
END $$;
GRANT SELECT ON ap_m1.restore_runs,ap_m1.restore_suppression_receipts,ap_m1.child_erasure_tombstones,ap_m1.children TO ap_m1_auth;
GRANT SELECT ON ap_m1.restore_ledger_imports TO ap_db_executor;
GRANT INSERT,UPDATE ON ap_m1.restore_ledger_imports TO ap_db_executor;
ALTER FUNCTION ap_m1._restore_ledger_checkpoint() OWNER TO ap_db_executor;
ALTER FUNCTION ap_m1._restore_ledger_matches(uuid) OWNER TO ap_db_executor;
ALTER FUNCTION ap_m1.import_restore_ledger(uuid,bytea) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1._restore_ledger_checkpoint(),ap_m1._restore_ledger_matches(uuid),ap_m1.import_restore_ledger(uuid,bytea) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1._restore_ledger_matches(uuid) TO ap_m1_auth;
GRANT EXECUTE ON FUNCTION ap_m1.import_restore_ledger(uuid,bytea) TO ap_privacy_worker;
ALTER FUNCTION ap_m1.restore_can_open(uuid) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1._purge_child_data(uuid,uuid) OWNER TO ap_db_executor;
ALTER FUNCTION ap_m1.request_child_erasure(uuid,uuid) OWNER TO ap_db_executor;
ALTER FUNCTION ap_m1.suppress_restore(uuid) OWNER TO ap_db_executor;
ALTER FUNCTION ap_m1.request_child_export(uuid,uuid) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.restore_can_open(uuid),ap_m1._purge_child_data(uuid,uuid),
 ap_m1.request_child_erasure(uuid,uuid),ap_m1.suppress_restore(uuid),ap_m1.request_child_export(uuid,uuid) FROM PUBLIC;
GRANT SELECT ON ap_m1.retention_holds TO ap_db_executor;
GRANT DELETE ON ap_m1.admin_action_audit,ap_m1.admin_support_read_audit,ap_m1.consent_decision_audit,ap_m1.erasure_evidence TO ap_db_executor;
ALTER FUNCTION ap_m1.purge_expired_privacy_audit() OWNER TO ap_db_executor;
ALTER FUNCTION ap_m1.verify_erasure_store(uuid,bytea) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.purge_expired_privacy_audit(),ap_m1.verify_erasure_store(uuid,bytea) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.purge_expired_privacy_audit(),ap_m1.verify_erasure_store(uuid,bytea) TO ap_privacy_worker;
GRANT EXECUTE ON FUNCTION ap_m1.restore_can_open(uuid),ap_m1.suppress_restore(uuid) TO ap_privacy_worker;
GRANT EXECUTE ON FUNCTION ap_m1.request_child_erasure(uuid,uuid),ap_m1.request_child_export(uuid,uuid) TO ap_m1_api;

-- Restricted support projections: no token hash, raw receipt, alias, GPS or media.
CREATE VIEW ap_m1.admin_subscription_support WITH(security_barrier=true) AS
 SELECT p.family_id,p.payer_id,p.sku_id,p.state,p.amount_paise,p.purchased_at,p.verified_at,
 (SELECT count(*) FROM ap_m1.child_seat_assignments s JOIN ap_m1.prepaid_family_batches b ON b.id=s.batch_id
 WHERE b.purchase_id=p.id AND s.removed_at IS NULL) AS assigned_seats
 FROM ap_m1.play_purchase_records p WHERE ap_m1.has_admin_permission('BILLING_READ');
CREATE VIEW ap_m1.admin_billing_reconciliation WITH(security_barrier=true) AS
 SELECT event_type,count(*) AS event_count,max(verified_at) AS last_verified_at
 FROM ap_m1.payment_reconciliation_inbox WHERE ap_m1.has_admin_permission('BILLING_READ') GROUP BY event_type;
GRANT SELECT ON ap_m1.play_purchase_records,ap_m1.child_seat_assignments,ap_m1.prepaid_family_batches,ap_m1.payment_reconciliation_inbox TO ap_db_executor;
ALTER VIEW ap_m1.admin_subscription_support OWNER TO ap_db_executor;
ALTER VIEW ap_m1.admin_billing_reconciliation OWNER TO ap_db_executor;
GRANT SELECT ON ap_m1.admin_subscription_support,ap_m1.admin_billing_reconciliation TO ap_m1_api;

-- Install inventory-driven privileges before forcing RLS. The restricted
-- migration login is not BYPASSRLS: forcing inventory RLS first would make the
-- preceding grant loop silently visit zero stores. The runner commits DDL and
-- these policies atomically; no unprotected intermediate schema is exposed.
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['retention_holds','account_deletion_requests','erasure_jobs','erasure_job_targets','erasure_evidence',
 'backup_inventory','backup_erasure_manifests','restore_runs','restore_suppression_receipts','restore_ledger_imports','export_jobs','erasure_store_inventory'] LOOP
 EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
 END LOOP;
END $$;
