import Foundation

public enum BackgroundMode: String, Codable, CaseIterable, Sendable {
    case preset, custom, seasonal
    public var title: String { switch self { case .preset: return "Presets"; case .custom: return "Custom"; case .seasonal: return "By month" } }
}

public enum InkStyle: String, Codable, CaseIterable, Sendable {
    case automatic, dark, light
    public var title: String { rawValue.capitalized }
}

public struct GradientPreset: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let start: String
    public let end: String
    public let angle: Double
    // Original native presets, independent of the reference's twelve seasonal colors.
    public static let all: [GradientPreset] = [
        .init(id: "coast", name: "Coast", start: "B9DDDD", end: "7EAFC5", angle: 132),
        .init(id: "sage", name: "Sage", start: "E3E8CF", end: "94B5A0", angle: 135),
        .init(id: "lavender", name: "Lavender", start: "E5D6F2", end: "A6B3D5", angle: 120),
        .init(id: "peach", name: "Peach", start: "F7DFC2", end: "EAA8A0", angle: 120),
        .init(id: "lagoon", name: "Lagoon", start: "B7E7DD", end: "75BCCC", angle: 150),
        .init(id: "rose", name: "Rose", start: "F1D4E3", end: "C69CB5", angle: 110),
        .init(id: "sand", name: "Sand", start: "F4E8CE", end: "C9AE90", angle: 132),
        .init(id: "apricot", name: "Apricot", start: "FFE4AB", end: "EBA680", angle: 135),
        .init(id: "mint", name: "Mint", start: "D6EBCB", end: "8ECBC1", angle: 90),
        .init(id: "sky", name: "Sky", start: "D5E7F5", end: "8EAED7", angle: 180),
        .init(id: "lilac", name: "Lilac", start: "EBDCF0", end: "C3A0D2", angle: 132),
        .init(id: "clay", name: "Clay", start: "E4CAB1", end: "BD8B75", angle: 110),
        .init(id: "meadow", name: "Meadow", start: "E0E7AC", end: "99BA84", angle: 135),
        .init(id: "ice", name: "Ice", start: "E8F2ED", end: "B2D5DF", angle: 145),
        .init(id: "butter", name: "Butter", start: "F7EFC4", end: "E9CD85", angle: 120),
        .init(id: "mauve", name: "Mauve", start: "DBBDD4", end: "B2A7CC", angle: 160),
        .init(id: "dusk", name: "Dusk", start: "293B65", end: "664D7B", angle: 120),
        .init(id: "ocean", name: "Ocean", start: "163A4B", end: "266C7C", angle: 145),
        .init(id: "forest", name: "Forest", start: "163E35", end: "3C6557", angle: 110),
        .init(id: "plum", name: "Plum", start: "3B264F", end: "754A6A", angle: 132),
        .init(id: "ember", name: "Ember", start: "662E30", end: "9F523E", angle: 135),
        .init(id: "slate", name: "Slate", start: "283446", end: "58697B", angle: 90),
        .init(id: "espresso", name: "Espresso", start: "382C2A", end: "705A4B", angle: 135),
        .init(id: "midnight", name: "Midnight", start: "101B36", end: "304573", angle: 150)
    ]
}

public struct BackgroundChoice: Codable, Equatable, Sendable {
    public var mode: BackgroundMode = .seasonal
    public var presetID = "coast"
    public var firstHex = "B9DDDD"
    public var secondHex = "7EAFC5"
    public var angle = 132.0
    public var ink: InkStyle = .automatic
    public init() {}

    public static func normalizedHex(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        guard value.count == 6, value.unicodeScalars.allSatisfy({ "0123456789ABCDEF".unicodeScalars.contains($0) }) else { return nil }
        return value
    }

    public func resolved(month: Int, hemisphere: Hemisphere, fill: Fill) -> ResolvedBackground {
        let preset = GradientPreset.all.first { $0.id == presetID } ?? GradientPreset.all[0]
        let current = Palette.current(month: month, hemisphere: hemisphere)
        let previous = Palette.previous(month: month, hemisphere: hemisphere)
        let start: String, end: String, name: String, caption: String, direction: Double
        switch mode {
        case .seasonal:
            start = previous.hex; end = current.hex; name = current.name; caption = current.caption; direction = 132
        case .preset:
            start = preset.start; end = preset.end; name = preset.name; caption = ""; direction = preset.angle
        case .custom:
            start = Self.normalizedHex(firstHex) ?? "B9DDDD"; end = Self.normalizedHex(secondHex) ?? "7EAFC5"
            name = "Custom colour"; caption = ""; direction = angle.isFinite ? min(360, max(0, angle)) : 132
        }
        // A solid custom color uses the first picker. Seasonal solids retain their original base.
        let solid = mode == .seasonal ? end : start
        let a = fill == .solid ? solid : start, b = fill == .solid ? solid : end
        let text: String
        switch ink {
        case .dark: text = "000000"
        case .light: text = "FFFFFF"
        case .automatic:
            if mode == .seasonal { text = "000000" }
            else {
                let luminances = [Self.luminance(a), Self.luminance(b)]
                let darkContrast = (luminances.min()! + 0.05) / 0.05
                let lightContrast = 1.05 / (luminances.max()! + 0.05)
                text = darkContrast >= lightContrast ? "000000" : "FFFFFF"
            }
        }
        return ResolvedBackground(start: a, end: b, name: name, caption: caption,
                                  angle: direction, seasonalGlow: mode == .seasonal, ink: text)
    }

    private static func luminance(_ hex: String) -> Double {
        let value = UInt32(hex, radix: 16) ?? 0
        let components = [16, 8, 0].map { shift -> Double in
            let c = Double((value >> shift) & 255) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
    }
}

public struct ResolvedBackground: Equatable, Sendable {
    public let start: String
    public let end: String
    public let name: String
    public let caption: String
    public let angle: Double
    public let seasonalGlow: Bool
    public let ink: String
    public var label: String {
        let colors = start == end || seasonalGlow ? "#\(end)" : "#\(start) → #\(end)"
        return caption.isEmpty ? "\(name)\n\(colors)" : "\(name)\n\(colors)\n\(caption)"
    }
}
