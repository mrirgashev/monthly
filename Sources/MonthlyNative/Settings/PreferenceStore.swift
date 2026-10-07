import Foundation
import WallpaperCore

enum PreferenceStore {
    static let key = "preferences.v1"
    static func load(defaults: UserDefaults = .standard) -> (Preferences, String?) {
        guard let data = defaults.data(forKey: key) else { return (Preferences(), nil) }
        do {
            var value = try JSONDecoder().decode(Preferences.self, from: data)
            guard (1...2).contains(value.schemaVersion) else {
                defaults.set(data, forKey: "preferences.recovery.\(Int(Date().timeIntervalSince1970))")
                return (Preferences(), "These settings were written by a newer app. Your saved data has been kept.")
            }
            value.schemaVersion = 2
            if value.desktopControlsVisible == nil {
                value.desktopControlsVisible = value.draft.desktopControls
            }
            return (value, nil)
        } catch {
            defaults.set(data, forKey: "preferences.recovery.\(Int(Date().timeIntervalSince1970))")
            return (Preferences(), "Saved settings could not be read. A recovery copy has been kept; defaults are in use.")
        }
    }
    static func save(_ value: Preferences, defaults: UserDefaults = .standard) throws {
        defaults.set(try JSONEncoder().encode(value), forKey: key)
    }
}
