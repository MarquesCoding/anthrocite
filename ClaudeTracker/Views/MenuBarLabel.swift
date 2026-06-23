import SwiftUI

/// The menu-bar label: icon + a compact live status (verb, or "N working").
struct MenuBarLabel: View {
    @ObservedObject var status: StatusStore
    @AppStorage(Prefs.showStatusKey) private var showStatus = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
            if showStatus, let title = menuTitle {
                Text(title)
            }
        }
    }

    private var menuTitle: String? {
        let working = status.workingSessions
        switch working.count {
        case 0: return nil
        case 1: return working[0].statusText
        default: return "\(working.count) working"
        }
    }
}
