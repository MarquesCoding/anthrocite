import SwiftUI
import ServiceManagement

/// Launch-at-login via the modern ServiceManagement API.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("LoginItem toggle failed: \(error)")
        }
    }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case system = "System"
    case orange = "Orange"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .system: return .primary
        case .orange: return Color(red: 0.85, green: 0.467, blue: 0.337) // Claude #D97757
        }
    }
}

/// Persisted UI preferences, shared between the menu-bar label and the dropdown.
enum Prefs {
    static let iconKey = "iconChoice"
    static let accentKey = "accentChoice"
    static let showTimerKey = "showTimer"
    static let showStatusKey = "showStatusText"
    static let scopeKey = "usageScope"
}
