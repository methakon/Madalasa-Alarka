#!/usr/bin/env python3
"""Non-destructive, credential-free PUBLIC staging HTTP security baseline.

Run only on owner-authorized Madalasa-Alarka staging. One GET per check,
sequentially, no brute-force, redirects, mutation, credential use or crawling.
This test asserts public HTTP routing, status codes, and mandatory security
headers (nosniff, no-referrer, HSTS, frame options, CSP on admin, no-store on APIs).
It certifies selected public HTTP boundary posture; tenant isolation and PostgreSQL
RLS require authenticated multi-family integration tests.
"""
import http.client
import json
import os
import ssl
import sys
import time
from urllib.parse import urlsplit

TARGETS = {
    "admin": "https://madalasa.berhampore.in",
    "api": "https://api.madalasa.berhampore.in",
}
# Public GETs only. Negative tests must not mutate state.
CHECKS = [
    ("admin_home", "admin", "/", {200}),
    ("admin_blocks_capabilities", "admin", "/v1/release/capabilities", {404}),
    ("admin_blocks_child_signals", "admin", "/v1/children/00000000-0000-4000-8000-000000000000/signals", {404}),
    ("admin_blocks_device_signals", "admin", "/v1/devices/00000000-0000-4000-8000-000000000000/signals/00000000-0000-4000-8000-000000000000/status", {404}),
    ("api_healthz", "api", "/healthz", {200}),
    ("api_capabilities", "api", "/v1/release/capabilities", {200}),
    ("api_blocks_admin", "api", "/v1/admin/auth/session", {404}),
    ("api_blocks_admin_challenge", "api", "/v1/admin/auth/challenge", {404}),
    ("api_blocks_root", "api", "/", {404}),
    ("api_blocks_readiness", "api", "/readyz", {404}),
    ("api_parent_signals_unauth", "api", "/v1/children/00000000-0000-4000-8000-000000000000/signals", {401}),
    ("api_device_signal_status_unauth", "api", "/v1/devices/00000000-0000-4000-8000-000000000000/signals/00000000-0000-4000-8000-000000000000/status", {401}),
    ("api_parent_profile_unauth", "api", "/v1/auth/parent/session", {401, 404, 405}),
    ("admin_admin_session_unauth", "admin", "/v1/admin/auth/session", {401, 404, 405}),
]
REDACTED = ("set-cookie", "authorization", "cookie", "x-api-key")


def check(label, target, path, expected):
    url = urlsplit(TARGETS[target] + path)
    context = ssl.create_default_context()
    conn = http.client.HTTPSConnection(url.hostname, 443, timeout=8, context=context)
    try:
        conn.request("GET", path, headers={
            "User-Agent": "MadalasaAuthorizedSecurityBaseline/1.0",
            "Accept": "application/json,text/html",
            "Cache-Control": "no-store",
        })
        resp = conn.getresponse()
        raw = resp.read(65537)
        status = resp.status
        headers = {k.lower(): v for k, v in resp.getheaders() if k.lower() not in REDACTED}
        flags = []
        if len(raw) > 65536:
            flags.append("OVERSIZE_RESPONSE")
        if status != 404 and status in (500, 502, 503, 504):
            flags.append("SERVER_ERROR")
        if status in (301, 302, 303, 307, 308):
            flags.append("UNEXPECTED_REDIRECT")
        if status not in expected:
            flags.append("UNEXPECTED_STATUS")
        if not headers.get("x-content-type-options", "").lower() == "nosniff":
            flags.append("MISSING_NOSNIFF")
        if headers.get("referrer-policy", "").lower() != "no-referrer":
            flags.append("MISSING_REFERRER_POLICY")
        if "max-age=" not in headers.get("strict-transport-security", "").lower():
            flags.append("MISSING_HSTS")
        if target == "admin" and not headers.get("x-frame-options", "").lower() == "deny":
            flags.append("ADMIN_FRAME_POLICY")
        if target == "admin" and not headers.get("content-security-policy"):
            flags.append("ADMIN_MISSING_CSP")
        if "/v1/" in path and "no-store" not in headers.get("cache-control", "").lower():
            flags.append("MISSING_API_NO_STORE")
        if target == "api" and "/v1/" in path and headers.get("cf-cache-status", "").upper() == "HIT":
            flags.append("API_EDGE_CACHE_HIT")
        if label == "api_capabilities" and status == 200:
            try:
                obj = json.loads(raw)
                if obj.get("release_profile") != "FREE_ONLY":
                    flags.append("RELEASE_PROFILE_NOT_FREE_ONLY")
            except (ValueError, UnicodeError):
                flags.append("BAD_CAPABILITIES_JSON")
        return {"check":label, "target":target, "status":status,
                "expected":sorted(expected), "result":"PASS" if not flags else "REVIEW",
                "flags":flags}
    finally:
        conn.close()


def main():
    if os.environ.get("MA_SECURITY_BASELINE_AUTHORIZED") != "YES":
        raise RuntimeError("Refusing network requests: set MA_SECURITY_BASELINE_AUTHORIZED=YES for owner-authorized staging")
    results = []
    for label, target, path, expected in CHECKS:
        try:
            item = check(label, target, path, expected)
        except (OSError, ssl.SSLError, TimeoutError) as exc:
            item = {"check":label,"target":target,"result":"ERROR",
                    "error_type":type(exc).__name__}
        results.append(item)
        print(json.dumps(item, sort_keys=True), flush=True)
        time.sleep(0.25)
    print(json.dumps({"summary":{"checks":len(results),
                     "pass":sum(x["result"]=="PASS" for x in results),
                     "review":sum(x["result"]=="REVIEW" for x in results),
                     "errors":sum(x["result"]=="ERROR" for x in results)}}))
    return 0 if all(x["result"]=="PASS" for x in results) else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as exc:
        print("ERROR:", str(exc), file=sys.stderr)
        sys.exit(2)
