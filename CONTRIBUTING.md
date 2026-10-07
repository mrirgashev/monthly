# Contributing

Bug reports and focused pull requests are welcome. Start with [build instructions](Docs/BUILDING.md) and [architecture](Docs/ARCHITECTURE.md).

For a bug, include the app version, macOS version, Apple Silicon/Intel, reproduction steps, expected behavior and actual behavior. For display issues, include resolution/scaling and layout settings. Remove private event titles, account names and personal paths from screenshots or logs before sharing.

Keep changes native to Swift/SwiftUI/AppKit. Add a focused regression test for a behavioral fix, run `./scripts/test.sh`, and inspect affected renderer samples or native screens. Inject dates and timezones into tests instead of changing the system clock. Use synthetic Calendar fixtures; do not upload personal preferences or event data.

Preserve draft versus applied settings, cancellation guards, local-only data handling and macOS security protections. Document hardware or permission paths you could not test. Avoid unrelated formatting changes and generated binaries in pull requests.

Contributions are provided under the project's MIT License. Include attribution and compatible licensing for any added third-party material.
