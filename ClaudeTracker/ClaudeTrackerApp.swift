import SwiftUI

@main
struct AnthrociteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let stores = Stores.shared

    var body: some Scene {
        // Menu bar — works standalone, no window required.
        MenuBarExtra {
            MenuContentView(usage: stores.usage, status: stores.status, pricing: stores.pricing)
        } label: {
            MenuBarLabel(status: stores.status)
        }
        .menuBarExtraStyle(.window)

        // Native macOS window scenes (Liquid Glass chrome).
        Window("\(AppInfo.name) Dashboard", id: "dashboard") {
            DashboardView(usage: stores.usage, pricing: stores.pricing)
                .scenePolicy()
        }
        .defaultSize(width: 900, height: 620)

        Settings {
            SettingsView(usage: stores.usage, pricing: stores.pricing)
                .scenePolicy()
        }
    }
}

/// While any real window is open, become a regular app (dock icon + window
/// management); drop back to a menu-bar agent when it closes.
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
