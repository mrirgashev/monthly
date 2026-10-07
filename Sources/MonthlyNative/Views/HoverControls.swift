import SwiftUI
import WallpaperCore

struct HoverControls: View {
    let settings: WallpaperSettings
    let showSettings: () -> Void
    let change: (@escaping (inout WallpaperSettings) -> Void) -> Void
    @State private var expanded = false
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            Button { expanded.toggle() } label: {
                Circle().fill(.black.opacity(0.45)).frame(width: 7, height: 7).frame(width: 28, height: 24)
            }.buttonStyle(.plain).help("Show wallpaper controls").accessibilityLabel("Show wallpaper controls")
            if expanded {
                icon("slider.horizontal.3", "Open settings", action: showSettings)
                Menu {
                    ForEach(Hemisphere.allCases, id: \.self) { value in
                        Button(value.title) { change { $0.hemisphere = value } }
                    }
                } label: { Image(systemName: "globe").frame(width: 28, height: 24) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().frame(width: 28, height: 24).help("Hemisphere").accessibilityLabel("Hemisphere")
                icon("calendar", "Switch month or day") { change { $0.numeral = $0.numeral == .month ? .day : .month } }
                icon("circle.lefthalf.filled", "Switch solid or gradient") { change { $0.fill = $0.fill == .solid ? .gradient : .solid } }
                Menu {
                    ForEach(Layout.allCases, id: \.self) { value in Button(value.title) { change { $0.layout = value } } }
                } label: { Image(systemName: "rectangle.split.3x1").frame(width: 28, height: 24) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().frame(width: 28, height: 24).help("Layout").accessibilityLabel("Layout")
                Menu {
                    ForEach(ScheduleMode.allCases, id: \.self) { value in Button(value.title) { change { $0.schedule = value } } }
                } label: { Image(systemName: "calendar.badge.clock").frame(width: 28, height: 24) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().frame(width: 28, height: 24).help("Today's schedule").accessibilityLabel("Today's schedule")
            }
        }
        .font(.system(size: 19, weight: .ultraLight))
        .foregroundStyle(.black.opacity(hovered ? 0.8 : 0.45))
        .frame(width: 30).padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { inside in hovered = inside; if inside { expanded = true } }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: expanded)
        .preferredColorScheme(.light)
    }
    private func icon(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 28, height: 24) }
            .buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
}
