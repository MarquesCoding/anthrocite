import {
  Activity,
  Layers,
  Gauge,
  DollarSign,
  BarChart3,
  Lock,
  Apple,
  Github,
} from "lucide-react";

const features = [
  {
    icon: Activity,
    title: "Live status",
    desc: "See exactly what Claude is doing right now — Reading, Running, Editing, Thinking — with a ticking timer in your menu bar.",
  },
  {
    icon: Layers,
    title: "Every session",
    desc: "Track all your concurrent agents at once, each with its own project, status and context window. CLI, VS Code or JetBrains.",
  },
  {
    icon: Gauge,
    title: "Real limits",
    desc: "Your actual 5-hour and weekly rate-limit usage with exact reset times — straight from Claude Code, not a guess.",
  },
  {
    icon: DollarSign,
    title: "Exact cost",
    desc: "Per-model pricing from the live LiteLLM dataset, split into input, output and cache. Know what every session really costs.",
  },
  {
    icon: BarChart3,
    title: "Dashboard",
    desc: "A native macOS dashboard with trends over time, top projects and models — built entirely from Apple's own components.",
  },
  {
    icon: Lock,
    title: "Totally private",
    desc: "Everything is read locally from your machine. Nothing about your code or usage is ever sent anywhere.",
  },
];

export default function App() {
  return (
    <div className="min-h-screen overflow-x-hidden">
      <Nav />
      <Hero />
      <Features />
      <Pricing />
      <Footer />
    </div>
  );
}

function Nav() {
  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-white/5 bg-[#050506]/70 backdrop-blur-xl">
      <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-6">
        <a href="#" className="flex items-center gap-2.5">
          <img src="/logo-light.svg" alt="" className="h-5 w-auto" />
          <span className="text-[15px] font-semibold tracking-tight">Anthrocite</span>
        </a>
        <nav className="hidden items-center gap-8 text-sm text-white/60 md:flex">
          <a href="#features" className="transition hover:text-white">Features</a>
          <a href="#pricing" className="transition hover:text-white">Pricing</a>
          <a href="https://github.com/MarquesCoding" className="transition hover:text-white">GitHub</a>
        </nav>
        <a
          href="#pricing"
          className="rounded-full bg-white px-4 py-1.5 text-sm font-medium text-black transition hover:bg-white/90"
        >
          Download
        </a>
      </div>
    </header>
  );
}

function Hero() {
  return (
    <section className="relative px-6 pt-40 pb-24 text-center">
      {/* soft radial glow */}
      <div className="pointer-events-none absolute left-1/2 top-0 -z-10 h-[600px] w-[900px] -translate-x-1/2 rounded-full bg-[radial-gradient(ellipse_at_center,rgba(255,255,255,0.08),transparent_60%)]" />
      <p className="mb-5 text-sm font-medium text-white/40">For Claude Code · macOS 15+</p>
      <h1 className="mx-auto max-w-4xl text-5xl font-semibold leading-[1.05] tracking-tight sm:text-7xl">
        <span className="silver">Your AI coding agents,</span>
        <br />
        <span className="silver">at a glance.</span>
      </h1>
      <p className="mx-auto mt-6 max-w-xl text-lg text-white/55">
        Anthrocite lives in your menu bar and shows live status, usage, cost and your
        real rate limits — across every session, in real time.
      </p>
      <div className="mt-9 flex items-center justify-center gap-3">
        <a
          href="#pricing"
          className="inline-flex items-center gap-2 rounded-full bg-white px-6 py-3 text-[15px] font-medium text-black transition hover:bg-white/90"
        >
          <Apple className="h-4.5 w-4.5" /> Download for macOS
        </a>
        <a
          href="#pricing"
          className="rounded-full border border-white/15 px-6 py-3 text-[15px] font-medium text-white/80 transition hover:border-white/30 hover:text-white"
        >
          Free for students
        </a>
      </div>
      <p className="mt-4 text-sm text-white/35">$1.99 · one-time · no subscription</p>

      <div className="mx-auto mt-20 max-w-md">
        <MenuMock />
      </div>
    </section>
  );
}

/* A faithful mock of the menu-bar dropdown, built in HTML/CSS. */
function MenuMock() {
  return (
    <div className="relative">
      <div className="pointer-events-none absolute -inset-10 -z-10 rounded-[40px] bg-white/[0.03] blur-2xl" />
      <div className="overflow-hidden rounded-2xl border border-white/10 bg-[#161618]/90 p-4 text-left shadow-2xl backdrop-blur-xl">
        {/* Sessions */}
        <p className="px-1 text-xs font-semibold uppercase tracking-wide text-white/40">Sessions · 2 working</p>
        <Session name="anthrocite" status="Editing 12s" pct={31} working />
        <Session name="ChatPod" status="Running 4s" pct={71} working />

        <div className="my-3 h-px bg-white/10" />

        {/* Usage */}
        <div className="mb-2 flex gap-1 rounded-lg bg-white/5 p-0.5 text-xs">
          <span className="flex-1 rounded-md bg-white/15 py-1 text-center font-medium text-white">Today</span>
          <span className="flex-1 py-1 text-center text-white/40">Session</span>
          <span className="flex-1 py-1 text-center text-white/40">Total</span>
        </div>
        <Row label="Tokens" value="89.4M" bold />
        <Row label="Cost" value="$75.10" bold />
        <Row label="Cache read" value="86.2M" muted />

        <div className="my-3 h-px bg-white/10" />

        {/* Limits */}
        <p className="px-1 text-xs font-semibold uppercase tracking-wide text-white/40">Limits</p>
        <Limit label="5-Hour Session" pct={13} sub="resets in 2h 4m" />
        <Limit label="Weekly" pct={2} sub="resets in 6d 1h" />
      </div>
    </div>
  );
}

function Session({ name, status, pct, working }: { name: string; status: string; pct: number; working?: boolean }) {
  return (
    <div className="px-1 py-2">
      <div className="flex items-center gap-2">
        <span className={`h-1.5 w-1.5 rounded-full ${working ? "bg-emerald-400" : "bg-white/30"}`} />
        <span className="text-[13px] font-medium">{name}</span>
        <span className="ml-auto text-xs text-white/50">{status}</span>
      </div>
      <Bar pct={pct} className="mt-1.5" />
      <p className="mt-1 text-[11px] text-white/35">{pct}% context</p>
    </div>
  );
}

function Row({ label, value, bold, muted }: { label: string; value: string; bold?: boolean; muted?: boolean }) {
  return (
    <div className={`flex justify-between px-1 py-0.5 text-[13px] ${muted ? "text-white/40" : ""}`}>
      <span className={bold ? "font-medium" : "text-white/55"}>{label}</span>
      <span className={`tabular-nums ${bold ? "font-semibold" : ""}`}>{value}</span>
    </div>
  );
}

function Limit({ label, pct, sub }: { label: string; pct: number; sub: string }) {
  return (
    <div className="px-1 py-1.5">
      <div className="flex justify-between text-[13px]">
        <span className="text-white/70">{label}</span>
        <span className="tabular-nums">{pct}%</span>
      </div>
      <Bar pct={pct} className="mt-1.5" />
      <p className="mt-1 text-[11px] text-white/35">{sub}</p>
    </div>
  );
}

function Bar({ pct, className = "" }: { pct: number; className?: string }) {
  return (
    <div className={`h-1 overflow-hidden rounded-full bg-white/10 ${className}`}>
      <div className="h-full rounded-full bg-white/55" style={{ width: `${pct}%` }} />
    </div>
  );
}

function Features() {
  return (
    <section id="features" className="mx-auto max-w-6xl px-6 py-28">
      <div className="mx-auto mb-16 max-w-2xl text-center">
        <h2 className="text-4xl font-semibold tracking-tight sm:text-5xl">Everything, where you can see it.</h2>
        <p className="mt-4 text-lg text-white/50">No dashboards to open, no terminals to check. Just glance up.</p>
      </div>
      <div className="grid gap-px overflow-hidden rounded-3xl border border-white/10 bg-white/10 sm:grid-cols-2 lg:grid-cols-3">
        {features.map((f) => (
          <div key={f.title} className="bg-[#050506] p-8">
            <f.icon className="h-6 w-6 text-white/80" strokeWidth={1.5} />
            <h3 className="mt-5 text-lg font-medium">{f.title}</h3>
            <p className="mt-2 text-[15px] leading-relaxed text-white/50">{f.desc}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

function Pricing() {
  return (
    <section id="pricing" className="mx-auto max-w-6xl px-6 py-28">
      <div className="mx-auto max-w-md">
        <div className="rounded-3xl border border-white/10 bg-gradient-to-b from-white/[0.06] to-transparent p-10 text-center">
          <p className="text-sm font-medium uppercase tracking-wide text-white/40">One-time purchase</p>
          <div className="mt-4 flex items-baseline justify-center gap-1">
            <span className="text-6xl font-semibold tracking-tight">$1.99</span>
          </div>
          <p className="mt-2 text-white/45">Yours forever. No subscription.</p>
          <a
            href="#"
            className="mt-8 inline-flex w-full items-center justify-center gap-2 rounded-full bg-white px-6 py-3.5 font-medium text-black transition hover:bg-white/90"
          >
            <Apple className="h-4.5 w-4.5" /> Download for macOS
          </a>
          <div className="mt-6 border-t border-white/10 pt-6 text-sm text-white/50">
            <span className="font-medium text-white/80">Student?</span> It's free — just{" "}
            <a className="underline decoration-white/30 underline-offset-4 hover:text-white" href="mailto:students@anthrocite.app">
              email us
            </a>{" "}
            from your university address.
          </div>
        </div>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="border-t border-white/5 px-6 py-12">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 sm:flex-row">
        <div className="flex items-center gap-2.5">
          <img src="/logo-light.svg" alt="" className="h-4 w-auto opacity-70" />
          <span className="text-sm text-white/40">© 2026 Anthrocite</span>
        </div>
        <div className="flex items-center gap-6 text-sm text-white/40">
          <a href="#features" className="hover:text-white">Features</a>
          <a href="#pricing" className="hover:text-white">Pricing</a>
          <a href="https://github.com/MarquesCoding" className="flex items-center gap-1.5 hover:text-white">
            <Github className="h-4 w-4" /> GitHub
          </a>
        </div>
      </div>
    </footer>
  );
}
