import Foundation

/// Minimal Discord Rich Presence (IPC) client. Connects to Discord's local
/// socket and publishes the current agent activity — project, provider, model
/// (shown on hover) and live token usage. Off by default.
///
/// To show the Claude/Codex logos you must create a Discord Application
/// (discord.com/developers), upload Rich Presence art assets named `claude`,
/// `codex` and `anthrocite`, and paste its Application ID in Settings.
final class DiscordPresence {
    static let shared = DiscordPresence()

    /// The official Anthrocite Discord application (hosts the logo/claude/codex
    /// art assets), used unless the user overrides it in Settings.
    static let officialAppID = "1519158752622678136"

    struct Activity: Equatable {
        var details: String        // line 1 (project)
        var state: String          // line 2 (status · tokens)
        var largeImage: String     // big image asset key (logo)
        var largeText: String      // big image hover text
        var smallImage: String?    // small provider badge (claude/codex)
        var smallText: String?     // small image hover text (model name)
        var start: Int?            // epoch seconds, for the elapsed timer
    }

    private let queue = DispatchQueue(label: "app.anthrocite.discord")
    private var fd: Int32 = -1
    private var handshaken = false
    private var appID = ""
    private var enabled = false
    private var lastSent: Activity?
    private var lastConnectAttempt = Date.distantPast

    // MARK: Public API (called from the main actor)

    func configure(enabled: Bool, appID: String) {
        queue.async {
            let changed = self.enabled != enabled || self.appID != appID
            self.enabled = enabled
            self.appID = appID.trimmingCharacters(in: .whitespaces)
            if !enabled || self.appID.isEmpty {
                self.clearAndDisconnect()
            } else if changed {
                self.disconnect()          // reconnect with the new id next refresh
                self.lastSent = nil
            }
        }
    }

    func set(_ activity: Activity?) {
        queue.async {
            guard self.enabled, !self.appID.isEmpty else { return }
            guard activity != self.lastSent else { return }
            self.lastSent = activity
            self.ensureConnected()
            guard self.handshaken else { return }
            if let activity {
                _ = self.send(op: 1, self.frame(for: activity))
            } else {
                _ = self.send(op: 1, self.clearFrame())
            }
        }
    }

    // MARK: Connection

    private func ensureConnected() {
        guard fd < 0 else { return }
        // Don't hammer the socket when Discord isn't running.
        guard Date().timeIntervalSince(lastConnectAttempt) > 10 else { return }
        lastConnectAttempt = Date()

        let base = ProcessInfo.processInfo.environment["TMPDIR"] ?? "/tmp/"
        for i in 0..<10 {
            let path = base + "discord-ipc-\(i)"
            guard let socket = Self.openSocket(path: path) else { continue }
            fd = socket
            if send(op: 0, ["v": 1, "client_id": appID]), readDrain() {
                handshaken = true
                return
            }
            disconnect()
        }
    }

    private func disconnect() {
        if fd >= 0 { close(fd) }
        fd = -1
        handshaken = false
    }

    private func clearAndDisconnect() {
        if handshaken { _ = send(op: 1, clearFrame()) }
        lastSent = nil
        disconnect()
    }

    // MARK: Frames

    private func frame(for a: Activity) -> [String: Any] {
        var assets: [String: Any] = ["large_image": a.largeImage, "large_text": a.largeText]
        if let small = a.smallImage { assets["small_image"] = small }
        if let smallText = a.smallText { assets["small_text"] = smallText }
        var activity: [String: Any] = ["details": a.details, "state": a.state, "assets": assets]
        if let start = a.start { activity["timestamps"] = ["start": start] }
        return ["cmd": "SET_ACTIVITY", "nonce": UUID().uuidString,
                "args": ["pid": ProcessInfo.processInfo.processIdentifier, "activity": activity]]
    }

    private func clearFrame() -> [String: Any] {
        ["cmd": "SET_ACTIVITY", "nonce": UUID().uuidString,
         "args": ["pid": ProcessInfo.processInfo.processIdentifier]]   // omit activity = clear
    }

    // MARK: Socket I/O

    private func send(op: UInt32, _ obj: [String: Any]) -> Bool {
        guard fd >= 0, let json = try? JSONSerialization.data(withJSONObject: obj) else { return false }
        var header = Data(count: 8)
        header.withUnsafeMutableBytes { raw in
            raw.storeBytes(of: op.littleEndian, toByteOffset: 0, as: UInt32.self)
            raw.storeBytes(of: UInt32(json.count).littleEndian, toByteOffset: 4, as: UInt32.self)
        }
        let payload = header + json
        let ok = payload.withUnsafeBytes { raw -> Bool in
            var sent = 0
            let total = raw.count
            while sent < total {
                let n = write(fd, raw.baseAddress!.advanced(by: sent), total - sent)
                if n <= 0 { return false }
                sent += n
            }
            return true
        }
        if !ok { disconnect() }
        return ok
    }

    /// Read and discard whatever Discord sent (the READY frame, ack frames).
    @discardableResult
    private func readDrain() -> Bool {
        guard fd >= 0 else { return false }
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = read(fd, &buf, buf.count)
        return n > 0
    }

    private static func openSocket(path: String) -> Int32? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8)
        let cap = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count < cap else { close(fd); return nil }
        withUnsafeMutablePointer(to: &addr.sun_path) {
            $0.withMemoryRebound(to: UInt8.self, capacity: cap) { dst in
                for (i, b) in pathBytes.enumerated() { dst[i] = b }
                dst[pathBytes.count] = 0
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let r = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, len) }
        }
        guard r == 0 else { close(fd); return nil }
        return fd
    }
}
