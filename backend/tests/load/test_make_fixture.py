"""Fixture safety regressions: forbidden inputs never reach PostgreSQL."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import make_fixture as fixture


class FixtureGuardTests(unittest.TestCase):
    def config(self):
        target = 'host=127.0.0.1 port=15433 dbname=madalasa_alarka_test password=test-only-fixture'
        return {'test': {'admin': target + ' user=postgres',
                         'runtime': target + ' user=madalasa_dev',
                         'migration': target + ' user=madalasa_migrator',
                         'container': 'madalasa-memory-test-postgres'}}

    def invoke(self, config, allow=True):
        with tempfile.TemporaryDirectory(dir=fixture.ROOT / '.local-db') as directory:
            path = Path(directory) / 'connection.json'
            path.write_text(json.dumps(config))
            path.chmod(0o600)
            return fixture.guarded_target(path, allow)

    def test_explicit_disposable_authorization_required(self):
        with patch.object(fixture.psycopg, 'connect') as connect:
            with self.assertRaises(ValueError):
                self.invoke(self.config(), allow=False)
            connect.assert_not_called()

    def test_forbidden_targets_never_connect_or_write(self):
        for replacement in ('host=remote', 'dbname=production', 'dbname=madalasa_alarka_dev',
                            'port=5432', 'user=other_admin', 'service=production',
                            'options=-crole=postgres', 'hostaddr=remote'):
            config = self.config()
            key = replacement.split('=', 1)[0]
            parts = [p for p in config['test']['admin'].split() if not p.startswith(key + '=')]
            config['test']['admin'] = ' '.join(parts + [replacement])
            with self.subTest(replacement=replacement), patch.object(fixture.psycopg, 'connect') as connect:
                with self.assertRaises(ValueError):
                    self.invoke(config)
                connect.assert_not_called()

    def test_ambient_libpq_is_rejected_before_connect(self):
        with patch.dict(os.environ, {'PGSERVICE': 'production'}), patch.object(fixture.psycopg, 'connect') as connect:
            with self.assertRaises(ValueError):
                self.invoke(self.config())
            connect.assert_not_called()

    def test_valid_target_requires_owned_container_before_connect(self):
        with patch.object(fixture.load_guard, 'inspect_container', side_effect=ValueError('wrong owner')) as inspect, \
                patch.object(fixture.psycopg, 'connect') as connect:
            with self.assertRaises(ValueError):
                self.invoke(self.config())
            inspect.assert_called_once_with('madalasa-memory-test-postgres', '15433', '127.0.0.1')
            connect.assert_not_called()

    def test_disabled_opt_in_never_writes(self):
        from unittest.mock import MagicMock
        connection = MagicMock()
        connection.execute.return_value.fetchone.return_value = (False,)
        with self.assertRaises(ValueError):
            fixture.require_synthetic_opt_in(connection)
        self.assertEqual(connection.execute.call_count, 1)
        self.assertTrue(connection.execute.call_args.args[0].startswith('SELECT'))

    def test_repository_application_label_is_removed_from_validated_dsns(self):
        config = self.config()
        for kind in ('admin', 'runtime', 'migration'):
            config['test'][kind] += ' application_name=madalasa-local'
        with patch.object(fixture.load_guard, 'inspect_container'), \
                patch.object(fixture.psycopg, 'connect') as connect:
            checked = self.invoke(config)
            for kind in ('admin', 'runtime', 'migration'):
                self.assertNotIn('application_name', fixture.conninfo_to_dict(checked[kind]))
            connect.assert_not_called()


    def test_main_rejects_opposite_loopback_listener_before_connect(self):
        for target_host, published_host in (('::1', '127.0.0.1'), ('127.0.0.1', '::1')):
            config = self.config()
            for kind in ('admin', 'runtime', 'migration'):
                config['test'][kind] = config['test'][kind].replace('127.0.0.1', target_host)
            item = {'State': {'Running': True}, 'Config': {'Labels': {
                'com.madalasa.local-db': 'synthetic',
                'com.madalasa.local-db-root': str(fixture.ROOT)}}, 'Mounts': [],
                'HostConfig': {'PortBindings': {'5432/tcp': [
                    {'HostIp': published_host, 'HostPort': '15433'}]}}}
            with self.subTest(target=target_host), \
                    tempfile.TemporaryDirectory(dir=fixture.ROOT / '.local-db') as directory:
                path = Path(directory) / 'connection.json'
                path.write_text(json.dumps(config))
                path.chmod(0o600)
                output = Path(directory) / 'fixture.json'
                argv = ['make_fixture.py', '--allow-disposable-db', '--devices', '1',
                        '--connection', str(path), '--output', str(output)]
                with patch('sys.argv', argv), \
                        patch.object(fixture.load_guard, 'docker', return_value=json.dumps([item])), \
                        patch.object(fixture.psycopg, 'connect') as connect:
                    with self.assertRaises(ValueError):
                        fixture.main()
                    connect.assert_not_called()
                    self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
