import SwiftUI

@main
struct ClaudeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Menu-bar agent; the real Settings window is shown by AppDelegate.
        Settings { EmptyView() }
    }
}
