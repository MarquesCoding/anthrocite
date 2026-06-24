import Foundation
import IOKit
import CryptoKit

/// A stable, anonymous device identifier for the (opt-in) leaderboard. Derived
/// by hashing the hardware UUID with a salt — the raw UUID never leaves the Mac
/// and isn't stored, so what we share is an opaque token, not personal data.
enum Identity {
    static let anonID: String = {
        let raw = (hardwareUUID() ?? "anthrocite-unknown") + "::anthrocite-leaderboard-v1"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }()

    private static func hardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let cf = IORegistryEntryCreateCFProperty(
            service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0) else { return nil }
        return cf.takeRetainedValue() as? String
    }
}
