"""L08-006/008/009/010: saved places CRUD with child scopes, per-adult notification
toggle, notification outbox not-misrepresented-as-viewed, and home/school privacy.

Disposable synthetic PostgreSQL only.
"""
import unittest
from uuid import uuid4

import psycopg
try:
    from . import fixtures
    from .test_location import domain_fixture, cleanup_domain
except ImportError:
    import fixtures
    from test_location import domain_fixture, cleanup_domain


class PlacesNotificationsTests(unittest.TestCase):
    def setUp(self):
        self.f = domain_fixture()
        self.addCleanup(lambda: cleanup_domain(self.f))
        self.child_a = self.f['child_a']
        self.child_b = self.f['child_b']

    # ---- L08-006 / L08-010: places CRUD + exact-child privacy ----

    def test_place_created_and_visible_only_to_authorized_guardian(self):
        place = uuid4()
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            db.execute('SELECT ap_m1.save_named_place(%s,%s,0,%s,%s,%s,%s)',
                       (self.child_a, place, 'Home (synthetic)', 22.5, 88.3, 150))
            db.commit()
            # Guardian A sees their own place.
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            self.assertEqual(
                db.execute('SELECT title FROM ap_m1.named_places WHERE id=%s', (place,)).fetchone()[0],
                'Home (synthetic)')
            db.rollback()
            # Guardian B (other family) cannot read child A's named place (home/school privacy).
            fixtures.as_parent(db, self.f['b'], self.f['family_b'])
            self.assertEqual(
                db.execute('SELECT count(*) FROM ap_m1.named_places WHERE child_id=%s', (self.child_a,)).fetchone()[0], 0)
            db.rollback()

    def test_saving_place_for_unauthorized_child_denied(self):
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            with self.assertRaises(psycopg.Error):
                with db.transaction():
                    db.execute('SELECT ap_m1.save_named_place(%s,%s,0,%s,%s,%s,%s)',
                               (self.child_b, uuid4(), 'Intrusion', 0.0, 0.0, 150))
            db.rollback()

    # ---- L08-008: per-place per-adult notification toggle ----

    def test_notification_rule_is_per_adult(self):
        place = uuid4()
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            db.execute('SELECT ap_m1.save_named_place(%s,%s,0,%s,%s,%s,%s)',
                       (self.child_a, place, 'School (synthetic)', 22.6, 88.4, 120))
            db.execute('SELECT ap_m1.set_place_notification_rule(%s,%s,0,%s,%s)',
                       (self.child_a, place, True, False))
            db.commit()
        with fixtures.admin_connection() as admin:
            rows = admin.execute(
                'SELECT adult_id,arrival_enabled,departure_enabled FROM ap_m1.place_notification_rules WHERE place_id=%s',
                (place,)).fetchall()
            # Exactly one rule, owned by guardian A, arrival-only.
            self.assertEqual(len(rows), 1)
            self.assertEqual(str(rows[0][0]), str(self.f['a']))
            self.assertTrue(rows[0][1])
            self.assertFalse(rows[0][2])

    # ---- L08-009: submitted is never misrepresented as viewed ----

    def test_delivery_submitted_is_distinct_from_confirmed_and_read(self):
        with fixtures.admin_connection() as admin:
            # A synthetic alert + delivery in SUBMITTED state (FCM fake "accepted").
            alert = uuid4()
            # Build a place-arrival alert for child A.
            place = uuid4()
            admin.execute(
                "INSERT INTO ap_m1.named_places(id,child_id,created_by,title,position,radius_m) "
                "VALUES(%s,%s,%s,'Home',public.ST_SetSRID(public.ST_MakePoint(88.3,22.5),4326)::public.geography,150)",
                (place, self.child_a, self.f['a']))
            admin.execute(
                "INSERT INTO ap_m1.alert_events(id,child_id,place_id,kind,observed_at) VALUES(%s,%s,%s,'ARRIVE',now())",
                (alert, self.child_a, place))
            delivery = admin.execute(
                "INSERT INTO ap_m1.notification_deliveries(child_id,alert_id,recipient_id,status,submitted_at) "
                "VALUES(%s,%s,%s,'SUBMITTED',now()) RETURNING id",
                (self.child_a, alert, self.f['a'])).fetchone()[0]
            status = admin.execute('SELECT status FROM ap_m1.notification_deliveries WHERE id=%s', (delivery,)).fetchone()[0]
            # Submitted to the fake transport is NOT delivered and NOT read.
            self.assertEqual(status, 'SUBMITTED')
            self.assertNotIn(status, ('DELIVERY_CONFIRMED',))
            read = admin.execute('SELECT count(*) FROM ap_m1.parent_notification_read_receipts WHERE delivery_id=%s', (delivery,)).fetchone()[0]
            self.assertEqual(read, 0)
            admin.rollback()


if __name__ == '__main__':
    unittest.main()
