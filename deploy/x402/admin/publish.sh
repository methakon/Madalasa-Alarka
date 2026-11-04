#!/usr/bin/env bash
# Atomic static admin release publication. Run on x402 as root, after reviewed CI build.
set -euo pipefail
if [ "$#" -ne 2 ]; then echo "usage: $0 /path/to/dist RELEASE_SHA" >&2; exit 64; fi
[ "$(id -u)" -eq 0 ] || { echo "root required to publish" >&2; exit 77; }
source_dir=$(realpath "$1")
version="$2"
[[ "$version" =~ ^[a-f0-9]{40}$ ]] || { echo "expected full source commit SHA" >&2; exit 64; }
test -s "$source_dir/index.html"
test -d "$source_dir/assets"
base=/srv/madalasa/admin
mkdir -p "$base/releases"
dest="$base/releases/$version"
test ! -e "$dest" || { echo "release already exists; never replace" >&2; exit 73; }
mkdir -m 0755 "$dest"
cp -a "$source_dir/." "$dest/"
chown -R root:root "$dest"
find "$dest" -type d -exec chmod 0755 {} +
find "$dest" -type f -exec chmod 0644 {} +
new="$base/.current.next.$$"
ln -s "$dest" "$new"
mv -Tf "$new" "$base/current"
echo "admin published to $dest (nginx must use root $base/current)"
echo "Previous releases retained for rollback. No nginx reload required for static symlink."
