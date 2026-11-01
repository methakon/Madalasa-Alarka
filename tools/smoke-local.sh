#!/usr/bin/env bash
# L01-011 - single-command local smoke pipeline for Android + backend + tooling.
# Detects available toolchains and runs what it can; honestly reports SKIPPED
# (toolchain absent) rather than faking success. LOCAL only.
#
# Usage:
#   tools/smoke-local.sh              # run smoke across android/backend/tooling
#   tools/smoke-local.sh --selftest   # prove the runner reports honest states
#
# Exit 0 = no executed step failed (skips allowed); 1 = an executed step failed.
set -uo pipefail
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root" || exit 1

declare -a RESULTS
record() { RESULTS+=("$1|$2"); printf '  [%s] %s\n' "$2" "$1"; }

have() { command -v "$1" >/dev/null 2>&1; }

smoke_tooling() {
  # Always runnable: python tooling self-tests.
  local rc=0
  if have python3; then
    if python3 testkit/fake-services/fakes.py --selftest >/dev/null 2>&1; then
      record "testkit fakes self-test" PASS
    else
      record "testkit fakes self-test" FAIL; rc=1
    fi
    if bash tools/seed-synthetic.sh --check >/dev/null 2>&1; then
      record "synthetic seed repeatable" PASS
    else
      record "synthetic seed repeatable" FAIL; rc=1
    fi
  else
    record "python tooling" SKIPPED
  fi
  return $rc
}

smoke_android() {
  if have java && [[ -x android/gradlew ]]; then
    if ( cd android && ./gradlew :madalasa:assembleDebug :alarka:assembleDebug -q ); then
      record "android assembleDebug" PASS
    else
      record "android assembleDebug" FAIL; return 1
    fi
  else
    record "android assembleDebug (no JDK)" SKIPPED
  fi
  return 0
}

smoke_backend() {
  if have cmake && have g++ && { [[ -d /usr/include/drogon ]] || [[ -d /usr/local/include/drogon ]]; }; then
    if cmake -S backend -B build/backend -DCMAKE_BUILD_TYPE=Debug >/dev/null 2>&1 \
        && cmake --build build/backend -j >/dev/null 2>&1; then
      record "backend compile" PASS
    else
      record "backend compile" FAIL; return 1
    fi
  else
    record "backend compile (no Drogon toolchain)" SKIPPED
  fi
  return 0
}

summarize() {
  local fails
  fails="$(printf '%s\n' "${RESULTS[@]}" | awk -F'|' '$2=="FAIL"' | wc -l | tr -d ' ')"
  echo "smoke summary: ${#RESULTS[@]} steps, ${fails} failed"
  [[ "$fails" == "0" ]]
}

selftest() {
  # The runner must classify an absent toolchain as SKIPPED, not FAIL/PASS.
  RESULTS=()
  smoke_android >/dev/null 2>&1 || true   # no JDK here -> expect SKIPPED entry
  local line; line="$(printf '%s\n' "${RESULTS[@]}" | grep -i android || true)"
  if ! printf '%s' "$line" | grep -q "SKIPPED"; then
    echo "selftest FAIL: android not reported SKIPPED without JDK (got: $line)"; return 1
  fi
  echo "selftest PASS: absent toolchain reported SKIPPED (honest)"
}

main() {
  if [[ "${1:-}" == "--selftest" ]]; then selftest; return $?; fi
  echo "local smoke pipeline:"
  local rc=0
  smoke_tooling || rc=1
  smoke_android || rc=1
  smoke_backend || rc=1
  summarize || rc=1
  return $rc
}

main "$@"
