import Foundation

/// Opt-in leaderboard client. Shares ONLY an anonymous device id, per-model
/// token totals, an optional display name and the app version — never projects,
/// paths, costs or any personal data. Off by default.
///
/// The backend (Cloudflare Workers + D1) isn't live yet, so `endpoint` is empty
/// and `submit` is a no-op; the payload shape below is what it will send.
enum Leaderboard {
    /// Empty until the Workers backend exists. (e.g. https://api.anthrocite.app/usage)
    static let endpoint = ""

    static var optedIn: Bool { UserDefaults.standard.bool(forKey: Prefs.leaderboardKey) }
    static var displayName: String {
        (UserDefaults.standard.string(forKey: Prefs.leaderboardNameKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    struct Payload: Codable {
        var id: String                 // anonymous device hash
        var name: String               // optional display name ("" = anonymous)
        var models: [String: Int]      // model id -> total tokens
        var version: String
    }

    static func payload(from index: AggregateIndex) -> Payload {
        var models: [String: Int] = [:]
        for (key, counts) in index.total.byModel {
            models[ModelKey.model(key), default: 0] += counts.total
        }
        return Payload(id: Identity.anonID, name: displayName, models: models, version: AppInfo.version)
    }

    /// Submits the payload when opted in and a backend is configured. No-op today.
    static func submitIfOptedIn(_ index: AggregateIndex) {
        guard optedIn, let url = URL(string: endpoint), !endpoint.isEmpty else { return }
        guard let body = try? JSONEncoder().encode(payload(from: index)) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        URLSession.shared.dataTask(with: req).resume()
    }
}
