import AppKit
import Combine
import EventKit
import ServiceManagement
import UniformTypeIdentifiers
import WallpaperCore

@MainActor final class AppState: ObservableObject {
    @Published var preferences: Preferences
    @Published private(set) var displays: [Display] = []
    @Published var previewDisplayID = ""
    @Published var previewMonth: Int? = nil
    @Published var showingSettings = false
    @Published private(set) var editingDesignID: UUID?
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var busy = false
    @Published private(set) var previewBusy = false
    @Published var errorMessage: String?
    @Published private(set) var status = "Preview your wallpaper, then apply it."
    @Published private(set) var loginStatus = SMAppService.mainApp.status
    let calendars = CalendarService()
    var onApplied: (() -> Void)?
    var onDisplaysChanged: (() -> Void)?
    var onDesktopControlsChanged: (() -> Void)?
    @Published private(set) var nextUpdate: Date?
    private var refreshTimer: Timer?
    private var observations: [(NotificationCenter, NSObjectProtocol)] = []
    private var exportPanel: NSSavePanel?
    private var previewTask: Task<Void, Never>?
    private var automaticTask: Task<Void, Never>?
    private var applyAgain = false
    private var previewRevision = 0
    private var environmentRevision = 0
    private var pausedForSleep = false
    private var lastAppliedURLs: [String: URL] = [:]
    private var cancellables = Set<AnyCancellable>()

    init() {
        let (saved, warning) = PreferenceStore.load()
        preferences = saved; errorMessage = warning
        displays = Display.connected()
        previewDisplayID = displays.first?.id ?? ""
        $preferences.dropFirst().sink { [weak self] value in
            do { try PreferenceStore.save(value) } catch { self?.errorMessage = error.localizedDescription }
            self?.requestPreview()
            Task { @MainActor [weak self] in self?.scheduleRefresh() }
        }.store(in: &cancellables)
        $previewMonth.dropFirst().sink { [weak self] _ in self?.requestPreview() }.store(in: &cancellables)
        $previewDisplayID.dropFirst().sink { [weak self] _ in self?.requestPreview() }.store(in: &cancellables)
        observeSystem()
        scheduleRefresh()
        requestPreview()
        if saved.hasApplied && saved.automaticUpdates { requestAutomaticApply() }
    }

    var current: CalendarSnapshot { CalendarSnapshot(date: Date()) }
    var desktopControlsVisible: Bool { preferences.desktopControlsVisible ?? preferences.draft.desktopControls }
    func setDesktopControlsVisible(_ visible: Bool) {
        preferences.desktopControlsVisible = visible
        onDesktopControlsChanged?()
    }
    var hasUnappliedChanges: Bool {
        preferences.draft != preferences.applied || preferences.draftPlan != preferences.appliedPlan || !preferences.hasApplied
    }
    var effectiveSettings: WallpaperSettings { settings(at: Date()) }
    private func settings(at date: Date) -> WallpaperSettings {
        DesignTimeline.settings(base: preferences.applied,
            plan: preferences.automaticUpdates ? preferences.appliedPlan : nil, at: date, timeZone: .current)
    }
    var activeDesignName: String? {
        guard preferences.automaticUpdates, let plan = preferences.appliedPlan,
              let index = DesignTimeline.index(for: plan, at: Date(), timeZone: .current) else { return nil }
        return plan.designs[index].name
    }
    func editPlan(_ body: (inout DesignPlan) -> Void) {
        var plan = preferences.draftPlan ?? DesignPlan()
        body(&plan); preferences.draftPlan = plan
    }
    func saveDesign() {
        editingDesignID = nil
        guard (preferences.draftPlan?.designs.count ?? 0) < 24 else { return }
        let settings = preferences.draft
        let appearance = settings.backgroundChoice.resolved(month: current.month,
            hemisphere: settings.hemisphere.resolved(in: .current), fill: settings.fill)
        editPlan { plan in
            let used = Set(plan.designs.map(\.minuteOfDay))
            let minute = (0..<24).map { (480 + $0 * 60) % 1440 }.first { !used.contains($0) } ?? 480
            plan.designs.append(SavedDesign(name: "\(appearance.name) · \(settings.layout.title)", settings: settings, minuteOfDay: minute))
        }
    }
    var previewDisplay: Display? { displays.first { $0.id == previewDisplayID } ?? displays.first }
    var previewSize: CGSize { previewDisplay?.logicalSize ?? CGSize(width: 1440, height: 900) }
    var selectedDisplays: [Display] {
        displays.filter { preferences.allDisplays || preferences.displayIDs.contains($0.id) }
    }
    var previewDate: Date {
        if previewMonth == current.month { return Date() }
        return previewMonth.flatMap { CalendarSnapshot.previewDate(month: $0, year: current.year) } ?? Date()
    }
    var previewSnapshot: CalendarSnapshot { CalendarSnapshot(date: previewDate) }

    func edit(_ body: (inout WallpaperSettings) -> Void) {
        body(&preferences.draft)
        if let id = editingDesignID {
            let draft = preferences.draft
            editPlan { plan in
                if let index = plan.designs.firstIndex(where: { $0.id == id }) { plan.designs[index].settings = draft }
            }
        }
        requestPreview()
    }
    var editingDesignName: String? {
        preferences.draftPlan?.designs.first { $0.id == editingDesignID }?.name
    }
    func beginEditingDesign(_ design: SavedDesign) {
        editingDesignID = design.id; preferences.draft = design.settings; previewMonth = nil
    }
    func finishEditingDesign() { editingDesignID = nil }
    func discardDraft() { editingDesignID = nil; preferences.draft = preferences.applied; preferences.draftPlan = preferences.appliedPlan; requestPreview() }

    func requestPreview() {
        previewRevision += 1
        let revision = previewRevision
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.previewBusy = true
            let size = self.previewSize
            let factor = min(1, 1400 / max(size.width, size.height))
            let request = self.request(settings: self.preferences.draft, date: self.previewDate,
                                       logicalSize: size, pixelSize: CGSize(width: size.width * factor, height: size.height * factor),
                                       highlight: self.previewMonth == nil || self.previewMonth == self.current.month)
            do {
                let image = try await RenderService.shared.preview(request)
                guard !Task.isCancelled, revision == self.previewRevision else { return }
                self.previewImage = NSImage(cgImage: image, size: size)
                self.previewBusy = false
            } catch {
                guard revision == self.previewRevision else { return }
                self.previewBusy = false; self.errorMessage = error.localizedDescription
            }
        }
    }

    private func request(settings: WallpaperSettings, date: Date, logicalSize: CGSize,
                         pixelSize: CGSize, highlight: Bool = true) -> RenderRequest {
        let zone = TimeZone.current
        let events = settings.schedule == .off ? [] : calendars.events(on: date, timeZone: zone, selectedIDs: settings.calendarIDs, allCalendars: settings.allCalendars)
        return RenderRequest(date: date, timeZone: zone, settings: settings, events: events,
                             logicalSize: logicalSize, pixelSize: pixelSize, highlightToday: highlight)
    }

    func applyDraft() {
        guard !busy else { return }
        if let error = preferences.draftPlan?.validationError { errorMessage = error; return }
        let scheduledSettings = preferences.draftPlan?.enabled == true ? preferences.draftPlan!.designs.map(\.settings) : []
        if ([preferences.draft] + scheduledSettings).contains(where: { $0.schedule != .off }) && !calendars.authorized {
            errorMessage = "Connect Calendars before applying a schedule, or set the schedule to Off."
            return
        }
        guard !selectedDisplays.isEmpty else { errorMessage = "Choose at least one connected display."; return }
        errorMessage = nil
        preferences.applied = preferences.draft
        preferences.appliedPlan = preferences.draftPlan
        if preferences.appliedPlan?.enabled == true { preferences.automaticUpdates = true }
        environmentRevision += 1
        scheduleRefresh()
        preferences.hasApplied = true
        previewMonth = nil
        Task { await apply(force: true) }
    }

    func quickChange(_ body: (inout WallpaperSettings) -> Void) {
        guard !busy else { return }
        var value = effectiveSettings
        body(&value)
        if value.schedule != .off && !calendars.authorized {
            errorMessage = "Connect Calendars in Settings to show your schedule."
            return
        }
        guard !selectedDisplays.isEmpty else { errorMessage = "Choose a connected display in Settings."; return }
        // A manual quick change intentionally pauses the design cycle. Date and event
        // refreshes keep running; saved designs remain available in the editor.
        preferences.appliedPlan?.timing = .off; preferences.draftPlan?.timing = .off
        preferences.applied = value; preferences.draft = value
        environmentRevision += 1; scheduleRefresh()
        preferences.hasApplied = true; previewMonth = nil
        Task { await apply(force: true) }
    }

    func reapply() {
        if !preferences.hasApplied { applyDraft(); return }
        Task { await apply(force: true) }
    }

    private func apply(force: Bool) async {
        guard !pausedForSleep else { applyAgain = true; return }
        guard !busy else { applyAgain = true; return }
        guard preferences.hasApplied else { return }
        let targets = selectedDisplays
        guard !targets.isEmpty else { status = "Waiting for a selected display."; return }
        busy = true
        let revision = environmentRevision
        let date = Date()
        let settings = settings(at: date)
        let dayKey = CalendarSnapshot(date: date).dayKey
        var errors: [String] = []
        var applied = 0
        defer {
            busy = false; scheduleRefresh(); onApplied?()
            if applyAgain { applyAgain = false; requestAutomaticApply(force: force) }
        }
        for display in targets {
            if pausedForSleep || revision != environmentRevision || settings != self.settings(at: Date()) {
                applyAgain = true; break
            }
            do {
                let request = request(settings: settings, date: date, logicalSize: display.logicalSize, pixelSize: display.pixelSize)
                let result = try await RenderService.shared.wallpaper(request)
                guard !Task.isCancelled, !pausedForSleep, revision == environmentRevision,
                      dayKey == current.dayKey, settings == self.settings(at: Date()),
                      selectedDisplays.contains(display),
                      let screen = display.screen else { applyAgain = true; continue }
                let currentURL = NSWorkspace.shared.desktopImageURL(for: screen)
                if force || currentURL != result.url || lastAppliedURLs[display.id] != result.url {
                    try NSWorkspace.shared.setDesktopImageURL(result.url, for: screen, options: [
                        .imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
                        .allowClipping: false
                    ])
                }
                lastAppliedURLs[display.id] = result.url
                applied += 1
            } catch { errors.append("\(display.name): \(error.localizedDescription)") }
        }
        if !errors.isEmpty {
            errorMessage = errors.joined(separator: "\n")
            status = "Applied to \(applied) of \(targets.count) displays. Reapply to retry."
        } else if applied > 0 {
            errorMessage = settings.schedule != .off && !calendars.authorized
                ? "Calendar access is off. Reconnect in Settings to refresh today's events." : nil
            status = "Updated \(current.monthName) \(current.day) · \(applied) display\(applied == 1 ? "" : "s")"
            if let name = activeDesignName { status += " · \(name)" }
        }
    }

    func requestAutomaticApply(force: Bool = false) {
        guard preferences.hasApplied, preferences.automaticUpdates || force, !pausedForSleep else { return }
        automaticTask?.cancel()
        automaticTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
            guard !Task.isCancelled, let self else { return }
            await self.apply(force: force)
        }
    }

    func setAutomaticUpdates(_ enabled: Bool) {
        environmentRevision += 1
        // Freeze the currently visible design when pausing, without losing the plan.
        let visible = effectiveSettings
        preferences.automaticUpdates = enabled
        if !enabled { preferences.applied = visible }
        scheduleRefresh()
        if enabled { requestAutomaticApply() } else { automaticTask?.cancel() }
    }

    func setAllDisplays(_ enabled: Bool) {
        environmentRevision += 1
        preferences.allDisplays = enabled
        onDisplaysChanged?()
        requestAutomaticApply()
    }

    func setDisplaySelected(_ display: Display, enabled: Bool) {
        environmentRevision += 1
        if enabled { preferences.displayIDs.insert(display.id) } else { preferences.displayIDs.remove(display.id) }
        onDisplaysChanged?()
        requestAutomaticApply()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { errorMessage = "Launch at login: \(error.localizedDescription)" }
        loginStatus = SMAppService.mainApp.status
    }

    func refreshEnvironment() {
        environmentRevision += 1
        displays = Display.connected()
        if !displays.contains(where: { $0.id == previewDisplayID }) { previewDisplayID = displays.first?.id ?? "" }
        calendars.refreshAuthorization()
        loginStatus = SMAppService.mainApp.status
        onDisplaysChanged?()
        requestPreview(); scheduleRefresh(); requestAutomaticApply()
    }

    private func scheduleRefresh() {
        refreshTimer?.invalidate()
        guard !pausedForSleep else { nextUpdate = nil; return }
        let date = Date()
        let next = DesignTimeline.nextRefresh(
            plan: preferences.automaticUpdates && preferences.hasApplied ? preferences.appliedPlan : nil,
            after: date, timeZone: .current)
        nextUpdate = next
        // One-shot timer, rescheduled from the wall clock on every wake/clock change.
        // Midnight remains a refresh boundary even when the selected design is fixed.
        let timer = Timer(fire: next.addingTimeInterval(0.15), interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refreshEnvironment() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func observeSystem() {
        func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping @MainActor () -> Void) {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in action() }
            }
            observations.append((center, token))
        }
        let normal = NotificationCenter.default, workspace = NSWorkspace.shared.notificationCenter
        for name in [NSApplication.didChangeScreenParametersNotification, .NSSystemTimeZoneDidChange,
                     .NSSystemClockDidChange, .NSCalendarDayChanged, .EKEventStoreChanged] {
            observe(normal, name) { [weak self] in self?.refreshEnvironment() }
        }
        observe(workspace, NSWorkspace.willSleepNotification) { [weak self] in
            self?.pausedForSleep = true; self?.environmentRevision += 1
            self?.refreshTimer?.invalidate(); self?.automaticTask?.cancel()
        }
        observe(workspace, NSWorkspace.didWakeNotification) { [weak self] in
            self?.pausedForSleep = false; self?.refreshEnvironment()
        }
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { [weak self] in self?.environmentRevision += 1; self?.requestAutomaticApply() }
        observe(normal, NSApplication.didBecomeActiveNotification) { [weak self] in self?.refreshEnvironment() }
    }

    func exportPreview() {
        guard exportPanel == nil else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(previewSnapshot.monthName)-\(previewSnapshot.year).png"
        exportPanel = panel
        NSApp.activate(ignoringOtherApps: true)
        // A synchronous runModal() can occupy the main actor while the dialog is
        // open. Use a sheet so timer, Calendar and wake updates remain responsive.
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.exportPanel = nil
                guard response == .OK, let destination = panel.url else { return }
                let size = self.previewDisplay?.pixelSize ?? CGSize(width: 2880, height: 1800)
                let request = self.request(settings: self.preferences.draft, date: self.previewDate,
                    logicalSize: self.previewSize, pixelSize: size,
                    highlight: self.previewMonth == nil || self.previewMonth == self.current.month)
                do {
                    let result = try await RenderService.shared.wallpaper(request)
                    try Data(contentsOf: result.url).write(to: destination, options: .atomic)
                } catch { self.errorMessage = error.localizedDescription }
            }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    func shutdown() {
        exportPanel?.cancel(nil); exportPanel = nil
        refreshTimer?.invalidate(); previewTask?.cancel(); automaticTask?.cancel()
        observations.forEach { $0.0.removeObserver($0.1) }
        observations.removeAll()
    }
}
