-- Historical M1-only adapter, immediately before immutable V2 0016.
-- Runner owns transaction. Never run on the clean V2 lineage.
-- Renaming the PK constraint also renames its schema-global backing index.
-- No rows or IDs are changed. 0017 merges these rows before removing the staging table.
DO $bridge$
DECLARE item record;
BEGIN
 IF to_regclass('ap_m1.credential_renewal_challenges') IS NULL OR
    NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='ap_m1.credential_renewal_challenges'::regclass
      AND attname='key_id' AND atttypid='uuid'::regtype AND NOT attisdropped) THEN
   RAISE EXCEPTION 'pre-0016 bridge requires historical M1 UUID renewal challenges';
 END IF;
 ALTER TABLE ap_m1.credential_renewal_challenges RENAME TO m1_historical_renewal_challenges;
 -- Generated check/FK names also avoid existing schema-wide names. Move every
 -- historical constraint (including its PK index) out of the canonical namespace.
 FOR item IN SELECT oid,conname FROM pg_constraint
   WHERE conrelid='ap_m1.m1_historical_renewal_challenges'::regclass LOOP
  EXECUTE format('ALTER TABLE ap_m1.m1_historical_renewal_challenges RENAME CONSTRAINT %I TO %I',
    item.conname,'m1_staged_'||item.oid);
 END LOOP;
END $bridge$;
