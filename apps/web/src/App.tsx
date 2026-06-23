import { useRef } from "react";
import { motion, useInView, LayoutGroup, type Variants } from "framer-motion";
import {
  IconBoltFilled,
  IconStack2Filled,
  IconGaugeFilled,
  IconCoinFilled,
  IconChartAreaLineFilled,
  IconShieldFilled,
  IconStarFilled,
  IconAppWindowFilled,
  IconBrandAppleFilled,
  IconBrandGithubFilled,
  IconWifi,
  IconAdjustmentsFilled,
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
  const slotRef = useRef<HTMLDivElement>(null);
  const inHero = useInView(slotRef, { margin: "-72px 0px 0px 0px" });
  return (
    <LayoutGroup>
      <div className="min-h-screen overflow-x-hidden">
        <Nav inHero={inHero} />
        <Hero slotRef={slotRef} inHero={inHero} />
        <Features />
        <Screenshots />
        <Footer />
      </div>
    </LayoutGroup>
  );
}

/* The single CTA pair that morphs between the hero and the nav via layoutId. */
const swing = { type: "spring" as const, stiffness: 320, damping: 18, mass: 0.9 };

function Cta({ compact = false }: { compact?: boolean }) {
  const pad = compact ? "py-1.5 text-sm" : "py-3.5 text-[15px]";
  const minw = compact ? "min-w-[116px]" : "min-w-[164px]";
  const sz = compact ? 16 : 19;
  const base = `inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full px-5 font-medium transition-colors ${pad} ${minw}`;
  return (
    <motion.div layoutId="cta" transition={swing} className="flex items-center gap-2.5">
      <motion.a layout transition={swing} href={REPO} className={`${base} border border-white/15 text-white/80 hover:border-white/30`}>
        <IconBrandGithubFilled size={sz} /> GitHub
      </motion.a>
      <motion.a layout transition={swing} href={RELEASES} className={`${base} bg-white text-black hover:bg-white/90`}>
        <IconBrandAppleFilled size={sz} /> Download
      </motion.a>
    </motion.div>
  );
}

function Nav({ inHero }: { inHero: boolean }) {
  return (
    <header className="fixed inset-x-0 top-4 z-50 px-4">
      <div className="mx-auto flex h-12 max-w-2xl items-center justify-between rounded-full border border-white/10 bg-white/[0.04] px-4 backdrop-blur-xl">
        <a href="#" className="flex items-center gap-2">
          <img src="/logo.svg" alt="" className="h-5 w-auto" />
          <span className="text-[15px] font-semibold tracking-tight">Anthrocite</span>
        </a>
        <div className="flex items-center gap-2">
          <a href="#features" className="rounded-full px-3 py-1.5 text-sm text-white/65 transition hover:text-white">Features</a>
          {!inHero && <Cta compact />}
        </div>
      </div>
    </header>
  );
}

function Hero({ slotRef, inHero }: { slotRef: React.RefObject<HTMLDivElement | null>; inHero: boolean }) {
  return (
    <section className="relative px-6 pt-36 text-center">
      <motion.div variants={container} initial="hidden" animate="show">
        <motion.h1 variants={item} className="mx-auto max-w-5xl text-[15vw] font-semibold leading-[0.92] tracking-[-0.04em] sm:text-[112px]">
          Every agent.
          <br />
          <span className="bg-gradient-to-b from-white via-white to-white/35 bg-clip-text text-transparent">One glance.</span>
        </motion.h1>
        <motion.p variants={item} className="mx-auto mt-7 max-w-lg text-lg text-white/55">
          Live status, usage, cost and your real rate limits for Claude Code —
          right in your menu bar, in real time.
        </motion.p>
        <motion.div ref={slotRef} variants={item} className="mt-8 flex min-h-[52px] items-center justify-center">
          {inHero && <Cta />}
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
        <video
          autoPlay
          loop
          muted
          playsInline
          className="absolute inset-0 h-full w-full object-cover"
        >
          <source src="/background.mp4" type="video/mp4" />
        </video>
      </div>
      {/* menu bar */}
      <div className="absolute inset-x-0 top-0 flex h-8 items-center justify-end gap-4 bg-black/20 px-4 text-[13px] text-white backdrop-blur-sm">
        <span className="flex items-center gap-1.5 font-medium">
          <img src="/logo.svg" alt="" className="h-3 w-auto" /> Editing 12s
        </span>
        <IconWifi size={15} />
        <IconAdjustmentsFilled size={15} />
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

      {/* dock */}
      <div className="absolute inset-x-0 bottom-3 flex justify-center">
        <div className="flex items-center gap-2 rounded-[20px] border border-white/15 bg-zinc-800/85 px-2.5 py-2 shadow-2xl backdrop-blur-xl">
          <div className="flex flex-col items-center">
            <img src="/icon.png" alt="Anthrocite" className="h-12 w-12 rounded-[12px] shadow-md" />
            <span className="mt-1 h-1 w-1 rounded-full bg-white/70" />
          </div>
          <div className="mx-0.5 h-12 w-px bg-white/20" />
          <img src="/trash.png" alt="Trash" className="h-12 w-12 object-contain"
            onError={(e) => (e.currentTarget.style.display = "none")} />
        </div>
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

/* Drop PNGs into apps/web/public/screenshots/ (dashboard.png, menu.png,
   sessions.png). Missing ones hide themselves. */
const screenshots = [
  { src: "/screenshots/dashboard.png", caption: "The dashboard — trends, projects & models" },
  { src: "/screenshots/menu.png", caption: "Live status in the menu bar" },
  { src: "/screenshots/sessions.png", caption: "Every concurrent session" },
];

function Screenshots() {
  return (
    <motion.section
      variants={container}
      initial="hidden"
      whileInView="show"
      viewport={{ once: true, margin: "-80px" }}
      className="mx-auto max-w-6xl px-6 py-16"
    >
      <div className="grid gap-5 md:grid-cols-2">
        {screenshots.map((s, i) => (
          <motion.figure
            variants={item}
            key={s.src}
            className={`overflow-hidden rounded-2xl border border-white/10 bg-white/[0.03] ${i === 0 ? "md:col-span-2" : ""}`}
          >
            <img
              src={s.src}
              alt={s.caption}
              loading="lazy"
              className="w-full"
              onError={(e) => {
                const f = e.currentTarget.closest("figure");
                if (f) (f as HTMLElement).style.display = "none";
              }}
            />
            <figcaption className="px-5 py-3 text-sm text-white/45">{s.caption}</figcaption>
          </motion.figure>
        ))}
      </div>
    </motion.section>
  );
}

function Footer() {
  return (
    <footer className="relative overflow-hidden px-6 pt-16 pb-24 text-center">
      <a href={RELEASES} className="inline-flex items-center gap-2 rounded-full bg-white px-7 py-3.5 text-[15px] font-medium text-black transition hover:bg-white/90">
        <IconBrandAppleFilled size={19} /> Download for macOS
      </a>
      <div className="mt-8 flex items-center justify-center">
        <a href={REPO} aria-label="GitHub" className="rounded-xl bg-white/[0.06] p-3 text-white/70 transition hover:text-white">
          <IconBrandGithubFilled size={22} />
        </a>
      </div>
      <p className="mt-10 text-sm text-white/35">© 2026 Anthrocite · MIT licensed</p>
      <div aria-hidden className="pointer-events-none absolute -bottom-6 left-1/2 -z-0 -translate-x-1/2 select-none text-[20vw] font-bold leading-none tracking-tighter text-white/[0.025]">
        Anthrocite
      </div>
    </footer>
  );
}
