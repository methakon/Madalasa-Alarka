-- V2 0022: trusted Google -> server-controlled admin session bridge, CSRF binding
-- and the back-office read paths the admin panel needs. Runner owns the transaction.
-- SYNTHETIC DATA ONLY until legal/Play gates close.
--
-- * Login nonce + login-state are generated HERE, single use, 5 minutes. The C++
--   verifier checks the Google signature, audience, freshness, email_verified and
--   that the token's nonce equals the challenge nonce; SQL then consumes the
--   challenge only when BOTH the nonce and the browser-bound state match.
-- * Only the dedicated ap_auth_issuer login (never ap_m1_api) may issue challenges
--   or exchange identities. Tokens are stored only as SHA-256.
-- * Every admin session carries a session-bound CSRF secret (hash only).
-- * Owner MFA is NOT implemented here: mfa_until stays NULL, so step-up
--   permissions (OWNER_MANAGE, FAQ_PUBLISH, AUDIT_READ) remain denied.

CREATE TABLE ap_m1.admin_login_challenges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 nonce_sha256 bytea NOT NULL UNIQUE CHECK(octet_length(nonce_sha256)=32),
 state_sha256 bytea NOT NULL CHECK(octet_length(state_sha256)=32),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL,
 consumed_at timestamptz,
 CHECK(expires_at>created_at AND expires_at<=created_at+interval '5 minutes')
);
CREATE INDEX admin_login_challenge_expiry ON ap_m1.admin_login_challenges(expires_at);
ALTER TABLE ap_m1.admin_login_challenges OWNER TO ap_m1_owner;
ALTER TABLE ap_m1.admin_login_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.admin_login_challenges FORCE ROW LEVEL SECURITY;
REVOKE ALL ON ap_m1.admin_login_challenges FROM PUBLIC,ap_m1_api,ap_auth_issuer,ap_m1_auth;
GRANT SELECT,INSERT,UPDATE,DELETE ON ap_m1.admin_login_challenges TO ap_db_executor;

ALTER TABLE ap_m1.admin_sessions ADD COLUMN csrf_sha256 bytea CHECK(octet_length(csrf_sha256)=32);

CREATE FUNCTION ap_m1.issue_admin_login_challenge()
 RETURNS TABLE(nonce text,login_state text,expires_at timestamptz)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
#variable_conflict use_column
DECLARE v_nonce text; v_state text; v_expires timestamptz; v_live integer;
BEGIN
 IF NOT pg_has_role(session_user,'ap_auth_issuer','MEMBER') OR pg_has_role(session_user,'ap_m1_api','MEMBER')
 THEN RAISE EXCEPTION 'challenge denied' USING ERRCODE='42501'; END IF;
 -- Unauthenticated endpoint: keep the store bounded.
 DELETE FROM ap_m1.admin_login_challenges c WHERE c.expires_at<clock_timestamp()-interval '1 hour';
 SELECT count(*) INTO v_live FROM ap_m1.admin_login_challenges c
  WHERE c.consumed_at IS NULL AND c.expires_at>clock_timestamp();
 IF v_live>=1000 THEN RAISE EXCEPTION 'too many pending admin logins' USING ERRCODE='MA429'; END IF;
 v_nonce:=encode(public.gen_random_bytes(32),'hex');
 v_state:=encode(public.gen_random_bytes(32),'hex');
 v_expires:=clock_timestamp()+interval '5 minutes';
 INSERT INTO ap_m1.admin_login_challenges(nonce_sha256,state_sha256,expires_at)
  VALUES(public.digest(v_nonce,'sha256'),public.digest(v_state,'sha256'),v_expires);
 RETURN QUERY SELECT v_nonce,v_state,v_expires;
END $f$;

CREATE FUNCTION ap_m1.exchange_admin_oidc_session(
 p_issuer text,p_subject text,p_verified_email text,p_nonce text,p_login_state text,p_lifetime_seconds integer)
 RETURNS TABLE(session_token text,csrf_token text,admin_id uuid,account_state text,expires_at timestamptz)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
#variable_conflict use_column
DECLARE v_challenge uuid; v_principal uuid; v_admin uuid; a ap_m1.admin_accounts;
 v_token text; v_csrf text; v_expires timestamptz;
BEGIN
 IF NOT pg_has_role(session_user,'ap_auth_issuer','MEMBER') OR pg_has_role(session_user,'ap_m1_api','MEMBER')
 OR p_issuer IS NULL OR NOT ap_m1._parent_oidc_issuer_trusted(p_issuer)
 OR p_subject IS NULL OR p_subject !~ '^[!-~]{1,255}$'
 OR p_verified_email IS NULL OR p_verified_email !~ '^[!-~]{1,254}$' OR position('@' in p_verified_email)<2
 OR p_nonce IS NULL OR p_nonce !~ '^[0-9a-f]{64}$' OR p_login_state IS NULL OR p_login_state !~ '^[0-9a-f]{64}$'
 OR p_lifetime_seconds IS NULL OR p_lifetime_seconds NOT BETWEEN 300 AND 3600
 THEN RAISE EXCEPTION 'session denied' USING ERRCODE='42501'; END IF;
 -- Single use: nonce AND browser-bound state must match one live challenge.
 UPDATE ap_m1.admin_login_challenges c SET consumed_at=clock_timestamp()
  WHERE c.nonce_sha256=public.digest(p_nonce,'sha256') AND c.state_sha256=public.digest(p_login_state,'sha256')
  AND c.consumed_at IS NULL AND c.expires_at>clock_timestamp()
  RETURNING c.id INTO v_challenge;
 IF v_challenge IS NULL THEN RAISE EXCEPTION 'session denied' USING ERRCODE='42501'; END IF;
 v_principal:=ap_m1.resolve_parent_principal(p_issuer,p_subject);
 PERFORM 1 FROM ap_m1.parent_principals p
  WHERE p.id=v_principal AND p.oidc_issuer=p_issuer AND p.oidc_subject=p_subject FOR NO KEY UPDATE;
 IF NOT FOUND OR EXISTS(SELECT 1 FROM ap_m1.adult_erasure_requests e WHERE e.principal_id=v_principal)
 THEN RAISE EXCEPTION 'session denied' USING ERRCODE='42501'; END IF;
 -- Identity only: register_admin grants nothing beyond the protected owner allowlist.
 v_admin:=ap_m1.register_admin(v_principal,lower(p_verified_email));
 SELECT * INTO STRICT a FROM ap_m1.admin_accounts x WHERE x.id=v_admin FOR SHARE;
 IF a.state IN ('SUSPENDED','REVOKED') THEN RAISE EXCEPTION 'session denied' USING ERRCODE='42501'; END IF;
 v_token:=encode(public.gen_random_bytes(32),'hex');
 v_csrf:=encode(public.gen_random_bytes(32),'hex');
 v_expires:=statement_timestamp()+make_interval(secs=>p_lifetime_seconds);
 INSERT INTO ap_m1.admin_sessions(admin_id,token_hash,revocation_epoch,authorized_at_issue,expires_at,mfa_until,csrf_sha256)
  VALUES(a.id,public.digest(v_token,'sha256'),a.session_revocation_epoch,a.state='ACTIVE',v_expires,NULL,
         public.digest(v_csrf,'sha256'));
 -- Bound live sessions per administrator: keep the newest 5.
 UPDATE ap_m1.admin_sessions s SET revoked_at=statement_timestamp()
  WHERE s.id IN (SELECT x.id FROM ap_m1.admin_sessions x WHERE x.admin_id=a.id AND x.revoked_at IS NULL
   AND x.expires_at>statement_timestamp() ORDER BY x.created_at DESC,x.id DESC OFFSET 5);
 INSERT INTO ap_m1.admin_action_audit(actor_admin_id,target_ref,action,outcome) VALUES(a.id,a.id,'ADMIN_LOGIN','SUCCESS');
 RETURN QUERY SELECT v_token,v_csrf,a.id,a.state,v_expires;
END $f$;

-- CSRF: header value must match the presented session's bound secret.
CREATE FUNCTION ap_m1.admin_csrf_valid(p_csrf text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT coalesce(p_csrf ~ '^[0-9a-f]{64}$' AND EXISTS(SELECT 1 FROM ap_m1.admin_sessions s
  JOIN ap_m1.admin_accounts a ON a.id=s.admin_id
  WHERE s.token_hash=public.digest(nullif(current_setting('ap.admin_session_token',true),''),'sha256')
  AND s.revoked_at IS NULL AND s.expires_at>statement_timestamp() AND s.revocation_epoch=a.session_revocation_epoch
  AND a.state NOT IN ('REVOKED','SUSPENDED') AND s.csrf_sha256=public.digest(p_csrf,'sha256')),false);
$f$;

-- Rotate the CSRF secret of the presented live session (page reload).
CREATE FUNCTION ap_m1.rotate_admin_csrf() RETURNS text
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
DECLARE v_csrf text:=encode(public.gen_random_bytes(32),'hex'); n integer;
BEGIN
 IF ap_m1.ctx_admin() IS NULL THEN RAISE EXCEPTION 'administrator session required' USING ERRCODE='28000'; END IF;
 UPDATE ap_m1.admin_sessions s SET csrf_sha256=public.digest(v_csrf,'sha256')
  WHERE s.token_hash=public.digest(nullif(current_setting('ap.admin_session_token',true),''),'sha256')
  AND s.revoked_at IS NULL AND s.expires_at>statement_timestamp();
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>1 THEN RAISE EXCEPTION 'administrator session required' USING ERRCODE='28000'; END IF;
 RETURN v_csrf;
END $f$;

CREATE FUNCTION ap_m1.revoke_current_admin_session() RETURNS boolean
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
DECLARE n integer;
BEGIN
 UPDATE ap_m1.admin_sessions s SET revoked_at=statement_timestamp()
  WHERE s.token_hash=public.digest(nullif(current_setting('ap.admin_session_token',true),''),'sha256')
  AND s.revoked_at IS NULL AND s.expires_at>statement_timestamp();
 GET DIAGNOSTICS n=ROW_COUNT;
 RETURN n=1;
END $f$;

-- Server-authoritative session view for page reloads (roles never from the browser).
CREATE FUNCTION ap_m1.admin_session_state()
 RETURNS TABLE(admin_id uuid,expires_at timestamptz,mfa_active boolean,role_codes text[])
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT s.admin_id,s.expires_at,coalesce(s.mfa_until>statement_timestamp(),false),
  CASE WHEN a.state='ACTIVE' AND s.authorized_at_issue THEN
   ARRAY(SELECT 'ROOT_OWNER' WHERE ap_m1.admin_is_owner(a.id)
         UNION SELECT g.role_code FROM ap_m1.admin_role_grants g WHERE g.admin_id=a.id AND g.revoked_at IS NULL
          AND (g.expires_at IS NULL OR g.expires_at>now()) ORDER BY 1)
  ELSE ARRAY[]::text[] END
 FROM ap_m1.admin_sessions s JOIN ap_m1.admin_accounts a ON a.id=s.admin_id
 WHERE s.token_hash=public.digest(nullif(current_setting('ap.admin_session_token',true),''),'sha256')
 AND s.revoked_at IS NULL AND s.expires_at>statement_timestamp() AND s.revocation_epoch=a.session_revocation_epoch
 AND a.state NOT IN ('REVOKED','SUSPENDED');
$f$;

-- Support queue: owner sees every ticket, agents only assigned ones. No requester identity.
CREATE FUNCTION ap_m1.admin_list_support_tickets(p_after uuid DEFAULT NULL,p_page_size integer DEFAULT 25)
 RETURNS TABLE(id uuid,subject text,state text,priority text,assigned_to_me boolean,revision bigint,
               created_at timestamptz,updated_at timestamptz)
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
#variable_conflict use_column
DECLARE v_admin uuid:=ap_m1.ctx_admin(); v_owner boolean;
BEGIN
 IF v_admin IS NULL OR NOT ap_m1.has_admin_permission('SUPPORT_READ')
 THEN RAISE EXCEPTION 'support access denied' USING ERRCODE='42501'; END IF;
 IF p_page_size IS NULL OR p_page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid page size' USING ERRCODE='22023'; END IF;
 v_owner:=ap_m1.admin_is_owner(v_admin);
 INSERT INTO ap_m1.admin_action_audit(actor_admin_id,target_ref,action,outcome) VALUES(v_admin,NULL,'SUPPORT_LIST','SUCCESS');
 RETURN QUERY SELECT t.id,t.subject,t.state,t.priority,t.assigned_admin_id IS NOT DISTINCT FROM v_admin,t.revision,
  t.created_at,t.updated_at FROM ap_m1.support_tickets t
  WHERE (v_owner OR t.assigned_admin_id=v_admin) AND (p_after IS NULL OR t.id>p_after)
  ORDER BY t.id LIMIT p_page_size;
END $f$;

-- Security audit: owner with an active MFA step-up only (AUDIT_READ is step_up).
CREATE FUNCTION ap_m1.admin_read_action_audit(p_after uuid DEFAULT NULL,p_page_size integer DEFAULT 50)
 RETURNS TABLE(id uuid,actor_admin_id uuid,target_ref uuid,action text,outcome text,occurred_at timestamptz)
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
#variable_conflict use_column
BEGIN
 IF NOT ap_m1.has_admin_permission('AUDIT_READ') OR NOT ap_m1.admin_is_owner(ap_m1.ctx_admin())
 THEN RAISE EXCEPTION 'audit access denied' USING ERRCODE='42501'; END IF;
 IF p_page_size IS NULL OR p_page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid page size' USING ERRCODE='22023'; END IF;
 RETURN QUERY SELECT x.id,x.actor_admin_id,x.target_ref,x.action,x.outcome,x.occurred_at
  FROM ap_m1.admin_action_audit x WHERE (p_after IS NULL OR x.id>p_after) ORDER BY x.id LIMIT p_page_size;
END $f$;

DO $acl$
DECLARE sig text;
BEGIN
 FOREACH sig IN ARRAY ARRAY['issue_admin_login_challenge()',
  'exchange_admin_oidc_session(text,text,text,text,text,integer)','rotate_admin_csrf()',
  'revoke_current_admin_session()','admin_list_support_tickets(uuid,integer)',
  'admin_read_action_audit(uuid,integer)'] LOOP
  EXECUTE format('ALTER FUNCTION ap_m1.%s OWNER TO ap_db_executor',sig);
  EXECUTE format('REVOKE ALL ON FUNCTION ap_m1.%s FROM PUBLIC,ap_m1_api,ap_m1_auth,ap_auth_issuer,ap_m1_owner',sig);
 END LOOP;
 FOREACH sig IN ARRAY ARRAY['admin_csrf_valid(text)','admin_session_state()'] LOOP
  EXECUTE format('ALTER FUNCTION ap_m1.%s OWNER TO ap_m1_auth',sig);
  EXECUTE format('REVOKE ALL ON FUNCTION ap_m1.%s FROM PUBLIC,ap_auth_issuer,ap_m1_owner',sig);
 END LOOP;
END $acl$;
GRANT EXECUTE ON FUNCTION ap_m1.issue_admin_login_challenge(),
 ap_m1.exchange_admin_oidc_session(text,text,text,text,text,integer) TO ap_auth_issuer;
GRANT EXECUTE ON FUNCTION ap_m1.rotate_admin_csrf(),ap_m1.revoke_current_admin_session(),
 ap_m1.admin_list_support_tickets(uuid,integer),ap_m1.admin_read_action_audit(uuid,integer),
 ap_m1.admin_csrf_valid(text),ap_m1.admin_session_state() TO ap_m1_api;
-- The admin bridge now owns identity minting; the raw issuer primitives are retired
-- from every login role (the exchange calls them internally as their owner).
REVOKE EXECUTE ON FUNCTION ap_m1.register_admin(uuid,text),ap_m1.mint_admin_session(uuid,timestamptz,timestamptz)
 FROM ap_auth_issuer;
