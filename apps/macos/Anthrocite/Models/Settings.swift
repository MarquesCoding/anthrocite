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

/// The menu-bar icon style. `logo` is Anthrocite's own neutral mark; the other
/// two are animated (frames cycled while an agent is working).
enum IconChoice: String, CaseIterable, Identifiable {
    case logo = "Anthrocite"
    case spark = "Claude"
    case crab = "Crab"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .logo:  return "Anthrocite"
        case .spark: return "Claude (animated)"
        case .crab:  return "Clawd crab (animated)"
        }
    }
    /// Whether this style cycles frames while an agent is working.
    var isAnimated: Bool { self != .logo }
    /// Crab frames are full-colour pixel art; the rest are tintable masks.
    var isColor: Bool { self == .crab }
}

/// How the limit-reset countdown is rendered in the dropdown.
enum CountdownFormat: String, CaseIterable, Identifiable {
    case ddhhmmss = "DD:HH:MM:SS"
    case hhmmss = "HH:MM:SS"
    case hhmm = "HH:MM"
    case dd = "DD"
    var id: String { rawValue }
}

/// Persisted UI preferences, shared between the menu-bar label and the dropdown.
enum Prefs {
    static let iconKey = "iconChoice"
    static let accentKey = "accentChoice"
    static let showTimerKey = "showTimer"
    static let showStatusKey = "showStatusText"
    static let scopeKey = "usageScope"
    static let soundKey = "playCompletionSound"
    static let countdownKey = "countdownFormat"
}
