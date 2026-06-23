<p align="center">
  <img src="apps/web/public/icon.png" width="72" alt="Anthrocite" />
</p>

<h1 align="center">Anthrocite</h1>

<p align="center">
  Live usage, cost &amp; status for your AI coding agents — right in the macOS menu bar.
</p>

<p align="center">
  <strong>Free &amp; open source · macOS 15+ · MIT licensed</strong>
</p>

<p align="center">
  <a href="https://github.com/MarquesCoding/anthrocite/releases/latest/download/Anthrocite.dmg"><strong>Download for macOS</strong></a>
  ·
  <a href="https://anthrocite.app">anthrocite.app</a>
</p>

---

Anthrocite watches your local Claude Code and OpenAI Codex sessions and shows
what every agent is doing — live status, token usage, real cost and your actual
rate limits — without anything leaving your machine.

## Features

- **Live status** — what each agent is doing right now (Reading / Running /
  Editing / …) with a timer in the menu bar.
- **Multi-session** — every concurrent session (CLI, VS Code, JetBrains, Codex)
  with its project, status and context window.
- **Claude Code &amp; Codex** — both providers tracked; filter the dashboard and
  the dropdown by provider.
- **Real rate limits** — 5-hour and weekly used %, with exact reset countdowns.
- **Exact cost** — per-model pricing from LiteLLM; the live session uses the
  agent's own reported cost.
- **Dashboard** — native Swift Charts for daily trends, projects and models.
- **Desktop widgets** — small, medium and large widgets for cost, tokens, limits
  and active sessions.
- **Menu-bar icons** — pick the Anthrocite mark, an animated Claude spark, or an
  animated crab; optional completion chime.
- **Built-in updates** — checks GitHub and installs new versions in place.

Everything is read locally from `~/.claude` and `~/.codex`; nothing is uploaded.

## Develop

This is a Turborepo + pnpm monorepo.

```
apps/
  macos/   Native menu-bar app + dashboard + widget (SwiftUI + AppKit, Xcode)
  web/     Landing page (Vite + React + Tailwind + Framer Motion)
```

```sh
pnpm install      # install JS workspaces
pnpm web          # run the landing page (Vite dev server)
pnpm build        # build all JS apps
```

The macOS app builds with Xcode:

```sh
xcodebuild -project apps/macos/Anthrocite.xcodeproj \
  -scheme Anthrocite -configuration Release build
```

## License

[MIT](LICENSE) © 2026 Marques Scripps.
