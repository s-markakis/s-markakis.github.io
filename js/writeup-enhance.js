// Writeup enhancements: reading progress bar, floating TOC,
// copy/wrap buttons on code blocks, series navigation, author card,
// share row, related-posts strip. Greek twins get Greek labels and links.
// Standalone (no deps); loaded by every writeup HTML after writeup-sidebar.js.
(function () {
  if (window.__sp1r4WriteupEnhanced) return;
  window.__sp1r4WriteupEnhanced = true;

  const POSTS_URL = '../posts.json';

  function currentSlug() {
    const file = (location.pathname.split('/').pop() || '').replace(/\.html$/i, '');
    return file;
  }

  // Greek twins are separate static files named <slug>-el.html. Keyed on the
  // filename: <html lang> is not reliable here until i18n.js has run.
  const IS_EL = /-el$/.test((location.pathname.split('/').pop() || '').replace(/\.html$/i, ''));
  const STR = IS_EL ? {
    toc: 'Σε αυτή τη σελίδα', share: 'Κοινοποίηση', related: 'Σχετικά writeups',
    part: (i, n) => 'Μέρος ' + i + ' από ' + n, start: 'Αρχή', end: 'Τέλος',
    prev: 'Προηγούμενο', next: 'Επόμενο', allParts: 'Όλη η σειρά →', minRead: ' λεπτά ανάγνωση',
    copy: 'COPY', copied: 'COPIED', wrap: 'WRAP',
    copyAria: 'Αντιγραφή κώδικα', wrapAria: 'Αναδίπλωση μεγάλων γραμμών',
    writtenBy: 'Γράφτηκε από',
    authorBio: 'Penetration tester και μηχανικός δικτύων με βάση την Κρήτη. Αν θέλεις έλεγχο αυτού του είδους στο δικό σου περιβάλλον, με υπογεγραμμένο scope, επικοινώνησε.',
    authorPentest: 'Penetration testing →', authorMore: 'Περισσότερα writeups →',
    locale: 'el-GR',
  } : {
    toc: 'On this page', share: 'Share', related: 'Related writeups',
    part: (i, n) => 'Part ' + i + ' of ' + n, start: 'Start', end: 'End',
    prev: 'Previous', next: 'Next', allParts: 'Full series →', minRead: ' min read',
    copy: 'COPY', copied: 'COPIED', wrap: 'WRAP',
    copyAria: 'Copy code to clipboard', wrapAria: 'Wrap long lines',
    writtenBy: 'Written by',
    authorBio: 'Penetration tester and network engineer based in Crete. If you want this kind of testing run against your own environment, under a signed scope, get in touch.',
    authorPentest: 'Penetration testing →', authorMore: 'More writeups →',
    locale: 'en-US',
  };

  const baseName = (path) => (path || '').split('/').pop();
  // Link to the Greek twin when reading in Greek and one exists.
  const hrefOf = (p) => baseName((IS_EL && p.html_el) || p.html) || '#';
  const titleOf = (p) => (IS_EL && p.title_el) || p.title || p.slug;

  // End-of-article blocks go inside the article column so they share its
  // width; falls back to "before the footer" on an unknown template.
  function appendEnd(el) {
    const h1 = document.querySelector('h1');
    const root = h1 && h1.closest('.wrap, .wrapper, main, article');
    if (root) { root.appendChild(el); return; }
    const footer = document.querySelector('footer');
    if (footer && footer.parentNode) footer.parentNode.insertBefore(el, footer);
    else document.body.appendChild(el);
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
      /* Theme tokens. Two writeup templates exist (--head/--body/--rule and
         --text-dark/--text/--border); declared on body, not :root, so the
         body.dark overrides of the underlying variables are picked up. */
      body {
        --sx-head: var(--head, var(--text-dark, #1a1a18));
        --sx-body: var(--body, var(--text, #6b675f));
        --sx-rule: var(--rule, var(--border, #e0deda));
        --sx-card: var(--card, var(--bg-code, #fff));
        --sx-term: var(--term-bg, var(--bg-term, #e8e6e0));
        --sx-accent: #c63d1f;
      }
      /* #c63d1f on #0f0f0f is 3.7:1; small accent text needs the lighter tone. */
      body.dark { --sx-accent: #e5674a; }

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
      /* The <pre> scrolls, not the wrapper, so the tools stay pinned while
         a long config line is scrolled sideways. */
      .term-wrap.sp1r4-copyable { overflow: hidden; }
      .term-wrap.sp1r4-copyable > pre { overflow-x: auto; }
      .sp1r4-code-tools {
        position: absolute; top: 8px; right: 8px; z-index: 5;
        display: flex; gap: 4px;
        opacity: 0.5; transition: opacity 0.15s;
      }
      .sp1r4-code-tools.in-bar { top: 2px; right: 4px; }
      .sp1r4-code-tools.in-flow { position: static; margin-left: 10px; flex: none; }
      .sp1r4-code-tools.in-flow .sp1r4-copy-btn { padding: 2px 8px; }
      .sp1r4-copyable:hover .sp1r4-code-tools,
      .sp1r4-code-tools:focus-within { opacity: 1; }
      @media (hover: none) { .sp1r4-code-tools { opacity: 0.85; } }
      .sp1r4-copy-btn {
        font-family: 'JetBrains Mono','Inter',monospace;
        font-size: 10px; font-weight: 600; letter-spacing: 0.06em;
        padding: 5px 9px; border-radius: 3px;
        background: rgba(26,26,24,0.86); color: #eae8e3;
        border: 1px solid rgba(234,232,227,0.18);
        cursor: pointer;
        transition: background 0.15s;
      }
      .sp1r4-copy-btn:hover { background: rgba(26,26,24,1); }
      .sp1r4-copy-btn.copied { background: #3a6a48; border-color: #3a6a48; color: #fff; }
      .sp1r4-wrap-btn { display: none; }
      .sp1r4-ovf .sp1r4-wrap-btn, .sp1r4-wrapped .sp1r4-wrap-btn { display: block; }
      .sp1r4-wrapped .sp1r4-wrap-btn { background: #c63d1f; border-color: #c63d1f; color: #fff; }
      .sp1r4-wrapped pre, .sp1r4-wrapped .term-body {
        white-space: pre-wrap !important; overflow-wrap: anywhere;
      }
      /* Right-edge fade: the only cue that a line continues when the OS
         hides scrollbars. Removed once scrolled to the end. */
      .sp1r4-ovf:not(.sp1r4-ovf-end)::after {
        content: ''; position: absolute; right: 0; bottom: 0;
        top: var(--sx-fade-top, 0px); width: 40px; pointer-events: none;
        background: linear-gradient(90deg, transparent, var(--sx-term));
      }
      .sp1r4-scroller:focus-visible { outline: 2px solid var(--sx-accent); outline-offset: -2px; }

      /* Current-section pill, left of the TOC toggle (only when it fits
         beside the article column; sized in JS). */
      .sp1r4-now {
        position: fixed; top: 66px; right: 64px; z-index: 51;
        height: 38px; padding: 0 12px; max-width: 240px;
        display: none; align-items: center;
        background: rgba(26,26,24,0.92); color: rgba(234,232,227,0.85);
        border: 1px solid rgba(234,232,227,0.15); border-radius: 4px;
        font-family: 'Inter',system-ui,sans-serif; font-size: 11px; font-weight: 500;
        white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
        cursor: pointer;
      }
      .sp1r4-now.show { display: block; line-height: 36px; }

      /* Series banner */
      .sp1r4-series {
        margin: 1.4rem 0 2rem;
        padding: 0.9rem 1.1rem;
        background: rgba(198,61,31,0.06);
        border: 1px solid rgba(198,61,31,0.2);
        border-left: 3px solid #c63d1f;
        border-radius: 5px;
        font-family: 'Barlow','Inter',system-ui,sans-serif;
        font-size: 0.85rem; color: var(--sx-body);
        display: flex; flex-wrap: wrap; gap: 6px 14px;
        align-items: center; justify-content: space-between;
      }
      .sp1r4-series-label {
        font-family: 'Barlow Condensed','Barlow',sans-serif;
        font-weight: 700; font-size: 0.72rem; letter-spacing: 0.14em;
        text-transform: uppercase; color: var(--sx-accent);
      }
      .sp1r4-series-label a { color: inherit; text-decoration: none; }
      .sp1r4-series-label a:hover { text-decoration: underline; }
      .sp1r4-series-title { color: var(--sx-head); font-weight: 600; }
      .sp1r4-series-nav { display: flex; gap: 12px; flex-wrap: wrap; }
      .sp1r4-series-nav a {
        color: var(--sx-accent); text-decoration: none;
        font-size: 0.78rem; font-weight: 600; letter-spacing: 0.04em;
      }
      .sp1r4-series-nav a:hover { text-decoration: underline; }
      .sp1r4-series-nav a[aria-disabled="true"] { color: var(--sx-body); opacity: 0.6; pointer-events: none; }

      /* End-of-article series navigation */
      .sp1r4-series-end {
        margin: 3rem 0 0; padding-top: 2rem;
        border-top: 1px solid var(--sx-rule);
        font-family: 'Inter',system-ui,sans-serif;
      }
      .sp1r4-series-end-head {
        display: flex; justify-content: space-between; align-items: baseline;
        gap: 12px; flex-wrap: wrap; margin-bottom: 0.9rem;
        font-family: 'Barlow Condensed','Barlow',sans-serif;
        font-weight: 700; font-size: 0.78rem; letter-spacing: 0.14em;
        text-transform: uppercase; color: var(--sx-body);
      }
      .sp1r4-series-end-head a { color: var(--sx-accent); text-decoration: none; }
      .sp1r4-series-end-head a:hover { text-decoration: underline; }
      .sp1r4-series-end-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
      @media (max-width: 560px) { .sp1r4-series-end-grid { grid-template-columns: 1fr; } }
      .sp1r4-series-end-card {
        display: block; padding: 14px 16px; text-decoration: none;
        background: var(--sx-card); border: 1px solid var(--sx-rule); border-radius: 5px;
        transition: border-color 0.15s, transform 0.15s;
      }
      .sp1r4-series-end-card:hover { border-color: var(--sx-accent); transform: translateY(-2px); text-decoration: none; }
      .sp1r4-series-end-card.next { text-align: right; grid-column: 2; }
      @media (max-width: 560px) { .sp1r4-series-end-card.next { grid-column: 1; } }
      .sp1r4-series-end-dir {
        font-size: 0.68rem; font-weight: 700; letter-spacing: 0.14em;
        text-transform: uppercase; color: var(--sx-accent);
      }
      .sp1r4-series-end-title { font-size: 0.98rem; font-weight: 600; color: var(--sx-head); margin-top: 4px; line-height: 1.3; }

      /* Author card — only on posts whose template has no .cta-card */
      .sp1r4-author {
        margin: 2.8rem 0 0; padding: 1.4rem 1.6rem;
        background: var(--sx-card); border: 1px solid var(--sx-rule);
        border-top: 3px solid #c63d1f; border-radius: 6px;
        font-family: 'Inter',system-ui,sans-serif;
      }
      .sp1r4-author-label {
        font-size: 0.68rem; font-weight: 700; letter-spacing: 0.14em;
        text-transform: uppercase; color: var(--sx-accent);
      }
      .sp1r4-author-name { font-size: 1.05rem; font-weight: 700; color: var(--sx-head); margin: 2px 0 6px; }
      .sp1r4-author p { font-size: 0.9rem; line-height: 1.6; color: var(--sx-body); margin: 0 0 0.9rem; }
      .sp1r4-author-links { display: flex; gap: 14px; flex-wrap: wrap; }
      .sp1r4-author-links a { color: var(--sx-accent); font-size: 0.85rem; font-weight: 600; text-decoration: none; }
      .sp1r4-author-links a:hover { text-decoration: underline; }

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
        text-transform: uppercase; color: var(--sx-body);
        margin-right: 6px;
      }
      .sp1r4-share-btn {
        display: inline-flex; align-items: center; gap: 6px;
        padding: 6px 12px; border-radius: 4px;
        background: var(--sx-card);
        border: 1px solid var(--sx-rule);
        color: var(--sx-head); text-decoration: none; cursor: pointer;
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
        border-top: 1px solid var(--sx-rule);
        font-family: 'Barlow','Inter',system-ui,sans-serif;
      }
      .sp1r4-related h3 {
        font-family: 'Barlow Condensed','Barlow',sans-serif;
        font-weight: 800; font-size: 1.4rem; letter-spacing: 0.04em;
        text-transform: uppercase; color: var(--sx-head); margin-bottom: 1rem;
      }
      .sp1r4-related-grid {
        display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
        gap: 12px;
      }
      .sp1r4-related-card {
        display: block; padding: 14px 16px;
        background: var(--sx-card);
        border: 1px solid var(--sx-rule);
        border-radius: 5px; text-decoration: none;
        transition: background 0.15s, border-color 0.15s, transform 0.15s;
      }
      .sp1r4-related-card:hover {
        border-color: var(--sx-accent);
        transform: translateY(-2px);
        text-decoration: none;
      }
      .sp1r4-related-tag {
        font-size: 0.65rem; font-weight: 700; letter-spacing: 0.14em;
        text-transform: uppercase; color: var(--sx-accent);
      }
      .sp1r4-related-title {
        font-size: 0.95rem; font-weight: 600; color: var(--sx-head);
        margin: 4px 0 4px; line-height: 1.3;
      }
      .sp1r4-related-meta {
        font-size: 0.72rem; color: var(--sx-body); letter-spacing: 0.04em;
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
        .sp1r4-progress, .sp1r4-toc-panel, .sp1r4-copy-btn, .sp1r4-code-tools,
        .sp1r4-related-card, .sp1r4-share-btn, .sp1r4-series-end-card { transition: none !important; }
        .sp1r4-related-card:hover, .sp1r4-share-btn:hover,
        .sp1r4-series-end-card:hover { transform: none !important; }
      }

      /* Print: strip nav/chrome so saved PDFs look clean. */
      @media print {
        .sp1r4-progress, .sp1r4-toc-toggle, .sp1r4-toc-panel,
        .sp1r4-code-tools, .sp1r4-share, .sp1r4-related, .sp1r4-now,
        .sp1r4-series-nav, .sp1r4-series-end, .sp1r4-author { display: none !important; }
        .sp1r4-ovf::after { display: none !important; }
        pre, .term-body { white-space: pre-wrap !important; overflow: visible !important; }
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
        if (h.closest('nav, footer, .sp1r4-related, .sp1r4-series, .sp1r4-toc-panel, .cta-card, .sp1r4-author')) return false;
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
    heading.textContent = STR.toc;
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

    // Active section = the last heading scrolled past the nav. (An
    // IntersectionObserver band loses the highlight between headings on
    // long sections; position lookup doesn't.)
    const links = panel.querySelectorAll('a');
    const byId = new Map();
    links.forEach(a => byId.set(a.dataset.targetId, a));

    const now = document.createElement('button');
    now.type = 'button';
    now.className = 'sp1r4-now';
    now.setAttribute('aria-hidden', 'true');
    now.tabIndex = -1;
    now.addEventListener('click', (e) => { e.stopPropagation(); open(); });
    document.body.appendChild(now);
    const column = headings[0].closest('.wrap, .wrapper, main, article');

    let ticking = false;
    function track() {
      ticking = false;
      let current = null, currentH2 = null;
      for (const h of headings) {
        if (h.getBoundingClientRect().top > 130) break;
        current = h;
        if (h.tagName === 'H2') currentH2 = h;
      }
      links.forEach(a => a.classList.remove('active'));
      if (current && byId.has(current.id)) byId.get(current.id).classList.add('active');

      // Pill only where there is free margin right of the article column.
      const free = column ? window.innerWidth - 64 - column.getBoundingClientRect().right - 12 : 0;
      if (currentH2 && free >= 150) {
        now.textContent = (currentH2.textContent || '').trim();
        now.style.maxWidth = Math.min(free, 260) + 'px';
        now.classList.add('show');
      } else {
        now.classList.remove('show');
      }
    }
    function onScroll() { if (!ticking) { ticking = true; requestAnimationFrame(track); } }
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll, { passive: true });
    track();
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

  // 3. Code/terminal blocks: copy, wrap toggle, horizontal-overflow cue
  function setupCopyButtons() {
    const hosts = [];
    document.querySelectorAll('.term-wrap, .terminal').forEach(el => hosts.push(el));
    document.querySelectorAll('pre').forEach(pre => {
      if (pre.closest('.term-wrap, .terminal, .sp1r4-copyable')) return;
      // A bare <pre> is its own scroller: wrap it so the tools neither
      // scroll away with the text nor end up inside the copied text.
      const box = document.createElement('div');
      pre.parentNode.insertBefore(box, pre);
      box.appendChild(pre);
      hosts.push(box);
    });

    const ro = ('ResizeObserver' in window) ? new ResizeObserver(entries => {
      entries.forEach(en => en.target.__sxCheck && en.target.__sxCheck());
    }) : null;

    hosts.forEach(host => {
      if (host.dataset.copyAttached === '1') return;
      host.dataset.copyAttached = '1';
      host.classList.add('sp1r4-copyable');

      const scrollers = () => Array.from(host.querySelectorAll('pre, .term-body'));
      // Vendor-tabbed blocks hold two <pre>; act on the one being shown.
      const active = () => scrollers().find(e => !e.hidden && e.offsetParent !== null) || scrollers()[0] || host;

      const tools = document.createElement('div');
      tools.className = 'sp1r4-code-tools';
      const bar = host.querySelector(':scope > .term-bar');
      const label = host.querySelector(':scope > .term-label');
      if (bar) {
        // Flex bar with the label pushed right: sit after it, in flow.
        tools.classList.add('in-flow');
        if (!bar.querySelector('.term-label')) tools.style.marginLeft = 'auto';
      } else if (label) {
        tools.classList.add('in-bar');
        label.style.paddingRight = '112px';
      }

      const wrapBtn = document.createElement('button');
      wrapBtn.type = 'button';
      wrapBtn.className = 'sp1r4-copy-btn sp1r4-wrap-btn';
      wrapBtn.textContent = STR.wrap;
      wrapBtn.setAttribute('aria-label', STR.wrapAria);
      wrapBtn.setAttribute('aria-pressed', 'false');

      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'sp1r4-copy-btn';
      btn.textContent = STR.copy;
      btn.setAttribute('aria-label', STR.copyAria);

      function check() {
        const sc = active();
        const ovf = sc.scrollWidth - sc.clientWidth > 4;
        host.classList.toggle('sp1r4-ovf', ovf);
        host.classList.toggle('sp1r4-ovf-end', ovf && sc.scrollLeft + sc.clientWidth >= sc.scrollWidth - 4);
        host.style.setProperty('--sx-fade-top', (sc === host ? 0 : sc.offsetTop) + 'px');
        if (ovf && sc.tabIndex !== 0) {
          // Keyboard users need focus to scroll an overflowing region.
          sc.tabIndex = 0;
          sc.classList.add('sp1r4-scroller');
        }
      }
      host.__sxCheck = check;
      scrollers().forEach(sc => sc.addEventListener('scroll', check, { passive: true }));
      // Vendor tabs / the build explorer swap content on click.
      host.addEventListener('click', () => setTimeout(check, 0));
      if (ro) ro.observe(host);
      const live = host.querySelector('.bx-cfg');
      if (live && 'MutationObserver' in window) {
        new MutationObserver(check).observe(live, { childList: true, characterData: true, subtree: true });
      }

      wrapBtn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        const on = host.classList.toggle('sp1r4-wrapped');
        wrapBtn.setAttribute('aria-pressed', on ? 'true' : 'false');
        check();
      });

      btn.addEventListener('click', async (e) => {
        e.preventDefault();
        e.stopPropagation();
        const src = active();
        const text = (src.innerText || src.textContent || '').replace(/\u00a0/g, ' ').trimEnd();
        try {
          if (navigator.clipboard && window.isSecureContext) {
            await navigator.clipboard.writeText(text);
          } else {
            const ta = document.createElement('textarea');
            ta.value = text; ta.style.position = 'fixed'; ta.style.left = '-9999px';
            document.body.appendChild(ta); ta.select();
            document.execCommand('copy'); document.body.removeChild(ta);
          }
          btn.textContent = STR.copied;
          btn.classList.add('copied');
          setTimeout(() => { btn.textContent = STR.copy; btn.classList.remove('copied'); }, 1600);
        } catch {
          btn.textContent = 'ERR';
          setTimeout(() => { btn.textContent = STR.copy; }, 1600);
        }
      });

      tools.appendChild(wrapBtn);
      tools.appendChild(btn);
      (bar || host).appendChild(tools);
      check();
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
    label.textContent = STR.share;
    sec.appendChild(label);

    function mkLink(href, name, iconSvg) {
      const a = document.createElement('a');
      a.className = 'sp1r4-share-btn';
      a.href = href;
      a.target = '_blank';
      a.rel = 'noopener noreferrer';
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
    appendEnd(sec);
  }

  // 5. Series: banner under the title + prev/next cards at the end.
  // Returns the slugs it already links, so "related" doesn't repeat them.
  function setupSeries(posts, here) {
    const shown = [];
    if (!here.series) return shown;
    const inSeries = posts
      .filter(p => p.series === here.series)
      .sort((a, b) => (a.series_order || 0) - (b.series_order || 0));
    const idx = inSeries.findIndex(p => p.slug === here.slug);
    if (idx < 0 || inSeries.length < 2) return shown;

    const prev = inSeries[idx - 1];
    const next = inSeries[idx + 1];
    if (prev) shown.push(prev.slug);
    if (next) shown.push(next.slug);
    const partText = STR.part(idx + 1, inSeries.length) + ' · ' + (here.series_name || here.series);
    // The series index is itself a post; resolve through it to get its Greek twin.
    let indexHref = null;
    if (here.series_index) {
      const indexPost = posts.find(p => p.html === here.series_index);
      indexHref = indexPost ? hrefOf(indexPost) : baseName(here.series_index);
    }

    const banner = document.createElement('div');
    banner.className = 'sp1r4-series';
    const label = document.createElement('span');
    label.className = 'sp1r4-series-label';
    if (indexHref) {
      const a = document.createElement('a');
      a.href = indexHref;
      a.textContent = partText;
      label.appendChild(a);
    } else {
      label.textContent = partText;
    }
    const nav = document.createElement('div');
    nav.className = 'sp1r4-series-nav';
    function navLink(p, text) {
      const a = document.createElement('a');
      a.textContent = text;
      if (p) a.href = hrefOf(p);
      else a.setAttribute('aria-disabled', 'true');
      return a;
    }
    nav.appendChild(navLink(prev, '← ' + (prev ? titleOf(prev) : STR.start)));
    nav.appendChild(navLink(next, (next ? titleOf(next) : STR.end) + ' →'));
    banner.appendChild(label);
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

    // End of article: where the reader actually decides what to open next.
    const end = document.createElement('nav');
    end.className = 'sp1r4-series-end';
    end.setAttribute('aria-label', here.series_name || here.series);
    const head = document.createElement('div');
    head.className = 'sp1r4-series-end-head';
    const headText = document.createElement('span');
    headText.textContent = partText;
    head.appendChild(headText);
    if (indexHref) {
      const all = document.createElement('a');
      all.href = indexHref;
      all.textContent = STR.allParts;
      head.appendChild(all);
    }
    end.appendChild(head);
    const grid = document.createElement('div');
    grid.className = 'sp1r4-series-end-grid';
    function card(p, dir, cls) {
      const a = document.createElement('a');
      a.className = 'sp1r4-series-end-card ' + cls;
      a.href = hrefOf(p);
      const d = document.createElement('div');
      d.className = 'sp1r4-series-end-dir';
      d.textContent = dir;
      const t = document.createElement('div');
      t.className = 'sp1r4-series-end-title';
      t.textContent = titleOf(p);
      a.appendChild(d);
      a.appendChild(t);
      return a;
    }
    if (prev) grid.appendChild(card(prev, '← ' + STR.prev, 'prev'));
    if (next) grid.appendChild(card(next, STR.next + ' →', 'next'));
    end.appendChild(grid);
    appendEnd(end);
    return shown;
  }

  // 6. Author card — the writeups built from the newer template end in a
  // hand-written .cta-card; the HTB template has nothing, so the reader
  // finishes the post with no idea who wrote it or how to reach them.
  function setupAuthor() {
    if (document.querySelector('.cta-card, .sp1r4-author')) return;
    const box = document.createElement('aside');
    box.className = 'sp1r4-author';
    const label = document.createElement('div');
    label.className = 'sp1r4-author-label';
    label.textContent = STR.writtenBy;
    const name = document.createElement('div');
    name.className = 'sp1r4-author-name';
    name.textContent = 'S. Markakis';
    const bio = document.createElement('p');
    bio.textContent = STR.authorBio;
    const links = document.createElement('div');
    links.className = 'sp1r4-author-links';
    const a1 = document.createElement('a');
    a1.href = IS_EL ? '/pentest-el.html' : '/pentest.html';
    a1.textContent = STR.authorPentest;
    const a2 = document.createElement('a');
    a2.href = '/blog.html';
    a2.textContent = STR.authorMore;
    links.appendChild(a1);
    links.appendChild(a2);
    box.appendChild(label);
    box.appendChild(name);
    box.appendChild(bio);
    box.appendChild(links);
    appendEnd(box);
  }

  // 7. Related posts by tag overlap
  function setupRelated(posts, here, exclude) {
    const skip = new Set(exclude || []);
    skip.add(here.slug);
    const tags = new Set(here.tags || []);
    const candidates = posts
      .filter(p => !skip.has(p.slug))
      .map(p => ({ p, overlap: (p.tags || []).filter(t => tags.has(t)).length }))
      .filter(x => x.overlap > 0)
      .sort((a, b) => b.overlap - a.overlap || (b.p.date || '').localeCompare(a.p.date || ''))
      .slice(0, 3)
      .map(x => x.p);
    if (!candidates.length) return;

    const sec = document.createElement('section');
    sec.className = 'sp1r4-related';
    const h = document.createElement('h3');
    h.textContent = STR.related;
    sec.appendChild(h);
    const grid = document.createElement('div');
    grid.className = 'sp1r4-related-grid';
    candidates.forEach(p => {
      const card = document.createElement('a');
      card.className = 'sp1r4-related-card';
      card.href = hrefOf(p);
      const tag = document.createElement('div');
      tag.className = 'sp1r4-related-tag';
      tag.textContent = (p.tags && p.tags[0]) || '';
      const t = document.createElement('div');
      t.className = 'sp1r4-related-title';
      t.textContent = titleOf(p);
      const meta = document.createElement('div');
      meta.className = 'sp1r4-related-meta';
      const parts = [];
      if (p.date) {
        try { parts.push(new Date(p.date + 'T00:00:00').toLocaleDateString(STR.locale, { month: 'short', day: 'numeric', year: 'numeric' })); }
        catch { parts.push(p.date); }
      }
      if (p.reading_time) parts.push(p.reading_time + STR.minRead);
      meta.textContent = parts.join(' · ');
      card.appendChild(tag);
      card.appendChild(t);
      card.appendChild(meta);
      grid.appendChild(card);
    });
    sec.appendChild(grid);
    appendEnd(sec);
  }

  function init() {
    injectStyles();
    setupProgress();
    setupTOC();
    setupImageLightbox();
    setupCopyButtons();
    setupReadingResume();
    loadGlobalSearch();
    // End-of-article order: series nav, author card, share, related.
    fetch(POSTS_URL, { cache: 'no-cache' })
      .then(r => r.ok ? r.json() : [])
      .catch(() => [])
      .then(posts => {
        const file = currentSlug() + '.html';
        const here = Array.isArray(posts)
          ? posts.find(p => baseName(p.html) === file || baseName(p.html_el) === file)
          : null;
        const linked = here ? setupSeries(posts, here) : [];
        setupAuthor();
        setupShare(here ? titleOf(here) : null);
        if (here) setupRelated(posts, here, linked);
      });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
