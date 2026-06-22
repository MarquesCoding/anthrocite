import SwiftUI
import AppKit

/// An AppKit segmented control wrapped for SwiftUI. AppKit controls (unlike
/// SwiftUI ones) receive clicks inside an NSMenu's tracking run loop.
struct ScopeSelector: NSViewRepresentable {
    @Binding var scope: Scope

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: Scope.allCases.map(\.rawValue),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.changed(_:)))
        control.segmentDistribution = .fillEqually
        control.selectedSegment = Scope.allCases.firstIndex(of: scope) ?? 0
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        control.selectedSegment = Scope.allCases.firstIndex(of: scope) ?? 0
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: ScopeSelector
        init(_ parent: ScopeSelector) { self.parent = parent }
        @objc func changed(_ sender: NSSegmentedControl) {
            let i = sender.selectedSegment
            if i >= 0, i < Scope.allCases.count { parent.scope = Scope.allCases[i] }
        }
    }
}

/// Display-only content embedded as a custom view inside the native NSMenu.
/// It draws NO background — the system menu provides the material/blur/corners.
/// Toggles, version and quit live in real NSMenuItems; the scope tab bar is an
/// AppKit segmented control (works inside the menu).
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
        // The current session shows Claude Code's own exact cost; otherwise we
        // price each model with the fetched pricing table.
        if scope == .session, let real = status.primary?.costUSD { return Fmt.usd(real) }
        return Fmt.usd(breakdown.totalCost(pricing.table))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !status.sessions.isEmpty {
                sessionsSection
                rule
            }
            usageSection
            rule
            limitsSection
        }
        .padding(.horizontal, 14)
        .padding(.top, 1)
        .padding(.bottom, 5)
        .frame(width: 290, alignment: .leading)
    }

    private var rule: some View {
        Divider().padding(.vertical, 9)
    }

    // MARK: Sessions

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                SectionHeader(text: status.sessions.count == 1 ? "Session" : "Sessions")
                if status.workingCount > 0 {
                    Text("\(status.workingCount) working")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            ForEach(status.sessions) { sessionRow($0) }
        }
    }

    private func sessionRow(_ s: LiveSession) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Circle()
                    .fill(s.isWorking ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(s.project).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 8)
                sessionStatus(s)
            }
            if let ctx = s.context {
                ProgressBar(fraction: ctx.usedPercentage / 100)
                Text("\(Fmt.tokens(ctx.usedTokens)) of \(Fmt.tokens(ctx.windowSize)) · \(Int(ctx.usedPercentage.rounded()))% context")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func sessionStatus(_ s: LiveSession) -> some View {
        if s.isWorking, let since = s.activeSince {
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                Text("\(s.statusText) \(max(0, Int(tl.date.timeIntervalSince(since))))s")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        } else {
            Text("idle").font(.system(size: 11)).foregroundStyle(.tertiary)
        }
    }

    // MARK: Usage

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: "Usage")
            ScopeSelector(scope: Binding(get: { scope }, set: { scopeRaw = $0.rawValue }))
                .frame(height: 22)
            StatRow(label: "Tokens", value: Fmt.tokens(breakdown.totalTokens), emphasized: true)
            StatRow(label: "Cost", value: costString, emphasized: true)

            let combined = breakdown.combined
            if combined.total > 0 {
                VStack(spacing: 4) {
                    subRow("Input", combined.input)
                    subRow("Output", combined.output)
                    subRow("Cache write", combined.cacheWrite)
                    subRow("Cache read", combined.cacheRead)
                }
                let cachePct = Int((Double(combined.cacheRead) / Double(combined.total) * 100).rounded())
                Text("\(cachePct)% are cached context re-reads")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
    }

    private func subRow(_ label: String, _ n: Int) -> some View {
        HStack {
            Text(label).foregroundStyle(.tertiary)
            Spacer()
            Text(Fmt.tokens(n)).monospacedDigit().foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
    }

    // MARK: Limits

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(text: "Limits")
            LimitRow(title: "5-Hour Session", window: status.fiveHour)
            LimitRow(title: "Weekly", window: status.sevenDay)
        }
    }
}

enum Scope: String, CaseIterable, Identifiable {
    case today = "Today", session = "Session", total = "Total"
    var id: String { rawValue }
}
