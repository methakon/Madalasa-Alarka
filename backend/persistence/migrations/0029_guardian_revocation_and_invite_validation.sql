-- Issue32 B09/B18 additive hardening. Runner owns transaction; synthetic replay only.
-- Published functions retain their signatures/defaults, owners, ACL and search_path.
-- No invitation HTTP route, new TTL, verifier, delegation or media release policy.
-- Acceptance already row-locks and is single-use: wall clock only fixes expiry
-- crossing that existing lock wait, not an alleged replay/read authorization bypass.
CREATE OR REPLACE FUNCTION ap_m1.issue_child_invite(child uuid,intended_adult uuid,scopes text[],lifetime interval DEFAULT interval '1 day') RETURNS text
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
DECLARE token text; s text;
BEGIN
 IF NOT coalesce(ap_m1.has_child_scope_v2(child,'MANAGE_CHILD_GRANTS'),false)
 OR intended_adult IS NULL OR intended_adult=ap_m1.ctx_principal()
 OR scopes IS NULL OR cardinality(scopes) NOT BETWEEN 1 AND 15
 OR cardinality(scopes)<>(SELECT count(DISTINCT requested_scope) FROM unnest(scopes) AS requested(requested_scope))
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

CREATE OR REPLACE FUNCTION ap_m1.accept_child_invite(token text) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $f$
DECLARE i ap_m1.child_access_invites%ROWTYPE; review uuid; consent uuid; s text;
BEGIN
 SELECT * INTO i FROM ap_m1.child_access_invites WHERE one_time_secret_hash=public.digest(token,'sha256') FOR UPDATE;
 IF NOT FOUND OR i.state<>'PENDING' OR i.revoked_at IS NOT NULL OR i.expires_at<=clock_timestamp()
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

CREATE OR REPLACE FUNCTION ap_m1.withdraw_consent(target uuid, request_id uuid) RETURNS void
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
 UPDATE ap_m1.child_access_grants_v2 SET revoked_at=clock_timestamp(),
 revocation_epoch=revocation_epoch+1,revision=revision+1,updated_at=clock_timestamp()
 WHERE child_id=c.child_id AND revoked_at IS NULL;
 PERFORM ap_m1.revoke_child_capabilities(c.child_id);
 INSERT INTO ap_m1.consent_decision_audit(consent_id,actor_id,action,request_id)
 VALUES(target,actor,'WITHDRAWN',request_id) ON CONFLICT ON CONSTRAINT consent_decision_audit_consent_id_request_id_key DO NOTHING;
END $$;

CREATE OR REPLACE FUNCTION ap_m1.acquire_viewer_lease(target_child uuid, session_id uuid, kind text) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE result uuid; capacity integer; trusted_id uuid:=ap_m1._trusted_viewer_session();
 BEGIN
 IF trusted_id IS NULL THEN RAISE EXCEPTION 'trusted viewer session required' USING ERRCODE='42501'; END IF;
 IF kind IS NULL OR kind NOT IN ('PREMIUM_MAP','AUTHORIZED_MEDIA') OR session_id IS NULL
 THEN RAISE EXCEPTION 'invalid viewer request'; END IF;
 IF NOT ap_m1.has_child_scope_v2(target_child,CASE WHEN kind='PREMIUM_MAP' THEN 'VIEW_HISTORY' ELSE 'REQUEST_MEDIA' END)
 OR (kind='AUTHORIZED_MEDIA' AND NOT ap_m1.has_consent(target_child,'MEDIA'))
 THEN RAISE EXCEPTION 'viewer scope denied' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.children WHERE id=target_child FOR UPDATE;
 UPDATE ap_m1.premium_viewer_leases l SET revoked_at=clock_timestamp(),revision=revision+1,updated_at=clock_timestamp()
 WHERE l.child_id=target_child AND l.revoked_at IS NULL AND
 (NOT EXISTS(SELECT 1 FROM ap_m1.trusted_sessions t WHERE t.id=l.trusted_session_id
 AND t.principal_id=l.adult_id AND t.device_id IS NULL
 AND t.revoked_at IS NULL AND t.expires_at>clock_timestamp())
 OR NOT ap_m1._media_actor_live(l.child_id,l.adult_id,CASE WHEN l.screen_kind='PREMIUM_MAP' THEN 'VIEW_HISTORY' ELSE 'REQUEST_MEDIA' END)
 OR (l.screen_kind='AUTHORIZED_MEDIA' AND NOT ap_m1.has_consent(l.child_id,'MEDIA')));
 capacity:=ap_m1.viewer_capacity(target_child);
 IF capacity=0 THEN RAISE EXCEPTION 'premium access expired' USING ERRCODE='42501'; END IF;
 SELECT id INTO result FROM ap_m1.premium_viewer_leases WHERE child_id=target_child AND adult_id=ap_m1.ctx_principal()
 AND device_session_id=session_id AND trusted_session_id=trusted_id AND screen_kind=kind AND expires_at>clock_timestamp() AND revoked_at IS NULL;
 IF FOUND THEN RETURN result; END IF;
 IF (SELECT count(*) FROM ap_m1.premium_viewer_leases WHERE child_id=target_child
 AND expires_at>clock_timestamp() AND revoked_at IS NULL)>=capacity THEN RAISE EXCEPTION 'viewer capacity full' USING ERRCODE='P0001'; END IF;
 INSERT INTO ap_m1.premium_viewer_leases(child_id,adult_id,device_session_id,trusted_session_id,screen_kind)
 VALUES(target_child,ap_m1.ctx_principal(),session_id,trusted_id,kind) RETURNING id INTO result;
 INSERT INTO ap_m1.media_access_audit(child_id,adult_id,action) VALUES(target_child,ap_m1.ctx_principal(),'LEASE_ACQUIRE');
 RETURN result;
 END;
$$;


-- Stored leases are disposable authorization metadata, not session authority.
-- Re-evaluate the same live scope/consent predicates used by acquisition. Never
-- revoke account sessions or infer child authority from billing membership.
CREATE FUNCTION ap_m1.invalidate_guardian_viewer_leases() RETURNS trigger
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER
 SET search_path=pg_catalog,ap_m1,public AS $$
BEGIN
 IF TG_TABLE_NAME='trusted_sessions' THEN
  UPDATE ap_m1.premium_viewer_leases l
   SET revoked_at=clock_timestamp(),revision=l.revision+1,updated_at=clock_timestamp()
   WHERE l.trusted_session_id=NEW.id AND l.revoked_at IS NULL
   AND (NEW.revoked_at IS NOT NULL OR NEW.expires_at<=clock_timestamp());
 ELSE
  -- Consent authority can underpin grants held by another adult. Recheck only
  -- this exact child; do not assume the consenting adult is the viewer.
  UPDATE ap_m1.premium_viewer_leases l
   SET revoked_at=clock_timestamp(),revision=l.revision+1,updated_at=clock_timestamp()
   WHERE l.child_id=NEW.child_id AND l.revoked_at IS NULL
   AND (NOT ap_m1._media_actor_live(l.child_id,l.adult_id,
        CASE WHEN l.screen_kind='PREMIUM_MAP' THEN 'VIEW_HISTORY' ELSE 'REQUEST_MEDIA' END)
     OR (l.screen_kind='AUTHORIZED_MEDIA' AND NOT ap_m1.has_consent(l.child_id,'MEDIA')));
 END IF;
 RETURN NEW;
END $$;

CREATE TRIGGER guardian_grant_lease_invalidation
 AFTER UPDATE ON ap_m1.child_access_grants_v2
 FOR EACH ROW EXECUTE FUNCTION ap_m1.invalidate_guardian_viewer_leases();
CREATE TRIGGER guardian_authority_lease_invalidation
 AFTER INSERT OR UPDATE ON ap_m1.child_authority_reviews
 FOR EACH ROW EXECUTE FUNCTION ap_m1.invalidate_guardian_viewer_leases();
CREATE TRIGGER guardian_consent_lease_invalidation
 AFTER UPDATE ON ap_m1.consent_records
 FOR EACH ROW EXECUTE FUNCTION ap_m1.invalidate_guardian_viewer_leases();
CREATE TRIGGER guardian_session_lease_invalidation
 AFTER UPDATE OF revoked_at,expires_at ON ap_m1.trusted_sessions
 FOR EACH ROW EXECUTE FUNCTION ap_m1.invalidate_guardian_viewer_leases();

ALTER FUNCTION ap_m1.invalidate_guardian_viewer_leases() OWNER TO ap_db_executor;
REVOKE ALL ON FUNCTION ap_m1.invalidate_guardian_viewer_leases()
 FROM PUBLIC,ap_m1_api,ap_m1_auth,ap_auth_issuer,ap_m1_owner;
