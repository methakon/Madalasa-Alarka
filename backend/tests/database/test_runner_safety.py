"""Safety and migration-runner tests; do not require a running database."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

from unittest.mock import patch
import json

SPEC = importlib.util.spec_from_file_location('database_manage', Path(__file__).parents[3] / 'tools/database/manage.py')
manage = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(manage)


class RunnerSafety(unittest.TestCase):
    def test_ci_mode_requires_every_explicit_flag(self):
        ci = {'MA_LOCAL_DB_CI':'1','GITHUB_ACTIONS':'true','MA_CI_SYNTHETIC':'1'}
        self.assertTrue(manage.ci_mode(ci))
        self.assertFalse(manage.ci_mode({}))
        self.assertFalse(manage.ci_mode({'MA_LOCAL_DB_CI':'0','GITHUB_ACTIONS':'true','MA_CI_SYNTHETIC':'1'}))
        for partial in ({'MA_LOCAL_DB_CI':'1'}, {'MA_LOCAL_DB_CI':'1','GITHUB_ACTIONS':'true'},
                        {'MA_LOCAL_DB_CI':'1','MA_CI_SYNTHETIC':'1'},
                        {'MA_LOCAL_DB_CI':'1','GITHUB_ACTIONS':'1','MA_CI_SYNTHETIC':'1'}):
            with self.assertRaises(ValueError): manage.ci_mode(partial)

    def test_ci_mode_refusals_are_unchanged_and_only_5432_is_added(self):
        ci = {'MA_LOCAL_DB_CI':'1','GITHUB_ACTIONS':'true','MA_CI_SYNTHETIC':'1'}
        good = {'host':'127.0.0.1','port':5432,'dbname':'madalasa_alarka_test'}
        refusals = [
            dict(good, host='db.example.com'),
            dict(good, host='192.0.2.1'),
            dict(good, hostaddr='192.0.2.1'),
            dict(good, dbname='madalasa_alarka_dev'),
            dict(good, dbname='postgres'),
            dict(good, service='madalasa'),
            dict(good, port=5433), dict(good, port=15432),
            dict(good, port=15433), dict(good, port=15434), dict(good, port=0),
        ]
        with patch.dict(manage.os.environ, ci, clear=False):
            manage.validate_target(good)
            for target in refusals:
                with self.subTest(target=target), self.assertRaises(ValueError):
                    manage.validate_target(target)
        with patch.dict(manage.os.environ, {}, clear=False):
            manage.os.environ.pop('MA_LOCAL_DB_CI', None)
            with self.assertRaises(ValueError): manage.validate_target(good)

    def test_ci_config_requires_absolute_private_path(self):
        ci = {'MA_LOCAL_DB_CI':'1','GITHUB_ACTIONS':'true','MA_CI_SYNTHETIC':'1'}
        with patch.dict(manage.os.environ, ci, clear=False):
            manage.os.environ.pop('MA_LOCAL_DB_CONFIG', None)
            with self.assertRaisesRegex(ValueError, 'MA_LOCAL_DB_CONFIG'): manage.configuration()
            manage.os.environ['MA_LOCAL_DB_CONFIG'] = 'relative/connection.json'
            with self.assertRaisesRegex(ValueError, 'absolute'): manage.configuration()
            with tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / 'connection.json'
                path.write_text('{"test":{"container":"none"}}')
                path.chmod(0o644)
                manage.os.environ['MA_LOCAL_DB_CONFIG'] = str(path)
                with self.assertRaisesRegex(ValueError, '0600'): manage.configuration()
                path.chmod(0o600)
                self.assertEqual(manage.configuration(), {'test':{'container':'none'}})

    def test_ci_guard_is_sql_identity_not_docker(self):
        from unittest.mock import MagicMock
        ci = {'MA_LOCAL_DB_CI':'1','GITHUB_ACTIONS':'true','MA_CI_SYNTHETIC':'1'}
        dsn = 'host=127.0.0.1 port=5432 dbname=madalasa_alarka_test user=postgres'
        cfg = {'test': {'admin': dsn, 'migration': dsn.replace('postgres','madalasa_migrator')}}
        good = ('madalasa_alarka_test','postgres','16.3 (Ubuntu 16.3-1)','postgres',True)
        def connection(row):
            conn = MagicMock()
            conn.__enter__.return_value = conn
            conn.execute.return_value.fetchone.return_value = row
            return conn
        cases = {
            'wrong database': ('madalasa_alarka_dev','postgres','16.3','postgres',True),
            'wrong login': ('madalasa_alarka_test','someone','16.3','postgres',True),
            'wrong version': ('madalasa_alarka_test','postgres','15.5','postgres',True),
            'wrong owner': ('madalasa_alarka_test','postgres','16.3','other_owner',True),
            'no postgis': ('madalasa_alarka_test','postgres','16.3','postgres',False),
        }
        for label, row in cases.items():
            with self.subTest(label), patch.dict(manage.os.environ, ci, clear=False), \
                 patch.object(manage,'configuration',return_value=cfg), \
                 patch.object(manage.psycopg,'connect',return_value=connection(row)), \
                 patch.object(manage.subprocess,'run') as docker:
                with self.assertRaises(ValueError): manage.assert_container('test')
                docker.assert_not_called()
        with patch.dict(manage.os.environ, ci, clear=False), \
             patch.object(manage,'configuration',return_value=cfg), \
             patch.object(manage.psycopg,'connect',return_value=connection(good)), \
             patch.object(manage.subprocess,'run') as docker:
            manage.assert_container('test')
            docker.assert_not_called()
            with self.assertRaises(ValueError): manage.container_for('test')
            with self.assertRaises(ValueError): manage.init()

    def test_ci_config_is_operator_safe_and_writes_private_file(self):
        ci = {'MA_LOCAL_DB_CI':'1','GITHUB_ACTIONS':'true','MA_CI_SYNTHETIC':'1'}
        with patch.dict(manage.os.environ, {}, clear=True):
            for name in ('MA_LOCAL_DB_CI',):
                manage.os.environ.pop(name, None)
            with self.assertRaises(ValueError): manage.ci_config()
        with patch.dict(manage.os.environ, dict(ci, MA_LOCAL_DB_CONFIG='relative.json'), clear=True):
            with self.assertRaisesRegex(ValueError, 'absolute'): manage.ci_config()
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / 'connection.json'
            inside = str(manage.DEFAULT_LOCAL / 'connection.json')
            env = dict(ci, MA_LOCAL_DB_CONFIG=inside, MA_CI_ADMIN_PASSWORD='x')
            with patch.dict(manage.os.environ, env, clear=True):
                with self.assertRaisesRegex(ValueError, 'local .local-db'): manage.ci_config()
            env = dict(ci, MA_LOCAL_DB_CONFIG=str(target))
            with patch.dict(manage.os.environ, env, clear=True):
                with self.assertRaisesRegex(ValueError, 'MA_CI_ADMIN_PASSWORD'): manage.ci_config()
            env = dict(ci, MA_LOCAL_DB_CONFIG=str(target),
                       MA_CI_ADMIN_DSN='host=127.0.0.1 port=5433 dbname=madalasa_alarka_test user=postgres')
            with patch.dict(manage.os.environ, env, clear=True):
                with self.assertRaises(ValueError): manage.ci_config()
            env = dict(ci, MA_LOCAL_DB_CONFIG=str(target), MA_CI_ADMIN_PASSWORD='synthetic-not-real')
            with patch.dict(manage.os.environ, env, clear=True):
                self.assertEqual(manage.ci_config(), target)
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            written = json.loads(target.read_text())['test']
            self.assertEqual(set(written), {'admin','migration','runtime','auth','billing'})
            for role, dsn in written.items():
                values = manage.conninfo_to_dict(dsn)
                self.assertEqual(values['port'], '5432')
                self.assertEqual(values['dbname'], 'madalasa_alarka_test')
                self.assertEqual(values['user'], 'postgres' if role == 'admin' else manage.ROLES[role][0])
            self.assertNotEqual(manage.conninfo_to_dict(written['admin'])['password'],
                                manage.conninfo_to_dict(written['runtime'])['password'])

    def test_private_pr11_config_accepts_only_owned_test_container_and_port(self):
        with patch.object(manage, 'ci_mode', return_value=False):
            self._pr11_config_checks()

    def _pr11_config_checks(self):
        target = {'host':'127.0.0.1','port':15434,'dbname':'madalasa_alarka_test'}
        # Under the default configuration 15434 is never a valid target, no matter
        # what MA_LOCAL_DB_DIR the suite inherited.
        with patch.object(manage, 'LOCAL', manage.DEFAULT_LOCAL):
            with self.assertRaises(ValueError):
                manage.validate_target(target)
        local = manage.ROOT / '.local-db/pr11-runtime'
        cfg = {'test': {'container':'madalasa-pr11-test-postgres',
                        'migration':manage.make_conninfo(**target,user='madalasa_migrator')}}
        item = {'Config':{'Labels':{'com.madalasa.local-db':'synthetic',
                                  'com.madalasa.local-db-root':str(manage.ROOT)}},
                'HostConfig':{'PortBindings':{'5432/tcp':[{'HostIp':'127.0.0.1','HostPort':'15434'}]}}}
        from types import SimpleNamespace
        with patch.object(manage,'LOCAL',local), patch.object(manage,'configuration',return_value=cfg), \
             patch.object(manage.subprocess,'run',return_value=SimpleNamespace(stdout=json.dumps([item]))) as run:
            manage.validate_target(target)
            manage.assert_container('test')
            self.assertEqual(manage.container_for('test'), 'madalasa-pr11-test-postgres')
            self.assertEqual(manage.quarantine_marker('test').parent,local)
            for label in ('com.madalasa.local-db','com.madalasa.local-db-root'):
                bad = json.loads(json.dumps(item)); bad['Config']['Labels'][label]='wrong'
                run.return_value.stdout=json.dumps([bad])
                with self.assertRaises(ValueError): manage.assert_container('test')
            run.return_value.stdout=json.dumps([item])
            cfg['test']['migration']=manage.make_conninfo(**dict(target,port=15433))
            with self.assertRaises(ValueError): manage.assert_container('test')
        with patch.object(manage,'LOCAL',local):
            with self.assertRaises(ValueError): manage.validate_target(dict(target,dbname='madalasa_alarka_dev'))

    def test_config_override_is_bounded_and_default_preserved(self):
        self.assertEqual(manage.local_directory({}), manage.ROOT / '.local-db')
        self.assertEqual(manage.local_directory({'MA_LOCAL_DB_DIR':'.local-db/pr11-runtime'}),
                         manage.ROOT / '.local-db/pr11-runtime')
        for value in ('/etc', '.', '.local-db/../elsewhere'):
            with self.assertRaises(ValueError): manage.local_directory({'MA_LOCAL_DB_DIR':value})

    def test_alternate_config_never_starts_default_compose(self):
        with patch.object(manage,'LOCAL',manage.ROOT / '.local-db/pr11-runtime'), \
             patch.object(manage.subprocess,'run') as run:
            for action in (manage.init,manage.start,manage.start_memory_test):
                with self.assertRaises(ValueError): action()
            run.assert_not_called()

    def test_only_named_loopback_databases_allowed(self):
        for host in ['db.example.com', '192.0.2.1', '/var/run/postgresql']:
            with self.assertRaises(ValueError):
                manage.validate_target({'host': host, 'port': 15432, 'dbname': 'madalasa_alarka_test'})
        for db in ['postgres', 'production', 'madalasa_alarka_dev; DROP DATABASE postgres']:
            with self.assertRaises(ValueError):
                manage.validate_target({'host': '127.0.0.1', 'port': 15432, 'dbname': db})
        # Default-port semantics are asserted against the default configuration,
        # independent of whatever MA_LOCAL_DB_DIR the running suite inherited.
        with patch.object(manage, 'LOCAL', manage.DEFAULT_LOCAL), \
             patch.object(manage, 'ci_mode', return_value=False):
            manage.validate_target({'host': '127.0.0.1', 'port': 15432, 'dbname': 'madalasa_alarka_test'})

    def test_historical_transaction_removed_not_function_body(self):
        sql = '-- historical\nBEGIN;\nDO $x$\nBEGIN\nNULL;\nEND $x$;\nCOMMIT;\n-- note\n'
        result = manage.transaction_body(sql)
        self.assertNotIn('\nCOMMIT;', result)
        self.assertNotIn('\nBEGIN;', result)
        self.assertIn('\nBEGIN\nNULL;', result)

    def test_memory_port_is_only_for_the_exact_test_database(self):
        with patch.object(manage, 'LOCAL', manage.DEFAULT_LOCAL), \
             patch.object(manage, 'ci_mode', return_value=False):
            manage.validate_target({'host':'127.0.0.1','port':15433,'dbname':'madalasa_alarka_test'})
            for target in (
                {'host':'127.0.0.1','hostaddr':'192.0.2.1','port':15433,'dbname':'madalasa_alarka_test'},
                {'host':'127.0.0.1','port':15433,'dbname':'madalasa_alarka_dev'},
            ):
                with self.assertRaises(ValueError):manage.validate_target(target)

    def test_unsafe_restore_path_rejected(self):
        with self.assertRaises(ValueError):
            manage.safe_backup_path(Path('/etc/passwd'))

    def test_original_migration_hash_is_pinned(self):
        self.assertEqual(manage.BASELINE_SHA256, manage.sha256(manage.MIGRATIONS / '0001_m1_identity.sql'))


if __name__ == '__main__':
    unittest.main()
