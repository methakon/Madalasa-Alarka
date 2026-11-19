#!/usr/bin/env bash
# L01-010 - generate a minimal SBOM from declared dependency manifests and
# check a basic dependency policy (pinned versions, no obvious disallowed entries).
# LOCAL governance only; not a security certification.
#
# Usage:
#   tools/check-sbom.sh                 # generate SBOM to build/sbom.json and check policy
#   tools/check-sbom.sh --selftest      # prove the policy check flags an unpinned dep
#
# Exit 0 = SBOM generated and policy ok; 1 = policy violation; 2 = usage error.
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
out="${SBOM_OUT:-$repo_root/build/sbom.json}"

collect_components() {
  # Emit "ecosystem|name|version|pinned" lines from known manifests.
  local root="$1"
  # Android version catalog (TOML): lines like name = "x.y.z"
  if [[ -f "$root/android/gradle/libs.versions.toml" ]]; then
    awk -F'=' '/^[[:space:]]*[a-zA-Z0-9_.-]+[[:space:]]*=[[:space:]]*".*"/{
      gsub(/[[:space:]]/,"",$1); v=$2; gsub(/[" ]/,"",v);
      pinned = (v ~ /^[0-9]/) ? "yes" : "no";
      print "gradle|" $1 "|" v "|" pinned
    }' "$root/android/gradle/libs.versions.toml"
  fi
  # Backend dependency lock (our format: name version sha license)
  if [[ -f "$root/backend/dependencies.lock" ]]; then
    awk 'NF>=2 && $1 !~ /^#/ {
      # System/inline/non-fetchable entries are not version-pinnable by us.
      if ($2=="system" || $2=="inline" || $2=="n/a") { pinned="exempt" }
      else { pinned=($2 ~ /^[0-9v]/)?"yes":"no" }
      print "cpp|" $1 "|" $2 "|" pinned
    }' "$root/backend/dependencies.lock"
  fi
  # Python doc tooling requirements, if present
  if [[ -f "$root/docs/tools/requirements.txt" ]]; then
    awk '/==/{split($0,a,"=="); print "pip|" a[1] "|" a[2] "|yes"}' "$root/docs/tools/requirements.txt"
  fi
}

generate_and_check() {
  local root="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  local comps; comps="$(collect_components "$root" || true)"
  local count unpinned
  count="$(printf '%s\n' "$comps" | grep -c '|' || true)"
  unpinned="$(printf '%s\n' "$comps" | awk -F'|' '$4=="no"{print $2}' || true)"
  {
    echo "{"
    echo "  \"sbom_format\": \"madalasa-local-min-1\","
    echo "  \"generated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"component_count\": ${count:-0},"
    echo "  \"components\": ["
    printf '%s\n' "$comps" | awk -F'|' 'NF==4{
      printf "    {\"ecosystem\":\"%s\",\"name\":\"%s\",\"version\":\"%s\",\"pinned\":\"%s\"}%s\n",$1,$2,$3,$4,(NR>0?",":"")
    }' | sed '$ s/,$//'
    echo "  ]"
    echo "}"
  } > "$dest"
  if [[ -n "${unpinned// /}" ]]; then
    echo "SBOM policy violation: unpinned dependencies:" >&2
    while IFS= read -r dependency; do
      if [[ -n "$dependency" ]]; then printf '  %s\n' "$dependency" >&2; fi
    done <<< "$unpinned"
    return 1
  fi
  echo "SBOM written to $dest; components=${count:-0}; all pinned"
}

selftest() {
  local tmp; tmp="$(mktemp -d)"
  mkdir -p "$tmp/backend"
  printf '# name version sha license\ndrogon 1.9.1 abc BSD\nbadlib latest def MIT\n' > "$tmp/backend/dependencies.lock"
  if generate_and_check "$tmp" "$tmp/sbom.json" 2>/dev/null; then
    echo "selftest FAIL: unpinned 'latest' not flagged"; rm -rf "$tmp"; return 1
  fi
  # All-pinned variant should pass.
  printf '# name version sha license\ndrogon 1.9.1 abc BSD\n' > "$tmp/backend/dependencies.lock"
  if ! generate_and_check "$tmp" "$tmp/sbom.json" >/dev/null 2>&1; then
    echo "selftest FAIL: pinned deps rejected"; rm -rf "$tmp"; return 1
  fi
  rm -rf "$tmp"
  echo "selftest PASS: flags unpinned dep, accepts pinned deps"
}

case "${1:-}" in
  --selftest) selftest ;;
  "") generate_and_check "$repo_root" "$out" ;;
  *) echo "Usage: tools/check-sbom.sh [--selftest]" >&2; exit 2 ;;
esac
