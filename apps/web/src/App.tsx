import { motion, type Variants } from "framer-motion";
import {
  IconBoltFilled,
  IconStack2Filled,
  IconGaugeFilled,
  IconCoinFilled,
  IconChartAreaLineFilled,
  IconShieldFilled,
  IconStarFilled,
  IconAppWindowFilled,
  IconBrandApple,
  IconBrandGithub,
  IconWifi,
  IconAdjustmentsHorizontal,
} from "@tabler/icons-react";

const REPO = "https://github.com/MarquesCoding/anthrocite";
const RELEASES = `${REPO}/releases`;

const container: Variants = {
  hidden: {},
  show: { transition: { staggerChildren: 0.08, delayChildren: 0.05 } },
};
const item: Variants = {
  hidden: { opacity: 0, y: 18 },
  show: { opacity: 1, y: 0, transition: { duration: 0.6, ease: [0.22, 1, 0.36, 1] } },
};

export default function App() {
  return (
    <div className="min-h-screen overflow-x-hidden">
      <Nav />
      <Hero />
      <Features />
      <Footer />
    </div>
  );
}

function Nav() {
  return (
    <header className="fixed inset-x-0 top-4 z-50 px-4">
      <div className="mx-auto flex h-12 max-w-2xl items-center justify-between rounded-full border border-white/10 bg-white/[0.04] px-4 backdrop-blur-xl">
        <a href="#" className="flex items-center gap-2">
          <img src="/logo.svg" alt="" className="h-5 w-auto" />
          <span className="text-[15px] font-semibold tracking-tight">Anthrocite</span>
        </a>
        <div className="flex items-center gap-1">
          <a href="#features" className="hidden rounded-full px-3 py-1.5 text-sm text-white/65 transition hover:text-white sm:block">Features</a>
          <a href={REPO} aria-label="GitHub" className="rounded-full p-2 text-white/65 transition hover:text-white"><IconBrandGithub size={18} /></a>
          <a href={RELEASES} className="rounded-full bg-white px-4 py-1.5 text-sm font-medium text-black transition hover:bg-white/90">Download</a>
        </div>
      </div>
    </header>
  );
}

function Hero() {
  return (
    <section className="relative px-6 pt-36 text-center">
      <motion.div variants={container} initial="hidden" animate="show">
        <motion.div variants={item} className="mb-7 inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-3.5 py-1.5 text-[13px] text-white/60">
          <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
          Free &amp; open source · macOS 15+
        </motion.div>
        <motion.h1 variants={item} className="mx-auto max-w-5xl text-[15vw] font-semibold leading-[0.92] tracking-[-0.04em] sm:text-[112px]">
          Every agent.
          <br />
          <span className="bg-gradient-to-b from-white via-white to-white/35 bg-clip-text text-transparent">One glance.</span>
        </motion.h1>
        <motion.p variants={item} className="mx-auto mt-7 max-w-lg text-lg text-white/55">
          Live status, usage, cost and your real rate limits for Claude Code —
          right in your menu bar, in real time.
        </motion.p>
        <motion.div variants={item} className="mt-8 flex flex-wrap items-center justify-center gap-3">
          <a href={RELEASES} className="inline-flex items-center gap-2 rounded-full bg-white px-7 py-3.5 text-[15px] font-medium text-black transition hover:bg-white/90">
            <IconBrandApple size={19} /> Download for macOS
          </a>
          <a href={REPO} className="inline-flex items-center gap-2 rounded-full border border-white/15 px-7 py-3.5 text-[15px] font-medium text-white/80 transition hover:border-white/30">
            <IconBrandGithub size={19} /> Star on GitHub
          </a>
        </motion.div>
      </motion.div>

      <motion.div
        variants={item}
        initial="hidden"
        animate="show"
        transition={{ delay: 0.4, duration: 0.9, ease: [0.22, 1, 0.36, 1] }}
        className="relative mx-auto mt-24 max-w-6xl"
      >
        <div
          aria-hidden
          className="pointer-events-none absolute -inset-x-24 -top-32 bottom-0 -z-10"
          style={{
            background:
              "radial-gradient(55% 45% at 45% 35%, rgba(124,92,255,0.45), transparent 70%), radial-gradient(45% 40% at 70% 55%, rgba(42,108,244,0.40), transparent 70%)",
            filter: "blur(30px)",
          }}
        />
        <DesktopMock />
        <div className="pointer-events-none absolute inset-x-0 -bottom-px h-48 bg-gradient-to-b from-transparent to-[#0a0b0e]" />
      </motion.div>
    </section>
  );
}

/* A framed macOS desktop showing the menu bar + Anthrocite dropdown over a
   wallpaper. Drop /hero-bg.jpg into public to use a real wallpaper. */
function DesktopMock() {
  return (
    <div className="relative overflow-hidden rounded-[22px] border border-white/15 shadow-[0_60px_140px_-30px_rgba(0,0,0,0.85)]">
      {/* wallpaper: iridescent discs (drop /hero-bg.jpg in public to override) */}
      <div className="relative aspect-[16/10] w-full overflow-hidden" style={{ background: "linear-gradient(150deg,#1d1233,#0d0a1b 70%)" }}>
        <div
          className="absolute left-[10%] top-1/2 h-[72%] w-[44%] -translate-y-1/2 rounded-full opacity-90"
          style={{ background: "conic-gradient(from 210deg, #ff7ad5, #b18bff, #6aa8ff, #6ff0e0, #c8ff7a, #ffd36a, #ff7ad5)", filter: "blur(16px)" }}
        />
        <div
          className="absolute right-[8%] top-1/2 h-[80%] w-[48%] -translate-y-1/2 rotate-12 rounded-full opacity-90"
          style={{ background: "conic-gradient(from 30deg, #6aa8ff, #b18bff, #ff7ad5, #ffd36a, #6ff0e0, #6aa8ff)", filter: "blur(16px)" }}
        />
        <img
          src="/hero-bg.jpg"
          alt=""
          className="absolute inset-0 h-full w-full object-cover"
          onError={(e) => (e.currentTarget.style.display = "none")}
        />
      </div>
      {/* menu bar */}
      <div className="absolute inset-x-0 top-0 flex h-8 items-center justify-end gap-4 bg-black/20 px-4 text-[13px] text-white backdrop-blur-sm">
        <span className="flex items-center gap-1.5 font-medium">
          <img src="/logo.svg" alt="" className="h-3 w-auto" /> Editing 12s
        </span>
        <IconWifi size={15} />
        <IconAdjustmentsHorizontal size={15} />
        <span className="tabular-nums">2:44</span>
      </div>
      {/* dropdown */}
      <div className="absolute right-3 top-10 w-[270px] overflow-hidden rounded-xl border border-white/10 bg-[#161618]/85 p-3.5 text-left shadow-2xl backdrop-blur-2xl sm:right-6 sm:top-11 sm:w-[300px]">
        <p className="px-1 text-[11px] font-semibold uppercase tracking-wide text-white/40">Sessions · 2 working</p>
        <Session name="anthrocite" status="Editing 12s" pct={31} />
        <Session name="ChatPod" status="Running 4s" pct={71} />
        <div className="my-2.5 h-px bg-white/10" />
        <div className="mb-2 flex gap-1 rounded-lg bg-white/5 p-0.5 text-[11px]">
          <span className="flex-1 rounded-md bg-white/15 py-1 text-center font-medium text-white">Today</span>
          <span className="flex-1 py-1 text-center text-white/40">Session</span>
          <span className="flex-1 py-1 text-center text-white/40">Total</span>
        </div>
        <Row label="Tokens" value="89.4M" bold />
        <Row label="Cost" value="$75.10" bold />
        <div className="my-2.5 h-px bg-white/10" />
        <p className="px-1 text-[11px] font-semibold uppercase tracking-wide text-white/40">Limits</p>
        <Limit label="5-Hour Session" pct={13} sub="resets in 2h 4m" />
        <Limit label="Weekly" pct={2} sub="resets in 6d 1h" />
      </div>
    </div>
  );
}

function Session({ name, status, pct }: { name: string; status: string; pct: number }) {
  return (
    <div className="px-1 py-1.5 text-white">
      <div className="flex items-center gap-2">
        <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
        <span className="text-[13px] font-medium">{name}</span>
        <span className="ml-auto text-[11px] text-white/50">{status}</span>
      </div>
      <Bar pct={pct} className="mt-1.5" />
    </div>
  );
}
function Row({ label, value, bold }: { label: string; value: string; bold?: boolean }) {
  return (
    <div className="flex justify-between px-1 py-0.5 text-[13px] text-white">
      <span className={bold ? "font-medium" : "text-white/55"}>{label}</span>
      <span className={`tabular-nums ${bold ? "font-semibold" : ""}`}>{value}</span>
    </div>
  );
}
function Limit({ label, pct, sub }: { label: string; pct: number; sub: string }) {
  return (
    <div className="px-1 py-1 text-white">
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

const features = [
  { icon: IconBoltFilled, title: "Live status" },
  { icon: IconStack2Filled, title: "Every session" },
  { icon: IconGaugeFilled, title: "Real limits" },
  { icon: IconCoinFilled, title: "Exact cost" },
  { icon: IconChartAreaLineFilled, title: "Usage trends" },
  { icon: IconShieldFilled, title: "Totally private" },
  { icon: IconAppWindowFilled, title: "Menu-bar native" },
  { icon: IconStarFilled, title: "Free & open source" },
];

function Features() {
  return (
    <motion.section
      id="features"
      variants={container}
      initial="hidden"
      whileInView="show"
      viewport={{ once: true, margin: "-80px" }}
      className="mx-auto max-w-5xl px-6 py-28"
    >
      <div className="grid grid-cols-2 gap-x-8 gap-y-14 sm:grid-cols-4">
        {features.map((f) => (
          <motion.div variants={item} key={f.title} className="flex flex-col items-center text-center">
            <f.icon size={34} className="text-white/85" />
            <h3 className="mt-4 text-[17px] font-semibold leading-tight">{f.title}</h3>
          </motion.div>
        ))}
      </div>
    </motion.section>
  );
}

function Footer() {
  return (
    <footer className="relative overflow-hidden px-6 pt-16 pb-24 text-center">
      <a href={RELEASES} className="inline-flex items-center gap-2 rounded-full bg-white px-7 py-3.5 text-[15px] font-medium text-black transition hover:bg-white/90">
        <IconBrandApple size={19} /> Download for macOS
      </a>
      <div className="mt-8 flex items-center justify-center">
        <a href={REPO} aria-label="GitHub" className="rounded-xl bg-white/[0.06] p-3 text-white/70 transition hover:text-white">
          <IconBrandGithub size={22} />
        </a>
      </div>
      <p className="mt-10 text-sm text-white/35">© 2026 Anthrocite · MIT licensed</p>
      <div aria-hidden className="pointer-events-none absolute -bottom-6 left-1/2 -z-0 -translate-x-1/2 select-none text-[20vw] font-bold leading-none tracking-tighter text-white/[0.025]">
        Anthrocite
      </div>
    </footer>
  );
}
