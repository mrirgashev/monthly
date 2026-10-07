import SwiftUI
import ServiceManagement
import WallpaperCore

@MainActor struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject var calendars: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("MONTHLY / NATIVE").font(.system(size: 11, weight: .medium)).tracking(2.1)
                Spacer()
                Button { state.showingSettings = false } label: {
                    Label("Back to wallpaper", systemImage: "arrow.left")
                }.buttonStyle(.plain).foregroundStyle(Design.muted)
            }.padding(.bottom, 21)
            Rectangle().fill(Design.border).frame(height: 1)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings").font(.system(size: 29, weight: .light)).tracking(-0.6)
                group("Every day") {
                    Toggle("Update wallpaper automatically", isOn: Binding(get: { state.preferences.automaticUpdates }, set: { state.setAutomaticUpdates($0) }))
                    Text("Refreshes dates and events at local midnight, at your design times, after sleep, and when displays or calendar events change. Keep the app running in the menu bar.").font(.system(size: 12)).foregroundStyle(Design.muted)
                    Toggle("Launch at login", isOn: Binding(get: { state.loginStatus == .enabled || state.loginStatus == .requiresApproval }, set: { state.setLaunchAtLogin($0) }))
                    if state.loginStatus == .requiresApproval {
                        Button("Approve in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                    }
                    Toggle("Show desktop control dot", isOn: Binding(get: { state.desktopControlsVisible }, set: { state.setDesktopControlsVisible($0) }))
                    Text("Show or hide the dot on the left of your wallpaper immediately. This applies to every design. You can always open the app from the menu bar.")
                        .font(.system(size: 11)).foregroundStyle(Design.muted)
                }
                group("Displays") {
                    Toggle("Apply to all displays, including newly connected displays", isOn: Binding(get: { state.preferences.allDisplays }, set: { state.setAllDisplays($0) }))
                    ForEach(state.displays) { display in
                        Toggle(isOn: Binding(get: { state.preferences.allDisplays || state.preferences.displayIDs.contains(display.id) }, set: { enabled in
                            state.setDisplaySelected(display, enabled: enabled)
                        })) {
                            HStack { Text(display.name); Spacer(); Text(display.resolution).foregroundStyle(Design.muted) }
                        }.disabled(state.preferences.allDisplays)
                    }
                    Text("Each display gets its own image at its full backing resolution. Disconnected display selections are retained.").font(.system(size: 12)).foregroundStyle(Design.muted)
                }
                group("Calendars") {
                    Text("Show today's events from macOS Calendar, including Google calendars added in System Settings → Internet Accounts.")
                        .font(.system(size: 12)).foregroundStyle(Design.muted)
                    Text("Calendar selections take effect when you return to the wallpaper and Apply.")
                        .font(.system(size: 11)).foregroundStyle(Design.muted)
                    if !calendars.authorized {
                        Button("Connect Calendars…") {
                            Task { await calendars.requestAccess(); state.requestPreview() }
                        }.buttonStyle(QuietButtonStyle()).frame(width: 190)
                        Text("macOS requires Full Access to read events. This app only reads; it never creates, edits, or sends events. Event titles appear on your desktop and in saved wallpaper images.")
                            .font(.system(size: 11)).foregroundStyle(Design.muted)
                    } else {
                        Toggle("All calendars", isOn: Binding(get: { state.preferences.draft.allCalendars }, set: { enabled in state.edit { $0.allCalendars = enabled } }))
                        ForEach(calendars.calendars) { calendar in
                            Toggle(isOn: Binding(get: { state.preferences.draft.allCalendars || state.preferences.draft.calendarIDs.contains(calendar.id) }, set: { enabled in
                                state.edit { settings in
                                    if enabled { settings.calendarIDs.insert(calendar.id) } else { settings.calendarIDs.remove(calendar.id) }
                                }
                            })) {
                                HStack {
                                    Circle().fill(Color(nsColor: calendar.color)).frame(width: 7, height: 7)
                                    Text(calendar.title)
                                    Spacer()
                                    Text(calendar.source).foregroundStyle(Design.muted).font(.system(size: 11))
                                }
                            }.disabled(state.preferences.draft.allCalendars)
                        }
                        if calendars.calendars.isEmpty { Text("No calendars are available in macOS Calendar.").foregroundStyle(Design.muted) }
                    }
                    if let message = calendars.message { Text(message).font(.system(size: 12)).foregroundStyle(.red) }
                }
                group("About") {
                    Text("Monthly Native 1.2").font(.system(size: 13, weight: .medium))
                    Text("An independent native implementation inspired by Living Monthly Wallpapers. Not affiliated with BetterCreating. Helvetica Neue is supplied by macOS. No web engine, third-party wallpaper app, or runtime downloads.")
                        .font(.system(size: 12)).foregroundStyle(Design.muted)
                    Button("Show generated wallpapers…") {
                        let url = RenderService.directory
                        if FileManager.default.fileExists(atPath: url.path) { NSWorkspace.shared.open(url) }
                    }.buttonStyle(.plain)
                }
                if let error = state.errorMessage { Text(error).foregroundStyle(.red).font(.system(size: 12)).textSelection(.enabled) }
            }.padding(.vertical, 25).frame(maxWidth: 760)
                .frame(maxWidth: .infinity, alignment: .center).padding(.horizontal, 3)
        }
        }.padding(28).background(Design.paper).foregroundStyle(Design.ink).preferredColorScheme(.light)
            .frame(minWidth: 900, minHeight: 640)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            FieldHeading(title: title)
            content()
        }.toggleStyle(.switch).controlSize(.small)
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Design.border, lineWidth: 1))
    }
}
