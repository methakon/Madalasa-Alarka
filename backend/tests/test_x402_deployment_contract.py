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

    def test_readiness_requires_both_database_pools(self):
        main = read("backend/src/main.cc")
        ready = main.split('"/readyz",', 1)[1].split('"/v1/release/capabilities",', 1)[0]
        # Source contract only: the coordinator separately exercises HTTP/SQL.
        for client in ("ma::kDbClientName", "ma::kAuthDbClientName"):
            self.assertIn(f"app().hasDbClient({client})", ready)
            self.assertIn(f"app().getDbClient({client})", ready)
        self.assertIn("if (!db || !issuer)", ready)
        self.assertIn("co_await issuer->execSqlCoro(", ready)
        self.assertRegex(ready, r'(?s)runtime_ready\s*&&\s*issuer_ready.*?body\["status"\] = "ready"')
        self.assertIn("catch (const std::exception&)", ready)
        self.assertNotIn(".what()", ready)
        self.assertIn("k503ServiceUnavailable", ready)

    def test_readiness_checks_exact_handler_functions_on_intended_login(self):
        main = read("backend/src/main.cc")
        ready = main.split('"/readyz",', 1)[1].split('"/v1/release/capabilities",', 1)[0]
        runtime, issuer = ready.split("const auto auth = co_await issuer->execSqlCoro(", 1)
        runtime = runtime.split("const auto res = co_await db->execSqlCoro(", 1)[1]
        issuer = issuer.split("const bool runtime_ready", 1)[0]
        expected = (
            (runtime, "ap_m1_api", "ap_auth_issuer", {
                "ap_m1.ingest_location_batch_receipt(uuid,uuid,jsonb)",
                "ap_m1.issue_device_pairing_code(uuid,bytea,integer)",
            }),
            (issuer, "ap_auth_issuer", "ap_m1_api", {
                "ap_m1.exchange_parent_oidc_session(text,text,bytea,integer)",
                "ap_m1.issue_admin_login_challenge()",
                "ap_m1.exchange_admin_oidc_session(text,text,text,text,text,integer)",
                "ap_m1.redeem_pairing_code(bytea,bytea,bytea,integer)",
                "ap_m1.read_enrollment_challenge_expiry(uuid)",
                "ap_m1.store_pending_device_profile(uuid,text,text,integer,text,text)",
                "ap_m1.consume_enrollment_challenge(uuid)",
                "ap_m1.activate_enrolled_device(uuid,bytea,integer)",
            }),
        )
        for query, allowed_role, forbidden_role, signatures in expected:
            with self.subTest(login=allowed_role):
                self.assertEqual(set(re.findall(r"\('([^']+\([^']*\))'\)", query)), signatures)
                # NULL from a missing function must become false BEFORE bool_and:
                # bool_and by itself would ignore a missing dependency's NULL.
                sql = "".join(re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', query))
                self.assertIn("bool_and(COALESCE(has_function_privilege(current_user,"
                              "to_regprocedure(signature),'EXECUTE'),false))", sql)
                self.assertIn(f"AND pg_has_role(session_user,'{allowed_role}','MEMBER')", sql)
                self.assertIn(f"AND NOT pg_has_role(session_user,'{forbidden_role}','MEMBER')", sql)
                self.assertIn("NOT rolsuper AND NOT rolbypassrls", sql)
                self.assertIn("has_schema_privilege(current_user,'ap_m1','USAGE')", sql)
        self.assertIn('res.at(0)["login"].as<std::string>() != auth.at(0)["login"].as<std::string>()', ready)

    def test_readiness_not_marketed_as_capacity(self):
        smoke = read("deploy/x402/api/smoke.sh")
        self.assertIn("monitoring_approval_inferred", smoke)
        self.assertIn("paid_checkout_enabled", smoke)
        self.assertIn("not proof of postgresql", smoke.lower())

if __name__ == "__main__":
    unittest.main()
