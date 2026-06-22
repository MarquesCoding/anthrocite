import Foundation

/// Single source of truth for branding/metadata, so a rename is one edit here
/// (plus the Xcode product name / bundle id).
enum AppInfo {
    static let name = "Anthrocite"
    static let tagline = "Usage & status for your AI coding agents"
    static let website = URL(string: "https://anthrocite.app")!
    static let githubURL = URL(string: "https://github.com/MarquesCoding/anthrocite")!
    static let license = "Proprietary"

    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
    static var build: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }
}
