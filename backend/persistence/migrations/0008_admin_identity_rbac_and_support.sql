-- Separate back-office identity; Google verification is performed ONLY by ap_auth_issuer.
-- No bootstrap email or preapproved real identity. Protected migration configuration
-- must populate owner_identity_allowlist with independently verified issuer + sub.
CREATE TABLE ap_m1.owner_identity_allowlist (
 issuer text NOT NULL, subject text NOT NULL, configured_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(issuer,subject), CHECK(length(issuer)>3 AND length(subject)>0)
);
CREATE TABLE ap_m1.admin_accounts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 principal_id uuid NOT NULL UNIQUE REFERENCES ap_m1.parent_principals(id),
 verified_email text NOT NULL CHECK(length(verified_email) BETWEEN 3 AND 320),
 verified_at timestamptz NOT NULL DEFAULT now(),
 state text NOT NULL DEFAULT 'NO_ACCESS' CHECK(state IN ('NO_ACCESS','ACTIVE','SUSPENDED','REVOKED')),
 session_revocation_epoch bigint NOT NULL DEFAULT 1 CHECK(session_revocation_epoch>0),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE ap_m1.admin_profiles (
 admin_id uuid PRIMARY KEY REFERENCES ap_m1.admin_accounts(id),
 full_name text NOT NULL CHECK(length(full_name) BETWEEN 1 AND 150),
 contact_email text NOT NULL CHECK(length(contact_email) BETWEEN 3 AND 320),
 contact_verified_at timestamptz,
 privacy_notice_version text NOT NULL CHECK(length(privacy_notice_version) BETWEEN 1 AND 100),
 -- DOB/gender/address are intentionally absent until necessity/legal approval.
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE ap_m1.admin_email_challenges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), admin_id uuid NOT NULL REFERENCES ap_m1.admin_accounts(id),
 contact_email text NOT NULL, challenge_hash bytea NOT NULL UNIQUE CHECK(octet_length(challenge_hash)=32),
 expires_at timestamptz NOT NULL, used_at timestamptz,
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 5), created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(expires_at>created_at)
);
CREATE TABLE ap_m1.admin_access_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), admin_id uuid NOT NULL REFERENCES ap_m1.admin_accounts(id),
 profile_revision bigint NOT NULL CHECK(profile_revision>0),
 state text NOT NULL DEFAULT 'PENDING_REVIEW' CHECK(state IN ('PENDING_REVIEW','APPROVED','REJECTED','SUSPENDED')),
 submitted_at timestamptz NOT NULL DEFAULT now(), decided_at timestamptz,
 decided_by uuid REFERENCES ap_m1.admin_accounts(id), decision_reason text CHECK(length(decision_reason)<=500),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK((state='PENDING_REVIEW' AND decided_at IS NULL AND decided_by IS NULL) OR
       (state<>'PENDING_REVIEW' AND decided_at IS NOT NULL AND decided_by IS NOT NULL))
);
CREATE UNIQUE INDEX one_pending_admin_request ON ap_m1.admin_access_requests(admin_id) WHERE state='PENDING_REVIEW';
CREATE TABLE ap_m1.admin_roles (
 code text PRIMARY KEY CHECK(code IN ('ROOT_OWNER','FAQ_EDITOR','SUPPORT_AGENT','BILLING_VIEWER','USAGE_AUDITOR')),
 description text NOT NULL, owner_assignable boolean NOT NULL
);
CREATE TABLE ap_m1.admin_permissions (
 code text PRIMARY KEY, step_up boolean NOT NULL DEFAULT false
);
CREATE TABLE ap_m1.admin_role_permissions (
 role_code text NOT NULL REFERENCES ap_m1.admin_roles(code), permission_code text NOT NULL REFERENCES ap_m1.admin_permissions(code),
 PRIMARY KEY(role_code,permission_code)
);
CREATE TABLE ap_m1.admin_role_grants (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), admin_id uuid NOT NULL REFERENCES ap_m1.admin_accounts(id),
 role_code text NOT NULL REFERENCES ap_m1.admin_roles(code) CHECK(role_code<>'ROOT_OWNER'),
 granted_by uuid NOT NULL REFERENCES ap_m1.admin_accounts(id),
 created_at timestamptz NOT NULL DEFAULT now(), revoked_at timestamptz, expires_at timestamptz,
 CHECK(expires_at IS NULL OR expires_at>created_at)
);
CREATE UNIQUE INDEX active_admin_role ON ap_m1.admin_role_grants(admin_id,role_code) WHERE revoked_at IS NULL;
CREATE TABLE ap_m1.admin_sessions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), admin_id uuid NOT NULL REFERENCES ap_m1.admin_accounts(id),
 token_hash bytea NOT NULL UNIQUE CHECK(octet_length(token_hash)=32),
 audience text NOT NULL DEFAULT 'madalasa-admin' CHECK(audience='madalasa-admin'),
 revocation_epoch bigint NOT NULL CHECK(revocation_epoch>0),
 authorized_at_issue boolean NOT NULL, mfa_until timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL, revoked_at timestamptz,
 CHECK(expires_at>created_at), CHECK(mfa_until IS NULL OR mfa_until<=expires_at)
);
CREATE INDEX admin_session_account ON ap_m1.admin_sessions(admin_id);
CREATE TABLE ap_m1.admin_action_audit (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_admin_id uuid REFERENCES ap_m1.admin_accounts(id),
 target_ref uuid, action text NOT NULL CHECK(length(action) BETWEEN 1 AND 80),
 outcome text NOT NULL CHECK(outcome IN ('AUTHORIZED','DENIED','SUCCESS')),
 occurred_at timestamptz NOT NULL DEFAULT now(), request_id uuid NOT NULL DEFAULT gen_random_uuid(),
 retention_policy_id uuid REFERENCES ap_m1.retention_policy_versions(id)
);
CREATE TABLE ap_m1.admin_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), access_request_id uuid NOT NULL REFERENCES ap_m1.admin_access_requests(id),
 kind text NOT NULL CHECK(kind IN ('ACCESS_REQUEST','APPROVED','REJECTED')),
 state text NOT NULL DEFAULT 'QUEUED' CHECK(state IN ('QUEUED','SENT','FAILED')),
 created_at timestamptz NOT NULL DEFAULT now(), delivered_at timestamptz,
 UNIQUE(access_request_id,kind)
);
INSERT INTO ap_m1.admin_roles VALUES
 ('ROOT_OWNER','Protected issuer/subject bootstrap owner',false),('FAQ_EDITOR','FAQ plain text CMS',true),
 ('SUPPORT_AGENT','Assigned support tickets',true),('BILLING_VIEWER','Restricted billing metadata',true),
 ('USAGE_AUDITOR','Parent service aggregates only',true);
INSERT INTO ap_m1.admin_permissions VALUES ('OWNER_MANAGE',true),('FAQ_EDIT',false),('FAQ_PUBLISH',true),
 ('SUPPORT_READ',false),('SUPPORT_REPLY',false),('BILLING_READ',false),('USAGE_READ',false),('AUDIT_READ',true);
INSERT INTO ap_m1.admin_role_permissions VALUES
 ('FAQ_EDITOR','FAQ_EDIT'),('FAQ_EDITOR','FAQ_PUBLISH'),('SUPPORT_AGENT','SUPPORT_READ'),
 ('SUPPORT_AGENT','SUPPORT_REPLY'),('BILLING_VIEWER','BILLING_READ'),('USAGE_AUDITOR','USAGE_READ');

CREATE FUNCTION ap_m1.ctx_admin() RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ap_m1,public AS $$
 SELECT s.admin_id FROM ap_m1.admin_sessions s JOIN ap_m1.admin_accounts a ON a.id=s.admin_id
 WHERE s.token_hash=public.digest(nullif(current_setting('ap.admin_session_token',true),''),'sha256')
 AND s.revoked_at IS NULL AND s.expires_at>statement_timestamp() AND s.revocation_epoch=a.session_revocation_epoch
 AND a.state NOT IN ('REVOKED','SUSPENDED')
$$;
CREATE FUNCTION ap_m1.admin_is_owner(target uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ap_m1 AS $$
 SELECT EXISTS(SELECT 1 FROM ap_m1.admin_accounts a JOIN ap_m1.parent_principals p ON p.id=a.principal_id
 JOIN ap_m1.owner_identity_allowlist o ON o.issuer=p.oidc_issuer AND o.subject=p.oidc_subject
 WHERE a.id=target AND a.state='ACTIVE')
$$;
CREATE FUNCTION ap_m1.has_admin_permission(wanted text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ap_m1,public AS $$
 SELECT EXISTS(SELECT 1 FROM ap_m1.admin_sessions s JOIN ap_m1.admin_accounts a ON a.id=s.admin_id
 JOIN ap_m1.admin_permissions p ON p.code=wanted
 WHERE s.token_hash=public.digest(nullif(current_setting('ap.admin_session_token',true),''),'sha256')
 AND a.state='ACTIVE' AND s.authorized_at_issue AND s.revoked_at IS NULL AND s.expires_at>statement_timestamp()
 AND s.revocation_epoch=a.session_revocation_epoch AND (NOT p.step_up OR s.mfa_until>statement_timestamp())
 AND (ap_m1.admin_is_owner(a.id) OR EXISTS(SELECT 1 FROM ap_m1.admin_role_grants g
 JOIN ap_m1.admin_role_permissions rp ON rp.role_code=g.role_code
 WHERE g.admin_id=a.id AND rp.permission_code=wanted AND g.revoked_at IS NULL
 AND (g.expires_at IS NULL OR g.expires_at>now()))))
$$;
-- Only the issuer has verified OIDC credentials and MFA assurance. Never exposed to API.
CREATE FUNCTION ap_m1.register_admin(target_principal uuid, verified_email text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE result uuid; owner_match boolean;
BEGIN
 SELECT EXISTS(SELECT 1 FROM ap_m1.parent_principals p JOIN ap_m1.owner_identity_allowlist o
 ON o.issuer=p.oidc_issuer AND o.subject=p.oidc_subject WHERE p.id=target_principal) INTO owner_match;
 INSERT INTO ap_m1.admin_accounts(principal_id,verified_email,state)
 VALUES(target_principal,verified_email,CASE WHEN owner_match THEN 'ACTIVE' ELSE 'NO_ACCESS' END)
 ON CONFLICT(principal_id) DO UPDATE SET verified_email=EXCLUDED.verified_email, verified_at=now()
 RETURNING id INTO result;
 RETURN result;
END $$;
CREATE FUNCTION ap_m1.mint_admin_session(target_admin uuid, valid_until timestamptz, assured_until timestamptz DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE token text; a ap_m1.admin_accounts;
BEGIN
 SELECT * INTO STRICT a FROM ap_m1.admin_accounts WHERE id=target_admin FOR SHARE;
 IF a.state IN ('SUSPENDED','REVOKED') OR valid_until<=now() OR valid_until>now()+interval '1 hour'
 OR assured_until>valid_until THEN RAISE EXCEPTION 'invalid admin session' USING ERRCODE='42501'; END IF;
 token:=encode(public.gen_random_bytes(32),'hex');
 INSERT INTO ap_m1.admin_sessions(admin_id,token_hash,revocation_epoch,authorized_at_issue,expires_at,mfa_until)
 VALUES(a.id,public.digest(token,'sha256'),a.session_revocation_epoch,a.state='ACTIVE',valid_until,assured_until);
 RETURN token;
END $$;
CREATE FUNCTION ap_m1.save_admin_profile(full_name text, contact_email text, notice_version text, expected bigint)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE aid uuid:=ap_m1.ctx_admin(); result bigint;
BEGIN
 IF aid IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE='42501'; END IF;
 IF expected=0 THEN
 INSERT INTO ap_m1.admin_profiles(admin_id,full_name,contact_email,privacy_notice_version,contact_verified_at)
 SELECT aid,full_name,contact_email,notice_version,CASE WHEN a.verified_email=contact_email THEN a.verified_at END
 FROM ap_m1.admin_accounts a WHERE a.id=aid RETURNING revision INTO result;
 ELSE
 UPDATE ap_m1.admin_profiles p SET full_name=save_admin_profile.full_name,
 contact_email=save_admin_profile.contact_email, privacy_notice_version=notice_version,
 contact_verified_at=CASE WHEN a.verified_email=save_admin_profile.contact_email THEN a.verified_at END,
 revision=p.revision+1,updated_at=now() FROM ap_m1.admin_accounts a
 WHERE p.admin_id=aid AND a.id=aid AND p.revision=expected RETURNING p.revision INTO result;
 END IF;
 IF result IS NULL THEN RAISE EXCEPTION 'profile revision conflict' USING ERRCODE='40001'; END IF;
 RETURN result;
END $$;
CREATE FUNCTION ap_m1.submit_admin_request(expected bigint) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE aid uuid:=ap_m1.ctx_admin(); result uuid;
BEGIN
 PERFORM 1 FROM ap_m1.admin_accounts WHERE id=aid FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM ap_m1.admin_profiles WHERE admin_id=aid AND revision=expected AND contact_verified_at IS NOT NULL)
 THEN RAISE EXCEPTION 'verified complete profile required' USING ERRCODE='42501'; END IF;
 SELECT id INTO result FROM ap_m1.admin_access_requests WHERE admin_id=aid AND state='PENDING_REVIEW';
 IF result IS NOT NULL THEN RETURN result; END IF;
 INSERT INTO ap_m1.admin_access_requests(admin_id,profile_revision) VALUES(aid,expected) RETURNING id INTO result;
 INSERT INTO ap_m1.admin_notifications(access_request_id,kind) VALUES(result,'ACCESS_REQUEST');
 RETURN result;
END $$;
CREATE FUNCTION ap_m1.decide_admin_request(target uuid, expected bigint, approve boolean, roles text[], reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE req ap_m1.admin_access_requests; role_name text;
BEGIN
 IF NOT ap_m1.has_admin_permission('OWNER_MANAGE') OR NOT ap_m1.admin_is_owner(ap_m1.ctx_admin())
 THEN RAISE EXCEPTION 'owner MFA required' USING ERRCODE='42501'; END IF;
 IF reason IS NULL OR length(reason) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'reason required'; END IF;
 SELECT * INTO STRICT req FROM ap_m1.admin_access_requests WHERE id=target FOR UPDATE;
 IF req.revision<>expected OR req.state<>'PENDING_REVIEW' THEN RAISE EXCEPTION 'decision conflict' USING ERRCODE='40001'; END IF;
 IF NOT EXISTS(SELECT 1 FROM ap_m1.admin_profiles WHERE admin_id=req.admin_id
 AND revision=req.profile_revision AND contact_verified_at IS NOT NULL) THEN RAISE EXCEPTION 'profile changed'; END IF;
 IF approve AND (coalesce(cardinality(roles),0)=0 OR EXISTS(SELECT 1 FROM unnest(roles) r
 WHERE NOT EXISTS(SELECT 1 FROM ap_m1.admin_roles WHERE code=r AND owner_assignable)))
 THEN RAISE EXCEPTION 'invalid roles'; END IF;
 UPDATE ap_m1.admin_access_requests SET state=CASE WHEN approve THEN 'APPROVED' ELSE 'REJECTED' END,
 decided_at=now(),decided_by=ap_m1.ctx_admin(),decision_reason=reason,revision=revision+1,updated_at=now() WHERE id=target;
 UPDATE ap_m1.admin_accounts SET state=CASE WHEN approve THEN 'ACTIVE' ELSE 'NO_ACCESS' END,
 session_revocation_epoch=session_revocation_epoch+1,revision=revision+1,updated_at=now() WHERE id=req.admin_id;
 IF approve THEN
 FOREACH role_name IN ARRAY roles LOOP
 INSERT INTO ap_m1.admin_role_grants(admin_id,role_code,granted_by) VALUES(req.admin_id,role_name,ap_m1.ctx_admin())
 ON CONFLICT(admin_id,role_code) WHERE revoked_at IS NULL DO NOTHING;
 END LOOP;
 END IF;
 INSERT INTO ap_m1.admin_action_audit(actor_admin_id,target_ref,action,outcome)
 VALUES(ap_m1.ctx_admin(),target,'ACCESS_DECISION','SUCCESS');
 INSERT INTO ap_m1.admin_notifications(access_request_id,kind) VALUES(target,CASE WHEN approve THEN 'APPROVED' ELSE 'REJECTED' END);
END $$;
CREATE FUNCTION ap_m1.revoke_admin_grant(target uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE aid uuid;
BEGIN
 IF NOT ap_m1.has_admin_permission('OWNER_MANAGE') OR NOT ap_m1.admin_is_owner(ap_m1.ctx_admin())
 THEN RAISE EXCEPTION 'owner MFA required' USING ERRCODE='42501'; END IF;
 UPDATE ap_m1.admin_role_grants SET revoked_at=coalesce(revoked_at,now()) WHERE id=target RETURNING admin_id INTO aid;
 UPDATE ap_m1.admin_accounts SET session_revocation_epoch=session_revocation_epoch+1,
 revision=revision+1,updated_at=now() WHERE id=aid;
 INSERT INTO ap_m1.admin_action_audit(actor_admin_id,target_ref,action,outcome)
 VALUES(ap_m1.ctx_admin(),target,'ROLE_REVOKED','SUCCESS');
END $$;

CREATE FUNCTION ap_m1.bump_admin_grant_epoch() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
BEGIN
 UPDATE ap_m1.admin_accounts SET session_revocation_epoch=session_revocation_epoch+1,
 revision=revision+1,updated_at=statement_timestamp()
 WHERE id=CASE WHEN TG_OP='DELETE' THEN OLD.admin_id ELSE NEW.admin_id END;
 RETURN NULL;
END $$;
CREATE TRIGGER admin_grant_revocation_epoch AFTER INSERT OR UPDATE OR DELETE ON ap_m1.admin_role_grants
 FOR EACH ROW EXECUTE FUNCTION ap_m1.bump_admin_grant_epoch();
ALTER FUNCTION ap_m1.bump_admin_grant_epoch() OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.bump_admin_grant_epoch() FROM PUBLIC;

CREATE FUNCTION ap_m1.suspend_admin(target uuid, revoke boolean DEFAULT false) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
BEGIN
 IF NOT ap_m1.has_admin_permission('OWNER_MANAGE') OR NOT ap_m1.admin_is_owner(ap_m1.ctx_admin())
 THEN RAISE EXCEPTION 'owner MFA required' USING ERRCODE='42501'; END IF;
 IF ap_m1.admin_is_owner(target) THEN RAISE EXCEPTION 'owner recovery is out-of-band only' USING ERRCODE='42501'; END IF;
 UPDATE ap_m1.admin_accounts SET state=CASE WHEN revoke THEN 'REVOKED' ELSE 'SUSPENDED' END,
 session_revocation_epoch=session_revocation_epoch+1,revision=revision+1,updated_at=statement_timestamp() WHERE id=target;
 INSERT INTO ap_m1.admin_action_audit(actor_admin_id,target_ref,action,outcome) VALUES(ap_m1.ctx_admin(),target,'ADMIN_SUSPEND','SUCCESS');
END $$;
ALTER FUNCTION ap_m1.suspend_admin(uuid,boolean) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.suspend_admin(uuid,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.suspend_admin(uuid,boolean) TO ap_m1_api;

CREATE FUNCTION ap_m1.issue_admin_email_challenge(target uuid, lifetime interval DEFAULT interval '15 minutes') RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE token text; email text;
BEGIN
 IF lifetime<=interval '0' OR lifetime>interval '30 minutes' THEN RAISE EXCEPTION 'invalid challenge lifetime'; END IF;
 SELECT contact_email INTO STRICT email FROM ap_m1.admin_profiles WHERE admin_id=target FOR UPDATE;
 UPDATE ap_m1.admin_email_challenges SET used_at=statement_timestamp() WHERE admin_id=target AND used_at IS NULL;
 token:=encode(public.gen_random_bytes(32),'hex');
 INSERT INTO ap_m1.admin_email_challenges(admin_id,contact_email,challenge_hash,expires_at)
 VALUES(target,email,public.digest(token,'sha256'),statement_timestamp()+lifetime);
 RETURN token;
END $$;
CREATE FUNCTION ap_m1.confirm_admin_contact(token text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
DECLARE challenge ap_m1.admin_email_challenges; aid uuid:=ap_m1.ctx_admin();
BEGIN
 IF aid IS NULL THEN RAISE EXCEPTION 'applicant authentication required' USING ERRCODE='42501'; END IF;
 SELECT * INTO challenge FROM ap_m1.admin_email_challenges WHERE admin_id=aid AND used_at IS NULL
 ORDER BY created_at DESC,id DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND OR challenge.expires_at<=statement_timestamp() OR challenge.attempts>=5 THEN RETURN false; END IF;
 UPDATE ap_m1.admin_email_challenges SET attempts=attempts+1 WHERE id=challenge.id;
 IF challenge.challenge_hash IS DISTINCT FROM public.digest(token,'sha256') THEN RETURN false; END IF;
 UPDATE ap_m1.admin_profiles SET contact_verified_at=statement_timestamp(),revision=revision+1,updated_at=statement_timestamp()
 WHERE admin_id=aid AND contact_email=challenge.contact_email;
 IF NOT FOUND THEN RETURN false; END IF;
 UPDATE ap_m1.admin_email_challenges SET used_at=statement_timestamp() WHERE id=challenge.id;
 RETURN true;
END $$;
ALTER FUNCTION ap_m1.issue_admin_email_challenge(uuid,interval) OWNER TO ap_db_executor;
ALTER FUNCTION ap_m1.confirm_admin_contact(text) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.issue_admin_email_challenge(uuid,interval),ap_m1.confirm_admin_contact(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.issue_admin_email_challenge(uuid,interval) TO ap_auth_issuer;
GRANT EXECUTE ON FUNCTION ap_m1.confirm_admin_contact(text) TO ap_m1_api;

CREATE TABLE ap_m1.faq_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text NOT NULL UNIQUE CHECK(slug ~ '^[a-z0-9][a-z0-9-]{1,149}$'),
 category text NOT NULL CHECK(length(category)<=100),
 state text NOT NULL DEFAULT 'DRAFT' CHECK(state IN ('DRAFT','PUBLISHED','ARCHIVED')),
 current_revision_id uuid, published_revision_id uuid,
 revision bigint NOT NULL DEFAULT 0 CHECK(revision>=0), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(state<>'PUBLISHED' OR published_revision_id IS NOT NULL)
);
CREATE TABLE ap_m1.faq_revisions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), faq_id uuid NOT NULL REFERENCES ap_m1.faq_entries(id),
 revision_no bigint NOT NULL CHECK(revision_no>0), language text NOT NULL DEFAULT 'en' CHECK(language='en'),
 title text NOT NULL CHECK(length(title) BETWEEN 3 AND 220 AND title !~ '[<>]'),
 -- Plain text subset of Markdown: no HTML or links/images/embedded URLs. Render as text.
 safe_body text NOT NULL CHECK(length(safe_body) BETWEEN 1 AND 10000 AND safe_body !~ '[<>\[\]]'),
 created_by uuid NOT NULL REFERENCES ap_m1.admin_accounts(id), created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(faq_id,revision_no), UNIQUE(faq_id,id)
);
ALTER TABLE ap_m1.faq_entries ADD FOREIGN KEY(id,current_revision_id) REFERENCES ap_m1.faq_revisions(faq_id,id);
ALTER TABLE ap_m1.faq_entries ADD FOREIGN KEY(id,published_revision_id) REFERENCES ap_m1.faq_revisions(faq_id,id);
CREATE FUNCTION ap_m1.faq_draft(target uuid, slug text, category text, title text, body text, expected bigint)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE f ap_m1.faq_entries; rid uuid;
BEGIN
 IF NOT ap_m1.has_admin_permission('FAQ_EDIT') THEN RAISE EXCEPTION 'FAQ edit denied' USING ERRCODE='42501'; END IF;
 IF expected=0 THEN INSERT INTO ap_m1.faq_entries(id,slug,category) VALUES(target,slug,category) ON CONFLICT(id) DO NOTHING; END IF;
 SELECT * INTO STRICT f FROM ap_m1.faq_entries WHERE id=target FOR UPDATE;
 IF f.revision<>expected OR f.state='ARCHIVED' THEN RAISE EXCEPTION 'FAQ revision conflict' USING ERRCODE='40001'; END IF;
 INSERT INTO ap_m1.faq_revisions(faq_id,revision_no,title,safe_body,created_by)
 VALUES(target,f.revision+1,title,body,ap_m1.ctx_admin()) RETURNING id INTO rid;
 UPDATE ap_m1.faq_entries SET current_revision_id=rid,revision=f.revision+1,updated_at=now() WHERE id=target;
 INSERT INTO ap_m1.admin_action_audit(actor_admin_id,target_ref,action,outcome) VALUES(ap_m1.ctx_admin(),target,'FAQ_DRAFT','SUCCESS');
 RETURN rid;
END $$;
CREATE FUNCTION ap_m1.faq_transition(target uuid, revision_id uuid, expected bigint, next_state text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE f ap_m1.faq_entries;
BEGIN
 IF NOT ap_m1.has_admin_permission('FAQ_PUBLISH') THEN RAISE EXCEPTION 'publish MFA required' USING ERRCODE='42501'; END IF;
 SELECT * INTO STRICT f FROM ap_m1.faq_entries WHERE id=target FOR UPDATE;
 IF f.revision<>expected OR next_state NOT IN ('PUBLISHED','DRAFT','ARCHIVED')
 OR (f.state='ARCHIVED' AND next_state<>'DRAFT') THEN RAISE EXCEPTION 'FAQ transition conflict' USING ERRCODE='40001'; END IF;
 IF NOT EXISTS(SELECT 1 FROM ap_m1.faq_revisions WHERE faq_id=target AND id=revision_id)
 THEN RAISE EXCEPTION 'foreign revision'; END IF;
 UPDATE ap_m1.faq_entries SET state=next_state,current_revision_id=revision_id,
 published_revision_id=CASE WHEN next_state='PUBLISHED' THEN revision_id ELSE NULL END,
 revision=revision+1,updated_at=now() WHERE id=target;
 INSERT INTO ap_m1.admin_action_audit(actor_admin_id,target_ref,action,outcome) VALUES(ap_m1.ctx_admin(),target,'FAQ_TRANSITION','SUCCESS');
 RETURN f.revision+1;
END $$;

CREATE TABLE ap_m1.support_tickets (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), requester_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 subject text NOT NULL CHECK(length(subject) BETWEEN 1 AND 220 AND subject !~ '[<>]'),
 state text NOT NULL DEFAULT 'OPEN' CHECK(state IN ('OPEN','IN_PROGRESS','WAITING_FOR_PARENT','RESOLVED','CLOSED')),
 priority text NOT NULL DEFAULT 'NORMAL' CHECK(priority IN ('LOW','NORMAL','HIGH')),
 assigned_admin_id uuid REFERENCES ap_m1.admin_accounts(id), revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX support_requester ON ap_m1.support_tickets(requester_id,created_at DESC);
CREATE INDEX support_assignee ON ap_m1.support_tickets(assigned_admin_id,state);
CREATE TABLE ap_m1.support_messages (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ticket_id uuid NOT NULL REFERENCES ap_m1.support_tickets(id),
 parent_author_id uuid REFERENCES ap_m1.parent_principals(id), admin_author_id uuid REFERENCES ap_m1.admin_accounts(id),
 body text NOT NULL CHECK(length(body) BETWEEN 1 AND 5000 AND body !~ '[<>]'),
 request_id uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 delivery_state text NOT NULL DEFAULT 'QUEUED' CHECK(delivery_state IN ('QUEUED','SENT','READ','FAILED')),
 CHECK(num_nonnulls(parent_author_id,admin_author_id)=1),UNIQUE(ticket_id,request_id)
);
CREATE INDEX support_message_feed ON ap_m1.support_messages(ticket_id,created_at,id);
CREATE TABLE ap_m1.admin_support_read_audit (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), admin_id uuid NOT NULL REFERENCES ap_m1.admin_accounts(id),
 ticket_id uuid NOT NULL REFERENCES ap_m1.support_tickets(id), accessed_at timestamptz NOT NULL DEFAULT now(),
 purpose text NOT NULL CHECK(purpose='ASSIGNED_SUPPORT'), request_id uuid NOT NULL,
 retention_policy_id uuid REFERENCES ap_m1.retention_policy_versions(id)
);
CREATE FUNCTION ap_m1.can_support_ticket(target uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ap_m1 AS $$
 SELECT EXISTS(SELECT 1 FROM ap_m1.support_tickets t WHERE t.id=target AND
 (t.requester_id=ap_m1.ctx_principal() OR (ap_m1.has_admin_permission('SUPPORT_READ')
 AND (t.assigned_admin_id=ap_m1.ctx_admin() OR ap_m1.admin_is_owner(ap_m1.ctx_admin())))))
$$;
CREATE FUNCTION ap_m1.create_support_ticket(subject text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,ap_m1 AS $$
DECLARE result uuid;
BEGIN
 IF ap_m1.ctx_principal() IS NULL THEN RAISE EXCEPTION 'parent required' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.support_tickets(requester_id,subject) VALUES(ap_m1.ctx_principal(),subject) RETURNING id INTO result;
 RETURN result;
END $$;
CREATE FUNCTION ap_m1.support_reply(target uuid, body text, request_id uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE result uuid; parent_id uuid; aid uuid;
BEGIN
 IF NOT ap_m1.can_support_ticket(target) THEN RAISE EXCEPTION 'ticket denied' USING ERRCODE='42501'; END IF;
 SELECT requester_id INTO parent_id FROM ap_m1.support_tickets WHERE id=target FOR UPDATE;
 IF parent_id=ap_m1.ctx_principal() THEN aid:=NULL;
 ELSE
 IF NOT ap_m1.has_admin_permission('SUPPORT_REPLY') THEN RAISE EXCEPTION 'reply denied' USING ERRCODE='42501'; END IF;
 parent_id:=NULL; aid:=ap_m1.ctx_admin();
 END IF;
 INSERT INTO ap_m1.support_messages(ticket_id,parent_author_id,admin_author_id,body,request_id)
 VALUES(target,parent_id,aid,body,request_id) ON CONFLICT ON CONSTRAINT support_messages_ticket_id_request_id_key DO NOTHING RETURNING id INTO result;
 IF result IS NULL THEN
 SELECT m.id INTO result FROM ap_m1.support_messages m WHERE m.ticket_id=target AND m.request_id=support_reply.request_id
 AND m.body=support_reply.body AND m.parent_author_id IS NOT DISTINCT FROM parent_id AND m.admin_author_id IS NOT DISTINCT FROM aid;
 IF result IS NULL THEN RAISE EXCEPTION 'idempotency conflict' USING ERRCODE='40001'; END IF;
 END IF;
 IF aid IS NOT NULL THEN INSERT INTO ap_m1.admin_action_audit(actor_admin_id,target_ref,action,outcome)
 VALUES(aid,target,'SUPPORT_REPLY','SUCCESS'); END IF;
 RETURN result;
END $$;
CREATE FUNCTION ap_m1.read_support_messages(target uuid, after_id uuid DEFAULT NULL, page_size integer DEFAULT 25)
RETURNS TABLE(id uuid,body text,author_kind text,created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
BEGIN
 IF NOT ap_m1.can_support_ticket(target) THEN RAISE EXCEPTION 'ticket denied' USING ERRCODE='42501'; END IF;
 IF page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid page size'; END IF;
 IF ap_m1.ctx_admin() IS NOT NULL THEN
 INSERT INTO ap_m1.admin_support_read_audit(admin_id,ticket_id,purpose,request_id)
 VALUES(ap_m1.ctx_admin(),target,'ASSIGNED_SUPPORT',gen_random_uuid());
 END IF;
 RETURN QUERY SELECT m.id,m.body,CASE WHEN m.admin_author_id IS NULL THEN 'PARENT' ELSE 'ADMIN' END,m.created_at
 FROM ap_m1.support_messages m WHERE m.ticket_id=target AND (after_id IS NULL OR m.id>after_id) ORDER BY m.id LIMIT page_size;
END $$;
CREATE FUNCTION ap_m1.update_support_ticket(target uuid, expected bigint, next_state text, assignee uuid, priority text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE result bigint;
BEGIN
 IF NOT ap_m1.has_admin_permission('SUPPORT_REPLY') OR NOT ap_m1.can_support_ticket(target)
 THEN RAISE EXCEPTION 'support update denied' USING ERRCODE='42501'; END IF;
 IF assignee IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ap_m1.admin_accounts a JOIN ap_m1.admin_role_grants g ON g.admin_id=a.id
 WHERE a.id=assignee AND a.state='ACTIVE' AND g.role_code='SUPPORT_AGENT' AND g.revoked_at IS NULL
 AND (g.expires_at IS NULL OR g.expires_at>now())) THEN RAISE EXCEPTION 'invalid assignee'; END IF;
 UPDATE ap_m1.support_tickets t SET state=next_state,assigned_admin_id=assignee,
 priority=update_support_ticket.priority,revision=revision+1,updated_at=now()
 WHERE t.id=target AND t.revision=expected RETURNING t.revision INTO result;
 IF result IS NULL THEN RAISE EXCEPTION 'ticket revision conflict' USING ERRCODE='40001'; END IF;
 INSERT INTO ap_m1.admin_action_audit(actor_admin_id,target_ref,action,outcome) VALUES(ap_m1.ctx_admin(),target,'TICKET_UPDATE','SUCCESS');
 RETURN result;
END $$;
CREATE TABLE ap_m1.parent_service_usage_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), parent_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 service_code text NOT NULL CHECK(service_code IN ('LOCATION_VIEW','HISTORY_VIEW','SUPPORT','BILLING','MEDIA_REQUEST')),
 started_at timestamptz NOT NULL, ended_at timestamptz NOT NULL CHECK(ended_at>=started_at),
 duration_seconds numeric GENERATED ALWAYS AS (extract(epoch FROM ended_at-started_at)) STORED,
 outcome text NOT NULL CHECK(outcome IN ('SUCCESS','DENIED','FAILED','UNKNOWN')),
 quota_seconds integer NOT NULL DEFAULT 0 CHECK(quota_seconds>=0), receipt_ref uuid,
 retention_policy_id uuid REFERENCES ap_m1.retention_policy_versions(id)
);
-- No JSON payload, URL, child ID, app behavior, coordinates or media columns.
CREATE VIEW ap_m1.parent_service_usage_aggregates WITH(security_barrier=true) AS
 SELECT parent_id,date_trunc('day',started_at) AS day,service_code,outcome,count(*) AS event_count,
 sum(duration_seconds) AS duration_seconds,sum(quota_seconds) AS quota_seconds
 FROM ap_m1.parent_service_usage_events WHERE ap_m1.has_admin_permission('USAGE_READ')
 GROUP BY parent_id,date_trunc('day',started_at),service_code,outcome;

-- Default deny everywhere. Only metadata lookup helpers use the read-only bypass owner.
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['owner_identity_allowlist','admin_accounts','admin_profiles','admin_email_challenges',
 'admin_access_requests','admin_roles','admin_permissions','admin_role_permissions','admin_role_grants','admin_sessions',
 'admin_action_audit','admin_notifications','faq_entries','faq_revisions','support_tickets','support_messages',
 'admin_support_read_audit','parent_service_usage_events'] LOOP
 EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
 END LOOP;
END $$;
CREATE POLICY own_admin ON ap_m1.admin_accounts FOR SELECT USING(id=ap_m1.ctx_admin() OR ap_m1.has_admin_permission('OWNER_MANAGE'));
CREATE POLICY own_profile ON ap_m1.admin_profiles FOR SELECT USING(admin_id=ap_m1.ctx_admin() OR ap_m1.has_admin_permission('OWNER_MANAGE'));
CREATE POLICY own_request ON ap_m1.admin_access_requests FOR SELECT USING(admin_id=ap_m1.ctx_admin() OR ap_m1.has_admin_permission('OWNER_MANAGE'));
CREATE POLICY parent_ticket ON ap_m1.support_tickets FOR SELECT USING(requester_id=ap_m1.ctx_principal());
CREATE POLICY parent_message ON ap_m1.support_messages FOR SELECT USING(EXISTS(SELECT 1 FROM ap_m1.support_tickets t WHERE t.id=ticket_id AND t.requester_id=ap_m1.ctx_principal()));
CREATE POLICY faq_entry_read ON ap_m1.faq_entries FOR SELECT USING(state='PUBLISHED' OR ap_m1.has_admin_permission('FAQ_EDIT'));
CREATE POLICY faq_revision_read ON ap_m1.faq_revisions FOR SELECT USING(ap_m1.has_admin_permission('FAQ_EDIT') OR
 EXISTS(SELECT 1 FROM ap_m1.faq_entries e WHERE e.id=faq_id AND e.state='PUBLISHED' AND e.published_revision_id=faq_revisions.id));

GRANT SELECT ON ap_m1.admin_accounts,ap_m1.admin_profiles,ap_m1.admin_access_requests,
 ap_m1.support_tickets,ap_m1.support_messages,ap_m1.faq_entries,ap_m1.faq_revisions TO ap_m1_api;
GRANT SELECT ON ap_m1.owner_identity_allowlist,ap_m1.admin_accounts,ap_m1.admin_sessions,
 ap_m1.parent_principals,ap_m1.admin_permissions,ap_m1.admin_role_permissions,ap_m1.admin_role_grants,ap_m1.support_tickets TO ap_m1_auth;
GRANT SELECT,INSERT,UPDATE ON ap_m1.admin_accounts,ap_m1.admin_profiles,ap_m1.admin_email_challenges,
 ap_m1.admin_access_requests,ap_m1.admin_role_grants,ap_m1.admin_sessions,ap_m1.admin_notifications,
 ap_m1.faq_entries,ap_m1.support_tickets TO ap_db_executor;
GRANT SELECT,INSERT ON ap_m1.faq_revisions,ap_m1.admin_action_audit,ap_m1.support_messages,ap_m1.admin_support_read_audit TO ap_db_executor;
GRANT SELECT ON ap_m1.admin_roles,ap_m1.owner_identity_allowlist,ap_m1.parent_principals,ap_m1.parent_service_usage_events TO ap_db_executor;
ALTER VIEW ap_m1.parent_service_usage_aggregates OWNER TO ap_db_executor;
GRANT SELECT ON ap_m1.parent_service_usage_aggregates TO ap_m1_api;
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure sig,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='ap_m1' AND p.proname=ANY(ARRAY['ctx_admin','admin_is_owner','has_admin_permission','register_admin','mint_admin_session',
 'save_admin_profile','submit_admin_request','decide_admin_request','revoke_admin_grant','faq_draft','faq_transition',
 'can_support_ticket','create_support_ticket','support_reply','read_support_messages','update_support_ticket']) LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC',f.sig);
 IF f.proname=ANY(ARRAY['ctx_admin','admin_is_owner','has_admin_permission','can_support_ticket']) THEN
 EXECUTE format('ALTER FUNCTION %s OWNER TO ap_m1_auth',f.sig);
 EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO ap_m1_api,ap_db_executor',f.sig);
 ELSE
 EXECUTE format('ALTER FUNCTION %s OWNER TO ap_db_executor',f.sig);
 IF f.proname IN ('register_admin','mint_admin_session') THEN
 EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO ap_auth_issuer',f.sig);
 ELSE EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO ap_m1_api',f.sig); END IF;
 END IF;
 END LOOP;
END $$;
