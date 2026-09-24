// Lead forms (Starlink survey, pentest enquiry) -> Web3Forms (AJAX, no page
// reload, no inline script). On success it also pings a Cloudflare Worker that
// forwards a Telegram message. Each form declares its i18n key prefix via
// data-i18n-prefix (e.g. "starlink", "pentest"); status text resolves to
// <prefix>.form.{sending,success,error}.
(function () {
  const t = (k, fb) => (window.Sp1r4I18n ? window.Sp1r4I18n.t(k) : fb);

  // Replace with your deployed Worker URL (see worker/README.md). Leave empty to disable.
  const TELEGRAM_ENDPOINT = 'https://leads-telegram.sp1r4.workers.dev';

  // Notify Telegram via the Worker. Best-effort: never blocks or fails the form UX.
  function notifyTelegram(formData) {
    if (!TELEGRAM_ENDPOINT || TELEGRAM_ENDPOINT.includes('YOUR-SUBDOMAIN')) return;
    fetch(TELEGRAM_ENDPOINT, { method: 'POST', body: formData }).catch(() => {});
  }

  function wire(form) {
    const prefix = form.getAttribute('data-i18n-prefix') || 'starlink';
    const status = form.querySelector('.form-status');
    const btn = form.querySelector('button[type="submit"]');

    form.addEventListener('submit', (e) => {
      e.preventDefault();
      if (form.botcheck && form.botcheck.value) return;          // honeypot tripped
      if (status) { status.className = 'form-status sending'; status.textContent = t(prefix + '.form.sending', 'Sending…'); }
      if (btn) btn.disabled = true;

      const data = new FormData(form);
      fetch('https://api.web3forms.com/submit', {
        method: 'POST',
        headers: { Accept: 'application/json' },
        body: data,
      })
        .then((r) => r.json())
        .then((res) => {
          if (!res.success) throw new Error(res.message || 'error');
          notifyTelegram(data);
          form.reset();
          if (status) { status.className = 'form-status ok'; status.textContent = t(prefix + '.form.success', "Thanks — I'll get back to you shortly."); }
        })
        .catch(() => {
          if (status) { status.className = 'form-status err'; status.textContent = t(prefix + '.form.error', 'Something went wrong — please email me directly.'); }
        })
        .finally(() => { if (btn) btn.disabled = false; });
    });
  }

  document.querySelectorAll('form.survey-form').forEach(wire);
})();
