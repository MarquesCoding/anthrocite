import SwiftUI

/// Lets the AppKit menu open SwiftUI `Window`/`Settings` scenes. SwiftUI's
/// `openWindow`/`openSettings` actions are captured from scene-graph views into
/// this singleton, then invoked from `NSMenuItem` actions.
@MainActor
final class WindowBridge {
    static let shared = WindowBridge()
    var openWindowAction: ((String) -> Void)?

    func open(_ id: String) { openWindowAction?(id) }
}

extension View {
    /// Capture the scene's openWindow action so the AppKit menu can drive it.
    func captureSceneActions() -> some View { modifier(CaptureSceneActions()) }
}

private struct CaptureSceneActions: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            WindowBridge.shared.openWindowAction = { openWindow(id: $0) }
        }
    }
}
