import SwiftUI
import AppKit

/// Owns the native NSStatusItem + NSMenu (works with no window open). Opens the
/// SwiftUI Window/Settings scenes via WindowBridge.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var stores: Stores { Stores.shared }
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
        stores.start()
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refreshButton()

        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshButton()
        }
    }

    /// Closing a window must never quit the app — the menu bar lives on.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Menu

    func menuWillOpen(_ menu: NSMenu) { menuOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuOpen = false; refreshButton() }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let content = NSMenuItem()
        let host = NSHostingView(rootView: MenuContentView(
            usage: stores.usage, status: stores.status, pricing: stores.pricing))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        content.view = host
        menu.addItem(content)

        menu.addItem(.separator())
        let dash = add("Open Dashboard…", #selector(openDashboard), menu)
        dash.keyEquivalent = "d"
        let settings = add("Settings…", #selector(openSettings), menu)
        settings.keyEquivalent = ","

        menu.addItem(.separator())
        toggle("Show status text", showStatus, #selector(toggleStatus), enabled: true, menu)
        toggle("Show timer", showTimer, #selector(toggleTimer), enabled: showStatus, menu)

        menu.addItem(.separator())
        header("Version \(AppInfo.version)", menu)
        add("Refresh Now", #selector(refreshNow), menu)
        let quit = add("Quit \(AppInfo.name)", #selector(quit), menu)
        quit.keyEquivalent = "q"
    }

    @discardableResult
    private func add(_ title: String, _ action: Selector, _ menu: NSMenu) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self; i.isEnabled = true
        menu.addItem(i)
        return i
    }
    private func header(_ title: String, _ menu: NSMenu) {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        menu.addItem(i)
    }
    private func toggle(_ title: String, _ on: Bool, _ action: Selector, enabled: Bool, _ menu: NSMenu) {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self; i.state = on ? .on : .off; i.isEnabled = enabled
        menu.addItem(i)
    }

    // MARK: Actions

    @objc private func openDashboard() { WindowBridge.shared.open("dashboard") }
    @objc private func openSettings() { WindowBridge.shared.openSettings() }
    @objc private func toggleStatus() { UserDefaults.standard.set(!showStatus, forKey: Prefs.showStatusKey) }
    @objc private func toggleTimer() { UserDefaults.standard.set(!showTimer, forKey: Prefs.showTimerKey) }
    @objc private func refreshNow() { Task { await stores.usage.refresh() } }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Status-bar button

    private func refreshButton() {
        guard let button = statusItem.button, !menuOpen else { return }
        let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent",
                               accessibilityDescription: AppInfo.name)?.withSymbolConfiguration(cfg)

        if let title = showStatus ? menuTitle() : nil {
            button.title = " " + title
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    private func menuTitle() -> String? {
        let working = stores.status.workingSessions
        switch working.count {
        case 0: return nil
        case 1:
            let s = working[0]
            if showTimer, let since = s.activeSince {
                return "\(s.statusText) \(max(0, Int(Date().timeIntervalSince(since))))s"
            }
            return s.statusText
        default: return "\(working.count) working"
        }
    }
}
