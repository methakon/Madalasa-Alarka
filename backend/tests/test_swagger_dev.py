#!/usr/bin/env python3
"""Synthetic-only Swagger UI, fixed-target proxy and OpenAPI regression tests."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from importlib.util import module_from_spec, spec_from_file_location
from tempfile import TemporaryDirectory
from threading import Thread
import unittest
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[2]
spec = spec_from_file_location("ma_swagger_dev", ROOT / "backend/scripts/swagger_dev.py")
mod = module_from_spec(spec)
spec.loader.exec_module(mod)


class FakeDrogon(BaseHTTPRequestHandler):
    seen = []
    def log_message(self, *_args): pass
    def do_GET(self): self.reply()
    def do_POST(self): self.reply()
    def do_DELETE(self): self.reply()
    def reply(self):
        n = int(self.headers.get("Content-Length", "0"))
        content = self.rfile.read(n) if n else b""
        self.seen.append((self.command, self.path, self.headers.get("Authorization"),
                          self.headers.get("Cookie"), content))
        response = json.dumps({"synthetic": True}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("X-Request-Id", "00000000-0000-4000-8000-000000000001")
        self.send_header("Set-Cookie", "secret=do-not-proxy")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)


class SwaggerLocalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = TemporaryDirectory(prefix="swagger-synthetic-")
        cls.assets = Path(cls.tmp.name)
        for name in ("swagger-ui.css", "swagger-ui-bundle.js", "swagger-ui-standalone-preset.js"):
            (cls.assets / name).write_text("/* synthetic asset fixture */")
        cls.backend = ThreadingHTTPServer(("127.0.0.1", 0), FakeDrogon)
        cls.bthread = Thread(target=cls.backend.serve_forever, daemon=True)
        cls.bthread.start()
        cls.docs = mod.make_server(0, assets_dir=cls.assets,
                                   backend_port=cls.backend.server_port)
        cls.dthread = Thread(target=cls.docs.serve_forever, daemon=True)
        cls.dthread.start()

    @classmethod
    def tearDownClass(cls):
        cls.docs.shutdown()
        cls.docs.server_close()
        cls.backend.shutdown()
        cls.backend.server_close()
        cls.tmp.cleanup()

    def get(self, path, *, method="GET", port=None, body=None, headers=None):
        base = f"http://127.0.0.1:{port or self.docs.server_port}"
        request = Request(base + path, data=body, method=method, headers=headers or {})
        try:
            with urlopen(request, timeout=3) as response:
                return response.status, response.read(), dict(response.headers)
        except HTTPError as error:
            return error.code, error.read(), dict(error.headers)

    def test_openapi_m1_is_frozen_and_planned_is_separate(self):
        count = lambda s: sum(1 for methods in s["paths"].values()
                              for method in methods if method in {"get","post","put","patch","delete"})
        for mode in ("m1", "planned"):
            status, contents, headers = self.get(f"/swagger/spec/{mode}.json")
            self.assertEqual(status, 200)
            contract = json.loads(contents)
            self.assertEqual(contract["openapi"], "3.1.0")
            self.assertEqual(contract["servers"][0]["url"], "/v1")
            self.assertEqual(headers["Cache-Control"], "no-store")
            if mode == "m1":
                self.assertEqual(count(contract), 14)
            else:
                self.assertGreater(count(contract), 14)
                self.assertIn("DESIGN ONLY", contract["info"]["title"])
        original = json.loads((ROOT / "docs/openapi-m1.yaml").read_text())
        self.assertEqual(original["servers"][0]["url"], "https://api.example.invalid/v1")

    def test_browser_assets_are_local_with_csp(self):
        status, page, headers = self.get("/swagger/m1")
        self.assertEqual(status, 200)
        self.assertIn(b'/swagger/m1/config.js', page)
        self.assertIn(b"Read-only Swagger documentation", page)
        self.assertNotIn(b"cdn.", page)
        self.assertIn("connect-src 'self'", headers["Content-Security-Policy"])
        self.assertEqual(headers["X-Content-Type-Options"], "nosniff")
        self.assertEqual(self.get("/swagger/assets/swagger-ui.css")[0], 200)
        self.assertEqual(self.get("/swagger/assets/../../config.json")[0], 404)
        self.assertEqual(self.get("/swagger/assets/secrets.env")[0], 404)

    def test_read_only_by_default_and_planned_never_executable(self):
        self.assertIn(b"supportedSubmitMethods: []", self.get("/swagger/m1/config.js")[1])
        self.assertIn(b"supportedSubmitMethods: []", self.get("/swagger/planned/config.js")[1])
        self.assertIn(b"validatorUrl: null", self.get("/swagger/m1/config.js")[1])
        self.assertIn(b"/swagger/planned/config.js", self.get("/swagger/planned")[1])
        FakeDrogon.seen.clear()
        status, body, _ = self.get("/v1/families")
        self.assertEqual(status, 403)
        self.assertEqual(FakeDrogon.seen, [])

    def test_m1_approved_methods_only_when_opted_in(self):
        with mod.make_server(0, assets_dir=self.assets,
                             backend_port=self.backend.server_port,
                             allow_calls=True) as server:
            thread = Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                port = server.server_port
                self.assertIn(b'supportedSubmitMethods: ["get", "post", "delete"]',
                              self.get("/swagger/m1/config.js", port=port)[1])
                self.assertIn(b"supportedSubmitMethods: []",
                              self.get("/swagger/planned/config.js", port=port)[1])
                FakeDrogon.seen.clear()
                result = self.get("/v1/families", port=port,
                                  headers={"Authorization": "Bearer synthetic-only",
                                           "Cookie": "do-not-forward=true"})
                self.assertEqual(result[0], 200)
                self.assertTrue(json.loads(result[1])["synthetic"])
                self.assertEqual(FakeDrogon.seen[-1][2], "Bearer synthetic-only")
                self.assertIsNone(FakeDrogon.seen[-1][3])
                self.assertNotIn("Set-Cookie", result[2])
                self.assertEqual(result[2]["X-Request-Id"], "00000000-0000-4000-8000-000000000001")
                self.assertEqual(self.get("/v1/families", method="PATCH", port=port)[0], 403)
                self.assertEqual(self.get("/v1/billing/products", port=port)[0], 403)
                self.assertEqual(self.get("/v1/devices/00000000-0000-4000-8000-000000000002/locations:batch",
                                          method="POST", body=b"{}", port=port)[0], 403)
                self.assertEqual(self.get("/v1/families", method="POST",
                                          body=b"a" * (65536 + 1), port=port)[0], 413)
                self.assertEqual(self.get("/v1/families", method="POST",
                                          body=b"{}", port=port)[0], 200)
            finally:
                server.shutdown()
                thread.join(timeout=5)

    def test_paths_and_modes_fail_closed(self):
        self.assertEqual(len(mod.m1_patterns()), 14)
        self.assertTrue(any(v == "GET" and p.fullmatch("/v1/families")
                            for v,p in mod.m1_patterns()))
        self.assertTrue(any(v == "POST" and p.fullmatch(
            "/v1/families/00000000-0000-4000-8000-000000000002/children")
            for v,p in mod.m1_patterns()))
        with self.assertRaises(ValueError): mod.local_spec("untrusted")
        with self.assertRaises(ValueError): mod.config("untrusted", True)
        with self.assertRaises(ValueError): mod.make_server(1, backend_port=0)


if __name__ == "__main__":
    unittest.main()
