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

    var totalTokens: Int { byModel.values.reduce(0) { $0 + $1.total } }

    /// The four token components summed across every model.
    var combined: TokenCounts { byModel.values.reduce(TokenCounts()) { $0 + $1 } }

    /// Exact cost, pricing each model id with the supplied table.
    func totalCost(_ table: PricingTable) -> Double {
        byModel.reduce(0) { $0 + $1.value.cost(table.pricing(for: $1.key)) }
    }

    /// Keep only models belonging to the given provider (`.all` = no filter).
    func filtered(_ provider: Provider) -> ModelBreakdown {
        guard provider != .all else { return self }
        var b = ModelBreakdown()
        b.byModel = byModel.filter { Provider.of($0.key) == provider }
        return b
    }
}

/// Which coding agent a model id belongs to.
enum Provider: String, CaseIterable, Identifiable, Sendable {
    case all = "All", claude = "Claude", codex = "Codex"
    var id: String { rawValue }

    static func of(_ modelID: String) -> Provider {
        let m = modelID.lowercased()
        if m.contains("gpt") || m.contains("codex") || m.hasPrefix("o1")
            || m.hasPrefix("o3") || m.hasPrefix("o4") { return .codex }
        return .claude
    }
}
