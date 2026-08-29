// Renders a left-side TOC of all blog posts inside a writeup page so
// readers can switch between posts without going back to /blog.html.
// Loaded by every writeup HTML; standalone (no other deps).
(function () {
  if (window.__sp1r4SidebarBuilt) return;
  window.__sp1r4SidebarBuilt = true;

  const POSTS_URL = '../posts.json';

  function currentSlug() {
    const file = (location.pathname.split('/').pop() || '').replace(/\.html$/i, '');
    return file;
  }

  function injectStyles() {
    if (document.getElementById('sp1r4-sidebar-style')) return;
    const css = `
      :root { --sp1r4-sb-width: 260px; }
      .sp1r4-sidebar {
        position: fixed; top: 0; left: 0; bottom: 0; width: var(--sp1r4-sb-width);
        z-index: 9998; padding: 70px 14px 24px;
        background: rgba(20,20,20,0.94);
        border-right: 1px solid rgba(255,255,255,0.08);
        backdrop-filter: blur(10px);
        -webkit-backdrop-filter: blur(10px);
        font-family: 'Inter', 'Barlow', system-ui, sans-serif;
        overflow-y: auto;
      }
      .sp1r4-sidebar h2 {
        font-size: 10px; font-weight: 600; letter-spacing: 0.18em;
        color: rgba(255,255,255,0.45); text-transform: uppercase;
        margin: 0 8px 12px; padding: 0;
      }
      .sp1r4-sb-list { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 2px; }
      .sp1r4-sb-item a {
        display: block; padding: 10px 12px; border-radius: 4px;
        text-decoration: none; color: rgba(234,232,227,0.78);
        font-size: 12px; font-weight: 500; line-height: 1.35;
        border-left: 2px solid transparent;
        transition: background 0.15s, color 0.15s, border-color 0.15s;
      }
      .sp1r4-sb-item a:hover {
        background: rgba(255,255,255,0.05); color: #fff;
      }
      .sp1r4-sb-item.active a {
        background: rgba(52,211,153,0.10);
        border-left-color: #34d399;
        color: #fff;
      }
      .sp1r4-sb-meta {
        display: block; margin-top: 3px;
        font-size: 9px; font-weight: 400;
        letter-spacing: 0.08em; text-transform: uppercase;
        color: rgba(255,255,255,0.35);
      }
      .sp1r4-sidebar-toggle {
        position: fixed; top: 66px; left: 18px; z-index: 51;
        display: none; width: 38px; height: 38px;
        background: rgba(20,20,20,0.94); color: #eae8e3;
        border: 1px solid rgba(255,255,255,0.12); border-radius: 4px;
        cursor: pointer; align-items: center; justify-content: center;
        backdrop-filter: blur(8px);
        -webkit-backdrop-filter: blur(8px);
      }
      .sp1r4-sidebar-toggle svg { width: 18px; height: 18px; stroke: currentColor; fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
      .sp1r4-sidebar-shadow {
        position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 9997;
        opacity: 0; pointer-events: none; transition: opacity 0.2s;
      }
      .sp1r4-sidebar-shadow.open { opacity: 1; pointer-events: auto; }

      /* Push the writeup body (and the fixed site nav) so neither sits under
         the always-open sidebar at desktop widths. */
      @media (min-width: 1100px) {
        body { padding-left: var(--sp1r4-sb-width) !important; }
        .site-nav { left: var(--sp1r4-sb-width) !important; }
        .writeup-back-link { left: calc(var(--sp1r4-sb-width) + 18px) !important; }
        /* Center the reading column on the full viewport (not just the space
           right of the sidebar) whenever there's room to do so without
           sliding under the sidebar; falls back to flush-left otherwise. */
        .wrap, .wrapper {
          margin-left: max(0px, calc((100vw - 780px) / 2 - var(--sp1r4-sb-width))) !important;
          margin-right: auto !important;
        }
      }
      @media (max-width: 1099px) {
        .sp1r4-sidebar {
          transform: translateX(-100%);
          transition: transform 0.2s ease-out;
          width: 280px; --sp1r4-sb-width: 280px;
        }
        .sp1r4-sidebar.open { transform: translateX(0); }
        .sp1r4-sidebar-toggle { display: flex; }
        .writeup-back-link { left: 64px !important; }
      }
    `;
    const style = document.createElement('style');
    style.id = 'sp1r4-sidebar-style';
    style.textContent = css;
    document.head.appendChild(style);
  }

  function formatDate(d) {
    if (!d) return '';
    try {
      return new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    } catch { return d; }
  }

  function build(posts) {
    injectStyles();

    const sorted = [...posts].sort((a, b) => (b.date || '').localeCompare(a.date || ''));
    const here = currentSlug();

    const aside = document.createElement('aside');
    aside.className = 'sp1r4-sidebar';
    aside.setAttribute('aria-label', 'Writeups');

    const heading = document.createElement('h2');
    heading.textContent = 'Writeups';
    aside.appendChild(heading);

    const ul = document.createElement('ul');
    ul.className = 'sp1r4-sb-list';
    sorted.forEach(p => {
      const li = document.createElement('li');
      li.className = 'sp1r4-sb-item' + (p.slug === here ? ' active' : '');
      const a = document.createElement('a');
      const file = (p.html || '').split('/').pop();
      a.href = file || '#';
      a.textContent = p.title || p.slug;
      const meta = document.createElement('span');
      meta.className = 'sp1r4-sb-meta';
      const parts = [];
      if (p.date) parts.push(formatDate(p.date));
      if (p.reading_time) parts.push(p.reading_time + ' min');
      meta.textContent = parts.join(' · ');
      a.appendChild(meta);
      li.appendChild(a);
      ul.appendChild(li);
    });
    aside.appendChild(ul);

    const toggle = document.createElement('button');
    toggle.className = 'sp1r4-sidebar-toggle';
    toggle.type = 'button';
    toggle.setAttribute('aria-label', 'Toggle writeups list');
    toggle.innerHTML = '<svg viewBox="0 0 24 24"><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="18" x2="21" y2="18"/></svg>';

    const shadow = document.createElement('div');
    shadow.className = 'sp1r4-sidebar-shadow';

    function close() { aside.classList.remove('open'); shadow.classList.remove('open'); }
    function open() { aside.classList.add('open'); shadow.classList.add('open'); }
    toggle.addEventListener('click', () => {
      aside.classList.contains('open') ? close() : open();
    });
    shadow.addEventListener('click', close);
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });

    document.body.appendChild(aside);
    document.body.appendChild(shadow);
    document.body.appendChild(toggle);
  }

  function init() {
    fetch(POSTS_URL, { cache: 'no-cache' })
      .then(r => r.ok ? r.json() : [])
      .then(posts => {
        if (Array.isArray(posts) && posts.length) build(posts);
      })
      .catch(() => {});
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
