"""Offline lineage planner tests. Never connect to PostgreSQL or Docker."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
from contextlib import nullcontext


class RecordingConnection:
    """Only the SQL boundary is faked; planning/validation use production code."""
    def __init__(self, history=(), ledger=(), objects=False):
        self.history, self.ledger, self.objects = history, ledger, objects
        self.calls = []
        self.result = []

    def __enter__(self): return self
    def __exit__(self, *args): return False
    def transaction(self): return nullcontext()
    def fetchone(self): return self.result[0]
    def fetchall(self): return self.result
    def execute(self, query, params=None, **kwargs):
        text = str(query)
        self.calls.append((text, params))
        if 'to_regclass' in text:
            self.result = [(True,)]
        elif 'SELECT version,filename,checksum,status FROM ma_migrations.lineage_history' in text:
            self.result = self.ledger
        elif 'SELECT version,filename,checksum,status FROM ma_migrations.history' in text:
            self.result = self.history
        elif 'SELECT EXISTS' in text:
            self.result = [(self.objects,)]
        else:
            self.result = [(None,)]
        return self


SPEC = importlib.util.spec_from_file_location('lineage_manage', Path(__file__).parents[3] / 'tools/database/manage.py')
manage = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(manage)


class MigrationLineages(unittest.TestCase):
    def test_replanning_a_fully_applied_lineage_is_a_noop(self):
        entries = self.entries()
        full = {e['id'] for e in manage.migration_plan(entries, 'm1')} | {
            e['id'] for e in manage.migration_plan(entries)} | {
            'compat:m1_pre_v2_0016', 'compat:m1_pre_v2_0017'}
        # Unpublished sources cannot legally appear in a ledger yet.
        full = {i for i in full if {e['id']: e for e in entries}[i]['sha256']}
        plan = manage.migration_plan(entries, applied=full)
        pending = {e['id'] for e in plan if e['id'] not in full}
        # Only unpublished sources may still be pending; once every entry is
        # pinned this set is empty and the plan is a true no-op.
        self.assertEqual(pending, {e['id'] for e in entries if e['sha256'] is None})
        again = manage.validate_migration_history(entries, [], self.ledger_rows(full))
        self.assertEqual(again, full)
        # A historical-only ledger must not acquire V2 compatibility bridges.
        self.assertNotIn('compat:m1_pre_v2_0016',
                         [e['id'] for e in manage.migration_plan(entries, 'm1')])

    def test_legacy_partial_tail_with_v2_is_rejected_not_repaired(self):
        entries = self.entries()
        ledger = self.ledger_rows(['common:0001','m1:0002','m1:0003','m1:0004','m1:0005','v2:0002'])
        with self.assertRaisesRegex(ValueError, 'm1:0006'):
            manage.validate_migration_history(entries, [], ledger)

    def test_current_m1_completes_before_v2_but_never_late_on_converged_history(self):
        entries = self.entries()
        m1 = ['common:0001'] + ['m1:%04d' % n for n in range(2, 7)]
        self.assertEqual([e['id'] for e in manage.migration_plan(entries, 'm1')], m1)
        for end in (4, 5, 6):
            applied = set(m1[:end])
            plan = [e['id'] for e in manage.migration_plan(entries, applied=applied)]
            self.assertEqual(plan[:3], ['common:0001', 'm1:0005', 'm1:0006'])
            self.assertLess(plan.index('compat:m1_pre_v2_0017'), plan.index('v2:0017'))
            self.assertEqual(plan[-1], 'v2:0021')
        old = set(m1[:4]) | {'v2:%04d' % n for n in range(2, 20)} | {'compat:m1_pre_v2_0016'}
        manage.validate_migration_history(entries, [], self.ledger_rows(old))
        plan = [e['id'] for e in manage.migration_plan(entries, applied=old)]
        self.assertFalse(any(i.startswith('m1:') for i in plan))
        # The old checkpoint converged without m1:0005/0006, so the additive
        # reconciliation bridge must still be selected; the historical DDL is not.
        self.assertIn('compat:m1_pre_v2_0017', plan)
        self.assertLess(plan.index('compat:m1_pre_v2_0017'), plan.index('v2:0017'))
        self.assertEqual(plan[-1], 'v2:0021')

    def ledger_rows(self, ids):
        known = {e['id']: e for e in self.entries()}
        return [(i, Path(known[i]['path']).name, known[i]['sha256'], 'APPLIED') for i in sorted(ids)]

    def test_m1_is_only_original_chain_and_v2_never_replays_it(self):
        entries = manage.load_migration_manifest(verify=False)
        self.assertEqual([e['id'] for e in manage.migration_plan(entries, 'm1')],
                         ['common:0001'] + ['m1:%04d' % n for n in range(2, 7)])
        clean = manage.migration_plan(entries, 'v2')
        self.assertEqual([e['id'] for e in clean], ['common:0001'] + ['v2:%04d' % n for n in range(2, 17)]
                         + ['compat:m1_pre_v2_0017'] + ['v2:%04d' % n for n in range(17, 22)])
        self.assertEqual([e['id'] for e in manage.migration_plan(entries, 'v2', through='0001')], ['common:0001'])

    def entries(self):
        return manage.load_migration_manifest(verify=False)

    def rows(self, ids):
        known = {e['id']: e for e in self.entries()}
        return [(i.split(':')[-1], Path(known[i]['path']).name, known[i]['sha256'], 'APPLIED') for i in ids]

    def test_adopts_exact_old_rows_and_rejects_filename_drift(self):
        rows = self.rows(['common:0001', 'v2:0002'])
        self.assertEqual(manage.validate_migration_history(self.entries(), rows, []), {'common:0001', 'v2:0002'})
        for column, value in [(0, '9999'), (1, '0002_unrecognized.sql'), (2, '0' * 64)]:
            bad = list(rows[1]); bad[column] = value
            with self.assertRaises(ValueError):
                manage.validate_migration_history(self.entries(), [rows[0], tuple(bad)], [])

    def test_m1_upgrade_order_and_downgrade_block(self):
        applied = manage.validate_migration_history(self.entries(), self.rows(['common:0001','m1:0002','m1:0003','m1:0004']), [])
        plan = [e['id'] for e in manage.migration_plan(self.entries(), applied=applied)]
        self.assertEqual(plan[-7:], ['v2:0016', 'compat:m1_pre_v2_0017', 'v2:0017', 'v2:0018', 'v2:0019', 'v2:0020', 'v2:0021'])
        self.assertEqual([e['id'] for e in manage.migration_plan(self.entries(), applied={
            'common:0001','m1:0002','m1:0003','m1:0004'})][:4],
            ['common:0001', 'm1:0005', 'm1:0006', 'v2:0002'])
        self.assertFalse({'m1:0002','m1:0003','m1:0004'} & set(plan))
        self.assertEqual([i for i in plan if i.startswith('m1:')], ['m1:0005', 'm1:0006'])
        with self.assertRaises(ValueError):
            manage.migration_plan(self.entries(), 'm1', applied={'common:0001', 'v2:0002'})

    def test_mixed_legacy_history_gaps_and_untracked_schema_rejected(self):
        for ids in [['common:0001','m1:0002','v2:0003'], ['common:0001','v2:0003']]:
            with self.assertRaises(ValueError):
                manage.validate_migration_history(self.entries(), self.rows(ids), [])
        with self.assertRaises(ValueError):
            manage.validate_migration_history(self.entries(), [], [], schema_has_objects=True)

    def test_namespaced_ledger_validated_and_requires_ordered_upgrade(self):
        rows = self.rows(['common:0001','m1:0002'])
        ledger = [('common:0001', *rows[0][1:]), ('m1:0002', *rows[1][1:])]
        self.assertEqual(manage.validate_migration_history(self.entries(), [], ledger), {'common:0001','m1:0002'})
        bad = [('v2:0016', *self.rows(['v2:0016'])[0][1:])]
        with self.assertRaises(ValueError):
            manage.validate_migration_history(self.entries(), [], ledger + bad)

    def test_full_plan_preflight_rejects_pending_bridge_before_any_apply(self):
        entries = [dict(e, sha256=None) if e['id']=='v2:0017' else e for e in self.entries()]
        manage.preflight_migration_plan(manage.migration_plan(entries, 'v2', through='0001'))
        with self.assertRaises(ValueError):
            manage.preflight_migration_plan(manage.migration_plan(entries))

    def test_runner_preflights_before_ddl_and_rejects_late_history_drift(self):
        conn = RecordingConnection(self.rows(['common:0001', 'v2:0002']) + [('0099','unknown.sql','a'*64,'APPLIED')])
        with patch.object(manage, 'assert_container'), patch.object(manage, 'connect', return_value=conn):
            with self.assertRaises(ValueError):
                manage.migrate('test', through='0001')
        self.assertFalse(any(q.lstrip().startswith(('CREATE','INSERT','ALTER','REVOKE','GRANT')) for q, _ in conn.calls))

    def test_runner_pending_final_bridge_does_not_apply_baseline(self):
        conn = RecordingConnection()
        entries = [dict(e, sha256=None) if e['id']=='v2:0017' else e for e in self.entries()]
        with patch.object(manage, 'load_migration_manifest', return_value=entries), \
             patch.object(manage, 'assert_container'), patch.object(manage, 'connect', return_value=conn):
            with self.assertRaises(ValueError):
                manage.migrate('test')
        self.assertFalse(any(q.lstrip().startswith(('CREATE','INSERT','ALTER','REVOKE','GRANT')) for q, _ in conn.calls))

    def test_runner_adopts_without_mutating_old_history(self):
        conn = RecordingConnection(self.rows(['common:0001']))
        with patch.object(manage, 'assert_container'), patch.object(manage, 'connect', return_value=conn):
            manage.migrate('test', through='0001', lineage='m1')
        writes = [(q,p) for q,p in conn.calls if 'INSERT INTO ma_migrations.lineage_history' in q]
        self.assertEqual(writes[0][1][:3], ('common:0001', '0001_m1_identity.sql', manage.BASELINE_SHA256))
        self.assertFalse(any('UPDATE ma_migrations.history' in q or 'INSERT INTO ma_migrations.history' in q for q,_ in conn.calls))

    def test_upgrade_quarantines_before_ddl_and_security_failure_never_opens(self):
        rows = self.rows(['common:0001','m1:0002','m1:0003','m1:0004'])
        conn = RecordingConnection(rows)
        events = []
        original = conn.execute
        def execute(query, *args, **kwargs):
            if str(query).startswith('CREATE'): events.append('ddl')
            return original(query, *args, **kwargs)
        conn.execute = execute
        entries = [dict(e, sha256=e['sha256'] or '1'*64) for e in self.entries()]
        plan = manage.migration_plan(entries, applied={ 'common:0001','m1:0002','m1:0003','m1:0004'})
        with patch.object(manage, 'load_migration_manifest', return_value=entries), \
             patch.object(manage, 'assert_container'), patch.object(manage, 'connect', return_value=conn), \
             patch.object(manage, 'preflight_migration_plan', return_value={e['id']: '-- buffered source' for e in plan}), \
             patch.object(manage, 'quarantine_marker') as marker, patch.object(manage, 'private_write'), \
             patch.object(manage, 'quarantine', side_effect=lambda d: events.append('quarantine')), \
             patch.object(manage, 'verify_lineage_security', side_effect=ValueError('ACL unsafe')) as verify, \
             patch.object(manage, 'open_after_restore') as reopen:
            marker.return_value.exists.return_value = False
            with self.assertRaisesRegex(ValueError, 'ACL unsafe'):
                manage.migrate('test')
            verify.assert_called_once_with('test')
            reopen.assert_not_called()
        self.assertLess(events.index('quarantine'), events.index('ddl'))
        new_rows = [p for q,p in conn.calls if 'INSERT INTO ma_migrations.history(' in q]
        # A 0004 checkpoint may finish historical M1 before V2; nothing else may.
        self.assertEqual([p[0] for p in new_rows][:2], ['m1:0005', 'm1:0006'])
        self.assertTrue(all(p[0].startswith(('m1:0005', 'm1:0006', 'v2:', 'compat:')) for p in new_rows))
        upgrade_rows = [(p[0],p[1],p[2],'APPLIED') for p in new_rows]
        manage.validate_migration_history(entries, rows + upgrade_rows, [])

    def test_manifest_duplicate_and_source_drift_fail(self):
        entries = self.entries()
        with patch.object(manage.json, 'loads', return_value={'migrations': entries + [entries[0]]}):
            with self.assertRaisesRegex(ValueError, 'Duplicate'):
                manage.load_migration_manifest(verify=False)
        with patch.object(manage, 'sha256', return_value='0'*64):
            with self.assertRaisesRegex(ValueError, 'drift'):
                manage.load_migration_manifest()

    def test_failed_legacy_retry_preserves_old_row_and_allows_success_projection(self):
        baseline, second = self.rows(['common:0001','v2:0002'])
        failed = (*second[:3], 'FAILED')
        retried = ('v2:0002', *second[1:])
        self.assertEqual(manage.validate_migration_history(self.entries(), [baseline,failed,retried], []),
                         {'common:0001','v2:0002'})

    def test_completed_resumed_upgrade_verifies_then_reopens(self):
        entries = [dict(e, sha256=e['sha256'] or '1'*64) for e in self.entries()]
        ids = ['common:0001'] + ['m1:%04d' % n for n in range(2, 7)] + [e['id'] for e in manage.migration_plan(entries)[1:]]
        ids = list(dict.fromkeys(ids))
        ids.insert(ids.index('v2:0016'), 'compat:m1_pre_v2_0016')
        ids = list(dict.fromkeys(ids))
        known = {e['id']:e for e in entries}
        ledger = [(i,Path(known[i]['path']).name,known[i]['sha256'],'APPLIED') for i in ids]
        conn = RecordingConnection(ledger=ledger)
        events = []
        with patch.object(manage, 'load_migration_manifest', return_value=entries), \
             patch.object(manage, 'assert_container'), patch.object(manage, 'connect', return_value=conn), \
             patch.object(manage, 'preflight_migration_plan', return_value={}), \
             patch.object(manage, 'quarantine_marker') as marker, patch.object(manage, 'private_write'), \
             patch.object(manage, 'quarantine', side_effect=lambda d: events.append('quarantine')), \
             patch.object(manage, 'verify_lineage_security', side_effect=lambda d: events.append('verify')), \
             patch.object(manage, 'open_after_restore', side_effect=lambda d: events.append('open')):
            marker.return_value.exists.return_value = True
            marker.return_value.read_text.return_value = '{"state":"LINEAGE_UPGRADE"}'
            manage.migrate('test')
        self.assertEqual(events, ['quarantine','verify','open'])

    def test_security_gate_rejects_each_acl_failure(self):
        from unittest.mock import MagicMock
        for responses in [[['public execute']], [[], ['privileged runtime']], [[], [], ['public create']]]:
            conn = MagicMock()
            conn.__enter__.return_value = conn
            conn.execute.return_value.fetchall.side_effect = responses
            with patch.object(manage, 'verify') as rls, patch.object(manage, 'connect', return_value=conn):
                with self.assertRaises(ValueError):
                    manage.verify_lineage_security('test')
                rls.assert_called_once_with('test')

    def test_cli_selects_lineage_and_preserves_through(self):
        for flags, expected in [([], ('test',None,'v2')), (['--lineage','m1','--through','0001'], ('test','0001','m1'))]:
            with patch.object(manage.sys, 'argv', ['manage.py','migrate'] + flags), patch.object(manage, 'migrate') as migrate:
                manage.main()
                migrate.assert_called_once_with(*expected)

    def test_restore_cli_propagates_lineage(self):
        with patch.object(manage.sys,'argv',['manage.py','restore','--lineage','m1','--file','historical.dump']), patch.object(manage,'restore') as restore:
            manage.main()
        restore.assert_called_once_with('test',Path('historical.dump'),False,'m1')

    def test_partial_m1_upgrade_rejected_before_ddl(self):
        for tail in (['m1:0002'], ['m1:0002','m1:0003']):
            conn=RecordingConnection(self.rows(['common:0001']+tail))
            with patch.object(manage,'assert_container'), patch.object(manage,'connect',return_value=conn), \
                 patch.object(manage,'quarantine'), patch.object(manage,'private_write'), \
                 patch.object(manage,'verify_lineage_security'), patch.object(manage,'open_after_restore'):
                with self.assertRaisesRegex(ValueError,'Complete historical M1'):
                    manage.migrate('test')
            self.assertFalse(any(q.lstrip().startswith(('CREATE','INSERT','ALTER','REVOKE','GRANT')) for q,_ in conn.calls))


if __name__ == '__main__':
    unittest.main()
