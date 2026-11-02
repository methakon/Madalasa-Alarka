"""Disposable PostgreSQL only. Every coordinate below is explicitly synthetic."""
import json
import unittest
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import psycopg
from psycopg.types.json import Jsonb
try:
    from . import fixtures
except ImportError:
    import fixtures


def domain_fixture():
    """Own child/device/consents, so revocation tests never mutate shared actors."""
    f = dict(fixtures.seed_core())
    f.update(child_a=uuid4(), device_a=uuid4(), review_a=uuid4(), consent_a=uuid4())
    with fixtures.admin_connection() as db:
        db.execute("insert into ap_m1.children(id,family_id,alias) values(%s,%s,'Synthetic domain test')", (f['child_a'], f['family_a']))
        db.execute("insert into ap_m1.child_authority_reviews(id,child_id,adult_id,state,lawful_basis_version,method_code,reviewed_at,expires_at) values(%s,%s,%s,'LOCAL_TEST_APPROVED','synthetic-v1','SYNTHETIC_FIXTURE',now(),now()+interval '1 day')", (f['review_a'],f['child_a'],f['a']))
        for purpose in ('CORE','LOCATION','USAGE','MEDIA'):
            cid = f['consent_a'] if purpose == 'CORE' else uuid4()
            db.execute("insert into ap_m1.consent_records(id,child_id,adult_id,purpose,status,authority_review_id,notice_version,legal_state,expires_at) values(%s,%s,%s,%s,'GRANTED',%s,'synthetic-v1','LOCAL_TEST_APPROVED',now()+interval '1 day')", (cid,f['child_a'],f['a'],purpose,f['review_a']))
        db.execute("insert into ap_m1.child_access_grants_v2(child_id,adult_id,scope,consent_record_id,authority_review_id,issued_by) select %s,adult_id,scope,%s,%s,issued_by from ap_m1.child_access_grants_v2 where child_id=%s and adult_id=%s and revoked_at IS NULL", (f['child_a'],f['consent_a'],f['review_a'],fixtures.seed_core(db)['child_a'],f['a']))
        db.execute("insert into ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state) values(%s,%s,%s,%s,'ACTIVE')", (f['device_a'],f['family_a'],f['child_a'],('SYNTHETIC-NOT-CRYPTO-' + str(f['device_a'])).encode()*2))
        f['device_key_a'] = fixtures.seed_device_key(db, f['device_a'])
        db.execute("insert into ap_m1.location_collection_policies(child_id,enabled,retain_for,policy_reference) values(%s,true,interval '7 days','SYNTHETIC_FIXTURE_ONLY')", (f['child_a'],))
    return f


def cleanup_domain(f):
    with fixtures.admin_connection() as db:
        # All rows belong to this independently seeded synthetic child.
        for table in ('policy_execution_receipts','rule_assignments','screen_time_rules',
                      'command_results','command_receipts','commands',
                      'device_permission_change_events','permission_snapshots','device_reenrollment_events',
                      'capability_snapshots','parent_notification_read_receipts','signal_acknowledgements',
                      'alert_delivery_attempts','notification_deliveries','alert_delivery_outbox','alert_events','child_signals',
                      'place_notification_rules','named_places','trip_routepoints','trip_revisions','trips',
                      'device_latest_positions','ingestion_outbox','location_observations','location_batch_items','location_event_dedup','location_ingest_batches','app_usage_intervals'):
            if table in ('command_results','capability_snapshots'):
                db.execute('delete from ap_m1.'+table+' where '+('command_id in (select id from ap_m1.commands where child_id=%s)' if table=='command_results' else 'device_id=%s'), (f['child_a'] if table=='command_results' else f['device_a'],))
            else:
                db.execute('delete from ap_m1.'+table+' where child_id=%s', (f['child_a'],))
        db.execute('set constraints all immediate')
        db.execute('delete from ap_m1.trusted_sessions where device_id=%s', (f['device_a'],))
        db.execute('delete from ap_m1.device_key_records where device_id=%s', (f['device_a'],))
        db.execute('delete from ap_m1.location_collection_policies where child_id=%s', (f['child_a'],))
        db.execute('delete from ap_m1.devices where id=%s', (f['device_a'],))
        db.execute('delete from ap_m1.child_access_grants_v2 where child_id=%s', (f['child_a'],))
        db.execute('delete from ap_m1.consent_records where child_id=%s', (f['child_a'],))
        db.execute('delete from ap_m1.child_authority_reviews where child_id=%s', (f['child_a'],))
        db.execute('delete from ap_m1.children where id=%s', (f['child_a'],))


class LocationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core = domain_fixture()

    @classmethod
    def tearDownClass(cls):
        cleanup_domain(cls.core)

    def setUp(self):
        self.db = fixtures.runtime_connection()
        self.addCleanup(self.db.close)
        self.addCleanup(self.db.rollback)
        self.admin = fixtures.admin_connection()
        self.addCleanup(self.admin.close)
        self.addCleanup(self.admin.rollback)
        self.device = self.core['device_a']
        self.child = self.core['child_a']

    def device_actor(self):
        fixtures.as_parent(self.db, None, None, self.device)

    def event(self, sequence=1, age=0):
        return dict(event_id=str(uuid4()), sequence=sequence,
                    observed_at=(datetime.now(timezone.utc)-timedelta(seconds=age+2)).isoformat(),
                    latitude=0.125, longitude=0.25, accuracy_m=12, provider='SYNTHETIC')

    def ingest(self, events, batch=None):
        return self.db.execute('select ap_m1.ingest_location_batch(%s,%s,%s)',
                               (self.device, batch or uuid4(), Jsonb(events))).fetchone()[0]

    def test_09_ingestion_replay_conflict_and_last_known(self):
        self.device_actor()
        event = self.event(sequence=1000001)
        batch = uuid4()
        self.assertEqual(self.ingest([event], batch), self.ingest([event], batch))
        with self.db.transaction():
            with self.assertRaises(psycopg.Error):
                with self.db.transaction():
                    self.ingest([dict(event, latitude=1)], batch)
        # Runtime cannot inject arbitrary raw observations, even for its own device.
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            with self.db.transaction():
                self.db.execute('delete from ap_m1.location_observations')

    def test_10_invalid_times_coordinates_sequences_atomic(self):
        self.device_actor()
        for change in [dict(latitude=91), dict(longitude=-181), dict(sequence=-1),
                       dict(observed_at=(datetime.now(timezone.utc)+timedelta(days=1)).isoformat())]:
            with self.subTest(change=change):
                with self.assertRaises(psycopg.Error):
                    with self.db.transaction():
                        self.ingest([self.event(1000002), dict(self.event(1000003), **change)])

    def test_11_free_direct_history_and_function_are_six_hour_bounded(self):
        self.device_actor()
        recent = self.event(2000001)
        old = self.event(2000002, age=7*3600)
        self.ingest([old, recent])
        fixtures.as_parent(self.db, self.core['a'], self.core['family_a'])
        self.assertFalse(self.db.execute('select rolsuper or rolbypassrls from pg_roles where rolname=current_user').fetchone()[0])
        rows = self.db.execute('select observed_at from ap_m1.location_observations where child_id=%s', (self.child,)).fetchall()
        self.assertEqual(1, len(rows))
        cutoff = datetime.now(timezone.utc)-timedelta(hours=6, seconds=2)
        self.assertTrue(all(row[0] >= cutoff for row in rows))
        self.assertEqual([], self.db.execute('select * from ap_m1.location_history(%s,now()-interval \'2 days\',now()-interval \'7 hours\',100)', (self.child,)).fetchall())
        self.assertEqual([], self.db.execute('select * from ap_m1.location_observations where child_id=%s', (self.core['child_b'],)).fetchall())

    def test_12_parent_cannot_impersonate_device(self):
        fixtures.as_parent(self.db, self.core['a'], self.core['family_a'])
        self.db.execute("select set_config('ap.device_id',%s,true)", (str(self.device),))
        with self.assertRaises(psycopg.Error):
            with self.db.transaction():
                self.ingest([self.event(1000004)])

    def test_13_places_revision_and_exact_child(self):
        fixtures.as_parent(self.db, self.core['a'], self.core['family_a'])
        place = uuid4()
        self.db.execute('select ap_m1.save_named_place(%s,%s,%s,%s,%s,%s,%s)',
                        (self.child, place, 0, 'Synthetic pin', 0.0, 0.0, 150))
        self.assertEqual(1, self.db.execute('select revision from ap_m1.named_places where id=%s', (place,)).fetchone()[0])
        with self.assertRaises(psycopg.Error):
            with self.db.transaction():
                self.db.execute('select ap_m1.save_named_place(%s,%s,0,%s,0,0,150)', (self.core['child_b'], place, 'denied'))


    def test_19_late_quality_and_sequence_dedup(self):
        self.device_actor()
        newest = self.event(3000001)
        older = self.event(3000002, age=60)
        coarse = dict(self.event(3000003), accuracy_m=500)
        self.ingest([newest])
        self.ingest([older, coarse])
        with self.assertRaises(psycopg.Error):
            with self.db.transaction():
                self.ingest([dict(self.event(3000001), latitude=2)])
        fixtures.as_parent(self.db, self.core['a'], self.core['family_a'])
        self.assertEqual(newest['event_id'], str(self.db.execute('select event_id from ap_m1.device_latest_positions where device_id=%s', (self.device,)).fetchone()[0]))
        self.assertEqual(3, self.db.execute('select count(*) from ap_m1.location_observations where child_id=%s', (self.child,)).fetchone()[0])
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            with self.db.transaction():
                self.db.execute('select ap_m1.publish_observed_trip(%s,%s,%s,0,%s,%s)', (self.child,self.device,uuid4(),[uuid4(),uuid4()],'denied'))

    def test_20_revoked_deleted_and_withdrawn_deny_existing_token(self):
        changes = [
            ("update ap_m1.devices set revoked_at=now() where id=%s", self.device,
             "update ap_m1.devices set revoked_at=null where id=%s"),
            ("update ap_m1.children set deletion_requested_at=now() where id=%s", self.child,
             "update ap_m1.children set deletion_requested_at=null where id=%s"),
            ("update ap_m1.consent_records set withdrawn_at=now() where child_id=%s and purpose='LOCATION'", self.child,
             "update ap_m1.consent_records set withdrawn_at=null where child_id=%s and purpose='LOCATION'"),
        ]
        for update, key, restore in changes:
            with self.subTest(update=update):
                self.device_actor()
                self.admin.execute(update, (key,))
                self.admin.commit()
                try:
                    with self.assertRaises(psycopg.Error):
                        with self.db.transaction():
                            self.ingest([self.event(4000001)])
                finally:
                    self.db.rollback()
                    self.admin.execute(restore,(key,))
                    self.admin.commit()

    def test_21_batch_failure_does_not_leave_partial_raw_rows(self):
        self.device_actor()
        with self.assertRaises(psycopg.Error):
            with self.db.transaction():
                self.ingest([self.event(5000001), dict(self.event(5000002),latitude=99)])
        fixtures.as_parent(self.db, self.core['a'], self.core['family_a'])
        self.assertEqual(0,self.db.execute('select count(*) from ap_m1.location_observations where child_id=%s',(self.child,)).fetchone()[0])


    def test_22_worker_trip_revisions_preserve_gaps_and_exact_source(self):
        self.device_actor()
        events=[self.event(6000001,age=900), self.event(6000002,age=30)]
        self.ingest(events)
        self.db.commit()
        trip=uuid4()
        self.assertEqual(1,self.admin.execute('select ap_m1.publish_observed_trip(%s,%s,%s,0,%s,%s)',
            (self.child,self.device,trip,[UUID(e['event_id']) for e in events],'SYNTHETIC evidence')).fetchone()[0])
        self.admin.commit()
        fixtures.as_parent(self.db, self.core['a'], self.core['family_a'])
        rows=self.db.execute('select point_kind from ap_m1.trip_routepoints where trip_id=%s order by point_no',(trip,)).fetchall()
        self.assertEqual(['OBSERVED','GAP','OBSERVED'],[r[0] for r in rows])
        self.db.rollback()
        with self.assertRaises(psycopg.Error):
            with self.admin.transaction():
                self.admin.execute('select ap_m1.publish_observed_trip(%s,%s,%s,1,%s,%s)',
                    (self.core['child_b'],self.device,trip,[UUID(e['event_id']) for e in events],'wrong child'))
        # Remove durable rows immediately: no inter-test fixture dependence.
        self.admin.execute('delete from ap_m1.trips where id=%s',(trip,))
        self.admin.execute('delete from ap_m1.location_observations where child_id=%s',(self.child,))
        self.admin.execute('delete from ap_m1.location_batch_items where child_id=%s',(self.child,))
        self.admin.execute('delete from ap_m1.location_event_dedup where child_id=%s',(self.child,))
        self.admin.execute('delete from ap_m1.location_ingest_batches where child_id=%s',(self.child,))
        self.admin.commit()


if __name__ == '__main__':
    unittest.main()
