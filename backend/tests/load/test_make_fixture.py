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
        target = 'host=127.0.0.1 port=15433 dbname=madalasa_alarka_test password=synthetic-fixture'
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
            inspect.assert_called_once_with('madalasa-memory-test-postgres', '15433')
            connect.assert_not_called()

    def test_disabled_opt_in_never_writes(self):
        from unittest.mock import MagicMock
        connection = MagicMock()
        connection.execute.return_value.fetchone.return_value = (False,)
        with self.assertRaises(ValueError):
            fixture.require_synthetic_opt_in(connection)
        self.assertEqual(connection.execute.call_count, 1)
        self.assertTrue(connection.execute.call_args.args[0].startswith('SELECT'))


if __name__ == '__main__':
    unittest.main()
