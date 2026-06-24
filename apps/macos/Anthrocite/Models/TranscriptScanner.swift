import Foundation

/// Pure, off-main scanner. Walks `~/.claude/projects/**/*.jsonl`, parsing only
/// the bytes appended since the offsets recorded in the supplied index.
enum TranscriptScanner {
    static let projectsDir: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appending(path: ".claude/projects", directoryHint: .isDirectory)

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ s: String) -> Date? {
        isoFractional.date(from: s) ?? isoPlain.date(from: s)
    }

    /// Returns an updated copy of `index` after folding in all new transcript
    /// data from both Claude Code (the CLI) and Xcode's coding intelligence.
    static func scan(into index: AggregateIndex) -> AggregateIndex {
        var index = scan(dir: projectsDir, origin: .claude, into: index)
        index.prune()
        return index
    }

    private static func scan(dir: URL, origin: Provider, into index: AggregateIndex) -> AggregateIndex {
        var index = index
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: dir,
                                         includingPropertiesForKeys: [.fileSizeKey],
                                         options: [.skipsHiddenFiles]) else {
            return index
        }
        for case let url as URL in walker where url.pathExtension == "jsonl" {
            let path = url.path
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            var offset = index.fileOffsets[path] ?? 0
            if offset > size { offset = 0 }            // truncated/rotated → re-read
            if offset == size { continue }             // nothing new

            guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
            defer { try? handle.close() }
            do { try handle.seek(toOffset: UInt64(offset)) } catch { continue }
            guard let chunk = try? handle.readToEnd(), !chunk.isEmpty else { continue }

            // Only consume through the last newline; keep any partial trailing line
            // for the next pass so we never parse a half-written record.
            guard let lastNL = chunk.lastIndex(of: 0x0A) else { continue }
            let consumed = chunk[...lastNL]
            for lineData in consumed.split(separator: 0x0A, omittingEmptySubsequences: true) {
                parseLine(Data(lineData), origin: origin, into: &index)
            }
            index.fileOffsets[path] = offset + consumed.count
        }
        return index
    }

    private static func parseLine(_ data: Data, origin: Provider, into index: inout AggregateIndex) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (obj["type"] as? String) == "assistant",
              let message = obj["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else { return }

        let counts = TokenCounts(
            input: intVal(usage["input_tokens"]),
            output: intVal(usage["output_tokens"]),
            cacheWrite: intVal(usage["cache_creation_input_tokens"]),
            cacheRead: intVal(usage["cache_read_input_tokens"]))
        guard counts.total > 0 else { return }

        let model = (message["model"] as? String) ?? "unknown"
        let sessionID = (obj["sessionId"] as? String) ?? "unknown"
        let ts = (obj["timestamp"] as? String).flatMap(parseDate) ?? Date()
        let project = (obj["cwd"] as? String).map { URL(filePath: $0).lastPathComponent } ?? "unknown"

        index.record(counts: counts, timestamp: ts, sessionID: sessionID,
                     model: model, project: project, origin: origin)
    }

    private static func intVal(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let n = any as? NSNumber { return n.intValue }
        return 0
    }
}
