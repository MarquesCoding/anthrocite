import SwiftUI

@main
struct AnthrociteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let stores = Stores.shared

    var body: some Scene {
        // Native window scenes (Liquid Glass chrome). The menu bar itself is an
        // AppKit NSStatusItem owned by AppDelegate — it works with no window open.
        Window("\(AppInfo.name) Dashboard", id: "dashboard") {
            DashboardView(usage: stores.usage, pricing: stores.pricing)
                .captureSceneActions()
                .scenePolicy()
        }
        .defaultSize(width: 900, height: 620)

        Settings {
            SettingsView(usage: stores.usage, pricing: stores.pricing)
                .captureSceneActions()
                .scenePolicy()
        }
    }
}

/// Become a regular app (dock icon) while a window is open; drop back to a
/// menu-bar agent when the last window closes — the menu bar always stays.
private struct ScenePolicy: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
            .onDisappear {
                let stillOpen = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
                if !stillOpen { NSApp.setActivationPolicy(.accessory) }
            }
    }
}

private extension View {
    func scenePolicy() -> some View { modifier(ScenePolicy()) }
}
