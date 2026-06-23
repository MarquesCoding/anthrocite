import SwiftUI
import AppKit

enum Scope: String, CaseIterable, Identifiable {
    case today = "Today", session = "Session", total = "Total"
    var id: String { rawValue }
}

/// AppKit segmented control (works inside an NSMenu's tracking run loop).
struct ScopeSelector: NSViewRepresentable {
    @Binding var scope: Scope
    func makeNSView(context: Context) -> NSSegmentedControl {
        let c = NSSegmentedControl(labels: Scope.allCases.map(\.rawValue),
                                   trackingMode: .selectOne,
                                   target: context.coordinator,
                                   action: #selector(Coordinator.changed(_:)))
        c.segmentDistribution = .fillEqually
        c.selectedSegment = Scope.allCases.firstIndex(of: scope) ?? 0
        return c
    }
    func updateNSView(_ c: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        c.selectedSegment = Scope.allCases.firstIndex(of: scope) ?? 0
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject {
        var parent: ScopeSelector
        init(_ p: ScopeSelector) { parent = p }
        @objc func changed(_ s: NSSegmentedControl) {
            let i = s.selectedSegment
            if i >= 0, i < Scope.allCases.count { parent.scope = Scope.allCases[i] }
        }
    }
}

/// Display-only content embedded in the native NSMenu (system draws the chrome).
struct MenuContentView: View {
    @ObservedObject var usage: UsageStore
    @ObservedObject var status: StatusStore
    @ObservedObject var pricing: PricingStore
    @AppStorage(Prefs.scopeKey) private var scopeRaw = Scope.today.rawValue

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
        VStack(alignment: .leading, spacing: 0) {
            if !status.sessions.isEmpty {
                sessionsSection.modifier(Inset())
                Divider().padding(.vertical, 8)
            }
            usageSection.modifier(Inset())
            Divider().padding(.vertical, 8)
            limitsSection.modifier(Inset())
        }
        .padding(.vertical, 6)
        .frame(width: 290)
        .captureSceneActions()
    }

    private var sessionsSection: some View {
        let claude = status.sessions.filter { !$0.isCodex }
        let codex = status.sessions.filter { $0.isCodex }
        return VStack(alignment: .leading, spacing: 12) {
            if !claude.isEmpty { providerGroup("Claude Code", claude) }
            if !codex.isEmpty { providerGroup("Codex", codex) }
        }
    }

    private func providerGroup(_ title: String, _ rows: [LiveSession]) -> some View {
        let working = rows.filter(\.isWorking).count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                if working > 0 {
                    Text("\(working) working").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            ForEach(rows) { sessionRow($0) }
        }
    }
    private func sessionRow(_ s: LiveSession) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Circle().fill(s.isWorking ? Color.green : Color.secondary.opacity(0.4)).frame(width: 6, height: 6)
                Text(s.project).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 8)
                statusLabel(s)
            }
            if let ctx = s.context {
                ProgressView(value: min(ctx.usedPercentage, 100), total: 100)
                Text("\(Fmt.tokens(ctx.usedTokens)) of \(Fmt.tokens(ctx.windowSize)) · \(Int(ctx.usedPercentage.rounded()))% context")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
    }
    @ViewBuilder private func statusLabel(_ s: LiveSession) -> some View {
        if s.isWorking, let since = s.activeSince {
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                Text("\(s.statusText) \(max(0, Int(tl.date.timeIntervalSince(since))))s")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        } else {
            Text("idle").font(.system(size: 11)).foregroundStyle(.tertiary)
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            ScopeSelector(scope: Binding(get: { scope }, set: { scopeRaw = $0.rawValue })).frame(height: 22)
            row("Tokens", Fmt.tokens(breakdown.totalTokens), bold: true)
            row("Cost", costString, bold: true)
            let c = breakdown.combined
            if c.total > 0 {
                row("Input", Fmt.tokens(c.input))
                row("Output", Fmt.tokens(c.output))
                row("Cache write", Fmt.tokens(c.cacheWrite))
                row("Cache read", Fmt.tokens(c.cacheRead))
            }
        }
    }

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Limits").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            limitRow("5-Hour Session", status.fiveHour)
            limitRow("Weekly", status.sevenDay)
        }
    }
    private func limitRow(_ title: String, _ window: LimitWindow?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.system(size: 13))
                Spacer()
                Text(window.map { "\(Int($0.usedPercentage.rounded()))%" } ?? "—").font(.system(size: 13))
            }
            ProgressView(value: min(window?.usedPercentage ?? 0, 100), total: 100)
            if let window {
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    Text("resets in \(Fmt.countdown(to: window.resetsAt, now: tl.date)) · \(Fmt.resetClock(window.resetsAt))")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            } else {
                Text("waiting for an active session").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
    }

    private func row(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.system(size: bold ? 13 : 12, weight: bold ? .medium : .regular))
    }
}

private struct Inset: ViewModifier {
    func body(content: Content) -> some View { content.padding(.horizontal, 14).padding(.vertical, 4) }
}
