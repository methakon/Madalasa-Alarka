"""Disposable synthetic media tests. No real capture, transport or media files.
Run: .local-db/venv/bin/python -m unittest discover -s backend/tests/database -p test_media.py -v
"""
import concurrent.futures
import threading
import unittest
from uuid import uuid4

import psycopg
from fixtures import admin_connection
from test_billing import World, EVIDENCE, verifier_connection


class MediaTests(unittest.TestCase):
    def setUp(self):
        self.w=World(); self.addCleanup(self.w.cleanup)
        self.w.purchase()

    def runtime(self,actor=None,family=None):
        actor=actor or self.w.actor
        if family is None:
            family=actor==self.w.actor
        return self.w.runtime(actor,family=family,reuse_session=True)

    def acquire(self,actor=None,session=None):
        session=session or uuid4()
        with self.runtime(actor) as c:
            lease=c.execute('SELECT ap_m1.acquire_viewer_lease(%s,%s,%s)',(self.w.child,session,'PREMIUM_MAP')).fetchone()[0]
        return lease,session

    def request(self,kind='AUDIO'):
        with self.runtime() as c:
            return c.execute('SELECT ap_m1.request_media(%s,%s,%s)',(self.w.child,self.w.device,kind)).fetchone()[0]

    def receipt(self,request,amount=1,outcome='DELIVERED_SYNTHETIC',event=None):
        with verifier_connection() as c:
            return c.execute('SELECT ap_m1.record_local_media_delivery(%s,%s,%s,%s,%s,%s)',
                             (request,event or uuid4(),outcome,amount,EVIDENCE,'LOCAL_SYNTHETIC')).fetchone()[0]

    def quota(self):
        with self.runtime() as c:
            return c.execute('SELECT * FROM ap_m1.get_media_quota(%s)',(self.w.child,)).fetchone()

    def test_15_viewer_capacity_race_and_release(self):
        barrier=threading.Barrier(2)
        def compete(actor):
            barrier.wait(timeout=10)
            try: return self.acquire(actor)
            except psycopg.errors.RaiseException as e:
                self.assertIn('capacity full',str(e)); return None
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as p:
            rows=list(p.map(compete,[self.w.actor,self.w.other]))
        self.assertEqual(sum(r is not None for r in rows),1)
        winner=next(i for i,r in enumerate(rows) if r)
        adult=[self.w.actor,self.w.other][winner]; lease,session=rows[winner]
        with self.runtime(adult,family=adult==self.w.actor) as c:
            c.execute('SELECT ap_m1.release_viewer_lease(%s,%s)',(lease,session))
        self.acquire([self.w.actor,self.w.other][1-winner])

    def test_16_heartbeat_revocation_and_takeover_requires_holder(self):
        lease,session=self.acquire()
        with self.runtime(self.w.other,family=False) as c:
            request=c.execute('SELECT ap_m1.request_viewer_takeover(%s)',(lease,)).fetchone()[0]
        with self.runtime(self.w.other,family=False) as c:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute('SELECT ap_m1.decide_viewer_takeover(%s,true)',(request,))
        with self.runtime() as c:
            c.execute('SELECT ap_m1.decide_viewer_takeover(%s,true)',(request,))
        with self.runtime() as c:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute('SELECT ap_m1.heartbeat_viewer_lease(%s,%s)',(lease,session))
        lease2,session2=self.acquire(self.w.other)
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_access_grants_v2 SET revoked_at=now() WHERE child_id=%s AND adult_id=%s AND scope='VIEW_HISTORY'",(self.w.child,self.w.other))
        with self.runtime(self.w.other,family=False) as c:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute('SELECT ap_m1.heartbeat_viewer_lease(%s,%s)',(lease2,session2))
        # Stale revoked guardian lease cannot pin the only slot until its TTL.
        self.acquire()

    def test_17_addon_capacity_expiry_and_base_lapse(self):
        self.w.purchase(sku='local_extra_viewer_100d')
        self.acquire(); second,session=self.acquire(self.w.other)
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.extra_viewer_purchases SET activated_at=now()-interval '101 days',expires_at=now()-interval '1 day' WHERE child_id=%s",(self.w.child,))
        with self.runtime(self.w.other,family=False) as c:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute('SELECT ap_m1.heartbeat_viewer_lease(%s,%s)',(second,session))
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_paid_entitlements SET valid_from=now()-interval '2 months',valid_until=now()-interval '1 month' WHERE child_id=%s",(self.w.child,))
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            self.acquire()
        self.assertEqual(self.quota(),(0,0,0,0,0))

    def test_18_capture_disabled_and_os_rejection_never_charged(self):
        self.assertEqual(self.quota(),(3600,1200,30,600,0))
        for kind in ('AUDIO','VIDEO_AV','IMAGE','SCREEN_SHARE'):
            request=self.request(kind)
            with self.runtime() as c:
                self.assertEqual(c.execute('SELECT state,reason_code FROM ap_m1.media_command_requests WHERE id=%s',(request,)).fetchone(),('UNSUPPORTED','FEATURE_NOT_RELEASED'))
            self.receipt(request,0,'OS_REJECTED')
        self.assertEqual(self.quota(),(3600,1200,30,600,0))
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.media_quota_ledger WHERE child_id=%s',(self.w.child,)).fetchone()[0],0)
            self.assertFalse(c.execute('SELECT bool_or(real_capture_enabled OR released) FROM ap_m1.media_capability_gates').fetchone()[0])

    def test_19_shared_pooled_addon_quota_replay_and_overspend(self):
        self.w.purchase(sku='local_extra_viewer_100d')
        self.quota()
        # Seed already-delivered base usage, then exercise real locked debit operation.
        with admin_connection() as c:
            c.execute('UPDATE ap_m1.child_media_quota_pools SET audio_used=3600,video_used=1200 WHERE child_id=%s',(self.w.child,))
        request=self.request(); event=uuid4()
        session=self.receipt(request,300,event=event)
        self.assertEqual(self.receipt(request,300,event=event),session)
        self.receipt(self.request('VIDEO_AV'),120)
        self.assertEqual(self.quota(),(0,0,30,600,1380))
        with self.assertRaisesRegex(psycopg.Error,'replay conflict'):
            self.receipt(request,299,event=event)
        with self.assertRaisesRegex(psycopg.Error,'invalid synthetic delivery'):
            self.receipt(self.request(),-1)
        with self.assertRaisesRegex(psycopg.Error,'session limit'):
            self.receipt(self.request(),301)
        with admin_connection() as c:
            c.execute('UPDATE ap_m1.extra_viewer_purchases SET used_av_seconds=1790 WHERE child_id=%s',(self.w.child,))
        with self.assertRaisesRegex(psycopg.Error,'quota exceeded'):
            self.receipt(self.request(),11)
        self.assertEqual(self.quota()[-1],10)
        self.receipt(self.request('VIDEO_AV'),10)
        self.assertEqual(self.quota()[-1],0)

    def test_20_quota_concurrency_no_double_spend(self):
        self.w.purchase(sku='local_extra_viewer_100d'); self.quota()
        with admin_connection() as c:
            c.execute('UPDATE ap_m1.child_media_quota_pools SET audio_used=3600,video_used=1200 WHERE child_id=%s',(self.w.child,))
            c.execute('UPDATE ap_m1.extra_viewer_purchases SET used_av_seconds=1790 WHERE child_id=%s',(self.w.child,))
        requests=[self.request(),self.request('VIDEO_AV')]; barrier=threading.Barrier(2)
        def spend(request):
            barrier.wait(timeout=10)
            try: self.receipt(request,10); return True
            except psycopg.errors.RaiseException as e:
                self.assertIn('quota exceeded',str(e)); return False
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as p:
            self.assertEqual(sorted(p.map(spend,requests)),[False,True])
        self.assertEqual(self.quota()[-1],0)

    def test_21_revoked_consent_adult_and_runtime_receipt_denied(self):
        request=self.request()
        with self.runtime() as c:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute('SELECT ap_m1.record_local_media_delivery(%s,%s,%s,%s,%s,%s)',(request,uuid4(),'DELIVERED_SYNTHETIC',1,EVIDENCE,'LOCAL_SYNTHETIC'))
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_access_grants_v2 SET revoked_at=now() WHERE child_id=%s AND adult_id=%s AND scope='REQUEST_MEDIA'",(self.w.child,self.w.actor))
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            self.receipt(request,1)
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.consent_records SET withdrawn_at=now(),status='WITHDRAWN' WHERE child_id=%s AND purpose='MEDIA'",(self.w.child,))
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            self.request()

    def test_22_metadata_read_audited_export_and_no_direct_bypass(self):
        self.receipt(self.request('IMAGE'))
        with self.runtime() as c:
            self.assertEqual(len(c.execute('SELECT * FROM ap_m1.read_media_activity(%s)',(self.w.child,)).fetchall()),1)
            c.execute('SELECT ap_m1.request_media_export(%s)',(self.w.child,))
        with admin_connection() as c:
            actions=[r[0] for r in c.execute('SELECT action FROM ap_m1.media_access_audit WHERE child_id=%s',(self.w.child,))]
            self.assertIn('READ_ACTIVITY',actions); self.assertIn('EXPORT_REQUEST',actions)
        for sql in ('SELECT * FROM ap_m1.media_sessions','SELECT * FROM ap_m1.media_quota_ledger',
                    'UPDATE ap_m1.media_capability_gates SET released=true',
                    'SELECT ap_m1.ensure_media_pool(%s)'):
            with self.runtime() as c:
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    c.execute(sql,(self.w.child,) if '%s' in sql else None)
    def test_25_trial_quota_is_once_for_whole_48h_not_daily(self):
        self.w=World(); self.addCleanup(self.w.cleanup)
        with self.runtime() as c:
            c.execute('SELECT ap_m1.start_family_trial(%s,true)',(self.w.family,))
        self.assertEqual(self.quota(),(300,120,3,120,0))
        self.receipt(self.request(),180)
        with self.assertRaisesRegex(psycopg.Error,'quota exceeded'):
            self.receipt(self.request(),121)
        self.receipt(self.request(),120)
        self.assertEqual(self.quota(),(0,120,3,120,0))
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.trial_redemptions SET started_at=now()-interval '49 hours',expires_at=now()-interval '1 hour' WHERE family_id=%s",(self.w.family,))
        self.assertEqual(self.quota(),(0,0,0,0,0))

    def test_26_annual_base_quota_has_separate_calendar_month_pool(self):
        with admin_connection() as c:
            entitlement,start=c.execute("UPDATE ap_m1.child_paid_entitlements SET valid_from=now()-interval '40 days',valid_until=now()+interval '325 days' WHERE child_id=%s RETURNING id,valid_from",(self.w.child,)).fetchone()
            c.execute("INSERT INTO ap_m1.child_media_quota_pools(child_id,entitlement_id,starts_at,expires_at,audio_used) VALUES(%s,%s,%s,%s+interval '1 month',3600)",(self.w.child,entitlement,start,start))
        self.assertEqual(self.quota(),(3600,1200,30,600,0))
        self.receipt(self.request(),300)
        self.assertEqual(self.quota(),(3300,1200,30,600,0))
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.child_media_quota_pools WHERE child_id=%s',(self.w.child,)).fetchone()[0],2)


if __name__=='__main__':
    unittest.main()
