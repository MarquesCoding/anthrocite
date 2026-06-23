import Foundation

/// Single source of truth for branding/metadata, so a rename is one edit here
/// (plus the Xcode product name / bundle id).
enum AppInfo {
    static let name = "Anthrocite"
    static let tagline = "Usage & status for your AI coding agents"
    static let website = URL(string: "https://anthrocite.app")!
    static let githubURL = URL(string: "https://github.com/MarquesCoding/anthrocite")!
    static let license = "MIT License"

    struct Credit: Identifiable {
        let id = UUID()
        let name: String
        let handle: String
        let role: String
        let url: URL
        /// GitHub serves the user's avatar directly at github.com/<user>.png.
        var avatarURL: URL { URL(string: "https://github.com/\(url.lastPathComponent).png?size=120")! }
    }

    static let credits: [Credit] = [
        Credit(name: "Marques", handle: "@MarquesCoding", role: "Creator & development",
               url: URL(string: "https://github.com/MarquesCoding")!),
        Credit(name: "dcm", handle: "@dcm_2610", role: "Design & ideas",
               url: URL(string: "https://github.com/dcm2610")!),
    ]

    static let acknowledgement = "Pricing data from LiteLLM."

    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
    static var build: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }
}
