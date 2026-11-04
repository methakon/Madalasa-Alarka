-- Additive E04 correction. Published migrations remain unchanged.
-- No retention duration, hold-release authority, archive deletion or external
-- store completion is decided here. Unresolvable scope/holds abort atomically.
GRANT INSERT,UPDATE ON ap_m1.erasure_store_inventory TO ap_db_executor;
SET LOCAL ROLE ap_db_executor;
-- 0 is unused in the preceding inventory. Bundles reference cases at order 4.
UPDATE ap_m1.erasure_store_inventory SET purge_order=0
 WHERE table_name='compliance_export_bundles' AND key_kind='CHILD';
INSERT INTO ap_m1.erasure_store_inventory(table_name,key_kind,purge_order)
 VALUES('child_device_pairing_log','CHILD',441);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM ap_m1.erasure_store_inventory b
   JOIN ap_m1.erasure_store_inventory c ON c.table_name='admin_cases'
   WHERE b.table_name='compliance_export_bundles' AND b.key_kind='CHILD'
     AND c.key_kind='CHILD' AND b.purge_order<c.purge_order) THEN
   RAISE EXCEPTION 'compliance bundle/case erasure dependency unresolved' USING ERRCODE='55000';
 END IF;
END $$;
RESET ROLE;
REVOKE INSERT,UPDATE ON ap_m1.erasure_store_inventory FROM ap_db_executor;
-- Same privileged purge executor as the other registered child stores. No
-- parent/API grants and no RLS relaxation for runtime callers.
GRANT SELECT,DELETE ON ap_m1.child_device_pairing_log TO ap_db_executor;

-- The executor has SELECT, not UPDATE/DELETE, on holds. Keep the lock-only
-- capability with the migration/table owner rather than grant hold mutation.
-- No parameters, dynamic SQL, data reads/writes or runtime caller grants.
CREATE FUNCTION ap_m1._lock_erasure_holds() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
BEGIN
 LOCK TABLE ap_m1.retention_holds IN SHARE ROW EXCLUSIVE MODE;
END $$;
ALTER FUNCTION ap_m1._lock_erasure_holds() OWNER TO CURRENT_USER;
REVOKE ALL ON FUNCTION ap_m1._lock_erasure_holds() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1._lock_erasure_holds() TO ap_db_executor;

CREATE OR REPLACE FUNCTION ap_m1._purge_child_data(target uuid, primary_job uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE store record; removed bigint;
BEGIN
 PERFORM 1 FROM ap_m1.devices WHERE child_id=target ORDER BY id FOR UPDATE;
 PERFORM 1 FROM ap_m1.children WHERE id=target FOR UPDATE;
 -- Serialize scope/hold checks with writes to these stores until transaction
 -- end. These are fences, not an interpretation or release of a legal hold.
 LOCK TABLE ap_m1.compliance_export_bundles IN SHARE ROW EXCLUSIVE MODE;
 PERFORM ap_m1._lock_erasure_holds();
 -- A family-wide (or globally unscoped) archive has no provable exact-child
 -- membership. Never delete siblings' archive or report a complete primary
 -- purge while this unresolved reference could still contain the subject.
 IF EXISTS(SELECT 1 FROM ap_m1.compliance_export_bundles b
   WHERE b.child_id IS NULL AND (b.target_family_id IS NULL OR
     NOT EXISTS(SELECT 1 FROM ap_m1.children WHERE id=target) OR
     b.target_family_id=(SELECT family_id FROM ap_m1.children WHERE id=target))) THEN
   RAISE EXCEPTION 'unresolved compliance bundle subject scope' USING ERRCODE='55000';
 END IF;
 -- Unknown category mapping cannot authorize deleting held subject records.
 -- Refuse relevant explicit subject references (or global holds), irrespective
 -- of review date; only released_at denotes release in the existing schema.
 IF EXISTS(SELECT 1 FROM ap_m1.retention_holds h WHERE h.released_at IS NULL AND (
   h.subject_ref IS NULL OR h.subject_ref=target
   OR h.subject_ref=(SELECT family_id FROM ap_m1.children WHERE id=target)
   OR h.subject_ref IN (SELECT id FROM ap_m1.devices WHERE child_id=target)
   OR h.subject_ref IN (SELECT id FROM ap_m1.admin_cases WHERE child_id=target)
   OR h.subject_ref IN (SELECT id FROM ap_m1.compliance_export_bundles WHERE child_id=target)
   OR h.subject_ref IN (SELECT id FROM ap_m1.child_device_pairing_log WHERE child_id=target)
 )) THEN
   RAISE EXCEPTION 'unreleased erasure subject hold requires resolution' USING ERRCODE='55000';
 END IF;
 -- Persistent tombstone deliberately has no FK requiring resurrection of child identity.
 INSERT INTO ap_m1.child_erasure_tombstones(child_id,reason_code) VALUES(target,'AUTHORIZED_ERASURE') ON CONFLICT(child_id) DO NOTHING;
 UPDATE ap_m1.children SET deletion_requested_at=coalesce(deletion_requested_at,clock_timestamp()),
 deleted_at=coalesce(deleted_at,clock_timestamp()),alias='Deleted child',state='SUSPENDED' WHERE id=target;
 UPDATE ap_m1.devices SET enrollment_state='REVOKED',revoked_at=coalesce(revoked_at,clock_timestamp()),
 spki_public_key=decode(repeat('00',80),'hex'),reported_manufacturer=NULL,
 reported_model=NULL,reported_android_api=NULL,reported_app_version=NULL WHERE child_id=target;
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
 -- Existing allowlist purge/evidence behavior is retained. An error in any
 -- store rolls back the whole request or restore, including its certificates.
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
ALTER FUNCTION ap_m1._purge_child_data(uuid,uuid) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1._purge_child_data(uuid,uuid) FROM PUBLIC;
