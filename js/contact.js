// Single source of truth for contact details + the shared "Free network check"
// CTA and contact pill. Change a number/handle here and it updates everywhere.
//
// ── TO EDIT LATER ────────────────────────────────────────────────────────────
//  • phone      → replace PHONE_PLACEHOLDER below with the real number (E.164).
//  • baseUrl    → switch to a custom domain (e.g. https://markakis.gr) in ONE spot.
//  • email      → the address is also mirrored in config.json (homepage) + JSON-LD.
// Renders into placeholders on the page (no inline JS, CSP-safe):
//   <div data-contact-cta></div>    → the Viber-first "free network check" CTA
//   <div data-contact-pill></div>   → segmented Email · Viber · Telegram · LinkedIn
// Re-renders on language change.

(function () {
  // Real number in E.164 (+CC…). viber links are derived by stripping to digits.
  const PHONE = '+30 697 667 7014';

  const CONTACT = {
    name: 'S. Markakis',
    baseUrl: 'https://s-markakis.github.io',   // ← one-line change for a custom domain
    email: 'sp1r4.work@gmail.com',
    phone: PHONE,
    telegram: 'https://t.me/S_Markakis',
    linkedin: 'https://www.linkedin.com/in/spyros-markakis',
    x: 'https://x.com/_SP1R4',                 // footer only
  };

  // The CTA / pill labels + the email fallback subject, per language. Kept here so
  // all injected contact copy lives in one file. (Viber/Telegram deep links can't
  // carry a prefilled message, so the prompt text lives on the email fallback.)
  const COPY = {
    en: {
      cta: 'Free network check',
      or: 'or email me',
      email: 'Email', viber: 'Viber', telegram: 'Telegram', linkedin: 'LinkedIn',
      emailSubject: 'Free network check',
    },
    el: {
      cta: 'Δωρεάν έλεγχος δικτύου',
      or: 'ή στείλτε μου email',
      email: 'Email', viber: 'Viber', telegram: 'Telegram', linkedin: 'LinkedIn',
      emailSubject: 'Δωρεάν έλεγχος δικτύου',
    },
  };

  const digits = CONTACT.phone.replace(/[^\d]/g, '');
  const ICON = {
    viber: '<svg viewBox="0 0 24 24"><path d="M12 3c4.6 0 7 2.3 7 6.6 0 4.4-2.4 6.7-7 6.7-.5 0-1 0-1.4-.1L7 19v-3.2C4.8 14.4 5 11.9 5 9.6 5 5.3 7.4 3 12 3z"/><path d="M9.5 8c1.7.1 2.9 1.3 3 3"/><path d="M9.7 6c2.7.1 4.6 2 4.7 4.8"/></svg>',
    telegram: '<svg viewBox="0 0 24 24"><path d="M22 2L11 13"/><path d="M22 2L15 22L11 13L2 9L22 2z"/></svg>',
    email: '<svg viewBox="0 0 24 24"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M2 7l10 7 10-7"/></svg>',
    linkedin: '<svg viewBox="0 0 24 24"><path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z"/><rect x="2" y="9" width="4" height="12"/><circle cx="4" cy="4" r="2"/></svg>',
  };

  function lang() {
    return (window.Sp1r4I18n && window.Sp1r4I18n.getLang() === 'el') ? 'el' : 'en';
  }
  function viberUrl() {
    return `viber://chat?number=${encodeURIComponent('+' + digits)}`;
  }
  function mailUrl(l) {
    return `mailto:${CONTACT.email}?subject=${encodeURIComponent(COPY[l].emailSubject)}`;
  }

  function renderCta(el) {
    const l = lang();
    const c = COPY[l];
    el.className = 'cta-check';
    el.innerHTML =
      `<a class="btn-check" href="${viberUrl()}" rel="noopener">` +
        `<span class="btn-check-icon">${ICON.viber}</span>` +
        `<span>${c.cta}</span></a>` +
      `<div class="cta-check-alt">${c.or}: ` +
        `<a href="${mailUrl(l)}">${CONTACT.email}</a></div>`;
  }

  function pillItem(href, iconKey, label, appScheme) {
    const attrs = appScheme ? 'rel="noopener"' : 'target="_blank" rel="noopener"';
    return `<a class="cta-pill-item" href="${href}" ${attrs}>` +
      `<span>${ICON[iconKey]}</span><span>${label}</span></a>`;
  }
  function renderPill(el) {
    const l = lang();
    const c = COPY[l];
    el.className = 'cta-pill';
    el.setAttribute('role', 'group');
    el.setAttribute('aria-label', 'Contact methods');
    el.innerHTML =
      pillItem(mailUrl(l), 'email', c.email, true) +
      pillItem(viberUrl(), 'viber', c.viber, true) +
      pillItem(CONTACT.telegram, 'telegram', c.telegram, false) +
      pillItem(CONTACT.linkedin, 'linkedin', c.linkedin, false);
  }

  function renderAll() {
    document.querySelectorAll('[data-contact-cta]').forEach(renderCta);
    document.querySelectorAll('[data-contact-pill]').forEach(renderPill);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', renderAll);
  } else {
    renderAll();
  }
  document.addEventListener('langchange', renderAll);

  window.Sp1r4Contact = { CONTACT, viberUrl, mailUrl };
})();
