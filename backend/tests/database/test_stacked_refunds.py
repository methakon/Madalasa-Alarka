"""Synthetic prepaid refund regressions; no migration/reset or real Play calls."""
import concurrent.futures
import threading
import unittest
from uuid import uuid4

from fixtures import admin_connection
from test_billing import World


class StackedRefundTests(unittest.TestCase):
    def setUp(self):
        self.w = World()
        self.addCleanup(self.w.cleanup)

    def term(self, purchase):
        with admin_connection() as c:
            return c.execute('''SELECT e.id,e.valid_from,e.valid_until,e.revision
                FROM ap_m1.child_paid_entitlements e
                JOIN ap_m1.child_seat_assignments s ON s.id=e.assignment_id
                JOIN ap_m1.prepaid_family_batches b ON b.id=s.batch_id
                WHERE b.purchase_id=%s AND e.child_id=%s''',
                (purchase, self.w.child)).fetchone()

    def test_refund_annual_predecessor_activates_future_purchase(self):
        first = self.w.purchase(sku='local_prepaid_year')
        second = self.w.purchase(sku='local_prepaid_year')
        addon = self.w.purchase(sku='local_extra_viewer_100d')
        old = self.term(second)
        self.w.reconcile(first)
        with self.w.runtime() as c:
            self.assertTrue(c.execute('SELECT ap_m1.has_paid_access(%s)',
                                     (self.w.child,)).fetchone()[0])
            self.assertEqual(c.execute('SELECT state FROM ap_m1.get_child_addons(%s)',
                                       (self.w.child,)).fetchone()[0], 'ACTIVE')
        new = self.term(second)
        self.assertLess(new[1], old[1])
        with admin_connection() as c:
            self.assertTrue(c.execute('''SELECT e.valid_until=e.valid_from+interval '1 year',
                e.valid_from>=greatest(p.purchased_at,p.verified_at),
                b.starts_at=e.valid_from AND b.expires_at=e.valid_until
                FROM ap_m1.child_paid_entitlements e
                JOIN ap_m1.child_seat_assignments s ON s.id=e.assignment_id
                JOIN ap_m1.prepaid_family_batches b ON b.id=s.batch_id
                JOIN ap_m1.play_purchase_records p ON p.id=b.purchase_id
                WHERE e.id=%s''', (new[0],)).fetchone() == (True, True, True))


    def test_future_pool_keeps_identity_and_consumption_after_rebase(self):
        first = self.w.purchase(sku='local_prepaid_year')
        second = self.w.purchase(sku='local_prepaid_year')
        term = self.term(second)
        # Seed a pre-materialized future window, not a replacement implementation.
        # Rebase must retain all accounting even if a future pool already exists.
        with admin_connection() as c:
            pool = c.execute('''INSERT INTO ap_m1.child_media_quota_pools
                (child_id,entitlement_id,starts_at,expires_at,audio_used,photos_used)
                VALUES(%s,%s,%s,%s::timestamptz+interval '1 month',123,2) RETURNING id''',
                (self.w.child,term[0],term[1],term[1])).fetchone()[0]
        self.w.reconcile(first)
        term = self.term(second)
        with admin_connection() as c:
            row = c.execute('''SELECT id,starts_at,expires_at,audio_used,photos_used
                FROM ap_m1.child_media_quota_pools WHERE entitlement_id=%s''', (term[0],)).fetchone()
        self.assertEqual(row[0:2], (pool,term[1]))
        self.assertEqual(row[3:], (123,2))
        with self.w.runtime() as c:
            quota = c.execute('SELECT * FROM ap_m1.get_media_quota(%s)', (self.w.child,)).fetchone()
        self.assertEqual((quota[0],quota[2]), (3477,28))
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.child_media_quota_pools WHERE entitlement_id=%s',
                                       (term[0],)).fetchone()[0],1)


    def test_four_terms_compact_deterministically_and_replays_do_not_move(self):
        purchases = [self.w.purchase(sku=sku) for sku in (
            'local_prepaid_year','local_prepaid_month','local_prepaid_year','local_prepaid_month')]
        old = [self.term(p) for p in purchases]
        event = self.w.reconcile(purchases[0], 'REVOKED')
        terms = [self.term(p) for p in purchases[1:]]
        self.assertLess(terms[0][1], old[1][1])
        for left,right in zip(terms,terms[1:]):
            self.assertEqual(left[2],right[1])
        self.w.reconcile(purchases[0], 'REVOKED',event)
        self.w.reconcile(purchases[0], 'REFUNDED')
        self.w.reconcile(purchases[0], 'CONFIRMED')
        self.assertEqual(terms,[self.term(p) for p in purchases[1:]])
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.purchase_adjustments WHERE purchase_id=%s',
                                       (purchases[0],)).fetchone()[0],1)
            audit = c.execute("SELECT purchase_id,details FROM ap_m1.entitlement_audit WHERE family_id=%s AND action='TERM_REBASED'",
                              (self.w.family,)).fetchall()
        self.assertEqual({row[0] for row in audit},set(purchases[1:]))
        self.assertTrue(all(row[1]['event_id']==str(event) for row in audit))

    def test_refund_later_unused_term_cannot_reopen_expired_predecessor(self):
        first = self.w.purchase()
        second = self.w.purchase()
        term = self.term(first)
        # Model time having passed without sleeps or changing PostgreSQL's clock.
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_paid_entitlements SET valid_from=now()-interval '2 months',valid_until=now()-interval '1 month' WHERE id=%s", (term[0],))
            c.execute('''INSERT INTO ap_m1.child_media_quota_pools
                (child_id,entitlement_id,starts_at,expires_at,audio_used)
                SELECT child_id,id,valid_from,valid_until,3600
                FROM ap_m1.child_paid_entitlements WHERE id=%s''', (term[0],))
        before = self.term(first)
        self.w.reconcile(second)
        self.assertEqual(self.term(first),before)
        with self.w.runtime() as c:
            self.assertFalse(c.execute('SELECT ap_m1.has_paid_access(%s)', (self.w.child,)).fetchone()[0])
            self.assertEqual(c.execute('SELECT * FROM ap_m1.get_media_quota(%s)', (self.w.child,)).fetchone(),(0,0,0,0,0))
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT audio_used FROM ap_m1.child_media_quota_pools WHERE child_id=%s',
                                       (self.w.child,)).fetchall(),[(3600,)])

    def test_refund_future_term_preserves_active_service_and_real_debit(self):
        from test_billing import EVIDENCE, verifier_connection
        first = self.w.purchase()
        second = self.w.purchase()
        with self.w.runtime() as c:
            request = c.execute("SELECT ap_m1.request_media(%s,%s,'AUDIO')", (self.w.child,self.w.device)).fetchone()[0]
        with verifier_connection() as c:
            c.execute("SELECT ap_m1.record_local_media_delivery(%s,%s,'DELIVERED_SYNTHETIC',100,%s,'LOCAL_SYNTHETIC')",
                      (request,uuid4(),EVIDENCE))
        before = self.term(first)
        with admin_connection() as c:
            pools = c.execute('SELECT id,starts_at,expires_at,audio_used FROM ap_m1.child_media_quota_pools WHERE child_id=%s', (self.w.child,)).fetchall()
            ledger = c.execute('SELECT id,pool_id,delivered_amount FROM ap_m1.media_quota_ledger WHERE child_id=%s', (self.w.child,)).fetchall()
        self.w.reconcile(second)
        self.assertEqual(self.term(first),before)
        with self.w.runtime() as c:
            self.assertEqual(c.execute('SELECT remaining_audio_seconds FROM ap_m1.get_media_quota(%s)', (self.w.child,)).fetchone()[0],3500)
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT id,starts_at,expires_at,audio_used FROM ap_m1.child_media_quota_pools WHERE child_id=%s', (self.w.child,)).fetchall(),pools)
            self.assertEqual(c.execute('SELECT id,pool_id,delivered_amount FROM ap_m1.media_quota_ledger WHERE child_id=%s', (self.w.child,)).fetchall(),ledger)

    def test_concurrent_renewal_and_refund_leave_contiguous_terms(self):
        first = self.w.purchase(sku='local_prepaid_year')
        second = self.w.purchase()
        intent = self.w.checkout()
        barrier = threading.Barrier(2)
        def renew():
            barrier.wait(timeout=10)
            return self.w.purchase(intent)
        def refund():
            barrier.wait(timeout=10)
            return self.w.reconcile(first)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            renewal = pool.submit(renew)
            reconciliation = pool.submit(refund)
            third = renewal.result(timeout=20)
            reconciliation.result(timeout=20)
        terms = [self.term(p) for p in (second,third)]
        self.assertEqual(terms[0][2],terms[1][1])
        with self.w.runtime() as c:
            self.assertTrue(c.execute('SELECT ap_m1.has_paid_access(%s)', (self.w.child,)).fetchone()[0])


    def test_runtime_cannot_reconcile_or_execute_pool_rebase(self):
        import psycopg
        from test_billing import EVIDENCE
        purchase = self.w.purchase()
        with self.w.runtime() as c:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute("SELECT ap_m1.reconcile_local_purchase(%s,%s,'REFUNDED',%s,'LOCAL_SYNTHETIC')",
                          (uuid4(),purchase,EVIDENCE))
        with self.w.runtime() as c:
            self.assertFalse(c.execute("SELECT coalesce(bool_or(has_function_privilege(current_user,p.oid,'EXECUTE')),false) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='ap_m1' AND p.proname='rebase_unstarted_media_pools'").fetchone()[0])

    def test_mixed_child_batch_preserves_started_sibling_term(self):
        first = self.w.purchase(sku='local_prepaid_year')
        intent = self.w.checkout('local_prepaid_year', [self.w.child,self.w.sibling])
        second = self.w.purchase(intent)
        with admin_connection() as c:
            sibling = c.execute('SELECT id,valid_from,valid_until,revision FROM ap_m1.child_paid_entitlements WHERE child_id=%s',
                                (self.w.sibling,)).fetchone()
        self.w.reconcile(first)
        with self.w.runtime() as c:
            self.assertEqual(c.execute('SELECT ap_m1.has_paid_access(%s),ap_m1.has_paid_access(%s)',
                                       (self.w.child,self.w.sibling)).fetchone(),(True,True))
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT id,valid_from,valid_until,revision FROM ap_m1.child_paid_entitlements WHERE child_id=%s',
                                       (self.w.sibling,)).fetchone(),sibling)
            self.assertTrue(c.execute('''SELECT b.starts_at=min(e.valid_from) AND b.expires_at=max(e.valid_until)
                FROM ap_m1.prepaid_family_batches b JOIN ap_m1.child_seat_assignments s ON s.batch_id=b.id
                JOIN ap_m1.child_paid_entitlements e ON e.assignment_id=s.id
                WHERE b.purchase_id=%s GROUP BY b.id''',(second,)).fetchone()[0])


if __name__ == '__main__':
    unittest.main()
