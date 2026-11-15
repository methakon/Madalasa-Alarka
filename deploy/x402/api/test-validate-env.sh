#!/usr/bin/env bash
# Offline synthetic-only regression tests for x402 environment validation.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
python3 - "$here/api.env.example" "$tmp" <<'PY'
import pathlib,sys
template=pathlib.Path(sys.argv[1]).read_text()
out=pathlib.Path(sys.argv[2])
replacements={
 'REQUIRED_DATABASE_NAME':'sandbox_db',
 'REQUIRED_NEON_HOSTNAME':'ep-synthetic.example.neon.tech',
 'REQUIRED_RUNTIME_DB_SECRET':'synthetic-not-a-secret-runtime',
 'REQUIRED_SEPARATE_AUTH_DB_SECRET':'synthetic-not-a-secret-auth',
 'REQUIRED_PARENT_GOOGLE_CLIENT_ID':'synthetic-parent-client-id',
 'REQUIRED_ADMIN_GOOGLE_CLIENT_ID':'synthetic-admin-client-id',
}
for a,b in replacements.items():
    if a not in template: raise SystemExit('missing template anchor '+a)
    template=template.replace(a,b)
(out/'valid.env').write_text(template)
cases={
 'group-role':('MA_PG_USER=ap_m1_api_user','MA_PG_USER=ap_m1_api'),
 'same-role':('MA_PG_AUTH_USER=ap_auth_issuer_user','MA_PG_AUTH_USER=ap_m1_api_user'),
 'tls-weak':('PGSSLMODE=verify-full','PGSSLMODE=require'),
 'tls-missing':('PGSSLMODE=verify-full','PGSSLMODE='),
 'local-db':('MA_PG_HOST=ep-synthetic.example.neon.tech','MA_PG_HOST=127.0.0.1'),
 'admin-http':('MA_ADMIN_ORIGIN=https://madalasa.berhampore.in','MA_ADMIN_ORIGIN=http://madalasa.berhampore.in'),
 'paid-on':('MA_RELEASE_PROFILE=FREE_ONLY','MA_RELEASE_PROFILE=PAID'),
 'placeholder':('MA_PG_DB=sandbox_db','MA_PG_DB=REQUIRED_DATABASE_NAME'),
}
for name,(good,bad) in cases.items():
    if good not in template: raise SystemExit('missing case anchor '+good)
    (out/(name+'.env')).write_text(template.replace(good,bad))
PY
bash "$here/validate-env.sh" "$tmp/valid.env"
for testfile in "$tmp"/*.env; do
  [[ "$testfile" == "$tmp/valid.env" ]] && continue
  if bash "$here/validate-env.sh" "$testfile" >"$tmp/negative.log" 2>&1; then
    echo "FAIL: validation accepted $(basename "$testfile")" >&2
    exit 1
  fi
  echo "PASS: rejected $(basename "$testfile")"
done
echo "PASS: x402 environment validator negative and positive contracts"
