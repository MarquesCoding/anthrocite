import Foundation

/// Lightweight projections derived from the usage index and live limits.
enum Insights {
    static let fiveHourLength: TimeInterval = 5 * 3_600
    static let weeklyLength: TimeInterval = 7 * 86_400

    /// Seconds until a rate-limit window is projected to hit 100%, assuming the
    /// current pace holds. nil if it's too early to tell or it won't be reached
    /// before the window resets.
    static func timeToLimit(used: Double, resetsAt: Date, windowLength: TimeInterval,
                            now: Date = Date()) -> TimeInterval? {
        guard used > 0, used < 100 else { return nil }
        let remaining = resetsAt.timeIntervalSince(now)
        let elapsed = windowLength - remaining
        guard elapsed > 300 else { return nil }            // first 5 min is noisy
        let ratePerSec = used / elapsed
        guard ratePerSec > 0 else { return nil }
        let toLimit = (100 - used) / ratePerSec
        return toLimit < remaining ? toLimit : nil          // nil = safe this window
    }

    /// Average daily cost over the last `days` days (for spend projection).
    static func avgDailyCost(_ index: AggregateIndex, _ table: PricingTable,
                             days: Int, now: Date = Date()) -> Double {
        let series = index.dailySeries(days: days, now: now)
        guard !series.isEmpty else { return 0 }
        let total = series.reduce(0.0) { $0 + $1.breakdown.totalCost(table) }
        return total / Double(series.count)
    }
}
