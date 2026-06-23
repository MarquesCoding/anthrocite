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
        // Monospaced digits so the ticking timer doesn't resize the item.
        if let f = statusItem.button?.font {
            statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: f.pointSize, weight: .regular)
        }
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

    @objc private func openDashboard() { showDashboard(.overview) }

    private func showDashboard(_ pane: DashboardPane) {
        Navigation.shared.pane = pane
        // Become a regular app and activate BEFORE opening, so the window
        // materialises immediately and comes to the front.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("dashboard") == true || $0.title.contains("Dashboard") }) {
            existing.makeKeyAndOrderFront(nil)
        } else {
            WindowBridge.shared.open("dashboard")
        }
    }
    @objc private func toggleStatus() { UserDefaults.standard.set(!showStatus, forKey: Prefs.showStatusKey) }
    @objc private func toggleTimer() { UserDefaults.standard.set(!showTimer, forKey: Prefs.showTimerKey) }
    @objc private func refreshNow() { Task { await stores.usage.refresh() } }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Status-bar button

    /// The menu-bar logo, sized to 16pt and rendered as a template (auto-tinted).
    private static let menuBarImage: NSImage? = {
        guard let base = NSImage(named: "MenuBarLogo"), let img = base.copy() as? NSImage else { return nil }
        let h: CGFloat = 13.5
        img.size = NSSize(width: img.size.height > 0 ? h * (img.size.width / img.size.height) : h, height: h)
        img.isTemplate = true
        return img
    }()

    private var lastTitleKey = ""

    private func refreshButton() {
        guard let button = statusItem.button, !menuOpen else { return }
        button.image = Self.menuBarImage

        let title = showStatus ? menuTitle() : nil
        // Key ignores the ticking "Ns" so the timer updates smoothly without a
        // fade every second; we only animate real state changes.
        let key = title.map { $0.replacingOccurrences(of: #"\s+\d+s$"#, with: "", options: .regularExpression) } ?? "<idle>"
        let animate = key != lastTitleKey && !lastTitleKey.isEmpty
        lastTitleKey = key

        let apply = {
            button.title = title.map { " " + $0 } ?? ""
            button.imagePosition = title == nil ? .imageOnly : .imageLeading
        }

        guard animate else { apply(); return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.16
            button.animator().alphaValue = 0
        }, completionHandler: {
            apply()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.16
                button.animator().alphaValue = 1
            }
        })
    }

    private func menuTitle() -> String? {
        let working = stores.status.workingSessions
        switch working.count {
        case 0: return nil
        case 1:
            let s = working[0]
            if showTimer, let since = s.activeSince {
                let secs = max(0, Int(Date().timeIntervalSince(since)))
                return "\(s.statusText) \(String(format: "%2d", secs))s"
            }
            return s.statusText
        default: return "\(working.count) working"
        }
    }
}
