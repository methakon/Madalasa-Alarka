"""A restored snapshot cannot certify its own erasure-ledger completeness."""
import hashlib
import unittest
from uuid import uuid4
import psycopg
import fixtures


class RestoreCheckpointTests(unittest.TestCase):
    def setUp(self):
        self.admin=fixtures.admin_connection()
        self.addCleanup(self.admin.close)
        self.addCleanup(self.admin.rollback)
        backup=self.admin.execute('INSERT INTO ap_m1.backup_inventory(backup_ref,completed_at) VALUES(%s,now()) RETURNING id',(uuid4(),)).fetchone()[0]
        self.restore=self.admin.execute('INSERT INTO ap_m1.restore_runs(backup_id) VALUES(%s) RETURNING id',(backup,)).fetchone()[0]

    def test_unimported_ledger_never_certifies_ready_even_if_empty(self):
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            with self.admin.transaction():
                self.admin.execute('SET LOCAL ROLE ap_privacy_worker')
                self.admin.execute('SELECT ap_m1.suppress_restore(%s)',(self.restore,))
        self.assertFalse(self.admin.execute('SELECT ap_m1.restore_can_open(%s)',(self.restore,)).fetchone()[0])

    def test_import_binds_independent_current_checkpoint(self):
        evidence=hashlib.sha256(b'LOCAL_SYNTHETIC_LEDGER_IMPORT').digest()
        self.admin.execute('SELECT ap_m1.import_restore_ledger(%s,%s)',(self.restore,evidence))
        self.admin.execute('SELECT ap_m1.suppress_restore(%s)',(self.restore,))
        self.assertTrue(self.admin.execute('SELECT ap_m1.restore_can_open(%s)',(self.restore,)).fetchone()[0])
        # A later independently recorded erasure invalidates the earlier proof.
        self.admin.execute("INSERT INTO ma_recovery.erasure_ledger(child_id,erased_at,reason_code) VALUES(%s,now(),'SYNTHETIC_CHECKPOINT')",(uuid4(),))
        self.assertFalse(self.admin.execute('SELECT ap_m1.restore_can_open(%s)',(self.restore,)).fetchone()[0])

    def test_runtime_cannot_attest_ledger_import(self):
        with fixtures.runtime_connection() as runtime:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                runtime.execute('SELECT ap_m1.import_restore_ledger(%s,%s)',(self.restore,b'x'*32))
