"""Direct unittest invocation must be as isolated as the lifecycle wrapper."""
import os
import unittest
from unittest.mock import patch
import fixtures


class FixtureTargetSafetyTests(unittest.TestCase):
    def test_ci_ports_require_the_full_opt_in_and_exact_database(self):
        ci = {'MA_LOCAL_DB_CI':'1','GITHUB_ACTIONS':'true','MA_CI_SYNTHETIC':'1'}
        dsn = 'host=127.0.0.1 port=5432 dbname=madalasa_alarka_test'
        with patch.dict(os.environ, ci, clear=False):
            fixtures._CI_VERIFIED.clear()
            self.assertEqual(fixtures.validate_test_dsn(dsn), dsn)
            for bad in ('host=127.0.0.1 port=5432 dbname=madalasa_alarka_dev',
                        'host=db.example.com port=5432 dbname=madalasa_alarka_test',
                        'host=127.0.0.1 port=5433 dbname=madalasa_alarka_test',
                        'host=127.0.0.1 port=5432 dbname=madalasa_alarka_test service=other'):
                with self.subTest(bad=bad), self.assertRaises(ValueError):
                    fixtures.validate_test_dsn(bad)
            # Additive only: the two existing local ports still validate unchanged.
            for port in ('15432','15433'):
                keep = f'host=127.0.0.1 port={port} dbname=madalasa_alarka_test'
                self.assertEqual(fixtures.validate_test_dsn(keep), keep)
        with patch.dict(os.environ, {}, clear=False):
            for name in ('MA_LOCAL_DB_CI','GITHUB_ACTIONS','MA_CI_SYNTHETIC'):
                os.environ.pop(name, None)
            with self.assertRaises(ValueError): fixtures.validate_test_dsn(dsn)

    def test_partial_ci_opt_in_fails_closed(self):
        for partial in ({'MA_LOCAL_DB_CI':'1'}, {'MA_LOCAL_DB_CI':'1','MA_CI_SYNTHETIC':'1'}):
            with patch.dict(os.environ, partial, clear=True):
                with self.assertRaises(ValueError): fixtures.validate_test_dsn(
                    'host=127.0.0.1 port=5432 dbname=madalasa_alarka_test')

    def test_pr11_fixture_checks_labels_before_connection(self):
        dsn = 'host=127.0.0.1 port=15434 dbname=madalasa_alarka_test'
        env = {'MA_TEST_DSN':dsn,'MA_LOCAL_DB_DIR':'.local-db/pr11-runtime'}
        with patch.dict(os.environ,env), patch.object(fixtures,'ci_mode',return_value=False), \
             patch.object(fixtures.psycopg,'connect') as connect:
            with patch('tools.database.manage.assert_container',side_effect=ValueError('wrong checkout')):
                with self.assertRaises(ValueError): fixtures.admin_connection()
            connect.assert_not_called()
            with patch('tools.database.manage.assert_container') as guard:
                # The alternate-config guard compares the live directory with the
                # one resolved at import, so pin both consistently here.
                pr11 = fixtures.ROOT / '.local-db/pr11-runtime'
                with patch('tools.database.manage.configuration',return_value={'test':{'container':'madalasa-pr11-test-postgres'}}), \
                     patch('tools.database.manage.LOCAL', pr11), \
                     patch('tools.database.manage.ci_mode', return_value=False):
                    self.assertEqual(fixtures._dsn('admin'),dsn)
                guard.assert_called_once_with('test')

    def test_pr11_port_requires_exact_explicit_config(self):
        dsn = 'host=127.0.0.1 port=15434 dbname=madalasa_alarka_test'
        for value in ('', '.local-db/other', '/etc'):
            with patch.dict(os.environ,{'MA_TEST_DSN':dsn,'MA_LOCAL_DB_DIR':value}), \
                 patch.object(fixtures,'ci_mode',return_value=False):
                with self.assertRaises(ValueError): fixtures._dsn('admin')

    def test_default_ports_still_require_exact_loopback_test_db(self):
        with patch.dict(os.environ,{'MA_LOCAL_DB_DIR':''}), \
             patch.object(fixtures,'ci_mode',return_value=False):
            for port in ('15432','15433'):
                dsn = f'host=127.0.0.1 port={port} dbname=madalasa_alarka_test'
                self.assertEqual(fixtures.validate_test_dsn(dsn),dsn)

    def test_direct_fixture_connections_reject_non_test_targets_before_connect(self):
        for dsn in (
            'host=remote.invalid port=15432 dbname=madalasa_alarka_test',
            'host=127.0.0.1 port=5432 dbname=madalasa_alarka_test',
            'host=127.0.0.1 port=15432 dbname=madalasa_alarka_dev',
            'host=127.0.0.1 hostaddr=192.0.2.1 port=15432 dbname=madalasa_alarka_test',
        ):
            with self.subTest(dsn=dsn), patch.dict(os.environ, {'MA_TEST_DSN':dsn}), \
                 patch.object(fixtures,'ci_mode',return_value=False):
                with self.assertRaises(ValueError):fixtures._dsn('admin')
