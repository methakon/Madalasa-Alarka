-- Production guard for the database test-mode switch (ap_m1.local_test_settings.enabled).
-- When the switch is on, LOCAL_TEST_APPROVED verification, synthetic purchase evidence and synthetic session minting
-- become usable inside the schema. Two independent layers keep that out of a real deployment:
--   1. The switch can only be turned ON in a database whose name marks it disposable:
--      madalasa_alarka_dev, madalasa_alarka_test, or ma_synthetic_<name>. A production database must not use
--      those names. (A superuser could still drop the trigger on purpose; that is a deliberate DDL act, not a
--      mistaken UPDATE.)
--   2. ap_m1.test_mode_enabled() lets the runtime role read ONLY that one boolean, so the backend can notice a
--      switch that is on anyway and refuse to serve. The runtime role has no SELECT on the table itself.
-- SYNTHETIC DATA ONLY in every test database.

CREATE FUNCTION ap_m1.guard_local_test_mode() RETURNS trigger
 LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF NEW.enabled AND current_database() !~ '^(madalasa_alarka_(dev|test)|ma_synthetic_[a-z0-9_]+)$' THEN
  RAISE EXCEPTION 'test mode may only be enabled in a disposable database (madalasa_alarka_dev, madalasa_alarka_test or ma_synthetic_*)'
   USING ERRCODE='42501';
 END IF;
 RETURN NEW;
END $$;

CREATE TRIGGER local_test_settings_disposable_only
 BEFORE INSERT OR UPDATE OF enabled ON ap_m1.local_test_settings
 FOR EACH ROW EXECUTE FUNCTION ap_m1.guard_local_test_mode();

CREATE FUNCTION ap_m1.test_mode_enabled() RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
 SELECT COALESCE((SELECT s.enabled FROM ap_m1.local_test_settings s WHERE s.singleton),false)
$$;
ALTER FUNCTION ap_m1.test_mode_enabled() OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.test_mode_enabled() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.test_mode_enabled() TO ap_m1_api;
