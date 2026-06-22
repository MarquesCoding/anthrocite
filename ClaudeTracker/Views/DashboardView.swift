import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview", projects = "Projects", models = "Models"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview: return "chart.xyaxis.line"
            case .projects: return "folder"
            case .models: return "cpu"
            }
        }
    }
    @State private var tab: Tab = .overview

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $tab) { t in
                Label(t.rawValue, systemImage: t.icon).tag(t)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            switch tab {
            case .overview: OverviewPane(usage: usage, pricing: pricing)
            case .projects: ProjectsPane(usage: usage, pricing: pricing)
            case .models:   ModelsPane(usage: usage, pricing: pricing)
            }
        }
        .frame(minWidth: 780, minHeight: 540)
    }
}

/// A point per day for the trend charts.
private struct DailyPoint: Identifiable {
    let id: Date
    let date: Date
    let tokens: Int
    let cost: Double
}

@MainActor
private func series(_ usage: UsageStore, _ table: PricingTable, days: Int) -> [DailyPoint] {
    usage.index.dailySeries(days: days).map {
        DailyPoint(id: $0.date, date: $0.date,
                   tokens: $0.breakdown.totalTokens, cost: $0.breakdown.totalCost(table))
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
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    StatCard(title: "All-time tokens", value: Fmt.tokens(usage.index.total.totalTokens))
                    StatCard(title: "All-time cost", value: Fmt.usd(usage.index.total.totalCost(table)))
                    StatCard(title: "This week", value: Fmt.tokens(week.reduce(0) { $0 + $1.tokens }))
                    StatCard(title: "Today", value: Fmt.tokens(usage.index.todayBreakdown.totalTokens))
                }

                GroupBox("Tokens per day · last 30 days") {
                    Chart(s30) { p in
                        AreaMark(x: .value("Day", p.date, unit: .day),
                                 y: .value("Tokens", p.tokens))
                        .foregroundStyle(.tint.opacity(0.25))
                        LineMark(x: .value("Day", p.date, unit: .day),
                                 y: .value("Tokens", p.tokens))
                        .foregroundStyle(.tint)
                    }
                    .chartYAxis { tokenAxis() }
                    .frame(height: 200).padding(.top, 4)
                }

                GroupBox("Cost per day · last 30 days") {
                    Chart(s30) { p in
                        BarMark(x: .value("Day", p.date, unit: .day),
                                y: .value("Cost", p.cost))
                    }
                    .frame(height: 160).padding(.top, 4)
                }
            }
            .padding(20)
        }
        .navigationTitle("Overview")
    }
}

private func tokenAxis() -> some AxisContent {
    AxisMarks { value in
        AxisGridLine()
        AxisValueLabel {
            if let n = value.as(Int.self) { Text(Fmt.tokens(n)) }
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.title2.weight(.semibold)).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Projects

private struct UsageRow: Identifiable {
    let id: String
    let name: String
    let tokens: Int
    let cost: Double
}

private struct ProjectsPane: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore
    @State private var sort = [KeyPathComparator(\UsageRow.tokens, order: .reverse)]

    var body: some View {
        let table = pricing.table
        let rows = usage.index.byProject.map {
            UsageRow(id: $0.key, name: $0.key, tokens: $0.value.totalTokens, cost: $0.value.totalCost(table))
        }.sorted(using: sort)

        Table(rows, sortOrder: $sort) {
            TableColumn("Project", value: \.name)
            TableColumn("Tokens", value: \.tokens) { Text(Fmt.tokens($0.tokens)).monospacedDigit() }
            TableColumn("Cost", value: \.cost) { Text(Fmt.usd($0.cost)).monospacedDigit() }
        }
        .navigationTitle("Projects")
    }
}

// MARK: - Models

private struct ModelsPane: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore
    @State private var sort = [KeyPathComparator(\UsageRow.tokens, order: .reverse)]

    var body: some View {
        let table = pricing.table
        let rows = usage.index.total.byModel.map {
            UsageRow(id: $0.key, name: $0.key, tokens: $0.value.total, cost: $0.value.cost(table.pricing(for: $0.key)))
        }.sorted(using: sort)

        VStack(spacing: 0) {
            Chart(rows) { r in
                BarMark(x: .value("Tokens", r.tokens), y: .value("Model", r.name))
            }
            .chartXAxis { tokenAxis() }
            .frame(height: max(120, CGFloat(rows.count) * 34))
            .padding(20)

            Table(rows, sortOrder: $sort) {
                TableColumn("Model", value: \.name)
                TableColumn("Tokens", value: \.tokens) { Text(Fmt.tokens($0.tokens)).monospacedDigit() }
                TableColumn("Cost", value: \.cost) { Text(Fmt.usd($0.cost)).monospacedDigit() }
            }
        }
        .navigationTitle("Models")
    }
}
