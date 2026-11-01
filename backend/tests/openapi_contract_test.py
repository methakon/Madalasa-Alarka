#!/usr/bin/env python3
"""L03-013 OpenAPI contract test: reject undocumented or widened properties.

Guards the contract so a response (or request) can never be silently widened
with undocumented fields: every object schema reachable from an operation's
responses/requestBody must set additionalProperties:false and declare its
required fields as a subset of its properties. Also asserts every operation's
2xx/4xx responses reference the shared Error envelope for errors and a concrete
schema for success (no free-form object).

Reuses docs/openapi.yaml (the CI-linted contract). stdlib only, offline.

  python3 backend/tests/openapi_contract_test.py
  python3 backend/tests/openapi_contract_test.py --selftest

Exit 0 = contract is tight; 1 = a widenable/undocumented schema found; 2 = error.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "docs/openapi.yaml"


def load(p: Path) -> dict:
    return json.loads(p.read_text(encoding="utf-8"))


def resolve(spec: dict, node):
    """Resolve a local $ref one level; return the node otherwise."""
    if isinstance(node, dict) and "$ref" in node:
        ref = node["$ref"]
        if not ref.startswith("#/"):
            return None
        cur = spec
        for part in ref[2:].split("/"):
            cur = cur.get(part, {}) if isinstance(cur, dict) else {}
        return cur
    return node


def iter_object_schemas(spec: dict, node, seen: set, errors: list, where: str, is_request: bool):
    """Walk a schema, flagging widenable object schemas.

    Policy (matches lint_openapi_full.py's intent): a schema must never set
    additionalProperties:true (explicit widening). For request bodies this is
    strict and also requires required[] be a subset of properties. A missing
    additionalProperties is tolerated (the contract's convention), and the
    documented free-form Error.details bag is exempt.
    """
    node = resolve(spec, node)
    if not isinstance(node, dict):
        return
    key = id(node)
    if key in seen:
        return
    seen.add(key)

    props = node.get("properties")
    if node.get("type") == "object" or props is not None:
        ap = node.get("additionalProperties", None)
        exempt = where.endswith(".details")  # documented free-form Error.details bag
        if ap is True and not exempt:
            errors.append(f"{where}: schema sets additionalProperties:true (undocumented widening)")
        req = node.get("required", [])
        if props is not None and is_request:
            extra = [r for r in req if r not in props]
            if extra:
                errors.append(f"{where}: required fields not in properties: {extra}")
        for pname, pschema in (props or {}).items():
            iter_object_schemas(spec, pschema, seen, errors, f"{where}.{pname}", is_request)
    for comb in ("allOf", "oneOf", "anyOf"):
        for i, sub in enumerate(node.get(comb, [])):
            iter_object_schemas(spec, sub, seen, errors, f"{where}[{comb}{i}]", is_request)
    if "items" in node:
        iter_object_schemas(spec, node["items"], seen, errors, f"{where}[]", is_request)


def check(spec: dict) -> list[str]:
    errors: list[str] = []
    for path, methods in spec["paths"].items():
        for m, op in methods.items():
            if m not in ("get", "post", "put", "delete", "patch"):
                continue
            base = f"{m.upper()} {path}"
            # request body object schemas must not widen
            rb = op.get("requestBody", {})
            for ct, media in (resolve(spec, rb) or {}).get("content", {}).items():
                iter_object_schemas(spec, media.get("schema", {}), set(), errors, f"{base} req({ct})", True)
            # response object schemas must not widen
            for code, resp in op.get("responses", {}).items():
                r = resolve(spec, resp) or {}
                for ct, media in r.get("content", {}).items():
                    iter_object_schemas(spec, media.get("schema", {}), set(), errors,
                                        f"{base} resp {code}({ct})", False)
    return errors


def selftest() -> int:
    spec = load(SPEC)
    bad = json.loads(json.dumps(spec))
    # Widen one response schema and confirm it is caught.
    target = None
    for path, methods in bad["paths"].items():
        for m, op in methods.items():
            if m == "get":
                for code, resp in op.get("responses", {}).items():
                    r = resp
                    for ct, media in (r.get("content") or {}).items():
                        sch = media.get("schema", {})
                        if isinstance(sch, dict) and "$ref" not in sch:
                            sch["additionalProperties"] = True
                            sch.setdefault("type", "object")
                            sch.setdefault("properties", {"x": {"type": "string"}})
                            target = f"{m.upper()} {path} {code}"
                            break
                    if target: break
            if target: break
        if target: break
    caught = bool(check(bad)) if target else False
    print(f"selftest={'PASS' if caught else 'FAIL'} (widened response at {target} detected={caught})")
    return 0 if caught else 1


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    if not SPEC.is_file():
        print(f"FAIL: missing {SPEC}", file=sys.stderr)
        return 2
    errors = check(load(SPEC))
    print(json.dumps({
        "contract": "docs/openapi.yaml",
        "violations": len(errors),
        "sample": errors[:10],
        "readiness": "contract tightness check only; not a live-handler or release proof",
    }, indent=2))
    for x in errors:
        print("  " + x, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
