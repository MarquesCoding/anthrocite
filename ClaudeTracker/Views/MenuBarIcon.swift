import AppKit

/// Builds the 16pt status-bar image. Uses a neutral SF Symbol (no third-party
/// branding); the System accent renders as a template (auto black/white),
/// Orange tints it. TODO: replace with an original Anthrocite mark.
enum MenuBarIcon {
    static func image(accent: AccentChoice) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let base = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent",
                           accessibilityDescription: "Anthrocite")?
            .withSymbolConfiguration(config) ?? NSImage()
        switch accent {
        case .system:
            base.isTemplate = true
            return base
        case .orange:
            return tinted(base, color: NSColor(red: 0.85, green: 0.467, blue: 0.337, alpha: 1))
        }
    }

    private static func tinted(_ image: NSImage, color: NSColor) -> NSImage {
        let out = NSImage(size: image.size)
        out.lockFocus()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver, fraction: 1)
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        out.unlockFocus()
        out.isTemplate = false
        return out
    }
}
