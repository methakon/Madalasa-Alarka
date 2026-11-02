#!/usr/bin/env python3
"""Local, loopback-only Swagger UI for Madalasa-Alarka OpenAPI 3.1.
No production Drogon route is added. Try-it-out is opt-in and M1-only.
Synthetic data and credentials ONLY.
"""
from __future__ import annotations
import argparse
from functools import partial
from http import HTTPStatus
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"
ASSETS = ROOT / "backend/swagger/node_modules/swagger-ui-dist"
ASSET_NAMES = frozenset(("swagger-ui.css", "swagger-ui-bundle.js",
                         "swagger-ui-standalone-preset.js",
                         "favicon-16x16.png", "favicon-32x32.png"))
CSP = ("default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; "
       "img-src 'self' data:; font-src 'self' data:; connect-src 'self'; "
       "base-uri 'none'; object-src 'none'; frame-ancestors 'none'; form-action 'none'")
MAX_BODY_BYTES = 65536


def spec_path(mode: str, docs_dir: Path = DOCS) -> Path:
    if mode not in ("m1", "planned"):
        raise ValueError("invalid Swagger documentation mode")
    return docs_dir / ("openapi-m1.yaml" if mode == "m1" else "openapi.yaml")


def local_spec(mode: str, docs_dir: Path = DOCS) -> dict:
    # The .yaml files are JSON-encoded valid YAML. Overlay the local proxy
    # server only in memory, without changing frozen source specifications.
    with spec_path(mode, docs_dir).open(encoding="utf-8") as src:
        spec = json.load(src)
    if spec.get("openapi") != "3.1.0":
        raise ValueError("unsupported OpenAPI version")
    spec["servers"] = [{"url": "/v1", "description": "LOCAL Swagger development proxy"}]
    if mode == "planned":
        spec["info"]["title"] += " — DESIGN ONLY, NOT IMPLEMENTED"
        spec["info"]["description"] = (
            "DESIGN ONLY. Swagger execution is disabled for all planned operations.\n\n"
            + spec["info"].get("description", ""))
    return spec


def m1_patterns(docs_dir: Path = DOCS) -> tuple:
    result = []
    for path, methods in local_spec("m1", docs_dir)["paths"].items():
        escaped = re.escape("/v1" + path)
        # UUID-bound path parameters, not arbitrary API route patterns.
        escaped = re.sub(r"\\\{[^}]+\\\}", r"[0-9A-Fa-f-]{36}", escaped)
        for method in methods:
            if method.lower() in ("get", "post", "delete", "put", "patch"):
                result.append((method.upper(), re.compile("^" + escaped + "$")))
    return tuple(result)


def page(mode: str, enabled: bool) -> bytes:
    if mode not in ("m1", "planned"):
        raise ValueError("invalid Swagger page")
    title = "M1 FROZEN CONTRACT (14 operations)" if mode == "m1" else "WIDER API — DESIGN ONLY"
    warning = ("Try it out is enabled for frozen M1 routes only."
               if enabled and mode == "m1" else "Read-only Swagger documentation; Try it out disabled.")
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Madalasa-Alarka Swagger — {title}</title>
<link rel="stylesheet" href="/swagger/assets/swagger-ui.css"></head>
<body><header style="padding:12px 24px;font-family:sans-serif;background:#f4f6f8">
<strong>Madalasa–Alarka LOCAL Swagger UI</strong>
<nav><a href="/swagger/m1">Frozen M1</a> ·
<a href="/swagger/planned">Planned Figma API — NOT IMPLEMENTED</a></nav>
<p>{title}. {warning} Synthetic data only. Never paste real child data or live credentials.</p>
</header><div id="swagger-ui"></div>
<script src="/swagger/assets/swagger-ui-bundle.js"></script>
<script src="/swagger/assets/swagger-ui-standalone-preset.js"></script>
<script src="/swagger/{mode}/config.js"></script></body></html>""".encode("utf-8")


def config(mode: str, enabled: bool) -> bytes:
    if mode not in ("m1", "planned"):
        raise ValueError("invalid Swagger configuration")
    spec_url = "/swagger/spec/m1.json" if mode == "m1" else "/swagger/spec/planned.json"
    allow = ["get", "post", "delete"] if enabled and mode == "m1" else []
    return ("window.onload = function() {\n"
            " window.ui = SwaggerUIBundle({\n"
            f"  url: {json.dumps(spec_url)},\n"
            "  dom_id: '#swagger-ui',\n"
            "  presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],\n"
            "  layout: 'StandaloneLayout',\n"
            "  validatorUrl: null,\n"
            "  queryConfigEnabled: false,\n"
            "  persistAuthorization: false,\n"
            "  displayRequestDuration: true,\n"
            "  deepLinking: false,\n"
            f"  supportedSubmitMethods: {json.dumps(allow)},\n"
            " });\n};\n").encode("utf-8")


class LocalSwaggerHandler(BaseHTTPRequestHandler):
    """Fixed loopback proxy; never routes production docs or arbitrary URLs."""
    protocol_version = "HTTP/1.0"
    server_version = "MA-LocalSwagger/1.0"
    sys_version = ""

    def __init__(self, *args, docs_dir: Path = DOCS, assets_dir: Path = ASSETS,
                 backend_port: int = 8080, allow_calls: bool = False, **kwargs):
        self.docs_dir, self.assets_dir = docs_dir, assets_dir
        self.backend_port, self.allow_calls = backend_port, allow_calls
        self.patterns = m1_patterns(docs_dir)
        super().__init__(*args, **kwargs)

    def log_message(self, _format, *_args):
        # Never log a bearer, key, URL query, or real/synthetic profile.
        pass

    def reply(self, status: int, body: bytes, mime: str, headers: dict | None = None):
        self.send_response(status)
        for name, value in (
            ("Content-Type", mime), ("Content-Length", str(len(body))),
            ("Cache-Control", "no-store"), ("X-Content-Type-Options", "nosniff"),
            ("Referrer-Policy", "no-referrer"), ("Content-Security-Policy", CSP)):
            self.send_header(name, value)
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlsplit(self.path)
        if url.scheme or url.netloc or (url.query and not url.path.startswith("/v1/")):
            return self.reply(400, b"invalid URL", "text/plain")
        path = url.path
        if path in ("/", "/swagger", "/swagger/"):
            return self.reply(302, b"", "text/plain", {"Location": "/swagger/m1"})
        if path in ("/swagger/m1", "/swagger/planned"):
            return self.reply(200, page(path.split("/")[-1], self.allow_calls), "text/html; charset=utf-8")
        if path in ("/swagger/spec/m1.json", "/swagger/spec/planned.json"):
            mode = "m1" if path.endswith("m1.json") else "planned"
            result = json.dumps(local_spec(mode, self.docs_dir),
                                ensure_ascii=False, separators=(",", ":")).encode("utf-8")
            return self.reply(200, result, "application/json; charset=utf-8")
        if path in ("/swagger/m1/config.js", "/swagger/planned/config.js"):
            # Page path, not Referer or user-supplied query, selects read-only mode.
            return self.reply(200, config(path.split("/")[2], self.allow_calls), "text/javascript")
        if path.startswith("/swagger/assets/"):
            name = path.removeprefix("/swagger/assets/")
            if name not in ASSET_NAMES:
                return self.reply(404, b"not found", "text/plain")
            asset = self.assets_dir / name
            if not asset.is_file():
                return self.reply(503, b"Install Swagger assets: cd backend/swagger && npm install --ignore-scripts",
                                  "text/plain")
            mime = ("text/css" if name.endswith(".css") else
                    "text/javascript" if name.endswith(".js") else "image/png")
            return self.reply(200, asset.read_bytes(), mime)
        if path.startswith("/v1/"):
            return self.proxy("GET", url)
        return self.reply(404, b"not found", "text/plain")

    def do_POST(self):
        return self.proxy("POST", urlsplit(self.path))

    def do_DELETE(self):
        return self.proxy("DELETE", urlsplit(self.path))

    def do_PUT(self):
        return self.proxy("PUT", urlsplit(self.path))

    def do_PATCH(self):
        return self.proxy("PATCH", urlsplit(self.path))

    def proxy(self, method, url):
        if not self.allow_calls:
            return self.reply(403, b"Try it out disabled: explicit local developer opt-in required",
                              "text/plain")
        if (url.scheme or url.netloc or
            not any(method == verb and pattern.fullmatch(url.path)
                    for verb, pattern in self.patterns)):
            return self.reply(403, b"Not a frozen M1 operation", "text/plain")
        if self.headers.get("Transfer-Encoding"):
            return self.reply(400, b"chunked requests prohibited", "text/plain")
        length = self.headers.get("Content-Length", "0")
        if not length.isdigit():
            return self.reply(400, b"invalid Content-Length", "text/plain")
        size = int(length)
        if size > MAX_BODY_BYTES:
            return self.reply(413, b"body exceeds local API limit", "text/plain")
        body = self.rfile.read(size) if size else None
        # Never forward Cookies, Host, X-Forwarded-* or unknown headers.
        headers = {key: self.headers[key] for key in
                   ("Authorization", "Accept", "Content-Type", "Idempotency-Key")
                   if self.headers.get(key)}
        upstream = HTTPConnection("127.0.0.1", self.backend_port, timeout=6)
        try:
            upstream.request(method, url.path + ("?" + url.query if url.query else ""),
                             body=body, headers=headers)
            response = upstream.getresponse()
            payload = response.read(MAX_BODY_BYTES + 1)
            if len(payload) > MAX_BODY_BYTES:
                return self.reply(502, b"upstream response exceeds limit", "text/plain")
            echoed = {}
            rid = response.getheader("X-Request-Id")
            if rid and re.fullmatch(r"[A-Za-z0-9-]{1,80}", rid):
                echoed["X-Request-Id"] = rid
            mime = response.getheader("Content-Type", "application/json")
            if not (mime.startswith("application/json") or mime.startswith("text/plain")):
                mime = "application/octet-stream"
            return self.reply(response.status, payload, mime, echoed)
        except (OSError, TimeoutError):
            return self.reply(502, b"local Drogon backend unavailable", "text/plain")
        finally:
            upstream.close()


def make_server(port: int, *, docs_dir: Path = DOCS, assets_dir: Path = ASSETS,
                backend_port: int = 8080, allow_calls: bool = False):
    if not (0 <= port <= 65535 and 1 <= backend_port <= 65535):
        raise ValueError("invalid port")
    handler = partial(LocalSwaggerHandler, docs_dir=docs_dir, assets_dir=assets_dir,
                      backend_port=backend_port, allow_calls=allow_calls)
    # Deliberately fixed IPv4 loopback, not configurable via environment.
    return ThreadingHTTPServer(("127.0.0.1", port), handler)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--backend-port", type=int, default=8080)
    ap.add_argument("--enable-try-it-out", action="store_true")
    args = ap.parse_args()
    with make_server(args.port, backend_port=args.backend_port,
                     allow_calls=args.enable_try_it_out) as server:
        print(f"Swagger M1: http://127.0.0.1:{server.server_port}/swagger/m1")
        print(f"Design-only: http://127.0.0.1:{server.server_port}/swagger/planned")
        print("Synthetic only; Try it out " + ("M1-only" if args.enable_try_it_out else "DISABLED"))
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
