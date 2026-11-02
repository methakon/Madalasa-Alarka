"""Synthetic-only history authorization; never installs migrations or resets DB.

Run: .local-db/venv/bin/python -m unittest discover -s backend/tests/database -p test_premium_history_leases.py -v
Client-instance UUIDs are NOT authentication. Reuse the minted bearer to model a
single authenticated session across connections; a new bearer is another session.
"""
from contextlib import contextmanager
import unittest
from uuid import uuid4

from fixtures import admin_connection, runtime_connection, mint_session
from test_billing import World


class PremiumHistoryLeaseTests(unittest.TestCase):
    def setUp(self):
        self.w = World()
        self.addCleanup(self.w.cleanup)
        self.addCleanup(self.clean_locations)
        self.w.purchase()
        self.token = mint_session(self.w.actor, self.w.family)
        self.other_token = mint_session(self.w.other)
        self.client = uuid4()
        with admin_connection() as c:
            for sequence, age in ((1, '7 hours'), (2, '1 hour')):
                event = uuid4()
                c.execute("INSERT INTO ap_m1.location_event_dedup(child_id,device_id,sequence,event_id,payload_digest) VALUES(%s,%s,%s,%s,decode(repeat('00',32),'hex'))", (self.w.child,self.w.device,sequence,event))
                c.execute("INSERT INTO ap_m1.location_observations(child_id,device_id,event_id,sequence,observed_at,latitude,longitude,position,accuracy_m,provider,quality) VALUES(%s,%s,%s,%s,now()-%s::interval,0,0,public.ST_SetSRID(public.ST_MakePoint(0,0),4326)::public.geography,1,'SYNTHETIC','QUALIFIED')", (self.w.child,self.w.device,event,sequence,age))

    def clean_locations(self):
        with admin_connection() as c:
            for table in ('location_observations', 'location_event_dedup'):
                c.execute('DELETE FROM ap_m1.' + table + ' WHERE child_id=%s', (self.w.child,))

    @contextmanager
    def session(self, token=None):
        with runtime_connection() as c:
            c.execute("SELECT set_config('ap.session_token',%s,true)", (token or self.token,))
            yield c

    def acquire(self, token=None, client=None):
        with self.session(token) as c:
            return c.execute("SELECT ap_m1.acquire_viewer_lease(%s,%s,'PREMIUM_MAP')", (self.w.child,client or self.client)).fetchone()[0]

    def assert_history(self, premium, token=None):
        with self.session(token) as c:
            expected = [(1,),(2,)] if premium else [(2,)]
            with self.subTest(path='direct_table_rls'):
                self.assertEqual(c.execute("SELECT sequence FROM ap_m1.location_observations WHERE child_id=%s ORDER BY sequence", (self.w.child,)).fetchall(), expected)
            with self.subTest(path='history_function'):
                self.assertEqual(c.execute("SELECT sequence FROM ap_m1.location_history(%s,statement_timestamp()-interval '8 hours',statement_timestamp(),500) ORDER BY sequence", (self.w.child,)).fetchall(), expected)
            with self.subTest(path='authorization_helper'):
                self.assertEqual(c.execute("SELECT ap_m1.can_read_location_history(%s,statement_timestamp()-interval '7 hours')", (self.w.child,)).fetchone()[0], premium)

    def test_paid_without_lease_only_gets_free_six_hours(self):
        self.assert_history(False)

    def test_holder_allowed_other_authorized_guardian_denied(self):
        self.acquire()
        self.assert_history(True)
        self.assert_history(False, self.other_token)

    def test_same_parent_different_trusted_session_cannot_reuse_lease(self):
        self.acquire()
        self.assert_history(True)
        self.assert_history(False, mint_session(self.w.actor, self.w.family))

    def test_expired_lease_keeps_free_history(self):
        lease = self.acquire()
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.premium_viewer_leases SET expires_at=now()-interval '1 second' WHERE id=%s", (lease,))
        self.assert_history(False)

    def test_revoked_lease_keeps_free_history(self):
        lease = self.acquire()
        with admin_connection() as c:
            c.execute('UPDATE ap_m1.premium_viewer_leases SET revoked_at=now() WHERE id=%s', (lease,))
        self.assert_history(False)

    def test_base_expiry_keeps_free_history(self):
        self.acquire()
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_paid_entitlements SET valid_from=now()-interval '2 months',valid_until=now()-interval '1 month' WHERE child_id=%s", (self.w.child,))
        self.assert_history(False)

    def test_revoked_scope_denies_even_free_history(self):
        self.acquire()
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_access_grants_v2 SET revoked_at=now() WHERE child_id=%s AND adult_id=%s AND scope='VIEW_HISTORY'", (self.w.child,self.w.actor))
        with self.session() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.location_observations WHERE child_id=%s', (self.w.child,)).fetchone()[0], 0)

    def assert_addon_loss(self, refund=False):
        purchase = self.w.purchase(sku='local_extra_viewer_100d')
        self.acquire()
        self.acquire(self.other_token)
        self.assert_history(True, self.other_token)
        if refund:
            self.w.reconcile(purchase)
        else:
            with admin_connection() as c:
                c.execute("UPDATE ap_m1.extra_viewer_purchases SET activated_at=now()-interval '101 days',expires_at=now()-interval '1 day' WHERE child_id=%s", (self.w.child,))
        self.assert_history(False, self.other_token)
        self.assert_history(True)

    def test_addon_expiry_removes_surplus_lease_immediately(self):
        self.assert_addon_loss()

    def test_addon_refund_removes_surplus_lease_immediately(self):
        self.assert_addon_loss(refund=True)

    def test_lease_is_exact_child_scoped_even_when_both_children_paid_authorized(self):
        # Give the same actor valid independent authority for another paid child.
        other = World()
        self.addCleanup(other.cleanup)
        other.purchase()
        with admin_connection() as c:
            review = uuid4()
            c.execute("INSERT INTO ap_m1.child_authority_reviews(id,child_id,adult_id,state,lawful_basis_version,method_code,reviewed_at,expires_at) VALUES(%s,%s,%s,'LOCAL_TEST_APPROVED','synthetic-v1','SYNTHETIC_FIXTURE',now(),now()+interval '1 day')", (review,other.child,self.w.actor))
            c.execute("INSERT INTO ap_m1.child_access_grants_v2(child_id,adult_id,scope,consent_record_id,authority_review_id,issued_by) VALUES(%s,%s,'VIEW_HISTORY',%s,%s,%s)", (other.child,self.w.actor,other.consent,review,self.w.actor))
        self.acquire()
        with self.session() as c:
            self.assertTrue(c.execute("SELECT ap_m1.has_child_scope_v2(%s,'VIEW_HISTORY') AND ap_m1.has_paid_access(%s)", (other.child,other.child)).fetchone()[0])
            self.assertFalse(c.execute("SELECT ap_m1.can_read_location_history(%s,statement_timestamp()-interval '7 hours')", (other.child,)).fetchone()[0])

    def test_media_screen_lease_does_not_authorize_map_history(self):
        with self.session() as c:
            c.execute("SELECT ap_m1.acquire_viewer_lease(%s,%s,'AUTHORIZED_MEDIA')", (self.w.child,self.client))
        self.assert_history(False)

    def test_free_history_survives_no_base_plan(self):
        with admin_connection() as c:
            c.execute('UPDATE ap_m1.child_paid_entitlements SET revoked_at=now() WHERE child_id=%s', (self.w.child,))
        self.assert_history(False)


if __name__ == '__main__':
    unittest.main()
