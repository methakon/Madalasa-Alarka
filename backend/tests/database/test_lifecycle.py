"""Actual dump/restore acceptance on the dedicated test database only."""
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

import psycopg
import fixtures
from datetime import datetime, timezone, timedelta
from uuid import uuid4
from psycopg.types.json import Jsonb

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/database'))
import manage


class BackupRestoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if fixtures.ci_mode():
            # The dump/restore drill drives the labelled local container. The
            # executed drill is recorded in local evidence; CI covers lineage,
            # ACL and the versioned regression suite instead.
            raise unittest.SkipTest('backup/restore needs the local container; '
                                    'local executed drill recorded in evidence')

    def test_backup_restore_preserves_schema_and_quarantines_runtime(self):
        fixtures.seed_core()
        def snapshot():
            with fixtures.admin_connection() as conn:
                return conn.execute("""SELECT c.relname,c.relkind,c.relrowsecurity,c.relforcerowsecurity,
                  (SELECT count(*) FROM pg_constraint k WHERE k.conrelid=c.oid)
                  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                  WHERE n.nspname='ap_m1' AND c.relkind IN ('r','p','v') ORDER BY c.relname""").fetchall()
        before=snapshot()
        backup=manage.backup('test')
        run=manage.subprocess.run
        observed=[]
        def actual_run(command,*args,**kwargs):
            if 'pg_restore' in command:
                try:
                    probe=fixtures.runtime_connection(connect_timeout=2)
                    probe.close()
                    observed.append('RUNTIME_ALLOWED_DURING_RESTORE')
                except psycopg.OperationalError:
                    observed.append('RUNTIME_DENIED_DURING_RESTORE')
            return run(command,*args,**kwargs)
        with patch.object(manage.subprocess,'run',side_effect=actual_run):
            manage.restore('test',backup)
        self.assertEqual(observed,['RUNTIME_DENIED_DURING_RESTORE'])
        self.assertEqual(snapshot(),before)
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime,fixtures.seed_core()['a'])
            self.assertIsNotNone(runtime.execute('SELECT ap_m1.ctx_principal()').fetchone()[0])
        # A repeat migration runner must see exact same checksums, not replay DDL.
        manage.migrate('test')

    def test_newer_erasure_ledger_suppresses_populated_older_backup(self):
        from test_location import domain_fixture
        f=domain_fixture()
        with fixtures.runtime_connection() as runtime:
            old_device_token=fixtures.as_parent(runtime,None,None,f['device_a'])
            event={'event_id':str(uuid4()),'sequence':1,
                   'observed_at':(datetime.now(timezone.utc)-timedelta(seconds=2)).isoformat(),
                   'latitude':0.125,'longitude':0.25,'accuracy_m':12,'provider':'SYNTHETIC'}
            runtime.execute('SELECT ap_m1.ingest_location_batch(%s,%s,%s)',(f['device_a'],uuid4(),Jsonb([event])))
        with fixtures.admin_connection() as admin:
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.location_observations WHERE child_id=%s',(f['child_a'],)).fetchone()[0],1)
        backup=manage.backup('test')
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime,f['a'],f['family_a'])
            runtime.execute('SELECT ap_m1.request_child_erasure(%s,%s)',(f['child_a'],uuid4()))
        with fixtures.admin_connection() as admin:
            self.assertIsNotNone(admin.execute('SELECT child_id FROM ma_recovery.erasure_ledger WHERE child_id=%s',(f['child_a'],)).fetchone())
            # Even losing application tombstones must not lose the independent
            # newer ledger that is excluded from application backup/reset.
            admin.execute('DELETE FROM ap_m1.child_erasure_tombstones WHERE child_id=%s',(f['child_a'],))
        manage.restore('test',backup)
        with fixtures.admin_connection() as admin:
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.location_observations WHERE child_id=%s',(f['child_a'],)).fetchone()[0],0)
            self.assertIsNotNone(admin.execute('SELECT deleted_at FROM ap_m1.children WHERE id=%s',(f['child_a'],)).fetchone()[0])
            self.assertEqual(admin.execute('SELECT enrollment_state FROM ap_m1.devices WHERE id=%s',(f['device_a'],)).fetchone()[0],'REVOKED')
        with fixtures.runtime_connection() as runtime:
            runtime.execute("SELECT set_config('ap.session_token',%s,true)",(old_device_token,))
            self.assertFalse(runtime.execute('SELECT ap_m1.owns_active_device(%s)',(f['device_a'],)).fetchone()[0])


if __name__=='__main__':unittest.main()
