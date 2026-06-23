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
    }
}
