#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Building Monthly Native requires macOS 14+ and Xcode 15+ (or newer Command Line Tools)." >&2
  exit 1
fi
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
universal=false
if [[ "${1:-}" == "--universal" ]]; then universal=true; fi
build_root="$project_dir/.build/distribution"
mkdir -p "$build_root"
stage="$(mktemp -d "$build_root/.stage.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/Monthly Native.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
if $universal; then
  xcrun swift build -c release --arch arm64
  arm_dir="$(xcrun swift build -c release --arch arm64 --show-bin-path)"
  # Swift 6.4's build engine uses the same Products/Release directory for both
  # architectures. Keep the first binary before the second build replaces it.
  cp "$arm_dir/MonthlyNative" "$stage/MonthlyNative-arm64"
  xcrun swift build -c release --arch x86_64
  intel_dir="$(xcrun swift build -c release --arch x86_64 --show-bin-path)"
  xcrun lipo -create "$stage/MonthlyNative-arm64" "$intel_dir/MonthlyNative" -output "$app/Contents/MacOS/MonthlyNative"
  bin_dir="$arm_dir"
else
  xcrun swift build -c release
  bin_dir="$(xcrun swift build -c release --show-bin-path)"
  cp "$bin_dir/MonthlyNative" "$app/Contents/MacOS/MonthlyNative"
fi
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/"
cp Configuration/Info.plist "$app/Contents/Info.plist"
cp Configuration/PrivacyInfo.xcprivacy "$app/Contents/Resources/PrivacyInfo.xcprivacy"
cp Sources/WallpaperCore/Resources/SouthernTimeZones.json "$app/Contents/Resources/SouthernTimeZones.json"
for resource in "$bin_dir"/*.bundle; do
  [[ -e "$resource" ]] || continue
  cp -R "$resource" "$app/Contents/Resources/"
done
xcrun swift scripts/Icon.swift "$build_root/AppIcon.iconset"
xcrun iconutil -c icns "$build_root/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"
identity="${SIGNING_IDENTITY:--}"
if [[ "$identity" == "-" ]]; then
  codesign --force --sign - --entitlements Configuration/MonthlyNative.entitlements "$app"
else
  codesign --force --options runtime --timestamp --sign "$identity" --entitlements Configuration/MonthlyNative.entitlements "$app"
fi
codesign --verify --deep --strict --verbose=2 "$app"
plutil -lint "$app/Contents/Info.plist"
destination="$build_root/Monthly Native.app"
# Replace only the known generated bundle, after the new bundle passed checks.
if [[ -d "$destination" ]]; then rm -rf "$destination"; fi
mv "$app" "$destination"
echo "Built: $destination"
