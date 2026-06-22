import Foundation

/// The persisted, incrementally-updated index over all of Claude Code's JSONL
/// transcripts. We keep per-file byte offsets so each refresh only parses the
/// bytes appended since last time — important because the transcript corpus is
/// hundreds of MB.
struct AggregateIndex: Codable, Sendable {
    /// path -> number of bytes already consumed (always on a line boundary).
    var fileOffsets: [String: Int] = [:]

    /// All-time totals, keyed by exact model id.
    var total = ModelBreakdown()

    /// Local-day key ("yyyy-MM-dd") -> that day's breakdown. Pruned to a small
    /// rolling window since all we surface is "today".
    var byDay: [String: ModelBreakdown] = [:]

    /// sessionId -> per-session info. Pruned to recent sessions.
    var sessions: [String: SessionInfo] = [:]

    struct SessionInfo: Codable, Sendable {
        var breakdown = ModelBreakdown()
        var lastTimestamp: Date = .distantPast
        var lastModel: String = ""
    }

    // MARK: Derived views

    var todayBreakdown: ModelBreakdown {
        byDay[AggregateIndex.dayKey(for: Date())] ?? ModelBreakdown()
    }

    /// The session with the most recent activity.
    var currentSession: SessionInfo? {
        sessions.values.max { $0.lastTimestamp < $1.lastTimestamp }
    }

    // MARK: Mutation

    mutating func record(counts: TokenCounts,
                         timestamp: Date, sessionID: String, model: String) {
        total.add(counts, model: model)
        byDay[AggregateIndex.dayKey(for: timestamp), default: ModelBreakdown()]
            .add(counts, model: model)
        var s = sessions[sessionID] ?? SessionInfo()
        s.breakdown.add(counts, model: model)
        if timestamp >= s.lastTimestamp {
            s.lastTimestamp = timestamp
            s.lastModel = model
        }
        sessions[sessionID] = s
    }

    /// Drop day buckets and sessions older than a couple of days so the cache
    /// stays small. `total` already retains the all-time numbers.
    mutating func prune(now: Date = Date()) {
        let keepDays = Set((0...2).map {
            AggregateIndex.dayKey(for: now.addingTimeInterval(Double(-$0) * 86_400))
        })
        byDay = byDay.filter { keepDays.contains($0.key) }
        let cutoff = now.addingTimeInterval(-2 * 86_400)
        sessions = sessions.filter { $0.value.lastTimestamp >= cutoff }
    }

    // MARK: Helpers

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"   // local time zone on purpose
        return f
    }()

    static func dayKey(for date: Date) -> String { dayFormatter.string(from: date) }
}
