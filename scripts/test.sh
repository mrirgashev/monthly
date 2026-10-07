#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "The native renderer tests require macOS with Xcode Command Line Tools." >&2
  exit 1
fi
cd "$(dirname "$0")/.."
xcrun swift test
./scripts/build.sh
app=".build/distribution/Monthly Native.app"
review_dir="$(mktemp -d "${TMPDIR:-/tmp}/monthly-native-review.XXXXXX")"
trap 'rm -rf "$review_dir"' EXIT
ditto "$app" "$review_dir/Monthly Native.app"
"$review_dir/Monthly Native.app/Contents/MacOS/MonthlyNative" --render-samples "$PWD/.build/reference-samples"
echo "Unit and renderer tests passed. Review .build/reference-samples and Docs/VALIDATION.md."
