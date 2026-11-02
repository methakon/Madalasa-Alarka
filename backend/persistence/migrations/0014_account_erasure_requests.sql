-- Adult account requests are distinct from exact-child erasure requests.
-- Minimize primary identity and revoke access now; financial/audit/backup stores
-- remain explicitly policy-blocked, never falsely labelled completely erased.
CREATE TABLE ap_m1.adult_erasure_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), principal_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 request_key uuid NOT NULL, state text NOT NULL DEFAULT 'REQUESTED'
 CHECK(state IN ('REQUESTED','ACCESS_REVOKED','PRIMARY_MINIMIZED','BLOCKED_POLICY','COMPLETED')),
 requested_at timestamptz NOT NULL DEFAULT now(), primary_minimized_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(principal_id,request_key)
);
CREATE UNIQUE INDEX adult_one_erasure_request ON ap_m1.adult_erasure_requests(principal_id);
CREATE TABLE ap_m1.adult_erasure_jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), request_id uuid NOT NULL REFERENCES ap_m1.adult_erasure_requests(id),
 category text NOT NULL CHECK(category IN ('FINANCIAL','SUPPORT','SECURITY_AUDIT','BACKUPS','CHILD_AUTHORITY')),
 state text NOT NULL DEFAULT 'BLOCKED_POLICY' CHECK(state IN ('BLOCKED_POLICY','PENDING','VERIFIED','FAILED_RETRYABLE')),
 retention_policy_id uuid REFERENCES ap_m1.retention_policy_versions(id), due_at timestamptz,
 proof_sha256 bytea CHECK(octet_length(proof_sha256)=32), completed_at timestamptz,
 UNIQUE(request_id,category), CHECK(state<>'VERIFIED' OR (proof_sha256 IS NOT NULL AND completed_at IS NOT NULL))
);
CREATE FUNCTION ap_m1.request_account_erasure(request_key uuid) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $fn$
DECLARE actor uuid:=ap_m1.ctx_principal(); existing uuid; result_id uuid; consent uuid; identity_row ap_m1.parent_principals;
BEGIN
 IF actor IS NULL OR request_key IS NULL THEN RAISE EXCEPTION 'authenticated account required' USING ERRCODE='42501'; END IF;
 -- Serialize account removal while retaining nonidentifying FK anchors for
 -- separately governed billing, child-authority and audit retention jobs.
 SELECT * INTO STRICT identity_row FROM ap_m1.parent_principals WHERE id=actor FOR NO KEY UPDATE;
 SELECT id INTO existing FROM ap_m1.adult_erasure_requests WHERE principal_id=actor;
 IF FOUND THEN RETURN existing; END IF;
 INSERT INTO ap_m1.adult_erasure_requests(principal_id,request_key) VALUES(actor,request_key) RETURNING id INTO result_id;
 -- Use the same device->child lock order and existing withdrawal fence as GPS.
 FOR consent IN SELECT id FROM ap_m1.consent_records WHERE adult_id=actor AND purpose='CORE' AND status='GRANTED' ORDER BY child_id LOOP
   PERFORM ap_m1.withdraw_consent(consent,request_key);
 END LOOP;
 UPDATE ap_m1.trusted_sessions SET revoked_at=COALESCE(revoked_at,clock_timestamp()),revision=revision+1,updated_at=clock_timestamp()
 WHERE principal_id=actor;
 UPDATE ap_m1.child_access_grants_v2 SET revoked_at=COALESCE(revoked_at,clock_timestamp()),revision=revision+1,updated_at=clock_timestamp()
 WHERE adult_id=actor;
 UPDATE ap_m1.guardian_memberships SET revoked_at=COALESCE(revoked_at,clock_timestamp()) WHERE principal_id=actor;
 UPDATE ap_m1.trusted_principal_verifications SET revoked_at=COALESCE(revoked_at,clock_timestamp()),revision=revision+1,updated_at=clock_timestamp() WHERE principal_id=actor;
 UPDATE ap_m1.admin_sessions SET revoked_at=COALESCE(revoked_at,clock_timestamp())
 WHERE admin_id IN (SELECT id FROM ap_m1.admin_accounts WHERE principal_id=actor);
 UPDATE ap_m1.admin_role_grants SET revoked_at=COALESCE(revoked_at,clock_timestamp())
 WHERE admin_id IN (SELECT id FROM ap_m1.admin_accounts WHERE principal_id=actor);
 DELETE FROM ap_m1.admin_email_challenges WHERE admin_id IN (SELECT id FROM ap_m1.admin_accounts WHERE principal_id=actor);
 UPDATE ap_m1.admin_profiles SET full_name='Erased account',contact_email='erased+'||actor::text||'@example.invalid',contact_verified_at=NULL,
 revision=revision+1,updated_at=clock_timestamp() WHERE admin_id IN (SELECT id FROM ap_m1.admin_accounts WHERE principal_id=actor);
 UPDATE ap_m1.admin_accounts SET verified_email='erased+'||actor::text||'@example.invalid',state='REVOKED',
 session_revocation_epoch=session_revocation_epoch+1,revision=revision+1,updated_at=clock_timestamp() WHERE principal_id=actor;
 DELETE FROM ap_m1.owner_identity_allowlist WHERE issuer=identity_row.oidc_issuer AND subject=identity_row.oidc_subject;
 UPDATE ap_m1.support_messages SET body='[Content removed at account erasure]'
 WHERE ticket_id IN (SELECT id FROM ap_m1.support_tickets WHERE requester_id=actor);
 UPDATE ap_m1.support_tickets SET subject='Erased account',revision=revision+1,updated_at=clock_timestamp() WHERE requester_id=actor;
 UPDATE ap_m1.parent_principals SET oidc_issuer='https://erased.example.invalid',oidc_subject='erased:'||actor::text WHERE id=actor;
 INSERT INTO ap_m1.adult_erasure_jobs(request_id,category)
 SELECT result_id,category FROM unnest(ARRAY['FINANCIAL','SUPPORT','SECURITY_AUDIT','BACKUPS','CHILD_AUTHORITY']) category;
 UPDATE ap_m1.adult_erasure_requests SET state='BLOCKED_POLICY',primary_minimized_at=clock_timestamp(),revision=revision+1,updated_at=clock_timestamp() WHERE id=result_id;
 RETURN result_id;
END $fn$;
ALTER FUNCTION ap_m1.request_account_erasure(uuid) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.request_account_erasure(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.request_account_erasure(uuid) TO ap_m1_api;
GRANT SELECT,INSERT,UPDATE ON ap_m1.adult_erasure_requests,ap_m1.adult_erasure_jobs TO ap_db_executor;
GRANT UPDATE ON ap_m1.parent_principals,ap_m1.guardian_memberships,ap_m1.trusted_principal_verifications,
 ap_m1.admin_sessions,ap_m1.admin_role_grants,ap_m1.admin_profiles,ap_m1.admin_accounts,
 ap_m1.support_messages,ap_m1.support_tickets TO ap_db_executor;
GRANT SELECT,DELETE ON ap_m1.owner_identity_allowlist,ap_m1.admin_email_challenges TO ap_db_executor;
ALTER TABLE ap_m1.adult_erasure_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.adult_erasure_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.adult_erasure_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.adult_erasure_jobs FORCE ROW LEVEL SECURITY;
CREATE POLICY adult_erasure_self_read ON ap_m1.adult_erasure_requests FOR SELECT TO ap_m1_api USING(principal_id=ap_m1.ctx_principal());
GRANT SELECT ON ap_m1.adult_erasure_requests TO ap_m1_api;
