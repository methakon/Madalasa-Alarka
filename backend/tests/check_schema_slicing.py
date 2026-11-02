#!/usr/bin/env python3
"""L02-001 check: no concept-only physical table created by accident.

Every physical ap_m1 base table must be justified either by a Figma concept
mapping (docs/data-model/local-postgresql/logical-to-physical.json) or by the
curated operational/security/audit/erasure/test allowlist below (each such
table is referenced by migrations: functions, policies, or foreign keys).

Fails (exit 1) if an unexplained physical table appears. Requires the v2 test
database to be up and migrated. LOCAL synthetic only.

  python3 backend/tests/check_schema_slicing.py
  python3 backend/tests/check_schema_slicing.py --selftest
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP = ROOT / "docs/data-model/local-postgresql/logical-to-physical.json"

# Deliberate implementation tables with no 1:1 Figma concept. Each is referenced
# by the migrations (see backend/persistence/SCHEMA_SLICING.md for justification).
OPERATIONAL_ALLOWLIST = {
    "admin_sessions", "admin_login_challenges", "credential_renewal_challenges",
    "owner_identity_allowlist", "trusted_principal_verifications", "device_credentials",
    "device_reenrollment_events", "audit_events", "consent_decision_audit",
    "entitlement_audit", "security_audit_events", "consent_documents",
    "consent_policy_versions", "adult_erasure_jobs", "adult_erasure_requests",
    "erasure_evidence", "erasure_store_inventory", "restore_ledger_imports",
    "restore_runs", "restore_suppression_receipts", "backup_inventory",
    "retention_holds", "compliance_export_bundles", "alert_delivery_attempts",
    "command_receipts", "trial_child_entitlements", "child_pickup_viewer_passes",
    "trip_routepoints", "location_collection_policies", "child_guardian_grants",
    "m1_renewal_hold_preservation", "local_test_settings",
}


def concept_tables() -> set[str]:
    m = json.loads(MAP.read_text(encoding="utf-8"))
    out: set[str] = set()
    for mp in m["mappings"]:
        for po in mp.get("physical_objects", []):
            if po.startswith("ap_m1."):
                out.add(po.split(".", 1)[1])
    return out


def physical_tables() -> set[str]:
    import psycopg  # noqa: local only
    sys.path.insert(0, str(ROOT / "backend/tests/database"))
    import fixtures  # type: ignore
    # Use the admin (DDL-owner) connection so ALL base tables are enumerated,
    # not just the RLS-projected subset visible to the runtime app role.
    conn_fn = getattr(fixtures, "admin_connection", None) or fixtures.runtime_connection
    with conn_fn() as c:
        rows = c.execute(
            "SELECT table_name FROM information_schema.tables "
            "WHERE table_schema='ap_m1' AND table_type='BASE TABLE'").fetchall()
    return {r[0] for r in rows}


def classify(phys: set[str], concepts: set[str]):
    justified_by_concept = phys & concepts
    justified_by_allowlist = (phys - concepts) & OPERATIONAL_ALLOWLIST
    unexplained = phys - concepts - OPERATIONAL_ALLOWLIST
    return justified_by_concept, justified_by_allowlist, unexplained


def selftest() -> int:
    concepts = concept_tables()
    # Inject a fake accidental table; it must be reported unexplained.
    phys = set(concepts) | OPERATIONAL_ALLOWLIST | {"accidental_concept_only_table"}
    _, _, unexplained = classify(phys, concepts)
    ok = unexplained == {"accidental_concept_only_table"}
    print(f"selftest={'PASS' if ok else 'FAIL'} (detected {sorted(unexplained)})")
    return 0 if ok else 1


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    concepts = concept_tables()
    phys = physical_tables()
    by_concept, by_allow, unexplained = classify(phys, concepts)
    print(json.dumps({
        "physical_tables": len(phys),
        "concept_tables_in_map": len(concepts),
        "justified_by_concept": len(by_concept),
        "justified_by_operational_allowlist": len(by_allow),
        "unexplained": sorted(unexplained),
        "readiness": "local schema-slicing check only; no release approval conferred",
    }, indent=2))
    if unexplained:
        print("FAIL: unexplained physical table(s) — a concept-only table may have "
              "been created by accident, or SCHEMA_SLICING.md/allowlist needs updating.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
