import SwiftUI

/// First-run welcome shown as a sheet over the dashboard. Explains the app and
/// installs the Claude Code integration on the user's say-so (rather than
/// silently on launch).
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("onboardingShown") private var onboardingShown = false
    @State private var installed = HookInstaller.isInstalled

    private let points: [(String, String, String)] = [
        ("bolt.fill", "Live status", "See what every Claude Code, Codex and Gemini session is doing — in your menu bar."),
        ("gauge.with.dots.needle.67percent", "Real limits & cost", "Your actual 5-hour/weekly limits and exact per-model spend."),
        ("rectangle.3.group.fill", "Widgets & alerts", "Desktop widgets, threshold alerts and an optional Discord status."),
        ("lock.fill", "Totally private", "Everything is read locally from ~/.claude and ~/.codex — nothing leaves your Mac."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
                Text("Welcome to \(AppInfo.name)").font(.title.weight(.bold))
                Text(AppInfo.tagline).foregroundStyle(.secondary)
            }
            .padding(.top, 28).padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(points, id: \.1) { icon, title, body in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon).font(.title3).foregroundStyle(.tint).frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.headline)
                            Text(body).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)

            Spacer(minLength: 20)

            VStack(spacing: 10) {
                Button {
                    HookInstaller.install()
                    installed = HookInstaller.isInstalled
                    finish()
                } label: {
                    Text(installed ? "Get started" : "Install Claude Code integration & continue")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large).buttonStyle(.borderedProminent)

                Button("Skip for now") { finish() }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 30).padding(.bottom, 24)
        }
        .frame(width: 460, height: 540)
    }

    private func finish() {
        onboardingShown = true
        dismiss()
    }
}
