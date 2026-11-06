-- Additive follow-up to the inventory hold fence. Existing SQL stays immutable.
-- A table lock cannot refresh REPEATABLE READ / SERIALIZABLE snapshots. Refuse
-- inventory deletion at unsupported isolation rather than miss a committed hold.
CREATE OR REPLACE FUNCTION ap_m1._refuse_held_inventory_delete() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE identities text[];
BEGIN
 IF current_setting('transaction_isolation') <> 'read committed' THEN
   RAISE EXCEPTION 'held inventory deletion requires read committed isolation' USING ERRCODE='55000';
 END IF;
 PERFORM ap_m1._lock_erasure_holds();
 SELECT array_agg(to_jsonb(OLD)->>a.attname) INTO identities
 FROM pg_attribute a WHERE a.attrelid=TG_RELID AND a.attnum>0
 AND NOT a.attisdropped AND a.atttypid='uuid'::regtype;
 IF identities IS NULL THEN
   RAISE EXCEPTION 'unresolved erasure inventory identity' USING ERRCODE='55000';
 END IF;
 IF EXISTS(SELECT 1 FROM ap_m1.retention_holds h
   WHERE h.released_at IS NULL AND
     (h.subject_ref IS NULL OR h.subject_ref::text=ANY(identities))) THEN
   RAISE EXCEPTION 'unreleased inventory subject hold requires resolution' USING ERRCODE='55000';
 END IF;
 RETURN OLD;
END $$;
-- CREATE OR REPLACE preserves executor ownership and the private ACL.
