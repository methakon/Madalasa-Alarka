#!/usr/bin/env python3
"""Validate named inter-entity arrows and ERD entity count (stdlib only)."""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT = ROOT / "docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json"
ARROW = re.compile(r"(?:→|->)\s*([a-z][a-z0-9_]*)")

def validate(erd):
    errors = []
    domains = erd.get("domains", [])
    tables = [t for d in domains for t in d.get("tables", [])]
    names = [t["name"] for t in tables]
    if len(set(names)) != len(names):
        errors.append("duplicate ERD entity names")
    if erd.get("tableCount") != len(tables):
        errors.append(f"ERD tableCount {erd.get('tableCount')} != {len(tables)} actual entities")
    if erd.get("domainCount") != len(domains):
        errors.append(f"ERD domainCount {erd.get('domainCount')} != {len(domains)} actual domains")
    known = set(names)
    for table in tables:
        for column in table.get("columns", []):
            if not isinstance(column, str):
                errors.append(f"{table['name']}: non-string column entry")
                continue
            for target in ARROW.findall(column):
                if target not in known:
                    errors.append(f"{table['name']}: {column!r} references missing ERD entity {target}")
    return errors

if __name__ == "__main__":
    path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
    errors = validate(json.loads(path.read_text()))
    if errors:
        print("ERD RELATION CHECK FAILED:\n- " + "\n- ".join(errors))
        raise SystemExit(1)
    print("ERD RELATION CHECK PASSED")
