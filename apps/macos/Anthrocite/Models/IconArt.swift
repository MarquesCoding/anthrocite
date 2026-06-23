import AppKit

/// Decodes the vendored base64 PNG frames (see `Vendor/`) into `NSImage`s once,
/// and styles a frame for the menu bar (sizing + template/tint, or full colour
/// for the crab). Frames are adapted from claude-status-bar (MIT, M. Cesanek).
enum IconArt {
    private static func decode(_ b64: [String]) -> [NSImage] {
        b64.compactMap { Data(base64Encoded: $0).flatMap(NSImage.init(data:)) }
    }

    static let spark: [NSImage] = decode(claudeSparkFramePNGs)
    static let crab: [NSImage] = decode(clawdCrabFramePNGs)
    static let claudeLogo: NSImage? = Data(base64Encoded: claudeLogoPNG).flatMap(NSImage.init(data:))

    /// Frames to cycle for a given style while working (empty for `.logo`).
    static func frames(for choice: IconChoice) -> [NSImage] {
        switch choice {
        case .logo:  return []
        case .spark: return spark
        case .crab:  return crab
        }
    }

    /// Size a frame to the menu bar and apply the right colour treatment:
    /// the crab keeps its pixel-art colours; masks become a template (so the
    /// system tints them) or are tinted with the accent colour.
    static func style(_ base: NSImage?, color: Bool, accent: AccentChoice) -> NSImage? {
        guard let base, let img = base.copy() as? NSImage else { return nil }
        let h: CGFloat = color ? 15 : 14
        let w = base.size.height > 0 ? h * (base.size.width / base.size.height) : h
        img.size = NSSize(width: w, height: h)

        if color {
            img.isTemplate = false
            return img
        }
        if accent == .orange {
            return tinted(img, NSColor(red: 0.85, green: 0.467, blue: 0.337, alpha: 1))
        }
        img.isTemplate = true   // adopt the menu-bar foreground colour
        return img
    }

    private static func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        let out = NSImage(size: image.size)
        out.lockFocus()
        let rect = NSRect(origin: .zero, size: image.size)
        image.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        out.unlockFocus()
        out.isTemplate = false
        return out
    }
}
