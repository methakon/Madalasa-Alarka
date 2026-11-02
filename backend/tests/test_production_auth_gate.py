"""Exercise the shell gate with real strings/grep and synthetic byte fixtures."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

GATE = Path(os.environ.get('MA_AUTH_GATE', Path(__file__).resolve().parents[1] /
                          'scripts/check_production_auth.sh'))


class ProductionAuthGateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='ma-marker-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.production = self.root / 'production fixture'
        self.production.write_bytes(b'\x00reject_all\x00healthz\x00')
        self.synthetic = self.root / 'synthetic fixture'
        # Early match followed by output larger than a pipe buffer: grep -q
        # closes its input, strings receives SIGPIPE, old pipefail gate misses it.
        self.synthetic.write_bytes(b'synthetic_test\n' + b'harmless_padding_line\n' * 100000)

    def gate(self, *paths, env=None):
        return subprocess.run(['/bin/bash', str(GATE), *map(str, paths)], env=env,
                              capture_output=True, text=True, timeout=10)

    def test_large_synthetic_fixture_is_rejected(self):
        result = self.gate(self.synthetic)
        self.assertEqual(result.returncode, 1, result.stderr)

    def test_production_fixture_passes(self):
        result = self.gate(self.production)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_real_tool_positive_and_negative_controls(self):
        self.assertEqual(self.gate(self.production, self.synthetic).returncode, 0)
        self.assertNotEqual(self.gate(self.production, self.production).returncode, 0)
        self.assertNotEqual(self.gate(self.synthetic, self.synthetic).returncode, 0)

    def test_invalid_inputs_fail_closed(self):
        for paths in [(), (self.root / 'missing',), (self.root,),
                      (self.production, self.root / 'missing'),
                      (self.production, self.synthetic, self.production)]:
            with self.subTest(paths=paths):
                self.assertEqual(self.gate(*paths).returncode, 2)
        empty = self.root / 'empty'
        empty.touch()
        self.assertEqual(self.gate(empty).returncode, 2)

    def test_tool_failure_after_clean_output_is_not_a_pass(self):
        for command in ['strings', 'grep']:
            with self.subTest(command=command):
                tools = self.root / command
                tools.mkdir()
                fake = tools / command
                fake.write_text('#!/bin/bash\nprintf "clean_fixture\\n"\nexit 9\n')
                fake.chmod(0o700)
                env = os.environ.copy()
                env['PATH'] = str(tools) + os.pathsep + env['PATH']
                self.assertEqual(self.gate(self.production, env=env).returncode, 2)

    def test_missing_tools_fail_closed(self):
        env = os.environ.copy()
        env['PATH'] = str(self.root)
        self.assertEqual(self.gate(self.production, env=env).returncode, 2)


if __name__ == '__main__':
    unittest.main()
