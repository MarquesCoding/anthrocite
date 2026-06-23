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

    /// Local-day key ("yyyy-MM-dd") -> that day's breakdown. Retained long-term
    /// for the dashboard's trend charts.
    var byDay: [String: ModelBreakdown] = [:]

    /// Project name (cwd leaf) -> all-time breakdown, for the Projects table.
    var byProject: [String: ModelBreakdown] = [:]

    /// Codex rollout files keep cwd/model in records separate from the token
    /// counts, so we remember them per file while scanning incrementally.
    var codexProject: [String: String] = [:]
    var codexModel: [String: String] = [:]

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

    mutating func record(counts: TokenCounts, timestamp: Date,
                         sessionID: String, model: String, project: String) {
        total.add(counts, model: model)
        byDay[AggregateIndex.dayKey(for: timestamp), default: ModelBreakdown()]
            .add(counts, model: model)
        byProject[project, default: ModelBreakdown()].add(counts, model: model)
        var s = sessions[sessionID] ?? SessionInfo()
        s.breakdown.add(counts, model: model)
        if timestamp >= s.lastTimestamp {
            s.lastTimestamp = timestamp
            s.lastModel = model
        }
        sessions[sessionID] = s
    }

    /// Keep ~13 months of daily history for charts; prune only stale sessions.
    mutating func prune(now: Date = Date()) {
        let keepDays = Set((0...400).map {
            AggregateIndex.dayKey(for: now.addingTimeInterval(Double(-$0) * 86_400))
        })
        byDay = byDay.filter { keepDays.contains($0.key) }
        let cutoff = now.addingTimeInterval(-2 * 86_400)
        sessions = sessions.filter { $0.value.lastTimestamp >= cutoff }
    }

    // MARK: Dashboard views

    /// Daily token totals, oldest → newest, for the last `days` days.
    func dailySeries(days: Int, now: Date = Date()) -> [(date: Date, breakdown: ModelBreakdown)] {
        (0..<days).reversed().compactMap { offset in
            let date = now.addingTimeInterval(Double(-offset) * 86_400)
            let key = AggregateIndex.dayKey(for: date)
            guard let b = byDay[key] else { return (date, ModelBreakdown()) }
            return (date, b)
        }
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
