#!/usr/bin/env python3
"""Offline strict structural linter for the M1 OpenAPI 3.1 contract (JSON-as-YAML).

Purpose: no network or pip required. Not a full OpenAPI conformance validator;
CI can additionally run Redocly/Spectral/openapi-spec-validator later.

Usage:  python3 backend/tests/lint_openapi_m1.py docs/openapi-m1.yaml
The rules are exercised against deliberately broken contracts by
backend/tests/test_lint_openapi_m1.py, so the linter itself is tested.
"""
import json
import re
import sys
from pathlib import Path

EXPECTED_OPERATIONS = {
    "createFamily", "listFamilies", "createChild", "listChildren", "getChild",
    "listChildDevices", "issuePairingCode", "redeemEnrollmentCode",
    "finishEnrollmentProof", "requestCredentialChallenge", "renewDeviceCredential",
    "recordCapabilities", "recordHealth", "revokeDevice",
}
# Routes that cannot carry a bearer credential: the device has no token yet
# (enrollment) or its short-lived token has expired (renewal). They are
# protected by single-use proofs and rate limits instead.
ANONYMOUS_ROUTES = {
    "/enrollment",
    "/enrollment/{enrollmentId}/proof",
    "/devices/{deviceId}/credential/challenge",
    "/devices/{deviceId}/credential/renew",
}
# 410 means "this one-time code or challenge is expired or already used".
GONE_OPERATIONS = {"redeemEnrollmentCode", "finishEnrollmentProof"}
# Status codes that cannot occur on an operation that takes no request body.
BODYLESS_FORBIDDEN = {"410", "413", "422"}
SECURITY_SCHEME_TYPES = {"apiKey", "http", "oauth2", "openIdConnect", "mutualTLS"}
JSON_SCHEMA_TYPES = {"null", "integer", "number", "boolean", "string", "array", "object"}
HTTP_VERBS = {"get", "post", "put", "patch", "delete"}
# Must equal Error.code's enum and the catalog in docs/API_CONVENTIONS_AND_ERROR_CATALOG.md.
# Which error codes each HTTP status may carry (docs/API_CONVENTIONS_AND_ERROR_CATALOG.md section 5.2).
# backend/tests/test_error_catalog_sync.py keeps this equal to the document table and the C++ catalog.
STATUS_TO_CODES = {
    "400": {"INVALID_REQUEST"},
    "401": {"UNAUTHENTICATED"},
    "403": {"FORBIDDEN"},
    "404": {"NOT_FOUND"},
    "409": {"CONFLICT", "IDEMPOTENCY_KEY_REUSED"},
    "410": {"CODE_EXPIRED_OR_USED"},
    "413": {"PAYLOAD_TOO_LARGE"},
    "422": {"VALIDATION_FAILED"},
    "429": {"RATE_LIMITED"},
    "500": {"INTERNAL_ERROR"},
    "503": {"SERVICE_UNAVAILABLE"},
}
ERROR_CODES = set().union(*STATUS_TO_CODES.values())
# Creates that a mobile client may retry after a lost response: a retry must not create a duplicate.
IDEMPOTENT_CREATES = {"createFamily", "createChild", "issuePairingCode"}
REF_KINDS = {"schemas", "headers", "parameters"}


def lint(doc):
    """Return (errors, operation_count, operation_ids, schema_count)."""
    errors = []

    def check(cond, message):
        if not cond:
            errors.append(message)

    check(doc.get("openapi") == "3.1.0", "OpenAPI version must be 3.1.0")
    servers = doc.get("servers")
    check(bool(servers) and all(
        isinstance(s.get("url"), str) and s["url"].startswith("https://")
        for s in servers or []), "M1 servers require HTTPS")
    components = doc.get("components", {})
    schemas = components.get("schemas", {})
    security = components.get("securitySchemes", {})
    check("ParentOIDC" in security and "DeviceBearer" in security, "Missing M1 auth schemes")

    # Security schemes use OpenAPI's own vocabulary (type: http), not JSON Schema's.
    for name, scheme in security.items():
        stype = scheme.get("type")
        check(stype in SECURITY_SCHEME_TYPES, f"securityScheme {name}: invalid type {stype}")
        if stype == "http":
            check(bool(scheme.get("scheme")), f"securityScheme {name}: http scheme required")

    ids = []
    operations = 0
    for url, verbs in doc.get("paths", {}).items():
        check(url.startswith("/") and "?" not in url, f"Invalid route: {url}")
        for method, op in verbs.items():
            operations += 1
            where = f"{method.upper()} {url}"
            check(method in HTTP_VERBS, f"{where}: invalid verb")
            oid = op.get("operationId")
            ids.append(oid)
            check(oid in EXPECTED_OPERATIONS, f"{where}: not a permitted M1 operation {oid}")
            check(bool(op.get("tags")) and bool(op.get("summary")), f"{where}: tags/summary required")
            check("x-required-scope" in op, f"{where}: missing child/action scope declaration")
            check("security" in op, f"{where}: explicit principal security required")
            sec = op.get("security")
            if sec:
                for requirement in sec:
                    for name in requirement:
                        check(name in security, f"{where}: undefined security scheme {name}")
            else:
                check(url in ANONYMOUS_ROUTES,
                      f"{where}: anonymous route beyond narrow pairing/proof/renewal")
            has_body = "requestBody" in op
            if method in {"post", "put", "patch"}:
                check(op.get("requestBody", {}).get("required") is True,
                      f"{where}: write operation requires typed body")
            declared = set(re.findall(r"\{(\w+)\}", url))
            actual = {p.get("name") for p in op.get("parameters", []) if p.get("in") == "path"}
            check(declared == actual, f"{where}: path params {declared} != {actual}")

            codes = op.get("responses", {})
            check(any(x in codes for x in ("200", "201", "202", "204")), f"{where}: no success")
            check("429" in codes, f"{where}: missing 429 response")
            for code, response in codes.items():
                hdrs = response.get("headers", {})
                check("X-Request-Id" in hdrs, f"{where}: {code} must declare the X-Request-Id header")
                if code == "429":
                    check("Retry-After" in hdrs, f"{where}: 429 must declare the Retry-After header")
            if oid in IDEMPOTENT_CREATES:
                refs = [p.get("$ref") for p in op.get("parameters", [])]
                check("#/components/parameters/IdempotencyKey" in refs,
                      f"{where}: retryable create must take the Idempotency-Key header")
            if has_body or op.get("parameters"):
                check("400" in codes, f"{where}: operation takes input but declares no 400")
            else:
                check("400" not in codes, f"{where}: 400 cannot occur on an operation without input")
            if sec:
                check("401" in codes, f"{where}: authenticated operation must declare 401")
            if not has_body:
                for bad in sorted(BODYLESS_FORBIDDEN & set(codes)):
                    errors.append(f"{where}: {bad} cannot occur on an operation without a request body")
            if "410" in codes:
                check(oid in GONE_OPERATIONS,
                      f"{where}: 410 is reserved for expired/used one-time enrollment codes")
            for code, response in codes.items():
                if code.startswith("2"):
                    continue
                allowed = STATUS_TO_CODES.get(code)
                check(allowed is not None, f"{where}: status {code} is not in the error catalog")
                declared_codes = response.get("x-error-codes")
                if not isinstance(declared_codes, list) or not declared_codes:
                    errors.append(f"{where}: {code} must declare x-error-codes (the catalog codes it can return)")
                elif allowed is not None:
                    check(len(declared_codes) == len(set(declared_codes)), f"{where}: {code} x-error-codes has duplicates")
                    for c in declared_codes:
                        check(c in allowed, f"{where}: {code} cannot carry error code {c}; allowed {sorted(allowed)}")
                    if "IDEMPOTENCY_KEY_REUSED" in declared_codes:
                        check(oid in IDEMPOTENT_CREATES,
                              f"{where}: IDEMPOTENCY_KEY_REUSED only applies to the retryable creates")
                    if code == "409" and oid in IDEMPOTENT_CREATES:
                        check("IDEMPOTENCY_KEY_REUSED" in declared_codes,
                              f"{where}: 409 on a retryable create must include IDEMPOTENCY_KEY_REUSED")
            for code, response in codes.items():
                if not code.startswith("2"):
                    ref = (response.get("content", {}).get("application/json", {})
                           .get("schema", {}).get("$ref"))
                    check(ref == "#/components/schemas/Error",
                          f"{where}: {code} must use the shared Error schema")

    check(operations == len(EXPECTED_OPERATIONS),
          f"Expected exactly {len(EXPECTED_OPERATIONS)} M1 operations, got {operations}")
    check(set(ids) == EXPECTED_OPERATIONS and len(ids) == len(set(ids)),
          f"Expected unique exact operationId set: {EXPECTED_OPERATIONS ^ set(ids)}")

    err_codes = schemas.get("Error", {}).get("properties", {}).get("code", {}).get("enum")
    check(isinstance(err_codes, list) and set(err_codes) == ERROR_CODES and len(err_codes) == len(set(err_codes)),
          f"Error.code enum must equal the documented catalog: {sorted(ERROR_CODES)}")

    for name, schema in schemas.items():
        if schema.get("type") == "object":
            req = schema.get("required")
            check(isinstance(req, list), f"{name}: missing required[]")
            if isinstance(req, list):
                check(len(req) == len(set(req)), f"{name}: duplicate required")
                check(set(req).issubset(set(schema.get("properties", {}))),
                      f"{name}: required fields not declared")
            check(schema.get("additionalProperties") is False,
                  f"{name}: enforce explicit fields")

    def walk(value, at="root"):
        if isinstance(value, dict):
            if "$ref" in value:
                ref = value["$ref"]
                parts = ref.split("/") if isinstance(ref, str) else []
                ok = (len(parts) == 4 and parts[:2] == ["#", "components"] and parts[2] in REF_KINDS
                      and parts[3] in components.get(parts[2], {}))
                check(ok, f"{at}: unresolved ref {ref}")
            ty = value.get("type")
            # A property that happens to be NAMED "type" holds a dict, not a type keyword.
            if isinstance(ty, (str, list)):
                items = [ty] if isinstance(ty, str) else ty
                check(all(x in JSON_SCHEMA_TYPES for x in items),
                      f"{at}: invalid JSON Schema type {ty}")
            if isinstance(value.get("required"), str):
                errors.append(f"{at}: required field must be array")
            for k, v in value.items():
                walk(v, at + "/" + str(k))
        elif isinstance(value, list):
            for i, v in enumerate(value):
                walk(v, at + f"/{i}")

    scan = dict(doc)
    scan_components = dict(components)
    scan_components.pop("securitySchemes", None)  # validated above with OpenAPI rules
    scan["components"] = scan_components
    walk(scan)
    return errors, operations, ids, len(schemas)


def main(argv):
    path = Path(argv[1] if len(argv) > 1 else "docs/openapi-m1.yaml")
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"FAIL: unreadable JSON/YAML subset {path}: {exc}", file=sys.stderr)
        return 1
    errors, operations, ids, schema_count = lint(doc)
    if errors:
        for error in errors:
            print("FAIL:", error, file=sys.stderr)
        print(f"M1 OpenAPI FAIL ({len(errors)} errors; {operations} operations)", file=sys.stderr)
        return 1
    print(f"M1 OpenAPI structural lint PASS ({operations} M1 operations, "
          f"{schema_count} schemas, {len(ids)} unique operationIds)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
