import SwiftUI
import WallpaperCore

@MainActor struct MainWindowView: View {
    @ObservedObject var state: AppState
    let openSettings: () -> Void

    var body: some View {
        Group {
            if state.showingSettings {
                SettingsView(state: state, calendars: state.calendars)
            } else {
                MainView(state: state, openSettings: openSettings)
            }
        }
    }
}

@MainActor struct MainView: View {
    @ObservedObject var state: AppState
    let openSettings: () -> Void
    @State private var showAutomation = false

    private func binding<T>(_ path: WritableKeyPath<WallpaperSettings, T>) -> Binding<T> {
        Binding(get: { state.preferences.draft[keyPath: path] }, set: { value in state.edit { $0[keyPath: path] = value } })
    }
    private var palette: ResolvedBackground {
        state.preferences.draft.backgroundChoice.resolved(month: state.previewSnapshot.month,
            hemisphere: state.preferences.draft.hemisphere.resolved(in: .autoupdatingCurrent), fill: state.preferences.draft.fill)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("MONTHLY / NATIVE").font(.system(size: 11, weight: .medium)).tracking(2.1)
                Spacer()
                Button(action: openSettings) { Label("Settings", systemImage: "slider.horizontal.3") }
                    .buttonStyle(.plain).foregroundStyle(Design.muted).keyboardShortcut(",")
            }.padding(.bottom, 21)
            Rectangle().fill(Design.border).frame(height: 1)
            HStack(alignment: .firstTextBaseline) {
                Text("Your day. Your colours.").font(.system(size: 29, weight: .light)).tracking(-0.7)
                Spacer()
                Circle().fill(Color(hex: palette.end)).frame(width: 7, height: 7)
                Text(state.previewMonth == nil ? "TODAY" : "PREVIEW").font(.system(size: 10, weight: .medium)).tracking(1.6)
            }.padding(.top, 25).padding(.bottom, 9)
            HStack {
                Text("\(state.previewSnapshot.monthName) \(String(state.previewSnapshot.year))  —  \(palette.name)")
                Spacer()
                Text(TimeZone.autoupdatingCurrent.identifier.replacingOccurrences(of: "_", with: " "))
            }.font(.system(size: 12)).foregroundStyle(Design.muted).padding(.bottom, 21)

            ScrollView {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 15) {
                    Color.clear
                        .aspectRatio(state.previewSize.width / state.previewSize.height, contentMode: .fit)
                        .overlay {
                            if let image = state.previewImage {
                                Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
                                    .accessibilityLabel("\(state.previewSnapshot.monthName) wallpaper preview, \(state.preferences.draft.layout.title), \(state.preferences.draft.fill.title)")
                            } else { ProgressView().controlSize(.small) }
                        }
                        .overlay(alignment: .leading) {
                            if state.desktopControlsVisible {
                                PreviewTools(state: state, openSettings: openSettings).padding(.leading, 8)
                            }
                        }
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Design.border, lineWidth: 1))
                    HStack {
                        Text(state.previewDisplay?.name ?? "No display connected")
                        Spacer()
                        Text(state.previewDisplay?.resolution ?? "1440 × 900")
                        if state.previewBusy { ProgressView().controlSize(.mini) }
                    }.font(.system(size: 11)).foregroundStyle(Design.muted)
                    BackgroundEditor(state: state).padding(.top, 6)
                    DisclosureGroup("Inspect another month") {
                        HStack(spacing: 5) {
                            ForEach(1...12, id: \.self) { month in
                                Button(String(month)) { state.previewMonth = month }
                                    .buttonStyle(QuietButtonStyle(selected: state.previewSnapshot.month == month))
                            }
                        }.padding(.vertical, 6)
                        HStack {
                            Text("Inspection only. Apply keeps today's date.")
                            Spacer()
                            Button("Back to today") { state.previewMonth = nil }.buttonStyle(.plain)
                        }.font(.system(size: 11)).foregroundStyle(Design.muted)
                    }.font(.system(size: 12))
                }.frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 19) {
                    field("Layout") { ChoiceRow(options: Layout.allCases, title: { $0.title }, selection: binding(\.layout)) }
                    field("Fill") { ChoiceRow(options: Fill.allCases, title: { $0.title }, selection: binding(\.fill)) }
                    field("Large numeral") { ChoiceRow(options: Numeral.allCases, title: { $0.title }, selection: binding(\.numeral)) }
                    if state.preferences.draft.backgroundChoice.mode == .seasonal {
                        field("Hemisphere") {
                            ChoiceRow(options: Hemisphere.allCases, title: { $0 == .automatic ? "Auto" : $0 == .northern ? "North" : "South" }, selection: binding(\.hemisphere))
                            Text("Seasonal colours follow your time zone, or your override.").font(.system(size: 11)).foregroundStyle(Design.muted)
                        }
                    }
                    field("Today's schedule") {
                        ChoiceRow(options: ScheduleMode.allCases, title: { $0.title }, selection: binding(\.schedule))
                        Button("Choose calendars…", action: openSettings).buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Design.muted)
                    }
                    field("Automatic designs") {
                        if let name = state.editingDesignName {
                            Text("Editing saved design: \(name)").font(.system(size: 12, weight: .medium))
                            Text("Your preview changes update this saved design when you Apply.")
                                .font(.system(size: 11)).foregroundStyle(Design.muted)
                            Button("Finish editing this design", action: state.finishEditingDesign)
                                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Design.muted)
                        }
                        Text(state.preferences.draftPlan?.enabled == true ? state.preferences.draftPlan!.timing.title + " · \(state.preferences.draftPlan!.designs.count) saved" : "Choose designs and set their times.")
                            .font(.system(size: 12)).foregroundStyle(Design.muted)
                        Button("Configure schedule…") { showAutomation = true }.buttonStyle(QuietButtonStyle())
                        Button("Save this preview as a design") { state.saveDesign(); showAutomation = true }
                            .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Design.muted)
                        if let name = state.activeDesignName {
                            Text("On desktop: \(name)").font(.system(size: 11)).foregroundStyle(Design.muted)
                        }
                        if state.preferences.hasApplied && state.preferences.automaticUpdates, let next = state.nextUpdate {
                            Text("Next refresh: \(next.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 11)).foregroundStyle(Design.muted)
                        }
                    }
                    field("Preview display") {
                        Picker("Preview display", selection: $state.previewDisplayID) {
                            ForEach(state.displays) { display in Text(display.name).tag(display.id) }
                        }.labelsHidden().frame(maxWidth: .infinity)
                    }
                }.frame(width: 290)
            }.padding(3)
            }
            .padding(.bottom, 20)
            if let message = state.errorMessage {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.circle")
                    Text(message).textSelection(.enabled)
                    Spacer()
                    Button("Dismiss") { state.errorMessage = nil }.buttonStyle(.plain)
                }.font(.system(size: 12)).foregroundStyle(.red).padding(12).background(Color.red.opacity(0.04)).cornerRadius(7).padding(.bottom, 12)
            }
            Rectangle().fill(Design.border).frame(height: 1)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.hasUnappliedChanges ? "Changes are ready to preview." : state.status).font(.system(size: 12))
                    Text(state.preferences.allDisplays ? "Apply to all connected displays" : "Apply to \(state.selectedDisplays.count) selected displays")
                        .font(.system(size: 11)).foregroundStyle(Design.muted)
                }
                Spacer()
                if state.hasUnappliedChanges && state.preferences.hasApplied {
                    Button("Revert", action: state.discardDraft).buttonStyle(.plain).foregroundStyle(Design.muted)
                }
                Button("Export PNG…", action: state.exportPreview).buttonStyle(QuietButtonStyle()).frame(width: 126)
                Button(action: state.applyDraft) {
                    HStack(spacing: 8) {
                        if state.busy { ProgressView().controlSize(.mini).tint(.white) }
                        Text(state.busy ? "Applying…" : state.preferences.draftPlan?.enabled == true ? "Apply schedule" : "Apply wallpaper")
                    }
                }.buttonStyle(QuietButtonStyle(selected: true)).frame(width: 157)
                    .disabled(state.busy || state.selectedDisplays.isEmpty).keyboardShortcut(.return, modifiers: .command)
            }.padding(.top, 18)
        }
        .padding(28).foregroundStyle(Design.ink).background(Design.paper).preferredColorScheme(.light)
        .frame(minWidth: 900, minHeight: 640)
        .sheet(isPresented: $showAutomation) { DesignAutomationView(state: state) }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) { FieldHeading(title: title); content() }
    }
}

@MainActor struct PreviewTools: View {
    @ObservedObject var state: AppState
    let openSettings: () -> Void
    var body: some View {
        HoverControls(settings: state.preferences.draft, showSettings: openSettings, change: state.edit)
    }
}
