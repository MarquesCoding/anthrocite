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

    /// day key -> project -> breakdown, so the Projects table can be filtered by
    /// time range. Pruned to a few months (the all-time view uses `byProject`).
    var byDayProject: [String: [String: ModelBreakdown]] = [:]

    /// Codex rollout files keep cwd/model in records separate from the token
    /// counts, so we remember them per file while scanning incrementally.
    var codexProject: [String: String] = [:]
    var codexModel: [String: String] = [:]

    /// Same idea for Gemini CLI session files (project/model live in the
    /// session_metadata record, token counts in later records).
    var geminiProject: [String: String] = [:]
    var geminiModel: [String: String] = [:]

    /// sessionId -> per-session info. Pruned to recent sessions.
    var sessions: [String: SessionInfo] = [:]

    struct SessionInfo: Codable, Sendable, Identifiable {
        var id = ""
        var project = ""
        var breakdown = ModelBreakdown()
        var firstTimestamp: Date = .distantFuture
        var lastTimestamp: Date = .distantPast
        var lastModel: String = ""

        var duration: TimeInterval { max(0, lastTimestamp.timeIntervalSince(firstTimestamp)) }
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

    mutating func record(counts: TokenCounts, timestamp: Date, sessionID: String,
                         model: String, project: String, origin: Provider) {
        // Encode the origin into the breakdown key so usage stays separable per
        // agent even when the same model is shared (e.g. Claude in CLI + Xcode).
        let key = ModelKey.make(origin, model)
        let day = AggregateIndex.dayKey(for: timestamp)
        total.add(counts, model: key)
        byDay[day, default: ModelBreakdown()].add(counts, model: key)
        byProject[project, default: ModelBreakdown()].add(counts, model: key)
        byDayProject[day, default: [:]][project, default: ModelBreakdown()].add(counts, model: key)
        var s = sessions[sessionID] ?? SessionInfo()
        s.id = sessionID
        if !project.isEmpty { s.project = project }
        s.breakdown.add(counts, model: key)
        if timestamp < s.firstTimestamp { s.firstTimestamp = timestamp }
        if timestamp >= s.lastTimestamp {
            s.lastTimestamp = timestamp
            s.lastModel = model
        }
        sessions[sessionID] = s
    }

    /// Keep ~13 months of daily totals for charts, ~3 months of per-project
    /// daily data (for the range filter), and ~30 days of session history.
    mutating func prune(now: Date = Date()) {
        func keys(_ days: Int) -> Set<String> {
            Set((0...days).map { AggregateIndex.dayKey(for: now.addingTimeInterval(Double(-$0) * 86_400)) })
        }
        byDay = byDay.filter { keys(400).contains($0.key) }
        let dpKeep = keys(95)
        byDayProject = byDayProject.filter { dpKeep.contains($0.key) }
        let cutoff = now.addingTimeInterval(-30 * 86_400)
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

    /// Day keys covering the last `days` days (nil = all time).
    private func rangeKeys(_ days: Int?, now: Date) -> Set<String>? {
        guard let days else { return nil }
        return Set((0..<days).map { AggregateIndex.dayKey(for: now.addingTimeInterval(Double(-$0) * 86_400)) })
    }

    /// Combined breakdown over a time range (nil days = all time).
    func breakdown(lastDays days: Int?, now: Date = Date()) -> ModelBreakdown {
        guard let keys = rangeKeys(days, now: now) else { return total }
        return ModelBreakdown.sum(byDay.filter { keys.contains($0.key) }.map(\.value))
    }

    /// Per-project breakdowns over a time range (nil days = all time).
    func projects(lastDays days: Int?, now: Date = Date()) -> [String: ModelBreakdown] {
        guard let keys = rangeKeys(days, now: now) else { return byProject }
        var out: [String: ModelBreakdown] = [:]
        for (day, projects) in byDayProject where keys.contains(day) {
            for (project, bd) in projects { out[project, default: ModelBreakdown()].merge(bd) }
        }
        return out
    }

    /// Past sessions, most recent first, for the history browser.
    func recentSessions() -> [SessionInfo] {
        sessions.values
            .filter { $0.breakdown.totalTokens > 0 }
            .sorted { $0.lastTimestamp > $1.lastTimestamp }
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
