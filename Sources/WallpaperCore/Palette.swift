import Foundation

public struct Palette: Equatable, Sendable {
    public let month: Int
    public let hex: String
    public let name: String
    public let caption: String
    public let captionVerified: Bool

    // Hex values are measured from the reference's public twelve-colour tour.
    // Unavailable captions are intentionally empty, never fabricated.
    public static let all: [Palette] = [
        .init(month: 1, hex: "2F4F6F", name: "January", caption: "", captionVerified: false),
        .init(month: 2, hex: "8A6FA6", name: "February", caption: "", captionVerified: false),
        .init(month: 3, hex: "6B8E5A", name: "March", caption: "", captionVerified: false),
        .init(month: 4, hex: "7FB7D8", name: "Rainwashed Sky Blue", caption: "Cleansing, optimism, movement", captionVerified: true),
        .init(month: 5, hex: "D16C8C", name: "May", caption: "", captionVerified: false),
        .init(month: 6, hex: "E6C16E", name: "Golden Straw", caption: "", captionVerified: false),
        .init(month: 7, hex: "F26B4F", name: "July", caption: "", captionVerified: false),
        .init(month: 8, hex: "C56A2D", name: "Burnt Amber", caption: "Maturity, warmth, late-summer richness", captionVerified: true),
        .init(month: 9, hex: "8A8F3A", name: "September", caption: "", captionVerified: false),
        .init(month: 10, hex: "C7511F", name: "Spiced Pumpkin", caption: "Transformation, warmth, nostalgia", captionVerified: true),
        .init(month: 11, hex: "5A414C", name: "November", caption: "", captionVerified: false),
        .init(month: 12, hex: "1F4D3C", name: "December", caption: "", captionVerified: false)
    ]
    public static func index(month: Int, hemisphere: Hemisphere) -> Int {
        let offset = hemisphere == .southern ? 6 : 0
        return ((month - 1 + offset) % 12 + 12) % 12
    }
    public static func current(month: Int, hemisphere: Hemisphere) -> Palette {
        all[index(month: month, hemisphere: hemisphere)]
    }
    public static func previous(month: Int, hemisphere: Hemisphere) -> Palette {
        all[(index(month: month, hemisphere: hemisphere) + 11) % 12]
    }
}
