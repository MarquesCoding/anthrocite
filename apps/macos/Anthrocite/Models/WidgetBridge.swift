import Foundation
import WidgetKit

/// Publishes a snapshot of the current usage/status/limits into the shared App
/// Group so the desktop widgets can render it. Writes are cheap and frequent;
/// widget timeline reloads are throttled to respect the system budget.
@MainActor
enum WidgetBridge {
    private static var lastReload = Date.distantPast

    static func update(usage: UsageStore, status: StatusStore, pricing: PricingStore) {
        guard let url = WidgetShared.snapshotURL else { return }

        let today = usage.index.todayBreakdown
        let total = usage.index.total
        let snap = WidgetSnapshot(
            updatedAt: Date(),
            todayCost: today.totalCost(pricing.table),
            todayTokens: today.totalTokens,
            totalCost: total.totalCost(pricing.table),
            totalTokens: total.totalTokens,
            fiveHour: status.fiveHour.map { WidgetLimit(usedPercentage: $0.usedPercentage, resetsAt: $0.resetsAt) },
            sevenDay: status.sevenDay.map { WidgetLimit(usedPercentage: $0.usedPercentage, resetsAt: $0.resetsAt) },
            workingCount: status.workingCount,
            activeCount: status.activeCount,
            sessions: status.sessions.prefix(6).map {
                WidgetSession(id: $0.id, name: $0.project,
                              status: $0.isWorking ? $0.statusText : "idle",
                              isWorking: $0.isWorking,
                              contextPercentage: $0.context?.usedPercentage)
            })

        guard let data = try? WidgetShared.encoder.encode(snap) else { return }
        try? data.write(to: url, options: .atomic)

        if Date().timeIntervalSince(lastReload) > 30 {
            lastReload = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
