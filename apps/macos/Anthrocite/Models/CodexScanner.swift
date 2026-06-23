import Foundation

/// Parses OpenAI Codex rollout logs (`~/.codex/sessions/**/*.jsonl`) into the
/// same usage index as Claude Code, so the dashboard shows both providers.
///
/// Codex records token usage in `event_msg` payloads of type `token_count`
/// (`info.last_token_usage`); the model comes from `turn_context` and the
/// project (cwd) from the leading `session_meta` record.
enum CodexScanner {
    static let sessionDirs: [URL] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appending(path: ".codex/sessions", directoryHint: .isDirectory),
            home.appending(path: ".codex/archived_sessions", directoryHint: .isDirectory),
        ]
    }()

    /// True when a Codex session directory exists — Codex logs usage natively,
    /// so no hook install is needed; we just read its rollouts.
    static var isDetected: Bool {
        sessionDirs.contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func scan(into index: AggregateIndex) -> AggregateIndex {
        var index = index
        let fm = FileManager.default
        for dir in sessionDirs {
            guard let walker = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey],
                                             options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in walker where url.pathExtension == "jsonl" {
                let path = url.path
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                var offset = index.fileOffsets[path] ?? 0
                if offset > size { offset = 0 }
                if offset == size { continue }

                guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
                defer { try? handle.close() }
                do { try handle.seek(toOffset: UInt64(offset)) } catch { continue }
                guard let chunk = try? handle.readToEnd(), !chunk.isEmpty,
                      let lastNL = chunk.lastIndex(of: 0x0A) else { continue }
                let consumed = chunk[...lastNL]
                for line in consumed.split(separator: 0x0A, omittingEmptySubsequences: true) {
                    parse(Data(line), path: path, into: &index)
                }
                index.fileOffsets[path] = offset + consumed.count
            }
        }
        index.prune()
        return index
    }

    private static func parse(_ data: Data, path: String, into index: inout AggregateIndex) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let payload = obj["payload"] as? [String: Any]
        switch obj["type"] as? String {
        case "session_meta":
            if let cwd = payload?["cwd"] as? String {
                index.codexProject[path] = URL(filePath: cwd).lastPathComponent
            }
        case "turn_context":
            if let m = payload?["model"] as? String, !m.isEmpty {
                index.codexModel[path] = normalize(m)
            }
        case "event_msg":
            guard (payload?["type"] as? String) == "token_count",
                  let info = payload?["info"] as? [String: Any],
                  let u = info["last_token_usage"] as? [String: Any] else { return }
            let cachedIn = intVal(u["cached_input_tokens"])
            let counts = TokenCounts(
                input: max(0, intVal(u["input_tokens"]) - cachedIn),
                output: intVal(u["output_tokens"]) + intVal(u["reasoning_output_tokens"]),
                cacheWrite: 0,
                cacheRead: cachedIn)
            guard counts.total > 0 else { return }
            let model = index.codexModel[path] ?? "gpt-5-codex"
            let project = index.codexProject[path] ?? "unknown"
            let ts = (obj["timestamp"] as? String).flatMap { iso.date(from: $0) } ?? Date()
            index.record(counts: counts, timestamp: ts, sessionID: path,
                         model: model, project: project, origin: .codex)
        default:
            break
        }
    }

    /// Map Codex subagent/profile names (e.g. "codex-auto-review", "guardian")
    /// to a real OpenAI model for pricing; keep genuine model ids as-is.
    private static func normalize(_ model: String) -> String {
        let m = model.lowercased()
        if m.hasPrefix("gpt") || m.hasPrefix("o1") || m.hasPrefix("o3") || m.hasPrefix("o4") {
            return model
        }
        return "gpt-5-codex"
    }

    private static func intVal(_ any: Any?) -> Int {
        if let n = any as? NSNumber { return n.intValue }
        return 0
    }
}
