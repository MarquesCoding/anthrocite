# Anthrocite

**Usage & status for your AI coding agents — in your macOS menu bar.**

Private monorepo (Turborepo + pnpm) containing the macOS app, the marketing
site, and the licensing API.

> Proprietary. Paid: **$1.99** one-time — free for students (email to verify).

## Structure

```
apps/
  macos/   Native macOS menu-bar app + dashboard (SwiftUI + AppKit, Xcode)
  web/     Marketing site / landing page (Vite + React + Tailwind)
  api/     Licensing API (Hono) — Polar webhooks + license validation
packages/  Shared code (TBD)
```

## Develop

```sh
pnpm install           # install JS workspaces
pnpm web               # run the landing page (Vite dev server)
pnpm api               # run the API (Hono)
pnpm build             # turbo build all JS apps
```

The macOS app builds with Xcode:

```sh
xcodebuild -project apps/macos/ClaudeTracker.xcodeproj \
  -scheme ClaudeTracker -configuration Release build
```

## The app

- **Live status** — what Claude is doing right now (Reading/Running/…); a timer
  in the menu bar.
- **Multi-session** — every concurrent session (CLI, VS Code, JetBrains) with
  per-project status + context.
- **Real limits** — 5-hour & weekly used % and exact resets, from Claude Code.
- **Exact cost** — per-model pricing (LiteLLM); current session uses Claude
  Code's own cost.
- **Dashboard** — native Swift Charts trends, projects & models.

Data is read locally from `~/.claude/projects/**/*.jsonl` and a per-session
status bridge (`apps/macos/scripts/anthrocite-statusline.sh`) — nothing leaves
your machine.

## License

Proprietary — see [LICENSE](LICENSE).
