"""Hermetic tests: no psycopg import, Docker, database, or network needed."""
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location('queued_load', Path(__file__).with_name('load.py'))
load = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(load)


class MetricTests(unittest.TestCase):
    def test_percentiles(self):
        self.assertEqual(load.percentile([5], 99), 5)
        self.assertEqual(load.percentile([4, 1, 3, 2], 50), 2.5)
        self.assertAlmostEqual(load.percentile(list(range(1, 101)), 95), 95.05)
        self.assertIsNone(load.percentile([], 50))
        for q in (-1, 101):
            with self.assertRaises(ValueError):
                load.percentile([1], q)


class GuardTests(unittest.TestCase):
    def test_target_requires_explicit_exact_loopback_identity(self):
        good = dict(host='127.0.0.1', port='15433', dbname='madalasa_alarka_test', user='madalasa_dev')
        load.validate_target(good)
        for changes in ({'host': 'remote'}, {'hostaddr': 'remote'}, {'port': '5432'},
                        {'dbname': 'madalasa_alarka_dev'}, {'user': 'postgres'},
                        {'service': 'anything'}, {'options': '-c role=postgres'}, {'passfile': 'x'}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                load.validate_target(dict(good, **changes))
        for field in good:
            bad = dict(good)
            del bad[field]
            with self.subTest(missing=field), self.assertRaises(ValueError):
                load.validate_target(bad)

    def test_bounds(self):
        load.validate_bounds(108, 8, [1, 8, 32, 108], 10, 1, 10)
        for args in ((109,8,[1],10,1,10), (108,0,[1],10,1,10),
                     (108,8,[109],10,1,10), (108,8,[8,1],10,1,10),
                     (108,8,[1],0,1,10), (108,8,[1],10,501,10),
                     (108,8,[1],10,1,0)):
            with self.subTest(args=args), self.assertRaises(ValueError):
                load.validate_bounds(*args)

    def test_missing_chain_refuses_without_fixture_or_database(self):
        import tempfile
        with tempfile.TemporaryDirectory(dir=load.HERE) as d:
            with self.assertRaisesRegex(ValueError, '0025.*0027'):
                load.source_chain(Path(d))

    def test_fixture_identity_and_shape(self):
        from uuid import uuid4
        fixture = {'synthetic_only': True, 'runtime_dsn': 'private', 'proof_dsn': 'private',
                   'device_guc': 'ap.device_credential_sha256',
                   'devices': [{'device_id': str(uuid4()), 'child_id': str(uuid4()),
                                'credential': 'invented-test-only', 'sequence_start': 1}]}
        load.validate_fixture(fixture, 1)
        for bad in (dict(fixture, synthetic_only=False), dict(fixture, devices=[]),
                    dict(fixture, device_guc='ap.session_token'),
                    dict(fixture, devices=fixture['devices'] * 2),
                    dict(fixture, unexpected='raw GPS')):
            with self.assertRaises(ValueError):
                load.validate_fixture(bad, 1)

    def test_container_identity_and_binding(self):
        item = {'State': {'Running': True}, 'Config': {'Labels': {
            'com.madalasa.local-db': 'synthetic', 'com.madalasa.local-db-root': str(load.ROOT)}},
            'HostConfig': {'PortBindings': {'5432/tcp': [{'HostIp': '127.0.0.1', 'HostPort': '15434'}]}},
            'Mounts': []}
        load.validate_container(item, '15434', '127.0.0.1')
        # The other loopback family can host an unrelated PostgreSQL instance.
        with self.assertRaises(ValueError):
            load.validate_container(item, '15434', '::1')
        item['HostConfig']['PortBindings']['5432/tcp'][0]['HostIp'] = '::1'
        load.validate_container(item, '15434', '::1')
        with self.assertRaises(ValueError):
            load.validate_container(item, '15434', '127.0.0.1')
        item['HostConfig']['PortBindings']['5432/tcp'][0]['HostIp'] = '0.0.0.0'
        with self.assertRaises(ValueError):
            load.validate_container(item, '15434', '127.0.0.1')

    def test_events_are_generated_only_and_unique(self):
        a, b = load.events(3, 50), load.events(3, 53)
        self.assertEqual([e['sequence'] for e in a], [50, 51, 52])
        self.assertEqual(a[0]['latitude'], 0.125)
        self.assertEqual(a[0]['provider'], 'SYNTHETIC')
        self.assertTrue(set(e['event_id'] for e in a).isdisjoint(e['event_id'] for e in b))

    def test_stage_uses_bounded_pool_and_actual_result_counters(self):
        from contextlib import contextmanager
        from types import SimpleNamespace, ModuleType
        from unittest.mock import patch
        import queue
        import sys
        import time
        class Conn:
            def __init__(self): self.device = None; self.credential = None
            @contextmanager
            def transaction(self): yield
            def execute(self, sql, params=None):
                if 'set_config' in sql:
                    self.credential = params[1]
                    return SimpleNamespace(fetchone=lambda: (None,))
                if 'ctx_device' in sql:
                    import hashlib
                    resolved = next((d for d in ('device-a', 'device-b') if hashlib.sha256(d.encode()).hexdigest() == self.credential), None)
                    return SimpleNamespace(fetchone=lambda: (resolved, None))
                return SimpleNamespace(fetchone=lambda: (params[1], len(params[2]), 0, False))
            def rollback(self): pass
        pool = queue.Queue(maxsize=1)
        pool.put(Conn())
        args = SimpleNamespace(batches_per_device=2, batch_size=1, interval_ms=0)
        fake_json = ModuleType('psycopg.types.json')
        fake_json.Jsonb = lambda value: value
        fixture = {'device_guc': 'ap.device_credential_sha256', 'devices': [
            {'device_id': 'device-a', 'credential': 'device-a'},
            {'device_id': 'device-b', 'credential': 'device-b'}]}
        with patch.dict(sys.modules, {'psycopg.types.json': fake_json}):
            result = load.stage(fixture, pool, 2, args, [1, 1], time.monotonic() + 1)
        self.assertEqual(result['attempts'], 4)
        self.assertEqual(result['successes'], 4)
        self.assertEqual(result['events_committed'], 4)
        self.assertEqual(len(set(result['_private_batch_ids'])), 4)
        self.assertEqual(result['errors'], {})
        self.assertEqual(pool.qsize(), 1)
        self.assertGreaterEqual(result['success_latency_ms']['p99'], result['success_latency_ms']['p50'])

    def test_bind_hashes_bearer_clears_session_and_checks_device(self):
        class Result:
            def fetchone(self): return ('wrong-device',)
        class Connection:
            calls = []
            def execute(self, sql, params=None):
                self.calls.append((sql, params))
                return Result()
        conn = Connection()
        with self.assertRaises(ValueError):
            load.bind_device(conn, 'ap.device_credential_sha256', {'device_id': 'wanted', 'credential': 'never-output'})
        import hashlib
        self.assertEqual(conn.calls[0][1], ('ap.device_credential_sha256', hashlib.sha256(b'never-output').hexdigest()))
        self.assertIn("ap.session_token", conn.calls[0][0])
        self.assertIn('ctx_device', conn.calls[1][0])

    def test_container_sample_parser(self):
        sample = load.parse_container_sample('usage_usec 1000\nuser_usec 700\nSYSTEM_MEMORY\n2048\nNETWORK\neth0: 10 0 0 0 0 0 0 0 20 0 0 0 0 0 0 0\nRSS\nVmRSS: 42 kB\n')
        self.assertEqual(sample['cpu_usage_usec'], 1000)
        self.assertEqual(sample['memory_current_bytes'], 2048)
        self.assertEqual(sample['network_rx_bytes'], 10)
        self.assertEqual(sample['network_tx_bytes'], 20)
        self.assertEqual(sample['postgres_pid1_rss_bytes'], 43008)

    def test_private_input_rejects_public_or_symlink(self):
        import tempfile
        with tempfile.TemporaryDirectory(dir=load.HERE) as d:
            path = Path(d) / 'fixture.json'
            path.write_text('{}')
            path.chmod(0o644)
            with self.assertRaises(ValueError):
                load.read_private(path)
            path.chmod(0o600)
            self.assertEqual(load.read_private(path), {})
            link = Path(d) / 'link'
            link.symlink_to(path)
            with self.assertRaises(ValueError):
                load.read_private(link)


if __name__ == '__main__':
    unittest.main()
