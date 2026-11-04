"""E-03: ingestion idempotence, replay-conflict taxonomy and out-of-order safety.

Exercises the real SECURITY DEFINER ingest path against disposable synthetic
PostgreSQL. Duplicate handling is asserted as behaviour, not as a claim about
device-side retry policy.
"""
import threading
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


def _event(minutes_ago=5, sequence=None, event_id=None, **overrides):
    payload = {
        'event_id': str(event_id or uuid4()),
        'sequence': sequence if sequence is not None else 9_000_000 + int(uuid4().int % 900_000),
        'observed_at': (datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)).isoformat(),
        'latitude': 22.5726, 'longitude': 88.3639, 'accuracy_m': 8.0, 'provider': 'SYNTHETIC',
    }
    payload.update(overrides)
    return payload


class IngestIdempotencyTests(unittest.TestCase):
    def setUp(self):
        self.f = domain_fixture()
        self.addCleanup(self._cleanup)
        self.device = self.f['device_a']
        self.child = self.f['child_a']

    def _cleanup(self):
        with fixtures.admin_connection() as admin:
            admin.execute('DELETE FROM ap_m1.location_batch_items WHERE child_id=%s', (self.child,))
        cleanup_domain(self.f)

    def _ingest(self, events, batch_id=None):
        batch_id = batch_id or uuid4()
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, None, None, self.device)
            row = db.execute(
                'SELECT * FROM ap_m1.ingest_location_batch_receipt(%s,%s,%s)',
                (self.device, batch_id, Jsonb(events))).fetchone()
            db.commit()
        return batch_id, row

    def _count(self, table, where='child_id=%s'):
        with fixtures.admin_connection() as admin:
            return admin.execute(f'SELECT count(*) FROM ap_m1.{table} WHERE {where}',
                                 (self.child,)).fetchone()[0]

    def test_identical_batch_replay_is_idempotent_and_reported(self):
        event = _event()
        batch, first = self._ingest([event])
        self.assertEqual(first[1], 1, 'first delivery accepts the event')
        self.assertEqual(first[2], 0, 'first delivery has no duplicates')
        self.assertFalse(first[3], 'first delivery is not a replay')
        rows_after_first = self._count('location_observations')

        same_batch, replay = self._ingest([event], batch_id=batch)
        self.assertEqual(same_batch, batch)
        self.assertTrue(replay[3], 'identical batch id must be reported as a replay')
        self.assertEqual(replay[1], 0, 'replay accepts no new events')
        self.assertEqual(replay[2], 1, 'replay reports the duplicate event')
        self.assertEqual(self._count('location_observations'), rows_after_first,
                         'replay must not duplicate observations')

    def test_batch_replay_with_different_payload_is_rejected(self):
        batch = uuid4()
        self._ingest([_event()], batch_id=batch)
        with self.assertRaises(psycopg.DatabaseError) as caught:
            self._ingest([_event()], batch_id=batch)
        self.assertEqual(caught.exception.sqlstate, 'MAB01', 'batch replay conflict code')

    def test_duplicate_event_in_new_batch_counts_as_duplicate(self):
        event = _event()
        self._ingest([event])
        before = self._count('location_observations')
        _, receipt = self._ingest([event])
        self.assertEqual(receipt[1], 0, 'duplicate event is not accepted again')
        self.assertEqual(receipt[2], 1, 'duplicate event is counted')
        self.assertEqual(self._count('location_observations'), before)

    def test_conflicting_event_payload_is_rejected(self):
        event = _event()
        self._ingest([event])
        mutated = dict(event, latitude=23.0)
        with self.assertRaises(psycopg.DatabaseError) as caught:
            self._ingest([mutated])
        self.assertEqual(caught.exception.sqlstate, 'MAB02', 'event replay conflict code')

    def test_reused_sequence_with_new_event_is_rejected(self):
        event = _event(sequence=9_111_111)
        self._ingest([event])
        with self.assertRaises(psycopg.DatabaseError) as caught:
            self._ingest([_event(sequence=9_111_111)])
        self.assertEqual(caught.exception.sqlstate, 'MAB03', 'sequence reuse code')

    def test_late_event_does_not_regress_latest_position(self):
        older = _event(minutes_ago=30, sequence=9_222_001)
        newer = _event(minutes_ago=2, sequence=9_222_002)
        self._ingest([newer])
        self._ingest([older])
        with fixtures.admin_connection() as admin:
            latest = admin.execute(
                'SELECT event_id FROM ap_m1.device_latest_positions WHERE device_id=%s',
                (self.device,)).fetchone()[0]
        self.assertEqual(str(latest), newer['event_id'], 'out-of-order arrival must not win')
        self.assertEqual(self._count('location_observations'), 2,
                         'late events are still persisted in history')

    def test_future_and_stale_timestamps_are_rejected(self):
        future = _event(minutes_ago=-10)
        with self.assertRaises(psycopg.errors.InvalidParameterValue) as caught:
            self._ingest([future])
        self.assertEqual(caught.exception.sqlstate, '22023')
        stale = _event(minutes_ago=60 * 24 * 30)
        with self.assertRaises(psycopg.errors.InvalidParameterValue) as caught:
            self._ingest([stale])
        self.assertEqual(caught.exception.sqlstate, '22023')

    def test_concurrent_identical_batches_store_one_copy(self):
        event = _event()
        batch = uuid4()
        outcomes = []
        lock = threading.Lock()

        def deliver():
            try:
                _, receipt = self._ingest([event], batch_id=batch)
                with lock:
                    outcomes.append(tuple(receipt[1:]))
            except psycopg.Error as exc:
                with lock:
                    outcomes.append(exc.sqlstate)

        threads = [threading.Thread(target=deliver) for _ in range(2)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=30)
        self.assertEqual(len(outcomes), 2, 'both deliveries completed')
        self.assertCountEqual(outcomes, [(1, 0, False), (0, 1, True)])
        self.assertEqual(self._count('location_observations'), 1,
                         'concurrent identical delivery must store exactly one observation')

    def test_repeated_array_occurrences_count_as_duplicates(self):
        event = _event()
        _, fresh = self._ingest([event, event])
        self.assertEqual(tuple(fresh[1:]), (1, 1, False))
        _, known = self._ingest([event, event])
        self.assertEqual(tuple(known[1:]), (0, 2, False))
        self.assertEqual(self._count('location_observations'), 1)

    def test_concurrent_distinct_batches_same_event_report_one_acceptance(self):
        event = _event()
        outcomes = []
        barrier = threading.Barrier(2)

        def deliver():
            try:
                barrier.wait(timeout=10)
                _, receipt = self._ingest([event])
                outcomes.append(tuple(receipt[1:]))
            except Exception as exc:
                outcomes.append(type(exc).__name__)

        threads = [threading.Thread(target=deliver) for _ in range(2)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=30)
        self.assertCountEqual(outcomes, [(1, 0, False), (0, 1, False)])
        self.assertEqual(self._count('location_observations'), 1)

    def test_receipt_refuses_missing_or_other_device_context(self):
        for actor in (None, self.f['a']):
            with fixtures.runtime_connection() as db:
                if actor:
                    fixtures.as_parent(db, actor, self.f['family_a'])
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    db.execute('SELECT * FROM ap_m1.ingest_location_batch_receipt(%s,%s,%s)',
                               (self.device, uuid4(), Jsonb([_event()])))
                db.rollback()


if __name__ == '__main__':
    unittest.main()
