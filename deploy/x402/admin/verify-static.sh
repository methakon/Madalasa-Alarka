#!/usr/bin/env bash
set -euo pipefail
root="${1:-/srv/madalasa/admin}"
test -f "$root/index.html" || { echo "missing admin bundle" >&2; exit 1; }
grep -q '/assets/' "$root/index.html" || { echo "not a Vite production build" >&2; exit 1; }
test -d "$root/assets" || { echo "missing fingerprinted assets" >&2; exit 1; }
echo 'PASS: static admin assets present (does not certify OIDC/login/backend).'
