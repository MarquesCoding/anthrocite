import Foundation

/// Installs the two Claude Code integration pieces Anthrocite needs:
///  1. the statusLine bridge (writes per-session status into ~/.claude/anthrocite-status)
///  2. the SessionEnd hook (removes a session's file the moment its chat closes)
/// Runs once on first launch; idempotent and re-runnable from Settings.
enum HookInstaller {
    private static let installedVersionKey = "hooksInstalledVersion"
    private static let currentVersion = 1

    private static var claudeDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude", directoryHint: .isDirectory)
    }

    static func installIfNeeded() {
        guard UserDefaults.standard.integer(forKey: installedVersionKey) < currentVersion else { return }
        install()
        UserDefaults.standard.set(currentVersion, forKey: installedVersionKey)
    }

    /// True once our statusLine + SessionEnd hook are present in settings.json.
    static var isInstalled: Bool {
        guard let obj = settings() else { return false }
        let sl = ((obj["statusLine"] as? [String: Any])?["command"] as? String) ?? ""
        return sl.contains("anthrocite-statusline") && hasSessionEndHook(obj)
    }

    @discardableResult
    static func install() -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(at: claudeDir.appending(path: "anthrocite-status", directoryHint: .isDirectory),
                                withIntermediateDirectories: true)
        writeScript(statusLineScript, name: "anthrocite-statusline.sh")
        writeScript(sessionEndScript, name: "anthrocite-session-end.sh")
        return mergeSettings()
    }

    // MARK: - Files

    private static func writeScript(_ contents: String, name: String) {
        let url = claudeDir.appending(path: name)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        } catch {
            NSLog("HookInstaller: failed to write \(name): \(error)")
        }
    }

    private static func settings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: claudeDir.appending(path: "settings.json")) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func hasSessionEndHook(_ obj: [String: Any]) -> Bool {
        let hooks = obj["hooks"] as? [String: Any]
        let entries = hooks?["SessionEnd"] as? [[String: Any]] ?? []
        return entries.contains { entry in
            (entry["hooks"] as? [[String: Any]])?.contains {
                ($0["command"] as? String)?.contains("anthrocite-session-end") == true
            } == true
        }
    }

    /// Merge our entries into settings.json without clobbering the user's other
    /// hooks (e.g. PreToolUse). Replaces statusLine (we need ours for data).
    @discardableResult
    private static func mergeSettings() -> Bool {
        let url = claudeDir.appending(path: "settings.json")
        var json = settings() ?? [:]

        json["statusLine"] = ["type": "command", "command": "$HOME/.claude/anthrocite-statusline.sh"]

        var hooks = json["hooks"] as? [String: Any] ?? [:]
        if !hasSessionEndHook(json) {
            var sessionEnd = hooks["SessionEnd"] as? [[String: Any]] ?? []
            sessionEnd.append(["hooks": [["type": "command", "command": "$HOME/.claude/anthrocite-session-end.sh"]]])
            hooks["SessionEnd"] = sessionEnd
        }
        json["hooks"] = hooks

        guard let data = try? JSONSerialization.data(
            withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return false }
        do { try data.write(to: url, options: .atomic); return true }
        catch { NSLog("HookInstaller: failed to write settings.json: \(error)"); return false }
    }

    // MARK: - Bundled script contents

    private static let statusLineScript = #"""
    #!/bin/sh
    # Anthrocite statusLine bridge (installed by Anthrocite.app).
    input=$(cat)
    dir="$HOME/.claude/anthrocite-status"
    mkdir -p "$dir" 2>/dev/null

    sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty' 2>/dev/null)
    [ -z "$sid" ] && sid="unknown"
    tmp="$dir/.$sid.tmp"
    printf '%s' "$input" > "$tmp" 2>/dev/null && mv "$tmp" "$dir/$sid.json" 2>/dev/null

    printf '%s' "$input" | /usr/bin/jq -r '
      [ (.model.display_name // empty),
        (if .rate_limits.five_hour.used_percentage != null
           then "5h \(.rate_limits.five_hour.used_percentage | floor)%" else empty end),
        (if .rate_limits.seven_day.used_percentage != null
           then "7d \(.rate_limits.seven_day.used_percentage | floor)%" else empty end)
      ] | join("  ·  ")' 2>/dev/null
    """#

    private static let sessionEndScript = #"""
    #!/bin/sh
    # Anthrocite SessionEnd hook (installed by Anthrocite.app).
    input=$(cat)
    sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty' 2>/dev/null)
    [ -n "$sid" ] && rm -f "$HOME/.claude/anthrocite-status/$sid.json"
    exit 0
    """#
}
