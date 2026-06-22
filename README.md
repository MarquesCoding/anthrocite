# Anthrocite

**Usage & status for your AI coding agents — in your macOS menu bar.**

Anthrocite shows what your coding agent (Claude Code today; Codex/ChatGPT planned)
is doing right now and how much you're using — live status, tokens, cost, context
window, and real rate limits — across every concurrent session, plus a full
dashboard of trends by project and model.

> Private, proprietary. macOS 15+ (Sequoia and later), Apple silicon & Intel.
> Paid: **$1.99** one-time — free for students (email to verify).

## Status

Working today:
- **Menu bar** — live status verb + timer ("Reading 9s", "N working").
- **Multi-session** — every concurrent session, per-project status + context %.
- **Real limits** — 5-hour & weekly used % with exact reset times.
- **Usage & cost** — Today / Session / All-time, per-model exact pricing
  (LiteLLM dataset; current session uses Claude Code's own cost).
- **Native menu** — system-drawn `NSMenu`, AppKit segmented scope selector.
- **Settings window** — launch at login, accent, toggles, pricing, about.

Planned (see `docs/` once added):
- Licensing + activation (paid), landing page, payments.
- Full dashboard app: graphs of token usage, cost over time, top projects/models.
- Codex (ChatGPT) provider support.

## Architecture

- **App** — SwiftUI + AppKit menu-bar agent (`ClaudeTracker.xcodeproj`, product
  `Anthrocite.app`). Models in `ClaudeTracker/Models`, views in `ClaudeTracker/Views`.
- **Data sources** (all local):
  1. Token/cost from `~/.claude/projects/**/*.jsonl` (incremental index).
  2. Live status/context/limits from a **statusLine bridge**
     (`scripts/anthrocite-statusline.sh`) that writes per-session JSON to
     `~/.claude/anthrocite-status/`.

## Build

```sh
xcodebuild -project ClaudeTracker.xcodeproj -scheme ClaudeTracker -configuration Release build
```

## Setup (statusLine bridge)

Add to `~/.claude/settings.json`:

```json
{ "statusLine": { "type": "command", "command": "$HOME/.claude/anthrocite-statusline.sh" } }
```

and install `scripts/anthrocite-statusline.sh` to `~/.claude/` (`chmod +x`).

## License

Proprietary — see [LICENSE](LICENSE).
