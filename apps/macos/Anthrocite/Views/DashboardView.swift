import SwiftUI
import Charts
import ServiceManagement

struct DashboardView: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore
    @ObservedObject private var nav = Navigation.shared
    @AppStorage("dashProvider") private var providerRaw = Provider.all.rawValue
    @AppStorage("dashRange") private var rangeRaw = TimeRange.all.rawValue
    @AppStorage("onboardingShown") private var onboardingShown = false
    private var provider: Provider { Provider(rawValue: providerRaw) ?? .all }
    private var range: TimeRange { TimeRange(rawValue: rangeRaw) ?? .all }
    /// Panes that get a time-range filter (Compare is all-time by design).
    private var rangedPane: Bool { [.overview, .projects, .models].contains(nav.pane) }

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
                case .overview: OverviewPane(usage: usage, pricing: pricing, provider: provider, range: range)
                case .projects: TablePane(title: "Projects", rows: projectRows)
                case .models:   ModelsPane(rows: modelRows)
                case .sessions: SessionsPane(usage: usage, pricing: pricing, provider: provider)
                case .compare:  ComparePane(usage: usage, pricing: pricing)
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
                if rangedPane {
                    ToolbarItem {
                        Picker("Range", selection: $rangeRaw) {
                            ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0.rawValue) }
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize()
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { !onboardingShown },
                                    set: { if !$0 { onboardingShown = true } })) {
            OnboardingView()
        }
    }

    private var projectRows: [UsageRow] {
        let table = pricing.table
        return usage.index.projects(lastDays: range.days).compactMap { name, bd -> UsageRow? in
            let b = bd.filtered(provider)
            guard b.totalTokens > 0 else { return nil }
            return UsageRow(id: name, name: name, tokens: b.totalTokens, cost: b.totalCost(table))
        }.sorted { $0.tokens > $1.tokens }
    }
    private var modelRows: [UsageRow] {
        let table = pricing.table
        return usage.index.breakdown(lastDays: range.days).filtered(provider).byModel.map { key, counts in
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
    let range: TimeRange

    // Stable snapshot so scrolling (which re-evaluates the body) doesn't
    // recompute the charts and retrigger their animations.
    @State private var pts: [DailyPoint] = []
    @State private var rangeTokens = 0
    @State private var rangeCost = 0.0
    @State private var cacheSaved = 0.0
    @State private var avgDaily = 0.0
    @State private var hitRate = 0.0

    private var chartDays: Int { range.days ?? 90 }

    private func recompute() {
        let table = pricing.table
        pts = series(usage, table, days: chartDays, provider: provider)
        let bd = usage.index.breakdown(lastDays: range.days).filtered(provider)
        rangeTokens = bd.totalTokens
        rangeCost = bd.totalCost(table)
        cacheSaved = bd.cacheSavings(table)
        hitRate = bd.cacheHitRate
        avgDaily = Insights.avgDailyCost(usage.index, table, days: 7)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        MetricCard(title: "Tokens", value: Fmt.tokens(rangeTokens), icon: "number")
                        MetricCard(title: "Cost", value: Fmt.usd(rangeCost), icon: "dollarsign.circle")
                        MetricCard(title: "Cache saved", value: Fmt.usd(cacheSaved), icon: "bolt.badge.clock")
                        MetricCard(title: "Avg / day", value: Fmt.usd(avgDaily), icon: "calendar")
                    }
                }
                Text("Projected ≈ \(Fmt.usd(avgDaily * 30)) this month at recent pace · \(Int((hitRate * 100).rounded()))% cache hit")
                    .font(.caption).foregroundStyle(.secondary)

                ChartCard(title: "Tokens per day", subtitle: "Last \(chartDays) days") {
                    Chart(pts) { p in
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

                ChartCard(title: "Cost per day", subtitle: "Last \(chartDays) days") {
                    Chart(pts) { p in
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
        .onChange(of: range) { _, _ in recompute() }
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

// MARK: - Sessions

private struct SessionRow: Identifiable {
    let id: String
    let project: String
    let model: String
    let date: Date
    let duration: TimeInterval
    let tokens: Int
    let cost: Double
}

private struct SessionsPane: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore
    let provider: Provider

    private var rows: [SessionRow] {
        let table = pricing.table
        return usage.index.recentSessions().compactMap { s in
            let b = s.breakdown.filtered(provider)
            guard b.totalTokens > 0 else { return nil }
            return SessionRow(id: s.id, project: s.project.isEmpty ? "session" : s.project,
                              model: ModelKey.model(s.lastModel), date: s.lastTimestamp,
                              duration: s.duration, tokens: b.totalTokens, cost: b.totalCost(table))
        }
    }

    var body: some View {
        Group {
            if rows.isEmpty {
                ContentUnavailableView("No sessions yet", systemImage: "clock.arrow.circlepath")
            } else {
                Table(rows) {
                    TableColumn("Project", value: \.project)
                    TableColumn("Model") { Text($0.model).foregroundStyle(.secondary) }.width(150)
                    TableColumn("When") { Text($0.date, format: .relative(presentation: .named)) }.width(110)
                    TableColumn("Duration") { Text(Fmt.duration($0.duration)) }.width(80)
                    TableColumn("Tokens") { Text(Fmt.tokens($0.tokens)).monospacedDigit() }.width(80)
                    TableColumn("Cost") { Text(Fmt.usd($0.cost)).monospacedDigit() }.width(80)
                }
            }
        }
        .navigationTitle("Sessions")
    }
}

// MARK: - Compare

private struct ComparePane: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore

    private var rows: [UsageRow] {
        let table = pricing.table
        return [Provider.claude, .codex, .gemini].compactMap { p in
            let b = usage.index.total.filtered(p)
            guard b.totalTokens > 0 else { return nil }
            return UsageRow(id: p.rawValue, name: p.rawValue, tokens: b.totalTokens, cost: b.totalCost(table))
        }.sorted { $0.cost > $1.cost }
    }

    var body: some View {
        ScrollView {
            if rows.isEmpty {
                ContentUnavailableView("No usage yet", systemImage: "chart.bar.xaxis").padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ChartCard(title: "Cost by provider", subtitle: "All time") {
                        Chart(rows) { r in
                            BarMark(x: .value("Provider", r.name), y: .value("Cost", r.cost))
                                .foregroundStyle(.tint).cornerRadius(4)
                                .annotation(position: .top) { Text(Fmt.usd(r.cost)).font(.caption2).foregroundStyle(.secondary) }
                        }
                        .frame(height: 200)
                    }
                    ChartCard(title: "Tokens by provider", subtitle: "All time") {
                        Chart(rows) { r in
                            BarMark(x: .value("Provider", r.name), y: .value("Tokens", r.tokens))
                                .foregroundStyle(.tint.opacity(0.7)).cornerRadius(4)
                                .annotation(position: .top) { Text(Fmt.tokens(r.tokens)).font(.caption2).foregroundStyle(.secondary) }
                        }
                        .chartYAxis { tokenAxis() }
                        .frame(height: 200)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Compare")
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
    @AppStorage(Prefs.menuMetricKey) private var menuMetricRaw = MenuMetric.status.rawValue
    @AppStorage(Prefs.alertsKey) private var alertsEnabled = false
    @AppStorage(Prefs.limitThresholdKey) private var limitThreshold = 80
    @AppStorage(Prefs.spendThresholdKey) private var spendThreshold = 0.0
    @AppStorage(Prefs.planKey) private var planRaw = ClaudePlan.unspecified.rawValue
    @ObservedObject private var updater = Updater.shared

    private var icon: IconChoice { IconChoice(rawValue: iconRaw) ?? .logo }
    private var menuMetric: MenuMetric { MenuMetric(rawValue: menuMetricRaw) ?? .status }

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
                Picker("Show", selection: $menuMetricRaw) {
                    ForEach(MenuMetric.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                Picker("Limit countdown", selection: $countdownRaw) {
                    ForEach(CountdownFormat.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                Toggle("Show status text", isOn: $showStatus).disabled(menuMetric != .status)
                Toggle("Show timer", isOn: $showTimer).disabled(!showStatus || menuMetric != .status)
                Toggle("Show cost", isOn: $showCost)
                Toggle("Play a sound when a response completes", isOn: $playSound)
            }
            Section {
                Toggle("Notify on thresholds", isOn: $alertsEnabled)
                if alertsEnabled {
                    Stepper("Rate-limit alert at \(limitThreshold)%", value: $limitThreshold, in: 50...100, step: 5)
                    LabeledContent("Daily spend alert") {
                        TextField("$0 = off", value: $spendThreshold, format: .number)
                            .frame(width: 90).multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder)
                    }
                }
            } header: { Text("Alerts") }
            footer: { Text("Posts a Notification Center alert when a 5-hour/weekly limit, or today's spend, crosses the threshold. $0 disables the spend alert.") }
            Section {
                Picker("Claude plan", selection: $planRaw) {
                    ForEach(ClaudePlan.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
            } header: { Text("Account") }
            footer: { Text("For your reference — Anthrocite reads your real rate limits from Claude Code directly.") }
            Section {
                integrationRow("Claude Code", ok: hooksInstalled,
                               okLabel: "Installed", offLabel: "Not installed")
                Button(hooksInstalled ? "Reinstall hooks" : "Install hooks") {
                    HookInstaller.install()
                    hooksInstalled = HookInstaller.isInstalled
                }
                integrationRow("Codex", ok: CodexScanner.isDetected,
                               okLabel: "Detected", offLabel: "Not found")
                integrationRow("Gemini", ok: GeminiScanner.isDetected,
                               okLabel: "Detected", offLabel: "Not used yet")
            } header: { Text("Integrations") }
            footer: { Text("Claude Code needs the statusLine + SessionEnd hooks for live status. Codex and Gemini log usage natively, so they're read automatically once detected.") }

            Section {
                Toggle("Discord Rich Presence", isOn: $discordEnabled)
                if discordEnabled {
                    TextField("Application ID (optional override)", text: $discordAppID)
                        .textFieldStyle(.roundedBorder)
                }
            } header: { Text("Discord") }
            footer: {
                Text("Shows your current project, model and live token usage in your Discord status. Requires the Discord desktop app to be running. Leave the ID blank to use the official Anthrocite app.")
            }

            Section {
                LabeledContent("Current version", value: "\(AppInfo.version) (\(AppInfo.build))")
                updatesRow
            } header: { Text("Updates") }
            footer: { Text("Checks GitHub for a newer signed release and installs it in place.") }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
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

    // Representative models per provider for the rate card.
    private let groups: [(String, [(String, String)])] = [
        ("Claude", [("Opus 4.5", "claude-opus-4-5"),
                    ("Sonnet 4.5", "claude-sonnet-4-5"),
                    ("Haiku 4.5", "claude-haiku-4-5")]),
        ("OpenAI · Codex", [("GPT-5", "gpt-5"),
                            ("GPT-5 Codex", "gpt-5-codex")]),
        ("Gemini", [("2.5 Pro", "gemini-2.5-pro"),
                    ("2.5 Flash", "gemini-2.5-flash")]),
    ]

    var body: some View {
        Form {
            Section {
                LabeledContent("Models seen", value: "\(usage.index.total.byModel.count)")
                LabeledContent("Projects", value: "\(usage.index.byProject.count)")
                Button("Rebuild index") { Task { await usage.refresh() } }
            }
            ForEach(groups, id: \.0) { provider, models in
                Section(provider) {
                    ForEach(models, id: \.1) { name, id in
                        LabeledContent(name, value: line(pricing.table.pricing(for: id)))
                    }
                }
            }
            Section {
                Button("Export usage as CSV…") {
                    UsageExport.saveCSV(UsageExport.csv(usage.index, pricing.table))
                }
                Button("Copy summary") {
                    UsageExport.copy(UsageExport.summary(usage.index, pricing.table))
                }
            } header: { Text("Export") }
            Section {
                Button("Refresh prices from LiteLLM") { pricing.start() }
            } footer: {
                Text("Per million tokens. Live rates from LiteLLM, cached locally; the active session uses the agent's own reported cost.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Rates")
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
