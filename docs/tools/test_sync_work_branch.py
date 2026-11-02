"""Hermetic Git integration tests for mandatory start-of-work main+dev sync.

No network credentials, child data or GitHub operations: each test creates a
disposable bare origin and working clone under a temporary directory.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("sync_work_branch.sh")


def run(*args, cwd, check=True):
    return subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=check)


class SyncWorkBranchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="ma_branch_sync_")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.remote = self.home / "origin.git"
        self.repo = self.home / "worker"
        run("git", "init", "--bare", "--initial-branch=main", str(self.remote), cwd=self.home)
        run("git", "clone", str(self.remote), str(self.repo), cwd=self.home)
        run("git", "config", "user.name", "Synthetic Branch Test", cwd=self.repo)
        run("git", "config", "user.email", "synthetic@example.invalid", cwd=self.repo)
        run("git", "switch", "-c", "main", cwd=self.repo)
        (self.repo / "base.txt").write_text("baseline\n")
        self.commit("initial synthetic baseline")
        self.git("push", "-u", "origin", "main")
        for branch in ("dev", "api"):
            self.git("switch", "-c", branch, "main")
            self.git("push", "-u", "origin", branch)
            self.git("switch", "main")

    def git(self, *args, check=True):
        return run("git", *args, cwd=self.repo, check=check)

    def commit(self, title):
        self.git("add", "-A")
        self.git("commit", "-m", title)

    def add_remote_change(self, branch, path, content):
        self.git("switch", branch)
        (self.repo / path).write_text(content)
        self.commit(f"update {branch} synthetic input")
        self.git("push", "origin", branch)

    def sync(self, branch):
        return run("bash", str(SCRIPT), branch, cwd=self.repo, check=False)

    def test_workstream_pulls_main_and_dev_and_records_heads(self):
        self.add_remote_change("main", "canonical-doc.txt", "main only\n")
        self.add_remote_change("dev", "integration-code.txt", "dev only\n")
        self.git("switch", "api")
        result = self.sync("api")
        self.assertEqual(0, result.returncode, result.stderr + result.stdout)
        self.assertTrue((self.repo / "canonical-doc.txt").exists())
        self.assertTrue((self.repo / "integration-code.txt").exists())
        self.git("merge-base", "--is-ancestor", "origin/main", "HEAD")
        self.git("merge-base", "--is-ancestor", "origin/dev", "HEAD")
        self.assertIn("PREWORK_SYNC_OK branch=api", result.stdout)
        self.assertIn("main=", result.stdout)
        self.assertIn("dev=", result.stdout)
        self.assertIn("utc=", result.stdout)

    def test_main_pulls_main_but_does_not_merge_unverified_dev(self):
        self.add_remote_change("dev", "unreviewed-dev.txt", "not ready for main\n")
        self.git("switch", "main")
        result = self.sync("main")
        self.assertEqual(0, result.returncode, result.stderr + result.stdout)
        self.assertFalse((self.repo / "unreviewed-dev.txt").exists())
        self.assertIn("NOT merging dev into main", result.stdout)
        self.git("merge-base", "--is-ancestor", "origin/main", "HEAD")
        ancestry = self.git("merge-base", "--is-ancestor", "origin/dev", "HEAD", check=False)
        self.assertNotEqual(0, ancestry.returncode)

    def test_dev_pulls_latest_main_without_merging_other_work(self):
        self.add_remote_change("main", "latest-policy.txt", "updated\n")
        self.git("switch", "dev")
        result = self.sync("dev")
        self.assertEqual(0, result.returncode, result.stderr + result.stdout)
        self.assertTrue((self.repo / "latest-policy.txt").exists())
        self.git("merge-base", "--is-ancestor", "origin/main", "HEAD")
        self.assertIn("PREWORK_SYNC_OK branch=dev", result.stdout)

    def test_dirty_worktree_is_rejected_without_losing_data(self):
        self.git("switch", "api")
        (self.repo / "base.txt").write_text("uncommitted changes must survive\n")
        result = self.sync("api")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("Dirty worktree", result.stderr)
        self.assertEqual("uncommitted changes must survive\n",
                         (self.repo / "base.txt").read_text())

    def test_wrong_branch_and_unapproved_branch_fail_closed(self):
        self.git("switch", "api")
        for requested in ("dev", "unknown", "feature/ad-hoc"):
            with self.subTest(requested=requested):
                result = self.sync(requested)
                self.assertNotEqual(0, result.returncode)
        self.assertEqual("api", self.git("branch", "--show-current").stdout.strip())


if __name__ == "__main__":
    unittest.main()
