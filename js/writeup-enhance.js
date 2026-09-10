// Writeup enhancements: reading progress bar, floating TOC,
// copy-to-clipboard buttons, series banner, related-posts strip.
// Standalone (no deps); loaded by every writeup HTML after writeup-sidebar.js.
(function () {
  if (window.__sp1r4WriteupEnhanced) return;
  window.__sp1r4WriteupEnhanced = true;

  const POSTS_URL = '../posts.json';

  function currentSlug() {
    const file = (location.pathname.split('/').pop() || '').replace(/\.html$/i, '');
    return file;
  }

  function slugify(s) {
    return (s || '')
      .toLowerCase()
      .replace(/[^\w\s-]/g, '')
      .trim()
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .slice(0, 60);
  }

  function injectStyles() {
    if (document.getElementById('sp1r4-enhance-style')) return;
    const css = `
      /* Reading progress bar */
      .sp1r4-progress {
        position: fixed; top: 0; left: 0; height: 2px; width: 0;
        background: #c63d1f; z-index: 10000;
        transition: width 0.05s linear;
        will-change: width;
      }

      /* Floating TOC — sits below the fixed 48px site nav. */
      .sp1r4-toc-toggle {
        position: fixed; top: 66px; right: 18px; z-index: 51;
        width: 38px; height: 38px;
        background: rgba(26,26,24,0.92); color: #eae8e3;
        border: 1px solid rgba(234,232,227,0.15); border-radius: 4px;
        cursor: pointer; display: flex; align-items: center; justify-content: center;
        backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px);
        transition: background 0.18s;
      }
      .sp1r4-toc-toggle:hover { background: rgba(26,26,24,1); }
      .sp1r4-toc-toggle svg { width: 18px; height: 18px; stroke: currentColor; fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }

      .sp1r4-toc-panel {
        position: fixed; top: 112px; right: 18px; z-index: 51;
        width: 280px; max-height: calc(100vh - 144px);
        background: rgba(20,20,20,0.96);
        border: 1px solid rgba(255,255,255,0.10); border-radius: 6px;
        backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px);
        font-family: 'Inter','Barlow',system-ui,sans-serif;
        padding: 14px 12px; overflow-y: auto;
        opacity: 0; pointer-events: none; transform: translateY(-6px);
        transition: opacity 0.18s, transform 0.18s;
      }
      .sp1r4-toc-panel.open { opacity: 1; pointer-events: auto; transform: translateY(0); }
      .sp1r4-toc-panel h3 {
        font-size: 10px; font-weight: 600; letter-spacing: 0.18em;
        color: rgba(255,255,255,0.45); text-transform: uppercase;
        margin: 0 6px 10px; padding: 0;
      }
      .sp1r4-toc-list { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 1px; }
      .sp1r4-toc-list a {
        display: block; padding: 7px 10px; border-radius: 3px;
        text-decoration: none; color: rgba(234,232,227,0.78);
        font-size: 12px; font-weight: 500; line-height: 1.35;
        border-left: 2px solid transparent;
      }
      .sp1r4-toc-list a:hover { background: rgba(255,255,255,0.05); color: #fff; }
      .sp1r4-toc-list a.active {
        background: rgba(198,61,31,0.10); border-left-color: #c63d1f; color: #fff;
      }
      .sp1r4-toc-list .lvl-3 { padding-left: 22px; font-size: 11px; color: rgba(234,232,227,0.62); }

      /* Copy button on code/terminal blocks */
      .sp1r4-copyable { position: relative; }
      .sp1r4-copy-btn {
        position: absolute; top: 8px; right: 8px; z-index: 5;
        font-family: 'JetBrains Mono','Inter',monospace;
        font-size: 10px; font-weight: 600; letter-spacing: 0.06em;
        padding: 5px 9px; border-radius: 3px;
        background: rgba(26,26,24,0.78); color: #eae8e3;
        border: 1px solid rgba(234,232,227,0.18);
        cursor: pointer; opacity: 0;
        transition: opacity 0.15s, background 0.15s;
      }
      .sp1r4-copyable:hover .sp1r4-copy-btn,
      .sp1r4-copy-btn:focus-visible { opacity: 1; }
      .sp1r4-copy-btn:hover { background: rgba(26,26,24,1); }
      .sp1r4-copy-btn.copied { background: #3a6a48; border-color: #3a6a48; color: #fff; }

      /* Series banner */
      .sp1r4-series {
        margin: 1.4rem 0 2rem;
        padding: 0.9rem 1.1rem;
        background: rgba(198,61,31,0.06);
        border: 1px solid rgba(198,61,31,0.2);
        border-left: 3px solid #c63d1f;
        border-radius: 5px;
        font-family: 'Barlow','Inter',system-ui,sans-serif;
        font-size: 0.85rem; color: #555550;
        display: flex; flex-wrap: wrap; gap: 6px 14px;
        align-items: center; justify-content: space-between;
      }
      .sp1r4-series-label {
        font-family: 'Barlow Condensed','Barlow',sans-serif;
        font-weight: 700; font-size: 0.72rem; letter-spacing: 0.14em;
        text-transform: uppercase; color: #c63d1f;
      }
      .sp1r4-series-title { color: #1a1a18; font-weight: 600; }
      .sp1r4-series-nav { display: flex; gap: 12px; flex-wrap: wrap; }
      .sp1r4-series-nav a {
        color: #c63d1f; text-decoration: none;
        font-size: 0.78rem; font-weight: 600; letter-spacing: 0.04em;
      }
      .sp1r4-series-nav a:hover { text-decoration: underline; }
      .sp1r4-series-nav a[aria-disabled="true"] { color: #aaa89f; pointer-events: none; }

      /* Share row */
      .sp1r4-share {
        margin: 2.4rem 0 1rem;
        display: flex; gap: 8px; flex-wrap: wrap;
        align-items: center; justify-content: center;
        font-family: 'Barlow','Inter',system-ui,sans-serif;
      }
      .sp1r4-share-label {
        font-family: 'Barlow Condensed','Barlow',sans-serif;
        font-weight: 700; font-size: 0.72rem; letter-spacing: 0.14em;
        text-transform: uppercase; color: #888880;
        margin-right: 6px;
      }
      .sp1r4-share-btn {
        display: inline-flex; align-items: center; gap: 6px;
        padding: 6px 12px; border-radius: 4px;
        background: rgba(26,26,24,0.04);
        border: 1px solid rgba(26,26,24,0.12);
        color: #1a1a18; text-decoration: none; cursor: pointer;
        font-size: 0.78rem; font-weight: 500; letter-spacing: 0.02em;
        transition: background 0.15s, border-color 0.15s, transform 0.15s;
      }
      .sp1r4-share-btn:hover {
        background: rgba(198,61,31,0.08);
        border-color: rgba(198,61,31,0.4);
        transform: translateY(-1px);
        text-decoration: none;
      }
      .sp1r4-share-btn svg {
        width: 13px; height: 13px;
        stroke: currentColor; fill: none; stroke-width: 1.6;
        stroke-linecap: round; stroke-linejoin: round;
      }
      .sp1r4-share-btn.copied {
        background: #3a6a48; border-color: #3a6a48; color: #fff;
      }

      /* Related posts */
      .sp1r4-related {
        margin: 3rem 0 1.5rem;
        padding-top: 2rem;
        border-top: 1px solid rgba(26,26,24,0.12);
        font-family: 'Barlow','Inter',system-ui,sans-serif;
      }
      .sp1r4-related h3 {
        font-family: 'Barlow Condensed','Barlow',sans-serif;
        font-weight: 800; font-size: 1.4rem; letter-spacing: 0.04em;
        text-transform: uppercase; color: #1a1a18; margin-bottom: 1rem;
      }
      .sp1r4-related-grid {
        display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
        gap: 12px;
      }
      .sp1r4-related-card {
        display: block; padding: 14px 16px;
        background: rgba(26,26,24,0.04);
        border: 1px solid rgba(26,26,24,0.10);
        border-radius: 5px; text-decoration: none;
        transition: background 0.15s, border-color 0.15s, transform 0.15s;
      }
      .sp1r4-related-card:hover {
        background: rgba(26,26,24,0.08);
        border-color: rgba(198,61,31,0.4);
        transform: translateY(-2px);
        text-decoration: none;
      }
      .sp1r4-related-tag {
        font-size: 0.65rem; font-weight: 700; letter-spacing: 0.14em;
        text-transform: uppercase; color: #c63d1f;
      }
      .sp1r4-related-title {
        font-size: 0.95rem; font-weight: 600; color: #1a1a18;
        margin: 4px 0 4px; line-height: 1.3;
      }
      .sp1r4-related-meta {
        font-size: 0.72rem; color: #888880; letter-spacing: 0.04em;
      }

      /* Hide TOC button when sidebar is open on narrow screens (would overlap close target) */
      @media (max-width: 1099px) {
        .sp1r4-toc-panel { right: 12px; width: calc(100vw - 24px); max-width: 320px; }
      }

      /* Image lightbox */
      .sp1r4-lightbox {
        position: fixed; inset: 0; z-index: 10001;
        background: rgba(0,0,0,0.92);
        display: flex; align-items: center; justify-content: center;
        padding: 40px;
        opacity: 0; transition: opacity 0.18s ease;
        cursor: zoom-out;
        backdrop-filter: blur(4px);
        -webkit-backdrop-filter: blur(4px);
      }
      .sp1r4-lightbox.open { opacity: 1; }
      .sp1r4-lightbox img {
        max-width: 100%; max-height: 100%;
        object-fit: contain;
        box-shadow: 0 20px 60px rgba(0,0,0,0.6);
        transform: scale(0.96);
        transition: transform 0.18s ease;
      }
      .sp1r4-lightbox.open img { transform: scale(1); }
      .sp1r4-lightbox-close {
        position: absolute; top: 18px; right: 18px;
        width: 38px; height: 38px; border-radius: 50%;
        background: rgba(255,255,255,0.08);
        border: 1px solid rgba(255,255,255,0.18);
        color: #fff; cursor: pointer;
        display: flex; align-items: center; justify-content: center;
        font-family: inherit; font-size: 20px; line-height: 1;
        transition: background 0.15s;
      }
      .sp1r4-lightbox-close:hover { background: rgba(255,255,255,0.16); }
      .sp1r4-lightbox-hint {
        position: absolute; bottom: 18px; left: 50%; transform: translateX(-50%);
        color: rgba(255,255,255,0.45);
        font-family: 'Barlow Condensed','Barlow',sans-serif;
        font-size: 11px; font-weight: 600; letter-spacing: 0.18em;
        text-transform: uppercase;
      }
      [data-lightboxable] { cursor: zoom-in; }

      @media (prefers-reduced-motion: reduce) {
        .sp1r4-progress, .sp1r4-toc-panel, .sp1r4-copy-btn,
        .sp1r4-related-card, .sp1r4-share-btn { transition: none !important; }
        .sp1r4-related-card:hover, .sp1r4-share-btn:hover { transform: none !important; }
      }

      /* Print: strip nav/chrome so saved PDFs look clean. */
      @media print {
        .sp1r4-progress, .sp1r4-toc-toggle, .sp1r4-toc-panel,
        .sp1r4-copy-btn, .sp1r4-share, .sp1r4-related,
        .sp1r4-series-nav { display: none !important; }
        body { padding-left: 0 !important; padding-top: 0 !important; background: #fff !important; }
        h1, h2, h3, h4 { page-break-after: avoid; }
        .term-wrap, .terminal, pre, figure, img {
          page-break-inside: avoid;
          max-width: 100% !important;
        }
        a[href^="http"]::after {
          content: " (" attr(href) ")";
          font-size: 0.82em; color: #555;
          word-break: break-all;
        }
      }
    `;
    const style = document.createElement('style');
    style.id = 'sp1r4-enhance-style';
    style.textContent = css;
    document.head.appendChild(style);
  }

  // 1. Reading progress bar
  function setupProgress() {
    const bar = document.createElement('div');
    bar.className = 'sp1r4-progress';
    bar.setAttribute('aria-hidden', 'true');
    document.body.appendChild(bar);

    function update() {
      const h = document.documentElement;
      const max = (h.scrollHeight - h.clientHeight) || 1;
      const pct = Math.max(0, Math.min(100, (h.scrollTop / max) * 100));
      bar.style.width = pct + '%';
    }
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update, { passive: true });
    update();
  }

  // 2. Floating TOC built from h2/h3
  function setupTOC() {
    const headings = Array.from(document.querySelectorAll('h2, h3'))
      .filter(h => {
        if (h.closest('nav, footer, .sp1r4-related, .sp1r4-series, .sp1r4-toc-panel')) return false;
        const txt = (h.textContent || '').trim();
        if (!txt) return false;
        return true;
      });
    if (headings.length < 3) return;

    const usedIds = new Set(Array.from(document.querySelectorAll('[id]')).map(e => e.id));
    headings.forEach(h => {
      if (!h.id) {
        let base = slugify(h.textContent) || 'section';
        let id = base, n = 2;
        while (usedIds.has(id)) { id = base + '-' + (n++); }
        h.id = id;
        usedIds.add(id);
      }
    });

    const toggle = document.createElement('button');
    toggle.className = 'sp1r4-toc-toggle';
    toggle.type = 'button';
    toggle.setAttribute('aria-label', 'Table of contents');
    toggle.setAttribute('aria-expanded', 'false');
    toggle.innerHTML = '<svg viewBox="0 0 24 24"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><circle cx="4" cy="6" r="1"/><circle cx="4" cy="12" r="1"/><circle cx="4" cy="18" r="1"/></svg>';

    const panel = document.createElement('aside');
    panel.className = 'sp1r4-toc-panel';
    panel.setAttribute('aria-label', 'Table of contents');
    const heading = document.createElement('h3');
    heading.textContent = 'On this page';
    panel.appendChild(heading);
    const ul = document.createElement('ul');
    ul.className = 'sp1r4-toc-list';
    headings.forEach(h => {
      const li = document.createElement('li');
      li.className = 'lvl-' + h.tagName.charAt(1);
      const a = document.createElement('a');
      a.href = '#' + h.id;
      a.textContent = (h.textContent || '').trim();
      a.dataset.targetId = h.id;
      li.appendChild(a);
      ul.appendChild(li);
    });
    panel.appendChild(ul);

    function close() { panel.classList.remove('open'); toggle.setAttribute('aria-expanded', 'false'); }
    function open() { panel.classList.add('open'); toggle.setAttribute('aria-expanded', 'true'); }
    toggle.addEventListener('click', () => panel.classList.contains('open') ? close() : open());
    panel.addEventListener('click', (e) => {
      if (e.target.tagName === 'A') close();
    });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });
    document.addEventListener('click', (e) => {
      if (!panel.contains(e.target) && !toggle.contains(e.target)) close();
    });

    document.body.appendChild(toggle);
    document.body.appendChild(panel);

    // Active section tracking
    const links = panel.querySelectorAll('a');
    if ('IntersectionObserver' in window) {
      const byId = new Map();
      links.forEach(a => byId.set(a.dataset.targetId, a));
      const visible = new Set();
      const io = new IntersectionObserver((entries) => {
        entries.forEach(en => {
          if (en.isIntersecting) visible.add(en.target.id);
          else visible.delete(en.target.id);
        });
        const orderedIds = headings.map(h => h.id);
        const firstVisible = orderedIds.find(id => visible.has(id));
        links.forEach(a => a.classList.remove('active'));
        if (firstVisible && byId.has(firstVisible)) byId.get(firstVisible).classList.add('active');
      }, { rootMargin: '-72px 0px -65% 0px', threshold: 0 });
      headings.forEach(h => io.observe(h));
    }
  }

  // 2.5. Image lightbox — click any content image for fullscreen view.
  function setupImageLightbox() {
    document.querySelectorAll('img').forEach(img => {
      if (img.closest('nav, footer, .sp1r4-sidebar, .sp1r4-related, .sp1r4-toc-panel, .sp1r4-share, .writeup-back-link')) return;
      if (img.dataset.lightboxAttached === '1') return;
      // Skip tiny/decorative images (icons, badges)
      const w = img.naturalWidth || img.width || 0;
      const h = img.naturalHeight || img.height || 0;
      if (w && w < 200 && h && h < 200) return;
      img.dataset.lightboxAttached = '1';
      img.setAttribute('data-lightboxable', '');
      img.addEventListener('click', (e) => {
        e.preventDefault();
        openLightbox(img);
      });
    });
  }

  function openLightbox(img) {
    const overlay = document.createElement('div');
    overlay.className = 'sp1r4-lightbox';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Image viewer');

    const full = document.createElement('img');
    full.src = img.currentSrc || img.src;
    full.alt = img.alt || '';
    overlay.appendChild(full);

    const close = document.createElement('button');
    close.className = 'sp1r4-lightbox-close';
    close.type = 'button';
    close.setAttribute('aria-label', 'Close image viewer');
    close.innerHTML = '&times;';
    overlay.appendChild(close);

    const hint = document.createElement('div');
    hint.className = 'sp1r4-lightbox-hint';
    hint.textContent = 'Click anywhere or press Esc to close';
    overlay.appendChild(hint);

    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    function shut() {
      overlay.classList.remove('open');
      setTimeout(() => {
        overlay.remove();
        document.body.style.overflow = prevOverflow;
        document.removeEventListener('keydown', onKey);
      }, 180);
    }
    function onKey(e) { if (e.key === 'Escape') shut(); }
    overlay.addEventListener('click', (e) => {
      // Close on overlay or close-button; don't close when clicking image itself for now
      if (e.target === overlay || e.target === close) shut();
    });
    document.addEventListener('keydown', onKey);

    document.body.appendChild(overlay);
    requestAnimationFrame(() => overlay.classList.add('open'));
  }

  // 3. Copy-to-clipboard on code/terminal blocks
  function setupCopyButtons() {
    const candidates = [];
    document.querySelectorAll('.term-wrap, .terminal').forEach(el => candidates.push(el));
    document.querySelectorAll('pre').forEach(pre => {
      if (pre.closest('.term-wrap, .terminal, .sp1r4-copyable')) return;
      candidates.push(pre);
    });

    candidates.forEach(target => {
      if (target.dataset.copyAttached === '1') return;
      target.dataset.copyAttached = '1';
      target.classList.add('sp1r4-copyable');

      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'sp1r4-copy-btn';
      btn.textContent = 'COPY';
      btn.setAttribute('aria-label', 'Copy code to clipboard');

      btn.addEventListener('click', async (e) => {
        e.preventDefault();
        e.stopPropagation();
        const src = target.querySelector('pre, .term-body, code') || target;
        const text = (src.innerText || src.textContent || '').replace(/ /g, ' ').trimEnd();
        try {
          if (navigator.clipboard && window.isSecureContext) {
            await navigator.clipboard.writeText(text);
          } else {
            const ta = document.createElement('textarea');
            ta.value = text; ta.style.position = 'fixed'; ta.style.left = '-9999px';
            document.body.appendChild(ta); ta.select();
            document.execCommand('copy'); document.body.removeChild(ta);
          }
          btn.textContent = 'COPIED';
          btn.classList.add('copied');
          setTimeout(() => { btn.textContent = 'COPY'; btn.classList.remove('copied'); }, 1600);
        } catch {
          btn.textContent = 'ERR';
          setTimeout(() => { btn.textContent = 'COPY'; }, 1600);
        }
      });

      target.appendChild(btn);
    });
  }

  // Load the global Ctrl+K search script (shared with the main pages).
  function loadGlobalSearch() {
    if (document.querySelector('script[data-sp1r4-search]')) return;
    const s = document.createElement('script');
    s.src = '/js/search.js';
    s.defer = true;
    s.setAttribute('data-sp1r4-search', '1');
    document.head.appendChild(s);
  }

  // 3.5. Reading-position resume — restore scroll % per slug across visits.
  function setupReadingResume() {
    const key = 'sp1r4-resume:' + currentSlug();
    const max = () => Math.max(0, document.documentElement.scrollHeight - window.innerHeight);

    try {
      const pct = parseFloat(localStorage.getItem(key));
      if (Number.isFinite(pct) && pct > 0.05 && pct < 0.95) {
        const restore = () => {
          const m = max();
          if (m > 0) window.scrollTo({ top: m * pct, behavior: 'instant' });
        };
        if (document.readyState === 'complete') restore();
        else window.addEventListener('load', restore, { once: true });
      }
    } catch {}

    let pending = null;
    window.addEventListener('scroll', () => {
      if (pending) return;
      pending = setTimeout(() => {
        try {
          const m = max();
          const pct = m > 0 ? window.scrollY / m : 0;
          if (pct > 0.95 || pct < 0.02) localStorage.removeItem(key);
          else localStorage.setItem(key, pct.toFixed(3));
        } catch {}
        pending = null;
      }, 800);
    }, { passive: true });
  }

  // 4. Share row — X, LinkedIn
  function setupShare(title) {
    const url = location.href;
    const enc = encodeURIComponent;
    const text = (title || document.title || '').trim();

    const sec = document.createElement('div');
    sec.className = 'sp1r4-share';

    const label = document.createElement('span');
    label.className = 'sp1r4-share-label';
    label.textContent = 'Share';
    sec.appendChild(label);

    function mkLink(href, name, iconSvg, opts) {
      const a = document.createElement('a');
      a.className = 'sp1r4-share-btn';
      a.href = href;
      if (opts && opts.newTab !== false) { a.target = '_blank'; a.rel = 'noopener noreferrer'; }
      a.innerHTML = iconSvg + '<span>' + name + '</span>';
      return a;
    }

    const xIcon = '<svg viewBox="0 0 24 24"><path d="M4 4l16 16M20 4L4 20"/></svg>';
    const liIcon = '<svg viewBox="0 0 24 24"><path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z"/><rect x="2" y="9" width="4" height="12"/><circle cx="4" cy="4" r="2"/></svg>';

    sec.appendChild(mkLink(
      'https://twitter.com/intent/tweet?text=' + enc(text) + '&url=' + enc(url),
      'X', xIcon
    ));
    sec.appendChild(mkLink(
      'https://www.linkedin.com/sharing/share-offsite/?url=' + enc(url),
      'LinkedIn', liIcon
    ));
    // Insert before related-posts section if present, otherwise before footer
    const related = document.querySelector('.sp1r4-related');
    if (related && related.parentNode) {
      related.parentNode.insertBefore(sec, related);
    } else {
      const footer = document.querySelector('footer');
      if (footer && footer.parentNode) footer.parentNode.insertBefore(sec, footer);
      else document.body.appendChild(sec);
    }
  }

  // 5. Series banner + 6. Related posts (depend on posts.json)
  function setupPostsAware(posts) {
    const slug = currentSlug();
    const here = posts.find(p => p.slug === slug);
    if (!here) return;

    if (here.series) {
      const inSeries = posts
        .filter(p => p.series === here.series)
        .sort((a, b) => (a.series_order || 0) - (b.series_order || 0));
      const idx = inSeries.findIndex(p => p.slug === slug);
      if (idx >= 0 && inSeries.length > 1) {
        const prev = inSeries[idx - 1];
        const next = inSeries[idx + 1];
        const banner = document.createElement('div');
        banner.className = 'sp1r4-series';
        const left = document.createElement('div');
        const label = document.createElement('span');
        label.className = 'sp1r4-series-label';
        const seriesName = (here.series_name) || here.series;
        label.textContent = 'Part ' + (idx + 1) + ' of ' + inSeries.length + ' · ' + seriesName;
        left.appendChild(label);
        const nav = document.createElement('div');
        nav.className = 'sp1r4-series-nav';
        const prevA = document.createElement('a');
        prevA.textContent = '← ' + (prev ? prev.title : 'Start');
        if (prev) {
          prevA.href = (prev.html || '').split('/').pop() || '#';
        } else {
          prevA.setAttribute('aria-disabled', 'true');
          prevA.href = '#';
        }
        const nextA = document.createElement('a');
        nextA.textContent = (next ? next.title : 'End') + ' →';
        if (next) {
          nextA.href = (next.html || '').split('/').pop() || '#';
        } else {
          nextA.setAttribute('aria-disabled', 'true');
          nextA.href = '#';
        }
        nav.appendChild(prevA);
        nav.appendChild(nextA);
        banner.appendChild(left);
        banner.appendChild(nav);

        const anchor = document.querySelector('.thesis-card, .post-header, h1.post-title, h1');
        if (anchor && anchor.parentNode) {
          if (anchor.classList.contains('thesis-card') || anchor.classList.contains('post-header')) {
            anchor.parentNode.insertBefore(banner, anchor);
          } else {
            anchor.parentNode.insertBefore(banner, anchor.nextSibling);
          }
        } else {
          document.body.insertBefore(banner, document.body.firstChild);
        }
      }
    }

    // Related: same-tag, exclude current, exclude same-series duplicates of immediate prev/next
    const tags = new Set(here.tags || []);
    const candidates = posts
      .filter(p => p.slug !== slug)
      .map(p => {
        const overlap = (p.tags || []).filter(t => tags.has(t)).length;
        return { p, overlap };
      })
      .filter(x => x.overlap > 0)
      .sort((a, b) => b.overlap - a.overlap || (b.p.date || '').localeCompare(a.p.date || ''))
      .slice(0, 3)
      .map(x => x.p);

    if (candidates.length) {
      const sec = document.createElement('section');
      sec.className = 'sp1r4-related';
      const h = document.createElement('h3');
      h.textContent = 'Related writeups';
      sec.appendChild(h);
      const grid = document.createElement('div');
      grid.className = 'sp1r4-related-grid';
      candidates.forEach(p => {
        const card = document.createElement('a');
        card.className = 'sp1r4-related-card';
        card.href = (p.html || '').split('/').pop() || '#';
        const tag = document.createElement('div');
        tag.className = 'sp1r4-related-tag';
        tag.textContent = (p.tags && p.tags[0]) || '';
        const t = document.createElement('div');
        t.className = 'sp1r4-related-title';
        t.textContent = p.title || p.slug;
        const meta = document.createElement('div');
        meta.className = 'sp1r4-related-meta';
        const parts = [];
        if (p.date) {
          try { parts.push(new Date(p.date + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })); }
          catch { parts.push(p.date); }
        }
        if (p.reading_time) parts.push(p.reading_time + ' min read');
        meta.textContent = parts.join(' · ');
        card.appendChild(tag);
        card.appendChild(t);
        card.appendChild(meta);
        grid.appendChild(card);
      });
      sec.appendChild(grid);

      const footer = document.querySelector('footer');
      if (footer && footer.parentNode) {
        footer.parentNode.insertBefore(sec, footer);
      } else {
        document.body.appendChild(sec);
      }
    }
  }

  function init() {
    injectStyles();
    setupProgress();
    setupTOC();
    setupImageLightbox();
    setupCopyButtons();
    setupReadingResume();
    loadGlobalSearch();
    fetch(POSTS_URL, { cache: 'no-cache' })
      .then(r => r.ok ? r.json() : [])
      .then(posts => {
        let title = null;
        if (Array.isArray(posts) && posts.length) {
          const here = posts.find(p => p.slug === currentSlug());
          if (here) title = here.title;
          setupPostsAware(posts);
        }
        setupShare(title);
      })
      .catch(() => { setupShare(null); });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
