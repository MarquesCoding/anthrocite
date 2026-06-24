import SwiftUI

enum DashboardPane: String, CaseIterable, Identifiable, Hashable {
    case overview = "Overview"
    case projects = "Projects"
    case models = "Models"
    case sessions = "Sessions"
    case compare = "Compare"
    case general = "Settings"
    case pricing = "Rates"
    case about = "About"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "chart.xyaxis.line"
        case .projects: return "folder"
        case .models: return "cpu"
        case .sessions: return "clock.arrow.circlepath"
        case .compare: return "chart.bar.xaxis"
        case .general: return "gearshape"
        case .pricing: return "dollarsign.circle"
        case .about: return "info.circle"
        }
    }
    static let usage: [DashboardPane] = [.overview, .projects, .models, .sessions, .compare]
    static let app: [DashboardPane] = [.general, .pricing, .about]
}

/// Shared so the menu bar can open the dashboard directly to a pane.
@MainActor
final class Navigation: ObservableObject {
    static let shared = Navigation()
    @Published var pane: DashboardPane = .overview
}
