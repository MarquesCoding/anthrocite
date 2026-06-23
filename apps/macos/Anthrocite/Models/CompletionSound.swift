import AppKit

/// Plays a short chime when an agent finishes a response, gated by the
/// "Play sound on completion" preference. Backed by the bundled job-done.mp3.
enum CompletionSound {
    private static let sound: NSSound? = {
        guard let url = Bundle.main.url(forResource: "job-done", withExtension: "mp3") else { return nil }
        return NSSound(contentsOf: url, byReference: true)
    }()

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: Prefs.soundKey) }

    static func play() {
        guard isEnabled, let sound else { return }
        if sound.isPlaying { sound.stop() }
        sound.play()
    }
}
