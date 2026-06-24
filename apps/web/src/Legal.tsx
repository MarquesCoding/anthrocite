import type { ReactNode } from "react";

const REPO = "https://github.com/MarquesCoding/anthrocite";

function Shell({ title, updated, children }: { title: string; updated: string; children: ReactNode }) {
  return (
    <div className="min-h-screen px-6 py-16">
      <div className="mx-auto max-w-2xl">
        <a href="/" className="mb-10 inline-flex items-center gap-2 text-sm text-white/60 transition hover:text-white">
          <img src="/logo.svg" alt="" className="h-4 w-auto" /> Anthrocite
        </a>
        <h1 className="font-display text-4xl font-semibold tracking-tight">{title}</h1>
        <p className="mt-2 text-sm text-white/40">Last updated {updated}</p>
        <div className="prose-anthrocite mt-10 space-y-6 text-[15px] leading-relaxed text-white/70">
          {children}
        </div>
        <footer className="mt-16 border-t border-white/10 pt-6 text-sm text-white/40">
          <a href="/privacy" className="hover:text-white">Privacy</a>
          <span className="px-2">·</span>
          <a href="/terms" className="hover:text-white">Terms</a>
          <span className="px-2">·</span>
          <a href={REPO} className="hover:text-white">GitHub</a>
        </footer>
      </div>
    </div>
  );
}

function H({ children }: { children: ReactNode }) {
  return <h2 className="font-display text-xl font-semibold text-white">{children}</h2>;
}

export function Privacy() {
  return (
    <Shell title="Privacy Policy" updated="June 2026">
      <p>
        Anthrocite is a local macOS app. It reads your AI coding-agent usage from files already
        on your Mac (<code>~/.claude</code> and <code>~/.codex</code>) and shows it in your menu
        bar. By default, <strong>nothing about your usage ever leaves your device.</strong>
      </p>

      <H>What we don't collect</H>
      <p>
        No accounts, no analytics, no tracking, no telemetry. We don't see your prompts, code,
        project names, file paths, or what you work on. There is no server involved in normal use.
      </p>

      <H>Features that use the network</H>
      <ul className="list-disc space-y-2 pl-5">
        <li><strong>Pricing</strong> — fetches public model rates from LiteLLM. No data about you is sent.</li>
        <li><strong>Updates</strong> — checks GitHub for new releases. A standard download request.</li>
        <li><strong>Discord Rich Presence</strong> (opt-in) — sends your current activity to the Discord app running locally on your Mac, via Discord's local socket. Display of that status is governed by Discord.</li>
        <li><strong>Leaderboard</strong> (opt-in, off by default) — described below.</li>
      </ul>

      <H>The leaderboard (opt-in)</H>
      <p>If, and only if, you turn it on, Anthrocite shares:</p>
      <ul className="list-disc space-y-2 pl-5">
        <li>an <strong>anonymous device id</strong> — a one-way hash of your Mac's hardware id (the raw id never leaves your device and can't be reversed);</li>
        <li>your <strong>per-model token totals</strong> and the model names;</li>
        <li>an <strong>optional display name</strong> you choose;</li>
        <li>the app version.</li>
      </ul>
      <p>
        It never includes your name, email, project names, file paths, prompts, costs, or any
        other personal data. You can turn it off at any time in Settings, and request deletion of
        your entry by contacting us.
      </p>

      <H>Contact</H>
      <p>Questions or a deletion request? Open an issue on <a className="text-white underline" href={REPO}>GitHub</a>.</p>
    </Shell>
  );
}

export function Terms() {
  return (
    <Shell title="Terms of Use" updated="June 2026">
      <p>
        Anthrocite is free, open-source software released under the MIT License. By using it you
        agree to these terms.
      </p>

      <H>As-is, no warranty</H>
      <p>
        The app is provided "as is", without warranty of any kind. Usage figures and especially
        cost estimates are approximate and for reference only — always treat your provider's own
        billing as the source of truth.
      </p>

      <H>Acceptable use</H>
      <p>
        If you join the leaderboard, don't submit falsified usage or attempt to manipulate
        rankings. We may remove entries that appear fraudulent or abusive.
      </p>

      <H>Changes</H>
      <p>
        These terms and the privacy policy may change as the app evolves; material changes will be
        noted here with an updated date.
      </p>

      <H>Contact</H>
      <p>Reach us via <a className="text-white underline" href={REPO}>GitHub</a>.</p>
    </Shell>
  );
}
