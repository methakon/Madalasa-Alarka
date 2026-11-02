-- Dedicated login role for the scheduled retention jobs (deployment step, NOT a migration: it carries a secret).
-- Run once per environment as a role that may create roles:
--   psql -d <database> -v ON_ERROR_STOP=1 -v ma_purge_password="$(cat /path/to/generated-secret)" -f ma_purge_role.sql
-- Least privilege: the three purge functions are SECURITY DEFINER, so the caller needs EXECUTE on them and USAGE on the schema,
-- and nothing else. It is deliberately NOT a member of ap_m1_owner (which owns every table).
-- Works on PostgreSQL 15 and 16. SYNTHETIC DATA ONLY in test environments.
BEGIN;
CREATE ROLE ma_purge LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS
  CONNECTION LIMIT 2 PASSWORD :'ma_purge_password';
GRANT USAGE ON SCHEMA ap_m1 TO ma_purge;
GRANT EXECUTE ON FUNCTION ap_m1.purge_credential_artifacts(interval, interval, interval) TO ma_purge;
GRANT EXECUTE ON FUNCTION ap_m1.purge_idempotency_keys(interval) TO ma_purge;
GRANT EXECUTE ON FUNCTION ap_m1.purge_pairing_codes(interval) TO ma_purge;
COMMIT;
