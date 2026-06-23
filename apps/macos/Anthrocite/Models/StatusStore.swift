import Foundation
import Combine

/// One rate-limit window (5-hour or weekly) as reported by Claude Code.
struct LimitWindow: Sendable, Equatable {
    var usedPercentage: Double
    var resetsAt: Date
}

/// The live context-window usage of a session.
struct ContextUsage: Sendable, Equatable {
    var usedTokens: Int        // total_input_tokens (what's occupying the window)
    var windowSize: Int        // context_window_size
    var usedPercentage: Double
}

enum ActivityPhase: Sendable { case idle, working }

/// One live Claude Code session, parsed from its per-session status file.
struct LiveSession: Identifiable, Sendable {
    let id: String
    var project: String
    var model: String?
    var context: ContextUsage?
    var costUSD: Double?
    var phase: ActivityPhase
    var statusText: String
    var activeSince: Date?
    var lastSeen: Date

    var isWorking: Bool { phase == .working }
    /// Codex live sessions are keyed "codex:<id>"; everything else is Claude.
    var isCodex: Bool { id.hasPrefix("codex:") }
}

/// Watches `~/.claude/claudetracker-status/` (one file per session, written by
/// the statusLine bridge) and exposes every live session plus the account-wide
/// rate limits.
@MainActor
final class StatusStore: ObservableObject {
    @Published private(set) var sessions: [LiveSession] = []
    @Published private(set) var fiveHour: LimitWindow?
    @Published private(set) var sevenDay: LimitWindow?

    /// Per-session "became active" timestamps, kept across reloads for the timer.
    private var activeSince: [String: Date] = [:]
    private var timer: Timer?

    /// A session is "active" (shown) only if its file was written recently.
    private static let activeWindow: TimeInterval = 120
    /// Stale files older than this are deleted on sight.
    private static let pruneAge: TimeInterval = 86_400

    static let statusDir: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appending(path: ".claude/anthrocite-status", directoryHint: .isDirectory)

    // MARK: Derived

    var workingSessions: [LiveSession] { sessions.filter(\.isWorking) }
    var activeCount: Int { sessions.count }
    var workingCount: Int { workingSessions.count }
    /// The most-recently-active session (for single-session views).
    var primary: LiveSession? { sessions.first }

    func start() {
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.reload()
        }
    }

    func reload() {
        let now = Date()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: Self.statusDir, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]) else {
            sessions = []
            return
        }

        var live: [LiveSession] = []
        var newestLimitsAt = Date.distantPast
        var seenIDs = Set<String>()

        for url in files where url.pathExtension == "json" {
            guard let mtime = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate else { continue }
            if now.timeIntervalSince(mtime) > Self.pruneAge { try? fm.removeItem(at: url); continue }

            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            // Account-wide limits: take them from the most recently written file,
            // even if that session is no longer "active".
            if let rl = obj["rate_limits"] as? [String: Any], mtime > newestLimitsAt {
                newestLimitsAt = mtime
                fiveHour = Self.window(from: rl["five_hour"])
                sevenDay = Self.window(from: rl["seven_day"])
            }

            guard now.timeIntervalSince(mtime) <= Self.activeWindow else { continue }

            let sid = (obj["session_id"] as? String) ?? url.deletingPathExtension().lastPathComponent
            seenIDs.insert(sid)

            let transcript = obj["transcript_path"] as? String
            let action = Self.currentAction(transcriptPath: transcript)
            let phase: ActivityPhase = action != nil ? .working : .idle
            if phase == .working {
                if activeSince[sid] == nil { activeSince[sid] = now }
            } else {
                activeSince[sid] = nil
            }

            live.append(LiveSession(
                id: sid,
                project: Self.projectName(obj),
                model: (obj["model"] as? [String: Any])?["display_name"] as? String,
                context: Self.context(from: obj["context_window"]),
                costUSD: (obj["cost"] as? [String: Any])?["total_cost_usd"] as? Double,
                phase: phase,
                statusText: action ?? "Idle",
                activeSince: activeSince[sid],
                lastSeen: mtime))
        }

        // Codex live sessions (CLI + Desktop), read from ~/.codex/sessions.
        let codex = CodexLive.scan(now: now)
        for var cs in codex.sessions {
            seenIDs.insert(cs.id)
            if cs.phase == .working {
                if activeSince[cs.id] == nil { activeSince[cs.id] = now }
            } else {
                activeSince[cs.id] = nil
            }
            cs.activeSince = activeSince[cs.id]
            live.append(cs)
        }
        // Fall back to Codex's own limits if no Claude limits are present.
        if fiveHour == nil { fiveHour = codex.fiveHour }
        if sevenDay == nil { sevenDay = codex.sevenDay }

        // Drop timers for sessions that disappeared.
        activeSince = activeSince.filter { seenIDs.contains($0.key) }
        sessions = live.sorted { $0.lastSeen > $1.lastSeen }
    }

    // MARK: Parsing helpers

    private static func projectName(_ obj: [String: Any]) -> String {
        let ws = obj["workspace"] as? [String: Any]
        let path = (ws?["project_dir"] as? String)
            ?? (ws?["current_dir"] as? String)
            ?? (obj["cwd"] as? String) ?? "session"
        return URL(filePath: path).lastPathComponent
    }

    private static func context(from any: Any?) -> ContextUsage? {
        guard let cw = any as? [String: Any] else { return nil }
        let used = intVal(cw["total_input_tokens"])
        let size = intVal(cw["context_window_size"])
        guard size > 0 else { return nil }
        let pct = (cw["used_percentage"] as? NSNumber)?.doubleValue
            ?? Double(used) / Double(size) * 100
        return ContextUsage(usedTokens: used, windowSize: size, usedPercentage: pct)
    }

    private static func window(from any: Any?) -> LimitWindow? {
        guard let d = any as? [String: Any],
              let pct = (d["used_percentage"] as? NSNumber)?.doubleValue,
              let resets = (d["resets_at"] as? NSNumber)?.doubleValue else { return nil }
        return LimitWindow(usedPercentage: pct, resetsAt: Date(timeIntervalSince1970: resets))
    }

    private static func intVal(_ any: Any?) -> Int {
        if let n = any as? NSNumber { return n.intValue }
        return 0
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Returns the current action verb for a session, or nil if it's idle.
    /// The last transcript record reveals the state:
    ///  - assistant with `stop_reason == tool_use` → a tool is running now
    ///  - a `user` record → Claude is generating the next turn
    ///  - assistant with any other stop_reason → the turn is finished (idle)
    private static func currentAction(transcriptPath: String?) -> String? {
        guard let path = transcriptPath,
              let handle = try? FileHandle(forReadingFrom: URL(filePath: path)) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let tailLen: UInt64 = 32_768
        try? handle.seek(toOffset: size > tailLen ? size - tailLen : 0)
        guard let data = try? handle.readToEnd() else { return nil }

        let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
        for lineData in lines.reversed() {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(lineData)) as? [String: Any],
                  let type = obj["type"] as? String,
                  type == "assistant" || type == "user" else { continue }

            if let tsStr = obj["timestamp"] as? String, let ts = iso.date(from: tsStr),
               Date().timeIntervalSince(ts) > 600 { return nil }

            if type == "user" { return "Thinking" }

            let message = obj["message"] as? [String: Any]
            let blocks = message?["content"] as? [[String: Any]] ?? []
            let stop = message?["stop_reason"] as? String
            if stop == "tool_use" || blocks.contains(where: { ($0["type"] as? String) == "tool_use" }) {
                let tool = blocks.last { ($0["type"] as? String) == "tool_use" }?["name"] as? String
                return verb(forTool: tool ?? "")
            }
            return nil
        }
        return nil
    }

    private static func verb(forTool tool: String) -> String {
        switch tool {
        case "Bash": return "Running"
        case "Read": return "Reading"
        case "Edit", "Write", "NotebookEdit": return "Editing"
        case "Grep", "Glob", "LS": return "Searching"
        case "WebFetch", "WebSearch": return "Browsing"
        case "Task", "Agent": return "Delegating"
        case "TodoWrite": return "Planning"
        default: return "Working"
        }
    }
}
