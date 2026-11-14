#!/usr/bin/env bash
# Non-destructive x402 deployment preflight. Does not install, alter ports or expose data.
set -euo pipefail
echo 'x402-endpoint: non-destructive API preflight'
echo 'Host:'; hostname; uname -m; cat /etc/os-release | grep -E '^PRETTY_NAME=' || true
echo 'RAM/swap:'; free -m
echo 'Disk:'; df -h /
echo 'Listeners (TCP):'; ss -ltn | awk 'NR==1 || /:(22|25|80|443|465|587|993|995|5432|8080) /'
echo 'Mail/nginx units:'; systemctl --no-pager --plain is-active nginx dovecot opensmtpd || true
for cmd in nginx curl systemctl; do command -v "$cmd" >/dev/null || { echo "missing $cmd" >&2; exit 1; }; done
nginx -t
if ss -ltn | grep -Eq '(^|[[:space:]])[^[:space:]]+:8080[[:space:]]'; then
  echo 'Port 8080 is already listening: inspect ownership before installation' >&2
fi
if [ -f /etc/madalasa/api.env ]; then
  mode=$(stat -c %a /etc/madalasa/api.env)
  case "$mode" in 600|640) : ;; *) echo "api.env mode $mode is too permissive; use 600/640" >&2; exit 1;; esac
  # Do not source, print or grep secrets from this file.
fi
# Release gate for the database test-mode switch. Needs the runtime login in the libpq environment (PG*).
# Skipping must be explicit; a silent skip would defeat the point.
if [ "${MA_PREFLIGHT_SKIP_TEST_MODE_CHECK:-0}" = 1 ]; then
  echo 'WARNING: test-mode switch NOT CHECKED (MA_PREFLIGHT_SKIP_TEST_MODE_CHECK=1). Do not release on this result.' >&2
else
  bash "$(dirname "$0")/check-test-mode-off.sh"
fi
echo 'PASS: basic non-destructive preflight. This is not DB, TLS or feature readiness.'
