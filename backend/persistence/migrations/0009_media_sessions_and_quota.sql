-- Metadata-only local domain. No URLs, filenames, media blobs or transport secrets.
-- No outer transaction. Real capture permanently fails closed in this migration.
CREATE TABLE ap_m1.premium_viewer_leases (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 device_session_id uuid NOT NULL,
 trusted_session_id uuid NOT NULL REFERENCES ap_m1.trusted_sessions(id),
 screen_kind text NOT NULL CHECK(screen_kind IN ('PREMIUM_MAP','AUTHORIZED_MEDIA')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 heartbeat_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL DEFAULT clock_timestamp()+interval '90 seconds',
 revoked_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX viewer_child_expiry_idx ON ap_m1.premium_viewer_leases(child_id,expires_at) WHERE revoked_at IS NULL;
CREATE TABLE ap_m1.viewer_takeover_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 active_lease uuid NOT NULL REFERENCES ap_m1.premium_viewer_leases(id),
 requester_adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 state text NOT NULL DEFAULT 'REQUESTED' CHECK(state IN ('REQUESTED','APPROVED','REFUSED')),
 requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL DEFAULT clock_timestamp()+interval '2 minutes',
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ap_m1.media_capability_gates (
 feature text PRIMARY KEY CHECK(feature IN ('AUDIO','VIDEO_AV','IMAGE','SCREEN_SHARE')),
 released boolean NOT NULL DEFAULT false CHECK(NOT released),
 android_gate text NOT NULL DEFAULT 'UNVERIFIED' CHECK(android_gate='UNVERIFIED'),
 play_legal_gate text NOT NULL DEFAULT 'UNAPPROVED' CHECK(play_legal_gate='UNAPPROVED'),
 real_capture_enabled boolean NOT NULL DEFAULT false CHECK(NOT real_capture_enabled)
);
INSERT INTO ap_m1.media_capability_gates(feature) VALUES('AUDIO'),('VIDEO_AV'),('IMAGE'),('SCREEN_SHARE');
CREATE TABLE ap_m1.media_command_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 device_id uuid NOT NULL REFERENCES ap_m1.devices(id),
 adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 kind text NOT NULL REFERENCES ap_m1.media_capability_gates(feature),
 state text NOT NULL DEFAULT 'UNSUPPORTED' CHECK(state='UNSUPPORTED'),
 reason_code text NOT NULL DEFAULT 'FEATURE_NOT_RELEASED' CHECK(reason_code='FEATURE_NOT_RELEASED'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ap_m1.media_sessions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 request_id uuid NOT NULL UNIQUE REFERENCES ap_m1.media_command_requests(id),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 authorized_adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 ended_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 transport_mode text NOT NULL DEFAULT 'LOCAL_SYNTHETIC_NO_CAPTURE' CHECK(transport_mode='LOCAL_SYNTHETIC_NO_CAPTURE'),
 exit_reason text NOT NULL CHECK(exit_reason IN ('DELIVERED_SYNTHETIC','OS_REJECTED','PERMISSION_REQUIRED','FAILED'))
);
CREATE TABLE ap_m1.media_lifecycle_events (
 event_id uuid PRIMARY KEY,
 media_session_id uuid NOT NULL REFERENCES ap_m1.media_sessions(id),
 state text NOT NULL CHECK(state IN ('DELIVERED_SYNTHETIC','OS_REJECTED','PERMISSION_REQUIRED','FAILED')),
 evidence_source text NOT NULL CHECK(evidence_source='LOCAL_SYNTHETIC'),
 evidence_sha256 bytea NOT NULL CHECK(octet_length(evidence_sha256)=32),
 duration_or_count integer NOT NULL CHECK(duration_or_count>=0),
 event_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ap_m1.child_media_quota_pools (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 entitlement_id uuid REFERENCES ap_m1.child_paid_entitlements(id),
 trial_id uuid REFERENCES ap_m1.trial_redemptions(id),
 starts_at timestamptz NOT NULL,
 expires_at timestamptz NOT NULL CHECK(expires_at>starts_at),
 audio_used integer NOT NULL DEFAULT 0 CHECK(audio_used>=0),
 video_used integer NOT NULL DEFAULT 0 CHECK(video_used>=0),
 photos_used integer NOT NULL DEFAULT 0 CHECK(photos_used>=0),
 screen_used integer NOT NULL DEFAULT 0 CHECK(screen_used>=0),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK((entitlement_id IS NOT NULL)::integer+(trial_id IS NOT NULL)::integer=1),
 UNIQUE NULLS NOT DISTINCT(child_id,entitlement_id,trial_id,starts_at)
);
-- Entitlement IDs are stable across forward-only billing compaction. Move any
-- pre-materialized calendar windows in place, never recreate/reset counters or
-- ledger references. Started entitlements are never rebased by billing.
CREATE FUNCTION ap_m1.rebase_unstarted_media_pools() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public SET timezone='UTC' AS $$
 DECLARE pool record; month_index integer;
 BEGIN
 IF (NEW.valid_from,NEW.valid_until) IS NOT DISTINCT FROM (OLD.valid_from,OLD.valid_until)
 THEN RETURN NEW; END IF;
 FOR pool IN SELECT q.id,q.starts_at FROM ap_m1.child_media_quota_pools q
  WHERE q.entitlement_id=NEW.id ORDER BY q.starts_at FOR UPDATE LOOP
  -- Find the original anniversary ordinal explicitly (age() rounds Jan31/Feb28
  -- differently). At most 12 windows for the supported annual/monthly SKUs.
  SELECT n INTO month_index FROM generate_series(0,11) n
   WHERE OLD.valid_from+make_interval(months=>n)=pool.starts_at;
  IF month_index IS NULL THEN RAISE EXCEPTION 'quota window not on entitlement anniversary'; END IF;
  UPDATE ap_m1.child_media_quota_pools SET
   starts_at=NEW.valid_from+make_interval(months=>month_index),
   expires_at=least(NEW.valid_until,NEW.valid_from+make_interval(months=>month_index+1)),
   revision=revision+1,updated_at=clock_timestamp() WHERE id=pool.id;
 END LOOP;
 RETURN NEW;
 END;
$$;
CREATE TRIGGER entitlement_media_window_rebase AFTER UPDATE OF valid_from,valid_until
 ON ap_m1.child_paid_entitlements FOR EACH ROW EXECUTE FUNCTION ap_m1.rebase_unstarted_media_pools();

CREATE TABLE ap_m1.media_quota_ledger (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 pool_id uuid NOT NULL REFERENCES ap_m1.child_media_quota_pools(id),
 media_session_id uuid NOT NULL REFERENCES ap_m1.media_sessions(id),
 addon_id uuid REFERENCES ap_m1.extra_viewer_purchases(id),
 media_kind text NOT NULL REFERENCES ap_m1.media_capability_gates(feature),
 delivered_amount integer NOT NULL CHECK(delivered_amount>0),
 committed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ap_m1.capture_artifact_refs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 media_session_id uuid NOT NULL REFERENCES ap_m1.media_sessions(id),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 storage_location text NOT NULL CHECK(storage_location='PARENT_LOCAL_ACK_ONLY'),
 file_size_bytes bigint CHECK(file_size_bytes>=0),
 -- An opaque local acknowledgement ID, never a URL/path or downloadable server media.
 acknowledgement_id uuid NOT NULL UNIQUE,
 erasure_state text NOT NULL DEFAULT 'NOT_SERVER_STORED' CHECK(erasure_state='NOT_SERVER_STORED'),
 expires_at timestamptz
);
CREATE TABLE ap_m1.media_access_audit (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 action text NOT NULL CHECK(action IN ('REQUEST_REFUSED','READ_ACTIVITY','EXPORT_REQUEST','LEASE_ACQUIRE','LEASE_RELEASE','TAKEOVER_REQUEST','TAKEOVER_APPROVED','TAKEOVER_REFUSED')),
 accessed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ap_m1.media_export_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 adult_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 state text NOT NULL DEFAULT 'REQUESTED_METADATA_ONLY' CHECK(state='REQUESTED_METADATA_ONLY')
);

CREATE FUNCTION ap_m1._media_actor_live(child uuid, adult uuid, wanted text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 SELECT adult IS NOT NULL AND NOT ap_m1.child_deleted(child) AND ap_m1.has_consent(child,'CORE')
 AND EXISTS(SELECT 1 FROM ap_m1.trusted_principal_verifications v WHERE v.principal_id=adult
 AND v.revoked_at IS NULL AND v.expires_at>statement_timestamp() AND v.state='LOCAL_TEST_APPROVED')
 AND EXISTS(SELECT 1 FROM ap_m1.child_access_grants_v2 g JOIN ap_m1.consent_records c ON c.id=g.consent_record_id AND c.child_id=g.child_id
 WHERE g.child_id=child AND g.adult_id=adult AND g.scope=wanted AND g.revoked_at IS NULL
 AND (g.expires_at IS NULL OR g.expires_at>statement_timestamp()) AND ap_m1._review_live(g.authority_review_id)
 AND c.purpose='CORE' AND c.status='GRANTED' AND c.revoked_at IS NULL AND c.withdrawn_at IS NULL
 AND (c.expires_at IS NULL OR c.expires_at>statement_timestamp()) AND ap_m1._review_live(c.authority_review_id)
 AND (c.legal_state='APPROVED' OR c.legal_state='LOCAL_TEST_APPROVED' AND EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled))
 AND (g.origin_invite_id IS NULL AND g.issued_by=g.adult_id AND g.legacy_grant_id IS NULL
 OR EXISTS(SELECT 1 FROM ap_m1.child_access_invites i WHERE i.id=g.origin_invite_id AND i.child_id=g.child_id
 AND i.intended_adult_id=g.adult_id AND i.accepted_by_adult_id=g.adult_id AND i.accepted_at IS NOT NULL
 AND i.state='ACCEPTED' AND i.revoked_at IS NULL AND g.scope=ANY(i.requested_scopes))));
$$;
CREATE FUNCTION ap_m1.viewer_capacity(target_child uuid) RETURNS integer
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 SELECT CASE WHEN ap_m1.has_paid_access(target_child) THEN 1+(SELECT count(*)::integer FROM ap_m1.extra_viewer_purchases a
 JOIN ap_m1.play_purchase_records p ON p.id=a.purchase_id WHERE a.child_id=target_child AND a.revoked_at IS NULL
 AND p.state='PURCHASED' AND a.activated_at<=now() AND a.expires_at>now())
 WHEN ap_m1.has_trial_access(target_child) THEN 1 ELSE 0 END;
$$;
CREATE FUNCTION ap_m1.acquire_viewer_lease(target_child uuid, session_id uuid, kind text) RETURNS uuid
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
 (NOT ap_m1._media_actor_live(l.child_id,l.adult_id,CASE WHEN l.screen_kind='PREMIUM_MAP' THEN 'VIEW_HISTORY' ELSE 'REQUEST_MEDIA' END)
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
CREATE FUNCTION ap_m1.heartbeat_viewer_lease(lease uuid, session_id uuid) RETURNS timestamptz
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE l ap_m1.premium_viewer_leases%ROWTYPE; result timestamptz; position integer;
 BEGIN
 SELECT * INTO l FROM ap_m1.premium_viewer_leases WHERE id=lease;
 IF NOT FOUND OR l.adult_id IS DISTINCT FROM ap_m1.ctx_principal() OR l.device_session_id IS DISTINCT FROM session_id
 OR l.trusted_session_id IS DISTINCT FROM ap_m1._trusted_viewer_session()
 THEN RAISE EXCEPTION 'lease denied' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.children WHERE id=l.child_id FOR UPDATE;
 SELECT * INTO l FROM ap_m1.premium_viewer_leases WHERE id=lease FOR UPDATE;
 IF l.revoked_at IS NOT NULL OR l.expires_at<=clock_timestamp()
 OR NOT ap_m1.has_child_scope_v2(l.child_id,CASE WHEN l.screen_kind='PREMIUM_MAP' THEN 'VIEW_HISTORY' ELSE 'REQUEST_MEDIA' END)
 OR (l.screen_kind='AUTHORIZED_MEDIA' AND NOT ap_m1.has_consent(l.child_id,'MEDIA'))
 THEN RAISE EXCEPTION 'lease expired or revoked' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO position FROM ap_m1.premium_viewer_leases x WHERE x.child_id=l.child_id
 AND x.revoked_at IS NULL AND x.expires_at>clock_timestamp() AND (x.created_at,x.id)<=(l.created_at,l.id);
 IF position>ap_m1.viewer_capacity(l.child_id) THEN RAISE EXCEPTION 'capacity expired' USING ERRCODE='42501'; END IF;
 result:=clock_timestamp()+interval '90 seconds';
 UPDATE ap_m1.premium_viewer_leases SET heartbeat_at=clock_timestamp(),expires_at=result,revision=revision+1,updated_at=clock_timestamp() WHERE id=lease;
 RETURN result;
 END;
$$;
CREATE FUNCTION ap_m1.release_viewer_lease(lease uuid, session_id uuid) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE child uuid;
 BEGIN
 SELECT child_id INTO child FROM ap_m1.premium_viewer_leases WHERE id=lease AND adult_id=ap_m1.ctx_principal()
 AND device_session_id=session_id AND trusted_session_id=ap_m1._trusted_viewer_session();
 IF NOT FOUND THEN RAISE EXCEPTION 'lease denied' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.children WHERE id=child FOR UPDATE;
 UPDATE ap_m1.premium_viewer_leases SET revoked_at=coalesce(revoked_at,clock_timestamp()),revision=revision+1,updated_at=clock_timestamp() WHERE id=lease;
 INSERT INTO ap_m1.media_access_audit(child_id,adult_id,action) VALUES(child,ap_m1.ctx_principal(),'LEASE_RELEASE');
 END;
$$;
CREATE FUNCTION ap_m1.request_viewer_takeover(lease uuid) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE l ap_m1.premium_viewer_leases%ROWTYPE; result uuid;
 BEGIN
 SELECT * INTO l FROM ap_m1.premium_viewer_leases WHERE id=lease;
 IF NOT FOUND OR l.revoked_at IS NOT NULL OR l.expires_at<=clock_timestamp()
 OR NOT ap_m1.has_child_scope_v2(l.child_id,CASE WHEN l.screen_kind='PREMIUM_MAP' THEN 'VIEW_HISTORY' ELSE 'REQUEST_MEDIA' END)
 THEN RAISE EXCEPTION 'takeover denied' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.viewer_takeover_requests(child_id,active_lease,requester_adult_id)
 VALUES(l.child_id,lease,ap_m1.ctx_principal()) RETURNING id INTO result;
 INSERT INTO ap_m1.media_access_audit(child_id,adult_id,action) VALUES(l.child_id,ap_m1.ctx_principal(),'TAKEOVER_REQUEST');
 RETURN result;
 END;
$$;
CREATE FUNCTION ap_m1.decide_viewer_takeover(request uuid, approve boolean) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE r ap_m1.viewer_takeover_requests%ROWTYPE; l ap_m1.premium_viewer_leases%ROWTYPE;
 BEGIN
 SELECT * INTO r FROM ap_m1.viewer_takeover_requests WHERE id=request;
 IF NOT FOUND THEN RAISE EXCEPTION 'takeover absent'; END IF;
 PERFORM 1 FROM ap_m1.children WHERE id=r.child_id FOR UPDATE;
 SELECT * INTO r FROM ap_m1.viewer_takeover_requests WHERE id=request FOR UPDATE;
 SELECT * INTO l FROM ap_m1.premium_viewer_leases WHERE id=r.active_lease FOR UPDATE;
 IF l.adult_id IS DISTINCT FROM ap_m1.ctx_principal() OR r.state<>'REQUESTED'
 OR l.trusted_session_id IS DISTINCT FROM ap_m1._trusted_viewer_session()
 OR r.expires_at<=clock_timestamp() OR approve IS NULL THEN RAISE EXCEPTION 'takeover denied' USING ERRCODE='42501'; END IF;
 UPDATE ap_m1.viewer_takeover_requests SET state=CASE WHEN approve THEN 'APPROVED' ELSE 'REFUSED' END,revision=revision+1,updated_at=clock_timestamp() WHERE id=request;
 IF approve THEN UPDATE ap_m1.premium_viewer_leases SET revoked_at=clock_timestamp(),revision=revision+1,updated_at=clock_timestamp() WHERE id=l.id; END IF;
 INSERT INTO ap_m1.media_access_audit(child_id,adult_id,action) VALUES(r.child_id,ap_m1.ctx_principal(),CASE WHEN approve THEN 'TAKEOVER_APPROVED' ELSE 'TAKEOVER_REFUSED' END);
 -- Approval releases the old slot; requester must acquire afresh with current grants.
 END;
$$;
CREATE FUNCTION ap_m1.request_media(target_child uuid, target_device uuid, media_kind text) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE result uuid;
 BEGIN
 IF NOT ap_m1.has_child_scope_v2(target_child,'REQUEST_MEDIA') OR NOT ap_m1.has_consent(target_child,'MEDIA')
 THEN RAISE EXCEPTION 'media scope denied' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM ap_m1.devices WHERE id=target_device AND child_id=target_child AND enrollment_state='ACTIVE' AND revoked_at IS NULL)
 THEN RAISE EXCEPTION 'device unavailable' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.media_command_requests(child_id,device_id,adult_id,kind)
 VALUES(target_child,target_device,ap_m1.ctx_principal(),media_kind) RETURNING id INTO result;
 INSERT INTO ap_m1.media_access_audit(child_id,adult_id,action) VALUES(target_child,ap_m1.ctx_principal(),'REQUEST_REFUSED');
 RETURN result;
 END;
$$;

-- Internal pool operation. Caller must hold the child row lock. No runtime execute.
CREATE FUNCTION ap_m1.ensure_media_pool(target_child uuid) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public SET timezone='UTC' AS $$
 DECLARE e ap_m1.child_paid_entitlements%ROWTYPE; t ap_m1.trial_redemptions%ROWTYPE;
 starts timestamptz; ends timestamptz; result uuid; month_index integer;
 BEGIN
 IF ap_m1.has_paid_access(target_child) THEN
  SELECT * INTO e FROM ap_m1.child_paid_entitlements WHERE child_id=target_child AND revoked_at IS NULL
  AND valid_from<=now() AND valid_until>now() ORDER BY valid_from,id LIMIT 1;
  -- Calendar anniversaries anchored to original start (avoids Jan31 -> Feb28 -> Mar28 drift).
  month_index:=(extract(year FROM age(now(),e.valid_from))*12+extract(month FROM age(now(),e.valid_from)))::integer;
  starts:=e.valid_from+make_interval(months=>month_index);
  WHILE starts>now() LOOP month_index:=month_index-1; starts:=e.valid_from+make_interval(months=>month_index); END LOOP;
  ends:=least(e.valid_until,e.valid_from+make_interval(months=>month_index+1));
  INSERT INTO ap_m1.child_media_quota_pools(child_id,entitlement_id,starts_at,expires_at)
  VALUES(target_child,e.id,starts,ends) ON CONFLICT DO NOTHING;
  SELECT id INTO result FROM ap_m1.child_media_quota_pools WHERE child_id=target_child AND entitlement_id=e.id AND starts_at=starts;
 ELSIF ap_m1.has_trial_access(target_child) THEN
  SELECT r.* INTO t FROM ap_m1.trial_redemptions r JOIN ap_m1.trial_child_entitlements c ON c.trial_id=r.id
  WHERE c.child_id=target_child AND r.started_at<=now() AND r.expires_at>now();
  INSERT INTO ap_m1.child_media_quota_pools(child_id,trial_id,starts_at,expires_at)
  VALUES(target_child,t.id,t.started_at,t.expires_at) ON CONFLICT DO NOTHING;
  SELECT id INTO result FROM ap_m1.child_media_quota_pools WHERE child_id=target_child AND trial_id=t.id;
 ELSE RAISE EXCEPTION 'no media entitlement' USING ERRCODE='42501'; END IF;
 RETURN result;
 END;
$$;
CREATE FUNCTION ap_m1.record_local_media_delivery(request uuid, event uuid, outcome text, delivered integer,
 evidence bytea, source text) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE r ap_m1.media_command_requests%ROWTYPE; pool ap_m1.child_media_quota_pools%ROWTYPE;
 old ap_m1.media_lifecycle_events%ROWTYPE; result uuid; poolid uuid; ceiling integer; used integer;
 base_amount integer; remaining integer; amount integer; addon record; session_limit integer;
 BEGIN
 IF NOT EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled)
 OR source IS DISTINCT FROM 'LOCAL_SYNTHETIC' OR octet_length(evidence) IS DISTINCT FROM 32
 OR delivered IS NULL OR delivered<0 OR outcome IS NULL OR outcome NOT IN ('DELIVERED_SYNTHETIC','OS_REJECTED','PERMISSION_REQUIRED','FAILED')
 OR (outcome<>'DELIVERED_SYNTHETIC' AND delivered<>0) OR (outcome='DELIVERED_SYNTHETIC' AND delivered=0)
 THEN RAISE EXCEPTION 'invalid synthetic delivery'; END IF;
 SELECT * INTO r FROM ap_m1.media_command_requests WHERE id=request;
 IF NOT FOUND THEN RAISE EXCEPTION 'request absent'; END IF;
 PERFORM 1 FROM ap_m1.children WHERE id=r.child_id FOR UPDATE;
 SELECT * INTO old FROM ap_m1.media_lifecycle_events WHERE event_id=event;
 IF FOUND THEN
  IF old.state<>outcome OR old.duration_or_count<>delivered OR old.evidence_sha256<>evidence
  OR NOT EXISTS(SELECT 1 FROM ap_m1.media_sessions WHERE id=old.media_session_id AND request_id=request)
  THEN RAISE EXCEPTION 'receipt replay conflict'; END IF;
  RETURN old.media_session_id;
 END IF;
 -- Receipts are explicitly synthetic; authority is rechecked for the original adult,
 -- without binding the verifier connection to an actor or trusting actor GUCs.
 IF NOT ap_m1._media_actor_live(r.child_id,r.adult_id,'REQUEST_MEDIA')
 OR ap_m1.child_deleted(r.child_id) OR NOT ap_m1.has_consent(r.child_id,'MEDIA')
 OR NOT EXISTS(SELECT 1 FROM ap_m1.devices WHERE id=r.device_id AND enrollment_state='ACTIVE' AND revoked_at IS NULL)
 THEN RAISE EXCEPTION 'media authority revoked' USING ERRCODE='42501'; END IF;
 IF EXISTS(SELECT 1 FROM ap_m1.media_sessions WHERE request_id=request) THEN RAISE EXCEPTION 'request already finalized'; END IF;
 INSERT INTO ap_m1.media_sessions(request_id,child_id,authorized_adult_id,exit_reason)
 VALUES(request,r.child_id,r.adult_id,outcome) RETURNING id INTO result;
 IF delivered>0 THEN
  poolid:=ap_m1.ensure_media_pool(r.child_id);
  SELECT * INTO pool FROM ap_m1.child_media_quota_pools WHERE id=poolid FOR UPDATE;
  session_limit:=CASE r.kind WHEN 'AUDIO' THEN CASE WHEN pool.trial_id IS NOT NULL THEN 180 ELSE 300 END
  WHEN 'VIDEO_AV' THEN CASE WHEN pool.trial_id IS NOT NULL THEN 60 ELSE 120 END
  WHEN 'SCREEN_SHARE' THEN CASE WHEN pool.trial_id IS NOT NULL THEN 60 ELSE 120 END ELSE 1 END;
  IF delivered>session_limit THEN RAISE EXCEPTION 'session limit exceeded'; END IF;
  ceiling:=CASE r.kind WHEN 'AUDIO' THEN CASE WHEN pool.trial_id IS NOT NULL THEN 300 ELSE 3600 END
  WHEN 'VIDEO_AV' THEN CASE WHEN pool.trial_id IS NOT NULL THEN 120 ELSE 1200 END
  WHEN 'SCREEN_SHARE' THEN CASE WHEN pool.trial_id IS NOT NULL THEN 120 ELSE 600 END
  ELSE CASE WHEN pool.trial_id IS NOT NULL THEN 3 ELSE 30 END END;
  used:=CASE r.kind WHEN 'AUDIO' THEN pool.audio_used WHEN 'VIDEO_AV' THEN pool.video_used WHEN 'SCREEN_SHARE' THEN pool.screen_used ELSE pool.photos_used END;
  base_amount:=least(delivered,greatest(0,ceiling-used)); remaining:=delivered-base_amount;
  IF remaining>0 AND (r.kind NOT IN ('AUDIO','VIDEO_AV') OR pool.trial_id IS NOT NULL) THEN RAISE EXCEPTION 'quota exceeded'; END IF;
  IF remaining>0 THEN
   FOR addon IN SELECT a.* FROM ap_m1.extra_viewer_purchases a JOIN ap_m1.play_purchase_records p ON p.id=a.purchase_id
   WHERE a.child_id=r.child_id AND a.revoked_at IS NULL AND p.state='PURCHASED' AND a.activated_at<=now()
   AND a.expires_at>now() AND a.used_av_seconds<1800 ORDER BY a.expires_at,a.id FOR UPDATE OF a LOOP
    amount:=least(remaining,1800-addon.used_av_seconds);
    UPDATE ap_m1.extra_viewer_purchases SET used_av_seconds=used_av_seconds+amount,revision=revision+1,updated_at=clock_timestamp() WHERE id=addon.id;
    INSERT INTO ap_m1.media_quota_ledger(child_id,pool_id,media_session_id,addon_id,media_kind,delivered_amount)
    VALUES(r.child_id,poolid,result,addon.id,r.kind,amount);
    remaining:=remaining-amount; EXIT WHEN remaining=0;
   END LOOP;
   IF remaining>0 THEN RAISE EXCEPTION 'quota exceeded'; END IF;
  END IF;
  IF base_amount>0 THEN
   UPDATE ap_m1.child_media_quota_pools SET
   audio_used=audio_used+CASE WHEN r.kind='AUDIO' THEN base_amount ELSE 0 END,
   video_used=video_used+CASE WHEN r.kind='VIDEO_AV' THEN base_amount ELSE 0 END,
   photos_used=photos_used+CASE WHEN r.kind='IMAGE' THEN base_amount ELSE 0 END,
   screen_used=screen_used+CASE WHEN r.kind='SCREEN_SHARE' THEN base_amount ELSE 0 END,
   revision=revision+1,updated_at=clock_timestamp() WHERE id=poolid;
   INSERT INTO ap_m1.media_quota_ledger(child_id,pool_id,media_session_id,media_kind,delivered_amount)
   VALUES(r.child_id,poolid,result,r.kind,base_amount);
  END IF;
 END IF;
 INSERT INTO ap_m1.media_lifecycle_events(event_id,media_session_id,state,evidence_source,evidence_sha256,duration_or_count)
 VALUES(event,result,outcome,source,evidence,delivered);
 RETURN result;
 END;
$$;
CREATE FUNCTION ap_m1.read_media_activity(target_child uuid, before_time timestamptz DEFAULT 'infinity', page_size integer DEFAULT 50)
 RETURNS TABLE(session_id uuid,kind text,outcome text,observed_at timestamptz)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 BEGIN
 IF NOT ap_m1.has_child_scope_v2(target_child,'VIEW_MEDIA') THEN RAISE EXCEPTION 'media read denied' USING ERRCODE='42501'; END IF;
 IF page_size IS NULL OR page_size NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid page size'; END IF;
 INSERT INTO ap_m1.media_access_audit(child_id,adult_id,action) VALUES(target_child,ap_m1.ctx_principal(),'READ_ACTIVITY');
 RETURN QUERY SELECT s.id,r.kind,s.exit_reason,s.started_at FROM ap_m1.media_sessions s
 JOIN ap_m1.media_command_requests r ON r.id=s.request_id
 WHERE s.child_id=target_child AND s.started_at<before_time ORDER BY s.started_at DESC,s.id LIMIT page_size;
 END;
$$;
CREATE FUNCTION ap_m1.request_media_export(target_child uuid) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE result uuid;
 BEGIN
 IF NOT ap_m1.has_child_scope_v2(target_child,'VIEW_MEDIA') THEN RAISE EXCEPTION 'media export denied' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.media_export_requests(child_id,adult_id) VALUES(target_child,ap_m1.ctx_principal()) RETURNING id INTO result;
 INSERT INTO ap_m1.media_access_audit(child_id,adult_id,action) VALUES(target_child,ap_m1.ctx_principal(),'EXPORT_REQUEST');
 RETURN result;
 END;
$$;
CREATE FUNCTION ap_m1.get_media_quota(target_child uuid)
 RETURNS TABLE(remaining_audio_seconds integer,remaining_video_seconds integer,remaining_photos integer,remaining_screen_seconds integer,extra_pooled_av_seconds integer)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE pool ap_m1.child_media_quota_pools%ROWTYPE; poolid uuid;
 BEGIN
 IF NOT ap_m1.has_child_scope_v2(target_child,'VIEW_MEDIA') THEN RAISE EXCEPTION 'quota denied' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.children WHERE id=target_child FOR UPDATE;
 IF NOT ap_m1.has_paid_access(target_child) AND NOT ap_m1.has_trial_access(target_child) THEN
  RETURN QUERY SELECT 0,0,0,0,0; RETURN;
 END IF;
 poolid:=ap_m1.ensure_media_pool(target_child);
 SELECT * INTO pool FROM ap_m1.child_media_quota_pools WHERE id=poolid;
 RETURN QUERY SELECT greatest(0,CASE WHEN pool.trial_id IS NULL THEN 3600 ELSE 300 END-pool.audio_used),
 greatest(0,CASE WHEN pool.trial_id IS NULL THEN 1200 ELSE 120 END-pool.video_used),
 greatest(0,CASE WHEN pool.trial_id IS NULL THEN 30 ELSE 3 END-pool.photos_used),
 greatest(0,CASE WHEN pool.trial_id IS NULL THEN 600 ELSE 120 END-pool.screen_used),
 CASE WHEN pool.trial_id IS NOT NULL THEN 0 ELSE (SELECT coalesce(sum(1800-a.used_av_seconds),0)::integer
 FROM ap_m1.extra_viewer_purchases a JOIN ap_m1.play_purchase_records p ON p.id=a.purchase_id
 WHERE a.child_id=target_child AND a.revoked_at IS NULL AND p.state='PURCHASED'
 AND a.activated_at<=now() AND a.expires_at>now()) END;
 END;
$$;
CREATE FUNCTION ap_m1.get_child_addons(target_child uuid)
 RETURNS TABLE(addon_id uuid,state text,activated_at timestamptz,expires_at timestamptz,extra_av_remaining_seconds integer)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 BEGIN
 IF NOT ap_m1.has_child_scope_v2(target_child,'VIEW_CHILD_PROFILE') THEN RAISE EXCEPTION 'addon read denied' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT a.id,CASE WHEN a.revoked_at IS NOT NULL OR p.state<>'PURCHASED' THEN 'REFUNDED'
 WHEN a.expires_at<=now() THEN 'EXPIRED' WHEN NOT ap_m1.has_paid_access(target_child) THEN 'DORMANT_BASE_EXPIRED' ELSE 'ACTIVE' END,
 a.activated_at,a.expires_at,1800-a.used_av_seconds
 FROM ap_m1.extra_viewer_purchases a JOIN ap_m1.play_purchase_records p ON p.id=a.purchase_id
 WHERE a.child_id=target_child ORDER BY a.activated_at,a.id;
 END;
$$;
DO $$ DECLARE t text; f record; BEGIN
 FOREACH t IN ARRAY ARRAY['premium_viewer_leases','viewer_takeover_requests','media_capability_gates','media_command_requests',
 'media_sessions','media_lifecycle_events','child_media_quota_pools','media_quota_ledger','capture_artifact_refs','media_access_audit','media_export_requests'] LOOP
  EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON ap_m1.%I FROM PUBLIC,ap_m1_api,ap_billing_verifier',t);
  EXECUTE format('GRANT SELECT,INSERT,UPDATE ON ap_m1.%I TO ap_db_executor',t);
 END LOOP;
 FOR f IN SELECT p.oid::regprocedure sig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='ap_m1' AND p.proname IN ('rebase_unstarted_media_pools','_media_actor_live','viewer_capacity','acquire_viewer_lease','heartbeat_viewer_lease','release_viewer_lease',
 'request_viewer_takeover','decide_viewer_takeover','request_media','ensure_media_pool','record_local_media_delivery','read_media_activity','request_media_export','get_media_quota','get_child_addons') LOOP
  EXECUTE format('ALTER FUNCTION %s OWNER TO ap_db_executor',f.sig);
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,ap_m1_api,ap_billing_verifier',f.sig);
 END LOOP;
END $$;
GRANT EXECUTE ON FUNCTION ap_m1.acquire_viewer_lease(uuid,uuid,text),ap_m1.heartbeat_viewer_lease(uuid,uuid),
 ap_m1.release_viewer_lease(uuid,uuid),ap_m1.request_viewer_takeover(uuid),ap_m1.decide_viewer_takeover(uuid,boolean),
 ap_m1.request_media(uuid,uuid,text),ap_m1.read_media_activity(uuid,timestamptz,integer),ap_m1.request_media_export(uuid),
 ap_m1.get_media_quota(uuid),ap_m1.get_child_addons(uuid) TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.record_local_media_delivery(uuid,uuid,text,integer,bytea,text) TO ap_billing_verifier;
GRANT SELECT ON ap_m1.devices TO ap_db_executor;
GRANT SELECT ON ap_m1.premium_viewer_leases,ap_m1.viewer_takeover_requests,ap_m1.media_command_requests,
 ap_m1.media_capability_gates,ap_m1.media_export_requests TO ap_m1_api;
CREATE POLICY own_viewer_read ON ap_m1.premium_viewer_leases FOR SELECT TO ap_m1_api
 USING(ap_m1.has_child_scope_v2(child_id,'VIEW_HISTORY') OR ap_m1.has_child_scope_v2(child_id,'VIEW_MEDIA'));
CREATE POLICY takeover_read ON ap_m1.viewer_takeover_requests FOR SELECT TO ap_m1_api
 USING(requester_adult_id=ap_m1.ctx_principal() AND ap_m1.has_child_scope_v2(child_id,'VIEW_CHILD_PROFILE'));
CREATE POLICY media_request_read ON ap_m1.media_command_requests FOR SELECT TO ap_m1_api
 USING(adult_id=ap_m1.ctx_principal() AND ap_m1.has_child_scope_v2(child_id,'VIEW_MEDIA'));
CREATE POLICY capability_gate_read ON ap_m1.media_capability_gates FOR SELECT TO ap_m1_api USING(true);
CREATE POLICY media_export_read ON ap_m1.media_export_requests FOR SELECT TO ap_m1_api
 USING(adult_id=ap_m1.ctx_principal() AND ap_m1.has_child_scope_v2(child_id,'VIEW_MEDIA'));
