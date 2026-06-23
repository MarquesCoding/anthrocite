import SwiftUI
import AppKit

/// Owns the native NSStatusItem + NSMenu (works with no window open). Opens the
/// SwiftUI Window/Settings scenes via WindowBridge.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var stores: Stores { Stores.shared }
    private var statusItem: NSStatusItem!
    private var tick: Timer?
    private var animTimer: Timer?
    private var frameIndex = 0
    private var menuOpen = false

    private var iconChoice: IconChoice {
        IconChoice(rawValue: UserDefaults.standard.string(forKey: Prefs.iconKey) ?? "") ?? .logo
    }
    private var accent: AccentChoice {
        AccentChoice(rawValue: UserDefaults.standard.string(forKey: Prefs.accentKey) ?? "") ?? .system
    }

    private var showStatus: Bool {
        UserDefaults.standard.object(forKey: Prefs.showStatusKey) == nil ? true
            : UserDefaults.standard.bool(forKey: Prefs.showStatusKey)
    }
    private var showTimer: Bool {
        UserDefaults.standard.object(forKey: Prefs.showTimerKey) == nil ? true
            : UserDefaults.standard.bool(forKey: Prefs.showTimerKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        HookInstaller.installIfNeeded()
        stores.start()
        Updater.shared.checkOnLaunch()
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
        updateIcon()

        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshButton()
        }
        // A faster timer drives the icon animation (and applies a freshly-chosen
        // icon/colour within a frame). It rests cheaply when nothing's working.
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self] _ in
            self?.updateIcon()
        }
    }

    /// Closing a window must never quit the app — the menu bar lives on.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Only the menu bar's "Quit" actually quits. The dock's right-click → Quit
    /// (and ⌘Q) instead just close any open window and stay a menu-bar agent.
    private var userRequestedQuit = false
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if userRequestedQuit { return .terminateNow }
        for window in NSApp.windows where window.styleMask.contains(.titled) {
            window.close()
        }
        NSApp.setActivationPolicy(.accessory)
        return .terminateCancel
    }

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
    @objc private func quit() { userRequestedQuit = true; NSApp.terminate(nil) }
    /// Lets the updater terminate the app for an in-place swap (bypasses the
    /// "closing a window shouldn't quit" guard).
    func forceQuit() { userRequestedQuit = true }

    // MARK: Status-bar button

    private static let logoBase = NSImage(named: "MenuBarLogo")

    private var wasAnimating = false

    /// Cycles animation frames while any session is working; when idle it always
    /// settles back on the Anthrocite logo (fading in on the work→idle hand-off),
    /// whatever animated style is selected. Runs ~11×/sec off `animTimer`.
    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let choice = iconChoice
        let frames = IconArt.frames(for: choice)
        let animating = choice.isAnimated && !frames.isEmpty && !stores.status.workingSessions.isEmpty

        if animating {
            frameIndex = (frameIndex + 1) % frames.count
            button.image = IconArt.style(frames[frameIndex], color: choice.isColor, accent: accent)
            wasAnimating = true
        } else {
            frameIndex = 0
            if wasAnimating {
                fadeButtonImage(button, to: restingImage)   // animation just finished
            } else {
                button.image = restingImage
            }
            wasAnimating = false
        }
    }

    /// The idle icon is always Anthrocite's own mark, regardless of style.
    private var restingImage: NSImage? { IconArt.style(Self.logoBase, color: false, accent: accent) }

    private func fadeButtonImage(_ button: NSStatusBarButton, to image: NSImage?) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            button.animator().alphaValue = 0
        }, completionHandler: {
            button.image = image
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                button.animator().alphaValue = 1
            }
        })
    }

    private var lastTitleKey = ""

    private func refreshButton() {
        guard let button = statusItem.button, !menuOpen else { return }

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
