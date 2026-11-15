#!/usr/bin/env bash
# Check startup contract without printing or sourcing credential values.
set -euo pipefail
file="${1:-/etc/madalasa/api.env}"
test -r "$file" || { echo "API environment missing or unreadable" >&2; exit 78; }
python3 - "$file" <<'PY'
import os,sys
from pathlib import Path
p=Path(sys.argv[1]); cfg={}
for raw in p.read_text().splitlines():
    line=raw.strip()
    if not line or line.startswith("#"): continue
    if "=" not in line: raise SystemExit("invalid environment file format")
    k,v=line.split("=",1)
    cfg[k.strip()]=v.strip().strip('"').strip("'")
required=("MA_RELEASE_PROFILE","MA_LISTEN_ADDR","MA_LISTEN_PORT","MA_ADMIN_ORIGIN",
          "MA_PG_DB","MA_PG_HOST","MA_PG_USER","MA_PG_PASSWORD",
          "MA_PG_AUTH_USER","MA_PG_AUTH_PASSWORD","MA_GOOGLE_OIDC_AUDIENCE",
          "MA_ADMIN_GOOGLE_OIDC_AUDIENCE")
for k in required:
    value=cfg.get(k,"")
    if not value or any(token in value for token in ("REQUIRED_","CHANGE_ME","example.invalid")):
        raise SystemExit("missing/placeholder value for "+k)
if cfg["MA_RELEASE_PROFILE"]!="FREE_ONLY": raise SystemExit("only FREE_ONLY is permitted")
if cfg["MA_LISTEN_ADDR"]!="127.0.0.1" or cfg["MA_LISTEN_PORT"]!="8080":
    raise SystemExit("API listener must be loopback:8080")
if not cfg["MA_ADMIN_ORIGIN"].startswith("https://"):
    raise SystemExit("admin origin must use HTTPS")
if cfg["MA_PG_USER"] != "ap_m1_api_user":
    raise SystemExit("runtime database login must be ap_m1_api_user")
if cfg["MA_PG_AUTH_USER"] != "ap_auth_issuer_user":
    raise SystemExit("auth issuer database login must be ap_auth_issuer_user")
if cfg["MA_PG_AUTH_USER"]==cfg["MA_PG_USER"]:
    raise SystemExit("issuer database login must differ from API login")
if cfg.get("PGSSLMODE","").lower() != "verify-full":
    raise SystemExit("remote database requires PGSSLMODE=verify-full")
if not cfg.get("PGSSLROOTCERT","").startswith("/"):
    raise SystemExit("PGSSLROOTCERT must be an absolute CA bundle path")
from urllib.parse import urlsplit
try:
    origin=urlsplit(cfg["MA_ADMIN_ORIGIN"])
    assert origin.scheme=="https" and origin.netloc=="madalasa.berhampore.in" and not origin.path.rstrip("/") and not origin.query and not origin.fragment and not origin.username
except (ValueError,AssertionError):
    raise SystemExit("admin origin must be exact expected HTTPS hostname")
if cfg["MA_PG_HOST"].strip().lower() in ("127.0.0.1","localhost","::1") or "/" in cfg["MA_PG_HOST"] or " " in cfg["MA_PG_HOST"] or ":" in cfg["MA_PG_HOST"] or "." not in cfg["MA_PG_HOST"]:
    raise SystemExit("Neon database requires a remote DNS hostname for TLS verification")
if cfg.get("MA_PG_CONNECTIONS","2") not in ("1","2"):
    raise SystemExit("limit runtime DB connections to 1 or 2 on x402")
for k in ("MA_OWNER_PAID_RELEASE_APPROVAL","MA_BILLDESK_APPROVAL","MA_PLAY_BILLING_APPROVAL"):
    if cfg.get(k): raise SystemExit("paid approval environment variable forbidden: "+k)
if cfg.get("MA_AUTH_MODE") in ("synthetic_test",):
    raise SystemExit("synthetic header authentication forbidden")
print("PASS: x402 free-only configuration contract; secrets not echoed")
PY
