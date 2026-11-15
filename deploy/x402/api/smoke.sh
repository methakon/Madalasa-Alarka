#!/usr/bin/env bash
# Local API smoke checks; no credentials/child data. Works before nginx publishing.
set -euo pipefail
base="${MA_SMOKE_BASE:-http://127.0.0.1:8080}"
case "$base" in http://127.0.0.1:*|https://127.0.0.1:*|https://api.*) : ;; *) echo "unsafe smoke base; use localhost or explicit HTTPS API hostname" >&2; exit 1;; esac
for endpoint in /healthz /v1/release/capabilities; do
  response=$(curl -fSs --max-time 8 --header 'Accept: application/json' "$base$endpoint")
  RESPONSE_JSON="$response" ENDPOINT="$endpoint" python3 - <<'PY'
import json,os
obj=json.loads(os.environ["RESPONSE_JSON"])
if os.environ["ENDPOINT"]=="/healthz":
    assert obj.get("status")=="ok"
else:
    assert obj.get("release_profile")=="FREE_ONLY"
    assert obj.get("paid_checkout_enabled") is False
    assert obj.get("trial_enabled") is False
    assert obj.get("premium_media_enabled") is False
    assert obj.get("monitoring_approval_inferred") is False
print("PASS",os.environ["ENDPOINT"])
PY
done
echo 'PASS: liveness/free-only responses; NOT proof of PostgreSQL, parent auth, RLS, device readiness or Play/legal approval.'
