// Telegram notifier for the site lead forms (Starlink survey, pentest
// enquiry, …). Receives the form submission (browser fetch) and forwards a message to a
// Telegram chat via the Bot API. The bot token and chat id live ONLY as
// Worker secrets (BOT_TOKEN, CHAT_ID) — never in the public site code.
//
// Secrets (set once):  wrangler secret put BOT_TOKEN   /   wrangler secret put CHAT_ID
// Var (in wrangler.toml): ALLOWED_ORIGIN = "https://sp1r4.github.io"

const json = (obj, status, cors) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });

const clip = (v, n) => (v == null ? '' : String(v).slice(0, n));

export default {
  async fetch(request, env) {
    const origin = env.ALLOWED_ORIGIN || '*';
    const cors = {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Vary': 'Origin',
    };

    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    if (request.method !== 'POST') return json({ ok: false, error: 'method' }, 405, cors);

    // Defense-in-depth: reject requests whose Origin isn't our site. A real
    // browser always sends Origin on this cross-origin POST; this blocks other
    // sites and naive scripts. NOT bulletproof (Origin is spoofable by non-
    // browser clients) — rate limiting (Cloudflare rule / Turnstile) is the
    // real abuse control. See worker/README.md.
    if (origin !== '*' && request.headers.get('Origin') !== origin) {
      return json({ ok: false, error: 'forbidden' }, 403, cors);
    }

    // Rate limit per client IP (binding configured in wrangler.toml).
    if (env.RATE_LIMITER) {
      const ip = request.headers.get('CF-Connecting-IP') || 'anon';
      const { success } = await env.RATE_LIMITER.limit({ key: ip });
      if (!success) return json({ ok: false, error: 'rate limited' }, 429, cors);
    }

    // Cap body size — a contact form is tiny; anything large is abuse.
    if (Number(request.headers.get('content-length') || 0) > 16384) {
      return json({ ok: false, error: 'too large' }, 413, cors);
    }

    let data;
    try {
      const ct = request.headers.get('content-type') || '';
      if (ct.includes('application/json')) {
        data = await request.json();
      } else {
        data = Object.fromEntries((await request.formData()).entries());
      }
    } catch {
      return json({ ok: false, error: 'bad request' }, 400, cors);
    }

    // Honeypot: silently accept bot submissions without notifying.
    if (data.botcheck) return json({ ok: true }, 200, cors);

    const name = clip(data.name, 200);
    const email = clip(data.email, 200);
    const location = clip(data.location, 300);   // Starlink form
    const company = clip(data.company, 300);      // pentest form
    const message = clip(data.message, 2000);
    const heading = clip(data.subject, 200) || clip(data.from_name, 200) || 'S. Markakis — new enquiry';

    if (!name && !email) return json({ ok: false, error: 'empty' }, 400, cors);

    const text =
      `🔔 ${heading}\n\n` +
      `👤 ${name}\n` +
      `✉️ ${email}\n` +
      (location ? `📍 ${location}\n` : '') +
      (company ? `🏢 ${company}\n` : '') +
      (message ? `📝 ${message}\n` : '');

    const tg = await fetch(`https://api.telegram.org/bot${env.BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: env.CHAT_ID, text, disable_web_page_preview: true }),
    });

    if (!tg.ok) return json({ ok: false, error: 'telegram' }, 502, cors);
    return json({ ok: true }, 200, cors);
  },
};
