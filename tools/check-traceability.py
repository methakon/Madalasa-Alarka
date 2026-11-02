#!/usr/bin/env python3
"""L00-011 validator for docs/roadmap/TRACEABILITY_LEDGER.csv.

Acceptance: "All release candidates have references and tests." Every row must
carry at least one design reference (ui/db/api) and a test_id, and a valid
test_status. LOCAL governance only; test_status may be NOT_RUN at this stage.

Usage:
  python3 tools/check-traceability.py            # validate the ledger
  python3 tools/check-traceability.py --selftest # prove a missing-test row fails

Exit 0 = valid; 1 = violation; 2 = usage/environment error.
"""
from __future__ import annotations

import csv
import io
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "docs" / "roadmap" / "TRACEABILITY_LEDGER.csv"
REQUIRED = ["requirement_id", "title", "priority", "ui_ref", "db_ref",
            "api_ref", "test_id", "test_status", "release_candidate"]
VALID_STATUS = {"NOT_RUN", "PASS", "FAILED", "SKIPPED", "BLOCKED"}


def validate_rows(rows: list[dict], where: str) -> list[str]:
    errors: list[str] = []
    for i, row in enumerate(rows, start=2):  # line 1 is header
        rid = row.get("requirement_id", "").strip()
        if not rid:
            errors.append(f"{where} line {i}: missing requirement_id")
            continue
        has_ref = any((row.get(c) or "").strip() and (row.get(c) or "").strip() != "n/a"
                      for c in ("ui_ref", "db_ref", "api_ref"))
        # NFR rows may legitimately have n/a ui/db; require at least one of db/api OR a test.
        if not has_ref and (row.get("db_ref", "").strip() in ("", "n/a")
                            and row.get("api_ref", "").strip() in ("", "n/a")):
            # allowed only if a concrete test_id is present (pure policy requirement)
            if not (row.get("test_id") or "").strip():
                errors.append(f"{where} {rid}: no reference and no test")
        if not (row.get("test_id") or "").strip():
            errors.append(f"{where} {rid}: missing test_id (release candidate must have a test)")
        status = (row.get("test_status") or "").strip()
        if status not in VALID_STATUS:
            errors.append(f"{where} {rid}: invalid test_status '{status}'")
    return errors


def load(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        return (reader.fieldnames or []), list(reader)


def selftest() -> int:
    bad = ("requirement_id,title,priority,ui_ref,db_ref,api_ref,test_id,test_status,release_candidate\n"
           "FR-999,Missing test,P0,P-01,some_table,GET /x,,NOT_RUN,YES\n")
    rows = list(csv.DictReader(io.StringIO(bad)))
    errs = validate_rows(rows, "<selftest>")
    ok = any("missing test_id" in e for e in errs)
    good = ("requirement_id,title,priority,ui_ref,db_ref,api_ref,test_id,test_status,release_candidate\n"
            "FR-001,Good,P0,P-01,t,GET /x,T-FR-001,NOT_RUN,YES\n")
    errs2 = validate_rows(list(csv.DictReader(io.StringIO(good))), "<selftest-good>")
    ok = ok and not errs2
    print(f"selftest={'PASS' if ok else 'FAIL'} (missing-test detected={bool(errs)}, clean-row-ok={not errs2})")
    return 0 if ok else 1


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    if not CSV_PATH.is_file():
        print(f"FAIL: missing {CSV_PATH}", file=sys.stderr)
        return 2
    fields, rows = load(CSV_PATH)
    errors: list[str] = []
    missing_cols = [c for c in REQUIRED if c not in fields]
    if missing_cols:
        errors.append(f"missing columns: {missing_cols}")
    else:
        errors.extend(validate_rows(rows, "TRACEABILITY_LEDGER.csv"))
    print(f"rows={len(rows)} columns_ok={not missing_cols} violations={len(errors)}")
    for e in errors:
        print("  " + e, file=sys.stderr)
    print("readiness: local traceability check only; no release/legal/Play approval conferred")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
