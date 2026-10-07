import AppKit
import WallpaperCore

enum SampleExporter {
    static func run() throws {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--render-samples"), args.count > index + 1 else {
            throw NSError(domain: "MonthlyNative", code: 1, userInfo: [NSLocalizedDescriptionKey: "Usage: MonthlyNative --render-samples OUTPUT_DIRECTORY"])
        }
        let directory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
        guard Hemisphere.automatic.resolved(in: TimeZone(identifier: "Australia/Sydney")!) == .southern else {
            throw NSError(domain: "MonthlyNative", code: 2, userInfo: [NSLocalizedDescriptionKey: "Packaged timezone resources are missing."])
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let zone = TimeZone(identifier: "Europe/London")!
        for month in 1...12 {
            for fill in Fill.allCases {
                for layout in Layout.allCases {
                    var settings = WallpaperSettings(); settings.fill = fill; settings.layout = layout
                    settings.hemisphere = .northern
                    let date = CalendarSnapshot.previewDate(month: month, year: 2026, timeZone: zone)!
                    let request = RenderRequest(date: date, timeZone: zone, settings: settings, events: [],
                                                logicalSize: CGSize(width: 1440, height: 900),
                                                pixelSize: CGSize(width: 960, height: 600), highlightToday: true)
                    let data = try WallpaperRenderer.png(WallpaperRenderer.render(request))
                    try data.write(to: directory.appendingPathComponent(String(format: "%02d-%@-%@.png", month, fill.rawValue, layout.rawValue)), options: .atomic)
                }
            }
        }
        // Deterministic stress scenes use synthetic titles only, never EventKit data.
        let stressDate = ISO8601DateFormatter().date(from: "2024-03-31T12:00:00Z")!
        let events = (0..<9).map { index in
            ScheduleEntry(id: "fixture-\(index)", title: index == 0 ? "Design review — a long title that should truncate safely" : "Planning デザイン \(index)",
                          time: index == 0 ? "All day" : "09:30", start: stressDate, end: stressDate.addingTimeInterval(3600), allDay: index == 0)
        }
        for (name, size) in [("portrait", CGSize(width: 1080, height: 1920)),
                             ("ultrawide", CGSize(width: 3440, height: 1440)),
                             ("retina", CGSize(width: 2880, height: 1800))] {
            for layout in Layout.allCases {
                var settings = WallpaperSettings(); settings.layout = layout
                settings.numeral = .day; settings.hemisphere = .southern; settings.schedule = .expanded
                let request = RenderRequest(date: stressDate, timeZone: zone, settings: settings, events: events,
                                            logicalSize: size, pixelSize: size, highlightToday: true)
                try WallpaperRenderer.png(WallpaperRenderer.render(request)).write(to: directory.appendingPathComponent("stress-\(name)-\(layout.rawValue).png"))
            }
        }
        for size in [CGSize(width: 1920, height: 1080), CGSize(width: 1440, height: 900)] {
            var settings = WallpaperSettings(); settings.hemisphere = .northern
            let request = RenderRequest(date: ISO8601DateFormatter().date(from: "2026-10-06T12:00:00Z")!, timeZone: zone,
                                        settings: settings, events: [], logicalSize: size, pixelSize: size, highlightToday: true)
            try WallpaperRenderer.png(WallpaperRenderer.render(request)).write(to: directory.appendingPathComponent("reference-october-\(Int(size.width)).png"))
        }
        for (index, preset) in GradientPreset.all.enumerated() {
            var settings = WallpaperSettings(), background = BackgroundChoice()
            background.mode = .preset; background.presetID = preset.id; settings.background = background
            settings.layout = Layout.allCases[index % 3]; settings.numeral = .day
            let request = RenderRequest(date: stressDate, timeZone: zone, settings: settings, events: [],
                logicalSize: CGSize(width: 1440, height: 900), pixelSize: CGSize(width: 960, height: 600), highlightToday: true)
            try WallpaperRenderer.png(WallpaperRenderer.render(request)).write(to: directory.appendingPathComponent("preset-\(preset.id).png"))
        }
        for hex in ["000000", "FFFFFF", "FF00FF", "123456"] {
            var settings = WallpaperSettings(), background = BackgroundChoice()
            background.mode = .custom; background.firstHex = hex; settings.background = background
            settings.fill = .solid; settings.layout = .right; settings.numeral = .day; settings.schedule = .expanded
            let request = RenderRequest(date: stressDate, timeZone: zone, settings: settings, events: events,
                logicalSize: CGSize(width: 1440, height: 900), pixelSize: CGSize(width: 1440, height: 900), highlightToday: true)
            try WallpaperRenderer.png(WallpaperRenderer.render(request)).write(to: directory.appendingPathComponent("custom-\(hex).png"))
        }
        print("Rendered 83 seasonal/reference scenes, 24 gradient presets and 4 custom-colour scenes to \(directory.path)")
    }
}
