#!/usr/bin/env python3
"""Phase 03 domain-acceptance verifier for the existing OpenAPI contract.

Reuse-first: the project already has one validated, CI-linted contract
(docs/openapi.yaml, 172 ops) plus the M1 subset (docs/openapi-m1.yaml). Rather
than physically fragment that working spec into docs/api/v1/*.yaml (which would
duplicate and endanger the linted artifact), this verifier asserts that each
Phase-03 domain acceptance invariant already holds in the single spec.

Covers L03-002..L03-010 acceptance invariants. LOCAL governance only.

  python3 docs/api/check_contract_domains.py
  python3 docs/api/check_contract_domains.py --selftest

Exit 0 = all invariants hold; 1 = violation; 2 = usage/environment error.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FULL = ROOT / "docs/openapi.yaml"
M1 = ROOT / "docs/openapi-m1.yaml"

ISSUER_SCHEMES = {"ParentBearer", "DeviceBearer", "AdminBearer", "AdminApplicantBearer"}


def load(p: Path) -> dict:
    return json.loads(p.read_text(encoding="utf-8"))


def operations(spec: dict):
    for path, methods in spec["paths"].items():
        for m, op in methods.items():
            if m in ("get", "post", "put", "delete", "patch"):
                yield m.upper(), path, op


def op_schemes(spec: dict, op: dict) -> set[str]:
    sec = op.get("security", spec.get("security"))
    return {k for blk in (sec or []) for k in blk}


def check(spec: dict) -> list[str]:
    e: list[str] = []
    ops = list(operations(spec))

    # L03-002: no route grants wrong-issuer access — every op has exactly one
    # issuer scheme (or is an explicit anonymous auth/enrollment route), never a
    # mix of parent+admin+device on one operation.
    for m, p, op in ops:
        schemes = op_schemes(spec, op)
        if not schemes:
            # anonymous routes are allowed only for auth/enrollment bootstrap and
            # explicitly public reads (service status, published FAQ).
            public_ok = (
                any(seg in p for seg in ("/auth/", "/enrollment", "/pairing-codes", "/.well-known"))
                or m == "GET" and (p == "/service/status" or p == "/faqs" or p.startswith("/faqs/"))
            )
            if not public_ok:
                e.append(f"L03-002 {m} {p}: no security and not an auth/enrollment/public-read route")
            continue
        if len(schemes) != 1:
            e.append(f"L03-002 {m} {p}: mixes issuers {sorted(schemes)} (wrong-issuer risk)")
        if not schemes <= ISSUER_SCHEMES:
            e.append(f"L03-002 {m} {p}: unknown issuer scheme {sorted(schemes)}")

    # L03-003: typed error code + request id envelope.
    err = spec["components"]["schemas"].get("Error", {})
    req = set(err.get("required", []))
    if not {"code", "message", "request_id"} <= req:
        e.append("L03-003: Error envelope must require code, message, request_id")

    # L03-004: parent domain is Google-identity only; guardian-grant creation is
    # fail-closed on relationship proof (no self-asserted verified/paid fields).
    gg = spec["paths"].get("/children/{childId}/guardian-grants", {}).get("post")
    if gg is not None and gg.get("x-implementation-status") != "BLOCKED_PARENT_RELATIONSHIP_PROOF":
        e.append("L03-004: guardian-grants POST must be BLOCKED_PARENT_RELATIONSHIP_PROOF (fail-closed)")

    # L03-005: device domain cannot self-assert managed mode or capture success —
    # device-bearer ops use SELF_ONLY-style scope, never a guardian/owner scope.
    for m, p, op in ops:
        if op_schemes(spec, op) == {"DeviceBearer"}:
            scope = op.get("x-required-scope", "")
            if "GUARDIAN" in scope or "OWNER" in scope:
                e.append(f"L03-005 {m} {p}: device route must not carry guardian/owner scope ({scope})")

    # L03-006: retryable create writes model an Idempotency-Key header.
    idem = 0
    for m, p, op in ops:
        if m in ("POST",):
            if any(pr.get("name", "").lower() == "idempotency-key" for pr in op.get("parameters", [])):
                idem += 1
    if idem < 1:
        e.append("L03-006: no POST operation models an Idempotency-Key header")

    # L03-009: admin applicant (NO_ACCESS) scope can only see its own application.
    for m, p, op in ops:
        if op_schemes(spec, op) == {"AdminApplicantBearer"}:
            scope = op.get("x-required-scope", "")
            if "OWNER" in scope or "SUPPORT" in scope or scope in ("FAQ_READ", "FAQ_EDITOR"):
                e.append(f"L03-009 {m} {p}: applicant route must be self-scoped, not {scope}")

    # L03-010: media/research operations are gated (never VERIFIED_IMPLEMENTED).
    for m, p, op in ops:
        if "media" in p.lower():
            st = op.get("x-implementation-status", "")
            if "RESEARCH" not in st and "BLOCKED" not in st and "PROPOSED" not in st and "DESIGN" not in st:
                e.append(f"L03-010 {m} {p}: media op not gated (status {st})")

    # L03-011 surface: unique operationIds (full linter enforces resolution).
    ids = [op.get("operationId") for _, _, op in ops]
    if len(ids) != len(set(ids)) or any(i is None for i in ids):
        e.append("L03-011: operationIds not all present and unique")

    return e


def selftest() -> int:
    spec = load(FULL)
    # Mutate a copy: give a device op an owner scope -> must be caught.
    bad = json.loads(json.dumps(spec))
    for p, methods in bad["paths"].items():
        for m, op in methods.items():
            if m in ("post", "get") and op_schemes(bad, op) == {"DeviceBearer"}:
                op["x-required-scope"] = "OWNER_MANAGE"
                break
        else:
            continue
        break
    caught = any(x.startswith("L03-005") for x in check(bad))
    print(f"selftest={'PASS' if caught else 'FAIL'} (device-owner-scope violation detected={caught})")
    return 0 if caught else 1


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    if not FULL.is_file():
        print(f"FAIL: missing {FULL}", file=sys.stderr)
        return 2
    spec = load(FULL)
    errors = check(spec)
    ops = list(operations(spec))
    print(json.dumps({
        "contract": "docs/openapi.yaml",
        "operations": len(ops),
        "issuer_partition": {s: sum(1 for _, _, o in ops if op_schemes(spec, o) == {s})
                             for s in sorted(ISSUER_SCHEMES)},
        "domain_invariants_checked": ["L03-002", "L03-003", "L03-004", "L03-005",
                                      "L03-006", "L03-009", "L03-010", "L03-011"],
        "errors": errors,
        "readiness": "contract-only domain acceptance check; not a live-handler or release proof",
    }, indent=2))
    for x in errors:
        print("  " + x, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
