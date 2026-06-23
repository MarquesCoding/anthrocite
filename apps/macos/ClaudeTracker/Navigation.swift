import SwiftUI

enum DashboardPane: String, CaseIterable, Identifiable, Hashable {
    case overview = "Overview"
    case projects = "Projects"
    case models = "Models"
    case general = "General"
    case pricing = "Pricing"
    case about = "About"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "chart.xyaxis.line"
        case .projects: return "folder"
        case .models: return "cpu"
        case .general: return "gearshape"
        case .pricing: return "dollarsign.circle"
        case .about: return "info.circle"
        }
    }
    static let usage: [DashboardPane] = [.overview, .projects, .models]
    static let app: [DashboardPane] = [.general, .pricing, .about]
}

/// Shared so the menu bar can open the dashboard directly to a pane.
@MainActor
final class Navigation: ObservableObject {
    static let shared = Navigation()
    @Published var pane: DashboardPane = .overview
}
