#!/usr/bin/env python3
"""Optional PUBLIC HTTPS acceptance of x402 SOS API against SYNTHETIC STAGING identities.

This script does not provision identities, change Cloudflare, log secrets, or
perform human admin login. It sends exactly one synthetic manual SOS and an
explicit synthetic guardian ACK when the operator has approved that fixture.
Do not run with actual children's identities or production credentials.

Usage: export MA_ACCEPTANCE_*=... from a secure shell/secret manager and run:
  MA_ACCEPTANCE_SYNTHETIC_ONLY=YES python3 deploy/x402/api/public-synthetic-sos-acceptance.py
Missing or malformed parameters fail closed before any network request.
"""
from datetime import datetime, timezone
import json
import os
import re
import ssl
import sys
import urllib.error
import urllib.request
from uuid import UUID, uuid4

API = "https://api.madalasa.berhampore.in"
UUID_RX = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")


def fail(message):
    raise RuntimeError(message)


def required(key):
    value = os.environ.get(key, "").strip()
    if not value:
        fail("missing required secure input: " + key)
    return value


def exact_uuid(value):
    try:
        parsed = UUID(value)
    except ValueError:
        fail("invalid UUID in acceptance fixture")
    if str(parsed) != value.lower() or not UUID_RX.fullmatch(value.lower()):
        fail("invalid acceptance UUID")
    return str(parsed)


def request(method, path, token=None, body=None):
    if not path.startswith("/v1/") or "?" in path or "#" in path:
        fail("unapproved API route")
    payload = json.dumps(body, separators=(",", ":")).encode() if body is not None else None
    headers = {"Accept": "application/json", "Cache-Control": "no-store"}
    if token:
        headers["Authorization"] = "Bearer " + token
    if payload is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(API + path, data=payload, headers=headers, method=method)
    opener = urllib.request.build_opener(
        urllib.request.HTTPSHandler(context=ssl.create_default_context()),
        urllib.request.HTTPHandler()
    )
    # Reject redirects even if they would otherwise be handled automatically.
    class DenyRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            fail("unexpected redirect from public API")
    opener.add_handler(DenyRedirect())
    try:
        with opener.open(req, timeout=15) as resp:
            status = resp.status
            mime = resp.headers.get("Content-Type", "")
            raw = resp.read(65537)
            cache = resp.headers.get("CF-Cache-Status", "")
    except urllib.error.HTTPError as err:
        status = err.code
        mime = err.headers.get("Content-Type", "")
        raw = err.read(65537)
        cache = err.headers.get("CF-Cache-Status", "")
    if len(raw) > 65536 or "application/json" not in mime.lower():
        fail(f"{method} route returned non-JSON or oversized payload (HTTP {status})")
    if status in (429, 503):
        fail(f"{method} route unavailable/blocked (HTTP {status}); inspect WAF and origin safely")
    if cache.upper() == "HIT":
        fail("authenticated API response was cached at an edge")
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError:
        fail("API sent malformed JSON")
    if not isinstance(obj, dict):
        fail("expected JSON object")
    return status, obj


def expect(label, condition):
    if not condition:
        fail("FAIL: " + label)
    print("PASS: " + label, flush=True)


def main():
    if os.environ.get("MA_ACCEPTANCE_SYNTHETIC_ONLY") != "YES":
        fail("Set MA_ACCEPTANCE_SYNTHETIC_ONLY=YES for approved synthetic-only staging fixture")
    device_id = exact_uuid(required("MA_ACCEPTANCE_DEVICE_ID"))
    child_id = exact_uuid(required("MA_ACCEPTANCE_CHILD_ID"))
    device_token = required("MA_ACCEPTANCE_DEVICE_BEARER")
    parent_token = required("MA_ACCEPTANCE_PARENT_BEARER")
    wrong_parent_token = os.environ.get("MA_ACCEPTANCE_OTHER_FAMILY_BEARER", "").strip()
    if parent_token == device_token or wrong_parent_token in (device_token, parent_token) and wrong_parent_token:
        fail("distinct fixture credentials required")
    if os.environ.get("MA_ACCEPTANCE_CONFIRMED_NO_REAL_MINOR_DATA") != "YES":
        fail("must explicitly verify all subjects are synthetic/non-minor test fixtures")
    event_id = str(uuid4())
    observed_at = datetime.now(timezone.utc).isoformat()
    post_path = f"/v1/devices/{device_id}/signals"
    status_path = f"/v1/devices/{device_id}/signals/{event_id}/status"
    list_path = f"/v1/children/{child_id}/signals"
    ack_path = f"/v1/children/{child_id}/signals/{event_id}/ack"

    # Prove negative auth first. No user or credential details are logged.
    s, _ = request("GET", list_path)
    expect("public guardian endpoint rejects unauthenticated", s == 401)
    s, _ = request("POST", post_path, body={"event_id":event_id, "kind":"SOS", "observed_at":observed_at})
    expect("public device endpoint rejects unauthenticated SOS", s == 401)
    if wrong_parent_token:
        s, _ = request("GET", list_path, wrong_parent_token)
        expect("other-family guardian cannot list child signals", s in (403, 404))
    s, data = request("POST", post_path, device_token,
                      {"event_id":event_id, "kind":"SOS", "observed_at":observed_at})
    expect("device HTTPS submission accepted and event-bound",
           s == 201 and data.get("event_id") == event_id and data.get("stage") == "SERVER_ACCEPTED")
    s, data = request("GET", status_path, device_token)
    expect("status initially unacknowledged and event-bound",
           s == 200 and data.get("event_id") == event_id and data.get("guardian_acknowledged") is False)
    s, data = request("GET", list_path, parent_token)
    signals = data.get("signals", [])
    expect("guardian fetch contains the exact submitted unacknowledged event",
           s == 200 and isinstance(signals, list) and
           sum(x.get("event_id") == event_id and x.get("acknowledged") is False
               for x in signals if isinstance(x, dict)) == 1)
    if wrong_parent_token:
        s, _ = request("POST", ack_path, wrong_parent_token, {})
        expect("other-family guardian cannot acknowledge", s in (403, 404))
    s, data = request("POST", ack_path, parent_token, {})
    expect("guardian explicitly acknowledges synthetic event",
           s == 200 and data.get("event_id") == event_id and data.get("stage") == "GUARDIAN_ACKNOWLEDGED")
    s, data = request("GET", status_path, device_token)
    expect("device converges on server-confirmed guardian acknowledgment",
           s == 200 and data.get("event_id") == event_id and
           data.get("guardian_acknowledged") is True and
           data.get("stage") == "GUARDIAN_ACKNOWLEDGED")
    print("PASS: PUBLIC synthetic HTTP SOS cycle (NOT native Android/outbox or real admin OIDC proof)")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
