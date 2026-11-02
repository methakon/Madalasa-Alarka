"""Real restricted-login regressions; invented key bytes are NOT crypto proof.

Run before migration replay to reproduce the key-only revocation vulnerability.
Only the parent integrator applies migrations; these tests never migrate a DB.
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


class DeviceKeyBindingTests(unittest.TestCase):
    def setUp(self):
        self.f = domain_fixture()
        self.addCleanup(cleanup_domain, self.f)
        self.db = fixtures.runtime_connection()
        self.addCleanup(self.db.close)
        self.addCleanup(self.db.rollback)
        self.device = self.f['device_a']
        self.key = self.f['device_key_a']
        self.now = datetime.now(timezone.utc) - timedelta(seconds=3)

    def bind(self, token):
        self.db.execute("select set_config('ap.session_token',%s,true)", (token,))

    def revoke_key(self, *, state=True):
        with fixtures.admin_connection() as db:
            db.execute("update ap_m1.device_key_records set revoked_at=clock_timestamp()" +
                       (",state='REVOKED'" if state else "") + " where key_id=%s", (self.key,))
            self.assertEqual(('ACTIVE', None), db.execute(
                'select enrollment_state,revoked_at from ap_m1.devices where id=%s',
                (self.device,)).fetchone())

    def command(self):
        command = uuid4()
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['a'], self.f['family_a'])
            db.execute('select ap_m1.request_device_command(%s,%s,%s,%s,%s)',
                       (self.f['child_a'], self.device, command, 'REFRESH_CAPABILITIES',
                        self.now + timedelta(minutes=5)))
        return command

    def operation(self, kind, command=None):
        if kind == 'GPS':
            event = dict(event_id=str(uuid4()), sequence=1, observed_at=self.now.isoformat(),
                         latitude=0.125, longitude=0.25, accuracy_m=12, provider='SYNTHETIC')
            return self.db.execute('select ap_m1.ingest_location_batch(%s,%s,%s)',
                                   (self.device, uuid4(), Jsonb([event]))).fetchone()[0]
        if kind == 'REPORT':
            return self.db.execute('select ap_m1.report_permissions(%s,1,1,%s,%s)',
                                   (self.device, self.now, Jsonb({'location': 'DENIED'}))).fetchone()[0]
        return self.db.execute('select ap_m1.record_command_receipt(%s,%s,1,%s,%s,%s)',
                               (self.device, command, 'DELIVERED', self.now, 'SYNTHETIC')).fetchone()[0]

    def assert_denied(self, token, kind, command=None):
        self.bind(token)
        try:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                with self.db.transaction():
                    self.operation(kind, command)
        finally:
            self.db.rollback()

    def test_no_active_key_cannot_mint_device_session(self):
        with fixtures.admin_connection() as db:
            db.execute('delete from ap_m1.device_key_records where device_id=%s', (self.device,))
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            fixtures.mint_session(None, device=self.device)

    def test_key_only_revocation_denies_gps(self):
        self.check_key_only_revocation('GPS')

    def test_key_only_revocation_denies_permission_reports(self):
        self.check_key_only_revocation('REPORT')

    def test_key_only_revocation_denies_command_receipts(self):
        self.check_key_only_revocation('RECEIPT')

    def check_key_only_revocation(self, kind):
        command = self.command() if kind == 'RECEIPT' else None
        token = fixtures.mint_session(None, device=self.device)
        # Positive control proves each request is otherwise valid, not malformed.
        self.bind(token)
        self.assertIsNotNone(self.operation(kind, command))
        self.db.rollback()
        self.bind(token)
        self.assertEqual(self.device, self.db.execute('select ap_m1.ctx_device()').fetchone()[0])
        # Revocation becomes visible on the next statement of this same transaction.
        self.revoke_key()
        self.assert_denied(token, kind, command)

    def test_revoked_timestamp_alone_invalidates_session(self):
        token = fixtures.mint_session(None, device=self.device)
        self.revoke_key(state=False)
        self.bind(token)
        self.assertIsNone(self.db.execute('select ap_m1.ctx_device()').fetchone()[0])
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            fixtures.mint_session(None, device=self.device)

    def test_rotation_rejects_old_session_and_accepts_new_one(self):
        old = fixtures.mint_session(None, device=self.device)
        self.revoke_key()
        new_key = uuid4()
        with fixtures.admin_connection() as db:
            db.execute('update ap_m1.devices set spki_public_key=%s where id=%s',
                       (('SYNTHETIC-ROTATION-NOT-CRYPTO-' + str(new_key)).encode()*2, self.device))
            fixtures.seed_device_key(db, self.device, new_key)
        new = fixtures.mint_session(None, device=self.device)
        self.bind(new)
        self.assertEqual(self.device, self.db.execute('select ap_m1.ctx_device()').fetchone()[0])
        self.db.rollback()
        self.bind(old)
        self.assertIsNone(self.db.execute('select ap_m1.ctx_device()').fetchone()[0])
        self.assertFalse(self.db.execute('select coalesce(ap_m1.owns_active_device(%s),false)',
                                         (self.device,)).fetchone()[0])

    def test_spoofed_key_gucs_cannot_rebind_revoked_token(self):
        token = fixtures.mint_session(None, device=self.device)
        self.revoke_key()
        self.bind(token)
        for name in ('ap.device_id', 'ap.bound_key_id', 'ap.key_id', 'ap.bound_key_generation',
                     'ap.bound_key_fingerprint_sha256'):
            self.db.execute('select set_config(%s,%s,true)', (name, str(self.key)))
        self.assertIsNone(self.db.execute('select ap_m1.ctx_device()').fetchone()[0])

    def test_parent_principal_session_unaffected_by_device_key_revocation(self):
        token = fixtures.mint_session(self.f['a'], self.f['family_a'])
        self.revoke_key()
        self.bind(token)
        self.assertEqual(self.f['a'], self.db.execute('select ap_m1.ctx_principal()').fetchone()[0])
        self.assertEqual(self.f['family_a'], self.db.execute('select ap_m1.ctx_family()').fetchone()[0])
        self.assertIsNone(self.db.execute('select ap_m1.ctx_device()').fetchone()[0])

    def test_fingerprint_change_invalidates_existing_binding(self):
        token = fixtures.mint_session(None, device=self.device)
        with fixtures.admin_connection() as db:
            db.execute("update ap_m1.device_key_records set fingerprint_sha256=public.digest(%s,'sha256') where key_id=%s",
                       (b'SYNTHETIC-FINGERPRINT-CHANGE', self.key))
        self.bind(token)
        self.assertIsNone(self.db.execute('select ap_m1.ctx_device()').fetchone()[0])

    def test_mismatched_key_fingerprint_cannot_mint(self):
        with fixtures.admin_connection() as db:
            db.execute("update ap_m1.device_key_records set fingerprint_sha256=public.digest(%s,'sha256') where key_id=%s",
                       (b'SYNTHETIC-MISMATCH', self.key))
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            fixtures.mint_session(None, device=self.device)

    def test_generation_change_invalidates_existing_binding(self):
        token = fixtures.mint_session(None, device=self.device)
        with fixtures.admin_connection() as db:
            # Missing column is explicitly a new-interface RED, not revocation evidence.
            self.assertTrue(db.execute("select exists(select 1 from information_schema.columns "
                                       "where table_schema='ap_m1' and table_name='device_key_records' "
                                       "and column_name='generation')").fetchone()[0],
                            'device key generation schema is missing')
            db.execute('update ap_m1.device_key_records set generation=generation+1 where key_id=%s', (self.key,))
        self.bind(token)
        self.assertIsNone(self.db.execute('select ap_m1.ctx_device()').fetchone()[0])
        new = fixtures.mint_session(None, device=self.device)
        self.bind(new)
        self.assertEqual(self.device, self.db.execute('select ap_m1.ctx_device()').fetchone()[0])

    def test_runtime_cannot_write_key_or_session_binding(self):
        fixtures.as_parent(self.db, self.f['a'], self.f['family_a'])
        for sql in ('update ap_m1.device_key_records set revoked_at=null where key_id=%s',
                    'update ap_m1.trusted_sessions set device_id=%s'):
            with self.subTest(sql=sql):
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    with self.db.transaction():
                        self.db.execute(sql, (self.key if 'device_key_records' in sql else self.device,))

    def test_pending_proof_device_cannot_mint_even_with_synthetic_key_record(self):
        with fixtures.admin_connection() as db:
            db.execute("update ap_m1.devices set enrollment_state='PENDING_PROOF' where id=%s", (self.device,))
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            fixtures.mint_session(None, device=self.device)


if __name__ == '__main__':
    unittest.main()
