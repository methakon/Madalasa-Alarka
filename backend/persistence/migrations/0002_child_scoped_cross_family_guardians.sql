-- V2 expand/backfill/switch. Runner owns the transaction; do not edit historical 0001.
-- No Google Family Link dependency. Identity != lawful authority != billing.
ALTER TABLE ap_m1.children ADD COLUMN deleted_at timestamptz,
 ADD COLUMN deletion_requested_at timestamptz,
 ADD COLUMN revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 ADD COLUMN updated_at timestamptz NOT NULL DEFAULT statement_timestamp();

CREATE TABLE ap_m1.local_test_settings (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 enabled boolean NOT NULL DEFAULT false,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT statement_timestamp()
);
INSERT INTO ap_m1.local_test_settings(singleton,enabled) VALUES(true,false);
CREATE TABLE ap_m1.trusted_principal_verifications (
 principal_id uuid PRIMARY KEY REFERENCES ap_m1.parent_principals(id),
 state text NOT NULL CHECK(state IN ('LOCAL_TEST_APPROVED','REVOKED')),
 verified_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 expires_at timestamptz NOT NULL DEFAULT (statement_timestamp()+interval '1 day'),
 revoked_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 CHECK(expires_at>verified_at)
);
-- Key generations are trusted enrollment/verifier state, never client GUCs.
-- This does not verify cryptographic possession or promote PENDING_PROOF devices.
ALTER TABLE ap_m1.device_key_records
 ADD COLUMN generation bigint NOT NULL DEFAULT 1 CHECK(generation>0);
CREATE TABLE ap_m1.trusted_sessions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 token_sha256 bytea NOT NULL UNIQUE CHECK(octet_length(token_sha256)=32),
 principal_id uuid REFERENCES ap_m1.parent_principals(id),
 family_id uuid REFERENCES ap_m1.families(id),
 device_id uuid REFERENCES ap_m1.devices(id),
 bound_key_id uuid REFERENCES ap_m1.device_key_records(key_id),
 bound_key_generation bigint CHECK(bound_key_generation>0),
 bound_key_fingerprint_sha256 bytea CHECK(octet_length(bound_key_fingerprint_sha256)=32),
 created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 expires_at timestamptz NOT NULL,
 revoked_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 CHECK(principal_id IS NOT NULL OR device_id IS NOT NULL),
 CHECK((device_id IS NULL AND bound_key_id IS NULL AND bound_key_generation IS NULL AND bound_key_fingerprint_sha256 IS NULL)
    OR (device_id IS NOT NULL AND bound_key_id IS NOT NULL AND bound_key_generation IS NOT NULL AND bound_key_fingerprint_sha256 IS NOT NULL)),
 CHECK(family_id IS NULL OR principal_id IS NOT NULL),
 CHECK(expires_at>created_at)
);
CREATE INDEX trusted_sessions_expiry_idx ON ap_m1.trusted_sessions(expires_at) WHERE revoked_at IS NULL;
CREATE TABLE ap_m1.child_erasure_tombstones (
 child_id uuid PRIMARY KEY,
 erased_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 reason_code text NOT NULL CHECK(length(reason_code) BETWEEN 1 AND 100)
);
CREATE TABLE ap_m1.child_authority_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 claimed_relationship text NOT NULL DEFAULT 'UNVERIFIED',
 state text NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','APPROVED','LOCAL_TEST_APPROVED','DISPUTED','REVOKED')),
 lawful_basis_version text NOT NULL CHECK(length(lawful_basis_version) BETWEEN 1 AND 100),
 method_code text NOT NULL CHECK(length(method_code) BETWEEN 1 AND 100),
 evidence_pointer_encrypted_nullable bytea,
 reviewed_at timestamptz,
 expires_at timestamptz,
 revoked_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 UNIQUE(id,child_id,adult_id),
 CHECK(state NOT IN ('APPROVED','LOCAL_TEST_APPROVED') OR (reviewed_at IS NOT NULL AND expires_at IS NOT NULL AND expires_at>reviewed_at)),
 CHECK(state<>'LOCAL_TEST_APPROVED' OR method_code='SYNTHETIC_FIXTURE')
);
CREATE INDEX authority_live_idx ON ap_m1.child_authority_reviews(child_id,adult_id);
CREATE TABLE ap_m1.consent_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 purpose text NOT NULL CHECK(purpose IN ('CORE','LOCATION','USAGE','MEDIA')),
 status text NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','GRANTED','WITHDRAWN','BLOCKED')),
 legal_state text NOT NULL DEFAULT 'PENDING' CHECK(legal_state IN ('PENDING','APPROVED','LOCAL_TEST_APPROVED','REVOKED')),
 authority_review_id uuid NOT NULL,
 notice_version text NOT NULL CHECK(length(notice_version) BETWEEN 1 AND 500),
 granted_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 expires_at timestamptz,
 withdrawn_at timestamptz,
 revoked_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 FOREIGN KEY(authority_review_id,child_id,adult_id) REFERENCES ap_m1.child_authority_reviews(id,child_id,adult_id),
 UNIQUE(id,child_id),
 CHECK(expires_at IS NULL OR expires_at>granted_at)
);
CREATE INDEX consent_live_idx ON ap_m1.consent_records(child_id,purpose);
CREATE TABLE ap_m1.child_access_invites (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 invited_by_adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 intended_adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 one_time_secret_hash bytea NOT NULL UNIQUE CHECK(octet_length(one_time_secret_hash)=32),
 requested_scopes text[] NOT NULL CHECK(cardinality(requested_scopes) BETWEEN 1 AND 15),
 state text NOT NULL DEFAULT 'PENDING' CHECK(state IN ('PENDING','ACCEPTED','REVOKED')),
 created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 expires_at timestamptz NOT NULL,
 accepted_by_adult_id uuid REFERENCES ap_m1.parent_principals(id),
 accepted_at timestamptz,
 revoked_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 CHECK(expires_at>created_at),
 CHECK(intended_adult_id<>invited_by_adult_id),
 CHECK((accepted_at IS NULL AND accepted_by_adult_id IS NULL) OR (accepted_at IS NOT NULL AND accepted_by_adult_id=intended_adult_id))
);
CREATE INDEX invites_child_idx ON ap_m1.child_access_invites(child_id,intended_adult_id);
CREATE TABLE ap_m1.child_access_grants_v2 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 scope text NOT NULL CHECK(scope IN ('VIEW_CHILD_PROFILE','VIEW_CHILD_DEVICES','PAIR_DEVICE','REVOKE_CHILD_DEVICE','MANAGE_CHILD_GRANTS','VIEW_LOCATION','VIEW_HISTORY','MANAGE_TRIPS','VIEW_ALERTS','MANAGE_ALERTS','VIEW_USAGE','MANAGE_COMMANDS','VIEW_MEDIA','REQUEST_MEDIA','MANAGE_CONSENT')),
 origin_invite_id uuid REFERENCES ap_m1.child_access_invites(id),
 consent_record_id uuid,
 authority_review_id uuid,
 issued_by uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 legacy_grant_id uuid UNIQUE REFERENCES ap_m1.child_guardian_grants(id),
 created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 expires_at timestamptz,
 revoked_at timestamptz,
 revocation_epoch bigint NOT NULL DEFAULT 1 CHECK(revocation_epoch>0),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
 FOREIGN KEY(consent_record_id,child_id) REFERENCES ap_m1.consent_records(id,child_id),
 FOREIGN KEY(authority_review_id,child_id,adult_id) REFERENCES ap_m1.child_authority_reviews(id,child_id,adult_id),
 -- Preserve even expired historical rows without approving them.
 CHECK(legacy_grant_id IS NOT NULL OR expires_at IS NULL OR expires_at>created_at)
);
CREATE UNIQUE INDEX v2_grant_live_unique ON ap_m1.child_access_grants_v2(child_id,adult_id,scope) WHERE revoked_at IS NULL;
-- Historical grants remain unapproved (NULL consent/review). Never manufacture approval.
INSERT INTO ap_m1.child_access_grants_v2(child_id,adult_id,scope,issued_by,legacy_grant_id,created_at,expires_at,revoked_at)
 SELECT child_id,principal_id,scope,principal_id,id,created_at,expires_at,revoked_at FROM ap_m1.child_guardian_grants;

DO $tables$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['local_test_settings','trusted_principal_verifications','trusted_sessions','child_erasure_tombstones','child_authority_reviews','consent_records','child_access_invites','child_access_grants_v2'] LOOP
  EXECUTE format('ALTER TABLE ap_m1.%I OWNER TO ap_m1_owner',t);
  EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON ap_m1.%I FROM PUBLIC,ap_m1_api,ap_auth_issuer',t);
  EXECUTE format('GRANT SELECT ON ap_m1.%I TO ap_m1_auth',t);
 END LOOP;
END $tables$;
GRANT SELECT ON ap_m1.children,ap_m1.families,ap_m1.device_key_records TO ap_m1_auth;
GRANT USAGE ON SCHEMA ap_m1 TO ap_db_executor,ap_auth_issuer;
GRANT SELECT ON ap_m1.local_test_settings,ap_m1.trusted_principal_verifications,
 ap_m1.parent_principals,ap_m1.families,ap_m1.guardian_memberships,ap_m1.devices,ap_m1.device_key_records,
 ap_m1.child_authority_reviews,ap_m1.consent_records TO ap_db_executor;
GRANT SELECT,INSERT,UPDATE ON ap_m1.trusted_sessions,ap_m1.child_access_invites,
 ap_m1.child_access_grants_v2,ap_m1.children TO ap_db_executor;
GRANT INSERT ON ap_m1.audit_events TO ap_db_executor;

CREATE FUNCTION ap_m1._review_live(review_id uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT EXISTS(SELECT 1 FROM ap_m1.child_authority_reviews r WHERE r.id=review_id
 AND r.revoked_at IS NULL AND r.reviewed_at<=statement_timestamp() AND r.expires_at>statement_timestamp()
 AND (r.state='APPROVED' AND r.method_code<>'SYNTHETIC_FIXTURE' OR r.state='LOCAL_TEST_APPROVED'
 AND EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled))
 AND NOT EXISTS(SELECT 1 FROM ap_m1.child_authority_reviews d WHERE d.child_id=r.child_id AND d.adult_id=r.adult_id AND d.state='DISPUTED' AND d.revoked_at IS NULL));
$f$;
CREATE FUNCTION ap_m1.child_deleted(child uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT NOT EXISTS(SELECT 1 FROM ap_m1.children c WHERE c.id=child AND c.deleted_at IS NULL AND c.deletion_requested_at IS NULL AND c.state='ACTIVE')
 OR EXISTS(SELECT 1 FROM ap_m1.child_erasure_tombstones WHERE child_id=child);
$f$;
CREATE FUNCTION ap_m1.has_consent(child uuid,purpose text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT NOT ap_m1.child_deleted(child) AND EXISTS(SELECT 1 FROM ap_m1.consent_records c
 WHERE c.child_id=child AND c.purpose=has_consent.purpose AND c.status='GRANTED'
 AND c.granted_at<=statement_timestamp() AND (c.expires_at IS NULL OR c.expires_at>statement_timestamp())
 AND c.withdrawn_at IS NULL AND c.revoked_at IS NULL AND ap_m1._review_live(c.authority_review_id)
 AND (c.legal_state='APPROVED' OR c.legal_state='LOCAL_TEST_APPROVED'
 AND EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled)));
$f$;
CREATE FUNCTION ap_m1._session() RETURNS TABLE(principal_id uuid,family_id uuid,device_id uuid)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT s.principal_id,s.family_id,s.device_id FROM ap_m1.trusted_sessions s
 WHERE s.token_sha256=public.digest(NULLIF(current_setting('ap.session_token',true),''),'sha256')
 AND s.expires_at>statement_timestamp() AND s.revoked_at IS NULL
 AND EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled)
 AND (s.principal_id IS NULL OR EXISTS(SELECT 1 FROM ap_m1.trusted_principal_verifications v
  WHERE v.principal_id=s.principal_id AND v.state='LOCAL_TEST_APPROVED' AND v.revoked_at IS NULL AND v.expires_at>statement_timestamp()))
 AND (s.family_id IS NULL OR EXISTS(SELECT 1 FROM ap_m1.guardian_memberships m JOIN ap_m1.families f ON f.id=m.family_id
  WHERE m.principal_id=s.principal_id AND m.family_id=s.family_id AND m.revoked_at IS NULL AND f.state='ACTIVE'))
 -- Re-resolve the issuer's stored key snapshot on EVERY device authorization.
 -- Key revocation/rotation alone must deny even while the device remains ACTIVE.
 AND (s.device_id IS NULL OR EXISTS(SELECT 1 FROM ap_m1.devices d
  JOIN ap_m1.device_key_records k ON k.device_id=d.id AND k.key_id=s.bound_key_id
  WHERE d.id=s.device_id AND k.state='ACTIVE' AND k.revoked_at IS NULL
  AND k.generation=s.bound_key_generation AND k.fingerprint_sha256=s.bound_key_fingerprint_sha256
  AND k.fingerprint_sha256=public.digest(d.spki_public_key,'sha256')
  AND d.enrollment_state='ACTIVE' AND d.revoked_at IS NULL AND NOT ap_m1.child_deleted(d.child_id) AND ap_m1.has_consent(d.child_id,'CORE')));
$f$;
CREATE OR REPLACE FUNCTION ap_m1.ctx_principal() RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path=pg_catalog,ap_m1,public AS $f$ SELECT principal_id FROM ap_m1._session(); $f$;
CREATE OR REPLACE FUNCTION ap_m1.ctx_family() RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path=pg_catalog,ap_m1,public AS $f$ SELECT family_id FROM ap_m1._session(); $f$;
CREATE OR REPLACE FUNCTION ap_m1.ctx_device() RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path=pg_catalog,ap_m1,public AS $f$ SELECT device_id FROM ap_m1._session(); $f$;

CREATE FUNCTION ap_m1._adult_has_scope(child uuid,actor uuid,wanted text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT actor IS NOT NULL AND NOT ap_m1.child_deleted(child) AND ap_m1.has_consent(child,'CORE')
 AND EXISTS(SELECT 1 FROM ap_m1.child_access_grants_v2 g JOIN ap_m1.consent_records c ON c.id=g.consent_record_id AND c.child_id=g.child_id
 WHERE g.child_id=child AND g.adult_id=actor AND g.scope=wanted
 AND g.revoked_at IS NULL AND (g.expires_at IS NULL OR g.expires_at>statement_timestamp())
 AND ap_m1._review_live(g.authority_review_id) AND c.purpose='CORE' AND c.status='GRANTED'
 AND c.revoked_at IS NULL AND c.withdrawn_at IS NULL AND (c.expires_at IS NULL OR c.expires_at>statement_timestamp())
 AND ap_m1._review_live(c.authority_review_id)
 AND (c.legal_state='APPROVED' OR c.legal_state='LOCAL_TEST_APPROVED' AND EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled))
 AND (g.origin_invite_id IS NULL AND g.issued_by=g.adult_id AND g.legacy_grant_id IS NULL
 OR EXISTS(SELECT 1 FROM ap_m1.child_access_invites i WHERE i.id=g.origin_invite_id AND i.child_id=g.child_id
 AND i.intended_adult_id=g.adult_id AND i.accepted_by_adult_id=g.adult_id AND i.accepted_at IS NOT NULL
 AND i.state='ACCEPTED' AND i.revoked_at IS NULL AND g.scope=ANY(i.requested_scopes))));
$f$;
CREATE FUNCTION ap_m1.has_child_scope_v2(child uuid,wanted text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT ap_m1._adult_has_scope(child,ap_m1.ctx_principal(),wanted);
$f$;
CREATE OR REPLACE FUNCTION ap_m1.has_scope(target_family uuid,target_child uuid,wanted text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT EXISTS(SELECT 1 FROM ap_m1.children WHERE id=target_child AND family_id=target_family)
 AND ap_m1.has_child_scope_v2(target_child,wanted);
$f$;
CREATE OR REPLACE FUNCTION ap_m1.family_owner(target_family uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT target_family=ap_m1.ctx_family() AND EXISTS(SELECT 1 FROM ap_m1.guardian_memberships m JOIN ap_m1.families f ON f.id=m.family_id
 WHERE m.family_id=target_family AND m.principal_id=ap_m1.ctx_principal() AND m.membership_role='OWNER' AND m.revoked_at IS NULL AND f.state='ACTIVE');
$f$;
CREATE OR REPLACE FUNCTION ap_m1.owns_active_device(target_device uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 SELECT target_device=ap_m1.ctx_device() AND EXISTS(SELECT 1 FROM ap_m1.devices d WHERE d.id=target_device
 AND d.enrollment_state='ACTIVE' AND d.revoked_at IS NULL AND NOT ap_m1.child_deleted(d.child_id) AND ap_m1.has_consent(d.child_id,'CORE'));
$f$;

CREATE FUNCTION ap_m1.mint_session(principal uuid,family uuid DEFAULT NULL,device uuid DEFAULT NULL,lifetime interval DEFAULT interval '1 hour') RETURNS text
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
DECLARE token text; binding ap_m1.device_key_records%ROWTYPE;
BEGIN
 -- Only pre-verified synthetic identities; no production identity assertion path.
 IF lifetime IS NULL OR lifetime<=interval '0' OR lifetime>interval '24 hours'
 OR NOT EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled)
 OR (principal IS NULL AND device IS NULL)
 OR (principal IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ap_m1.trusted_principal_verifications v WHERE v.principal_id=principal
  AND v.state='LOCAL_TEST_APPROVED' AND v.revoked_at IS NULL AND v.expires_at>statement_timestamp()))
 OR (family IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ap_m1.guardian_memberships m JOIN ap_m1.families f ON f.id=m.family_id
  WHERE m.principal_id=principal AND m.family_id=family AND m.revoked_at IS NULL AND f.state='ACTIVE'))
 THEN RAISE EXCEPTION 'session denied' USING ERRCODE='42501'; END IF;
 IF device IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ap_m1.devices d WHERE d.id=device AND d.enrollment_state='ACTIVE'
 AND d.revoked_at IS NULL AND NOT ap_m1.child_deleted(d.child_id) AND ap_m1.has_consent(d.child_id,'CORE')
 AND (family IS NULL OR family=d.family_id)
 AND (principal IS NULL OR ap_m1._adult_has_scope(d.child_id,principal,'VIEW_CHILD_DEVICES')))
 THEN RAISE EXCEPTION 'session denied' USING ERRCODE='42501'; END IF;
 IF device IS NOT NULL THEN
  -- No caller key ID/fingerprint/generation argument or GUC is accepted. Only
  -- privileged enrollment state selects this binding; synthetic mint is not
  -- real proof-of-possession. Pending proof still fails the device check above.
  SELECT k.* INTO binding FROM ap_m1.device_key_records k
   JOIN ap_m1.devices d ON d.id=k.device_id
   WHERE k.device_id=device AND k.state='ACTIVE' AND k.revoked_at IS NULL
   AND octet_length(k.fingerprint_sha256)=32
   AND k.fingerprint_sha256=public.digest(d.spki_public_key,'sha256');
  IF NOT FOUND THEN RAISE EXCEPTION 'session denied' USING ERRCODE='42501'; END IF;
 END IF;
 token:=encode(public.gen_random_bytes(32),'hex');
 INSERT INTO ap_m1.trusted_sessions(token_sha256,principal_id,family_id,device_id,
  bound_key_id,bound_key_generation,bound_key_fingerprint_sha256,expires_at)
 VALUES(public.digest(token,'sha256'),principal,family,device,
  binding.key_id,binding.generation,binding.fingerprint_sha256,statement_timestamp()+lifetime);
 RETURN token;
END $f$;
CREATE FUNCTION ap_m1.revoke_session(token text) RETURNS void
 LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
 UPDATE ap_m1.trusted_sessions SET revoked_at=statement_timestamp(),revision=revision+1,updated_at=statement_timestamp()
 WHERE token_sha256=public.digest(token,'sha256') AND revoked_at IS NULL;
$f$;
CREATE FUNCTION ap_m1.create_child(alias text) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
DECLARE child uuid;
BEGIN
 IF NOT coalesce(ap_m1.family_owner(ap_m1.ctx_family()),false) OR alias IS NULL OR length(alias) NOT BETWEEN 1 AND 80
 THEN RAISE EXCEPTION 'operation denied' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.children(family_id,alias) VALUES(ap_m1.ctx_family(),alias) RETURNING id INTO child;
 INSERT INTO ap_m1.audit_events(family_id,actor_principal_id,action,result_code)
 VALUES(ap_m1.ctx_family(),ap_m1.ctx_principal(),'CHILD_CREATED','PENDING_AUTHORITY_REVIEW');
 -- No automatic data grants/consent/authority. A reviewed workflow must follow.
 RETURN child;
END $f$;
CREATE FUNCTION ap_m1.issue_child_invite(child uuid,intended_adult uuid,scopes text[],lifetime interval DEFAULT interval '1 day') RETURNS text
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
DECLARE token text; s text;
BEGIN
 IF NOT coalesce(ap_m1.has_child_scope_v2(child,'MANAGE_CHILD_GRANTS'),false)
 OR intended_adult IS NULL OR intended_adult=ap_m1.ctx_principal()
 OR scopes IS NULL OR cardinality(scopes) NOT BETWEEN 1 AND 15
 OR lifetime IS NULL OR lifetime<=interval '0' OR lifetime>interval '7 days'
 OR NOT EXISTS(SELECT 1 FROM ap_m1.parent_principals WHERE id=intended_adult)
 THEN RAISE EXCEPTION 'invitation denied' USING ERRCODE='42501'; END IF;
 FOREACH s IN ARRAY scopes LOOP
  -- Grant management, enrollment, media and consent never delegated by an invite.
  IF s IS NULL OR s NOT IN ('VIEW_CHILD_PROFILE','VIEW_CHILD_DEVICES','VIEW_LOCATION','VIEW_HISTORY','MANAGE_TRIPS','VIEW_ALERTS','MANAGE_ALERTS','VIEW_USAGE')
  OR NOT coalesce(ap_m1.has_child_scope_v2(child,s),false)
  THEN RAISE EXCEPTION 'invitation denied' USING ERRCODE='42501'; END IF;
 END LOOP;
 token:=encode(public.gen_random_bytes(32),'hex');
 INSERT INTO ap_m1.child_access_invites(child_id,invited_by_adult_id,intended_adult_id,one_time_secret_hash,requested_scopes,expires_at)
 VALUES(child,ap_m1.ctx_principal(),intended_adult,public.digest(token,'sha256'),scopes,statement_timestamp()+lifetime);
 INSERT INTO ap_m1.audit_events(family_id,actor_principal_id,action,result_code)
 SELECT family_id,ap_m1.ctx_principal(),'CHILD_INVITE_ISSUED','SUCCESS' FROM ap_m1.children WHERE id=child;
 RETURN token;
END $f$;
CREATE FUNCTION ap_m1.accept_child_invite(token text) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
DECLARE i ap_m1.child_access_invites%ROWTYPE; review uuid; consent uuid; s text;
BEGIN
 SELECT * INTO i FROM ap_m1.child_access_invites WHERE one_time_secret_hash=public.digest(token,'sha256') FOR UPDATE;
 IF NOT FOUND OR i.state<>'PENDING' OR i.revoked_at IS NOT NULL OR i.expires_at<=statement_timestamp()
 OR i.intended_adult_id IS DISTINCT FROM ap_m1.ctx_principal()
 OR NOT ap_m1.has_consent(i.child_id,'CORE')
 THEN RAISE EXCEPTION 'invitation denied' USING ERRCODE='42501'; END IF;
 -- Explicit live issuer check, not a historical OWNER/billing membership assertion.
 IF NOT ap_m1._adult_has_scope(i.child_id,i.invited_by_adult_id,'MANAGE_CHILD_GRANTS')
 THEN RAISE EXCEPTION 'invitation denied' USING ERRCODE='42501'; END IF;
 SELECT id INTO review FROM ap_m1.child_authority_reviews r WHERE r.child_id=i.child_id AND r.adult_id=i.intended_adult_id
 AND ap_m1._review_live(r.id) ORDER BY reviewed_at DESC LIMIT 1;
 SELECT id INTO consent FROM ap_m1.consent_records c WHERE c.child_id=i.child_id AND c.purpose='CORE' AND c.status='GRANTED'
 AND c.withdrawn_at IS NULL AND c.revoked_at IS NULL AND (c.expires_at IS NULL OR c.expires_at>statement_timestamp())
 AND ap_m1._review_live(c.authority_review_id)
 AND (c.legal_state='APPROVED' OR c.legal_state='LOCAL_TEST_APPROVED' AND EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled))
 ORDER BY c.granted_at DESC LIMIT 1;
 IF review IS NULL OR consent IS NULL THEN RAISE EXCEPTION 'invitation denied' USING ERRCODE='42501'; END IF;
 FOREACH s IN ARRAY i.requested_scopes LOOP
  -- Recheck source scope at acceptance, including narrowed/revoked source grants.
  IF NOT ap_m1._adult_has_scope(i.child_id,i.invited_by_adult_id,s)
  THEN RAISE EXCEPTION 'invitation denied' USING ERRCODE='42501'; END IF;
  INSERT INTO ap_m1.child_access_grants_v2(child_id,adult_id,scope,origin_invite_id,consent_record_id,authority_review_id,issued_by,expires_at)
  VALUES(i.child_id,i.intended_adult_id,s,i.id,consent,review,i.invited_by_adult_id,i.expires_at);
 END LOOP;
 UPDATE ap_m1.child_access_invites SET state='ACCEPTED',accepted_by_adult_id=ap_m1.ctx_principal(),accepted_at=statement_timestamp(),revision=revision+1,updated_at=statement_timestamp() WHERE id=i.id;
 INSERT INTO ap_m1.audit_events(family_id,actor_principal_id,action,result_code)
 SELECT family_id,ap_m1.ctx_principal(),'CHILD_INVITE_ACCEPTED','SUCCESS' FROM ap_m1.children WHERE id=i.child_id;
 RETURN i.child_id;
END $f$;
CREATE FUNCTION ap_m1.revoke_child_invite(invite uuid) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
DECLARE i ap_m1.child_access_invites%ROWTYPE;
BEGIN
 SELECT * INTO i FROM ap_m1.child_access_invites WHERE id=invite FOR UPDATE;
 IF NOT FOUND OR NOT coalesce(ap_m1.has_child_scope_v2(i.child_id,'MANAGE_CHILD_GRANTS'),false)
 THEN RAISE EXCEPTION 'invitation denied' USING ERRCODE='42501'; END IF;
 UPDATE ap_m1.child_access_invites SET state='REVOKED',revoked_at=statement_timestamp(),revision=revision+1,updated_at=statement_timestamp() WHERE id=invite;
 UPDATE ap_m1.child_access_grants_v2 SET revoked_at=statement_timestamp(),revocation_epoch=revocation_epoch+1,revision=revision+1,updated_at=statement_timestamp() WHERE origin_invite_id=invite AND revoked_at IS NULL;
 INSERT INTO ap_m1.audit_events(family_id,actor_principal_id,action,result_code)
 SELECT family_id,ap_m1.ctx_principal(),'CHILD_INVITE_REVOKED','SUCCESS' FROM ap_m1.children WHERE id=i.child_id;
END $f$;
CREATE FUNCTION ap_m1.revoke_child_grant(grant_id uuid) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
DECLARE child uuid;
BEGIN
 SELECT child_id INTO child FROM ap_m1.child_access_grants_v2 WHERE id=grant_id FOR UPDATE;
 IF child IS NULL OR NOT coalesce(ap_m1.has_child_scope_v2(child,'MANAGE_CHILD_GRANTS'),false)
 THEN RAISE EXCEPTION 'operation denied' USING ERRCODE='42501'; END IF;
 UPDATE ap_m1.child_access_grants_v2 SET revoked_at=statement_timestamp(),revocation_epoch=revocation_epoch+1,revision=revision+1,updated_at=statement_timestamp() WHERE id=grant_id;
 INSERT INTO ap_m1.audit_events(family_id,actor_principal_id,action,result_code)
 SELECT family_id,ap_m1.ctx_principal(),'CHILD_GRANT_REVOKED','SUCCESS' FROM ap_m1.children WHERE id=child;
END $f$;

-- Retire every old policy, including dangerous self-membership bootstrap writes.
DO $policies$
DECLARE p record;
BEGIN
 FOR p IN SELECT tablename,policyname FROM pg_policies WHERE schemaname='ap_m1' LOOP
  EXECUTE format('DROP POLICY %I ON ap_m1.%I',p.policyname,p.tablename);
 END LOOP;
END $policies$;
REVOKE INSERT,UPDATE,DELETE ON ap_m1.families,ap_m1.guardian_memberships,ap_m1.children,
 ap_m1.child_guardian_grants,ap_m1.pairing_codes,ap_m1.devices FROM ap_m1_api;
CREATE POLICY families_r ON ap_m1.families FOR SELECT TO ap_m1_api USING(ap_m1.family_owner(id));
CREATE POLICY parents_r ON ap_m1.parent_principals FOR SELECT TO ap_m1_api USING(id=ap_m1.ctx_principal());
CREATE POLICY memberships_r ON ap_m1.guardian_memberships FOR SELECT TO ap_m1_api
 USING(family_id=ap_m1.ctx_family() AND (principal_id=ap_m1.ctx_principal() OR ap_m1.family_owner(family_id)));
CREATE POLICY children_r ON ap_m1.children FOR SELECT TO ap_m1_api USING(ap_m1.has_child_scope_v2(id,'VIEW_CHILD_PROFILE'));
-- child_guardian_grants retired; enrollment_challenges, device_key_records,
-- command_results intentionally remain default-deny (no M1 runtime policies).
CREATE POLICY pairing_r ON ap_m1.pairing_codes FOR SELECT TO ap_m1_api USING(ap_m1.has_child_scope_v2(child_id,'PAIR_DEVICE'));
CREATE POLICY devices_r ON ap_m1.devices FOR SELECT TO ap_m1_api USING(ap_m1.has_child_scope_v2(child_id,'VIEW_CHILD_DEVICES'));
CREATE POLICY snapshots_r ON ap_m1.capability_snapshots FOR SELECT TO ap_m1_api
 USING(EXISTS(SELECT 1 FROM ap_m1.devices d WHERE d.id=device_id AND ap_m1.has_child_scope_v2(d.child_id,'VIEW_CHILD_DEVICES')));
CREATE POLICY snapshots_i ON ap_m1.capability_snapshots FOR INSERT TO ap_m1_api WITH CHECK(ap_m1.owns_active_device(device_id));
CREATE POLICY health_r ON ap_m1.device_health FOR SELECT TO ap_m1_api
 USING(EXISTS(SELECT 1 FROM ap_m1.devices d WHERE d.id=device_id AND ap_m1.has_child_scope_v2(d.child_id,'VIEW_CHILD_DEVICES')));
CREATE POLICY health_i ON ap_m1.device_health FOR INSERT TO ap_m1_api WITH CHECK(ap_m1.owns_active_device(device_id));
CREATE POLICY health_u ON ap_m1.device_health FOR UPDATE TO ap_m1_api USING(ap_m1.owns_active_device(device_id)) WITH CHECK(ap_m1.owns_active_device(device_id));
CREATE POLICY cmds_r ON ap_m1.commands FOR SELECT TO ap_m1_api
 USING(EXISTS(SELECT 1 FROM ap_m1.devices d WHERE d.id=device_id AND ap_m1.has_child_scope_v2(d.child_id,'MANAGE_COMMANDS')));
CREATE POLICY audit_r ON ap_m1.audit_events FOR SELECT TO ap_m1_api USING(ap_m1.family_owner(family_id));
CREATE POLICY revocation_r ON ap_m1.revocation_epochs FOR SELECT TO ap_m1_api USING(ap_m1.family_owner(family_id));
GRANT SELECT ON ap_m1.child_access_grants_v2,ap_m1.consent_records TO ap_m1_api;
CREATE POLICY consents_r ON ap_m1.consent_records FOR SELECT TO ap_m1_api
 USING(ap_m1.has_child_scope_v2(child_id,'MANAGE_CONSENT'));
CREATE POLICY grants_v2_r ON ap_m1.child_access_grants_v2 FOR SELECT TO ap_m1_api
 USING(ap_m1.has_child_scope_v2(child_id,'VIEW_CHILD_PROFILE') AND (adult_id=ap_m1.ctx_principal() OR ap_m1.has_child_scope_v2(child_id,'MANAGE_CHILD_GRANTS')));
-- Invite tokens/hashes are never directly exposed to API, even to the inviter.
REVOKE SELECT ON ap_m1.child_access_invites FROM ap_m1_api;

DO $functions$
DECLARE f record;
BEGIN
 FOR f IN SELECT p.oid::regprocedure AS sig,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='ap_m1' LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,ap_m1_api,ap_auth_issuer',f.sig);
  IF f.proname IN ('mint_session','revoke_session','create_child','issue_child_invite','accept_child_invite','revoke_child_invite','revoke_child_grant') THEN
   EXECUTE format('ALTER FUNCTION %s OWNER TO ap_db_executor',f.sig);
  ELSE
   EXECUTE format('ALTER FUNCTION %s OWNER TO ap_m1_auth',f.sig);
  END IF;
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO ap_m1_auth,ap_db_executor',f.sig);
  IF f.proname IN ('mint_session','revoke_session') THEN
   EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO ap_auth_issuer',f.sig);
   -- Lookup helper owner stays strictly read-only, including via function calls.
   EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM ap_m1_auth',f.sig);
  ELSIF f.proname NOT IN ('_session','_review_live','_adult_has_scope') THEN
   EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO ap_m1_api',f.sig);
  END IF;
  IF f.proname IN ('create_child','issue_child_invite','accept_child_invite','revoke_child_invite','revoke_child_grant') THEN
   EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM ap_m1_auth',f.sig);
  END IF;
 END LOOP;
END $functions$;
