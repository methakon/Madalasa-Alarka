"""The error catalog exists in three places: the doc table, the OpenAPI Error.code enum and the C++ table.
This test fails if any of them drift (code set, HTTP status, retryable default)."""
import pathlib, re, unittest
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
DOC = ROOT / "docs" / "API_CONVENTIONS_AND_ERROR_CATALOG.md"
OPENAPI = ROOT / "docs" / "openapi-m1.yaml"
CPP = ROOT / "backend" / "src" / "error_catalog.h"


def cpp_table():
    text = CPP.read_text()
    block = text.split("// SYNC-BEGIN")[1].split("// SYNC-END")[0]
    return {c: (int(s), r == "true") for c, s, r in re.findall(r'\{"([A-Z_]+)",\s*(\d+),\s*(true|false)\}', block)}


def doc_table():
    out = {}
    for line in DOC.read_text().splitlines():
        m = re.match(r"\|\s*(\d{3})\s*\|\s*`([A-Z_]+)`\s*\|\s*\**(true|false)", line)
        if m:
            out[m.group(2)] = (int(m.group(1)), m.group(3) == "true")
    return out


class ErrorCatalogSync(unittest.TestCase):
    def test_cpp_matches_doc(self):
        self.assertEqual(cpp_table(), doc_table())

    def test_cpp_matches_openapi_enum(self):
        enum = yaml.safe_load(OPENAPI.read_text())["components"]["schemas"]["Error"]["properties"]["code"]["enum"]
        self.assertEqual(set(cpp_table()), set(enum))

    def test_cpp_status_to_code_matches_linter(self):
        import sys
        sys.path.insert(0, str(ROOT / "backend" / "tests"))
        import lint_openapi_m1 as linter
        by_status = {}
        for code, (status, _) in cpp_table().items():
            by_status.setdefault(str(status), set()).add(code)
        self.assertEqual(by_status, linter.STATUS_TO_CODES)

    def test_twelve_codes(self):
        self.assertEqual(len(cpp_table()), 12)


if __name__ == "__main__":
    unittest.main()
