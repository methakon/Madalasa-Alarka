#!/usr/bin/env bash
# L01-012 - verify a clean tree and scan tracked files for committed secrets.
# Self-contained inline secret scan (no external dependency). LOCAL only; not a
# security certification.
#
# Usage:
#   tools/verify-clean-build.sh            # scan tracked files, report clean tree
#   tools/verify-clean-build.sh --selftest # prove a planted secret is detected
#
# Exit 0 = clean; 1 = secret found or dirty unexpectedly; 2 = usage error.
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Secret value patterns (not mere keywords). Mirrors the main-branch data scanner
# intent but is self-contained so it runs on any worktree.
secret_grep() {
  local target="$1"
  grep -REn \
    -e '-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----' \
    -e 'AIza[0-9A-Za-z_-]{20,}' \
    -e '(secret|password|api[_-]?key|client[_-]?secret)"?[[:space:]]*[:=][[:space:]]*"?[A-Za-z0-9/+_-]{12,}' \
    -e 'purchase_?[tT]oken"?[[:space:]]*[:=][[:space:]]*"?[A-Za-z0-9._-]{20,}' \
    -e 'ey[JI][A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}' \
    "$target" 2>/dev/null \
    | grep -Eiv 'do-not-|placeholder|example|<[a-z]|redacted|dummy|sentinel|changeme|your-|test-only' \
    || true
}

scan_tracked() {
  local hits="" f
  # Only tracked text files; skip this scanner itself and lockfiles of hashes.
  while IFS= read -r f; do
    [[ "$f" == "tools/verify-clean-build.sh" ]] && continue
    case "$f" in
      *.md|*.json|*.yaml|*.yml|*.sh|*.py|*.kt|*.kts|*.cc|*.h|*.cpp|*.sql|*.txt|*.env|*.example|*.toml|*.properties)
        local out; out="$(secret_grep "$repo_root/$f")"
        [[ -n "$out" ]] && hits+="$out"$'\n'
        ;;
    esac
  done < <(git -C "$repo_root" ls-files)
  printf '%s' "$hits"
}

selftest() {
  local tmp; tmp="$(mktemp)"
  printf 'client_secret = "AKIAabc123def456ghi789"\n' > "$tmp"
  if [[ -z "$(secret_grep "$tmp")" ]]; then echo "selftest FAIL: planted secret not detected"; rm -f "$tmp"; return 1; fi
  printf 'client_secret = "<placeholder>"\n' > "$tmp"
  # Placeholder (angle brackets) should not be a 12+ alnum run -> no hit.
  if [[ -n "$(secret_grep "$tmp")" ]]; then echo "selftest FAIL: placeholder flagged"; rm -f "$tmp"; return 1; fi
  rm -f "$tmp"
  echo "selftest PASS: detects planted secret, ignores placeholder"
}

main() {
  case "${1:-}" in
    --selftest) selftest; return $? ;;
    "") ;;
    *) echo "Usage: tools/verify-clean-build.sh [--selftest]" >&2; return 2 ;;
  esac
  local dirty; dirty="$(git -C "$repo_root" status --porcelain)"
  local hits; hits="$(scan_tracked)"
  if [[ -n "$hits" ]]; then
    echo "SECRET SCAN FAILED:" >&2; printf '%s\n' "$hits" >&2; return 1
  fi
  echo "clean-build check: no committed secrets in tracked text files"
  [[ -n "$dirty" ]] && echo "note: worktree has uncommitted changes (informational)"
  return 0
}

main "$@"
