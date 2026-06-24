import Foundation
import UserNotifications

/// Posts Notification Center alerts when a rate-limit or daily spend crosses a
/// user-set threshold. Off by default; fires at most once per window/day.
@MainActor
final class AlertMonitor {
    static let shared = AlertMonitor()

    private var requestedAuth = false
    private var firedLimit: [String: Date] = [:]   // id -> the resetsAt it fired for
    private var firedSpendDay = ""

    func check(status: StatusStore, usage: UsageStore, pricing: PricingStore) {
        guard UserDefaults.standard.bool(forKey: Prefs.alertsKey) else { return }
        ensureAuth()

        let limitT = Double(UserDefaults.standard.object(forKey: Prefs.limitThresholdKey) as? Int ?? 80)
        checkLimit("5h", "5-hour limit", status.fiveHour, threshold: limitT)
        checkLimit("7d", "Weekly limit", status.sevenDay, threshold: limitT)

        let spendT = UserDefaults.standard.double(forKey: Prefs.spendThresholdKey)
        if spendT > 0 {
            let today = usage.index.todayBreakdown.totalCost(pricing.table)
            let day = AggregateIndex.dayKey(for: Date())
            if today >= spendT, firedSpendDay != day {
                firedSpendDay = day
                notify("Daily spend reached", "You've spent \(Fmt.usd(today)) today.")
            }
        }
    }

    private func checkLimit(_ id: String, _ name: String, _ window: LimitWindow?, threshold: Double) {
        guard let w = window else { return }
        if let firedFor = firedLimit[id], firedFor != w.resetsAt { firedLimit[id] = nil }  // new window
        if w.usedPercentage >= threshold, firedLimit[id] == nil {
            firedLimit[id] = w.resetsAt
            notify("\(name) at \(Int(w.usedPercentage.rounded()))%",
                   "Resets \(Fmt.resetClock(w.resetsAt)).")
        }
    }

    private func ensureAuth() {
        guard !requestedAuth else { return }
        requestedAuth = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
