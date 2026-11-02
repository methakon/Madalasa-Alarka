"""Static checks for the scheduled-job deployment files (no systemd needed; systemd-analyze verify runs too if present)."""
import configparser, os, pathlib, shutil, subprocess, unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
DEPLOY = ROOT / "backend" / "deploy"
SERVICE = DEPLOY / "systemd" / "ma-purge.service"
TIMER = DEPLOY / "systemd" / "ma-purge.timer"


def unit(path):
    cp = configparser.ConfigParser(strict=False, interpolation=None, delimiters=("=",))
    cp.optionxform = str  # systemd keys are case-sensitive
    cp.read_string(path.read_text())
    return cp


class PurgeUnits(unittest.TestCase):
    def test_service(self):
        s = unit(SERVICE)["Service"]
        self.assertEqual(s["Type"], "oneshot")
        self.assertEqual(s["User"], "ma-purge")
        self.assertTrue(s["EnvironmentFile"].startswith("/etc/madalasa/"))
        self.assertEqual(s["ExecStart"], "/opt/madalasa/backend/scripts/run_purge.sh")
        for key, want in {"NoNewPrivileges": "yes", "ProtectSystem": "strict", "PrivateTmp": "yes",
                          "ProtectHome": "yes", "CapabilityBoundingSet": ""}.items():
            self.assertEqual(s.get(key), want, key)
        self.assertIn("TimeoutStartSec", s)

    def test_exec_target_exists_and_is_executable(self):
        script = ROOT / "backend" / "scripts" / "run_purge.sh"
        self.assertTrue(script.is_file() and os.access(script, os.X_OK))

    def test_timer(self):
        cp = unit(TIMER)
        self.assertEqual(cp["Timer"]["OnCalendar"], "hourly")
        self.assertEqual(cp["Timer"]["Persistent"], "true")
        self.assertIn("RandomizedDelaySec", cp["Timer"])
        self.assertEqual(cp["Timer"]["Unit"], "ma-purge.service")
        self.assertEqual(cp["Install"]["WantedBy"], "timers.target")

    def test_no_secrets_in_deployment_files(self):
        for f in DEPLOY.rglob("*"):
            if f.is_file():
                text = f.read_text().lower()
                self.assertNotIn("pgpassword=", text.replace(" ", ""), f.name)
                self.assertNotIn("begin private key", text, f.name)

    def test_role_is_least_privilege(self):
        sql = (DEPLOY / "ma_purge_role.sql").read_text()
        for must in ("NOINHERIT", "NOSUPERUSER", "NOBYPASSRLS", "NOCREATEROLE", ":'ma_purge_password'"):
            self.assertIn(must, sql)
        self.assertNotIn("ap_m1_owner", sql.replace("NOT a member of ap_m1_owner", ""))

    @unittest.skipUnless(shutil.which("systemd-analyze"), "systemd-analyze not installed")
    def test_systemd_analyze_accepts_units(self):
        r = subprocess.run(["systemd-analyze", "verify", "--man=no", str(SERVICE), str(TIMER)],
                           capture_output=True, text=True)
        # The service path and user do not exist on a CI runner; only syntax problems matter here.
        bad = [l for l in r.stderr.splitlines() if "Unknown" in l or "Invalid" in l or "syntax" in l.lower()]
        self.assertEqual(bad, [], r.stderr)


if __name__ == "__main__":
    unittest.main()
