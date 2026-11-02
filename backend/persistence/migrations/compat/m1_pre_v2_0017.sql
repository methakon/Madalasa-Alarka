-- Apply on BOTH lineages immediately before published 0017, AFTER V2 0016.
-- Runner owns transaction. 0017 drops the historical renewal staging relation;
-- preserve its hold flags separately, including false, before that destructive DDL.
-- No runtime/issuer policies, grants, or executable surface. Not an authority store.
CREATE TABLE ap_m1.m1_renewal_hold_preservation (
 challenge_id uuid PRIMARY KEY,
 retention_hold boolean NOT NULL
);
ALTER TABLE ap_m1.m1_renewal_hold_preservation OWNER TO ap_m1_owner;
ALTER TABLE ap_m1.m1_renewal_hold_preservation ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.m1_renewal_hold_preservation FORCE ROW LEVEL SECURITY;
REVOKE ALL ON ap_m1.m1_renewal_hold_preservation FROM PUBLIC,ap_m1_api,ap_m1_auth,ap_auth_issuer;
GRANT SELECT,INSERT ON ap_m1.m1_renewal_hold_preservation TO ap_db_executor;
DO $grant_source$
BEGIN
 IF to_regclass('ap_m1.m1_historical_renewal_challenges') IS NOT NULL THEN
  GRANT SELECT ON ap_m1.m1_historical_renewal_challenges TO ap_db_executor;
 END IF;
END $grant_source$;
SET LOCAL ROLE ap_db_executor;
DO $preserve$
BEGIN
 IF to_regclass('ap_m1.m1_historical_renewal_challenges') IS NOT NULL
 AND EXISTS(SELECT 1 FROM pg_attribute
  WHERE attrelid=to_regclass('ap_m1.m1_historical_renewal_challenges')
  AND attname='retention_hold' AND NOT attisdropped) THEN
  INSERT INTO ap_m1.m1_renewal_hold_preservation(challenge_id,retention_hold)
   SELECT id,retention_hold FROM ap_m1.m1_historical_renewal_challenges;
 END IF;
END $preserve$;
RESET ROLE;
REVOKE INSERT ON ap_m1.m1_renewal_hold_preservation FROM ap_db_executor;
