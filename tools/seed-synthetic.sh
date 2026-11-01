#!/usr/bin/env bash
# L01-008 - repeatable synthetic fixture seed (LOCAL only, no live keys).
# Generates deterministic synthetic fixtures under .local-fixtures/ for local
# development and tests. Uses only synthetic aliases and a public test bounding
# box; never real child data, credentials, payment tokens or live API keys.
#
# Usage:
#   tools/seed-synthetic.sh                 # write fixtures
#   tools/seed-synthetic.sh --check         # verify repeatability (idempotent hash)
#   tools/seed-synthetic.sh --selftest      # end-to-end repeatability proof
#
# Exit 0 = success; 1 = repeatability or content violation; 2 = usage error.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
out_dir="${SEED_OUT_DIR:-$repo_root/.local-fixtures}"
# Fixed seed => deterministic output. No randomness, no network, no secrets.
SEED="${SYNTHETIC_SEED:-42}"

emit_fixtures() {
  local dir="$1"
  mkdir -p "$dir"
  # Synthetic families/children/devices. All identifiers are demo_ prefixed.
  cat > "$dir/families.json" <<EOF
{
  "seed": ${SEED},
  "note": "SYNTHETIC ONLY - no real persons, payments or secrets",
  "families": [
    {"id": "demo_family_01", "owner_alias": "demo_adult_a"},
    {"id": "demo_family_02", "owner_alias": "demo_adult_b"}
  ],
  "children": [
    {"id": "demo_child_01", "family_id": "demo_family_01", "alias": "demo_kid_one"},
    {"id": "demo_child_02", "family_id": "demo_family_01", "alias": "demo_kid_two"}
  ],
  "devices": [
    {"id": "demo_device_01", "child_id": "demo_child_01", "model": "synthetic_pixel"}
  ]
}
EOF
  # Synthetic location fixtures inside a declared public test bounding box.
  cat > "$dir/locations.json" <<EOF
{
  "seed": ${SEED},
  "bounding_box": {"min_lat": 22.30, "max_lat": 22.40, "min_lon": 87.30, "max_lon": 87.40},
  "observations": [
    {"child_id": "demo_child_01", "lat": 22.3210, "lon": 87.3210, "accuracy_m": 12, "t": "2026-01-01T00:00:00Z"},
    {"child_id": "demo_child_01", "lat": 22.3250, "lon": 87.3260, "accuracy_m": 9,  "t": "2026-01-01T00:05:00Z"}
  ]
}
EOF
}

content_hash() {
  # Order-stable hash of all fixture files.
  find "$1" -type f | LC_ALL=C sort | xargs cat | sha256sum | awk '{print $1}'
}

do_seed() { emit_fixtures "$out_dir"; echo "seeded fixtures in $out_dir (seed=$SEED)"; }

do_check() {
  local a b t1 t2
  t1="$(mktemp -d)"; t2="$(mktemp -d)"
  SEED="$SEED" emit_fixtures "$t1"; a="$(content_hash "$t1")"
  SEED="$SEED" emit_fixtures "$t2"; b="$(content_hash "$t2")"
  rm -rf "$t1" "$t2"
  if [[ "$a" != "$b" ]]; then echo "NOT repeatable: $a != $b" >&2; return 1; fi
  echo "repeatable seed hash=$a"
}

do_selftest() {
  do_check || return 1
  # Prove no live-key / secret markers in emitted fixtures (value patterns, not the word).
  local tmp; tmp="$(mktemp -d)"; emit_fixtures "$tmp"
  if grep -RiEq "AIza[0-9A-Za-z_-]{20,}|-----BEGIN|purchase_?token\"?\s*[:=]|(secret|password|api[_-]?key)\"?\s*[:=]\s*\"?[A-Za-z0-9]" "$tmp"; then
    echo "selftest FAIL: fixture contains a secret-like marker" >&2; rm -rf "$tmp"; return 1
  fi
  rm -rf "$tmp"
  echo "selftest PASS: deterministic and secret-free"
}

case "${1:-}" in
  --check) do_check ;;
  --selftest) do_selftest ;;
  "" ) do_seed ;;
  *) echo "Usage: tools/seed-synthetic.sh [--check|--selftest]" >&2; exit 2 ;;
esac
