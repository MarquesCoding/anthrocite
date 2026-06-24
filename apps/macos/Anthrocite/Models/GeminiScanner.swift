import Foundation

/// Parses Gemini CLI session logs into the same usage index as the other
/// providers. Gemini stores sessions under `~/.gemini/tmp/<hash>/chats/` as
/// JSONL streams: a `session_metadata` record (project/model), then message and
/// `message_update` records carrying token counts.
///
/// NOTE: best-effort. The Gemini CLI log format is young and still changing, so
/// this tolerates several field spellings (a flat `tokens` object and the raw
/// Gemini `usageMetadata`). It is intentionally defensive.
enum GeminiScanner {
    static let root: URL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".gemini/tmp", directoryHint: .isDirectory)

    /// True once Gemini CLI has written any session data.
    static var isDetected: Bool {
        FileManager.default.fileExists(atPath: FileManager.default
            .homeDirectoryForCurrentUser.appending(path: ".gemini").path)
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func scan(into index: AggregateIndex) -> AggregateIndex {
        var index = index
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey],
                                         options: [.skipsHiddenFiles]) else { return index }
        for case let url as URL in walker where url.pathExtension == "jsonl" && url.path.contains("/chats/") {
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
        index.prune()
        return index
    }

    private static func parse(_ data: Data, path: String, into index: inout AggregateIndex) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // session_metadata carries the model and project for the whole file.
        if (obj["type"] as? String) == "session_metadata" {
            if let model = (obj["model"] as? String) ?? (obj["modelName"] as? String), !model.isEmpty {
                index.geminiModel[path] = model
            }
            let cwd = (obj["cwd"] as? String) ?? (obj["projectRoot"] as? String) ?? (obj["projectHash"] as? String)
            if let cwd, !cwd.isEmpty {
                index.geminiProject[path] = cwd.contains("/") ? URL(filePath: cwd).lastPathComponent : cwd
            }
            return
        }

        // Any record may carry usage — either a flat `tokens` object or the raw
        // Gemini `usageMetadata`.
        guard let counts = tokenCounts(obj["tokens"]) ?? tokenCounts(obj["usageMetadata"]),
              counts.total > 0 else { return }

        if let model = obj["model"] as? String, !model.isEmpty { index.geminiModel[path] = model }
        let model = index.geminiModel[path] ?? "gemini-2.5-pro"
        let project = index.geminiProject[path] ?? "gemini"
        let ts = (obj["timestamp"] as? String).flatMap { iso.date(from: $0) } ?? Date()
        // One session per file (the metadata sessionId isn't on every record).
        index.record(counts: counts, timestamp: ts, sessionID: path,
                     model: model, project: project, origin: .gemini)
    }

    /// Pulls a `TokenCounts` out of either spelling. Gemini's input often
    /// includes cached tokens, so we subtract them into the cache-read bucket.
    private static func tokenCounts(_ any: Any?) -> TokenCounts? {
        guard let d = any as? [String: Any] else { return nil }
        let input = intVal(d["input"]) + intVal(d["promptTokenCount"])
        let output = intVal(d["output"]) + intVal(d["candidatesTokenCount"])
        let thoughts = intVal(d["thoughts"]) + intVal(d["thought"]) + intVal(d["thoughtsTokenCount"])
        let cached = intVal(d["cached"]) + intVal(d["cachedContentTokenCount"])
        let counts = TokenCounts(
            input: max(0, input - cached),
            output: output + thoughts,
            cacheWrite: 0,
            cacheRead: cached)
        return counts.total > 0 ? counts : nil
    }

    private static func intVal(_ any: Any?) -> Int {
        if let n = any as? NSNumber { return n.intValue }
        return 0
    }
}
