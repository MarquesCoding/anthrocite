import AppKit

/// Checks the GitHub Releases API for a newer version and, on request, downloads
/// the signed DMG, swaps the running .app bundle in place, and relaunches.
/// No external dependency (Sparkle) — the release pipeline already ships a DMG.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case downloading
        case failed(String)
    }

    struct Release: Equatable {
        let version: String      // normalised, e.g. "0.1.2"
        let tag: String          // raw tag, e.g. "v0.1.2"
        let dmgURL: URL
        let pageURL: URL
        let notes: String
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var latest: Release?

    private let apiURL = URL(string: "https://api.github.com/repos/MarquesCoding/anthrocite/releases/latest")!
    private let lastCheckKey = "lastUpdateCheck"

    /// Quietly check at most once a day on launch.
    func checkOnLaunch() {
        let last = UserDefaults.standard.double(forKey: lastCheckKey)
        guard Date().timeIntervalSince1970 - last > 86_400 else { return }
        Task { await check(userInitiated: false) }
    }

    func check(userInitiated: Bool) async {
        if case .checking = state { return }
        if case .downloading = state { return }
        state = .checking
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)

        do {
            var req = URLRequest(url: apiURL)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue(AppInfo.name, forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = obj["tag_name"] as? String else {
                throw Err.parse
            }
            let assets = obj["assets"] as? [[String: Any]] ?? []
            guard let dmg = assets.lazy
                .compactMap({ $0["browser_download_url"] as? String })
                .first(where: { $0.lowercased().hasSuffix(".dmg") })
                .flatMap(URL.init(string:)) else { throw Err.noAsset }

            let release = Release(
                version: Self.normalise(tag),
                tag: tag,
                dmgURL: dmg,
                pageURL: (obj["html_url"] as? String).flatMap(URL.init(string:)) ?? AppInfo.githubURL,
                notes: (obj["body"] as? String) ?? "")

            latest = release
            if Self.isNewer(release.version, than: AppInfo.version) {
                state = .available(version: release.version)
            } else {
                state = .upToDate
            }
        } catch {
            state = userInitiated ? .failed(friendly(error)) : .idle
        }
    }

    /// Download the DMG, swap the bundle, and relaunch.
    func downloadAndInstall() async {
        guard let release = latest else { return }
        state = .downloading
        do {
            var req = URLRequest(url: release.dmgURL)
            req.setValue(AppInfo.name, forHTTPHeaderField: "User-Agent")
            let (tmp, _) = try await URLSession.shared.download(for: req)
            let dmg = tmp.deletingLastPathComponent().appending(path: "Anthrocite-update.dmg")
            try? FileManager.default.removeItem(at: dmg)
            try FileManager.default.moveItem(at: tmp, to: dmg)
            try installFromDMG(dmg)
            // installFromDMG relaunches via a detached helper, so we quit.
            (NSApp.delegate as? AppDelegate)?.forceQuit()
            NSApp.terminate(nil)
        } catch {
            state = .failed(friendly(error))
        }
    }

    // MARK: - Install

    private func installFromDMG(_ dmg: URL) throws {
        let mount = try run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-quiet", dmg.path,
                                                 "-mountpoint", NSTemporaryDirectory() + "anthrocite-mnt"])
        _ = mount
        let mnt = NSTemporaryDirectory() + "anthrocite-mnt"
        defer { _ = try? run("/usr/bin/hdiutil", ["detach", "-quiet", mnt]) }

        let app = try FileManager.default.contentsOfDirectory(atPath: mnt)
            .first { $0.hasSuffix(".app") }
        guard let app else { throw Err.noApp }
        let src = mnt + "/" + app

        // Stage a copy off the disk image so we can detach before swapping.
        let staged = NSTemporaryDirectory() + "Anthrocite-new.app"
        try? FileManager.default.removeItem(atPath: staged)
        _ = try run("/usr/bin/ditto", [src, staged])

        let dest = Bundle.main.bundleURL.path
        let pid = ProcessInfo.processInfo.processIdentifier
        // Wait for us to quit, replace the bundle, clear quarantine, relaunch.
        let script = """
        #!/bin/sh
        while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.3; done
        /usr/bin/ditto "\(staged)" "\(dest)"
        /usr/bin/xattr -dr com.apple.quarantine "\(dest)" 2>/dev/null
        /bin/rm -rf "\(staged)"
        /usr/bin/open "\(dest)"
        """
        let scriptURL = URL(filePath: NSTemporaryDirectory() + "anthrocite-update.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let helper = Process()
        helper.executableURL = URL(filePath: "/bin/sh")
        helper.arguments = [scriptURL.path]
        try helper.run()   // detached; runs after we terminate
    }

    @discardableResult
    private func run(_ launchPath: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(filePath: launchPath)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        try p.run()
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard p.terminationStatus == 0 else { throw Err.process(launchPath) }
        return out
    }

    // MARK: - Version compare

    private static func normalise(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// Numeric, component-wise semver comparison ("0.1.10" > "0.1.2").
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private enum Err: Error { case parse, noAsset, noApp, process(String) }
    private func friendly(_ error: Error) -> String {
        if error is Err { return "Couldn't find a downloadable release." }
        return (error as NSError).localizedDescription
    }
}
