import SwiftUI

/// Shared app state, so both the MenuBarExtra and the Window/Settings scenes
/// reference the same running stores (started once at launch).
@MainActor
final class Stores {
    static let shared = Stores()

    let usage = UsageStore()
    let status = StatusStore()
    let pricing = PricingStore()

    private var started = false
    private var widgetTimer: Timer?
    private var discordTimer: Timer?
    func start() {
        guard !started else { return }
        started = true
        usage.start()
        status.start()
        pricing.start()
        // Keep the desktop widgets fed with a fresh snapshot.
        WidgetBridge.update(usage: usage, status: status, pricing: pricing)
        widgetTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                WidgetBridge.update(usage: self.usage, status: self.status, pricing: self.pricing)
            }
        }
        // Discord Rich Presence (off unless enabled in Settings).
        refreshDiscord()
        discordTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshDiscord() }
        }
    }

    private func refreshDiscord() {
        let enabled = UserDefaults.standard.bool(forKey: Prefs.discordKey)
        let appID = UserDefaults.standard.string(forKey: Prefs.discordAppIDKey) ?? ""
        DiscordPresence.shared.configure(enabled: enabled, appID: appID)
        DiscordPresence.shared.set(enabled && !appID.isEmpty ? discordActivity() : nil)
    }

    /// Maps the most-recent live session to a Discord activity (nil = clear).
    private func discordActivity() -> DiscordPresence.Activity? {
        guard let s = status.workingSessions.first ?? status.primary else { return nil }
        let tokens = s.context?.usedTokens ?? 0
        let parts = [s.isWorking ? s.statusText : "idle",
                     tokens > 0 ? "\(Fmt.tokens(tokens)) tokens" : nil].compactMap { $0 }
        return DiscordPresence.Activity(
            details: "Working in \(s.project)",
            state: parts.joined(separator: " · "),
            largeImage: s.isCodex ? "codex" : "claude",
            largeText: s.model ?? (s.isCodex ? "Codex" : "Claude"),
            smallImage: nil,
            start: s.isWorking ? s.activeSince.map { Int($0.timeIntervalSince1970) } : nil)
    }
}
