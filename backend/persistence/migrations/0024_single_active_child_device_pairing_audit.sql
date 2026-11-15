-- QR-ready pairing audit and one ACTIVE device per child.
-- This is additive. Pairing code/HTTP enrollment remain supported as fallback.
-- Device descriptions are untrusted, optional metadata. Only verified proof
-- activation creates an audit receipt. No IMEI/serial/advertising IDs collected.
-- Existing duplicate ACTIVE child devices are a MIGRATION BLOCKER: resolve
-- with explicit authorized revocation before applying, never silently choose.
DO $precheck$
BEGIN
 IF EXISTS(
  SELECT 1 FROM ap_m1.devices d
  WHERE d.enrollment_state='ACTIVE' AND d.revoked_at IS NULL
  GROUP BY d.child_id HAVING count(*)>1
 ) THEN
  RAISE EXCEPTION 'Multiple active devices exist for a child. Review/revoke before v2:0024.'
    USING ERRCODE='23505';
 END IF;
END $precheck$;

-- This index is the authoritative race-safe concurrency fence, regardless
-- of which endpoint activates an M1 or V2 device, including direct SQL calls.
CREATE UNIQUE INDEX ux_one_active_alarka_per_child
 ON ap_m1.devices(child_id)
 WHERE enrollment_state='ACTIVE' AND revoked_at IS NULL;

ALTER TABLE ap_m1.devices
 ADD COLUMN pairing_method text NOT NULL DEFAULT 'PARENT_CODE'
   CHECK (pairing_method IN ('PARENT_CODE','QR_APPROVED')),
 ADD COLUMN reported_manufacturer text CHECK (reported_manufacturer IS NULL OR char_length(reported_manufacturer)<=80),
 ADD COLUMN reported_model text CHECK (reported_model IS NULL OR char_length(reported_model)<=120),
 ADD COLUMN reported_android_api integer CHECK (reported_android_api IS NULL OR reported_android_api BETWEEN 29 AND 45),
 ADD COLUMN reported_app_version text CHECK (reported_app_version IS NULL OR char_length(reported_app_version)<=60);

CREATE TABLE ap_m1.child_device_pairing_log (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id) ON DELETE CASCADE,
 family_id uuid NOT NULL REFERENCES ap_m1.families(id) ON DELETE CASCADE,
 device_id uuid NOT NULL UNIQUE,
 pairing_method text NOT NULL CHECK (pairing_method IN ('PARENT_CODE','QR_APPROVED')),
 reported_manufacturer text,
 reported_model text,
 reported_android_api integer,
 reported_app_version text,
 key_fingerprint_sha256 bytea NOT NULL CHECK (octet_length(key_fingerprint_sha256)=32),
 paired_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 unpaired_at timestamptz,
 CHECK (unpaired_at IS NULL OR unpaired_at>=paired_at)
);
CREATE INDEX child_device_pairing_history_idx
 ON ap_m1.child_device_pairing_log(child_id,paired_at DESC);
ALTER TABLE ap_m1.child_device_pairing_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.child_device_pairing_log FORCE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.child_device_pairing_log OWNER TO ap_m1_owner;

-- Only the backend enrollment/revocation definer and guarded support workers
-- write logs; parent viewers must use a scoped API, not a table SELECT.
CREATE POLICY child_device_pairing_log_auth_write
 ON ap_m1.child_device_pairing_log FOR ALL TO ap_m1_auth
 USING(true) WITH CHECK(true);
GRANT SELECT,INSERT,UPDATE,DELETE ON ap_m1.child_device_pairing_log TO ap_m1_auth;

-- Called only inside the same backend transaction as redeem_pairing_code,
-- with the UUID returned from that one-time code. It does NOT authenticate a
-- device; the activated log row is written later only after P-256 proof.
CREATE FUNCTION ap_m1.store_pending_device_profile(
 p_enrollment uuid, p_manufacturer text, p_model text,
 p_android_api integer, p_app_version text, p_method text
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
DECLARE v_device uuid;
BEGIN
 IF (p_method IS NULL OR p_method NOT IN ('PARENT_CODE','QR_APPROVED')
     OR p_manufacturer IS NULL OR char_length(p_manufacturer)>80
     OR p_model IS NULL OR char_length(p_model)>120
     OR p_android_api NOT BETWEEN 29 AND 45
     OR p_app_version IS NULL OR char_length(p_app_version)>60) THEN
   RETURN false;
 END IF;
 SELECT d.id INTO v_device
 FROM ap_m1.enrollment_challenges c JOIN ap_m1.devices d ON d.id=c.device_id
 WHERE c.id=p_enrollment AND c.consumed_at IS NULL
  AND c.expires_at>statement_timestamp()
  AND d.enrollment_state='PENDING_PROOF' AND d.revoked_at IS NULL
 FOR UPDATE OF d;
 IF NOT FOUND THEN RETURN false; END IF;
 UPDATE ap_m1.devices SET
  pairing_method=p_method,reported_manufacturer=left(p_manufacturer,80),
  reported_model=left(p_model,120),reported_android_api=p_android_api,
  reported_app_version=p_app_version
 WHERE id=v_device;
 RETURN true;
END $fn$;
ALTER FUNCTION ap_m1.store_pending_device_profile(uuid,text,text,integer,text,text) OWNER TO ap_m1_auth;
REVOKE ALL ON FUNCTION ap_m1.store_pending_device_profile(uuid,text,text,integer,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.store_pending_device_profile(uuid,text,text,integer,text,text) TO ap_m1_api;

-- Persist successful device metadata as a receipt only on P-256-verified
-- activation. The code path performs key verification BEFORE this update.
CREATE FUNCTION ap_m1.log_pairing_after_device_state_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
BEGIN
 IF NEW.enrollment_state='ACTIVE' AND OLD.enrollment_state IS DISTINCT FROM 'ACTIVE'
    AND NEW.revoked_at IS NULL THEN
   INSERT INTO ap_m1.child_device_pairing_log(
     child_id,family_id,device_id,pairing_method,reported_manufacturer,
     reported_model,reported_android_api,reported_app_version,key_fingerprint_sha256
   ) VALUES (
     NEW.child_id,NEW.family_id,NEW.id,NEW.pairing_method,
     NEW.reported_manufacturer,NEW.reported_model,NEW.reported_android_api,
     NEW.reported_app_version,sha256(NEW.spki_public_key)
   );
 ELSIF (NEW.revoked_at IS NOT NULL OR NEW.enrollment_state='REVOKED')
       AND OLD.enrollment_state='ACTIVE' THEN
   UPDATE ap_m1.child_device_pairing_log
   SET unpaired_at=coalesce(unpaired_at,clock_timestamp())
   WHERE device_id=NEW.id;
 END IF;
 RETURN NEW;
END $fn$;
ALTER FUNCTION ap_m1.log_pairing_after_device_state_change() OWNER TO ap_m1_auth;
REVOKE ALL ON FUNCTION ap_m1.log_pairing_after_device_state_change() FROM PUBLIC;
CREATE TRIGGER child_device_pairing_success_and_revocation_log
 AFTER UPDATE OF enrollment_state,revoked_at ON ap_m1.devices
 FOR EACH ROW EXECUTE FUNCTION ap_m1.log_pairing_after_device_state_change();

-- Existing active devices predate this audit. Only one per child was allowed
-- by the migration precheck; preserve them with unavailable metadata.
INSERT INTO ap_m1.child_device_pairing_log (
 child_id,family_id,device_id,pairing_method,reported_manufacturer,
 reported_model,reported_android_api,reported_app_version,key_fingerprint_sha256,paired_at
)
SELECT d.child_id,d.family_id,d.id,d.pairing_method,d.reported_manufacturer,
 d.reported_model,d.reported_android_api,d.reported_app_version,
 sha256(d.spki_public_key),d.created_at
FROM ap_m1.devices d
WHERE d.enrollment_state='ACTIVE' AND d.revoked_at IS NULL
ON CONFLICT(device_id) DO NOTHING;

-- No direct SELECT/UPDATE privileges for ap_m1_api or arbitrary guardians.
-- Key fingerprint and model are informational; QR nonce is never stored here.

-- Security-definer read for the guardian pairing endpoint; never expose
-- raw devices to an arbitrary parent or trust client-side cached state.
CREATE FUNCTION ap_m1.child_has_live_alarka_device(p_child uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
 SELECT EXISTS(
   SELECT 1 FROM ap_m1.devices
   WHERE child_id=p_child AND enrollment_state='ACTIVE' AND revoked_at IS NULL
 )
$fn$;
ALTER FUNCTION ap_m1.child_has_live_alarka_device(uuid) OWNER TO ap_m1_auth;
REVOKE ALL ON FUNCTION ap_m1.child_has_live_alarka_device(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.child_has_live_alarka_device(uuid) TO ap_m1_api;

-- Minimized parent-facing device detail: exact-child guardian scope, no
-- secrets, no raw SPKI, no IMEI/serial or credential token.
CREATE FUNCTION ap_m1.child_active_device_summary(p_child uuid)
RETURNS TABLE(device_id uuid,manufacturer text,model text,android_api integer,
              app_version text,method text,paired_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
 SELECT d.id,d.reported_manufacturer,d.reported_model,d.reported_android_api,
        d.reported_app_version,d.pairing_method,l.paired_at
 FROM ap_m1.devices d
 LEFT JOIN ap_m1.child_device_pairing_log l ON l.device_id=d.id
 WHERE d.child_id=p_child AND d.enrollment_state='ACTIVE' AND d.revoked_at IS NULL
   AND ap_m1.has_child_scope_v2(p_child,'VIEW_CHILD_PROFILE')
 ORDER BY d.created_at DESC LIMIT 1
$fn$;
ALTER FUNCTION ap_m1.child_active_device_summary(uuid) OWNER TO ap_m1_auth;
REVOKE ALL ON FUNCTION ap_m1.child_active_device_summary(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.child_active_device_summary(uuid) TO ap_m1_api;

-- Erasure is stronger than a pairing audit retention preference: a durable
-- child-erasure tombstone removes this personal-device pairing history.
CREATE FUNCTION ap_m1._erase_child_pairing_logs_on_tombstone() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $fn$
BEGIN
 DELETE FROM ap_m1.child_device_pairing_log WHERE child_id=NEW.child_id;
 RETURN NEW;
END $fn$;
ALTER FUNCTION ap_m1._erase_child_pairing_logs_on_tombstone() OWNER TO ap_m1_auth;
REVOKE ALL ON FUNCTION ap_m1._erase_child_pairing_logs_on_tombstone() FROM PUBLIC;
CREATE TRIGGER purge_child_pairing_audit_after_erasure
 AFTER INSERT ON ap_m1.child_erasure_tombstones
 FOR EACH ROW EXECUTE FUNCTION ap_m1._erase_child_pairing_logs_on_tombstone();
