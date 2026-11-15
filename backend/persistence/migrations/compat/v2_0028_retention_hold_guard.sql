-- Additive post-0028 compatibility fence, not a rewrite of published SQL.
-- Inventory-wide BEFORE DELETE guards protect explicitly held row identities,
-- including batches and media sessions omitted from 0028's subject allowlist.
-- No hold-release authority, review-date expiry or retention duration is inferred.
CREATE FUNCTION ap_m1._refuse_held_inventory_delete() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE identities text[];
BEGIN
 -- Serialize with hold issuance/release before reading its committed state.
 -- Purge already holds this lock; this also fences direct maintenance deletes.
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
ALTER FUNCTION ap_m1._refuse_held_inventory_delete() OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1._refuse_held_inventory_delete() FROM PUBLIC;
-- FORCE-RLS inventory is read through the trusted executor. This temporary
-- migration-only bridge exposes target names, never subject records.
CREATE FUNCTION ap_m1._hold_guard_inventory_targets() RETURNS SETOF text
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
 SELECT table_name::text FROM ap_m1.erasure_store_inventory ORDER BY purge_order
$$;
ALTER FUNCTION ap_m1._hold_guard_inventory_targets() OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1._hold_guard_inventory_targets() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1._hold_guard_inventory_targets() TO CURRENT_USER;
DO $$
DECLARE store record;
BEGIN
 FOR store IN SELECT ap_m1._hold_guard_inventory_targets() AS table_name LOOP
   IF to_regclass('ap_m1.'||store.table_name) IS NULL THEN
     -- The published inventory retains conceptual/retired aliases; 0028 skips
     -- these too. Guard every physical table without inventing new stores.
     CONTINUE;
   END IF;
   EXECUTE format('CREATE TRIGGER refuse_held_inventory_delete BEFORE DELETE ON ap_m1.%I '
     'FOR EACH ROW EXECUTE FUNCTION ap_m1._refuse_held_inventory_delete()',store.table_name);
 END LOOP;
END $$;
DROP FUNCTION ap_m1._hold_guard_inventory_targets();
