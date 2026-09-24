// Renders the homepage from config.json. Theme is handled by theme.js.

const ICONS = {
  email: `<svg viewBox="0 0 24 24"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M2 7l10 7 10-7"/></svg>`,
  github: `<svg viewBox="0 0 24 24"><path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22"/></svg>`,
  box: `<svg viewBox="0 0 24 24"><polygon points="12 2 22 8.5 22 15.5 12 22 2 15.5 2 8.5"/><line x1="12" y1="22" x2="12" y2="15.5"/><polyline points="22 8.5 12 15.5 2 8.5"/></svg>`,
  link: `<svg viewBox="0 0 24 24"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>`,
  linkedin: `<svg viewBox="0 0 24 24"><path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z"/><rect x="2" y="9" width="4" height="12"/><circle cx="4" cy="4" r="2"/></svg>`,
  twitter: `<svg viewBox="0 0 24 24"><path d="M23 3a10.9 10.9 0 0 1-3.14 1.53 4.48 4.48 0 0 0-7.86 3v1A10.66 10.66 0 0 1 3 4s-4 9 5 13a11.64 11.64 0 0 1-7 2c9 5 20 0 20-11.5a4.5 4.5 0 0 0-.08-.83A7.72 7.72 0 0 0 23 3z"/></svg>`,
  globe: `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>`,
  shield: `<svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>`,
  terminal: `<svg viewBox="0 0 24 24"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg>`,
  code: `<svg viewBox="0 0 24 24"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>`,
  discord: `<svg viewBox="0 0 24 24"><path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028c.462-.63.874-1.295 1.226-1.994a.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03z"/></svg>`,
  youtube: `<svg viewBox="0 0 24 24"><path d="M22.54 6.42a2.78 2.78 0 0 0-1.94-2C18.88 4 12 4 12 4s-6.88 0-8.6.46a2.78 2.78 0 0 0-1.94 2A29 29 0 0 0 1 11.75a29 29 0 0 0 .46 5.33A2.78 2.78 0 0 0 3.4 19.1c1.72.46 8.6.46 8.6.46s6.88 0 8.6-.46a2.78 2.78 0 0 0 1.94-2 29 29 0 0 0 .46-5.25 29 29 0 0 0-.46-5.33z"/><polygon points="9.75 15.02 15.5 11.75 9.75 8.48 9.75 15.02"/></svg>`,
  blog: `<svg viewBox="0 0 24 24"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>`,
  telegram: `<svg viewBox="0 0 24 24"><path d="M22 2L11 13"/><path d="M22 2L15 22L11 13L2 9L22 2z"/></svg>`,
  satellite: `<svg viewBox="0 0 24 24"><path d="M4 12c0-4.4 3.6-8 8-8s8 3.6 8 8"/><path d="M8 12c0-2.2 1.8-4 4-4s4 1.8 4 4"/><circle cx="12" cy="12" r="1.5"/><line x1="12" y1="12" x2="12" y2="22"/><line x1="8" y1="22" x2="16" y2="22"/></svg>`,
  activity: `<svg viewBox="0 0 24 24"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg>`,
  viber: `<svg viewBox="0 0 24 24"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>`,
};

const isPreview = new URLSearchParams(location.search).get('preview') === '1';
const cfgPromise = isPreview && localStorage.getItem('sp1r4_preview')
  ? Promise.resolve(JSON.parse(localStorage.getItem('sp1r4_preview')))
  : fetch('config.json').then(r => r.json());

function localized(obj, key) {
  const lang = window.Sp1r4I18n ? window.Sp1r4I18n.getLang() : 'en';
  if (lang !== 'en' && obj[key + '_' + lang]) return obj[key + '_' + lang];
  return obj[key];
}

let cachedCfg = null;

function applyCfgI18n(cfg) {
  document.getElementById('bio').textContent = localized(cfg, 'bio');
  const statusTxt = document.querySelector('#status .status-text');
  if (statusTxt) statusTxt.textContent = localized(cfg.status, 'text');
  const footerSub = document.querySelector('#footer .footer-sub');
  if (footerSub) footerSub.textContent = localized(cfg.footer, 'sub');
  const lang = window.Sp1r4I18n ? window.Sp1r4I18n.getLang() : 'en';
  document.querySelectorAll('.link-card').forEach(card => {
    const i = parseInt(card.dataset.linkIdx, 10);
    const link = cfg.links[i];
    if (!link) return;
    const titleEl = card.querySelector('.link-title');
    const subEl = card.querySelector('.link-sub');
    if (titleEl) titleEl.textContent = localized(link, 'title');
    if (subEl) subEl.textContent = localized(link, 'sub');
    if (card.dataset.hrefEl) card.href = lang === 'el' ? card.dataset.hrefEl : card.dataset.hrefEn;
  });
}

function renderPill(link, container, idx) {
  const pill = document.createElement('div');
  pill.className = 'link-pill';
  pill.style.setProperty('--i', idx);
  (link.items || []).forEach(it => {
    const a = document.createElement('a');
    a.className = 'link-pill-item';
    const safeUrl = /^(https?:|mailto:|tel:|tg:|viber:|\/|#|\.|\w[\w\-]*\.html)/i.test(it.url.trim()) ? it.url : '#';
    a.href = safeUrl;
    const isAppScheme = /^(mailto:|tel:|tg:|viber:)/i.test(safeUrl);
    if (!isAppScheme) { a.target = '_blank'; }
    a.rel = 'noopener';
    const icon = document.createElement('span');
    icon.className = 'link-pill-icon';
    icon.innerHTML = Object.prototype.hasOwnProperty.call(ICONS, it.icon) ? ICONS[it.icon] : ICONS.link;
    const label = document.createElement('span');
    label.className = 'link-pill-label';
    label.textContent = it.label;
    a.appendChild(icon);
    a.appendChild(label);
    pill.appendChild(a);
  });
  container.appendChild(pill);
}

cfgPromise.then(cfg => {
  cachedCfg = cfg;
  // The HTML ships static fallback content (for no-JS visitors and crawlers);
  // clear it before re-rendering from config.json.
  ['avatar-wrap', 'status', 'links-container', 'footer'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.innerHTML = '';
  });
  const aw = document.getElementById('avatar-wrap');
  const img = document.createElement('img');
  img.src = cfg.avatar;
  img.alt = cfg.name;
  img.addEventListener('error', () => {
    img.style.display = 'none';
    const fb = document.createElement('div');
    fb.className = 'avatar-initials';
    fb.textContent = cfg.name.split(' ').map(w => w[0]).join('');
    aw.appendChild(fb);
  });
  aw.appendChild(img);

  document.getElementById('name').textContent = cfg.name;
  document.getElementById('brand').textContent = cfg.brand;
  document.getElementById('bio').textContent = localized(cfg, 'bio');

  const statusEl = document.getElementById('status');
  if (cfg.status && cfg.status.visible) {
    const dot = document.createElement('span');
    dot.className = 'status-dot';
    dot.style.background = cfg.status.color;
    dot.style.setProperty('--status-color', cfg.status.color);
    const txt = document.createElement('span');
    txt.className = 'status-text';
    txt.textContent = localized(cfg.status, 'text');
    statusEl.appendChild(dot);
    statusEl.appendChild(txt);
  } else {
    statusEl.style.display = 'none';
  }

  const container = document.getElementById('links-container');
  cfg.links.forEach((link, i) => {
    if (link.type === 'pill') {
      renderPill(link, container, i);
      return;
    }
    const a = document.createElement('a');
    a.className = link.primary ? 'link-card link-card-primary' : 'link-card';
    a.dataset.linkIdx = String(i);
    const safeUrl = /^(https?:|mailto:|tel:|tg:|viber:|\/|#|\.|\w[\w\-]*\.html)/i.test(link.url.trim()) ? link.url : '#';
    a.href = safeUrl;
    // Language-aware internal link: switch to the Greek twin file when in Greek.
    if (link.url_el && /^[\w][\w\-]*\.html$/i.test(link.url_el.trim())) {
      a.dataset.hrefEn = safeUrl;
      a.dataset.hrefEl = link.url_el;
      const lang = window.Sp1r4I18n ? window.Sp1r4I18n.getLang() : 'en';
      a.href = lang === 'el' ? link.url_el : safeUrl;
    }
    const isInternal = /^[\w][\w\-]*\.html$/i.test(link.url.trim());
    const isAppScheme = /^(mailto:|tel:|tg:|viber:)/i.test(safeUrl);
    if (!isAppScheme && !isInternal) a.target = '_blank';
    a.rel = 'noopener';
    a.style.setProperty('--i', i);

    const icon = document.createElement('div');
    icon.className = 'link-icon';
    icon.innerHTML = Object.prototype.hasOwnProperty.call(ICONS, link.icon) ? ICONS[link.icon] : ICONS.link;

    const text = document.createElement('div');
    text.className = 'link-text';
    const title = document.createElement('div');
    title.className = 'link-title';
    title.textContent = localized(link, 'title');
    text.appendChild(title);
    if (link.sub) {
      const sub = document.createElement('div');
      sub.className = 'link-sub';
      sub.textContent = localized(link, 'sub');
      text.appendChild(sub);
    }

    const arrow = document.createElement('span');
    arrow.className = 'link-arrow';
    arrow.textContent = isInternal ? '›' : '↗';

    a.appendChild(icon);
    a.appendChild(text);
    a.appendChild(arrow);

    a.addEventListener('mousemove', (e) => {
      const rect = a.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      const midX = rect.width / 2;
      const midY = rect.height / 2;
      const rotY = ((x - midX) / midX) * 4;
      const rotX = ((midY - y) / midY) * 3;
      a.style.transform = `translateY(-3px) rotateX(${rotX}deg) rotateY(${rotY}deg) scale(1.015)`;
    });
    a.addEventListener('mouseleave', () => { a.style.transform = ''; });

    container.appendChild(a);
  });

  const footer = document.getElementById('footer');
  const ft = document.createElement('div');
  ft.className = 'footer-wordmark';
  ft.textContent = cfg.footer.title;
  const fs = document.createElement('div');
  fs.className = 'footer-sub';
  fs.textContent = localized(cfg.footer, 'sub');
  footer.appendChild(ft);
  footer.appendChild(fs);
});

document.addEventListener('langchange', () => {
  if (cachedCfg) applyCfgI18n(cachedCfg);
});

document.addEventListener('DOMContentLoaded', () => {
  const themeToggle = document.querySelector('.theme-toggle');
  if (themeToggle) {
    themeToggle.addEventListener('click', () => window.toggleTheme && window.toggleTheme());
    themeToggle.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        window.toggleTheme && window.toggleTheme();
      }
    });
  }

  const langBtn = document.getElementById('index-lang');
  if (langBtn) {
    const sync = () => {
      if (window.Sp1r4I18n) langBtn.textContent = window.Sp1r4I18n.getLang() === 'el' ? 'EN' : 'EL';
    };
    sync();
    langBtn.addEventListener('click', (e) => {
      e.preventDefault();
      if (window.Sp1r4I18n) {
        window.Sp1r4I18n.toggleLang();
        sync();
      }
    });
    document.addEventListener('langchange', sync);
  }
});
