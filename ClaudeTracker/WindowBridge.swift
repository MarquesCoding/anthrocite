import SwiftUI

/// Lets the AppKit menu open SwiftUI `Window`/`Settings` scenes. SwiftUI's
/// `openWindow`/`openSettings` actions are captured from scene-graph views into
/// this singleton, then invoked from `NSMenuItem` actions.
@MainActor
final class WindowBridge {
    static let shared = WindowBridge()
    var openWindowAction: ((String) -> Void)?
    var openSettingsAction: (() -> Void)?

    func open(_ id: String) { openWindowAction?(id) }
    func openSettings() { openSettingsAction?() }
}

extension View {
    /// Capture the scene's open actions so the AppKit menu can drive them.
    func captureSceneActions() -> some View { modifier(CaptureSceneActions()) }
}

private struct CaptureSceneActions: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content.onAppear {
            WindowBridge.shared.openWindowAction = { openWindow(id: $0) }
            WindowBridge.shared.openSettingsAction = { openSettings() }
        }
    }
}
