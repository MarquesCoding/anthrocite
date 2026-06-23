import SwiftUI
import AppKit

/// Minimal delegate: start the shared stores at launch and run as a menu-bar
/// agent (no dock icon) until a window opens.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Stores.shared.start()
        NSApp.setActivationPolicy(.accessory)
    }
}
