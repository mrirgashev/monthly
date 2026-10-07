# Third-party references and resources

- **Living Monthly Wallpapers / BetterCreating:** reference product and design at https://monthlywallpapers.com/. Names are used for attribution/comparison only. This app is independent, not an official client and does not claim a subscription or licence relationship. Reference marketing images, logo files, HTML, CSS and JavaScript are not distributed in this project.
- **Helvetica Neue:** accessed as an installed macOS font through AppKit/Core Text; no font file is bundled. If unavailable, the app uses the macOS system font.
- **IANA Time Zone Database:** `SouthernTimeZones.json` is a list of timezone identifiers whose reference-city coordinates in the system `zone.tab` are south of the equator, plus conventional aliases. Timezone database material is public domain. This estimates seasonal preference; it does not establish a device's geographic position.
- **Apple frameworks:** AppKit, SwiftUI, Foundation, Combine, Core Graphics, Core Text, ColorSync, ImageIO, Uniform Type Identifiers, CryptoKit, EventKit and ServiceManagement are supplied by macOS. XCTest is used only for tests.
- **GitHub Actions:** optional CI uses checkout/upload-artifact actions; they are not included in the app or needed for local builds.

There are no third-party runtime package dependencies.
