#!/usr/bin/env bash
# Run on a CI/build host (preferably not the 954 MiB VM).
# The Vite build must NOT contain development fixtures or synthetic root-owner preview.
set -euo pipefail
cd "$(dirname "$0")/../../../admin-web"
test -f package-lock.json || { echo 'Missing package-lock.json: cannot reproducibly use npm ci' >&2; exit 1; }
export NODE_ENV=production
export VITE_ADMIN_SYNTHETIC_PREVIEW=false
export VITE_ADMIN_GOOGLE_CLIENT_ID="${VITE_ADMIN_GOOGLE_CLIENT_ID:-207621418218-0bh5omf3aj4ita86kcjiorc387361o4k.apps.googleusercontent.com}"
npm ci --ignore-scripts --include=dev
npm test
npm run build
test -s dist/index.html
if grep -RqE 'SYNTHETIC ROOT_OWNER|Invented example accounts' dist/assets/*.js; then
  echo 'WARNING: fixture strings exist in bundle; verify dead-code-elimination and UI runtime gating.' >&2
  # Strings may survive bundle tree shaking; runtime must remain fail-closed.
fi
echo 'Built admin-web/dist. Install only after review of commit and hash.'
