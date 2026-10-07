#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application identity.}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your existing notarytool Keychain profile.}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then echo "Notarization requires Developer ID signing." >&2; exit 1; fi
./scripts/build.sh --universal
app=".build/distribution/Monthly Native.app"
archive=".build/distribution/MonthlyNative-notarization.zip"
ditto -c -k --keepParent "$app" "$archive"
xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose "$app"
ditto -c -k --keepParent "$app" .build/distribution/MonthlyNative-macOS.zip
echo "Distribution archive: .build/distribution/MonthlyNative-macOS.zip"
