#!/usr/bin/env python3
"""Tests for the M1 OpenAPI linter: it must pass the real contract AND fail broken ones.

Run:  python3 backend/tests/test_lint_openapi_m1.py
Standard library only.
"""
import copy
import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lint_openapi_m1 as linter  # noqa: E402

CONTRACT = HERE.parent.parent / "docs" / "openapi-m1.yaml"
REAL = json.loads(CONTRACT.read_text(encoding="utf-8"))


def op(doc, operation_id):
    for verbs in doc["paths"].values():
        for candidate in verbs.values():
            if candidate["operationId"] == operation_id:
                return candidate
    raise KeyError(operation_id)


def errors_for(doc):
    return linter.lint(doc)[0]


class RealContract(unittest.TestCase):
    def test_real_contract_passes(self):
        self.assertEqual(errors_for(REAL), [])

    def test_http_security_schemes_are_accepted(self):
        # Regression: the first linter rejected OpenAPI's "type: http" as a JSON Schema type.
        self.assertEqual(REAL["components"]["securitySchemes"]["ParentOIDC"]["type"], "http")
        self.assertFalse([e for e in errors_for(REAL) if "securityScheme" in e or "type http" in e])

    def test_operations_do_not_share_one_copied_error_set(self):
        error_sets = set()
        for verbs in REAL["paths"].values():
            for candidate in verbs.values():
                error_sets.add(tuple(sorted(c for c in candidate["responses"] if not c.startswith("2"))))
        self.assertGreaterEqual(len(error_sets), 5)


class BrokenContractsFail(unittest.TestCase):
    def mutate(self, fn):
        doc = copy.deepcopy(REAL)
        fn(doc)
        return errors_for(doc)

    def assertFails(self, fn, fragment):
        found = self.mutate(fn)
        self.assertTrue(any(fragment in e for e in found), f"expected '{fragment}' in {found}")

    def test_invalid_schema_type(self):
        self.assertFails(lambda d: d["components"]["schemas"]["Receipt"]["properties"]["id"]
                         .update(type="strin"), "invalid JSON Schema type")

    def test_bad_security_scheme_type(self):
        self.assertFails(lambda d: d["components"]["securitySchemes"]["DeviceBearer"]
                         .update(type="basic"), "invalid type")

    def test_http_scheme_without_scheme(self):
        self.assertFails(lambda d: d["components"]["securitySchemes"]["DeviceBearer"]
                         .pop("scheme"), "http scheme required")

    def test_get_with_413(self):
        def go(d):
            op(d, "getChild")["responses"]["413"] = copy.deepcopy(op(d, "getChild")["responses"]["404"])
        self.assertFails(go, "413 cannot occur on an operation without a request body")

    def test_gone_on_a_list(self):
        def go(d):
            op(d, "listChildren")["responses"]["410"] = copy.deepcopy(op(d, "listChildren")["responses"]["404"])
        self.assertFails(go, "410")

    def test_missing_429(self):
        self.assertFails(lambda d: op(d, "getChild")["responses"].pop("429"), "missing 429")

    def test_missing_400_when_operation_takes_input(self):
        self.assertFails(lambda d: op(d, "getChild")["responses"].pop("400"), "declares no 400")

    def test_400_on_operation_without_input(self):
        def go(d):
            op(d, "listFamilies")["responses"]["400"] = copy.deepcopy(op(d, "getChild")["responses"]["400"])
        self.assertFails(go, "400 cannot occur")

    def test_authenticated_operation_without_401(self):
        self.assertFails(lambda d: op(d, "getChild")["responses"].pop("401"), "must declare 401")

    def test_unexpected_anonymous_route(self):
        self.assertFails(lambda d: op(d, "getChild").update(security=[]), "anonymous route")

    def test_error_response_must_use_error_schema(self):
        def go(d):
            op(d, "getChild")["responses"]["404"]["content"]["application/json"]["schema"] = {"type": "object"}
        self.assertFails(go, "shared Error schema")

    def test_undefined_security_scheme(self):
        self.assertFails(lambda d: op(d, "getChild").update(security=[{"Nope": []}]), "undefined security scheme")

    def test_object_schema_must_forbid_extra_fields(self):
        self.assertFails(lambda d: d["components"]["schemas"]["Receipt"].pop("additionalProperties"),
                         "enforce explicit fields")

    def test_non_https_server(self):
        self.assertFails(lambda d: d["servers"][0].update(url="http://api.example.invalid/v1"), "HTTPS")

    def test_extra_operation_is_rejected(self):
        def go(d):
            d["paths"]["/extra"] = {"get": copy.deepcopy(op(d, "getChild"))}
            d["paths"]["/extra"]["get"]["operationId"] = "extra"
            d["paths"]["/extra"]["get"]["parameters"] = []
        self.assertFails(go, "not a permitted M1 operation")

    def test_unresolved_schema_ref(self):
        def go(d):
            d["components"]["schemas"]["Receipt"]["properties"]["id"] = {"$ref": "#/components/schemas/Missing"}
        self.assertFails(go, "unresolved ref")

    def test_property_named_type_is_not_a_false_positive(self):
        def go(d):
            d["components"]["schemas"]["Receipt"]["properties"]["type"] = {"type": "string"}
        self.assertEqual(self.mutate(go), [])

    def test_every_response_needs_request_id_header(self):
        self.assertFails(lambda d: op(d, "getChild")["responses"]["404"]["headers"].pop("X-Request-Id"),
                         "X-Request-Id")

    def test_429_needs_retry_after(self):
        self.assertFails(lambda d: op(d, "getChild")["responses"]["429"]["headers"].pop("Retry-After"),
                         "Retry-After")

    def test_error_code_enum_must_match_catalog(self):
        self.assertFails(lambda d: d["components"]["schemas"]["Error"]["properties"]["code"]["enum"].append("MADE_UP"),
                         "Error.code enum")

    def test_error_code_must_be_an_enum(self):
        self.assertFails(lambda d: d["components"]["schemas"]["Error"]["properties"]["code"].pop("enum"),
                         "Error.code enum")

    def test_retryable_create_needs_idempotency_key(self):
        self.assertFails(lambda d: op(d, "createChild").update(parameters=[
            p for p in op(d, "createChild")["parameters"] if "$ref" not in p]), "Idempotency-Key")

    def test_unresolved_header_ref(self):
        def go(d):
            op(d, "getChild")["responses"]["404"]["headers"]["X-Request-Id"] = {"$ref": "#/components/headers/Nope"}
        self.assertFails(go, "unresolved ref")

class StatusToErrorCode(unittest.TestCase):
    """G-6: every error response declares which catalog codes it can carry, and the status must permit them."""

    def broken(self, operation_id, status, codes):
        doc = copy.deepcopy(REAL)
        op(doc, operation_id)["responses"][status]["x-error-codes"] = codes
        return errors_for(doc)

    def test_wrong_code_for_status(self):
        self.assertTrue(any("cannot carry error code NOT_FOUND" in e for e in self.broken("getChild", "401", ["NOT_FOUND"])))

    def test_missing_declaration(self):
        doc = copy.deepcopy(REAL)
        del op(doc, "getChild")["responses"]["404"]["x-error-codes"]
        self.assertTrue(any("must declare x-error-codes" in e for e in errors_for(doc)))

    def test_empty_and_duplicate_declarations(self):
        self.assertTrue(any("must declare x-error-codes" in e for e in self.broken("getChild", "404", [])))
        self.assertTrue(any("duplicates" in e for e in self.broken("getChild", "404", ["NOT_FOUND", "NOT_FOUND"])))

    def test_unknown_status(self):
        doc = copy.deepcopy(REAL)
        op(doc, "getChild")["responses"]["418"] = copy.deepcopy(op(doc, "getChild")["responses"]["404"])
        self.assertTrue(any("status 418 is not in the error catalog" in e for e in errors_for(doc)))

    def test_idempotency_code_only_on_retryable_creates(self):
        # No non-create operation has to declare a 409 (G-5 removed them), so add one to a read operation.
        doc = copy.deepcopy(REAL)
        responses = op(doc, "getChild")["responses"]
        responses["409"] = copy.deepcopy(responses["404"])
        responses["409"]["x-error-codes"] = ["CONFLICT", "IDEMPOTENCY_KEY_REUSED"]
        self.assertTrue(any("only applies to the retryable creates" in e for e in errors_for(doc)))

    def test_retryable_create_409_must_include_key_reuse(self):
        self.assertTrue(any("must include IDEMPOTENCY_KEY_REUSED" in e for e in self.broken("createFamily", "409", ["CONFLICT"])))

    def test_every_real_error_response_is_declared(self):
        for url, verbs in REAL["paths"].items():
            for method, o in verbs.items():
                for status, r in o["responses"].items():
                    if not status.startswith("2"):
                        self.assertIn("x-error-codes", r, f"{method} {url} {status}")


class DocumentationInSync(unittest.TestCase):
    def test_error_catalog_document_lists_exactly_the_linted_codes(self):
        text = (HERE.parent.parent / "docs" / "API_CONVENTIONS_AND_ERROR_CATALOG.md").read_text(encoding="utf-8")
        table = text.split("### 5.2 Catalog")[1].split("### 5.3")[0]
        documented = set()
        for line in table.splitlines():
            cells = [c.strip() for c in line.split("|")]
            if len(cells) > 3 and cells[1].isdigit():
                documented.add(cells[2].strip("`"))
        self.assertEqual(documented, linter.ERROR_CODES)

    def test_status_to_code_table_matches_the_document(self):
        text = (HERE.parent.parent / "docs" / "API_CONVENTIONS_AND_ERROR_CATALOG.md").read_text(encoding="utf-8")
        table = text.split("### 5.2 Catalog")[1].split("### 5.3")[0]
        documented = {}
        for line in table.splitlines():
            cells = [c.strip() for c in line.split("|")]
            if len(cells) > 3 and cells[1].isdigit():
                documented.setdefault(cells[1], set()).add(cells[2].strip("`"))
        self.assertEqual(documented, linter.STATUS_TO_CODES)


if __name__ == "__main__":
    unittest.main(verbosity=2)
