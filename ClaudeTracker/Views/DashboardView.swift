import SwiftUI
import Charts
import ServiceManagement

struct DashboardView: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore
    @ObservedObject private var nav = Navigation.shared

    var body: some View {
        NavigationSplitView {
            List(selection: $nav.pane) {
                Section("Usage") {
                    ForEach(DashboardPane.usage) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                }
                Section("App") {
                    ForEach(DashboardPane.app) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                }
            }
            .navigationSplitViewColumnWidth(200)
        } detail: {
            switch nav.pane {
            case .overview: OverviewPane(usage: usage, pricing: pricing)
            case .projects: TablePane(title: "Projects", rows: projectRows)
            case .models:   ModelsPane(rows: modelRows)
            case .general:  GeneralPane()
            case .pricing:  PricingPane(usage: usage, pricing: pricing)
            case .about:    AboutPane()
            }
        }
    }

    private var projectRows: [UsageRow] {
        let table = pricing.table
        return usage.index.byProject.map {
            UsageRow(id: $0.key, name: $0.key, tokens: $0.value.totalTokens, cost: $0.value.totalCost(table))
        }.sorted { $0.tokens > $1.tokens }
    }
    private var modelRows: [UsageRow] {
        let table = pricing.table
        return usage.index.total.byModel.map {
            UsageRow(id: $0.key, name: $0.key, tokens: $0.value.total,
                     cost: $0.value.cost(table.pricing(for: $0.key)))
        }.sorted { $0.tokens > $1.tokens }
    }
}

// MARK: - Shared models

struct UsageRow: Identifiable {
    let id: String
    let name: String
    let tokens: Int
    let cost: Double
}

private struct DailyPoint: Identifiable {
    let id: Date
    let date: Date
    let tokens: Int
    let cost: Double
}

@MainActor
private func series(_ usage: UsageStore, _ table: PricingTable, days: Int) -> [DailyPoint] {
    usage.index.dailySeries(days: days).map {
        DailyPoint(id: $0.date, date: $0.date, tokens: $0.breakdown.totalTokens, cost: $0.breakdown.totalCost(table))
    }
}

// MARK: - Overview

private struct OverviewPane: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore

    var body: some View {
        let table = pricing.table
        let s30 = series(usage, table, days: 30)
        let week = s30.suffix(7)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        MetricCard(title: "All-time tokens", value: Fmt.tokens(usage.index.total.totalTokens), icon: "number")
                        MetricCard(title: "All-time cost", value: Fmt.usd(usage.index.total.totalCost(table)), icon: "dollarsign.circle")
                        MetricCard(title: "This week", value: Fmt.tokens(week.reduce(0) { $0 + $1.tokens }), icon: "calendar")
                        MetricCard(title: "Today", value: Fmt.tokens(usage.index.todayBreakdown.totalTokens), icon: "sun.max")
                    }
                }

                ChartCard(title: "Tokens per day", subtitle: "Last 30 days") {
                    Chart(s30) { p in
                        AreaMark(x: .value("Day", p.date, unit: .day), y: .value("Tokens", p.tokens))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.linearGradient(colors: [.accentColor.opacity(0.35), .accentColor.opacity(0.02)],
                                                             startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", p.date, unit: .day), y: .value("Tokens", p.tokens))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.tint)
                    }
                    .chartYAxis { tokenAxis() }
                    .chartXAxis { dayAxis() }
                    .frame(height: 220)
                }

                ChartCard(title: "Cost per day", subtitle: "Last 30 days") {
                    Chart(s30) { p in
                        BarMark(x: .value("Day", p.date, unit: .day), y: .value("Cost", p.cost))
                            .foregroundStyle(.tint)
                            .cornerRadius(3)
                    }
                    .chartXAxis { dayAxis() }
                    .frame(height: 180)
                }
            }
            .padding(20)
        }
        .navigationTitle("Overview")
    }
}

// MARK: - Tables

private struct TablePane: View {
    let title: String
    let rows: [UsageRow]
    @State private var sort = [KeyPathComparator(\UsageRow.tokens, order: .reverse)]

    var body: some View {
        let maxTokens = rows.map(\.tokens).max() ?? 1
        Table(rows.sorted(using: sort), sortOrder: $sort) {
            TableColumn(title == "Projects" ? "Project" : "Model", value: \.name)
            TableColumn("Tokens", value: \.tokens) { Text(Fmt.tokens($0.tokens)).monospacedDigit() }
                .width(90)
            TableColumn("Cost", value: \.cost) { Text(Fmt.usd($0.cost)).monospacedDigit() }
                .width(90)
            TableColumn("Share") { r in
                ProgressView(value: Double(r.tokens), total: Double(maxTokens))
                    .controlSize(.small)
            }
        }
        .navigationTitle(title)
    }
}

private struct ModelsPane: View {
    let rows: [UsageRow]
    var body: some View {
        VStack(spacing: 0) {
            ChartCard(title: "Tokens by model", subtitle: nil) {
                Chart(rows) { r in
                    BarMark(x: .value("Tokens", r.tokens), y: .value("Model", r.name))
                        .foregroundStyle(.tint)
                        .cornerRadius(3)
                }
                .chartXAxis { tokenAxis() }
                .frame(height: max(120, CGFloat(rows.count) * 36))
            }
            .padding(20)
            TablePane(title: "Models", rows: rows)
        }
    }
}

// MARK: - Settings panes

private struct GeneralPane: View {
    @State private var launchAtLogin = LoginItem.isEnabled
    @AppStorage(Prefs.showStatusKey) private var showStatus = true
    @AppStorage(Prefs.showTimerKey) private var showTimer = true

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, v in LoginItem.set(v) }
            }
            Section("Menu Bar") {
                Toggle("Show status text", isOn: $showStatus)
                Toggle("Show timer", isOn: $showTimer).disabled(!showStatus)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

private struct PricingPane: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore
    private let families: [(String, ModelFamily, String)] = [
        ("Opus", .opus, "claude-opus-4-8"),
        ("Sonnet", .sonnet, "claude-sonnet-4-6"),
        ("Haiku", .haiku, "claude-haiku-4-5"),
    ]
    var body: some View {
        Form {
            Section {
                LabeledContent("Models seen", value: "\(usage.index.total.byModel.count)")
                LabeledContent("Projects", value: "\(usage.index.byProject.count)")
                Button("Rebuild index") { Task { await usage.refresh() } }
            }
            Section {
                ForEach(families, id: \.0) { name, _, id in
                    let p = pricing.table.pricing(for: id)
                    LabeledContent(name, value: line(p))
                }
                Button("Refresh prices from LiteLLM") { pricing.start() }
            } header: { Text("Pricing · per million tokens") }
            footer: { Text("Live rates from LiteLLM, cached locally. The current session uses Claude Code's own exact cost.") }
        }
        .formStyle(.grouped)
        .navigationTitle("Pricing")
    }
    private func line(_ p: ModelPricing) -> String {
        func m(_ v: Double) -> String { String(format: "$%g", v * 1_000_000) }
        return "in \(m(p.input)) · out \(m(p.output)) · cache \(m(p.cacheRead))"
    }
}

private struct AboutPane: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 52)).foregroundStyle(.tint)
            Text(AppInfo.name).font(.largeTitle.weight(.semibold))
            Text("Version \(AppInfo.version) (\(AppInfo.build))").foregroundStyle(.secondary)
            Text(AppInfo.tagline).foregroundStyle(.secondary)
            Link("Website", destination: AppInfo.website)
            Text("\(AppInfo.license)").font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("About")
    }
}

// MARK: - Building blocks

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.caption).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
                Text(value).font(.title.weight(.semibold)).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.headline)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                content
            }
            .padding(6)
            .frame(maxWidth: .infinity)
        }
    }
}

private func tokenAxis() -> some AxisContent {
    AxisMarks { value in
        AxisGridLine()
        AxisValueLabel { if let n = value.as(Int.self) { Text(Fmt.tokens(n)) } }
    }
}
private func dayAxis() -> some AxisContent {
    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
        AxisGridLine()
        AxisValueLabel(format: .dateTime.month().day())
    }
}
