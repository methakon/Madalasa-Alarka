#!/usr/bin/env bash
# Roll back only admin static symlink, not API/database state.
set -euo pipefail
if [ "$#" -ne 1 ]; then echo "usage: $0 PREVIOUS_RELEASE_SHA" >&2; exit 64; fi
[ "$(id -u)" -eq 0 ] || { echo "root required" >&2; exit 77; }
[[ "$1" =~ ^[a-f0-9]{40}$ ]] || { echo "expected full source SHA" >&2; exit 64; }
base=/srv/madalasa/admin
dest="$base/releases/$1"
test -s "$dest/index.html" || { echo "release missing; no change" >&2; exit 66; }
next="$base/.current.rollback.$$"
ln -s "$dest" "$next"
mv -Tf "$next" "$base/current"
echo "admin rolled back to $1"
