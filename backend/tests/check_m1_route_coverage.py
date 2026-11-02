#!/usr/bin/env python3
"""Check every frozen OpenAPI M1 verb/path is actually registered in Drogon.

Runs offline; validates route presence, not handler correctness, PostgreSQL RLS,
Android capability or production authorization. Also records extra non-M1
routes separately (e.g. future /locations:batch) without changing the contract.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "docs/openapi-m1.yaml"
ENTRY = ROOT / "backend/src/main.cc"
METHODS = {"get", "post", "put", "patch", "delete"}

def audit():
    schema = json.loads(CONTRACT.read_text(encoding="utf-8"))
    expected = {
        ("/v1" + path, method.upper(), details["operationId"])
        for path, methods in schema["paths"].items()
        for method, details in methods.items()
        if method in METHODS
    }
    source = ENTRY.read_text(encoding="utf-8")
    pattern = re.compile(r'app\(\)\.registerHandler\(\s*"([^"]+)"\s*,.*?\{(Get|Post|Delete|Put|Patch)\}\);', re.S)
    registered = [(route, method.upper()) for route, method in pattern.findall(source)]
    duplicates = sorted({p for p in registered if registered.count(p) > 1})
    missing = sorted((route, method, op) for route, method, op in expected
                     if (route, method) not in registered)
    extras = sorted(set(registered) - {(route, method) for route, method, _ in expected})
    return expected, registered, duplicates, missing, extras

if __name__ == "__main__":
    expected, registered, duplicate, missing, extras = audit()
    if missing or duplicate or len(expected) != 14:
        raise SystemExit(f"M1 HANDLER COVERAGE FAIL: missing={missing} duplicate={duplicate} contract_count={len(expected)}")
    print(f"M1 route registration PASS: {len(expected)} frozen operations; extra non-M1 routes={extras}")
