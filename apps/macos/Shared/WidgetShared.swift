import Foundation
import os

/// Shared between the app and the widget extension via an App Group. The app
/// writes a small snapshot on each refresh; the widget reads it to render.
enum WidgetShared {
    // macOS requires the App Group id to be Team-ID-prefixed; the bare
    // "group.app.anthrocite" resolves to nil in the sandboxed widget.
    static let appGroup = "DG952Y4Q43.group.app.anthrocite"
    static let snapshotName = "widget-snapshot.json"

    /// macOS requires the widget extension to be sandboxed, so the only way to
    /// share data is the App Group container (entitlements are injected at the
    /// codesign step with the Developer ID cert). Returns nil in unsigned dev
    /// builds — the widget only runs in the signed build anyway.
    static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(snapshotName)
    }

    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    private static let log = Logger(subsystem: "app.anthrocite", category: "widget")

    static func load() -> WidgetSnapshot {
        guard let url = snapshotURL else {
            log.error("load: snapshotURL is nil (App Group container unavailable)")
            return .placeholder
        }
        guard let data = try? Data(contentsOf: url) else {
            log.error("load: read failed at \(url.path, privacy: .public)")
            return .placeholder
        }
        do {
            return try decoder.decode(WidgetSnapshot.self, from: data)
        } catch {
            log.error("load: decode failed: \(String(describing: error), privacy: .public)")
            return .placeholder
        }
    }
}

struct WidgetLimit: Codable, Hashable {
    var usedPercentage: Double
    var resetsAt: Date
}

struct WidgetSession: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var status: String
    var isWorking: Bool
    var contextPercentage: Double?
}

/// Everything the widgets display, captured at a moment in time.
struct WidgetSnapshot: Codable, Hashable {
    var updatedAt: Date
    var todayCost: Double
    var todayTokens: Int
    var totalCost: Double
    var totalTokens: Int
    var fiveHour: WidgetLimit?
    var sevenDay: WidgetLimit?
    var workingCount: Int
    var activeCount: Int
    var sessions: [WidgetSession]

    static let placeholder = WidgetSnapshot(
        updatedAt: Date(),
        todayCost: 4.20, todayTokens: 1_240_000,
        totalCost: 75.10, totalTokens: 651_700_000,
        fiveHour: WidgetLimit(usedPercentage: 13, resetsAt: Date().addingTimeInterval(7_440)),
        sevenDay: WidgetLimit(usedPercentage: 2, resetsAt: Date().addingTimeInterval(521_000)),
        workingCount: 1, activeCount: 2,
        sessions: [
            WidgetSession(id: "1", name: "anthrocite", status: "Editing", isWorking: true, contextPercentage: 31),
            WidgetSession(id: "2", name: "ChatPod", status: "idle", isWorking: false, contextPercentage: 71),
        ])
}

/// Compact formatting shared by the widget views.
enum WFmt {
    static func tokens(_ n: Int) -> String {
        let v = Double(n)
        switch n {
        case 1_000_000_000...: return String(format: "%.1fB", v / 1_000_000_000)
        case 1_000_000...:     return String(format: "%.1fM", v / 1_000_000)
        case 1_000...:         return String(format: "%.1fK", v / 1_000)
        default:               return "\(n)"
        }
    }
    static func usd(_ amount: Double) -> String {
        if amount > 0 && amount < 0.01 { return "<$0.01" }
        return String(format: "$%.2f", amount)
    }
}
