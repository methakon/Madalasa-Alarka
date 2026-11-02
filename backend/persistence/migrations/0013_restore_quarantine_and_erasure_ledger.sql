-- Recovery metadata is deliberately outside the application snapshot namespace.
-- Do not include this schema in ordinary application dumps or reset it during
-- restore: newer erasure tombstones must survive an older application backup.
CREATE SCHEMA IF NOT EXISTS ma_recovery AUTHORIZATION ap_m1_owner;
REVOKE ALL ON SCHEMA ma_recovery FROM PUBLIC;
GRANT USAGE,CREATE ON SCHEMA ma_recovery TO ap_db_executor;
CREATE TABLE IF NOT EXISTS ma_recovery.erasure_ledger (
 child_id uuid PRIMARY KEY,
 erased_at timestamptz NOT NULL,
 reason_code text NOT NULL CHECK(length(reason_code) BETWEEN 1 AND 80),
 recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS ma_recovery.control (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 quarantined boolean NOT NULL DEFAULT false,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT now()
);
-- Backfill without widening access or creating a restored child identity.
GRANT SELECT,INSERT,UPDATE ON ma_recovery.erasure_ledger TO ap_db_executor;
GRANT INSERT ON ma_recovery.control TO ap_db_executor;
SET LOCAL ROLE ap_db_executor;
INSERT INTO ma_recovery.control(singleton) VALUES(true) ON CONFLICT DO NOTHING;
INSERT INTO ma_recovery.erasure_ledger(child_id,erased_at,reason_code)
 SELECT child_id,erased_at,reason_code FROM ap_m1.child_erasure_tombstones
 ON CONFLICT(child_id) DO UPDATE SET erased_at=LEAST(erasure_ledger.erased_at,EXCLUDED.erased_at);
RESET ROLE;
REVOKE INSERT ON ma_recovery.control FROM ap_db_executor;
CREATE OR REPLACE FUNCTION ma_recovery.remember_erasure() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ma_recovery AS $fn$
BEGIN
 INSERT INTO ma_recovery.erasure_ledger(child_id,erased_at,reason_code)
 VALUES(NEW.child_id,NEW.erased_at,NEW.reason_code)
 ON CONFLICT(child_id) DO UPDATE SET erased_at=LEAST(erasure_ledger.erased_at,EXCLUDED.erased_at);
 RETURN NEW;
END $fn$;
ALTER FUNCTION ma_recovery.remember_erasure() OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ma_recovery.remember_erasure() FROM PUBLIC;
CREATE TRIGGER remember_child_erasure AFTER INSERT ON ap_m1.child_erasure_tombstones
 FOR EACH ROW EXECUTE FUNCTION ma_recovery.remember_erasure();
CREATE OR REPLACE FUNCTION ma_recovery.database_open() RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ma_recovery AS $fn$
 SELECT EXISTS(SELECT 1 FROM ma_recovery.control WHERE singleton AND NOT quarantined);
$fn$;
ALTER FUNCTION ma_recovery.database_open() OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ma_recovery.database_open() FROM PUBLIC;
GRANT USAGE ON SCHEMA ma_recovery TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ma_recovery.database_open() TO ap_m1_api;
GRANT SELECT,INSERT,UPDATE ON ma_recovery.erasure_ledger TO ap_db_executor;
GRANT SELECT ON ma_recovery.control TO ap_db_executor;
ALTER TABLE ma_recovery.erasure_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE ma_recovery.erasure_ledger FORCE ROW LEVEL SECURITY;
ALTER TABLE ma_recovery.control ENABLE ROW LEVEL SECURITY;
ALTER TABLE ma_recovery.control FORCE ROW LEVEL SECURITY;
ALTER TABLE ma_recovery.erasure_ledger OWNER TO ap_m1_owner;
ALTER TABLE ma_recovery.control OWNER TO ap_m1_owner;
