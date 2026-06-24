import AppKit

/// Exports the usage index as CSV / a copyable text summary.
enum UsageExport {
    static func csv(_ index: AggregateIndex, _ table: PricingTable) -> String {
        var lines = ["provider,model,input,output,cache_write,cache_read,total,cost_usd"]
        for (key, c) in index.total.byModel.sorted(by: { $0.value.total > $1.value.total }) {
            let model = ModelKey.model(key)
            let origin = ModelKey.origin(key).rawValue
            let cost = c.cost(table.pricing(for: model))
            lines.append("\(origin),\(model),\(c.input),\(c.output),\(c.cacheWrite),\(c.cacheRead),\(c.total),\(String(format: "%.4f", cost))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func summary(_ index: AggregateIndex, _ table: PricingTable) -> String {
        let t = index.total
        let today = index.todayBreakdown
        return """
        Anthrocite usage
        All-time: \(Fmt.tokens(t.totalTokens)) tokens · \(Fmt.usd(t.totalCost(table)))
        Today: \(Fmt.tokens(today.totalTokens)) tokens · \(Fmt.usd(today.totalCost(table)))
        Cache saved (all-time): \(Fmt.usd(t.cacheSavings(table)))
        """
    }

    @MainActor static func saveCSV(_ text: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "anthrocite-usage.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? text.data(using: .utf8)?.write(to: url)
    }

    @MainActor static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
