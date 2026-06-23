import Foundation

/// Live Codex (CLI + Desktop) sessions for the menu, read from the currently
/// active rollout files in `~/.codex/sessions/YYYY/MM/DD/`. Each active rollout
/// gives us the project (cwd), model, context usage and Codex's own 5h/weekly
/// rate limits.
enum CodexLive {
    static let activeWindow: TimeInterval = 120
    static let workingWindow: TimeInterval = 12

    struct Result {
        var sessions: [LiveSession] = []
        var fiveHour: LimitWindow?
        var sevenDay: LimitWindow?
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func scan(now: Date = Date()) -> Result {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let cal = Calendar(identifier: .gregorian)
        var result = Result()
        var newestLimits = Date.distantPast

        for offset in 0...1 {
            let day = now.addingTimeInterval(Double(-offset) * 86_400)
            let c = cal.dateComponents([.year, .month, .day], from: day)
            let sub = String(format: "%04d/%02d/%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            let dir = home.appending(path: ".codex/sessions/\(sub)", directoryHint: .isDirectory)
            guard let files = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { continue }

            for url in files where url.pathExtension == "jsonl" {
                guard let mtime = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                      now.timeIntervalSince(mtime) <= activeWindow,
                      let parsed = parse(url, mtime: mtime, now: now) else { continue }
                result.sessions.append(parsed.session)
                if let limits = parsed.limits, mtime > newestLimits {
                    newestLimits = mtime
                    result.fiveHour = limits.0
                    result.sevenDay = limits.1
                }
            }
        }
        return result
    }

    private static func parse(_ url: URL, mtime: Date, now: Date)
        -> (session: LiveSession, limits: (LimitWindow?, LimitWindow?)?)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        // Head: session_meta (first record) → project + id.
        var project = "Codex"
        var id = url.deletingPathExtension().lastPathComponent
        if let head = try? handle.read(upToCount: 16_384), let nl = head.firstIndex(of: 0x0A),
           let obj = try? JSONSerialization.jsonObject(with: Data(head[..<nl])) as? [String: Any],
           (obj["type"] as? String) == "session_meta", let p = obj["payload"] as? [String: Any] {
            if let cwd = p["cwd"] as? String { project = URL(filePath: cwd).lastPathComponent }
            if let sid = p["id"] as? String { id = sid }
        }

        // Tail: latest token_count (context + rate limits) and turn_context (model).
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > 32_768 ? size - 32_768 : 0)
        var model: String?
        var context: ContextUsage?
        var limits: (LimitWindow?, LimitWindow?)?
        if let tail = try? handle.readToEnd() {
            for line in tail.split(separator: 0x0A, omittingEmptySubsequences: true) {
                guard let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
                let p = obj["payload"] as? [String: Any]
                switch obj["type"] as? String {
                case "turn_context":
                    if let m = p?["model"] as? String, !m.isEmpty { model = m }
                case "event_msg" where (p?["type"] as? String) == "token_count":
                    if let info = p?["info"] as? [String: Any] {
                        let used = intVal((info["total_token_usage"] as? [String: Any])?["total_tokens"])
                        let window = intVal(info["model_context_window"])
                        if window > 0 {
                            context = ContextUsage(usedTokens: used, windowSize: window,
                                                   usedPercentage: Double(used) / Double(window) * 100)
                        }
                    }
                    if let rl = p?["rate_limits"] as? [String: Any] {
                        limits = (window(rl["primary"]), window(rl["secondary"]))
                    }
                default:
                    break
                }
            }
        }

        let working = now.timeIntervalSince(mtime) <= workingWindow
        let session = LiveSession(
            id: "codex:" + id,
            project: project,
            model: model.map { "Codex · \($0)" } ?? "Codex",
            context: context,
            costUSD: nil,
            phase: working ? .working : .idle,
            statusText: "Working",
            activeSince: nil,
            lastSeen: mtime)
        return (session, limits)
    }

    private static func window(_ any: Any?) -> LimitWindow? {
        guard let d = any as? [String: Any],
              let pct = (d["used_percent"] as? NSNumber)?.doubleValue,
              let resets = (d["resets_at"] as? NSNumber)?.doubleValue else { return nil }
        return LimitWindow(usedPercentage: pct, resetsAt: Date(timeIntervalSince1970: resets))
    }

    private static func intVal(_ any: Any?) -> Int { (any as? NSNumber)?.intValue ?? 0 }
}
