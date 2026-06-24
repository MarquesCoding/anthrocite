import Foundation
import Combine

/// Owns the aggregate index: loads the on-disk cache, runs incremental scans on
/// a background task, and publishes the latest snapshot to the UI.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var index = AggregateIndex()
    @Published private(set) var isIndexing = false
    @Published private(set) var lastUpdated: Date?

    private var timer: Timer?
    private var scanning = false
    private var lastCacheSave = Date.distantPast

    private static let cacheURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Anthrocite", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "index.json")
    }()

    func start() {
        loadCache()
        Task { await refresh() }
        // Totals don't need sub-10s freshness; scanning the transcript corpus
        // more often than this is the main idle-CPU cost.
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        guard !scanning else { return }
        scanning = true
        if index.fileOffsets.isEmpty { isIndexing = true }
        let current = index
        let updated = await Task.detached(priority: .utility) {
            GeminiScanner.scan(into: CodexScanner.scan(into: TranscriptScanner.scan(into: current)))
        }.value
        index = updated
        lastUpdated = Date()
        isIndexing = false
        scanning = false
        saveCache()
    }

    // MARK: Cache

    private func loadCache() {
        guard let data = try? Data(contentsOf: Self.cacheURL),
              let decoded = try? JSONDecoder().decode(AggregateIndex.self, from: data) else { return }
        index = decoded
    }

    private func saveCache() {
        // Throttle disk writes: the UI refreshes every 2s, but persisting the
        // ~125KB index that often would needlessly hammer the SSD.
        guard Date().timeIntervalSince(lastCacheSave) > 20 else { return }
        lastCacheSave = Date()
        let snapshot = index
        Task.detached(priority: .background) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: Self.cacheURL, options: .atomic)
        }
    }
}
