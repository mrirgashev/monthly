# Validation

## Version 1.2.0

Local validation on 7 October 2026 used an Apple Silicon Mac running macOS 27.0.1 and Swift 6.4. These observations are from this environment, not a claim of universal compatibility.

- **44 XCTest tests passed:** 27 core and 17 rendering/cache/preferences tests. Coverage includes month grids, leap years, DST boundaries, ordered design scheduling, fixed backgrounds, cache recovery and preference migration.
- A universal `arm64` / `x86_64` app built with a macOS 14 deployment target and passed strict ad-hoc signature verification.
- The standalone bundle rendered **111 sample images** outside its build directory. Version 1.2 preserved the five-line wallpaper rendering from 1.1.1.
- Native UI inspection confirmed Settings and the editor share one window; Back to wallpaper and Command-comma work. The desktop-dot toggle applies immediately and stays off after quit/relaunch.
- Earlier native checks observed an actual scheduled design change and a midnight date rollover, plus Retina wallpaper application/export.
- The DMG passed checksum verification, mounted bundle signature and content checks, and the Applications shortcut check. Its Finder installation layout was visually inspected.

GitHub Actions provides separate results for each published commit. It tests and renders offscreen; it does not validate interactive Calendar permissions, physical displays or system login behavior.

## Still unverified

- Intel hardware execution and runtime compatibility on older supported macOS versions.
- External, rotated or mirrored displays, hotplug races and multi-display failures on physical hardware.
- All Calendar grant/deny/revoke paths, actual login execution, sleep across a scheduled boundary, and exhaustive Spaces behavior.
- Comprehensive VoiceOver, energy and accessibility testing.
- Developer ID signing, notarization and first-download Gatekeeper behavior on another Mac.

The app is an independent native adaptation of public reference designs. Private paid-editor states and pixel-perfect equivalence are not claimed. Public screenshots were used as references, not redistributed assets.
