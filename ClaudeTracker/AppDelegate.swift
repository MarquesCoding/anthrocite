import SwiftUI
import AppKit

/// Owns the status-bar item and a native NSMenu. The menu's chrome (material,
/// blur, corners, shadow) is drawn entirely by the system — we apply no
/// background styling. Rich data lives in a transparent custom view item; all
/// interaction lives in real NSMenuItems.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let usage = UsageStore()
    let status = StatusStore()
    let pricing = PricingStore()

    private var statusItem: NSStatusItem!
    private var tick: Timer?
    private var menuOpen = false

    private var showStatus: Bool {
        UserDefaults.standard.object(forKey: Prefs.showStatusKey) == nil ? true
            : UserDefaults.standard.bool(forKey: Prefs.showStatusKey)
    }
    private var showTimer: Bool {
        UserDefaults.standard.object(forKey: Prefs.showTimerKey) == nil ? true
            : UserDefaults.standard.bool(forKey: Prefs.showTimerKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        usage.start()
        status.start()
        pricing.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refreshButton()

        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshButton()
        }

        // Once the Settings window closes, drop back to a menu-bar-only agent.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            DispatchQueue.main.async {
                let stillOpen = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
                if !stillOpen { NSApp.setActivationPolicy(.accessory) }
            }
        }
    }

    // MARK: NSMenuDelegate — rebuild fresh each time it opens

    func menuWillOpen(_ menu: NSMenu) { menuOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuOpen = false; refreshButton() }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let content = NSMenuItem()
        let host = NSHostingView(rootView: MenuContentView(usage: usage, status: status, pricing: pricing))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        content.view = host
        menu.addItem(content)

        menu.addItem(.separator())

        addToggle("Show status text", on: showStatus, action: #selector(toggleStatus), enabled: true, to: menu)
        addToggle("Show timer", on: showTimer, action: #selector(toggleTimer), enabled: showStatus, to: menu)

        menu.addItem(.separator())

        let dash = addAction("Open Dashboard…", #selector(openDashboard), to: menu)
        dash.keyEquivalent = "d"
        let settings = addAction("Settings…", #selector(openSettings), to: menu)
        settings.keyEquivalent = ","
        addHeader("Version \(AppInfo.version)", to: menu)
        addAction("Refresh Now", #selector(refreshNow), to: menu)
        let quit = addAction("Quit \(AppInfo.name)", #selector(quit), to: menu)
        quit.keyEquivalent = "q"
    }

    // MARK: Menu builders

    @discardableResult
    private func addHeader(_ title: String, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        return item
    }

    @discardableResult
    private func addAction(_ title: String, _ action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        menu.addItem(item)
        return item
    }

    private func addToggle(_ title: String, on: Bool, action: Selector, enabled: Bool, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        item.isEnabled = enabled
        menu.addItem(item)
    }

    // MARK: Actions

    @objc private func toggleStatus() {
        UserDefaults.standard.set(!showStatus, forKey: Prefs.showStatusKey)
    }
    @objc private func toggleTimer() {
        UserDefaults.standard.set(!showTimer, forKey: Prefs.showTimerKey)
    }
    @objc private func refreshNow() { Task { await usage.refresh() } }
    @objc private func quit() { NSApp.terminate(nil) }
    private var settingsWindow: NSWindow?
    private var dashboardWindow: NSWindow?

    @objc private func openDashboard() {
        if dashboardWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 860, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            w.title = "\(AppInfo.name) Dashboard"
            w.isReleasedWhenClosed = false
            w.center()
            w.contentView = NSHostingView(rootView: DashboardView(usage: usage, pricing: pricing))
            dashboardWindow = w
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 470),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            w.title = AppInfo.name
            w.isReleasedWhenClosed = false
            w.center()
            w.contentView = NSHostingView(rootView: SettingsView(usage: usage, pricing: pricing))
            settingsWindow = w
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }


    // MARK: Status-bar button

    private func refreshButton() {
        guard let button = statusItem.button, !menuOpen else { return }
        let d = UserDefaults.standard
        let accent = AccentChoice(rawValue: d.string(forKey: Prefs.accentKey) ?? "") ?? .system
        button.image = MenuBarIcon.image(accent: accent)

        if let title = showStatus ? menuTitle() : nil {
            button.title = " " + title
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    /// Stable multi-session summary: one working session shows its verb + timer;
    /// several show a "N working" count; none shows just the icon.
    private func menuTitle() -> String? {
        let working = status.workingSessions
        switch working.count {
        case 0:
            return nil
        case 1:
            let s = working[0]
            if showTimer, let since = s.activeSince {
                return "\(s.statusText) \(max(0, Int(Date().timeIntervalSince(since))))s"
            }
            return s.statusText
        default:
            return "\(working.count) working"
        }
    }

    static var shortVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
