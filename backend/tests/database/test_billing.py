"""Focused disposable PostgreSQL tests. All payment evidence is LOCAL_SYNTHETIC.
No Play calls, raw purchase tokens, real child data, role-switch impersonation or sleeps.
Run: .local-db/venv/bin/python -m unittest discover -s backend/tests/database -p test_billing.py -v
"""
import concurrent.futures
import datetime
import hashlib
import json
import os
import pathlib
import threading
import unittest
from uuid import uuid4

import psycopg
from fixtures import admin_connection, runtime_connection, as_parent

ROOT = pathlib.Path(__file__).resolve().parents[3]
EVIDENCE = hashlib.sha256(b'LOCAL_SYNTHETIC_TEST_EVIDENCE_NOT_PLAY').digest()


def verifier_connection():
    """Actual restricted login supplied by parent bootstrap, never SET ROLE."""
    dsn = os.environ.get('MA_BILLING_DSN')
    if not dsn:
        path = ROOT / '.local-db/connection.json'
        if path.stat().st_mode & 0o077:
            raise RuntimeError('connection.json must be private')
        config = json.loads(path.read_text())
        config = config.get('test', config)
        dsn = config.get('billing') or config.get('billing_dsn')
    if not dsn:
        raise RuntimeError('parent must provision MA_BILLING_DSN / test.billing restricted login')
    from fixtures import validate_test_dsn
    return psycopg.connect(validate_test_dsn(dsn))


class World:
    """Unique committed test fixture, cleaned by exact UUIDs; safe across domains."""
    def __init__(self):
        self.actor, self.other, self.family, self.child, self.sibling, self.device = [uuid4() for _ in range(6)]
        self.review, self.other_review, self.consent = uuid4(), uuid4(), uuid4()
        self._sessions={}
        self._session_lock=threading.Lock()
        with admin_connection() as c:
            if c.execute("SELECT to_regprocedure('ap_m1.record_local_verified_purchase(uuid,bytea,bytea,text,timestamptz)'),to_regclass('ap_m1.media_sessions')").fetchone().count(None):
                raise RuntimeError('Apply identity, billing and media migrations before focused tests; no fixtures were written')
            c.execute("INSERT INTO ap_m1.local_test_settings VALUES(true,true) ON CONFLICT(singleton) DO UPDATE SET enabled=true")
            for adult in (self.actor, self.other):
                c.execute('INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES(%s,%s,%s)', (adult,'https://synthetic.example.invalid',str(adult)))
                c.execute("INSERT INTO ap_m1.trusted_principal_verifications(principal_id,state) VALUES(%s,'LOCAL_TEST_APPROVED')", (adult,))
            c.execute("INSERT INTO ap_m1.families(id,label) VALUES(%s,'synthetic billing test')", (self.family,))
            c.execute("INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES(%s,%s,'OWNER')", (self.family,self.actor))
            for child in (self.child,self.sibling):
                c.execute("INSERT INTO ap_m1.children(id,family_id,alias) VALUES(%s,%s,'synthetic')", (child,self.family))
            for adult,review in ((self.actor,self.review),(self.other,self.other_review)):
                c.execute("INSERT INTO ap_m1.child_authority_reviews(id,child_id,adult_id,state,lawful_basis_version,method_code,reviewed_at,expires_at) VALUES(%s,%s,%s,'LOCAL_TEST_APPROVED','synthetic-v1','SYNTHETIC_FIXTURE',now(),now()+interval '1 day')", (review,self.child,adult))
            for purpose in ('CORE','MEDIA','LOCATION','USAGE'):
                cid = self.consent if purpose=='CORE' else uuid4()
                c.execute("INSERT INTO ap_m1.consent_records(id,child_id,adult_id,purpose,status,authority_review_id,notice_version,legal_state,expires_at) VALUES(%s,%s,%s,%s,'GRANTED',%s,'synthetic-v1','LOCAL_TEST_APPROVED',now()+interval '1 day')", (cid,self.child,self.actor,purpose,self.review))
            for adult,review in ((self.actor,self.review),(self.other,self.other_review)):
                for scope in ('VIEW_CHILD_PROFILE','VIEW_HISTORY','VIEW_MEDIA','REQUEST_MEDIA','VIEW_LOCATION'):
                    c.execute('INSERT INTO ap_m1.child_access_grants_v2(child_id,adult_id,scope,consent_record_id,authority_review_id,issued_by) VALUES(%s,%s,%s,%s,%s,%s)',(self.child,adult,scope,self.consent,review,adult))
            c.execute("INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state) VALUES(%s,%s,%s,%s,'ACTIVE')", (self.device,self.family,self.child,b'SYNTHETIC-KEY-'*8))

    def runtime(self, actor=None, family=True, reuse_session=False):
        """New bearer by default; persistent synthetic clients opt in per World."""
        c=runtime_connection()
        actor=actor or self.actor
        family_id=self.family if family else None
        try:
            if reuse_session:
                key=(actor,family_id)
                with self._session_lock:
                    token=self._sessions.get(key)
                    if token is None:
                        token=as_parent(c,actor,family_id)
                        self._sessions[key]=token
                    else:
                        c.execute("SELECT set_config('ap.session_token',%s,true)",(token,))
            else:
                as_parent(c,actor,family_id)
        except Exception:
            c.close()
            raise
        return c

    def checkout(self, sku='local_prepaid_month', selected=None):
        with self.runtime() as c:
            return c.execute('SELECT ap_m1.create_checkout(%s,%s,%s::uuid[])',(self.family,sku,selected or [self.child])).fetchone()[0]

    def purchase(self, intent=None, digest=None, sku='local_prepaid_month'):
        intent = intent or self.checkout(sku)
        digest = digest or hashlib.sha256(uuid4().bytes).digest()
        with verifier_connection() as c:
            result=c.execute('SELECT ap_m1.record_local_verified_purchase(%s,%s,%s,%s,clock_timestamp())', (intent,digest,EVIDENCE,'LOCAL_SYNTHETIC')).fetchone()[0]
        return result

    def reconcile(self, purchase, outcome='REFUNDED', event=None):
        event=event or uuid4()
        with verifier_connection() as c:
            c.execute('SELECT ap_m1.reconcile_local_purchase(%s,%s,%s,%s,%s)', (event,purchase,outcome,EVIDENCE,'LOCAL_SYNTHETIC'))
        return event

    def cleanup(self):
        with admin_connection() as c:
            # Each statement is scoped to this world's UUID, never TRUNCATE shared fixtures.
            for table in ('media_quota_ledger','capture_artifact_refs','media_lifecycle_events'):
                c.execute(f'DELETE FROM ap_m1.{table} WHERE media_session_id IN (SELECT id FROM ap_m1.media_sessions WHERE child_id=%s)',(self.child,))
            for table in ('media_sessions','child_media_quota_pools','media_command_requests','media_access_audit','media_export_requests','viewer_takeover_requests','premium_viewer_leases'):
                c.execute(f'DELETE FROM ap_m1.{table} WHERE child_id=%s',(self.child,))
            c.execute('DELETE FROM ap_m1.entitlement_audit WHERE family_id=%s',(self.family,))
            for table in ('child_paid_entitlements','child_seat_assignments','trial_child_entitlements'):
                c.execute(f'DELETE FROM ap_m1.{table} WHERE child_id IN (SELECT id FROM ap_m1.children WHERE family_id=%s)',(self.family,))
            c.execute('DELETE FROM ap_m1.extra_viewer_purchases WHERE child_id=%s',(self.child,))
            for table in ('prepaid_family_batches','trial_eligibility_checks','trial_redemptions','founding_families'):
                c.execute(f'DELETE FROM ap_m1.{table} WHERE family_id=%s',(self.family,))
            for table in ('purchase_adjustments','payment_reconciliation_inbox'):
                c.execute(f'DELETE FROM ap_m1.{table} WHERE purchase_id IN (SELECT id FROM ap_m1.play_purchase_records WHERE family_id=%s)',(self.family,))
            for table in ('play_purchase_records','family_checkout_intents'):
                c.execute(f'DELETE FROM ap_m1.{table} WHERE family_id=%s',(self.family,))
            c.execute('DELETE FROM ap_m1.trusted_sessions WHERE principal_id IN (%s,%s)',(self.actor,self.other))
            c.execute('DELETE FROM ap_m1.child_access_grants_v2 WHERE child_id=%s',(self.child,))
            c.execute('DELETE FROM ap_m1.consent_records WHERE child_id=%s',(self.child,))
            c.execute('DELETE FROM ap_m1.child_authority_reviews WHERE child_id=%s',(self.child,))
            c.execute('DELETE FROM ap_m1.devices WHERE id=%s',(self.device,))
            c.execute('DELETE FROM ap_m1.children WHERE family_id=%s',(self.family,))
            c.execute('DELETE FROM ap_m1.guardian_memberships WHERE family_id=%s',(self.family,))
            c.execute('DELETE FROM ap_m1.families WHERE id=%s',(self.family,))
            c.execute('DELETE FROM ap_m1.trusted_principal_verifications WHERE principal_id IN (%s,%s)',(self.actor,self.other))
            c.execute('DELETE FROM ap_m1.parent_principals WHERE id IN (%s,%s)',(self.actor,self.other))


class BillingTests(unittest.TestCase):
    def setUp(self):
        self.w=World()
        self.addCleanup(self.w.cleanup)

    def test_07_prepaid_selected_child_only_and_no_autorenew(self):
        self.w.purchase()
        with self.w.runtime() as c:
            self.assertEqual(c.execute('SELECT ap_m1.has_paid_access(%s),ap_m1.has_paid_access(%s)',(self.w.child,self.w.sibling)).fetchone(),(True,False))
            self.assertEqual(c.execute('SELECT amount_paise,auto_renew FROM ap_m1.play_purchase_records WHERE family_id=%s',(self.w.family,)).fetchone(),(5000,False))
        with self.w.runtime(self.w.other,family=False) as c:
            self.assertTrue(c.execute('SELECT ap_m1.has_paid_access(%s)',(self.w.child,)).fetchone()[0])
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.play_purchase_records WHERE family_id=%s',(self.w.family,)).fetchone()[0],0)
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute('SELECT ap_m1.create_checkout(%s,%s,%s::uuid[])',(self.w.family,'local_prepaid_month',[self.w.child]))

    def test_six_selected_children_checkout_and_verified_entitlements(self):
        selected=[self.w.child]+[uuid4() for _ in range(5)]
        with admin_connection() as c:
            for child in selected[1:]:
                c.execute("INSERT INTO ap_m1.children(id,family_id,alias) VALUES(%s,%s,'synthetic selected child')",(child,self.w.family))
        intent=self.w.checkout(selected=selected)
        purchase=self.w.purchase(intent)
        with self.w.runtime() as c:
            self.assertEqual(c.execute('SELECT selected_child_ids FROM ap_m1.family_checkout_intents WHERE id=%s',(intent,)).fetchone()[0],selected)
            # Purchasing seats does not confer authority over the other children.
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.child_paid_entitlements WHERE child_id=ANY(%s::uuid[]) AND ap_m1.has_paid_access(child_id)',(selected,)).fetchone()[0],1)
            self.assertFalse(c.execute('SELECT ap_m1.has_paid_access(%s)',(self.w.sibling,)).fetchone()[0])
            self.assertEqual(c.execute('SELECT capacity FROM ap_m1.prepaid_family_batches WHERE purchase_id=%s',(purchase,)).fetchone()[0],6)
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.child_paid_entitlements WHERE child_id=ANY(%s::uuid[]) AND revoked_at IS NULL AND valid_from<=now() AND valid_until>now()', (selected,)).fetchone()[0],6)

    def test_08_trial_48h_once_no_founding_count(self):
        with self.w.runtime() as c:
            trial=c.execute('SELECT ap_m1.start_family_trial(%s,true)',(self.w.family,)).fetchone()[0]
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT extract(epoch FROM expires_at-started_at)::integer FROM ap_m1.trial_redemptions WHERE id=%s',(trial,)).fetchone()[0],172800)
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.founding_families WHERE family_id=%s',(self.w.family,)).fetchone()[0],0)
        with self.w.runtime() as c:
            with self.assertRaisesRegex(psycopg.Error,'already used'):
                c.execute('SELECT ap_m1.start_family_trial(%s,true)',(self.w.family,))
        with self.w.runtime() as c:
            self.assertEqual(c.execute('SELECT ap_m1.has_trial_access(%s),ap_m1.has_paid_access(%s)',(self.w.child,self.w.child)).fetchone(),(True,False))

    def test_09_digest_replay_conflict_and_concurrent_same_purchase(self):
        intent=self.w.checkout(); digest=hashlib.sha256(uuid4().bytes).digest(); barrier=threading.Barrier(2)
        def buy():
            barrier.wait(timeout=10)
            return self.w.purchase(intent,digest)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(lambda _:buy(),range(2)))
        self.assertEqual(results[0],results[1])
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.play_purchase_records WHERE family_id=%s',(self.w.family,)).fetchone()[0],1)
        other_intent=self.w.checkout()
        with self.assertRaisesRegex(psycopg.Error,'replay conflict'):
            self.w.purchase(other_intent,digest)

    def test_10_first1008_distinct_family_boundary_concurrently(self):
        other=World(); self.addCleanup(other.cleanup)
        # Fill only vacant ranks with invented families, preserve existing allocation.
        filler=[]
        with admin_connection() as c:
            maximum=c.execute('SELECT coalesce(max(qualifying_rank),0) FROM ap_m1.founding_families').fetchone()[0]
            self.assertLessEqual(maximum,1007,'boundary test needs disposable test DB with an available slot')
            for rank in range(maximum+1,1008):
                fid=uuid4(); filler.append(fid)
                c.execute("INSERT INTO ap_m1.families(id,label) VALUES(%s,'synthetic boundary filler')",(fid,))
                c.execute('INSERT INTO ap_m1.founding_families(family_id,qualifying_rank,first_paid_at) VALUES(%s,%s,now())',(fid,rank))
        def clear_filler():
            with admin_connection() as c:
                c.execute('DELETE FROM ap_m1.founding_families WHERE family_id=ANY(%s::uuid[])',(filler,))
                c.execute('DELETE FROM ap_m1.families WHERE id=ANY(%s::uuid[])',(filler,))
        self.addCleanup(clear_filler)
        intents=[self.w.checkout(),other.checkout()]; barrier=threading.Barrier(2)
        def buy(pair):
            world,intent=pair; barrier.wait(timeout=10); return world.purchase(intent)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(buy,zip((self.w,other),intents)))
        with admin_connection() as c:
            rows=c.execute('SELECT qualifying_rank FROM ap_m1.founding_families WHERE family_id IN (%s,%s)',(self.w.family,other.family)).fetchall()
            self.assertEqual(rows,[(1008,)])
            self.assertEqual(sorted(r[0] for r in c.execute('SELECT amount_paise FROM ap_m1.play_purchase_records WHERE family_id IN (%s,%s)',(self.w.family,other.family))),[5000,9900])
        self.w.purchase(); other.purchase()
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.founding_families WHERE family_id IN (%s,%s)',(self.w.family,other.family)).fetchone()[0],1)

    def test_11_refund_reconciliation_replay_and_no_resurrection(self):
        purchase=self.w.purchase(); event=self.w.reconcile(purchase)
        self.w.reconcile(purchase,event=event)
        self.w.reconcile(purchase,'CONFIRMED')
        with self.w.runtime() as c:
            self.assertFalse(c.execute('SELECT ap_m1.has_paid_access(%s)',(self.w.child,)).fetchone()[0])
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.purchase_adjustments WHERE purchase_id=%s',(purchase,)).fetchone()[0],1)
            self.assertEqual(c.execute('SELECT state FROM ap_m1.play_purchase_records WHERE id=%s',(purchase,)).fetchone()[0],'REFUNDED')
        with self.assertRaisesRegex(psycopg.Error,'replay conflict'):
            self.w.reconcile(purchase,'REVOKED',event)

    def test_12_verifier_only_no_actor_spoof_or_direct_write(self):
        intent=self.w.checkout()
        with runtime_connection() as c:
            c.execute("SELECT set_config('ap.principal_id',%s,true),set_config('ap.family_id',%s,true)",(str(self.w.actor),str(self.w.family)))
            self.assertIsNone(c.execute('SELECT ap_m1.ctx_principal()').fetchone()[0])
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute('SELECT ap_m1.create_checkout(%s,%s,%s::uuid[])',(self.w.family,'local_prepaid_month',[self.w.child]))
        with self.w.runtime() as c:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute('SELECT ap_m1.record_local_verified_purchase(%s,%s,%s,%s,now())',(intent,EVIDENCE,EVIDENCE,'LOCAL_SYNTHETIC'))
        with self.w.runtime() as c:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute("UPDATE ap_m1.play_purchase_records SET state='PURCHASED'")
        with verifier_connection() as c:
            self.assertEqual(c.execute("SELECT rolsuper,rolbypassrls FROM pg_roles WHERE rolname=current_user").fetchone(),(False,False))
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute('INSERT INTO ap_m1.founding_families VALUES(%s,1,now(),true)',(self.w.family,))

    def test_13_addon_calendar_expiry_dormancy_resume_and_refund(self):
        base=self.w.purchase(); addon=self.w.purchase(sku='local_extra_viewer_100d')
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT expires_at=activated_at+interval \'100 days\',total_av_seconds FROM ap_m1.extra_viewer_purchases WHERE purchase_id=%s',(addon,)).fetchone(),(True,1800))
        self.w.reconcile(base)
        with self.w.runtime() as c:
            self.assertEqual(c.execute('SELECT state FROM ap_m1.get_child_addons(%s)',(self.w.child,)).fetchone()[0],'DORMANT_BASE_EXPIRED')
        self.w.purchase()
        with self.w.runtime() as c:
            self.assertEqual(c.execute('SELECT state FROM ap_m1.get_child_addons(%s)',(self.w.child,)).fetchone()[0],'ACTIVE')
        self.w.reconcile(addon)
        with self.w.runtime() as c:
            self.assertEqual(c.execute('SELECT state FROM ap_m1.get_child_addons(%s)',(self.w.child,)).fetchone()[0],'REFUNDED')

    def test_14_expired_intent_duplicates_and_yearly_calendar_term(self):
        with self.w.runtime() as c:
            with self.assertRaisesRegex(psycopg.Error,'invalid selection'):
                c.execute('SELECT ap_m1.create_checkout(%s,%s,%s::uuid[])',(self.w.family,'local_prepaid_month',[self.w.child,self.w.child]))
        intent=self.w.checkout()
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.family_checkout_intents SET expires_at=now()-interval '1 second' WHERE id=%s",(intent,))
        with self.assertRaisesRegex(psycopg.Error,'expired'):
            self.w.purchase(intent)
        purchase=self.w.purchase(sku='local_prepaid_year')
        with admin_connection() as c:
            self.assertTrue(c.execute("SELECT e.valid_until=e.valid_from+interval '1 year' FROM ap_m1.child_paid_entitlements e JOIN ap_m1.child_seat_assignments s ON s.id=e.assignment_id JOIN ap_m1.prepaid_family_batches b ON b.id=s.batch_id WHERE b.purchase_id=%s",(purchase,)).fetchone()[0])
        with self.w.runtime() as c:
            with self.assertRaisesRegex(psycopg.Error,'previously paid'):
                c.execute('SELECT ap_m1.start_family_trial(%s,true)',(self.w.family,))
    def test_23_trial_expiry_and_new_child_does_not_restart(self):
        with self.w.runtime() as c:
            trial=c.execute('SELECT ap_m1.start_family_trial(%s,true)',(self.w.family,)).fetchone()[0]
        late_child=uuid4()
        with admin_connection() as c:
            c.execute("INSERT INTO ap_m1.children(id,family_id,alias) VALUES(%s,%s,'synthetic late child')",(late_child,self.w.family))
        with self.w.runtime() as c:
            self.assertFalse(c.execute('SELECT ap_m1.has_trial_access(%s)',(late_child,)).fetchone()[0])
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.trial_redemptions SET started_at=now()-interval '49 hours',expires_at=now()-interval '1 hour' WHERE id=%s",(trial,))
        with self.w.runtime() as c:
            self.assertFalse(c.execute('SELECT ap_m1.has_trial_access(%s)',(self.w.child,)).fetchone()[0])
            with self.assertRaisesRegex(psycopg.Error,'already used'):
                c.execute('SELECT ap_m1.start_family_trial(%s,true)',(self.w.family,))

    def test_24_catalog_unverified_and_nonlocal_evidence_refused(self):
        with self.w.runtime() as c:
            rows=c.execute('SELECT kind,public_price_paise,founding_price_paise,auto_renew,play_configuration_state FROM ap_m1.billing_product_catalog ORDER BY kind').fetchall()
            self.assertEqual(rows,[('ADDON',10000,10000,False,'UNVERIFIED'),('MONTH',9900,5000,False,'UNVERIFIED'),('YEAR',99900,50000,False,'UNVERIFIED')])
        intent=self.w.checkout()
        with verifier_connection() as c:
            with self.assertRaisesRegex(psycopg.Error,'invalid local evidence'):
                c.execute('SELECT ap_m1.record_local_verified_purchase(%s,%s,%s,%s,now())',(intent,EVIDENCE,EVIDENCE,'GOOGLE_PLAY'))
        with admin_connection() as c:
            rows=c.execute("SELECT relname,relrowsecurity,relforcerowsecurity FROM pg_class WHERE relnamespace='ap_m1'::regnamespace AND relname IN ('play_purchase_records','child_paid_entitlements','extra_viewer_purchases','founding_families','media_sessions','premium_viewer_leases','media_quota_ledger')").fetchall()
            self.assertEqual(len(rows),7)
            self.assertTrue(all(row[1] and row[2] for row in rows))


if __name__=='__main__':
    unittest.main()
