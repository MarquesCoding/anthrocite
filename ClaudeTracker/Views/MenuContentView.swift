import SwiftUI

enum Scope: String, CaseIterable, Identifiable {
    case today = "Today", session = "Session", total = "Total"
    var id: String { rawValue }
}

/// The MenuBarExtra (.window) dropdown — all native SwiftUI controls.
struct MenuContentView: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var status: StatusStore
    @ObservedObject var pricing: PricingStore

    @Environment(\.openWindow) private var openWindow
    @AppStorage(Prefs.scopeKey) private var scopeRaw = Scope.today.rawValue
    @AppStorage(Prefs.showTimerKey) private var showTimer = true
    @AppStorage(Prefs.showStatusKey) private var showStatus = true

    private var scope: Scope { Scope(rawValue: scopeRaw) ?? .today }

    private var breakdown: ModelBreakdown {
        switch scope {
        case .today:   return usage.index.todayBreakdown
        case .total:   return usage.index.total
        case .session: return usage.index.currentSession?.breakdown ?? ModelBreakdown()
        }
    }

    private var costString: String {
        if scope == .session, let real = status.primary?.costUSD { return Fmt.usd(real) }
        return Fmt.usd(breakdown.totalCost(pricing.table))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !status.sessions.isEmpty {
                sessionsSection
                Divider()
            }
            usageSection
            Divider()
            limitsSection
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    // MARK: Sessions

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(status.sessions.count == 1 ? "Session" : "Sessions")
                    .font(.headline)
                Spacer()
                if status.workingCount > 0 {
                    Text("\(status.workingCount) working")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(status.sessions) { sessionRow($0) }
        }
    }

    private func sessionRow(_ s: LiveSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Circle().fill(s.isWorking ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(s.project).fontWeight(.medium).lineLimit(1)
                Spacer(minLength: 8)
                sessionStatus(s)
            }
            if let ctx = s.context {
                ProgressView(value: min(ctx.usedPercentage, 100), total: 100)
                Text("\(Fmt.tokens(ctx.usedTokens)) of \(Fmt.tokens(ctx.windowSize)) · \(Int(ctx.usedPercentage.rounded()))% context")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func sessionStatus(_ s: LiveSession) -> some View {
        if s.isWorking, let since = s.activeSince {
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                Text(showTimer ? "\(s.statusText) \(max(0, Int(tl.date.timeIntervalSince(since))))s" : s.statusText)
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Text("idle").font(.caption).foregroundStyle(.tertiary)
        }
    }

    // MARK: Usage

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Scope", selection: Binding(get: { scope }, set: { scopeRaw = $0.rawValue })) {
                ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            LabeledContent("Tokens") { Text(Fmt.tokens(breakdown.totalTokens)).fontWeight(.semibold) }
            LabeledContent("Cost") { Text(costString).fontWeight(.semibold) }

            let c = breakdown.combined
            if c.total > 0 {
                Group {
                    LabeledContent("Input") { Text(Fmt.tokens(c.input)) }
                    LabeledContent("Output") { Text(Fmt.tokens(c.output)) }
                    LabeledContent("Cache write") { Text(Fmt.tokens(c.cacheWrite)) }
                    LabeledContent("Cache read") { Text(Fmt.tokens(c.cacheRead)) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Limits

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Limits").font(.headline)
            limitRow("5-Hour Session", status.fiveHour)
            limitRow("Weekly", status.sevenDay)
        }
    }

    private func limitRow(_ title: String, _ window: LimitWindow?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(window.map { "\(Int($0.usedPercentage.rounded()))%" } ?? "—")
            }
            .font(.subheadline)
            ProgressView(value: min(window?.usedPercentage ?? 0, 100), total: 100)
            if let window {
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    Text("resets in \(Fmt.countdown(to: window.resetsAt, now: tl.date)) · \(Fmt.resetClock(window.resetsAt))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text("waiting for an active session")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Toggle("Show status text", isOn: $showStatus)
            Toggle("Show timer", isOn: $showTimer).disabled(!showStatus)

            Divider()

            Button {
                openWindow(id: "dashboard")
            } label: {
                Label("Open Dashboard", systemImage: "chart.xyaxis.line")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("Quit \(AppInfo.name)", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .toggleStyle(.switch)
        .buttonStyle(.plain)
        .controlSize(.small)
    }
}
