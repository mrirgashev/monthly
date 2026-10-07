#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:-$project_dir/.build/distribution/Monthly Native.app}"
output="${2:-$project_dir/dist/MonthlyNative.dmg}"
dmgbuild_bin="${DMGBUILD:-dmgbuild}"
command -v "$dmgbuild_bin" >/dev/null || {
  echo 'Packaging requires dmgbuild 1.6.7 (a build-time Python tool only).' >&2
  exit 1
}
test -d "$app/Contents"
codesign --verify --deep --strict "$app"
mkdir -p "$(dirname "$output")" "$project_dir/.build/distribution"
stage="$(mktemp -d "$project_dir/.build/distribution/.dmg.XXXXXX")"
mounted=0
cleanup() {
  if [ "$mounted" = 1 ]; then hdiutil detach "$stage/verify" >/dev/null || return; fi
  rm -rf "$stage"
}
trap cleanup EXIT
swift "$project_dir/scripts/DMGBackground.swift" "$stage"
"$dmgbuild_bin" -s "$project_dir/scripts/dmg-settings.py" \
  -D "app=$app" -D "background=$stage/installer.png" \
  "Monthly Native" "$stage/MonthlyNative.dmg"
hdiutil verify "$stage/MonthlyNative.dmg"
mkdir "$stage/verify"
hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$stage/verify" "$stage/MonthlyNative.dmg"
mounted=1
codesign --verify --deep --strict "$stage/verify/Monthly Native.app"
diff -qr "$app" "$stage/verify/Monthly Native.app"
test "$(readlink "$stage/verify/Applications")" = /Applications
hdiutil detach "$stage/verify"
mounted=0
mv -f "$stage/MonthlyNative.dmg" "$output"
echo "Created: $output"
