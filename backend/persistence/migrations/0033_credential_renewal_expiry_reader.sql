-- Amar-Pola V2 migration v0033 -- PostgreSQL 16+.
-- Narrow reader for credential renewal challenge expiry.
-- Renewal uses the separate issuer login; do not grant direct table reads
-- to the runtime API role.

CREATE FUNCTION ap_m1.read_renewal_challenge_expiry(challenge uuid)
RETURNS timestamptz LANGUAGE sql SECURITY DEFINER
SET search_path=pg_catalog,ap_m1 AS $$
 SELECT expires_at FROM ap_m1.credential_renewal_challenges WHERE id=challenge
$$;

ALTER FUNCTION ap_m1.read_renewal_challenge_expiry(uuid) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.read_renewal_challenge_expiry(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.read_renewal_challenge_expiry(uuid) TO ap_auth_issuer;
