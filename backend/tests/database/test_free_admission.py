"""Free-first FIFO admission regression; synthetic disposable PostgreSQL only.

The test changes are rolled back, including the synthetic family, child aliases,
admission rows and erasure tombstone. It NEVER runs on a production DSN.
"""
import unittest
import psycopg
from uuid import uuid4
from fixtures import admin_connection


class FreeAdmissionTests(unittest.TestCase):
    def test_atomic_108_child_cap_fifo_and_tombstone_reallocation(self):
        db = admin_connection()
        try:
            base = db.execute(
                "SELECT count(*) FROM ap_m1.free_child_admissions "
                "WHERE admission_state='ADMITTED'").fetchone()[0]
            self.assertLessEqual(base, 108)
            family = uuid4()
            db.execute("INSERT INTO ap_m1.families(id,label) VALUES(%s,'synthetic admission limit')", (family,))
            needed = 108 - base
            ids = [uuid4() for _ in range(needed + 2)]
            for i, child in enumerate(ids):
                db.execute(
                    "INSERT INTO ap_m1.children(id,family_id,alias) VALUES(%s,%s,%s)",
                    (child, family, f'synthetic waitlist {i}'))
            rows = db.execute(
                "SELECT child_id,admission_state FROM ap_m1.free_child_admissions "
                "WHERE child_id=ANY(%s::uuid[])", (ids,)).fetchall()
            state = {child: status for child, status in rows}
            self.assertEqual(sum(x == 'ADMITTED' for x in state.values()), needed)
            self.assertEqual(sum(x == 'WAITLISTED' for x in state.values()), 2)
            self.assertEqual(state[ids[-2]], 'WAITLISTED')
            self.assertEqual(state[ids[-1]], 'WAITLISTED')
            self.assertEqual(db.execute(
                "SELECT count(*) FROM ap_m1.free_child_admissions WHERE admission_state='ADMITTED'"
            ).fetchone()[0], 108)
            # Queue entrants cannot be authorized for child services regardless
            # of fake billing state or count of additional guardian sessions.
            self.assertFalse(db.execute(
                "SELECT ap_m1.child_free_admitted(%s)", (ids[-2],)).fetchone()[0])
            self.assertFalse(db.execute(
                "SELECT ap_m1.child_free_admitted(%s)", (ids[-1],)).fetchone()[0])
            # Even a fabricated device id cannot start a queued child's
            # SOS/check-in pipeline: admission is enforced before FK checks.
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                with db.transaction():
                    db.execute(
                        "INSERT INTO ap_m1.child_signals(event_id,child_id,device_id,kind,observed_at) "
                        "VALUES(%s,%s,%s,'IM_SAFE',clock_timestamp())",
                        (uuid4(), ids[-2], uuid4())
                    )
            if needed:
                db.execute(
                    "INSERT INTO ap_m1.child_erasure_tombstones(child_id,reason_code) "
                    "VALUES(%s,'SYNTHETIC_ADMISSION_RELEASE')", (ids[0],))
                self.assertEqual(db.execute(
                    "SELECT admission_state FROM ap_m1.free_child_admissions WHERE child_id=%s",
                    (ids[0],)).fetchone()[0], 'RELEASED')
                self.assertEqual(db.execute(
                    "SELECT admission_state FROM ap_m1.free_child_admissions WHERE child_id=%s",
                    (ids[-2],)).fetchone()[0], 'ADMITTED')
                self.assertEqual(db.execute(
                    "SELECT admission_state FROM ap_m1.free_child_admissions WHERE child_id=%s",
                    (ids[-1],)).fetchone()[0], 'WAITLISTED')
                self.assertEqual(db.execute(
                    "SELECT count(*) FROM ap_m1.free_child_admissions WHERE admission_state='ADMITTED'"
                ).fetchone()[0], 108)
        finally:
            db.rollback()
            db.close()

    def test_self_registration_receipt_preserves_original_child_scope_rls(self):
        # Unconsented child can be confirmed only to its actual registrant.
        # Do not widen ordinary children SELECT to family owners.
        from fixtures import seed_core, runtime_connection, as_parent
        f = seed_core()
        with runtime_connection() as db:
            as_parent(db, f['a'], f['family_a'])
            new_id = db.execute(
                "SELECT ap_m1.create_child(%s)", ('synthetic pending registration',)
            ).fetchone()[0]
            # RLS remains strict before consent/child-specific grant.
            self.assertEqual(db.execute(
                "SELECT count(*) FROM ap_m1.children WHERE id=%s", (new_id,)
            ).fetchone()[0], 0)
            receipt = db.execute(
                "SELECT service_state FROM ap_m1.my_free_registration_profiles(%s) WHERE id=%s",
                (f['family_a'],new_id)
            ).fetchone()
            self.assertIsNotNone(receipt)
            self.assertIn(receipt[0], ('ADMITTED','WAITLISTED'))
            # A different family selector must not expose the receipt.
            self.assertEqual(db.execute(
                "SELECT count(*) FROM ap_m1.my_free_registration_profiles(%s)",
                (f['family_b'],)
            ).fetchone()[0],0)
            db.rollback()

    def test_existing_child_select_rls_was_never_broadened(self):
        with admin_connection() as db:
            rows=db.execute(
                "SELECT policyname FROM pg_policies "
                "WHERE schemaname='ap_m1' AND tablename='children'"
            ).fetchall()
            self.assertNotIn('free_queue_owner_child_profile',[x[0] for x in rows])

    def test_denied_or_missing_children_never_have_slots(self):
        with admin_connection() as db:
            self.assertFalse(db.execute(
                "SELECT ap_m1.child_free_admitted(%s)", (uuid4(),)).fetchone()[0])


if __name__ == '__main__':
    unittest.main()
