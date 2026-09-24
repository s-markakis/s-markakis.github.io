// Renders the shared site nav into <nav id="site-nav"></nav>. Active link is
// determined by the current path. Wires up hamburger and theme toggle without
// inline event handlers (so the page can ship a strict CSP).

(function () {
  const NAV_LINKS = [
    { href: 'services.html', i18n: 'nav.services' },
    { href: 'managed.html', i18n: 'nav.managed', elHref: 'managed-el.html' },
    { href: 'projects.html', i18n: 'nav.projects' },
    { href: 'blog.html', i18n: 'nav.blog' },
  ];

  const SUN = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>';
  const MOON = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';

  function currentPage() {
    const path = location.pathname.split('/').pop() || 'index.html';
    return path;
  }

  function buildNav(target) {
    const here = currentPage();
    // Writeups live one level deep under /writeups/; root pages are at /.
    // Prefix the shared nav links so they resolve from either location.
    const base = location.pathname.includes('/writeups/') ? '../' : '';
    const links = NAV_LINKS.map(l => {
      // Active also matches the Greek twin (e.g. managed-el.html → managed).
      const active = (l.href === here || l.elHref === here) ? ' active' : '';
      const elAttr = l.elHref ? ` data-href-el="${base}${l.elHref}"` : '';
      return `<a href="${base}${l.href}" class="nav-link${active}"${elAttr} data-i18n="${l.i18n}"></a>`;
    }).join('');

    target.classList.add('site-nav');
    target.setAttribute('data-i18n-attr-aria-label', 'nav.main');
    target.innerHTML = `
      <a href="${base}index.html" class="nav-brand">S. Markakis</a>
      <button class="nav-hamburger" data-i18n-attr-aria-label="nav.toggleMenu" type="button" aria-expanded="false">
        <span></span><span></span><span></span>
      </button>
      <div class="nav-links">${links}</div>
      <button class="nav-lang" data-i18n-attr-aria-label="nav.toggleLang" type="button"></button>
      <div class="nav-toggle" data-i18n-attr-aria-label="nav.toggleTheme" role="button" tabindex="0">
        <span class="toggle-icon">${SUN}</span>
        <div class="toggle-track"><div class="toggle-knob"></div></div>
        <span class="toggle-icon">${MOON}</span>
      </div>
    `;

    const hamburger = target.querySelector('.nav-hamburger');
    hamburger.addEventListener('click', () => {
      const open = target.classList.toggle('nav-open');
      hamburger.setAttribute('aria-expanded', String(open));
    });

    const langBtn = target.querySelector('.nav-lang');
    function updateLangBtn() {
      langBtn.textContent = (window.Sp1r4I18n && window.Sp1r4I18n.getLang() === 'el') ? 'EN' : 'EL';
    }
    updateLangBtn();
    langBtn.addEventListener('click', () => {
      // Pages with a static counterpart edition (data-lang-target) navigate
      // to it when switching INTO its language, persisting the choice via
      // setLang so the rest of the site follows. Switching the other way on
      // a bilingual page (e.g. geo-detected Greek on starlink.html) falls
      // back to the client-side toggle — the counterpart would be the same
      // language the visitor is leaving.
      const counterpart = document.body.dataset.langTarget;
      const i18n = window.Sp1r4I18n;
      if (counterpart) {
        const pageLang = document.body.dataset.lang || 'en';
        const counterpartLang = pageLang === 'el' ? 'en' : 'el';
        const want = (i18n && i18n.getLang() === 'el') ? 'en' : 'el';
        if (!i18n || want === counterpartLang) {
          if (i18n) i18n.setLang(want);
          location.href = counterpart;
          return;
        }
      }
      if (i18n) {
        i18n.toggleLang();
        updateLangBtn();
      }
    });
    // Keep the label in sync when language changes automatically (e.g. geo detection).
    document.addEventListener('langchange', updateLangBtn);

    const toggle = target.querySelector('.nav-toggle');
    toggle.addEventListener('click', () => window.toggleTheme && window.toggleTheme());
    toggle.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        window.toggleTheme && window.toggleTheme();
      }
    });

    if (window.Sp1r4I18n) window.Sp1r4I18n.applyTranslations(target);
  }

  function init() {
    const target = document.getElementById('site-nav');
    if (target) buildNav(target);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
