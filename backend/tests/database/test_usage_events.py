"""L09-006/007: capability-gated phone-usage events (legal OFF => zero ingest) and
usage aggregation where missing time is never counted as zero.

Disposable synthetic PostgreSQL only.
"""
import unittest
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import psycopg
try:
    from . import fixtures
    from .test_location import domain_fixture, cleanup_domain
except ImportError:
    import fixtures
    from test_location import domain_fixture, cleanup_domain


class UsageEventsTests(unittest.TestCase):
    def setUp(self):
        self.f = domain_fixture()
        self.addCleanup(lambda: cleanup_domain(self.f))
        self.device = self.f['device_a']
        self.child_a = self.f['child_a']

    def _interval(self, start_min_ago, end_min_ago, pkg='com.example.app', coverage='COMPLETE', ms=None):
        now = datetime.now(timezone.utc)
        start = now - timedelta(minutes=start_min_ago)
        end = now - timedelta(minutes=end_min_ago)
        if ms is None:
            ms = int((end - start).total_seconds() * 1000)
        conn = fixtures.runtime_connection()
        try:
            fixtures.as_parent(conn, None, None, self.device)
            conn.execute('SELECT ap_m1.record_usage_interval(%s,%s,%s,%s,%s,%s,%s)',
                         (self.device, uuid4(), pkg, start, end, ms, coverage))
            conn.commit()
        finally:
            conn.close()
        return start, end

    # ---- L09-006: legal OFF gate => zero ingest ----

    def test_usage_ingest_denied_without_usage_consent(self):
        with fixtures.admin_connection() as admin:
            admin.execute("UPDATE ap_m1.consent_records SET withdrawn_at=now() WHERE child_id=%s AND purpose='USAGE'", (self.child_a,))
            admin.commit()
        try:
            conn = fixtures.runtime_connection()
            try:
                fixtures.as_parent(conn, None, None, self.device)
                now = datetime.now(timezone.utc)
                with self.assertRaises(psycopg.Error):
                    with conn.transaction():
                        conn.execute('SELECT ap_m1.record_usage_interval(%s,%s,%s,%s,%s,%s,%s)',
                                     (self.device, uuid4(), 'com.example.app',
                                      now - timedelta(minutes=10), now - timedelta(minutes=5), 300000, 'COMPLETE'))
                conn.rollback()
            finally:
                conn.close()
            with fixtures.admin_connection() as admin:
                self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.app_usage_intervals WHERE child_id=%s', (self.child_a,)).fetchone()[0], 0)
                admin.rollback()
        finally:
            with fixtures.admin_connection() as admin:
                admin.execute("UPDATE ap_m1.consent_records SET withdrawn_at=NULL WHERE child_id=%s AND purpose='USAGE'", (self.child_a,))
                admin.commit()

    # ---- L09-007: missing time never counted as zero ----

    def test_summary_partial_coverage_is_not_reported_as_complete(self):
        # One interval well inside a wide window => coverage PARTIAL (window not fully covered).
        self._interval(start_min_ago=40, end_min_ago=35, coverage='COMPLETE')
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            now = datetime.now(timezone.utc)
            rows = db.execute('SELECT observed_seconds,coverage_quality FROM ap_m1.usage_summary(%s,%s,%s)',
                              (self.child_a, now - timedelta(hours=2), now)).fetchall()
            db.rollback()
        self.assertTrue(rows)
        # The window is only partially covered: coverage must NOT claim COMPLETE.
        self.assertTrue(all(r[1] in ('PARTIAL', 'UNKNOWN') for r in rows))

    def test_window_with_no_intervals_yields_no_false_zero(self):
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            now = datetime.now(timezone.utc)
            # A window with no usage rows returns no rows at all — not "0 seconds used".
            rows = db.execute('SELECT * FROM ap_m1.usage_summary(%s,%s,%s)',
                              (self.child_a, now - timedelta(hours=2), now - timedelta(hours=1))).fetchall()
            db.rollback()
        self.assertEqual(rows, [])


if __name__ == '__main__':
    unittest.main()
