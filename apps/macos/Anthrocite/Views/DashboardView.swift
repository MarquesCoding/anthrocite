import SwiftUI
import Charts
import ServiceManagement

struct DashboardView: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore
    @ObservedObject private var nav = Navigation.shared
    @AppStorage("dashProvider") private var providerRaw = Provider.all.rawValue
    private var provider: Provider { Provider(rawValue: providerRaw) ?? .all }

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
            Group {
                switch nav.pane {
                case .overview: OverviewPane(usage: usage, pricing: pricing, provider: provider)
                case .projects: TablePane(title: "Projects", rows: projectRows)
                case .models:   ModelsPane(rows: modelRows)
                case .general:  GeneralPane()
                case .pricing:  PricingPane(usage: usage, pricing: pricing)
                case .about:    AboutPane()
                }
            }
            .toolbar {
                if DashboardPane.usage.contains(nav.pane) {
                    ToolbarItem {
                        Picker("Provider", selection: $providerRaw) {
                            ForEach(Provider.allCases) { Text($0.rawValue).tag($0.rawValue) }
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize()
                    }
                }
            }
        }
    }

    private var projectRows: [UsageRow] {
        let table = pricing.table
        return usage.index.byProject.compactMap { name, bd -> UsageRow? in
            let b = bd.filtered(provider)
            guard b.totalTokens > 0 else { return nil }
            return UsageRow(id: name, name: name, tokens: b.totalTokens, cost: b.totalCost(table))
        }.sorted { $0.tokens > $1.tokens }
    }
    private var modelRows: [UsageRow] {
        let table = pricing.table
        return usage.index.total.filtered(provider).byModel.map { key, counts in
            let model = ModelKey.model(key)
            // When showing all origins, label shared models with their agent.
            let name = provider == .all && ModelKey.origin(key) != .claude
                ? "\(model) · \(ModelKey.origin(key).rawValue)" : model
            return UsageRow(id: key, name: name, tokens: counts.total,
                            cost: counts.cost(table.pricing(for: model)))
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
private func series(_ usage: UsageStore, _ table: PricingTable, days: Int, provider: Provider) -> [DailyPoint] {
    usage.index.dailySeries(days: days).map {
        let b = $0.breakdown.filtered(provider)
        return DailyPoint(id: $0.date, date: $0.date, tokens: b.totalTokens, cost: b.totalCost(table))
    }
}

// MARK: - Overview

private struct OverviewPane: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore
    let provider: Provider

    // Stable snapshot so scrolling (which re-evaluates the body) doesn't
    // recompute the charts and retrigger their animations.
    @State private var s30: [DailyPoint] = []
    @State private var allTimeTokens = 0
    @State private var allTimeCost = 0.0
    @State private var weekTokens = 0
    @State private var todayTokens = 0

    private func recompute() {
        let table = pricing.table
        s30 = series(usage, table, days: 30, provider: provider)
        let total = usage.index.total.filtered(provider)
        allTimeTokens = total.totalTokens
        allTimeCost = total.totalCost(table)
        weekTokens = s30.suffix(7).reduce(0) { $0 + $1.tokens }
        todayTokens = usage.index.todayBreakdown.filtered(provider).totalTokens
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        MetricCard(title: "All-time tokens", value: Fmt.tokens(allTimeTokens), icon: "number")
                        MetricCard(title: "All-time cost", value: Fmt.usd(allTimeCost), icon: "dollarsign.circle")
                        MetricCard(title: "This week", value: Fmt.tokens(weekTokens), icon: "calendar")
                        MetricCard(title: "Today", value: Fmt.tokens(todayTokens), icon: "sun.max")
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
        .onAppear(perform: recompute)
        .onChange(of: usage.lastUpdated) { _, _ in recompute() }
        .onChange(of: pricing.table) { _, _ in recompute() }
        .onChange(of: provider) { _, _ in recompute() }
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
    @State private var hooksInstalled = HookInstaller.isInstalled
    @AppStorage(Prefs.showStatusKey) private var showStatus = true
    @AppStorage(Prefs.showTimerKey) private var showTimer = true
    @AppStorage(Prefs.iconKey) private var iconRaw = IconChoice.logo.rawValue
    @AppStorage(Prefs.accentKey) private var accentRaw = AccentChoice.system.rawValue
    @AppStorage(Prefs.soundKey) private var playSound = false
    @AppStorage(Prefs.showCostKey) private var showCost = true
    @AppStorage(Prefs.countdownKey) private var countdownRaw = CountdownFormat.hhmmss.rawValue
    @AppStorage(Prefs.discordKey) private var discordEnabled = false
    @AppStorage(Prefs.discordAppIDKey) private var discordAppID = ""
    @ObservedObject private var updater = Updater.shared

    private var icon: IconChoice { IconChoice(rawValue: iconRaw) ?? .logo }

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, v in LoginItem.set(v) }
            }
            Section("Menu Bar") {
                Picker("Icon", selection: $iconRaw) {
                    ForEach(IconChoice.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Picker("Colour", selection: $accentRaw) {
                    ForEach(AccentChoice.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                .disabled(icon.isColor)   // the crab keeps its own colours
                Picker("Limit countdown", selection: $countdownRaw) {
                    ForEach(CountdownFormat.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                Toggle("Show status text", isOn: $showStatus)
                Toggle("Show timer", isOn: $showTimer).disabled(!showStatus)
                Toggle("Show cost", isOn: $showCost)
                Toggle("Play a sound when a response completes", isOn: $playSound)
            }
            Section {
                integrationRow("Claude Code", ok: hooksInstalled,
                               okLabel: "Installed", offLabel: "Not installed")
                Button(hooksInstalled ? "Reinstall hooks" : "Install hooks") {
                    HookInstaller.install()
                    hooksInstalled = HookInstaller.isInstalled
                }
                integrationRow("Codex", ok: CodexScanner.isDetected,
                               okLabel: "Detected", offLabel: "Not found")
                integrationRow("Xcode", ok: TranscriptScanner.xcodeDetected,
                               okLabel: "Detected", offLabel: "Not used yet")
            } header: { Text("Integrations") }
            footer: { Text("Claude Code needs the statusLine + SessionEnd hooks for live status. Codex and Xcode log usage natively, so they're read automatically once detected.") }

            Section {
                Toggle("Discord Rich Presence", isOn: $discordEnabled)
                if discordEnabled {
                    TextField("Discord Application ID", text: $discordAppID)
                        .textFieldStyle(.roundedBorder)
                }
            } header: { Text("Discord") }
            footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shows your current project, model and live token usage in your Discord status.")
                    Text("Create an app at discord.com/developers, upload Rich Presence art assets named “claude” and “codex”, then paste its Application ID above.")
                }
            }

            Section {
                LabeledContent("Current version", value: "\(AppInfo.version) (\(AppInfo.build))")
                updatesRow
            } header: { Text("Updates") }
            footer: { Text("Checks GitHub for a newer signed release and installs it in place.") }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    private func integrationRow(_ name: String, ok: Bool, okLabel: String, offLabel: String) -> some View {
        LabeledContent(name) {
            Label(ok ? okLabel : offLabel, systemImage: ok ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(ok ? Color.green : Color.secondary)
                .labelStyle(.titleAndIcon)
        }
    }

    @ViewBuilder private var updatesRow: some View {
        switch updater.state {
        case .checking:
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Checking…").foregroundStyle(.secondary) }
        case .downloading:
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Downloading update…").foregroundStyle(.secondary) }
        case .available(let v):
            Label("Version \(v) available", systemImage: "arrow.down.circle.fill").foregroundStyle(.green)
            Button("Download & Install") { Task { await updater.downloadAndInstall() } }
        case .upToDate:
            Label("You're up to date", systemImage: "checkmark.circle").foregroundStyle(.secondary)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        case .idle:
            EmptyView()
        }
        Button("Check for Updates") { Task { await updater.check(userInitiated: true) } }
            .disabled(updater.state == .checking || updater.state == .downloading)
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
        ScrollView {
            VStack(spacing: 18) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

                VStack(spacing: 5) {
                    Text(AppInfo.name).font(.largeTitle.weight(.bold))
                    Text(AppInfo.tagline).foregroundStyle(.secondary)
                    Text("Version \(AppInfo.version) (\(AppInfo.build))")
                        .font(.caption).foregroundStyle(.tertiary)
                }

                Link(destination: AppInfo.website) {
                    Label("anthrocite.app", systemImage: "globe")
                }
                .buttonStyle(.bordered)

                GroupBox {
                    VStack(spacing: 0) {
                        ForEach(Array(AppInfo.credits.enumerated()), id: \.element.id) { i, c in
                            if i > 0 { Divider() }
                            creditRow(c)
                        }
                    }
                } label: {
                    Label("Credits", systemImage: "heart")
                }
                .frame(maxWidth: 420)

                Text(AppInfo.acknowledgement)
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("© 2026 Marques · \(AppInfo.license)")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(30)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("About")
    }

    private func creditRow(_ c: AppInfo.Credit) -> some View {
        Link(destination: c.url) {
            HStack(spacing: 12) {
                AsyncImage(url: c.avatarURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable().foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).fontWeight(.medium)
                    Text(c.role).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(c.handle).font(.callout).foregroundStyle(.secondary)
                Image(systemName: "arrow.up.right.square").foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
