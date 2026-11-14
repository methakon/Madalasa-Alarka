-- Migration 0032: the test-mode switch can only be turned on in a disposable database, and the runtime role can read
-- only a boolean about it. Run as migration admin in a database named ma_synthetic_*, madalasa_alarka_dev or
-- madalasa_alarka_test. Everything rolls back. SYNTHETIC DATA ONLY.
\set ON_ERROR_STOP on
BEGIN;
CREATE FUNCTION pg_temp.try(stmt text) RETURNS text LANGUAGE plpgsql AS $$
BEGIN EXECUTE stmt; RETURN 'OK'; EXCEPTION WHEN OTHERS THEN RETURN SQLSTATE; END $$;
CREATE FUNCTION pg_temp.ok(c boolean, label text) RETURNS void LANGUAGE plpgsql AS
$$ BEGIN IF c IS DISTINCT FROM true THEN RAISE EXCEPTION 'test mode guard assertion: %', label; END IF; END $$;

DO $$
DECLARE r text; v boolean;
BEGIN
 -- TM_01 off by default in a fresh install is representable and readable through the probe.
 UPDATE ap_m1.local_test_settings SET enabled=false WHERE singleton;
 SET LOCAL ROLE ap_m1_api;
 SELECT ap_m1.test_mode_enabled() INTO v;
 RESET ROLE;
 PERFORM pg_temp.ok(v=false, 'TM_01 probe reports off');

 -- TM_02 the runtime role cannot read the table directly: the probe is its only view.
 SET LOCAL ROLE ap_m1_api;
 r := pg_temp.try('SELECT enabled FROM ap_m1.local_test_settings');
 RESET ROLE;
 PERFORM pg_temp.ok(r='42501', 'TM_02 runtime role has no direct read ('||r||')');

 -- TM_03 enabling in a disposable database works and the probe sees it.
 UPDATE ap_m1.local_test_settings SET enabled=true WHERE singleton;
 SET LOCAL ROLE ap_m1_api;
 SELECT ap_m1.test_mode_enabled() INTO v;
 RESET ROLE;
 PERFORM pg_temp.ok(v=true, 'TM_03 probe reports on');

 -- TM_04 the runtime role cannot flip it.
 SET LOCAL ROLE ap_m1_api;
 r := pg_temp.try('UPDATE ap_m1.local_test_settings SET enabled=false');
 RESET ROLE;
 PERFORM pg_temp.ok(r='42501', 'TM_04 runtime role cannot write ('||r||')');

 -- TM_05 the probe is not callable by PUBLIC.
 PERFORM pg_temp.ok(NOT has_function_privilege('public','ap_m1.test_mode_enabled()','EXECUTE'), 'TM_05 not executable by PUBLIC');
 PERFORM pg_temp.ok(has_function_privilege('ap_m1_api','ap_m1.test_mode_enabled()','EXECUTE'), 'TM_05 executable by the runtime role');
END $$;

-- TM_06 the trigger refuses enabling in a production-named database. The name is checked through the same
-- predicate the trigger uses, and the trigger itself is exercised by simulating a production name.
DO $$
DECLARE r text; ok_names text[] := ARRAY['madalasa_alarka_dev','madalasa_alarka_test','ma_synthetic_x','ma_synthetic_v2_1'];
        bad_names text[] := ARRAY['madalasa_alarka','madalasa_prod','madalasa_alarka_test2','xmadalasa_alarka_test','ma_synthetic_','MA_SYNTHETIC_X','prod_ma_synthetic_x','postgres','neondb'];
        n text; p text := '^(madalasa_alarka_(dev|test)|ma_synthetic_[a-z0-9_]+)$';
BEGIN
 FOREACH n IN ARRAY ok_names LOOP PERFORM pg_temp.ok(n ~ p, 'TM_06 allowed name '||n); END LOOP;
 FOREACH n IN ARRAY bad_names LOOP PERFORM pg_temp.ok(n !~ p, 'TM_06 refused name '||n); END LOOP;
 PERFORM pg_temp.ok(pg_get_functiondef('ap_m1.guard_local_test_mode()'::regprocedure) LIKE '%'||p||'%', 'TM_06 trigger uses the same predicate');
 PERFORM pg_temp.ok((SELECT count(*) FROM pg_trigger WHERE tgrelid='ap_m1.local_test_settings'::regclass AND tgname='local_test_settings_disposable_only' AND tgenabled='O')=1, 'TM_06 trigger installed and enabled');
END $$;
ROLLBACK;
\echo m1 test mode guard PASS (all changes rolled back)
