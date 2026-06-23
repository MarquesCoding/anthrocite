import { serve } from "@hono/node-server";
import { Hono } from "hono";

const app = new Hono();

app.get("/", (c) => c.json({ name: "anthrocite-api", status: "ok" }));
app.get("/health", (c) => c.json({ ok: true }));

// License activation/validation — wired to Polar later.
// Polar issues + validates license keys; this proxies/caches that for the app.
app.post("/license/validate", async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const key = (body as { key?: string }).key;
  if (!key) return c.json({ valid: false, error: "missing key" }, 400);
  // TODO: POST to Polar's license-keys validate endpoint with POLAR_TOKEN.
  return c.json({ valid: false, error: "not_implemented" }, 501);
});

// Polar webhook (order/checkout completed) — issue/record the license.
app.post("/webhooks/polar", async (c) => {
  // TODO: verify signature, handle order.created -> store entitlement.
  return c.json({ received: true });
});

const port = Number(process.env.PORT ?? 8787);
serve({ fetch: app.fetch, port });
console.log(`anthrocite-api listening on http://localhost:${port}`);
