import Foundation

public enum Layout: String, Codable, CaseIterable, Sendable {
    case designed, centred, right
    public var title: String { switch self { case .designed: return "Designed"; case .centred: return "Centred"; case .right: return "Right" } }
}
public enum Fill: String, Codable, CaseIterable, Sendable {
    case gradient, solid
    public var title: String { rawValue.capitalized }
}
public enum Numeral: String, Codable, CaseIterable, Sendable {
    case month, day
    public var title: String { self == .month ? "Month" : "Today's date" }
}
public enum Hemisphere: String, Codable, CaseIterable, Sendable {
    case automatic, northern, southern
    public var title: String { rawValue.capitalized }
    public func resolved(in zone: TimeZone) -> Hemisphere {
        guard self == .automatic else { return self }
        return HemisphereMap.southernZones.contains(zone.identifier) ? .southern : .northern
    }
}
public enum ScheduleMode: String, Codable, CaseIterable, Sendable {
    case off, collapsed, expanded
    public var title: String { rawValue.capitalized }
}

public struct WallpaperSettings: Codable, Equatable, Sendable {
    public var layout: Layout = .designed
    public var fill: Fill = .gradient
    public var numeral: Numeral = .month
    public var hemisphere: Hemisphere = .automatic
    public var schedule: ScheduleMode = .off
    public var allCalendars = true
    public var calendarIDs: Set<String> = []
    public var desktopControls = true
    // Optional fields let version-1 preferences migrate without discarding user choices.
    public var background: BackgroundChoice? = nil
    public var backgroundChoice: BackgroundChoice { background ?? BackgroundChoice() }
    public init() {}
}

public struct Preferences: Codable, Equatable, Sendable {
    public var schemaVersion = 2
    public var draft = WallpaperSettings()
    public var applied = WallpaperSettings()
    public var hasApplied = false
    public var automaticUpdates = true
    public var allDisplays = true
    public var displayIDs: Set<String> = []
    public var draftPlan: DesignPlan? = nil
    public var appliedPlan: DesignPlan? = nil
    // App-wide visibility, independent of saved wallpaper designs. Nil migrates
    // the last choice from the old draft-only Settings switch.
    public var desktopControlsVisible: Bool? = nil
    public init() {}
}

enum HemisphereMap {
    static let southernZones: Set<String> = {
        let resource = Bundle.main.url(forResource: "SouthernTimeZones", withExtension: "json")
            ?? Bundle.module.url(forResource: "SouthernTimeZones", withExtension: "json")
        guard let url = resource,
              let data = try? Data(contentsOf: url),
              let zones = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(zones)
    }()
}
