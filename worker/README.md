# Telegram notifier (Cloudflare Worker)

When someone submits the Starlink site-survey form, the page sends the email
(via Web3Forms, unchanged) **and** pings this Worker, which forwards a message to
your Telegram chat. The bot token stays a Worker secret — it is never in the
public site code.

## One-time setup

1. **(Recommended) Rotate the bot token.** Open [@BotFather](https://t.me/BotFather)
   → `/revoke` → pick the bot → copy the **new** token. (Do this because the old
   token was shared in plaintext.)

2. **Find your chat id.** Message your bot once, then open:
   `https://api.telegram.org/bot<TOKEN>/getUpdates`
   and copy `result[].message.chat.id` (a number, e.g. `123456789`).

3. **Install + log in to Cloudflare** (free account):
   ```sh
   npm i -g wrangler
   wrangler login
   ```

4. **Set the secrets** (from inside this `worker/` folder):
   ```sh
   wrangler secret put BOT_TOKEN     # paste the new token
   wrangler secret put CHAT_ID       # paste your chat id
   ```

5. **Deploy:**
   ```sh
   wrangler deploy
   ```
   Copy the printed URL, e.g. `https://noctis-telegram.<you>.workers.dev`.

6. **Plug the URL into the site** — replace the placeholder in **two** files:
   - `js/form.js` → `TELEGRAM_ENDPOINT`
   - `starlink.html` → the `connect-src` entry in the `Content-Security-Policy`
     (replace `https://noctis-telegram.YOUR-SUBDOMAIN.workers.dev`)

   Then commit & push.

## Test
```sh
curl -X POST https://noctis-telegram.<you>.workers.dev \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test","email":"t@t.gr","location":"Χανιά","message":"δοκιμή"}'
```
A Telegram message should arrive. Then submit the real form on the site.

## Security
- **Secrets** (`BOT_TOKEN`, `CHAT_ID`) live only as Worker secrets — never in the
  repo or the public site code.
- **Origin check**: the Worker rejects any POST whose `Origin` header isn't
  `ALLOWED_ORIGIN`. This blocks other websites and naive scripts — but `Origin`
  is spoofable by non-browser clients, so it is NOT a complete defence.
- **Body cap**: requests over 16 KB are rejected; fields are clipped.
- **Plain-text Telegram message** (no `parse_mode`) → user input can't inject
  Telegram markup.

### ⚠️ Add rate limiting (recommended)
The endpoint is public and unauthenticated by nature (it serves a public form).
Without a rate limit, someone who finds the URL could flood your Telegram /
burn the Cloudflare free quota. Add ONE of:

- **Cloudflare Rate Limiting rule** (no code): Dashboard → your Worker →
  *Settings → Rate limiting* (or a WAF rate-limit rule on the route), e.g.
  max 5 requests / minute / IP.
- **Cloudflare Turnstile** (stronger): add the Turnstile widget to the form and
  verify the token in the Worker via the siteverify API before sending. Note this
  adds a Cloudflare script to the page (relax CSP accordingly).

## Redeploy after changes
Any edit to `index.js` (e.g. the Origin check) needs a redeploy:
```sh
wrangler deploy
```

## Notes
- `ALLOWED_ORIGIN` in `wrangler.toml` locks the endpoint to `https://s-markakis.github.io`.
- The email path (Web3Forms) is independent — if the Worker is down, the email
  still goes through and the customer sees no error.
