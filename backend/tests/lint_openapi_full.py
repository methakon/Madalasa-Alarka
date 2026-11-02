#!/usr/bin/env python3
"""Validate complete planning OpenAPI and Figma screen contracts (stdlib-only JSON YAML subset).

Docs/openapi.yaml is currently encoded as JSON, which is valid YAML 1.2. Fail closed on
missing routes, duplicate operation IDs, unresolved schema references, or unsafe body types.
This checks SPECIFICATION CONSISTENCY, NOT implementation or production legality.
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path
from check_erd_references import validate as validate_erd

ROOT = Path(__file__).resolve().parents[2]
API = ROOT / "docs/openapi.yaml"
SCREEN = ROOT / "docs/audits/FIGMA_SCREEN_API_DB_AUDIT_2026-10-28.json"
DB = ROOT / "docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json"
METHODS = {"get", "post", "put", "patch", "delete"}
FORBIDDEN_REQUEST_FIELDS = {
    "AdminProfileUpsert": {"contact_verified", "email_verified", "admin_role", "state"},
    "CheckoutIntentRequest": {"expected_amount", "verified", "paid", "currency"},
    "PlayPurchaseProof": {"verified", "refund_state", "play_state", "paid_until"},
    "MediaStartRequest": {"state", "approved", "os_decision", "duration_delivered_seconds"},
}
SENSITIVE_REQUEST_ROUTES = {
    ("put", "/admin/access/profile"): "AdminProfileUpsert",
    ("post", "/families/{familyId}/checkout-intents"): "CheckoutIntentRequest",
    ("post", "/billing/purchases/verify"): "PlayPurchaseProof",
    ("post", "/children/{childId}/media/requests"): "MediaStartRequest",
}
def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)
def main() -> int:
    errors: list[str] = []
    try:
        spec = json.loads(API.read_text(encoding="utf-8"))
        audit = json.loads(SCREEN.read_text(encoding="utf-8"))
        db = json.loads(DB.read_text(encoding="utf-8"))
    except (ValueError, OSError) as exc:
        print(f"FAIL loading contract: {exc}", file=sys.stderr)
        return 2
    require(str(spec.get("openapi", "")).startswith("3.1"), "Expected OpenAPI 3.1", errors)
    require(audit.get("counts", {}).get("screens") == 187, "Wrong Figma screen inventory", errors)
    require(db.get("domainCount") == 11 and db.get("tableCount") == 120, "Logical schema addendum missing", errors)
    errors.extend(validate_erd(db))
    schemes = set(spec.get("components", {}).get("securitySchemes", {}))
    schemas = spec.get("components", {}).get("schemas", {})
    ids: set[str] = set()
    operations = 0
    for route, methods in spec.get("paths", {}).items():
        if not isinstance(methods, dict):
            errors.append(f"{route}: PathItem must be object")
            continue
        for method, op in methods.items():
            if method not in METHODS:
                continue
            operations += 1
            opname = op.get("operationId")
            require(bool(opname) and opname not in ids, f"Duplicate/missing operationId: {method} {route}", errors)
            if opname:
                ids.add(opname)
            require(bool(op.get("description")), f"Missing description: {method} {route}", errors)
            require(bool(op.get("x-required-scope")), f"No server authorization scope: {method} {route}", errors)
            require(any(str(k).startswith("2") for k in op.get("responses", {})), f"No success response: {method} {route}", errors)
            for param in re.findall(r"{([A-Za-z0-9_]+)}", route):
                require(any(p.get("name") == param and p.get("in") == "path" and p.get("required") for p in op.get("parameters", [])), f"Missing path parameter {param}: {method} {route}", errors)
            for entry in op.get("security", []):
                for key in entry:
                    require(key in schemes, f"Unknown auth scheme {key}: {method} {route}", errors)
            if route.startswith("/admin/owner/") and method != "get":
                require("OWNER" in str(op.get("x-required-scope")), f"Owner mutation not role-bound: {method} {route}", errors)
    for ref in re.findall(r"#/components/schemas/([A-Za-z0-9_]+)", json.dumps(spec)):
        require(ref in schemas, f"Undefined schema: {ref}", errors)
    for (method, route), expected in SENSITIVE_REQUEST_ROUTES.items():
        op = spec.get("paths", {}).get(route, {}).get(method, {})
        actual = op.get("requestBody", {}).get("content", {}).get("application/json", {}).get("schema", {}).get("$ref", "").split("/")[-1]
        require(actual == expected, f"Unsafe request type: {method} {route} is {actual}, expected {expected}", errors)
    for schema_name, fields in FORBIDDEN_REQUEST_FIELDS.items():
        p = schemas.get(schema_name, {}).get("properties", {})
        require(not fields.intersection(p), f"Client can claim trusted state in {schema_name}: {fields.intersection(p)}", errors)
    grant = spec.get("paths", {}).get("/children/{childId}/guardian-grants", {}).get("post", {})
    require(grant.get("x-implementation-status") == "BLOCKED_PARENT_RELATIONSHIP_PROOF", "Guardian role proof fail-closed gate missing", errors)
    admin_children = spec.get("paths", {}).get("/admin/subscribers/{familyId}/children", {}).get("get", {})
    response = admin_children.get("responses", {}).get("200", {}).get("content", {}).get("application/json", {}).get("schema", {})
    ref = response.get("properties", {}).get("items", {}).get("items", {}).get("$ref", "")
    require(ref.endswith("/AdminChildSeatAlias"), "Admin child list exposes full child model instead of minimal projection", errors)
    for screen in audit.get("screens", []):
        require(bool(screen.get("node_id")), f"Missing editable Figma node: {screen.get('screen_key')}", errors)
        for specifier in screen.get("requested_apis", []):
            match = re.fullmatch(r"(GET|POST|PUT|PATCH|DELETE) (/.+)", specifier)
            if match:
                m, path = match.groups()
                require(m.lower() in spec.get("paths", {}).get(path, {}), f"{screen.get('screen_key')}: missing {specifier}", errors)
    # Contract-hardening audit for 2026-10-28. This is NOT backend runtime evidence.
    post_audit_path = ROOT / "docs/audits/POST_REMEDIATION_SCREEN_API_DB_COVERAGE_2026-10-28.json"
    try:
        post_audit = json.loads(post_audit_path.read_text(encoding="utf-8"))
    except (ValueError, OSError) as exc:
        errors.append(f"Missing post-remediation coverage file: {exc}")
        post_audit = {}
    summary = post_audit.get("summary", {})
    require(operations >= 171, f"Expected at least 171 current designed operations, got {operations}", errors)
    require(len(spec.get("paths", {})) >= 155, "API path regression (<155)", errors)
    require(summary.get("original_screen_count") == 187, "Post-remediation Figma screen count mismatch", errors)
    require(summary.get("conceptual_db_entities") == db.get("tableCount"), "DB table count mismatch after remediation", errors)
    for candidate in post_audit.get("candidates", []):
        raw_key = candidate.get("key", "")
        method, sep, path = raw_key.partition(" ")
        if candidate.get("resolution") == "SPECIFIED_DESIGN_ONLY":
            require(method.lower() in spec.get("paths", {}).get(path, {}),
                    f"Regressed screen supplemental operation: {raw_key}", errors)
        if candidate.get("resolution") == "REJECTED_UNSAFE_REDUNDANT":
            require(method.lower() not in spec.get("paths", {}).get(path, {}),
                    f"Unsafe access-request revocation endpoint resurrected: {raw_key}", errors)
    for path, methods in spec.get("paths", {}).items():
        for method, op in methods.items():
            if method not in {"post", "put", "patch"}:
                continue
            body = op.get("requestBody", {}).get("content", {}).get("application/json", {}).get("schema", {})
            require('"additionalProperties": true' not in json.dumps(body),
                    f"Open-ended client payload at {method.upper()} {path}", errors)
    require(all(row.get("unmatched_documented_routes") == []
                for row in post_audit.get("screen_coverage", [])),
            "At least one Figma screen references an absent method/path", errors)
    if errors:
        print("OPENAPI/SCREEN AUDIT: FAIL")
        for error in errors:
            print(" - " + error)
        return 1
    print(f"OPENAPI/SCREEN AUDIT: PASS (contract only): {operations} operations, {len(spec.get('paths', {}))} paths, {len(audit['screens'])} Figma screens, {db['tableCount']} conceptual tables")
    print("NOT A BACKEND/ANDROID BUILD, PLATFORM APPROVAL OR A DATABASE MIGRATION TEST")
    return 0

if __name__ == "__main__":
    sys.exit(main())
