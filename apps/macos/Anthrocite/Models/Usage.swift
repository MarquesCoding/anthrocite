import Foundation

/// We still bucket models into a coarse family for pricing fallbacks only.
enum ModelFamily: String, Codable, CaseIterable, Sendable {
    case opus, sonnet, haiku, other

    static func from(modelID: String) -> ModelFamily {
        let id = modelID.lowercased()
        if id.contains("opus") { return .opus }
        if id.contains("sonnet") { return .sonnet }
        if id.contains("haiku") { return .haiku }
        return .other
    }
}

// MARK: - Token counts

struct TokenCounts: Codable, Sendable, Equatable {
    var input: Int = 0
    var output: Int = 0
    var cacheWrite: Int = 0   // cache_creation_input_tokens
    var cacheRead: Int = 0    // cache_read_input_tokens

    var total: Int { input + output + cacheWrite + cacheRead }

    static func + (lhs: TokenCounts, rhs: TokenCounts) -> TokenCounts {
        TokenCounts(input: lhs.input + rhs.input,
                    output: lhs.output + rhs.output,
                    cacheWrite: lhs.cacheWrite + rhs.cacheWrite,
                    cacheRead: lhs.cacheRead + rhs.cacheRead)
    }
    static func += (lhs: inout TokenCounts, rhs: TokenCounts) { lhs = lhs + rhs }

    func cost(_ p: ModelPricing) -> Double {
        Double(input) * p.input
            + Double(output) * p.output
            + Double(cacheWrite) * p.cacheWrite
            + Double(cacheRead) * p.cacheRead
    }
}

/// Token counts keyed by exact model id, so cost can be priced per model.
struct ModelBreakdown: Codable, Sendable, Equatable {
    var byModel: [String: TokenCounts] = [:]

    mutating func add(_ counts: TokenCounts, model: String) {
        byModel[model, default: TokenCounts()] += counts
    }

    mutating func merge(_ other: ModelBreakdown) {
        for (k, v) in other.byModel { byModel[k, default: TokenCounts()] += v }
    }

    static func sum(_ breakdowns: [ModelBreakdown]) -> ModelBreakdown {
        var out = ModelBreakdown()
        for b in breakdowns { out.merge(b) }
        return out
    }

    var totalTokens: Int { byModel.values.reduce(0) { $0 + $1.total } }

    /// The four token components summed across every model.
    var combined: TokenCounts { byModel.values.reduce(TokenCounts()) { $0 + $1 } }

    /// Exact cost, pricing each model id with the supplied table.
    func totalCost(_ table: PricingTable) -> Double {
        byModel.reduce(0) { $0 + $1.value.cost(table.pricing(for: ModelKey.model($1.key))) }
    }

    /// USD saved by prompt caching: each cache-read token would otherwise have
    /// been billed at the full input rate.
    func cacheSavings(_ table: PricingTable) -> Double {
        byModel.reduce(0) { acc, kv in
            let p = table.pricing(for: ModelKey.model(kv.key))
            return acc + Double(kv.value.cacheRead) * max(0, p.input - p.cacheRead)
        }
    }

    /// Fraction of prompt tokens served from cache (0…1).
    var cacheHitRate: Double {
        let c = combined
        let prompt = c.input + c.cacheRead + c.cacheWrite
        return prompt > 0 ? Double(c.cacheRead) / Double(prompt) : 0
    }

    /// Keep only models belonging to the given provider (`.all` = no filter).
    func filtered(_ provider: Provider) -> ModelBreakdown {
        guard provider != .all else { return self }
        var b = ModelBreakdown()
        b.byModel = byModel.filter { ModelKey.origin($0.key) == provider }
        return b
    }
}

/// Which coding agent produced some usage. Because Xcode's coding intelligence
/// reuses Claude/Codex *models*, origin can't be inferred from the model id —
/// it's tagged from the data source and encoded into the breakdown key.
enum Provider: String, CaseIterable, Identifiable, Sendable {
    case all = "All", claude = "Claude", codex = "Codex", xcode = "Xcode", gemini = "Gemini"
    var id: String { rawValue }

    /// Legacy fallback: classify a bare model id (used for keys written before
    /// origin tagging existed, which were Claude- or Codex-only).
    static func of(_ modelID: String) -> Provider {
        let m = modelID.lowercased()
        if m.contains("gemini") || m.contains("gemma") { return .gemini }
        if m.contains("gpt") || m.contains("codex") || m.hasPrefix("o1")
            || m.hasPrefix("o3") || m.hasPrefix("o4") { return .codex }
        return .claude
    }
}

/// Breakdown keys are `"<origin>\u{1}<model>"`, so a model used by more than one
/// agent (e.g. Claude in both the CLI and Xcode) stays separable. Keys written
/// before this scheme have no separator and fall back to model-based origin.
enum ModelKey {
    static let sep: Character = "\u{1}"

    static func make(_ origin: Provider, _ model: String) -> String {
        "\(origin.rawValue)\(sep)\(model)"
    }
    static func origin(_ key: String) -> Provider {
        guard let i = key.firstIndex(of: sep) else { return .of(key) }
        return Provider(rawValue: String(key[..<i])) ?? .of(model(key))
    }
    static func model(_ key: String) -> String {
        guard let i = key.firstIndex(of: sep) else { return key }
        return String(key[key.index(after: i)...])
    }
}
