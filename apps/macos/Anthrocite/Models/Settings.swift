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
    static let showCostKey = "showCost"
    static let discordKey = "discordRichPresence"
    static let discordAppIDKey = "discordAppID"
    static let alertsKey = "alertsEnabled"
    static let limitThresholdKey = "alertLimitThreshold"
    static let spendThresholdKey = "alertSpendThreshold"
    static let menuMetricKey = "menuMetric"
    static let planKey = "claudePlan"
}

/// What the menu-bar label shows next to the icon.
enum MenuMetric: String, CaseIterable, Identifiable {
    case status = "Status"
    case costToday = "Today's cost"
    case fiveHour = "5-hour limit"
    var id: String { rawValue }
}

/// Time window for the dashboard's usage views.
enum TimeRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "7 days"
    case month = "30 days"
    case all = "All"
    var id: String { rawValue }
    /// Number of days, or nil for all-time.
    var days: Int? {
        switch self {
        case .today: return 1
        case .week:  return 7
        case .month: return 30
        case .all:   return nil
        }
    }
}

/// The user's Claude subscription, used to frame limits. Informational.
enum ClaudePlan: String, CaseIterable, Identifiable {
    case unspecified = "Not set"
    case pro = "Pro"
    case max5 = "Max 5×"
    case max20 = "Max 20×"
    case api = "API / Console"
    var id: String { rawValue }
}
