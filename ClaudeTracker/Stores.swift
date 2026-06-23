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
    func start() {
        guard !started else { return }
        started = true
        usage.start()
        status.start()
        pricing.start()
    }
}
