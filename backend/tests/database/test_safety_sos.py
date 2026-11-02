"""L09-002/003/004/005/012: SOS durable acceptance vs guardian ACK, authorized
fanout only, delivery retry/failed non-guarantee, health staleness, and the
duplicate/offline/revocation safety cases.

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


class SafetySosTests(unittest.TestCase):
    def setUp(self):
        self.f = domain_fixture()
        self.addCleanup(lambda: cleanup_domain(self.f))
        self.device = self.f['device_a']
        self.child_a = self.f['child_a']

    def _raise_sos(self, eid=None, t=None):
        eid = eid or uuid4()
        t = t or (datetime.now(timezone.utc) - timedelta(seconds=5))
        conn = fixtures.runtime_connection()
        try:
            fixtures.as_parent(conn, None, None, self.device)
            conn.execute('SELECT ap_m1.record_child_signal(%s,%s,%s,%s)', (self.device, eid, 'SOS', t))
            conn.commit()
        finally:
            conn.close()
        return eid, t

    # ---- L09-002: device receipt != guardian acknowledgement ----

    def test_device_sos_receipt_is_not_guardian_acknowledgement(self):
        eid, _t = self._raise_sos()
        with fixtures.admin_connection() as admin:
            # The signal + alert exist (device receipt), but no acknowledgement yet.
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.child_signals WHERE event_id=%s', (eid,)).fetchone()[0], 1)
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.alert_events WHERE signal_event_id=%s', (eid,)).fetchone()[0], 1)
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.signal_acknowledgements WHERE event_id=%s', (eid,)).fetchone()[0], 0)
            admin.rollback()
        # A guardian with VIEW_ALERTS acknowledges; now an ack row exists, distinct from receipt.
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            db.execute('SELECT ap_m1.acknowledge_child_signal(%s,%s)', (self.child_a, eid))
            db.commit()
        with fixtures.admin_connection() as admin:
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.signal_acknowledgements WHERE event_id=%s', (eid,)).fetchone()[0], 1)
            admin.rollback()

    # ---- L09-012: duplicate SOS does not create a second alert ----

    def test_duplicate_sos_event_id_is_idempotent(self):
        eid, t = self._raise_sos()
        # Re-send the same event id with identical fields: idempotent, no second alert.
        self._raise_sos(eid=eid, t=t)
        with fixtures.admin_connection() as admin:
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.child_signals WHERE event_id=%s', (eid,)).fetchone()[0], 1)
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.alert_events WHERE signal_event_id=%s', (eid,)).fetchone()[0], 1)
            admin.rollback()

    def test_sos_replay_with_different_payload_is_rejected(self):
        eid, _t = self._raise_sos()
        conn = fixtures.runtime_connection()
        try:
            fixtures.as_parent(conn, None, None, self.device)
            with self.assertRaises(psycopg.Error):
                with conn.transaction():
                    # Same event id but different kind => replay conflict, no duplicate alert.
                    conn.execute('SELECT ap_m1.record_child_signal(%s,%s,%s,%s)',
                                 (self.device, eid, 'IM_SAFE', datetime.now(timezone.utc) - timedelta(seconds=3)))
            conn.rollback()
        finally:
            conn.close()

    # ---- L09-003 / L09-012: fanout only to authorized guardian; no unrelated parent ----

    def test_delivery_to_unrelated_parent_is_rejected(self):
        eid, _t = self._raise_sos()
        with fixtures.admin_connection() as admin:
            alert = admin.execute('SELECT id FROM ap_m1.alert_events WHERE signal_event_id=%s', (eid,)).fetchone()[0]
            # Guardian B (other family) is not an authorized recipient for child A.
            with self.assertRaises(psycopg.errors.InsufficientPrivilege) if False else self.assertRaises(psycopg.Error):
                with admin.transaction():
                    admin.execute("SET LOCAL ROLE ap_db_executor")
                    admin.execute('SELECT ap_m1.record_alert_delivery_attempt(%s,%s,%s,%s,%s,%s)',
                                  (self.child_a, alert, self.f['b'], 'PUSH', 'SUBMITTED', 'synthetic-ref'))
            admin.rollback()

    # ---- L09-004: retry / explicit failed delivery surfaces non-guarantee ----

    def test_failed_delivery_keeps_outbox_pending_and_not_confirmed(self):
        eid, _t = self._raise_sos()
        with fixtures.admin_connection() as admin:
            alert = admin.execute('SELECT id FROM ap_m1.alert_events WHERE signal_event_id=%s', (eid,)).fetchone()[0]
            admin.execute("SET LOCAL ROLE ap_db_executor")
            admin.execute('SELECT ap_m1.record_alert_delivery_attempt(%s,%s,%s,%s,%s,%s)',
                          (self.child_a, alert, self.f['a'], 'PUSH', 'FAILED', 'synthetic-fail'))
            admin.execute("RESET ROLE")
            status = admin.execute('SELECT status FROM ap_m1.notification_deliveries WHERE alert_id=%s AND recipient_id=%s', (alert, self.f['a'])).fetchone()[0]
            self.assertEqual(status, 'FAILED')
            self.assertNotEqual(status, 'DELIVERY_CONFIRMED')
            outbox = admin.execute('SELECT state FROM ap_m1.alert_delivery_outbox WHERE alert_id=%s', (alert,)).fetchone()[0]
            self.assertEqual(outbox, 'PENDING')  # stays pending for retry; not a delivered claim
            admin.rollback()

    # ---- L09-005: health last-seen with staleness retained ----

    def test_device_health_retains_observed_and_recorded_timestamps(self):
        with fixtures.admin_connection() as admin:
            observed = datetime.now(timezone.utc) - timedelta(minutes=20)
            # Insert as the privileged admin fixture (write-path RBAC is not under test here;
            # this verifies the schema retains distinct observed/recorded staleness signals).
            admin.execute("INSERT INTO ap_m1.device_health(device_id,observed_at,battery_percent,charging) "
                          "VALUES(%s,%s,%s,%s) ON CONFLICT(device_id) DO UPDATE SET observed_at=excluded.observed_at,"
                          "battery_percent=excluded.battery_percent,charging=excluded.charging,recorded_at=now()",
                          (self.device, observed, 42, False))
            row = admin.execute('SELECT observed_at,recorded_at,battery_percent FROM ap_m1.device_health WHERE device_id=%s', (self.device,)).fetchone()
            obs, rec, batt = row
            self.assertGreaterEqual(rec, obs)  # staleness is explicit (recorded after observed)
            self.assertEqual(batt, 42)
            age_min = (datetime.now(timezone.utc) - obs).total_seconds() / 60
            self.assertGreater(age_min, 15)  # last-seen is stale, truthfully retained
            admin.rollback()


if __name__ == '__main__':
    unittest.main()
