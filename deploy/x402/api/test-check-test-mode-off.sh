#!/usr/bin/env bash
# Offline test of check-test-mode-off.sh with a fake psql on PATH.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
run() { # <fake psql stdout> <fake psql exit code>  -> prints the script's exit code
  printf '#!/usr/bin/env bash\n[ "%s" = 0 ] && printf "%%s\\n" "%s"\nexit %s\n' "$2" "$1" "$2" > "$tmp/bin/psql"
  chmod +x "$tmp/bin/psql"
  set +e; PATH="$tmp/bin:$PATH" bash "$here/check-test-mode-off.sh" >/dev/null 2>&1; local rc=$?; set -e; echo $rc
}
expect() { [ "$(run "$2" "$3")" = "$1" ] || { echo "FAIL: $4" >&2; exit 1; }; }
expect 0 'false|madalasa_alarka' 0 'off in a production-named database passes'
expect 1 'true|madalasa_alarka' 0 'switch on must fail'
expect 1 'false|madalasa_alarka_test' 0 'disposable name in production must fail'
expect 1 'false|ma_synthetic_x' 0 'ma_synthetic_ name must fail'
expect 0 'false|prod_madalasa_alarka_test' 0 'only the exact reserved names are refused'
expect 1 '' 1 'psql failure (function missing or unreachable) must fail'
expect 1 'maybe|madalasa_alarka' 0 'unexpected probe answer must fail'
expect 1 '' 0 'empty answer must fail'
# psql missing entirely
set +e; PATH="/usr/bin/nonexistent-dir" "$BASH" "$here/check-test-mode-off.sh" >/dev/null 2>&1; rc=$?; set -e
[ "$rc" = 1 ] || { echo 'FAIL: missing psql must fail' >&2; exit 1; }
echo 'PASS: check-test-mode-off gate'
