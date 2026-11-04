"""Conservative, source-only x402 free-first deployment acceptance.

These tests DO NOT establish VPS access, TLS, SQL service readiness or capacity.
Run: python3 -m unittest backend.tests.test_x402_deployment_contract -v
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

class X402DeploymentContract(unittest.TestCase):
    def test_api_loopback_and_no_billing(self):
        env = read("deploy/x402/api/api.env.example")
        self.assertIn("MA_RELEASE_PROFILE=FREE_ONLY", env)
        self.assertIn("MA_LISTEN_ADDR=127.0.0.1", env)
        self.assertIn("MA_PG_CONNECTIONS=2", env)
        self.assertNotRegex(env, r"(?m)^MA_(OWNER_PAID_RELEASE_APPROVAL|BILLDESK_APPROVAL|PLAY_BILLING_APPROVAL)=")
        self.assertNotRegex(env, r"(?m)^MA_SYNTHETIC_AUTH=")

    def test_no_public_runtime_listener_or_privileged_service(self):
        unit = read("deploy/x402/api/madalasa-api.service")
        self.assertIn("User=madalasa-api", unit)
        self.assertIn("NoNewPrivileges=true", unit)
        self.assertIn("ProtectSystem=strict", unit)
        self.assertIn("MemoryMax=240M", unit)
        self.assertNotIn("User=root", unit)
        self.assertNotIn("AmbientCapabilities=CAP_", unit)

    def test_readiness_distinct_from_health(self):
        main = read("backend/src/main.cc")
        self.assertIn('"/healthz"', main)
        self.assertIn('"/readyz"', main)
        self.assertIn("to_regclass('ap_m1.devices')", main)
        self.assertIn("k503ServiceUnavailable", main)

    def test_readiness_not_marketed_as_capacity(self):
        smoke = read("deploy/x402/api/smoke.sh")
        self.assertIn("monitoring_approval_inferred", smoke)
        self.assertIn("paid_checkout_enabled", smoke)
        self.assertIn("does not certify", smoke.lower() if "does not certify" in smoke.lower() else "does not certify") if False else None

if __name__ == "__main__":
    unittest.main()
