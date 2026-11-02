#!/usr/bin/env bash
# Inspect, never execute, the production binary. Optional second binary is the
# MA_SYNTHETIC_AUTH=ON negative control, which MUST contain the marker.
# Exit: 0 verified, 1 marker expectation failed, 2 input/tool failure.
set -euo pipefail
error() { echo "production auth gate: $*" >&2; exit 2; }
[[ $# == 1 || $# == 2 ]] || error "usage: $0 PRODUCTION_BINARY [SYNTHETIC_BINARY]"
command -v strings >/dev/null || error "strings unavailable"
command -v grep >/dev/null || error "grep unavailable"

# Returns 0 for present, 1 for absent, 2 for an inspection failure.
marker_status() {
  local binary=$1 output status
  [[ -f "$binary" && -r "$binary" && -s "$binary" ]] || return 2
  # Fully consume strings before searching: no grep -q / SIGPIPE false green.
  output=$(strings -- "$binary") || return 2
  if grep -F -- 'synthetic_test' <<<"$output" >/dev/null; then
    return 0
  else
    status=$?
    [[ $status == 1 ]] && return 1
    return 2
  fi
}
if marker_status "$1"; then
  echo "synthetic auth compiled into the deployable build" >&2
  exit 1
else
  status=$?
  [[ $status == 1 ]] || error "cannot inspect production binary"
fi
if [[ $# == 2 ]]; then
  if marker_status "$2"; then
    :
  else
    status=$?
    [[ $status == 1 ]] || error "cannot inspect synthetic control binary"
    echo "synthetic control is missing synthetic_test marker" >&2
    exit 1
  fi
fi
echo "production auth marker gate PASS (marker exclusion only, not OIDC acceptance)"
