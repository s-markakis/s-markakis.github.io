// Persisted light/dark theme toggle. Applied as early as possible to avoid FOUC.
(function () {
  const saved = localStorage.getItem('sp1r4_theme');
  if (saved === 'dark' || (!saved && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    document.documentElement.classList.add('preload-dark');
  }
})();

document.addEventListener('DOMContentLoaded', () => {
  if (document.documentElement.classList.contains('preload-dark')) {
    document.body.classList.add('dark');
    document.documentElement.classList.remove('preload-dark');
  }
});

window.toggleTheme = function () {
  document.body.classList.toggle('dark');
  localStorage.setItem('sp1r4_theme', document.body.classList.contains('dark') ? 'dark' : 'light');
};

if ('serviceWorker' in navigator && location.protocol !== 'file:') {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  });
}

// Cloudflare Web Analytics — privacy-preserving, cookieless, no cross-site
// tracking. Stays INERT until you paste your token below (one place, all pages).
// Get it from the Cloudflare dashboard → Web Analytics → add site → the
// data-cf-beacon token. The CSP already allows the beacon host site-wide.
const CF_ANALYTICS_TOKEN = ''; // <-- paste Cloudflare Web Analytics token to activate
if (CF_ANALYTICS_TOKEN && location.protocol !== 'file:') {
  window.addEventListener('load', () => {
    const s = document.createElement('script');
    s.defer = true;
    s.src = 'https://static.cloudflareinsights.com/beacon.min.js';
    s.setAttribute('data-cf-beacon', JSON.stringify({ token: CF_ANALYTICS_TOKEN }));
    document.head.appendChild(s);
  });
}
