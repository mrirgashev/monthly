import AppKit
import SwiftUI
import Combine
import Carbon
import WallpaperCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var state: AppState!
    private var statusItem: NSStatusItem!
    private var mainWindow: NSWindow?
    private var overlays: [NSPanel] = []
    private var observers = Set<AnyCancellable>()
    private var menuActions: [Int: () -> Void] = [:]
    private var nextAction = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        state = AppState()
        state.onApplied = { [weak self] in self?.rebuildOverlays() }
        state.onDisplaysChanged = { [weak self] in self?.rebuildOverlays() }
        state.onDesktopControlsChanged = { [weak self] in self?.rebuildOverlays() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Monthly Native")
        statusItem.button?.toolTip = "Monthly Native — your living calendar wallpaper"
        let menu = NSMenu(); menu.delegate = self; statusItem.menu = menu
        installApplicationMenu()
        let event = NSAppleEventManager.shared().currentAppleEvent
        let loginLaunch = event?.paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem))?.booleanValue == true
            || event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
        rebuildOverlays()
        if !loginLaunch || !state.preferences.hasApplied { showMain() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMain(); return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        state?.shutdown(); overlays.forEach { $0.close() }
    }
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.mainWindow?.isVisible != true {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    @objc func showMain() {
        state.showingSettings = false
        presentMainWindow()
    }

    private func presentMainWindow() {
        if mainWindow == nil {
            let view = MainWindowView(state: state, openSettings: { [weak self] in self?.showSettings() })
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 960),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Monthly Native"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .white
            window.contentView = NSHostingView(rootView: view)
            window.minSize = NSSize(width: 920, height: 680)
            window.setFrameAutosaveName("MonthlyNative.Main")
            window.isReleasedWhenClosed = false; window.delegate = self
            window.center(); mainWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        state.requestPreview()
    }

    @objc private func reapplyWallpaper() { state.reapply() }

    @objc func showSettings() {
        state.calendars.refreshAuthorization()
        state.showingSettings = true
        presentMainWindow()
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems(); menuActions.removeAll(); nextAction = 0
        let heading = NSMenuItem(title: "\(state.current.monthName) \(state.current.day), \(state.current.year)", action: nil, keyEquivalent: "")
        heading.isEnabled = false; menu.addItem(heading)
        add("Open Monthly Native…", to: menu, key: "o") { [weak self] in self?.showMain() }
        add(state.busy ? "Applying…" : "Reapply wallpaper", to: menu, key: "r", enabled: !state.busy) { [weak self] in self?.state.reapply() }
        menu.addItem(.separator())
        submenu("Layout", in: menu, values: Layout.allCases, selected: state.effectiveSettings.layout, title: { $0.title }) { [weak self] value in
            self?.state.quickChange { $0.layout = value }
        }
        submenu("Fill", in: menu, values: Fill.allCases, selected: state.effectiveSettings.fill, title: { $0.title }) { [weak self] value in
            self?.state.quickChange { $0.fill = value }
        }
        submenu("Large numeral", in: menu, values: Numeral.allCases, selected: state.effectiveSettings.numeral, title: { $0.title }) { [weak self] value in
            self?.state.quickChange { $0.numeral = value }
        }
        submenu("Hemisphere", in: menu, values: Hemisphere.allCases, selected: state.effectiveSettings.hemisphere, title: { $0.title }) { [weak self] value in
            self?.state.quickChange { $0.hemisphere = value }
        }
        submenu("Today's schedule", in: menu, values: ScheduleMode.allCases, selected: state.effectiveSettings.schedule, title: { $0.title }) { [weak self] value in
            self?.state.quickChange { $0.schedule = value }
        }
        menu.addItem(.separator())
        add("Automatic updates", to: menu, checked: state.preferences.automaticUpdates) { [weak self] in
            guard let self else { return }; self.state.setAutomaticUpdates(!self.state.preferences.automaticUpdates)
        }
        add("Settings…", to: menu, key: ",") { [weak self] in self?.showSettings() }
        if state.errorMessage != nil {
            add("View update error…", to: menu) { [weak self] in self?.showMain() }
        }
        menu.addItem(.separator())
        add("Quit Monthly Native", to: menu, key: "q") { NSApp.terminate(nil) }
    }

    private func submenu<T: Equatable>(_ name: String, in menu: NSMenu, values: [T], selected: T,
                                      title: (T) -> String, action: @escaping (T) -> Void) {
        let parent = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        let child = NSMenu()
        for value in values { add(title(value), to: child, enabled: !state.busy, checked: value == selected) { action(value) } }
        parent.submenu = child; menu.addItem(parent)
    }

    private func add(_ title: String, to menu: NSMenu, key: String = "", enabled: Bool = true,
                     checked: Bool = false, action: @escaping () -> Void) {
        let item = NSMenuItem(title: title, action: #selector(performMenuAction(_:)), keyEquivalent: key)
        item.target = self; item.tag = nextAction; item.isEnabled = enabled
        item.state = checked ? .on : .off
        menuActions[nextAction] = action; nextAction += 1
        menu.autoenablesItems = false; menu.addItem(item)
    }
    @objc private func performMenuAction(_ sender: NSMenuItem) { menuActions[sender.tag]?() }

    private func installApplicationMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Monthly Native", action: #selector(showSettings), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Monthly Native", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Monthly Native", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; main.addItem(appItem)
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: ""), file = NSMenu(title: "File")
        file.addItem(withTitle: "Open Monthly Native…", action: #selector(showMain), keyEquivalent: "o").target = self
        file.addItem(withTitle: "Reapply Wallpaper", action: #selector(reapplyWallpaper), keyEquivalent: "r").target = self
        fileItem.submenu = file; main.addItem(fileItem)
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""), edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit; main.addItem(editItem)
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: ""), windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu; main.addItem(windowItem)
        NSApp.mainMenu = main; NSApp.windowsMenu = windowMenu
    }

    private func rebuildOverlays() {
        overlays.forEach { $0.close() }; overlays.removeAll()
        guard state.preferences.hasApplied, state.desktopControlsVisible else { return }
        for display in state.selectedDisplays {
            guard let screen = display.screen else { continue }
            let height: CGFloat = 256
            let rect = NSRect(x: screen.frame.minX + screen.frame.width * 0.012,
                              y: screen.frame.midY - height / 2, width: 38, height: height)
            let panel = DesktopControlPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isFloatingPanel = false; panel.hidesOnDeactivate = false
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: DesktopControlsView(state: state, showSettings: { [weak self] in self?.showSettings() }))
            panel.orderBack(nil); overlays.append(panel)
        }
    }
}

private final class DesktopControlPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor private struct DesktopControlsView: View {
    @ObservedObject var state: AppState
    let showSettings: () -> Void
    var body: some View {
        HoverControls(settings: state.effectiveSettings, showSettings: showSettings, change: state.quickChange)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
