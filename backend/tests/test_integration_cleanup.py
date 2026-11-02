"""Hermetic failure paths of the actual integration script; no PostgreSQL/network.

The caller and sibling live in a NEW session: the old kill(0) bug cannot
signal the unittest runner or the user's shell.
"""
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().with_name('integration_families.sh')


class IntegrationCleanupTests(unittest.TestCase):
    def run_failure(self, stage, expected, stubborn=False):
        with tempfile.TemporaryDirectory(prefix='ma-cleanup-') as root:
            root = Path(root)
            tools = root / 'tools'
            tools.mkdir()
            scratch = root / 'scratch'
            scratch.mkdir()
            def tool(name, content):
                path = tools / name
                path.write_text('#!/usr/bin/env bash\n' + content)
                path.chmod(0o700)
                return path
            tool('psql', 'printf "%s\\n" "$*" >>"$FIXTURE/sql"\n'
                 'if [[ "$FAIL_STAGE" == before_server && "$*" == *" -f "* ]]; then exit 37; fi\n')
            tool('curl', 'if [[ "$*" == *healthz* ]]; then\n'
                 '  for i in {1..100}; do [[ -s "$FIXTURE/pids" ]] && exit 0; sleep 0.01; done\n'
                 '  exit 22\nfi\n'
                 'while [[ $# -gt 0 ]]; do\n'
                 '  if [[ "$1" == -o ]]; then printf "{}" >"$2"; shift; fi\n'
                 '  shift\ndone\nprintf "000"\nexit 22\n')
            backend = tool('backend', 'echo $$ >>"$FIXTURE/pids"\n'
                           + ('trap "" TERM\n' if stubborn else '')
                           + 'while :; do sleep 0.1; done\n')
            env = os.environ.copy()
            # No inherited connection credentials reach even the fake executables.
            for key in tuple(env):
                if key.startswith(('PG', 'MA_PG_')):
                    env.pop(key)
            env.update(PATH=str(tools) + os.pathsep + env['PATH'],
                       TMPDIR=str(scratch), FIXTURE=str(root), FAIL_STAGE=stage)
            wrapper = '''trap 'exit 91' TERM
sleep 60 & sibling=$!
bash "$1" "$2"
result=$?
kill -0 "$sibling" || exit 92
kill "$sibling"; wait "$sibling" 2>/dev/null
printf 'CALLER_AND_SIBLING_SURVIVED:%s\\n' "$result"
exit "$result"
'''
            proc = subprocess.Popen(['bash', '-c', wrapper, 'cleanup-test', str(SCRIPT), str(backend)],
                                    env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    start_new_session=True, text=True)
            try:
                stdout, stderr = proc.communicate(timeout=10)
                # Verify before the isolation safety-net below; otherwise the
                # harness itself could conceal a leaked/unreaped backend.
                pids = root / 'pids'
                if pids.exists():
                    for pid in map(int, pids.read_text().splitlines()):
                        with self.assertRaises(ProcessLookupError,
                                               msg=f'backend {pid} was not killed and reaped'):
                            os.kill(pid, 0)
            finally:
                # This is ONLY the new test session, never the invoking process group.
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait()
            self.assertEqual(proc.returncode, expected, (stdout, stderr))
            self.assertIn(f'CALLER_AND_SIBLING_SURVIVED:{expected}', stdout)
            sql = (root / 'sql').read_text()
            self.assertIn('DROP DATABASE IF EXISTS', sql)
            self.assertEqual(list(scratch.iterdir()), [], 'temporary output/logs leaked')
            if stage == 'before_server':
                self.assertFalse((root / 'pids').exists())
            else:
                self.assertTrue((root / 'pids').exists(), 'first backend never started')

    def test_failure_before_first_server_preserves_exit_and_caller(self):
        self.run_failure('before_server', 37)

    def test_failure_before_second_server_preserves_exit_and_caller(self):
        self.run_failure('before_second', 1)

    def test_uncooperative_child_cleanup_is_bounded(self):
        self.run_failure('before_second', 1, stubborn=True)


if __name__ == '__main__':
    unittest.main()
