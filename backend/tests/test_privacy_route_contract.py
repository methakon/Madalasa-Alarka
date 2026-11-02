#!/usr/bin/env python3
"""Static fail-closed contract checks; runtime/DB acceptance still required."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "src/main.cc").read_text()
HEADER = (ROOT / "src/privacy_endpoints.h").read_text()
SCHEMA = (ROOT / "persistence/migrations/0002_child_scoped_cross_family_guardians.sql").read_text()


class PrivacyRouteContractTests(unittest.TestCase):
    def test_routes_use_existing_openapi_path_names(self):
        for path in (
            "/v1/children/{childId}/guardian-grants",
            "/v1/children/{childId}/consents",
            "/v1/children/{childId}/guardian-grants/{grantId}",
            "/v1/devices/{deviceId}/consent-status",
        ):
            self.assertIn(f'"{path}"', MAIN)

    def test_parent_routes_require_trusted_session_and_exact_scope(self):
        self.assertIn("ParentAuthMode::V2Session", HEADER)
        self.assertIn("bind_parent_principal", HEADER)
        self.assertIn("MANAGE_CHILD_GRANTS", HEADER)
        self.assertIn("MANAGE_CONSENT", HEADER)
        self.assertIn("ap_m1.has_child_scope_v2", HEADER)
        self.assertIn("privacy_not_found(rid)", HEADER)
        self.assertNotIn("x-synthetic-parent", HEADER)

    def test_revoke_requires_same_child_and_committed_sql_transaction(self):
        self.assertIn("id=$1::uuid AND child_id=$2::uuid", HEADER)
        self.assertIn("ap_m1.revoke_child_grant", HEADER)
        self.assertIn("co_await commit(std::move(tx))", HEADER)
        self.assertIn("if (e.sqlState() == \"42501\")", HEADER)
        self.assertIn("CREATE FUNCTION ap_m1.revoke_child_grant", SCHEMA)

    def test_child_endpoint_requires_matching_device_identity(self):
        self.assertIn("co_await authenticate_device(req)", HEADER)
        self.assertIn("*target != actor->device_id", HEADER)
        self.assertIn('body["collection_authorized"] = false', HEADER)
        self.assertIn("UNKNOWN_DEVICE_LOCAL_ONLY", HEADER)

    def test_private_responses_disallow_caching(self):
        self.assertIn("add_no_store(resp);", HEADER)
        self.assertNotIn("LOG_INFO << actor->child_id", HEADER)


if __name__ == "__main__":
    unittest.main()
