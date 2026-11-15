#!/usr/bin/env bash
# Read-only smoke/health acceptance. Run on x402 AFTER operator-controlled setup.
# Never sources secrets or changes nginx/systemd/DB/mail configuration.
set -euo pipefail

api_host=${MA_API_PUBLIC_HOST:-api.madalasa.berhampore.in}
admin_host=${MA_ADMIN_PUBLIC_HOST:-madalasa.berhampore.in}
[[ "$api_host" == "api.madalasa.berhampore.in" ]] || { echo "unexpected API hostname" >&2; exit 64; }
[[ "$admin_host" == "madalasa.berhampore.in" ]] || { echo "unexpected admin hostname" >&2; exit 64; }

echo '1/7: existing mail and HTTP services must be active'
for unit in nginx dovecot opensmtpd; do
  if ! systemctl is-active --quiet "$unit"; then
    echo "NO-GO: pre-existing service is not active: $unit" >&2
    exit 1
  fi
  echo "PASS: $unit active"
done
nginx -t
echo '2/7: API must be listening on loopback only'
if ! ss -ltn | grep -Eq '127[.]0[.]0[.]1:8080[[:space:]]'; then
  echo 'NO-GO: API loopback listener not found' >&2
  exit 1
fi
echo '3/7: JSON liveness and database readiness'
for endpoint in healthz readyz; do
  curl --fail --silent --show-error --max-time 8 "http://127.0.0.1:8080/$endpoint" |
  ENDPOINT="$endpoint" python3 -c 'import json,sys,os; d=json.load(sys.stdin); expected="ok" if os.getenv("ENDPOINT")=="healthz" else "ready"; assert d.get("status")==expected,d; print("PASS:",os.getenv("ENDPOINT"))'
done

echo '4/7: free-only release profile'
curl --fail --silent --show-error --max-time 8 http://127.0.0.1:8080/v1/release/capabilities |
python3 -c 'import json,sys; o=json.load(sys.stdin); assert o.get("release_profile")=="FREE_ONLY",o; assert o.get("paid_checkout_enabled") is False,o; assert o.get("trial_enabled") is False,o; assert o.get("premium_media_enabled") is False,o; assert o.get("monitoring_approval_inferred") is False,o; print("PASS: FREE_ONLY no paid/media/monitoring approval")'

echo '5/7: DNS + public TLS (no -k; cert and hostname must be trusted)'
for host in "$api_host" "$admin_host"; do
  getent ahosts "$host" >/dev/null || { echo "NO-GO: DNS missing for $host" >&2; exit 1; }
  curl --fail --silent --show-error --max-time 10 --output /dev/null "https://$host/" || {
    # API intentionally returns 404 at root: still require successful TLS and a valid HTTP response.
    if [[ "$host" != "$api_host" ]]; then exit 1; fi
    code=$(curl --silent --show-error --max-time 10 --output /dev/null --write-out '%{http_code}' "https://$host/") || exit 1
    [[ "$code" == 404 ]] || { echo "NO-GO: unexpected API root response $code" >&2; exit 1; }
  }
  echo "PASS: verified public TLS for $host"
done

echo '6/7: admin and API vhost separation'
for target in "https://$api_host/v1/admin/auth/session" "https://$admin_host/v1/release/capabilities"; do
  status=$(curl --silent --show-error --max-time 10 --output /dev/null --write-out '%{http_code}' "$target") || exit 1
  [[ "$status" == 404 ]] || { echo "NO-GO: vhost separation unexpected HTTP $status at $target" >&2; exit 1; }
done
echo 'PASS: API/admin vhost isolation'

echo '7/7: bounded process and host resource facts (not a capacity certification)'
systemctl --no-pager --plain is-active madalasa-api
systemctl show madalasa-api -p MainPID -p MemoryCurrent -p MemoryPeak -p NRestarts
free -m
df -h /
echo 'PASS: basic x402 staging smoke; no user sign-in, OIDC, child ingest, payment, retention or load certification implied.'
