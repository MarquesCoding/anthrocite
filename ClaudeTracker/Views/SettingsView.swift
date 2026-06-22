import SwiftUI

struct SettingsView: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore

    enum Pane: String, CaseIterable, Identifiable {
        case general = "General", usage = "Usage & Pricing", about = "About"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .usage: return "chart.bar"
            case .about: return "info.circle"
            }
        }
    }

    @State private var pane: Pane = .general

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { p in
                Label(p.rawValue, systemImage: p.icon).tag(p)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            Group {
                switch pane {
                case .general: GeneralPane()
                case .usage:   UsagePane(usage: usage, pricing: pricing)
                case .about:   AboutPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 640, height: 460)
    }
}

// MARK: - General

private struct GeneralPane: View {
    @State private var launchAtLogin = LoginItem.isEnabled
    @AppStorage(Prefs.accentKey) private var accentRaw = AccentChoice.system.rawValue
    @AppStorage(Prefs.showStatusKey) private var showStatus = true
    @AppStorage(Prefs.showTimerKey) private var showTimer = true

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, v in LoginItem.set(v) }
            }
            Section("Menu Bar") {
                Picker("Accent", selection: $accentRaw) {
                    ForEach(AccentChoice.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                Toggle("Show status text", isOn: $showStatus)
                Toggle("Show timer", isOn: $showTimer).disabled(!showStatus)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

// MARK: - Usage & Pricing

private struct UsagePane: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var pricing: PricingStore

    private let families: [(String, ModelFamily)] =
        [("Opus", .opus), ("Sonnet", .sonnet), ("Haiku", .haiku)]

    var body: some View {
        Form {
            Section {
                LabeledContent("Indexed sessions", value: "\(usage.index.sessions.count)")
                LabeledContent("Models seen", value: "\(usage.index.total.byModel.count)")
                Button("Rebuild index now") { Task { await usage.refresh() } }
            } header: { Text("Usage") }

            Section {
                ForEach(families, id: \.0) { name, fam in
                    let p = pricing.table.pricing(for: fam.sampleID)
                    LabeledContent(name, value: priceLine(p))
                }
                Button("Refresh prices from LiteLLM") { pricing.start() }
            } header: { Text("Pricing (per million tokens)") }
            footer: { Text("Live rates from LiteLLM's public dataset, cached locally. The current session uses Claude Code's own exact cost.") }
        }
        .formStyle(.grouped)
        .navigationTitle("Usage & Pricing")
    }

    private func priceLine(_ p: ModelPricing) -> String {
        func m(_ v: Double) -> String { String(format: "$%g", v * 1_000_000) }
        return "in \(m(p.input)) · out \(m(p.output)) · cache \(m(p.cacheRead))"
    }
}

private extension ModelFamily {
    var sampleID: String {
        switch self {
        case .opus: return "claude-opus-4-8"
        case .sonnet: return "claude-sonnet-4-6"
        case .haiku: return "claude-haiku-4-5"
        case .other: return "claude"
        }
    }
}

// MARK: - About

private struct AboutPane: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 52)).foregroundStyle(.tint)
            Text(AppInfo.name).font(.title.weight(.semibold))
            Text("Version \(AppInfo.version) (\(AppInfo.build))").foregroundStyle(.secondary)
            Text(AppInfo.tagline).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Link("GitHub", destination: AppInfo.githubURL)
                Button("Check for Updates…") { /* wired to Sparkle next */ }
            }
            .padding(.top, 4)

            Text("\(AppInfo.license) License").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("About")
    }
}
