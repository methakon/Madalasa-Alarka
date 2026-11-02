"""L09-008/010: remote command state machine, named OS-refusal failures and audit,
and the conditional app-control gate (standard phone never claims broad blocking).

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


class CommandStateMachineTests(unittest.TestCase):
    def setUp(self):
        self.f = domain_fixture()
        self.addCleanup(lambda: cleanup_domain(self.f))
        self.device = self.f['device_a']
        self.child_a = self.f['child_a']

    def _queue_refresh(self):
        cmd = uuid4()
        deadline = datetime.now(timezone.utc) + timedelta(minutes=30)
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            db.execute('SELECT ap_m1.request_device_command(%s,%s,%s,%s,%s)',
                       (self.child_a, self.device, cmd, 'REFRESH_CAPABILITIES', deadline))
            db.commit()
        return cmd

    # ---- L09-008: only released command kinds accepted; no false broad control ----

    def test_unreleased_command_kind_is_refused(self):
        cmd = uuid4()
        deadline = datetime.now(timezone.utc) + timedelta(minutes=30)
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            with self.assertRaises(psycopg.Error) as ctx:
                with db.transaction():
                    db.execute('SELECT ap_m1.request_device_command(%s,%s,%s,%s,%s)',
                               (self.child_a, self.device, cmd, 'BLOCK_ALL_APPS', deadline))
            # A standard phone never gets a broad app-blocking command queued.
            self.assertIn('FEATURE_NOT_RELEASED', str(ctx.exception))
            db.rollback()

    # ---- L09-010: state machine happy path and named OS-refusal failure ----

    def test_full_state_machine_queued_to_completed(self):
        cmd = self._queue_refresh()
        with fixtures.admin_connection() as admin:
            self.assertEqual(admin.execute('SELECT command_state FROM ap_m1.commands WHERE id=%s', (cmd,)).fetchone()[0], 'QUEUED')
        now = datetime.now(timezone.utc)
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, None, None, self.device)
            db.execute('SELECT ap_m1.record_command_receipt(%s,%s,%s,%s,%s,%s)', (self.device, cmd, 1, 'DELIVERED', now, 'DELIVERED'))
            db.execute('SELECT ap_m1.record_command_receipt(%s,%s,%s,%s,%s,%s)', (self.device, cmd, 2, 'ACCEPTED', now, 'ACCEPTED'))
            db.execute('SELECT ap_m1.record_command_receipt(%s,%s,%s,%s,%s,%s)', (self.device, cmd, 3, 'COMPLETED', now, 'OK'))
            db.commit()
        with fixtures.admin_connection() as admin:
            self.assertEqual(admin.execute('SELECT command_state FROM ap_m1.commands WHERE id=%s', (cmd,)).fetchone()[0], 'COMPLETED')
            # Terminal result recorded for audit.
            self.assertEqual(admin.execute('SELECT outcome FROM ap_m1.command_results WHERE command_id=%s', (cmd,)).fetchone()[0], 'COMPLETED')
            admin.rollback()

    def test_os_refusal_returns_named_failure_and_audit(self):
        cmd = self._queue_refresh()
        now = datetime.now(timezone.utc)
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, None, None, self.device)
            db.execute('SELECT ap_m1.record_command_receipt(%s,%s,%s,%s,%s,%s)', (self.device, cmd, 1, 'DELIVERED', now, 'DELIVERED'))
            db.execute('SELECT ap_m1.record_command_receipt(%s,%s,%s,%s,%s,%s)', (self.device, cmd, 2, 'OS_REJECTED', now, 'OS_DENIED'))
            db.commit()
        with fixtures.admin_connection() as admin:
            self.assertEqual(admin.execute('SELECT command_state,reason_code FROM ap_m1.commands WHERE id=%s', (cmd,)).fetchone(), ('OS_REJECTED', 'OS_DENIED'))
            self.assertEqual(admin.execute('SELECT outcome FROM ap_m1.command_results WHERE command_id=%s', (cmd,)).fetchone()[0], 'OS_REJECTED')
            admin.rollback()

    def test_invalid_transition_is_rejected(self):
        cmd = self._queue_refresh()
        now = datetime.now(timezone.utc)
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, None, None, self.device)
            # QUEUED -> COMPLETED is not a legal transition (must go through DELIVERED/ACCEPTED).
            with self.assertRaises(psycopg.Error):
                with db.transaction():
                    db.execute('SELECT ap_m1.record_command_receipt(%s,%s,%s,%s,%s,%s)', (self.device, cmd, 1, 'COMPLETED', now, 'ILLEGAL'))
            db.rollback()


if __name__ == '__main__':
    unittest.main()
