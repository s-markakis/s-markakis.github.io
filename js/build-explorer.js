/* Build-series interactive topology: step slider, per-device cumulative config with the
   selected step's lines highlighted, "show step N" jump links, and synced Cisco/MikroTik tabs.
   Data comes from <script type="application/json" id="bx-data"> written by the generator. */
(function () {
  'use strict';

  // ---- vendor tabs (work even on pages without an explorer)
  function setVendor(v) {
    document.querySelectorAll('[data-vt]').forEach(function (box) {
      box.querySelectorAll('.vt-btn').forEach(function (b) {
        var on = b.getAttribute('data-v') === v;
        b.classList.toggle('on', on);
        b.setAttribute('aria-selected', on ? 'true' : 'false');
      });
      box.querySelectorAll('.vt-pane').forEach(function (p) { p.hidden = p.getAttribute('data-v') !== v; });
    });
    try { localStorage.setItem('sp1r4_vendor', v); } catch (e) { /* storage blocked: tabs still work */ }
  }
  document.addEventListener('click', function (e) {
    var b = e.target.closest && e.target.closest('.vt-btn');
    if (b) setVendor(b.getAttribute('data-v'));
  });
  try { var saved = localStorage.getItem('sp1r4_vendor'); if (saved) setVendor(saved); } catch (e) { /* ignore */ }

  // ---- explorer
  var root = document.getElementById('bx');
  var dataEl = document.getElementById('bx-data');
  if (!root || !dataEl) return;
  var data;
  try { data = JSON.parse(dataEl.textContent); } catch (e) { return; }
  var steps = data.steps, max = steps.length;
  var els = root.querySelectorAll('.bx-el');
  var range = document.getElementById('bx-range');
  var title = document.getElementById('bx-title');
  var lab = document.getElementById('bx-steplabel');
  var adds = document.getElementById('bx-adds');
  var devBox = document.getElementById('bx-devs');
  var cfgLabel = document.getElementById('bx-cfglabel');
  var cfgPre = document.getElementById('bx-cfg');
  var step = max + 1;            // max+1 = full network, nothing highlighted as new
  var dev = null;

  function esc(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

  Object.keys(data.devices).forEach(function (id) {
    var b = document.createElement('button');
    b.type = 'button';
    b.textContent = data.devices[id];
    b.setAttribute('data-dev', id);
    b.addEventListener('click', function () { pick(id); });
    devBox.appendChild(b);
  });

  function firstStep(id) {
    var f = data.configs[id];
    return f && f.length ? Math.min.apply(null, f.map(function (x) { return x.step; })) : 999;
  }

  function renderCfg() {
    devBox.querySelectorAll('button').forEach(function (b) {
      var id = b.getAttribute('data-dev');
      b.classList.toggle('on', id === dev);
      b.disabled = step <= max && firstStep(id) > step;
    });
    root.querySelectorAll('.bx-cfg[data-dev]').forEach(function (g) { g.classList.toggle('bx-on', g.getAttribute('data-dev') === dev); });
    if (!dev) { cfgLabel.textContent = 'Select a device to see its configuration'; cfgPre.innerHTML = ''; return; }
    var frags = (data.configs[dev] || []).filter(function (f) { return step > max || f.step <= step; });
    var added = frags.filter(function (f) { return f.step === step; }).reduce(function (n, f) { return n + f.text.split('\n').length; }, 0);
    cfgLabel.textContent = data.devices[dev] + (step > max ? ' — complete configuration' :
      ' — configuration after step ' + step + (added ? ' (' + added + ' lines added in this step)' : ' (nothing added in this step)'));
    if (!frags.length) { cfgPre.innerHTML = '<span class="bx-hdr">! nothing configured on this device yet</span>'; return; }
    var out = '', first = null;
    frags.forEach(function (f) {
      var body = '<span class="bx-hdr">! ── step ' + f.step + ' · ' + esc(f.title) + ' · ' + esc(f.label) + '</span>\n' + esc(f.text);
      if (f.step === step) { out += '<span class="bx-add">' + body + '</span>\n'; if (first === null) first = out.length; }
      else out += body + '\n\n';
    });
    cfgPre.innerHTML = out;
    var hl = cfgPre.querySelector('.bx-add');
    cfgPre.scrollTop = 0;
    if (hl) cfgPre.scrollTop = hl.getBoundingClientRect().top - cfgPre.getBoundingClientRect().top - 8;
  }

  function setStep(s) {
    step = s;
    els.forEach(function (e) {
      var st = +e.getAttribute('data-step');
      e.classList.toggle('bx-ghost', s <= max && st > s);
      e.classList.toggle('bx-new', s <= max && st === s);
    });
    if (s > max) {
      range.value = max;
      lab.textContent = 'FULL NETWORK';
      adds.textContent = 'all ' + max + ' steps built';
      title.textContent = 'Full network · all steps built';
    } else {
      range.value = s;
      var st = steps[s - 1];
      lab.textContent = 'STEP ' + s + ' OF ' + max;
      adds.textContent = 'adds: ' + st.adds;
      title.innerHTML = 'Step ' + s + ' · ' + esc(st.title) + ' <a href="#step-' + s + '" style="font-size:.8rem;text-transform:none;letter-spacing:0;">read the step ↓</a>';
      // follow the change: if the selected device didn't change in this step, select one that did
      var changed = Object.keys(data.configs).filter(function (id) {
        return data.configs[id].some(function (f) { return f.step === s; });
      });
      if (changed.length && changed.indexOf(dev) < 0) dev = changed[0];
    }
    renderCfg();
  }

  function pick(id) { dev = id; renderCfg(); }

  range.addEventListener('input', function () { setStep(+range.value); });
  root.addEventListener('click', function (e) {
    var b = e.target.closest('[data-bx]');
    if (b) {
      var a = b.getAttribute('data-bx');
      if (a === 'all') setStep(max + 1);
      else if (a === 'prev') setStep(Math.max(1, (step > max ? max : step) - 1));
      else if (a === 'next') setStep(step >= max ? max + 1 : step + 1);
      return;
    }
    var g = e.target.closest('.bx-cfg[data-dev]');
    if (g) pick(g.getAttribute('data-dev'));
  });
  root.addEventListener('keydown', function (e) {
    var g = e.target.closest && e.target.closest('.bx-cfg[data-dev]');
    if (g && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); pick(g.getAttribute('data-dev')); }
  });
  document.addEventListener('click', function (e) {
    var j = e.target.closest && e.target.closest('[data-bx-step]');
    if (!j) return;
    e.preventDefault();
    setStep(+j.getAttribute('data-bx-step'));
    root.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });

  setStep(max + 1);
})();
