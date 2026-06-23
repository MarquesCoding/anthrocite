import Foundation
import Combine

/// Per-token USD prices for one model.
struct ModelPricing: Sendable, Equatable {
    var input: Double
    var output: Double
    var cacheWrite: Double
    var cacheRead: Double
}

/// A lookup of model id → pricing, sourced from LiteLLM's public pricing
/// dataset (the same data ccusage uses) with correct built-in fallbacks.
struct PricingTable: Sendable, Equatable {
    var byModel: [String: ModelPricing] = [:]

    /// Best-effort pricing for a transcript model id (e.g. "claude-opus-4-8").
    func pricing(for modelID: String) -> ModelPricing {
        if let exact = byModel[modelID] { return exact }
        let id = modelID.lowercased()
        // Longest key that is a substring of the id (or vice-versa) wins.
        let match = byModel
            .filter { id.contains($0.key.lowercased()) || $0.key.lowercased().contains(id) }
            .max { $0.key.count < $1.key.count }
        return match?.value ?? PricingTable.fallback(for: ModelFamily.from(modelID: modelID))
    }

    /// Correct current list prices (per million tokens → per token) by family,
    /// used when the remote dataset is unavailable.
    static func fallback(for family: ModelFamily) -> ModelPricing {
        func mtok(_ i: Double, _ o: Double, _ cw: Double, _ cr: Double) -> ModelPricing {
            ModelPricing(input: i/1e6, output: o/1e6, cacheWrite: cw/1e6, cacheRead: cr/1e6)
        }
        switch family {
        case .opus:           return mtok(5, 25, 6.25, 0.50)   // Opus 4.5+
        case .sonnet, .other: return mtok(3, 15, 3.75, 0.30)
        case .haiku:          return mtok(1, 5, 1.25, 0.10)
        }
    }

    static var bundled: PricingTable {
        func mtok(_ i: Double, _ o: Double, _ cr: Double) -> ModelPricing {
            ModelPricing(input: i/1e6, output: o/1e6, cacheWrite: 0, cacheRead: cr/1e6)
        }
        var t = PricingTable()
        t.byModel["claude-opus"] = fallback(for: .opus)
        t.byModel["claude-sonnet"] = fallback(for: .sonnet)
        t.byModel["claude-haiku"] = fallback(for: .haiku)
        // OpenAI / Codex fallbacks (LiteLLM provides exact rates when online).
        t.byModel["gpt-5-codex"] = mtok(1.25, 10, 0.125)
        t.byModel["gpt-5"] = mtok(1.25, 10, 0.125)
        t.byModel["gpt"] = mtok(2.5, 10, 0.25)
        return t
    }
}

/// Loads exact per-model pricing: serves a correct bundled table immediately,
/// then refreshes from LiteLLM's dataset (cached to disk) in the background.
@MainActor
final class PricingStore: ObservableObject {
    @Published private(set) var table = PricingTable.bundled

    private static let url = URL(string:
        "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json")!
    private static let cacheURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Anthrocite", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "pricing.json")
    }()

    func start() {
        if let data = try? Data(contentsOf: Self.cacheURL),
           let parsed = Self.parse(data) {
            table = parsed
        }
        Task { await fetchRemote() }
    }

    private func fetchRemote() async {
        guard let data = try? await URLSession.shared.data(from: Self.url).0,
              let parsed = Self.parse(data) else { return }
        table = parsed
        try? data.write(to: Self.cacheURL, options: .atomic)
    }

    /// Parse LiteLLM's flat {modelName: {input_cost_per_token, ...}} map,
    /// keeping only Claude models.
    nonisolated private static func parse(_ data: Data) -> PricingTable? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var table = PricingTable.bundled
        for (name, value) in root {
            let n = name.lowercased()
            guard n.contains("claude") || n.contains("gpt") || n.contains("codex")
                    || n.hasPrefix("o1") || n.hasPrefix("o3") || n.hasPrefix("o4"),
                  let m = value as? [String: Any],
                  let inCost = (m["input_cost_per_token"] as? NSNumber)?.doubleValue,
                  let outCost = (m["output_cost_per_token"] as? NSNumber)?.doubleValue else { continue }
            let cw = (m["cache_creation_input_token_cost"] as? NSNumber)?.doubleValue ?? inCost * 1.25
            let cr = (m["cache_read_input_token_cost"] as? NSNumber)?.doubleValue ?? inCost * 0.1
            // Normalise the "anthropic.claude-..." Bedrock prefix to the bare id too.
            let key = name.replacingOccurrences(of: "anthropic.", with: "")
            table.byModel[key] = ModelPricing(input: inCost, output: outCost, cacheWrite: cw, cacheRead: cr)
        }
        return table
    }
}
