# Building and packaging

## Requirements

- macOS 14 or later.
- Xcode 15+ / Swift 5.9+ or compatible Command Line Tools. Select the intended toolchain in Xcode Settings → Locations.
- No third-party Swift packages. Python is only needed for optional DMG packaging.

Open `Package.swift` in Xcode to work on the code. Use a packaged `.app` for Calendar permission, wallpaper and login-item testing; a bare SwiftPM executable has a different bundle context.

## Test and run

```sh
./scripts/test.sh
open ".build/distribution/Monthly Native.app"
```

The script runs XCTest, builds and verifies an ad-hoc signed app, copies it outside the build directory, and exports 111 deterministic review PNGs to `.build/reference-samples`. It does not apply wallpaper or request Calendar access. Images with events use synthetic fixtures. See [validation](VALIDATION.md) for the boundary between automated and manual coverage.

To build only, run `./scripts/build.sh`. To build both Apple Silicon and Intel slices:

```sh
./scripts/build.sh --universal
```

Output: `.build/distribution/Monthly Native.app`. Install in `/Applications` before testing launch at login.

## Create a DMG

```sh
python3 -m venv .build/dmg-tools
.build/dmg-tools/bin/python -m pip install dmgbuild==1.6.7
DMGBUILD="$PWD/.build/dmg-tools/bin/dmgbuild" ./scripts/package-dmg.sh
```

Output: `dist/MonthlyNative.dmg`, with a drag-to-Applications layout. The script verifies the disk image, mounts it read-only, checks its app signature and contents, and checks the Applications shortcut. Packaging does not notarize the app.

## Developer ID signing and notarization

The default build is ad-hoc signed. Public downloads may be blocked by Gatekeeper. With your own Developer ID Application certificate and an existing `notarytool` Keychain profile:

```sh
export SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export NOTARY_PROFILE='your-existing-keychain-profile'
./scripts/notarize.sh
```

This builds a universal app, signs with hardened runtime, submits it, staples the ticket and produces `.build/distribution/MonthlyNative-macOS.zip`. To package that stapled app as a DMG, run `package-dmg.sh` afterward without rebuilding it. This signing path has not been executed for the current release. Never commit certificates, keys or credentials.

## Releases

GitHub Actions tests every push and pull request. Pushing a `v*` tag runs the release workflow: test, build a universal app, package DMG and ZIP, calculate SHA-256 checksums, and publish a GitHub Release. Only the release job receives repository write permission. The workflow currently uses ad-hoc signing and labels that limitation in the release notes.

Before tagging, update `Configuration/Info.plist`, the About version, and `Docs/RELEASE_NOTES.md`; run the local checks and inspect the native app. The tag must match `CFBundleShortVersionString` (for example, `v1.2.0`). Never move an already-published release tag. Installers belong in Releases, not Git history.
