-- Purpose/version records supplement, never replace, 0002 consent_records/reviews.
-- No adopted TTLs. No client-controlled legal-approval switch.
CREATE TABLE ap_m1.consent_policy_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), purpose text NOT NULL CHECK(purpose IN ('CORE','LOCATION','USAGE','MEDIA')),
 version text NOT NULL CHECK(length(version) BETWEEN 1 AND 100),
 state text NOT NULL DEFAULT 'DRAFT' CHECK(state IN ('DRAFT','APPROVED','RETIRED')),
 effective_from timestamptz, approved_reference text,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(purpose,version), CHECK(state<>'APPROVED' OR (effective_from IS NOT NULL AND coalesce(length(approved_reference),0)>0))
);
CREATE TABLE ap_m1.consent_documents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), policy_id uuid NOT NULL REFERENCES ap_m1.consent_policy_versions(id),
 language text NOT NULL CHECK(language ~ '^[a-z]{2}(-[A-Z]{2})?$'),
 document_version text NOT NULL CHECK(length(document_version) BETWEEN 1 AND 100),
 content_sha256 bytea NOT NULL CHECK(octet_length(content_sha256)=32),
 content_text text NOT NULL CHECK(length(content_text) BETWEEN 1 AND 50000),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(policy_id,language,document_version), UNIQUE(policy_id,id)
);
ALTER TABLE ap_m1.consent_records ADD COLUMN policy_version_id uuid REFERENCES ap_m1.consent_policy_versions(id);
ALTER TABLE ap_m1.consent_records ADD COLUMN document_id uuid;
ALTER TABLE ap_m1.consent_records ADD FOREIGN KEY(policy_version_id,document_id) REFERENCES ap_m1.consent_documents(policy_id,id);
CREATE TABLE ap_m1.consent_decision_audit (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), consent_id uuid NOT NULL REFERENCES ap_m1.consent_records(id),
 actor_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 action text NOT NULL CHECK(action IN ('REQUESTED','GRANTED','WITHDRAWN','BLOCKED')),
 request_id uuid NOT NULL, occurred_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(consent_id,request_id), UNIQUE(actor_id,request_id)
);
CREATE TABLE ap_m1.retention_policy_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), category text NOT NULL CHECK(length(category) BETWEEN 1 AND 100),
 version text NOT NULL CHECK(length(version) BETWEEN 1 AND 100),
 state text NOT NULL DEFAULT 'DRAFT' CHECK(state IN ('DRAFT','APPROVED','RETIRED')),
 period_days integer CHECK(period_days>0),
 clock_basis text NOT NULL CHECK(clock_basis IN ('OBSERVED_AT','CREATED_AT','CLOSED_AT','REVOKED_AT','BACKUP_COMPLETED_AT')),
 purpose text NOT NULL CHECK(length(purpose) BETWEEN 1 AND 1000),
 deletion_method text NOT NULL CHECK(length(deletion_method) BETWEEN 1 AND 500),
 backups_bound_days integer CHECK(backups_bound_days>0),
 exception_review_reference text, approval_reference text, effective_from timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(category,version),
 CHECK(state<>'APPROVED' OR (period_days IS NOT NULL AND backups_bound_days IS NOT NULL
 AND effective_from IS NOT NULL AND coalesce(length(approval_reference),0)>0))
);
CREATE INDEX retention_effective ON ap_m1.retention_policy_versions(category,effective_from DESC) WHERE state='APPROVED';
CREATE FUNCTION ap_m1.retention_deadline(category text, original_time timestamptz) RETURNS timestamptz
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
 SELECT original_time+make_interval(days=>p.period_days) FROM ap_m1.retention_policy_versions p
 WHERE p.category=retention_deadline.category AND p.state='APPROVED' AND p.effective_from<=now()
 ORDER BY p.effective_from DESC,p.id LIMIT 1
$$;
-- Optional later-domain tables are hard-coded, never supplied by an API caller.
-- This function is deliberately not API executable: withdrawal/erasure invoke it.
CREATE FUNCTION ap_m1.revoke_child_capabilities(target uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE tbl text;
BEGIN
 -- Every child-scoped consumer must also recheck has_consent/child_deleted.
 -- Physical termination supports migrations that are introduced after this one.
 FOREACH tbl IN ARRAY ARRAY['premium_viewer_leases','media_sessions','media_command_requests','media_request_device_approvals'] LOOP
 IF to_regclass('ap_m1.'||tbl) IS NOT NULL THEN
 IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass('ap_m1.'||tbl) AND attname='child_id' AND NOT attisdropped) THEN
 IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass('ap_m1.'||tbl) AND attname='revoked_at' AND NOT attisdropped) THEN
 EXECUTE format('UPDATE ap_m1.%I SET revoked_at=coalesce(revoked_at,now()) WHERE child_id=$1',tbl) USING target;
 END IF;
 IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass('ap_m1.'||tbl) AND attname='expires_at' AND NOT attisdropped) THEN
 EXECUTE format('UPDATE ap_m1.%I SET expires_at=least(expires_at,clock_timestamp()) WHERE child_id=$1',tbl) USING target;
 END IF;
 IF tbl='media_sessions' AND EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass('ap_m1.'||tbl) AND attname='ended_at' AND NOT attisdropped) THEN
 EXECUTE 'UPDATE ap_m1.media_sessions SET ended_at=coalesce(ended_at,clock_timestamp()) WHERE child_id=$1' USING target;
 END IF;
 END IF;
 END IF;
 END LOOP;
 UPDATE ap_m1.commands SET command_state='CANCELLED'
 WHERE device_id IN (SELECT id FROM ap_m1.devices WHERE child_id=target)
 AND command_state IN ('CREATED','QUEUED','DELIVERED');
END $$;
CREATE FUNCTION ap_m1.withdraw_consent(target uuid, request_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE c ap_m1.consent_records; actor uuid:=ap_m1.ctx_principal();
BEGIN
 SELECT * INTO STRICT c FROM ap_m1.consent_records WHERE id=target;
 -- Match ingestion's device -> child -> consent lock order. In particular do
 -- not hold a consent UPDATE lock while waiting for ingestion's child SHARE.
 PERFORM 1 FROM ap_m1.devices WHERE child_id=c.child_id ORDER BY id FOR UPDATE;
 PERFORM 1 FROM ap_m1.children WHERE id=c.child_id FOR UPDATE;
 SELECT * INTO STRICT c FROM ap_m1.consent_records WHERE id=target FOR UPDATE;
 -- Repeat by the same consenting adult is safe after scope has been revoked.
 IF actor IS NULL OR (c.adult_id<>actor AND NOT ap_m1.has_child_scope_v2(c.child_id,'MANAGE_CONSENT'))
 THEN RAISE EXCEPTION 'consent withdrawal denied' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.children WHERE id=c.child_id FOR UPDATE;
 -- Withdrawal fences all child capabilities, including an already-paid stream.
 UPDATE ap_m1.consent_records SET status='WITHDRAWN',withdrawn_at=coalesce(withdrawn_at,now()),
 revision=revision+1,updated_at=statement_timestamp()
 WHERE child_id=c.child_id AND (id=target OR purpose='CORE') AND status='GRANTED';
 UPDATE ap_m1.child_access_grants_v2 SET revoked_at=coalesce(revoked_at,now()) WHERE child_id=c.child_id;
 PERFORM ap_m1.revoke_child_capabilities(c.child_id);
 INSERT INTO ap_m1.consent_decision_audit(consent_id,actor_id,action,request_id)
 VALUES(target,actor,'WITHDRAWN',request_id) ON CONFLICT ON CONSTRAINT consent_decision_audit_consent_id_request_id_key DO NOTHING;
END $$;
CREATE FUNCTION ap_m1.request_consent_review(target_child uuid, target_document uuid, target_review uuid, request_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1 AS $$
DECLARE doc record; result uuid; actor uuid:=ap_m1.ctx_principal();
BEGIN
 IF actor IS NULL OR NOT ap_m1.has_child_scope_v2(target_child,'MANAGE_CONSENT')
 THEN RAISE EXCEPTION 'consent review denied' USING ERRCODE='42501'; END IF;
 SELECT d.id,d.policy_id,p.purpose,d.document_version INTO STRICT doc FROM ap_m1.consent_documents d
 JOIN ap_m1.consent_policy_versions p ON p.id=d.policy_id
 WHERE d.id=target_document AND p.state='APPROVED' AND p.effective_from<=statement_timestamp();
 IF NOT EXISTS(SELECT 1 FROM ap_m1.child_authority_reviews WHERE id=target_review AND child_id=target_child AND adult_id=actor)
 THEN RAISE EXCEPTION 'authority review mismatch' USING ERRCODE='42501'; END IF;
 -- This records a request, NOT statutory authority approval; ingestion stays denied.
 SELECT a.consent_id INTO result FROM ap_m1.consent_decision_audit a JOIN ap_m1.consent_records c ON c.id=a.consent_id
 WHERE a.actor_id=actor AND a.request_id=request_consent_review.request_id AND a.action='REQUESTED'
 AND c.child_id=target_child AND c.document_id=target_document;
 IF result IS NOT NULL THEN RETURN result; END IF;
 INSERT INTO ap_m1.consent_records(child_id,adult_id,purpose,status,legal_state,authority_review_id,notice_version,policy_version_id,document_id)
 VALUES(target_child,actor,doc.purpose,'PENDING','PENDING',target_review,doc.document_version,doc.policy_id,doc.id) RETURNING id INTO result;
 INSERT INTO ap_m1.consent_decision_audit(consent_id,actor_id,action,request_id) VALUES(result,actor,'REQUESTED',request_id);
 RETURN result;
END $$;
GRANT INSERT ON ap_m1.consent_records TO ap_db_executor;
GRANT SELECT ON ap_m1.consent_documents,ap_m1.consent_policy_versions TO ap_db_executor;
ALTER FUNCTION ap_m1.request_consent_review(uuid,uuid,uuid,uuid) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.request_consent_review(uuid,uuid,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.request_consent_review(uuid,uuid,uuid,uuid) TO ap_m1_api;

DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['consent_policy_versions','consent_documents','consent_decision_audit','retention_policy_versions'] LOOP
 EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
 END LOOP;
END $$;
CREATE POLICY consent_policy_read ON ap_m1.consent_policy_versions FOR SELECT USING(state='APPROVED' AND effective_from<=now());
CREATE POLICY consent_document_read ON ap_m1.consent_documents FOR SELECT USING(EXISTS(
 SELECT 1 FROM ap_m1.consent_policy_versions p WHERE p.id=policy_id AND p.state='APPROVED' AND p.effective_from<=now()));
CREATE POLICY own_consent_decision_audit ON ap_m1.consent_decision_audit FOR SELECT USING(actor_id=ap_m1.ctx_principal());
GRANT SELECT ON ap_m1.consent_policy_versions,ap_m1.consent_documents,ap_m1.consent_decision_audit TO ap_m1_api;
GRANT SELECT ON ap_m1.retention_policy_versions TO ap_m1_auth;
GRANT SELECT,UPDATE ON ap_m1.consent_records,ap_m1.child_access_grants_v2,ap_m1.children,ap_m1.commands TO ap_db_executor;
GRANT SELECT,UPDATE ON ap_m1.devices TO ap_db_executor;
GRANT SELECT,INSERT ON ap_m1.consent_decision_audit TO ap_db_executor;
ALTER FUNCTION ap_m1.retention_deadline(text,timestamptz) OWNER TO ap_m1_auth;
ALTER FUNCTION ap_m1.revoke_child_capabilities(uuid) OWNER TO ap_db_executor;
ALTER FUNCTION ap_m1.withdraw_consent(uuid,uuid) OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.retention_deadline(text,timestamptz),ap_m1.revoke_child_capabilities(uuid),ap_m1.withdraw_consent(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ap_m1.retention_deadline(text,timestamptz) TO ap_db_executor;
GRANT EXECUTE ON FUNCTION ap_m1.withdraw_consent(uuid,uuid) TO ap_m1_api;
