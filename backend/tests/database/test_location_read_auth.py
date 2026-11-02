"""L07-012: parent/child isolation and historical cursor safety for the read path.

Child B must be invisible to a guardian scoped only to child A, even with a crafted
child id or history cursor/range. Disposable synthetic PostgreSQL only.
"""
import unittest
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import psycopg
from psycopg.types.json import Jsonb
try:
    from . import fixtures
    from .test_location import domain_fixture, cleanup_domain
except ImportError:
    import fixtures
    from test_location import domain_fixture, cleanup_domain


class LocationReadAuthTests(unittest.TestCase):
    def setUp(self):
        self.f = domain_fixture()
        self.addCleanup(lambda: self._cleanup())
        self.device = self.f['device_a']
        self.child_a = self.f['child_a']
        self.child_b = self.f['child_b']  # from seed_core; guardian A is NOT scoped to B

    def _cleanup(self):
        with fixtures.admin_connection() as admin:
            if admin.execute("SELECT to_regclass('ap_m1.location_batch_items')").fetchone()[0]:
                admin.execute('DELETE FROM ap_m1.location_batch_items WHERE child_id=%s', (self.child_a,))
        cleanup_domain(self.f)

    def _ingest_recent(self):
        ev = dict(event_id=str(uuid4()), sequence=7_000_001,
                  observed_at=(datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat(),
                  latitude=0.1, longitude=0.2, accuracy_m=10, provider='SYNTHETIC')
        conn = fixtures.runtime_connection()
        try:
            fixtures.as_parent(conn, None, None, self.device)
            conn.execute('SELECT ap_m1.ingest_location_batch(%s,%s,%s)', (self.device, uuid4(), Jsonb([ev])))
            conn.commit()
        finally:
            conn.close()
        return ev

    def test_latest_location_denied_to_wrong_guardian(self):
        """L07-002/L07-012: guardian B cannot read child A's latest observation."""
        self._ingest_recent()
        with fixtures.runtime_connection() as db:
            # Guardian B authenticates to their own family/child B only.
            fixtures.as_parent(db, self.f['b'], self.f['family_b'])
            rows = db.execute('SELECT count(*) FROM ap_m1.location_observations WHERE child_id=%s', (self.child_a,)).fetchone()[0]
            self.assertEqual(rows, 0, 'child A observations invisible to guardian B via RLS')
            # Even a crafted history query for child A returns nothing for guardian B.
            crafted = db.execute(
                "SELECT * FROM ap_m1.location_history(%s, now()-interval '2 days', now(), 500)", (self.child_a,)
            ).fetchall()
            self.assertEqual(crafted, [])
            db.rollback()

    def test_authorized_guardian_sees_only_their_child(self):
        """L07-012: guardian A sees child A but never child B, even with a crafted id."""
        self._ingest_recent()
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            own = db.execute('SELECT count(*) FROM ap_m1.location_observations WHERE child_id=%s', (self.child_a,)).fetchone()[0]
            self.assertGreaterEqual(own, 1)
            # Crafted query for sibling/other child B leaks nothing.
            other = db.execute('SELECT * FROM ap_m1.location_observations WHERE child_id=%s', (self.child_b,)).fetchall()
            self.assertEqual(other, [])
            db.rollback()

    def test_history_cursor_cannot_cross_six_hour_free_boundary(self):
        """L07-005/L07-012: a crafted older range cannot retrieve free fixes >6h old."""
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            older = db.execute(
                "SELECT * FROM ap_m1.location_history(%s, now()-interval '2 days', now()-interval '7 hours', 500)",
                (self.child_a,)
            ).fetchall()
            self.assertEqual(older, [], 'no cursor retrieves free fixes older than the 6h window')
            db.rollback()


if __name__ == '__main__':
    unittest.main()
