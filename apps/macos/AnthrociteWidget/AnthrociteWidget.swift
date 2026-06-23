import WidgetKit
import SwiftUI

// MARK: - Timeline

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), snapshot: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), snapshot: context.isPreview ? .placeholder : WidgetShared.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: Date(), snapshot: WidgetShared.load())
        // The app reloads us on real changes; this is just a safety refresh.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

@main
struct AnthrociteWidgetBundle: WidgetBundle {
    var body: some Widget { AnthrociteWidget() }
}

struct AnthrociteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.anthrocite.widget", provider: Provider()) { entry in
            WidgetView(snapshot: entry.snapshot)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Anthrocite")
        .description("Live status, usage, cost and limits for your AI coding agents.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        switch family {
        case .systemSmall: SmallWidget(s: snapshot)
        case .systemLarge: LargeWidget(s: snapshot)
        default:           MediumWidget(s: snapshot)
        }
    }
}

private struct Header: View {
    let working: Int
    var body: some View {
        HStack(spacing: 6) {
            Text("Anthrocite").font(.system(size: 12, weight: .semibold))
            Spacer()
            if working > 0 {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("\(working) working").font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                Text("idle").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
    }
}

private struct SmallWidget: View {
    let s: WidgetSnapshot
    var body: some View {
        // No wordmark here (it wraps at this width — the OS already labels the
        // widget); just a status line, the headline cost, and the 5-hour bar.
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Circle().fill(s.workingCount > 0 ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(s.workingCount > 0 ? "\(s.workingCount) working" : "idle")
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Text(WFmt.usd(s.todayCost)).font(.system(size: 30, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1)
            Text("\(WFmt.tokens(s.todayTokens)) today").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 0)
            if let f = s.fiveHour { LimitBar(title: "5h", limit: f, titleSize: 10, showReset: false) }
        }
    }
}

private struct MediumWidget: View {
    let s: WidgetSnapshot
    var body: some View {
        // Reset lines are dropped here (they overflowed) — both limits still show.
        VStack(alignment: .leading, spacing: 0) {
            Header(working: s.workingCount)
            Spacer(minLength: 8)
            HStack(spacing: 14) {
                Metric(title: "Today", value: WFmt.usd(s.todayCost), sub: WFmt.tokens(s.todayTokens))
                Metric(title: "All-time", value: WFmt.usd(s.totalCost), sub: WFmt.tokens(s.totalTokens))
            }
            Spacer(minLength: 10)
            VStack(spacing: 9) {
                if let f = s.fiveHour { LimitBar(title: "5-hour", limit: f, showReset: false) }
                if let w = s.sevenDay { LimitBar(title: "Weekly", limit: w, showReset: false) }
            }
        }
    }
}

private struct LargeWidget: View {
    let s: WidgetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Header(working: s.workingCount)
            HStack(spacing: 14) {
                Metric(title: "Today", value: WFmt.usd(s.todayCost), sub: WFmt.tokens(s.todayTokens))
                Metric(title: "All-time", value: WFmt.usd(s.totalCost), sub: WFmt.tokens(s.totalTokens))
            }
            VStack(spacing: 7) {
                if let f = s.fiveHour { LimitBar(title: "5-hour", limit: f) }
                if let w = s.sevenDay { LimitBar(title: "Weekly", limit: w) }
            }
            if !s.sessions.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(s.sessions.prefix(4)) { SessionRow(session: $0) }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Pieces

private struct Metric: View {
    let title: String; let value: String; let sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 20, weight: .bold)).minimumScaleFactor(0.6).lineLimit(1)
            Text("\(sub) tokens").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Proportional bar — the stock ProgressView track renders as a bright full
/// width line on the dark widget, which reads as "100%".
private struct WBar: View {
    let pct: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.15))
                Capsule().fill(Color.green)
                    .frame(width: max(4, geo.size.width * CGFloat(min(max(pct, 0), 100)) / 100))
            }
        }
        .frame(height: 5)
    }
}

private struct LimitBar: View {
    let title: String
    let limit: WidgetLimit
    var titleSize: CGFloat = 12
    var showReset = true
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: titleSize)).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(limit.usedPercentage.rounded()))%").font(.system(size: titleSize, weight: .medium))
            }
            WBar(pct: limit.usedPercentage)
            if showReset {
                Text("resets ").font(.system(size: 10)).foregroundStyle(.tertiary)
                    + Text(limit.resetsAt, style: .relative).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
    }
}

private struct SessionRow: View {
    let session: WidgetSession
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(session.isWorking ? Color.green : Color.secondary.opacity(0.4)).frame(width: 6, height: 6)
            Text(session.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
            Spacer(minLength: 6)
            Text(session.status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}
