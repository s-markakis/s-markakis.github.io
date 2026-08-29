// Visual FX — all opt-in to prefers-reduced-motion.
//   1. Background: a per-page kinetic layer (mesh / rain / flow / aurora).
//   2. Scroll-reveal: below-the-fold blocks fade up as they enter the viewport.
//   3. Spotlight: a faint accent glow tracks the cursor across cards.
//
// Per-page background is chosen by filename (override with <body data-bg="...">):
//   pentest → rain · consulting → flow · everything else → mesh
//   (aurora is available as an opt-in via <body data-bg="aurora">)
(function () {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  function accentColor() {
    return getComputedStyle(document.body).getPropertyValue('--accent').trim() || '#c63d1f';
  }
  function themeRGB() {
    return document.body.classList.contains('dark') ? '244,243,239' : '15,15,15';
  }
  function mkCanvas(id) {
    const c = document.createElement('canvas');
    c.id = id; c.className = 'fx-bg';
    c.setAttribute('aria-hidden', 'true');
    document.body.prepend(c);
    return c;
  }
  function dpr() { return Math.min(devicePixelRatio || 1, 2); }
  // Re-read theme colours when the light/dark class flips.
  function onThemeChange(fn) {
    new MutationObserver(fn).observe(document.body, { attributes: true, attributeFilter: ['class'] });
  }
  // Pause/resume a rAF loop when the tab visibility changes.
  function onVisibility(stop, go) {
    document.addEventListener('visibilitychange', () => {
      stop();
      if (!document.hidden && !reduce) go();
    });
  }

  /* ── 1a. Constellation (mesh) — Starlink ──────────────────────────── */
  function constellation() {
    const canvas = mkCanvas('fx-constellation');
    const ctx = canvas.getContext('2d');
    let w = 0, h = 0, nodes = [], line = '15,15,15', accent = '#c63d1f', raf = 0;
    const MAXD = 132;

    function readColors() { line = themeRGB(); accent = accentColor(); }
    function resize() {
      const d = dpr();
      w = canvas.clientWidth; h = canvas.clientHeight;
      canvas.width = w * d; canvas.height = h * d;
      ctx.setTransform(d, 0, 0, d, 0, 0);
      const count = Math.max(14, Math.min(72, Math.floor((w * h) / 22000)));
      nodes = Array.from({ length: count }, (_, i) => ({
        x: Math.random() * w, y: Math.random() * h,
        vx: (Math.random() - 0.5) * 0.22, vy: (Math.random() - 0.5) * 0.22,
        accent: i % 9 === 0,
      }));
    }
    function draw() {
      ctx.clearRect(0, 0, w, h);
      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
          const a = nodes[i], b = nodes[j];
          const dx = a.x - b.x, dy = a.y - b.y, d = Math.hypot(dx, dy);
          if (d < MAXD) {
            ctx.strokeStyle = `rgba(${line},${(1 - d / MAXD) * 0.16})`;
            ctx.lineWidth = 0.6;
            ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
          }
        }
      }
      for (const n of nodes) {
        ctx.beginPath(); ctx.arc(n.x, n.y, n.accent ? 1.7 : 1.1, 0, 7);
        ctx.fillStyle = n.accent ? accent : `rgba(${line},0.4)`;
        ctx.fill();
      }
    }
    function step() {
      for (const n of nodes) {
        n.x += n.vx; n.y += n.vy;
        if (n.x < 0 || n.x > w) n.vx *= -1;
        if (n.y < 0 || n.y > h) n.vy *= -1;
      }
      draw();
      raf = requestAnimationFrame(step);
    }

    readColors(); resize();
    if (reduce) draw(); else step();
    addEventListener('resize', () => { readColors(); resize(); if (reduce) draw(); }, { passive: true });
    onThemeChange(readColors);
    onVisibility(() => cancelAnimationFrame(raf), step);
  }

  /* ── 1b. Digital rain — Pentest ───────────────────────────────────── */
  function rain() {
    const canvas = mkCanvas('fx-bg-rain');
    const ctx = canvas.getContext('2d');
    const GLYPHS = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#@$%&*<>/\\|=+-'.split('');
    const STEP = 16, TAIL = 10, TICK = 75;     // px cell, trail length, ms/row
    let w = 0, h = 0, cols = 0, heads = [], buf = [], line = '15,15,15', accent = '#c63d1f', raf = 0, last = 0;

    const glyph = () => GLYPHS[(Math.random() * GLYPHS.length) | 0];
    function readColors() { line = themeRGB(); accent = accentColor(); }
    function resize() {
      const d = dpr();
      w = canvas.clientWidth; h = canvas.clientHeight;
      canvas.width = w * d; canvas.height = h * d;
      ctx.setTransform(d, 0, 0, d, 0, 0);
      ctx.font = `600 ${STEP - 2}px 'JetBrains Mono', monospace`;
      ctx.textBaseline = 'top';
      cols = Math.ceil(w / STEP) + 1;
      heads = Array.from({ length: cols }, () => -((Math.random() * 40) | 0) * STEP);
      buf = Array.from({ length: cols }, () => Array.from({ length: TAIL }, glyph));
    }
    function draw() {
      ctx.clearRect(0, 0, w, h);
      for (let c = 0; c < cols; c++) {
        const x = c * STEP, head = heads[c], col = buf[c];
        for (let t = 0; t < TAIL; t++) {
          const y = head - t * STEP;
          if (y < -STEP || y > h) continue;
          if (t === 0) {
            ctx.fillStyle = (c % 7 === 0)
              ? accent
              : `rgba(${line},0.92)`;
          } else {
            ctx.fillStyle = `rgba(${line},${(1 - t / TAIL) * 0.45})`;
          }
          ctx.fillText(col[t], x, y);
        }
      }
    }
    function advance() {
      for (let c = 0; c < cols; c++) {
        heads[c] += STEP;
        buf[c].pop(); buf[c].unshift(glyph());
        if (heads[c] - TAIL * STEP > h && Math.random() > 0.975) {
          heads[c] = -((Math.random() * 16) | 0) * STEP;
        }
      }
    }
    function step(ts) {
      raf = requestAnimationFrame(step);
      if (ts - last < TICK) return;
      last = ts;
      advance(); draw();
    }

    readColors(); resize();
    if (reduce) draw(); else raf = requestAnimationFrame(step);
    addEventListener('resize', () => { readColors(); resize(); if (reduce) draw(); }, { passive: true });
    onThemeChange(() => { readColors(); if (reduce) draw(); });
    onVisibility(() => cancelAnimationFrame(raf), () => { last = 0; raf = requestAnimationFrame(step); });
  }

  /* ── 1c. Packet-flow field — Consulting ───────────────────────────── */
  function flow() {
    const canvas = mkCanvas('fx-bg-flow');
    const ctx = canvas.getContext('2d');
    const HIST = 7, SPEED = 0.7;
    let w = 0, h = 0, parts = [], line = '15,15,15', accent = '#c63d1f', raf = 0, t = 0;

    function readColors() { line = themeRGB(); accent = accentColor(); }
    function field(x, y) {                       // smooth trig vector field
      return (Math.cos(x * 0.0075) + Math.sin(y * 0.0075)) * Math.PI + t * 0.00018;
    }
    function spawn(p) {
      p.x = Math.random() * w; p.y = Math.random() * h;
      p.life = 120 + (Math.random() * 220 | 0);
      p.hist = [];
      p.accent = Math.random() < 0.14;
    }
    function resize() {
      const d = dpr();
      w = canvas.clientWidth; h = canvas.clientHeight;
      canvas.width = w * d; canvas.height = h * d;
      ctx.setTransform(d, 0, 0, d, 0, 0);
      ctx.lineWidth = 1; ctx.lineCap = 'round';
      const count = Math.max(24, Math.min(90, Math.floor((w * h) / 18000)));
      parts = Array.from({ length: count }, () => { const p = {}; spawn(p); return p; });
    }
    function draw() {
      ctx.clearRect(0, 0, w, h);
      for (const p of parts) {
        if (p.hist.length < 2) continue;
        for (let i = 1; i < p.hist.length; i++) {
          const a = p.hist[i - 1], b = p.hist[i];
          const alpha = (i / p.hist.length) * (p.accent ? 0.5 : 0.22);
          ctx.strokeStyle = p.accent ? `rgba(198,61,31,${alpha})` : `rgba(${line},${alpha})`;
          ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
        }
        const head = p.hist[p.hist.length - 1];
        ctx.beginPath(); ctx.arc(head.x, head.y, p.accent ? 1.6 : 1.0, 0, 7);
        ctx.fillStyle = p.accent ? accent : `rgba(${line},0.5)`;
        ctx.fill();
      }
    }
    function step() {
      t++;
      for (const p of parts) {
        const a = field(p.x, p.y);
        p.x += Math.cos(a) * SPEED; p.y += Math.sin(a) * SPEED;
        p.hist.push({ x: p.x, y: p.y });
        if (p.hist.length > HIST) p.hist.shift();
        if (--p.life < 0 || p.x < -20 || p.x > w + 20 || p.y < -20 || p.y > h + 20) spawn(p);
      }
      draw();
      raf = requestAnimationFrame(step);
    }

    readColors(); resize();
    if (reduce) draw(); else step();
    addEventListener('resize', () => { readColors(); resize(); if (reduce) draw(); }, { passive: true });
    onThemeChange(readColors);
    onVisibility(() => cancelAnimationFrame(raf), step);
  }

  /* ── 1d. Sonar — quiet concentric rings + expanding pings ─────────── */
  function sonar() {
    const canvas = mkCanvas('fx-bg-sonar');
    const ctx = canvas.getContext('2d');
    const RINGS = 5, RING_GAP = 150, PING_EVERY = 2600, PING_LIFE = 2400, MAX_PINGS = 3;
    let w = 0, h = 0, cx = 0, cy = 0, contacts = [], pings = [], line = '15,15,15', accent = '#c63d1f', raf = 0, lastPing = 0;

    function readColors() { line = themeRGB(); accent = accentColor(); }
    function resize() {
      const d = dpr();
      w = canvas.clientWidth; h = canvas.clientHeight;
      canvas.width = w * d; canvas.height = h * d;
      ctx.setTransform(d, 0, 0, d, 0, 0);
      cx = w * 0.5; cy = h * 0.44;
      const count = Math.max(6, Math.min(16, Math.floor((w * h) / 90000)));
      contacts = Array.from({ length: count }, () => ({
        x: Math.random() * w, y: Math.random() * h,
        phase: Math.random() * Math.PI * 2,
        accent: Math.random() < 0.2,
      }));
    }
    function draw(ts) {
      ctx.clearRect(0, 0, w, h);
      // static rings
      for (let r = 1; r <= RINGS; r++) {
        ctx.beginPath(); ctx.arc(cx, cy, r * RING_GAP, 0, 7);
        ctx.strokeStyle = `rgba(${line},0.05)`;
        ctx.lineWidth = 0.7;
        ctx.stroke();
      }
      // crosshair
      ctx.strokeStyle = `rgba(${line},0.04)`;
      ctx.beginPath(); ctx.moveTo(cx - RINGS * RING_GAP, cy); ctx.lineTo(cx + RINGS * RING_GAP, cy); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(cx, cy - RINGS * RING_GAP); ctx.lineTo(cx, cy + RINGS * RING_GAP); ctx.stroke();
      // blinking contacts
      for (const c of contacts) {
        const a = 0.12 + 0.22 * Math.abs(Math.sin(ts / 1600 + c.phase));
        ctx.beginPath(); ctx.arc(c.x, c.y, c.accent ? 1.8 : 1.2, 0, 7);
        ctx.fillStyle = c.accent ? `rgba(198,61,31,${a + 0.1})` : `rgba(${line},${a})`;
        ctx.fill();
      }
      // expanding pings
      for (const p of pings) {
        const t = (ts - p.born) / PING_LIFE;
        if (t >= 1) continue;
        const r = 6 + t * 130;
        const a = (1 - t) * (p.accent ? 0.4 : 0.22);
        ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, 7);
        ctx.strokeStyle = p.accent ? `rgba(198,61,31,${a})` : `rgba(${line},${a})`;
        ctx.lineWidth = 1;
        ctx.stroke();
      }
      pings = pings.filter((p) => ts - p.born < PING_LIFE);
    }
    function step(ts) {
      raf = requestAnimationFrame(step);
      if (ts - lastPing > PING_EVERY && pings.length < MAX_PINGS) {
        lastPing = ts + Math.random() * 1400;
        const src = contacts[(Math.random() * contacts.length) | 0];
        pings.push({ x: src.x, y: src.y, born: ts, accent: src.accent });
      }
      draw(ts);
    }

    readColors(); resize();
    if (reduce) draw(0); else raf = requestAnimationFrame(step);
    addEventListener('resize', () => { readColors(); resize(); if (reduce) draw(0); }, { passive: true });
    onThemeChange(() => { readColors(); if (reduce) draw(0); });
    onVisibility(() => cancelAnimationFrame(raf), () => { raf = requestAnimationFrame(step); });
  }

  /* ── 1e. Scanline — a slow sweep down the page with target hits ───── */
  function scan() {
    const canvas = mkCanvas('fx-bg-scan');
    const ctx = canvas.getContext('2d');
    const PERIOD = 16000, TRAIL = 140, HIT_LIFE = 900;
    let w = 0, h = 0, targets = [], hits = [], line = '15,15,15', accent = '#c63d1f', raf = 0, prevY = -1;

    function readColors() { line = themeRGB(); accent = accentColor(); }
    function resize() {
      const d = dpr();
      w = canvas.clientWidth; h = canvas.clientHeight;
      canvas.width = w * d; canvas.height = h * d;
      ctx.setTransform(d, 0, 0, d, 0, 0);
      const count = Math.max(8, Math.min(22, Math.floor((w * h) / 65000)));
      targets = Array.from({ length: count }, () => ({
        x: Math.random() * w, y: Math.random() * h,
        accent: Math.random() < 0.25,
      }));
    }
    function draw(ts) {
      ctx.clearRect(0, 0, w, h);
      const y = ((ts % PERIOD) / PERIOD) * (h + TRAIL) - TRAIL / 2;
      // faint dot grid rows near the beam feel "revealed" by it
      for (const t of targets) {
        ctx.beginPath(); ctx.arc(t.x, t.y, 1.1, 0, 7);
        ctx.fillStyle = `rgba(${line},0.10)`;
        ctx.fill();
      }
      // trailing glow above the line
      const grad = ctx.createLinearGradient(0, y - TRAIL, 0, y);
      grad.addColorStop(0, `rgba(${line},0)`);
      grad.addColorStop(1, `rgba(${line},0.05)`);
      ctx.fillStyle = grad;
      ctx.fillRect(0, y - TRAIL, w, TRAIL);
      // the scan line itself
      ctx.fillStyle = `rgba(198,61,31,0.28)`;
      ctx.fillRect(0, y, w, 1);
      // register hits when the beam crosses a target
      if (prevY >= 0 && y > prevY) {
        for (const t of targets) {
          if (t.y > prevY && t.y <= y) hits.push({ x: t.x, y: t.y, born: ts, accent: t.accent });
        }
      }
      prevY = y < prevY ? -1 : y;                 // reset at wrap-around
      // hit blips: a brief expanding tick
      for (const hit of hits) {
        const t = (ts - hit.born) / HIT_LIFE;
        if (t >= 1) continue;
        const a = (1 - t) * (hit.accent ? 0.55 : 0.3);
        const r = 2 + t * 10;
        ctx.beginPath(); ctx.arc(hit.x, hit.y, r, 0, 7);
        ctx.strokeStyle = hit.accent ? `rgba(198,61,31,${a})` : `rgba(${line},${a})`;
        ctx.lineWidth = 1;
        ctx.stroke();
        ctx.beginPath(); ctx.arc(hit.x, hit.y, 1.4, 0, 7);
        ctx.fillStyle = hit.accent ? `rgba(198,61,31,${a + 0.2})` : `rgba(${line},${a + 0.15})`;
        ctx.fill();
      }
      hits = hits.filter((hh) => ts - hh.born < HIT_LIFE);
    }
    function step(ts) {
      raf = requestAnimationFrame(step);
      draw(ts);
    }

    readColors(); resize();
    if (reduce) draw(PERIOD * 0.35); else raf = requestAnimationFrame(step);
    addEventListener('resize', () => { readColors(); resize(); if (reduce) draw(PERIOD * 0.35); }, { passive: true });
    onThemeChange(() => { readColors(); if (reduce) draw(PERIOD * 0.35); });
    onVisibility(() => cancelAnimationFrame(raf), () => { raf = requestAnimationFrame(step); });
  }

  /* ── 1f. Aurora (calm drifting glows) — default ───────────────────── */
  function aurora() {
    const el = document.createElement('div');
    el.className = 'fx-aurora';
    el.setAttribute('aria-hidden', 'true');
    el.innerHTML = '<b class="b1"></b><b class="b2"></b><b class="b3"></b>';
    document.body.prepend(el);                  // motion + reduced-motion handled in CSS
  }

  function background() {
    const page = (location.pathname.split('/').pop() || 'index.html').toLowerCase();
    // ?bg= wins (handy for previewing), then <body data-bg>, then the page default.
    const qbg = new URLSearchParams(location.search).get('bg');
    const mode = qbg || document.body.dataset.bg || ({
      'consulting.html': 'flow',
    }[page] || 'mesh');
    ({ mesh: constellation, rain, flow, aurora, sonar, scan }[mode] || aurora)();
  }

  /* ── 2. Scroll-reveal ─────────────────────────────────────────────── */
  function reveal() {
    if (reduce) return;
    const SEL = '.section-label,.intro,.areas,.why,.why-list,.service-card,.uc-card,'
      + '.step,.pkg,.pkg-note,.faq-item,.cta,.credential-card,.cert-card,.credentials,.certs';
    const io = new IntersectionObserver((entries) => {
      for (const e of entries) {
        if (e.isIntersecting) { e.target.classList.add('reveal-in'); io.unobserve(e.target); }
      }
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    const fold = innerHeight * 0.92;
    document.querySelectorAll(SEL).forEach((el) => {
      if (el.getBoundingClientRect().top > fold) {
        el.style.animation = 'none';     // cancel the one-shot load animation
        el.classList.add('reveal');
        io.observe(el);
      }
    });
  }

  /* ── 3. Cursor spotlight ──────────────────────────────────────────── */
  function spotlight() {
    if (reduce || matchMedia('(hover: none)').matches) return;
    const SEL = '.service-card,.uc-card,.pkg,.project-card,.cert-card';
    document.addEventListener('pointermove', (e) => {
      const card = e.target.closest && e.target.closest(SEL);
      if (!card) return;
      const r = card.getBoundingClientRect();
      card.style.setProperty('--mx', ((e.clientX - r.left) / r.width * 100) + '%');
      card.style.setProperty('--my', ((e.clientY - r.top) / r.height * 100) + '%');
    }, { passive: true });
  }

  function start() { background(); reveal(); spotlight(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
