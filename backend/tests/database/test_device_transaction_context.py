"""DeviceBearer -> V2 context. Synthetic restricted-login DB tests; never migrate.

Offline: .venv/bin/python -m unittest backend.tests.database.test_device_transaction_context.DeviceContextSourceTests -v
DB (integrator after replay): .venv/bin/python -m unittest backend.tests.database.test_device_transaction_context.DeviceTransactionContextTests -v
"""
import hashlib
from pathlib import Path
import secrets
import unittest
from uuid import uuid4

import psycopg
from psycopg.types.json import Jsonb

try:
    from . import fixtures
    from .test_location import domain_fixture, cleanup_domain
    from .test_ingest_idempotency import _event
except ImportError:
    import fixtures
    from test_location import domain_fixture, cleanup_domain
    from test_ingest_idempotency import _event

ROOT = Path(__file__).resolve().parents[3]


class DeviceContextSourceTests(unittest.TestCase):
    def test_context_reuses_live_credential_lookup_without_minting(self):
        migration = ROOT / 'backend/persistence/migrations/0027_device_credential_transaction_context.sql'
        self.assertTrue(migration.exists(), 'DeviceBearer V2 context migration is missing')
        sql = migration.read_text()
        self.assertIn('ap_m1.authenticate_device_credential(', sql)
        self.assertNotIn('INSERT INTO ap_m1.trusted_sessions', sql)
        self.assertNotIn("current_setting('ap.device_id'", sql)
        self.assertIn("~ '^[0-9a-f]{64}$'", sql)

    def test_parent_and_local_test_resolution_preserved(self):
        migration = ROOT / 'backend/persistence/migrations/0027_device_credential_transaction_context.sql'
        self.assertTrue(migration.exists(), 'DeviceBearer V2 context migration is missing')
        old = (ROOT / 'backend/persistence/migrations/0021_parent_oidc_session_bridge.sql').read_text()
        old_body = old.split('AS $f$', 2)[2].split('$f$;', 1)[0]
        new_body = migration.read_text().split('AS $f$', 1)[1].split('$f$;', 1)[0]
        # The only change to the original branches is excluding mixed credentials.
        expected = old_body.rstrip().removesuffix(';').replace(
            'WHERE t.token_sha256=',
            "WHERE NULLIF(current_setting('ap.device_credential_sha256',true),'') IS NULL\n  AND t.token_sha256=")
        self.assertTrue(new_body.startswith(expected), 'original parent/local-test branches changed')

    def test_http_uses_transaction_credential_and_database_counts(self):
        src = (ROOT / 'backend/src/device_activity.h').read_text()
        ingest = src.split('inline drogon::Task<drogon::HttpResponsePtr> ingest_location_batch(', 1)[1]
        self.assertEqual(ingest.count('co_await bind_device_transaction('), 1)
        self.assertNotIn("set_config('ap.device_id'", ingest)
        self.assertIn('ap_m1.ingest_location_batch_receipt(', src)
        self.assertIn('res.at(0)["accepted_count"]', src)
        self.assertIn('res.at(0)["duplicate_count"]', src)
        support = (ROOT / 'backend/src/db_support.h').read_text()
        for state in ('MAB01', 'MAB02', 'MAB03'):
            self.assertIn('state == "' + state + '"', support)

    def test_context_migration_does_not_expand_health_writes(self):
        sql = (ROOT / 'backend/persistence/migrations/0027_device_credential_transaction_context.sql').read_text()
        self.assertNotIn('GRANT INSERT', sql)
        self.assertNotIn('CREATE POLICY', sql)


class DeviceTransactionContextTests(unittest.TestCase):
    def setUp(self):
        self.f = domain_fixture()
        self.device = self.f['device_a']
        self.key = self.f['device_key_a']
        self.addCleanup(self.cleanup)
        self.db = fixtures.runtime_connection()
        self.addCleanup(self.db.close)
        self.addCleanup(self.db.rollback)
        # Invented bearer seeded only by the privileged test harness. Not a
        # production issuance mechanism, and never printed or put in GUCs raw.
        self.digest = hashlib.sha256(secrets.token_bytes(32)).digest()
        with fixtures.admin_connection() as admin:
            admin.execute(
                'INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,expires_at,'
                'bound_key_generation,bound_key_fingerprint_sha256) '
                "SELECT %s,key_id,%s,'ENROLLMENT',clock_timestamp()+interval '1 hour',generation,fingerprint_sha256 "
                'FROM ap_m1.device_key_records WHERE key_id=%s',
                (self.device, self.digest, self.key))

    def cleanup(self):
        with fixtures.admin_connection() as admin:
            admin.execute('DELETE FROM ap_m1.device_health WHERE device_id=%s', (self.device,))
            admin.execute('DELETE FROM ap_m1.device_credentials WHERE device_id=%s', (self.device,))
        cleanup_domain(self.f)

    def bind(self, digest=None):
        self.db.execute("SELECT set_config('ap.session_token','',true),"
                        "set_config('ap.device_credential_sha256',%s,true)",
                        ((self.digest if digest is None else digest).hex(),))

    def context(self):
        row = self.db.execute('SELECT ap_m1.ctx_principal(),ap_m1.ctx_family(),ap_m1.ctx_device()').fetchone()
        assert row is not None
        return row

    def ingest(self, device=None, batch=None, event=None):
        return self.db.execute('SELECT * FROM ap_m1.ingest_location_batch_receipt(%s,%s,%s)',
                               (device or self.device, batch or uuid4(), Jsonb([event or _event()]))).fetchone()

    def denied(self, device=None):
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            with self.db.transaction():
                self.ingest(device=device)

    def test_valid_credential_ingests_and_reports_replay(self):
        self.bind()
        self.assertEqual((None, self.f['family_a'], self.device), self.context())
        event, batch = _event(), uuid4()
        self.assertEqual((batch, 1, 0, False), self.ingest(batch=batch, event=event))
        self.assertEqual((batch, 0, 1, True), self.ingest(batch=batch, event=event))

    def test_device_context_does_not_restore_revoked_health_table_writes(self):
        self.bind()
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            with self.db.transaction():
                self.db.execute('INSERT INTO ap_m1.device_health(device_id,observed_at,charging,permission_revision) '
                                'VALUES(%s,clock_timestamp(),false,1)', (self.device,))

    def test_raw_uuid_and_forged_digest_cannot_authorize(self):
        self.db.execute("SELECT set_config('ap.device_id',%s,true)", (str(self.device),))
        self.denied()
        self.bind(hashlib.sha256(secrets.token_bytes(32)).digest())
        self.assertIsNone(self.context()[2])
        self.denied()

    def test_malformed_digest_fails_closed_without_cast_errors(self):
        for value in ('not-hex', '00', 'g' * 64, '0' * 65):
            with self.subTest(shape=len(value)):
                self.db.execute("SELECT set_config('ap.device_credential_sha256',%s,true)", (value,))
                self.assertIsNone(self.context()[2])
                self.denied()

    def test_parent_token_is_not_a_device_credential(self):
        token = fixtures.as_parent(self.db, self.f['a'], self.f['family_a'])
        self.assertEqual(self.f['a'], self.context()[0])
        self.denied()
        self.bind(hashlib.sha256(token.encode()).digest())
        self.assertIsNone(self.context()[2])
        self.denied()

    def test_valid_credential_cannot_ingest_for_another_device(self):
        self.bind()
        # Core fixture device is distinct from the independently owned device.
        other = fixtures.seed_core()['device_a']
        self.db.execute("SELECT set_config('ap.device_id',%s,true)", (str(other),))
        self.assertNotEqual(self.device, other)
        self.denied(device=other)
        self.assertEqual(self.device, self.context()[2])

    def test_committed_revocation_visible_on_next_statement(self):
        self.bind()
        self.assertEqual(self.device, self.context()[2])
        with fixtures.admin_connection() as admin:
            admin.execute('UPDATE ap_m1.device_credentials SET revoked_at=clock_timestamp() '
                          'WHERE token_sha256=%s', (self.digest,))
        self.assertIsNone(self.context()[2])
        self.denied()

    def test_expired_credential_denied_even_in_older_transaction(self):
        self.bind()
        self.assertEqual(self.device, self.context()[2])
        with fixtures.admin_connection() as admin:
            admin.execute("UPDATE ap_m1.device_credentials SET issued_at=clock_timestamp()-interval '2 hours',"
                          "expires_at=clock_timestamp()-interval '1 hour' WHERE token_sha256=%s", (self.digest,))
        self.assertIsNone(self.context()[2])
        self.denied()

    def test_key_generation_and_fingerprint_revalidated(self):
        for change in ('generation=generation+1',
                       "fingerprint_sha256=public.digest('SYNTHETIC-CHANGED','sha256')",
                       "state='REVOKED',revoked_at=clock_timestamp()"):
            with self.subTest(change=change):
                self.bind()
                self.assertEqual(self.device, self.context()[2])
                with fixtures.admin_connection() as admin:
                    admin.execute('UPDATE ap_m1.device_key_records SET ' + change + ' WHERE key_id=%s', (self.key,))
                try:
                    self.assertIsNone(self.context()[2])
                    self.denied()
                finally:
                    self.db.rollback()
                    with fixtures.admin_connection() as admin:
                        admin.execute("UPDATE ap_m1.device_key_records k SET generation=c.bound_key_generation,"
                                      "fingerprint_sha256=c.bound_key_fingerprint_sha256,state='ACTIVE',revoked_at=NULL "
                                      'FROM ap_m1.device_credentials c WHERE k.key_id=%s AND c.key_id=k.key_id', (self.key,))

    def test_device_revocation_revalidated(self):
        self.bind()
        self.assertEqual(self.device, self.context()[2])
        with fixtures.admin_connection() as admin:
            admin.execute('UPDATE ap_m1.devices SET revoked_at=clock_timestamp() WHERE id=%s', (self.device,))
        self.assertIsNone(self.context()[2])
        self.denied()

    def test_transaction_local_context_does_not_leak_after_commit(self):
        self.bind()
        self.assertEqual(self.device, self.context()[2])
        self.db.commit()
        self.assertEqual((None, None, None), self.context())

    def test_mixed_parent_and_device_credentials_fail_closed(self):
        fixtures.as_parent(self.db, self.f['a'], self.f['family_a'])
        self.db.execute("SELECT set_config('ap.device_credential_sha256',%s,true)", (self.digest.hex(),))
        self.assertEqual((None, None, None), self.context())
        self.denied()

    def test_runtime_cannot_read_or_write_credential_proof(self):
        for sql in ('SELECT token_sha256 FROM ap_m1.device_credentials',
                    'UPDATE ap_m1.device_credentials SET revoked_at=NULL',
                    'INSERT INTO ap_m1.trusted_sessions(token_sha256,expires_at) '
                    "VALUES(decode(repeat('00',32),'hex'),clock_timestamp()+interval '1 hour')"):
            with self.subTest(operation=sql.split()[0]):
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    with self.db.transaction():
                        self.db.execute(sql)


if __name__ == '__main__':
    unittest.main()
