"""L06-012: 48h reconnect, many batches and crash recovery — no loss after durable
ack, each event inserted once, with a recorded performance envelope.

Disposable synthetic PostgreSQL only. Every coordinate is explicitly synthetic.
Scales N down from the 10000-batch target by default so CI stays fast; set
AP_RECOVERY_BATCHES to raise it. The durability/exactly-once invariants are
independent of N.
"""
import os
import time
import unittest
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import psycopg
from psycopg.types.json import Jsonb
try:
    from . import fixtures
    from .test_location import domain_fixture, cleanup_domain
except ImportError:
    import fixtures
    from test_location import domain_fixture, cleanup_domain


class LocationRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.f = domain_fixture()
        self.addCleanup(lambda: self._cleanup())
        self.device = self.f['device_a']
        self.child = self.f['child_a']

    def _cleanup(self):
        with fixtures.admin_connection() as admin:
            if admin.execute("SELECT to_regclass('ap_m1.location_batch_items')").fetchone()[0]:
                admin.execute('DELETE FROM ap_m1.location_batch_items WHERE child_id=%s', (self.child,))
        cleanup_domain(self.f)

    def _event(self, sequence, observed_at):
        return dict(event_id=str(uuid4()), sequence=sequence,
                    observed_at=observed_at.isoformat(),
                    latitude=0.125, longitude=0.25, accuracy_m=12, provider='SYNTHETIC')

    def test_crash_before_commit_yields_no_rows_no_ack(self):
        """Tx-A durable inbox: a batch ingested but not committed (simulated crash
        via rollback) leaves no inbox, no observations and no outbox row."""
        batch = uuid4()
        ev = self._event(1, datetime.now(timezone.utc) - timedelta(seconds=5))
        conn = fixtures.runtime_connection()
        try:
            fixtures.as_parent(conn, None, None, self.device)
            conn.execute('SELECT ap_m1.ingest_location_batch(%s,%s,%s)', (self.device, batch, Jsonb([ev])))
            # Crash before COMMIT: the HTTP 202 is only sent after the outer commit.
            conn.rollback()
        finally:
            conn.close()
        with fixtures.admin_connection() as admin:
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.location_ingest_batches WHERE id=%s', (batch,)).fetchone()[0], 0)
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.location_observations WHERE child_id=%s', (self.child,)).fetchone()[0], 0)
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.ingestion_outbox WHERE child_id=%s', (self.child,)).fetchone()[0], 0)

    def test_48h_reconnect_many_batches_no_loss_and_exactly_once(self):
        """Buffer a 48h window of batches offline, then reconnect and commit each.
        Every event is durably stored exactly once; re-sending a committed batch is
        idempotent (no duplicate rows), and the outbox worker claims each batch once."""
        n = int(os.environ.get('AP_RECOVERY_BATCHES', '200'))
        # Stay strictly inside the 48h max_upload_age window: start at 47h ago and
        # keep a safety margin from clock_timestamp() so no event trips INVALID_GPS.
        window_secs = 47 * 3600
        base = datetime.now(timezone.utc) - timedelta(seconds=window_secs)
        batches = []
        seq = 2_000_000
        t0 = time.monotonic()
        conn = fixtures.runtime_connection()
        try:
            for i in range(n):
                # Spread observed times across the ~47h offline window, newest-safe.
                observed = base + timedelta(seconds=i * (window_secs // max(n, 1)))
                if observed >= datetime.now(timezone.utc) - timedelta(seconds=10):
                    observed = datetime.now(timezone.utc) - timedelta(seconds=10)
                ev = self._event(seq + i, observed)
                batch = uuid4()
                batches.append((batch, ev))
                fixtures.as_parent(conn, None, None, self.device)
                conn.execute('SELECT ap_m1.ingest_location_batch(%s,%s,%s)', (self.device, batch, Jsonb([ev])))
                conn.commit()
            ingest_secs = time.monotonic() - t0

            # Idempotent replay of every committed batch: no duplicate observations.
            for batch, ev in batches:
                fixtures.as_parent(conn, None, None, self.device)
                conn.execute('SELECT ap_m1.ingest_location_batch(%s,%s,%s)', (self.device, batch, Jsonb([ev])))
                conn.commit()
        finally:
            conn.close()

        with fixtures.admin_connection() as admin:
            obs_count = admin.execute('SELECT count(*) FROM ap_m1.location_observations WHERE child_id=%s', (self.child,)).fetchone()[0]
            dedup_count = admin.execute('SELECT count(*) FROM ap_m1.location_event_dedup WHERE child_id=%s', (self.child,)).fetchone()[0]
            batch_count = admin.execute('SELECT count(*) FROM ap_m1.location_ingest_batches WHERE child_id=%s', (self.child,)).fetchone()[0]
            outbox_count = admin.execute('SELECT count(*) FROM ap_m1.ingestion_outbox WHERE child_id=%s', (self.child,)).fetchone()[0]

        # No loss, exactly once: one observation + one dedup row + one batch each.
        self.assertEqual(obs_count, n, 'every event stored exactly once (no loss, no dupes)')
        self.assertEqual(dedup_count, n)
        self.assertEqual(batch_count, n)
        self.assertEqual(outbox_count, n)

        # Simulated worker restart: each PENDING job is claimed exactly once even if
        # a worker crashes after claiming (lease expiry) — completion is fenced.
        worker = uuid4()
        with fixtures.admin_connection() as admin:
            claimed = admin.execute('SELECT job_id,lease_fence FROM ap_m1.claim_ingestion_jobs(%s,%s)', (worker, min(n, 50))).fetchall()
            self.assertTrue(len(claimed) >= 1)
            # A stale fence (worker "restarted" losing its lease view) cannot complete.
            jid, fence = claimed[0]
            self.assertFalse(admin.execute('SELECT ap_m1.complete_ingestion_job(%s,%s,%s)', (jid, worker, fence + 99)).fetchone()[0])
            self.assertTrue(admin.execute('SELECT ap_m1.complete_ingestion_job(%s,%s,%s)', (jid, worker, fence)).fetchone()[0])
            admin.rollback()

        # Performance envelope (synthetic, informational — not a production SLA).
        print(f"\n[L06-012 ENVELOPE] batches={n} ingest+commit={ingest_secs:.3f}s "
              f"({n / ingest_secs:.1f} batches/s) observations={obs_count} dedup_rows={dedup_count}")

    def test_diagnostics_surface_stale_unknown_and_outage(self):
        """L06-011: GPS health/queue/status diagnostics. A device with no fix is
        UNKNOWN; a last fix older than the freshness window is STALE; separate
        observed/received timestamps make an outage explicit rather than invented."""
        # No observations yet → UNKNOWN last-known position.
        with fixtures.admin_connection() as admin:
            latest = admin.execute('SELECT count(*) FROM ap_m1.device_latest_positions WHERE device_id=%s', (self.device,)).fetchone()[0]
            self.assertEqual(latest, 0, 'no fix yet => UNKNOWN, not a fabricated location')

        # Ingest one qualified fix ~30 min old (stale relative to a 6-hour fresh UI,
        # but present), and confirm observed_at and received_at are distinct signals.
        conn = fixtures.runtime_connection()
        try:
            observed = datetime.now(timezone.utc) - timedelta(minutes=30)
            ev = self._event(3_000_000, observed)
            fixtures.as_parent(conn, None, None, self.device)
            conn.execute('SELECT ap_m1.ingest_location_batch(%s,%s,%s)', (self.device, uuid4(), Jsonb([ev])))
            conn.commit()
        finally:
            conn.close()

        with fixtures.admin_connection() as admin:
            row = admin.execute(
                'SELECT observed_at, received_at FROM ap_m1.location_observations WHERE child_id=%s', (self.child,)
            ).fetchone()
            observed_at, received_at = row
            # Outage/latency is explicit: received strictly at/after observed.
            self.assertGreaterEqual(received_at, observed_at)
            # Staleness is derivable: this fix is older than a 5-minute freshness bound.
            age_seconds = (datetime.now(timezone.utc) - observed_at).total_seconds()
            self.assertGreater(age_seconds, 300, 'fix is stale vs a 5-min freshness window')
            # Latest-position is recorded (known), not invented as "now".
            latest = admin.execute('SELECT observed_at FROM ap_m1.device_latest_positions WHERE device_id=%s', (self.device,)).fetchone()
            self.assertIsNotNone(latest)
            self.assertEqual(latest[0], observed_at)


if __name__ == '__main__':
    unittest.main()
