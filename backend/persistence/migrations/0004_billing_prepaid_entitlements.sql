-- Local synthetic prepaid ledger. NOT Google Play verification or an approved catalog.
-- Runner owns transaction. Monthly/yearly terms use UTC calendar arithmetic.
DO $$ BEGIN
 IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='ap_billing_verifier') THEN
  CREATE ROLE ap_billing_verifier NOLOGIN NOSUPERUSER NOBYPASSRLS;
 END IF;
END $$;
GRANT USAGE ON SCHEMA ap_m1 TO ap_billing_verifier, ap_db_executor;

CREATE TABLE ap_m1.billing_product_catalog (
 sku_id text PRIMARY KEY,
 kind text NOT NULL CHECK(kind IN ('MONTH','YEAR','ADDON')),
 currency text NOT NULL DEFAULT 'INR' CHECK(currency='INR'),
 public_price_paise integer NOT NULL CHECK(public_price_paise>0),
 founding_price_paise integer NOT NULL CHECK(founding_price_paise>0),
 auto_renew boolean NOT NULL DEFAULT false CHECK(NOT auto_renew),
 play_configuration_state text NOT NULL DEFAULT 'UNVERIFIED' CHECK(play_configuration_state='UNVERIFIED')
);
INSERT INTO ap_m1.billing_product_catalog(sku_id,kind,public_price_paise,founding_price_paise) VALUES
 ('local_prepaid_month','MONTH',9900,5000),('local_prepaid_year','YEAR',99900,50000),
 ('local_extra_viewer_100d','ADDON',10000,10000);
CREATE TABLE ap_m1.price_offers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 sku_id text NOT NULL REFERENCES ap_m1.billing_product_catalog(sku_id),
 eligibility_rule text NOT NULL CHECK(eligibility_rule IN ('PUBLIC','FOUNDING_FIRST_1008')),
 target_price_paise integer NOT NULL CHECK(target_price_paise>0),
 catalog_verified boolean NOT NULL DEFAULT false CHECK(NOT catalog_verified),
 UNIQUE(sku_id,eligibility_rule)
);
INSERT INTO ap_m1.price_offers(sku_id,eligibility_rule,target_price_paise)
 SELECT sku_id,'PUBLIC',public_price_paise FROM ap_m1.billing_product_catalog
 UNION ALL SELECT sku_id,'FOUNDING_FIRST_1008',founding_price_paise FROM ap_m1.billing_product_catalog;
CREATE TABLE ap_m1.founding_families (
 family_id uuid PRIMARY KEY REFERENCES ap_m1.families(id),
 qualifying_rank integer NOT NULL UNIQUE CHECK(qualifying_rank BETWEEN 1 AND 1008),
 first_paid_at timestamptz NOT NULL,
 eligibility_active boolean NOT NULL DEFAULT true
);
CREATE TABLE ap_m1.family_checkout_intents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL REFERENCES ap_m1.families(id),
 payer_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 sku_id text NOT NULL REFERENCES ap_m1.billing_product_catalog(sku_id),
 selected_child_ids uuid[] NOT NULL CHECK(cardinality(selected_child_ids)>=1),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL DEFAULT clock_timestamp()+interval '15 minutes',
 consumed_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ap_m1.play_purchase_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 checkout_intent_id uuid NOT NULL UNIQUE REFERENCES ap_m1.family_checkout_intents(id),
 family_id uuid NOT NULL REFERENCES ap_m1.families(id),
 payer_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 sku_id text NOT NULL REFERENCES ap_m1.billing_product_catalog(sku_id),
 token_sha256 bytea NOT NULL UNIQUE CHECK(octet_length(token_sha256)=32),
 evidence_sha256 bytea NOT NULL CHECK(octet_length(evidence_sha256)=32),
 evidence_source text NOT NULL CHECK(evidence_source='LOCAL_SYNTHETIC'),
 purchased_at timestamptz NOT NULL,
 verified_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 state text NOT NULL DEFAULT 'PURCHASED' CHECK(state IN ('PURCHASED','REFUNDED','REVOKED')),
 amount_paise integer NOT NULL CHECK(amount_paise>0),
 auto_renew boolean NOT NULL DEFAULT false CHECK(NOT auto_renew),
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ap_m1.prepaid_family_batches (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 purchase_id uuid NOT NULL UNIQUE REFERENCES ap_m1.play_purchase_records(id),
 family_id uuid NOT NULL REFERENCES ap_m1.families(id),
 capacity integer NOT NULL CHECK(capacity>=1),
 starts_at timestamptz NOT NULL,
 expires_at timestamptz NOT NULL CHECK(expires_at>starts_at)
);
CREATE TABLE ap_m1.child_seat_assignments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 batch_id uuid NOT NULL REFERENCES ap_m1.prepaid_family_batches(id),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 assigned_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 removed_at timestamptz,
 UNIQUE(batch_id,child_id)
);
CREATE TABLE ap_m1.child_paid_entitlements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 assignment_id uuid NOT NULL UNIQUE REFERENCES ap_m1.child_seat_assignments(id),
 valid_from timestamptz NOT NULL,
 valid_until timestamptz NOT NULL CHECK(valid_until>valid_from),
 revoked_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX paid_child_time_idx ON ap_m1.child_paid_entitlements(child_id,valid_until);
CREATE TABLE ap_m1.extra_viewer_purchases (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 purchase_id uuid NOT NULL UNIQUE REFERENCES ap_m1.play_purchase_records(id),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id),
 activated_at timestamptz NOT NULL,
 expires_at timestamptz NOT NULL CHECK(expires_at>activated_at),
 extra_slots integer NOT NULL DEFAULT 1 CHECK(extra_slots=1),
 total_av_seconds integer NOT NULL DEFAULT 1800 CHECK(total_av_seconds=1800),
 used_av_seconds integer NOT NULL DEFAULT 0 CHECK(used_av_seconds BETWEEN 0 AND 1800),
 revoked_at timestamptz,
 revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX addon_child_expiry_idx ON ap_m1.extra_viewer_purchases(child_id,expires_at);
CREATE TABLE ap_m1.trial_redemptions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL UNIQUE REFERENCES ap_m1.families(id),
 payer_id uuid NOT NULL UNIQUE REFERENCES ap_m1.parent_principals(id),
 started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 expires_at timestamptz NOT NULL,
 CHECK(expires_at=started_at+interval '48 hours')
);
CREATE TABLE ap_m1.trial_child_entitlements (
 trial_id uuid NOT NULL REFERENCES ap_m1.trial_redemptions(id),
 child_id uuid NOT NULL UNIQUE REFERENCES ap_m1.children(id),
 PRIMARY KEY(trial_id,child_id)
);
CREATE TABLE ap_m1.trial_eligibility_checks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL REFERENCES ap_m1.families(id),
 payer_id uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 trial_redemption_id uuid REFERENCES ap_m1.trial_redemptions(id),
 risk_result text NOT NULL CHECK(risk_result IN ('ELIGIBLE','ALREADY_PAID','ALREADY_REDEEMED')),
 checked_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ap_m1.entitlement_audit (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL REFERENCES ap_m1.families(id),
 purchase_id uuid REFERENCES ap_m1.play_purchase_records(id),
 action text NOT NULL CHECK(action IN ('PURCHASE','TRIAL','REFUNDED','REVOKED','RECONCILED','TERM_REBASED')),
 -- Before/after windows and triggering event; never purchase tokens or child media.
 details jsonb NOT NULL DEFAULT '{}'::jsonb,
 observed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ap_m1.payment_reconciliation_inbox (
 event_id uuid PRIMARY KEY,
 purchase_id uuid NOT NULL REFERENCES ap_m1.play_purchase_records(id),
 event_type text NOT NULL CHECK(event_type IN ('CONFIRMED','REFUNDED','REVOKED')),
 evidence_sha256 bytea NOT NULL CHECK(octet_length(evidence_sha256)=32),
 evidence_source text NOT NULL CHECK(evidence_source='LOCAL_SYNTHETIC'),
 received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 verified_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ap_m1.purchase_adjustments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 purchase_id uuid NOT NULL REFERENCES ap_m1.play_purchase_records(id),
 event_id uuid NOT NULL UNIQUE REFERENCES ap_m1.payment_reconciliation_inbox(event_id),
 reason text NOT NULL CHECK(reason IN ('REFUNDED','REVOKED')),
 effective_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE FUNCTION ap_m1.has_paid_access(target_child uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 SELECT NOT ap_m1.child_deleted(target_child) AND EXISTS (
 SELECT 1 FROM ap_m1.child_paid_entitlements e
 JOIN ap_m1.child_seat_assignments s ON s.id=e.assignment_id
 JOIN ap_m1.prepaid_family_batches b ON b.id=s.batch_id
 JOIN ap_m1.play_purchase_records p ON p.id=b.purchase_id
 WHERE e.child_id=target_child AND e.revoked_at IS NULL AND s.removed_at IS NULL
 AND p.state='PURCHASED' AND e.valid_from<=now() AND e.valid_until>now());
$$;
CREATE FUNCTION ap_m1.has_trial_access(target_child uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 SELECT NOT ap_m1.child_deleted(target_child) AND EXISTS (
 SELECT 1 FROM ap_m1.trial_child_entitlements c JOIN ap_m1.trial_redemptions t ON t.id=c.trial_id
 WHERE c.child_id=target_child AND t.started_at<=now() AND t.expires_at>now());
$$;
CREATE FUNCTION ap_m1.create_checkout(target_family uuid, sku text, selected uuid[]) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE result uuid; n integer; kind text;
 BEGIN
 IF NOT ap_m1.family_owner(target_family) THEN RAISE EXCEPTION 'billing owner required' USING ERRCODE='42501'; END IF;
 SELECT c.kind INTO kind FROM ap_m1.billing_product_catalog c WHERE c.sku_id=sku;
 n:=cardinality(selected);
 IF kind IS NULL OR n IS NULL OR n<1 OR array_position(selected,NULL) IS NOT NULL
 OR (SELECT count(DISTINCT v) FROM unnest(selected) v)<>n OR (kind='ADDON' AND n<>1)
 THEN RAISE EXCEPTION 'invalid selection'; END IF;
 IF (SELECT count(*) FROM ap_m1.children c WHERE c.id=ANY(selected) AND c.family_id=target_family
 AND c.state='ACTIVE' AND c.deleted_at IS NULL AND c.deletion_requested_at IS NULL)<>n
 THEN RAISE EXCEPTION 'invalid child selection' USING ERRCODE='42501'; END IF;
 INSERT INTO ap_m1.family_checkout_intents(family_id,payer_id,sku_id,selected_child_ids)
 VALUES(target_family,ap_m1.ctx_principal(),sku,selected) RETURNING id INTO result;
 RETURN result;
 END;
$$;

CREATE FUNCTION ap_m1.check_trial_eligibility(target_family uuid) RETURNS boolean
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE result text; redeemed uuid;
 BEGIN
 IF NOT coalesce(ap_m1.family_owner(target_family),false) THEN RAISE EXCEPTION 'billing owner required' USING ERRCODE='42501'; END IF;
 SELECT id INTO redeemed FROM ap_m1.trial_redemptions WHERE family_id=target_family OR payer_id=ap_m1.ctx_principal() LIMIT 1;
 result:=CASE WHEN EXISTS(SELECT 1 FROM ap_m1.play_purchase_records WHERE family_id=target_family OR payer_id=ap_m1.ctx_principal())
 THEN 'ALREADY_PAID' WHEN redeemed IS NOT NULL THEN 'ALREADY_REDEEMED' ELSE 'ELIGIBLE' END;
 INSERT INTO ap_m1.trial_eligibility_checks(family_id,payer_id,trial_redemption_id,risk_result)
 VALUES(target_family,ap_m1.ctx_principal(),redeemed,result);
 RETURN result='ELIGIBLE';
 END;
$$;
CREATE FUNCTION ap_m1.start_family_trial(target_family uuid, acknowledged boolean) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public AS $$
 DECLARE result uuid; started timestamptz:=clock_timestamp();
 BEGIN
 IF acknowledged IS DISTINCT FROM true OR NOT ap_m1.family_owner(target_family)
 THEN RAISE EXCEPTION 'owner acknowledgement required' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.families WHERE id=target_family FOR UPDATE;
 IF NOT ap_m1.check_trial_eligibility(target_family)
 THEN RAISE EXCEPTION 'trial already used or previously paid'; END IF;
 INSERT INTO ap_m1.trial_redemptions(family_id,payer_id,started_at,expires_at)
 VALUES(target_family,ap_m1.ctx_principal(),started,started+interval '48 hours') RETURNING id INTO result;
 INSERT INTO ap_m1.trial_child_entitlements SELECT result,id FROM ap_m1.children
 WHERE family_id=target_family AND state='ACTIVE' AND deleted_at IS NULL AND deletion_requested_at IS NULL;
 INSERT INTO ap_m1.entitlement_audit(family_id,action) VALUES(target_family,'TRIAL');
 RETURN result;
 END;
$$;

-- Verifier-only. A hash and LOCAL_SYNTHETIC evidence are not proof of a Play purchase.
-- A production verifier must be separately approved and implemented; this grants none.
CREATE FUNCTION ap_m1.record_local_verified_purchase(intent uuid, token_digest bytea,
 evidence_digest bytea, evidence_source text, successful_at timestamptz) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public SET timezone='UTC' AS $$
 DECLARE i ap_m1.family_checkout_intents%ROWTYPE; p ap_m1.play_purchase_records%ROWTYPE;
 c ap_m1.billing_product_catalog%ROWTYPE; result uuid; batch uuid; assignment uuid;
 child uuid; starts timestamptz; ends timestamptz; rank integer; founding boolean; at_time timestamptz:=clock_timestamp();
 BEGIN
 IF NOT EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled)
 OR evidence_source IS DISTINCT FROM 'LOCAL_SYNTHETIC' OR octet_length(token_digest) IS DISTINCT FROM 32
 OR octet_length(evidence_digest) IS DISTINCT FROM 32 OR successful_at IS NULL
 OR successful_at>at_time OR successful_at<at_time-interval '1 day' THEN RAISE EXCEPTION 'invalid local evidence'; END IF;
 -- One global serialization point avoids rank gaps and distinct-family boundary races.
 PERFORM pg_advisory_xact_lock(4004,1008);
 SELECT * INTO i FROM ap_m1.family_checkout_intents WHERE id=intent FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'intent absent'; END IF;
 SELECT * INTO p FROM ap_m1.play_purchase_records WHERE token_sha256=token_digest;
 IF FOUND THEN
  IF p.checkout_intent_id<>intent OR p.evidence_sha256<>evidence_digest THEN RAISE EXCEPTION 'purchase replay conflict'; END IF;
  RETURN p.id;
 END IF;
 IF i.consumed_at IS NOT NULL OR i.expires_at<=at_time THEN RAISE EXCEPTION 'intent expired or consumed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM ap_m1.guardian_memberships m WHERE m.family_id=i.family_id
 AND m.principal_id=i.payer_id AND m.membership_role='OWNER' AND m.revoked_at IS NULL)
 THEN RAISE EXCEPTION 'payer revoked' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM ap_m1.families WHERE id=i.family_id AND state='ACTIVE' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'family inactive'; END IF;
 -- Lock children in stable order shared with lease/quota functions.
 PERFORM 1 FROM ap_m1.children WHERE id=ANY(i.selected_child_ids) ORDER BY id FOR UPDATE;
 IF (SELECT count(*) FROM ap_m1.children WHERE id=ANY(i.selected_child_ids)
 AND family_id=i.family_id AND state='ACTIVE' AND deleted_at IS NULL AND deletion_requested_at IS NULL)
 <>cardinality(i.selected_child_ids) THEN RAISE EXCEPTION 'child unavailable'; END IF;
 SELECT * INTO c FROM ap_m1.billing_product_catalog WHERE sku_id=i.sku_id;
 IF c.kind<>'ADDON' AND NOT EXISTS(SELECT 1 FROM ap_m1.founding_families WHERE family_id=i.family_id) THEN
  SELECT coalesce(max(qualifying_rank),0)+1 INTO rank FROM ap_m1.founding_families;
  IF rank<=1008 THEN INSERT INTO ap_m1.founding_families VALUES(i.family_id,rank,successful_at,true); END IF;
 END IF;
 founding:=EXISTS(SELECT 1 FROM ap_m1.founding_families WHERE family_id=i.family_id AND eligibility_active);
 INSERT INTO ap_m1.play_purchase_records(checkout_intent_id,family_id,payer_id,sku_id,token_sha256,
 evidence_sha256,evidence_source,purchased_at,amount_paise)
 VALUES(intent,i.family_id,i.payer_id,i.sku_id,token_digest,evidence_digest,evidence_source,successful_at,
 cardinality(i.selected_child_ids)*CASE WHEN founding THEN c.founding_price_paise ELSE c.public_price_paise END)
 RETURNING id INTO result;
 IF c.kind='ADDON' THEN
  INSERT INTO ap_m1.extra_viewer_purchases(purchase_id,child_id,activated_at,expires_at)
  VALUES(result,i.selected_child_ids[1],successful_at,successful_at+interval '100 days');
 ELSE
  INSERT INTO ap_m1.prepaid_family_batches(purchase_id,family_id,capacity,starts_at,expires_at)
  VALUES(result,i.family_id,cardinality(i.selected_child_ids),at_time,at_time+interval '1 month') RETURNING id INTO batch;
  FOREACH child IN ARRAY i.selected_child_ids LOOP
   SELECT greatest(at_time,coalesce(max(valid_until),at_time)) INTO starts
   FROM ap_m1.child_paid_entitlements WHERE child_id=child AND revoked_at IS NULL;
   ends:=starts+CASE WHEN c.kind='MONTH' THEN interval '1 month' ELSE interval '1 year' END;
   INSERT INTO ap_m1.child_seat_assignments(batch_id,child_id) VALUES(batch,child) RETURNING id INTO assignment;
   INSERT INTO ap_m1.child_paid_entitlements(child_id,assignment_id,valid_from,valid_until) VALUES(child,assignment,starts,ends);
  END LOOP;
  UPDATE ap_m1.prepaid_family_batches SET (starts_at,expires_at)=(SELECT min(e.valid_from),max(e.valid_until)
  FROM ap_m1.child_paid_entitlements e JOIN ap_m1.child_seat_assignments s ON s.id=e.assignment_id WHERE s.batch_id=batch) WHERE id=batch;
 END IF;
 UPDATE ap_m1.family_checkout_intents SET consumed_at=at_time,updated_at=at_time,revision=revision+1 WHERE id=intent;
 INSERT INTO ap_m1.entitlement_audit(family_id,purchase_id,action) VALUES(i.family_id,result,'PURCHASE');
 RETURN result;
 END;
$$;
CREATE FUNCTION ap_m1.reconcile_local_purchase(event uuid, purchase uuid, outcome text, evidence bytea, source text) RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ap_m1,public SET timezone='UTC' AS $$
 DECLARE p ap_m1.play_purchase_records%ROWTYPE; old ap_m1.payment_reconciliation_inbox%ROWTYPE;
 child uuid; term record; cursor_at timestamptz; starts timestamptz; ends timestamptz; at_time timestamptz;
 BEGIN
 IF NOT EXISTS(SELECT 1 FROM ap_m1.local_test_settings WHERE singleton AND enabled)
 OR source IS DISTINCT FROM 'LOCAL_SYNTHETIC' OR octet_length(evidence) IS DISTINCT FROM 32
 OR outcome NOT IN ('CONFIRMED','REFUNDED','REVOKED') OR outcome IS NULL THEN RAISE EXCEPTION 'invalid local reconciliation'; END IF;
 PERFORM pg_advisory_xact_lock(4004,1008);
 SELECT * INTO p FROM ap_m1.play_purchase_records WHERE id=purchase;
 IF NOT FOUND THEN RAISE EXCEPTION 'purchase absent'; END IF;
 -- Same child lock as leases and quota debit: revocation and delivery serialize.
 PERFORM 1 FROM ap_m1.children c WHERE c.id IN (
 SELECT s.child_id FROM ap_m1.child_seat_assignments s JOIN ap_m1.prepaid_family_batches b ON b.id=s.batch_id WHERE b.purchase_id=purchase
 UNION SELECT a.child_id FROM ap_m1.extra_viewer_purchases a WHERE a.purchase_id=purchase
 ) ORDER BY c.id FOR UPDATE;
 SELECT * INTO p FROM ap_m1.play_purchase_records WHERE id=purchase FOR UPDATE;
 SELECT * INTO old FROM ap_m1.payment_reconciliation_inbox WHERE event_id=event;
 IF FOUND THEN
  IF old.purchase_id<>purchase OR old.event_type<>outcome OR old.evidence_sha256<>evidence THEN RAISE EXCEPTION 'reconciliation replay conflict'; END IF;
  RETURN;
 END IF;
 INSERT INTO ap_m1.payment_reconciliation_inbox(event_id,purchase_id,event_type,evidence_sha256,evidence_source)
 VALUES(event,purchase,outcome,evidence,source);
 -- A terminal purchase is never resurrected or adjusted twice, including distinct
 -- notification IDs. The inbox still persists each notification for replay checks.
 IF p.state<>'PURCHASED' THEN RETURN; END IF;
 IF outcome<>'CONFIRMED' THEN
  at_time:=clock_timestamp(); -- sampled after all child locks, not before a lock wait
  INSERT INTO ap_m1.purchase_adjustments(purchase_id,event_id,reason,effective_at) VALUES(purchase,event,outcome,at_time);
  UPDATE ap_m1.play_purchase_records SET state=outcome,revision=revision+1,updated_at=at_time WHERE id=purchase;
  UPDATE ap_m1.child_paid_entitlements SET revoked_at=at_time,revision=revision+1,updated_at=at_time
  WHERE assignment_id IN (SELECT s.id FROM ap_m1.child_seat_assignments s JOIN ap_m1.prepaid_family_batches b ON b.id=s.batch_id WHERE b.purchase_id=purchase);
  UPDATE ap_m1.extra_viewer_purchases SET revoked_at=at_time,revision=revision+1,updated_at=at_time WHERE purchase_id=purchase;
  -- Conservative forward-only compaction: started/expired service is immutable.
  -- Only unstarted surviving terms move, no earlier than this adjustment and their
  -- purchased/verified timestamps. Reapply the SKU's full UTC calendar duration,
  -- not a seconds difference (month ends/leap years). IDs and seat links survive.
  FOR child IN SELECT s.child_id FROM ap_m1.child_seat_assignments s
   JOIN ap_m1.prepaid_family_batches b ON b.id=s.batch_id WHERE b.purchase_id=purchase ORDER BY s.child_id LOOP
   SELECT greatest(at_time,coalesce(max(e.valid_until),at_time)) INTO cursor_at
   FROM ap_m1.child_paid_entitlements e
   JOIN ap_m1.child_seat_assignments s ON s.id=e.assignment_id
   JOIN ap_m1.prepaid_family_batches b ON b.id=s.batch_id
   JOIN ap_m1.play_purchase_records q ON q.id=b.purchase_id
   WHERE e.child_id=child AND e.revoked_at IS NULL AND s.removed_at IS NULL
    AND q.state='PURCHASED' AND e.valid_from<=at_time;
   FOR term IN SELECT e.*,b.purchase_id,b.family_id,b.id AS batch_id,c.kind,q.purchased_at,q.verified_at
    FROM ap_m1.child_paid_entitlements e
    JOIN ap_m1.child_seat_assignments s ON s.id=e.assignment_id
    JOIN ap_m1.prepaid_family_batches b ON b.id=s.batch_id
    JOIN ap_m1.play_purchase_records q ON q.id=b.purchase_id
    JOIN ap_m1.billing_product_catalog c ON c.sku_id=q.sku_id
    WHERE e.child_id=child AND e.revoked_at IS NULL AND s.removed_at IS NULL
     AND q.state='PURCHASED' AND e.valid_from>at_time
    ORDER BY e.valid_from,q.verified_at,q.id,e.id LOOP
    starts:=greatest(cursor_at,term.purchased_at,term.verified_at);
    ends:=starts+CASE WHEN term.kind='MONTH' THEN interval '1 month' ELSE interval '1 year' END;
    IF starts<term.valid_from THEN
     UPDATE ap_m1.child_paid_entitlements SET valid_from=starts,valid_until=ends,
      revision=revision+1,updated_at=at_time WHERE id=term.id;
     UPDATE ap_m1.prepaid_family_batches SET (starts_at,expires_at)=(
      SELECT min(e.valid_from),max(e.valid_until) FROM ap_m1.child_paid_entitlements e
      JOIN ap_m1.child_seat_assignments s ON s.id=e.assignment_id WHERE s.batch_id=term.batch_id)
      WHERE id=term.batch_id;
     INSERT INTO ap_m1.entitlement_audit(family_id,purchase_id,action,details,observed_at)
      VALUES(term.family_id,term.purchase_id,'TERM_REBASED',jsonb_build_object(
       'event_id',event,'trigger_purchase_id',purchase,'entitlement_id',term.id,
       'child_id',child,'old_from',term.valid_from,'old_until',term.valid_until,
       'new_from',starts,'new_until',ends,'policy','FORWARD_ONLY_UNSTARTED_V1'),at_time);
     cursor_at:=ends;
    ELSE cursor_at:=term.valid_until;
    END IF;
   END LOOP;
  END LOOP;
 END IF;
 INSERT INTO ap_m1.entitlement_audit(family_id,purchase_id,action) VALUES(p.family_id,purchase,CASE WHEN outcome='CONFIRMED' THEN 'RECONCILED' ELSE outcome END);
 END;
$$;

DO $$ DECLARE t text; f record; BEGIN
 FOREACH t IN ARRAY ARRAY['billing_product_catalog','price_offers','trial_eligibility_checks','founding_families','family_checkout_intents','play_purchase_records',
 'prepaid_family_batches','child_seat_assignments','child_paid_entitlements','extra_viewer_purchases',
 'trial_redemptions','trial_child_entitlements','entitlement_audit','payment_reconciliation_inbox','purchase_adjustments'] LOOP
  EXECUTE format('ALTER TABLE ap_m1.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE ap_m1.%I FORCE ROW LEVEL SECURITY',t);
  EXECUTE format('GRANT SELECT,INSERT,UPDATE ON ap_m1.%I TO ap_db_executor',t);
  EXECUTE format('REVOKE ALL ON ap_m1.%I FROM PUBLIC,ap_m1_api,ap_billing_verifier',t);
 END LOOP;
 FOR f IN SELECT p.oid::regprocedure sig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='ap_m1' AND p.proname IN ('has_paid_access','has_trial_access','create_checkout','start_family_trial','check_trial_eligibility',
 'record_local_verified_purchase','reconcile_local_purchase') LOOP
  EXECUTE format('ALTER FUNCTION %s OWNER TO ap_db_executor',f.sig);
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,ap_m1_api,ap_billing_verifier',f.sig);
 END LOOP;
END $$;
GRANT SELECT ON ap_m1.families,ap_m1.children,ap_m1.guardian_memberships TO ap_db_executor;
-- Row locks require UPDATE; executor is NOLOGIN, never inherited by runtime.
GRANT UPDATE ON ap_m1.families,ap_m1.children TO ap_db_executor;
GRANT EXECUTE ON FUNCTION ap_m1.has_paid_access(uuid),ap_m1.has_trial_access(uuid) TO ap_m1_api,ap_m1_auth;
GRANT EXECUTE ON FUNCTION ap_m1.create_checkout(uuid,text,uuid[]),ap_m1.start_family_trial(uuid,boolean),ap_m1.check_trial_eligibility(uuid) TO ap_m1_api;
GRANT EXECUTE ON FUNCTION ap_m1.record_local_verified_purchase(uuid,bytea,bytea,text,timestamptz),
 ap_m1.reconcile_local_purchase(uuid,uuid,text,bytea,text) TO ap_billing_verifier;
GRANT SELECT ON ap_m1.billing_product_catalog,ap_m1.price_offers TO ap_m1_api;
CREATE POLICY offers_read ON ap_m1.price_offers FOR SELECT TO ap_m1_api USING(true);
CREATE POLICY catalog_read ON ap_m1.billing_product_catalog FOR SELECT TO ap_m1_api USING(true);
GRANT SELECT ON ap_m1.family_checkout_intents,ap_m1.play_purchase_records,ap_m1.founding_families,
 ap_m1.prepaid_family_batches,ap_m1.trial_redemptions,ap_m1.trial_eligibility_checks,ap_m1.entitlement_audit TO ap_m1_api;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['family_checkout_intents','play_purchase_records','founding_families','prepaid_family_batches','trial_redemptions','trial_eligibility_checks','entitlement_audit'] LOOP
  EXECUTE format('CREATE POLICY billing_owner_read ON ap_m1.%I FOR SELECT TO ap_m1_api USING(ap_m1.family_owner(family_id))',t);
 END LOOP;
END $$;
GRANT SELECT ON ap_m1.child_paid_entitlements,ap_m1.extra_viewer_purchases TO ap_m1_api;
CREATE POLICY entitlement_child_read ON ap_m1.child_paid_entitlements FOR SELECT TO ap_m1_api
 USING(ap_m1.has_child_scope_v2(child_id,'VIEW_CHILD_PROFILE'));
CREATE POLICY addon_child_read ON ap_m1.extra_viewer_purchases FOR SELECT TO ap_m1_api
 USING(ap_m1.has_child_scope_v2(child_id,'VIEW_CHILD_PROFILE'));
