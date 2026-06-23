import SwiftUI

// MARK: - Native-style menu primitives

/// A clickable menu row that mimics a native AppKit menu item: 13pt text, an
/// accent-coloured rounded highlight on hover, optional leading checkmark and
/// trailing keyboard shortcut.
struct MenuRow: View {
    var title: String
    var shortcut: String? = nil
    var checked: Bool? = nil
    var disabled: Bool = false
    var action: () -> Void = {}
    @State private var hover = false

    private var active: Bool { hover && !disabled }

    var body: some View {
        HStack(spacing: 6) {
            if checked != nil {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity((checked ?? false) ? 1 : 0)
                    .frame(width: 13)
            }
            Text(title)
            Spacer(minLength: 10)
            if let shortcut {
                Text(shortcut)
                    .foregroundStyle(active ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(disabled ? AnyShapeStyle(.tertiary)
                                  : (active ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)))
        .padding(.horizontal, 9)
        .frame(height: 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 5).fill(active ? Color.accentColor : .clear))
        .padding(.horizontal, 5)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { if !disabled { action() } }
    }
}

/// A native-looking menu separator.
struct MenuSeparator: View {
    var body: some View {
        Divider().padding(.horizontal, 12).padding(.vertical, 5)
    }
}

/// A small grey section label, like "Energy Mode" in system menus.
struct SectionHeader: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Data widgets

/// A thin, monochrome progress bar.
struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule()
                    .fill(Color.primary.opacity(0.55))
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 5)
    }
}

/// A rate-limit row: title + percentage, a bar, and the reset countdown.
struct LimitRow: View {
    let title: String
    let window: LimitWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Text(window.map { "\(Int($0.usedPercentage.rounded()))%" } ?? "—")
                    .monospacedDigit()
            }
            .font(.system(size: 13))

            ProgressBar(fraction: (window?.usedPercentage ?? 0) / 100)

            if let window {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text("resets in \(Fmt.countdown(to: window.resetsAt, now: ctx.date)) · \(Fmt.resetClock(window.resetsAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("waiting for an active session")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// A plain "label … value" line.
struct StatRow: View {
    let label: String
    let value: String
    var emphasized: Bool = false

    var body: some View {
        HStack {
            Text(label).foregroundStyle(emphasized ? .primary : .secondary)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.primary)
        }
        .font(.system(size: 13, weight: emphasized ? .medium : .regular))
    }
}
