// Renders the blog post list from posts.json with tag filtering.
// Search uses Pagefind (full-text index) when available, falling back
// to a substring match on title/description/tags if it fails to load.

let posts = [];
let activeFilter = null;
let searchQuery = '';
let pagefindMod = null;
let pagefindReady = false;
let pagefindUrls = null;
let pagefindReqId = 0;

// Special (non-tag) filter: the N most recent posts by date.
const RECENT = '__recent__';
const RECENT_N = 10;
// Pagination: render this many cards at a time, "Load more" for the rest.
const PAGE_SIZE = 24;
let shownCount = PAGE_SIZE;
let lastRenderKey = null;

async function initPagefind() {
  try {
    pagefindMod = await import('/pagefind/pagefind.js');
    if (pagefindMod.options) await pagefindMod.options({ baseUrl: '/' });
    pagefindReady = true;
  } catch (e) {
    pagefindReady = false;
  }
}
initPagefind();

async function runPagefind(query) {
  const myReq = ++pagefindReqId;
  if (!pagefindReady || !pagefindMod || !query.trim()) {
    pagefindUrls = null;
    return;
  }
  try {
    const result = await pagefindMod.search(query);
    if (myReq !== pagefindReqId) return;
    const set = new Set();
    await Promise.all(result.results.map(async r => {
      const d = await r.data();
      try {
        const u = new URL(d.url, location.href);
        set.add(u.pathname.replace(/^\//, ''));
      } catch {}
    }));
    if (myReq !== pagefindReqId) return;
    pagefindUrls = set;
  } catch (e) {
    pagefindUrls = null;
  }
}

const t = (k) => (window.Sp1r4I18n ? window.Sp1r4I18n.t(k) : k);

function formatDate(d) {
  const date = new Date(d + 'T00:00:00');
  const locale = window.Sp1r4I18n && window.Sp1r4I18n.getLang() === 'el' ? 'el-GR' : 'en-US';
  return date.toLocaleDateString(locale, { year: 'numeric', month: 'long', day: 'numeric' });
}

function getAllTags() {
  const tags = new Set();
  posts.forEach(p => (p.tags || []).forEach(t => tags.add(t)));
  // Platform pills first (in this order), then every topic tag alphabetically.
  const PLATFORM = ['cisco', 'mikrotik'];
  const rest = [...tags].filter(t => !PLATFORM.includes(t)).sort();
  return [...PLATFORM.filter(t => tags.has(t)), ...rest];
}

function renderFilterBar() {
  const bar = document.getElementById('filter-bar');
  bar.innerHTML = '';
  const tags = getAllTags();
  if (tags.length <= 1) { bar.style.display = 'none'; return; }
  bar.style.display = 'flex';

  const allBtn = document.createElement('button');
  allBtn.className = 'filter-pill' + (activeFilter === null ? ' active' : '');
  allBtn.textContent = t('blog.filter.all');
  allBtn.addEventListener('click', () => { activeFilter = null; renderFilterBar(); renderList(); });
  bar.appendChild(allBtn);

  const recentBtn = document.createElement('button');
  recentBtn.className = 'filter-pill' + (activeFilter === RECENT ? ' active' : '');
  recentBtn.textContent = t('blog.filter.recent');
  recentBtn.addEventListener('click', () => { activeFilter = RECENT; renderFilterBar(); renderList(); });
  bar.appendChild(recentBtn);

  tags.forEach(tag => {
    const btn = document.createElement('button');
    btn.className = 'filter-pill' + (activeFilter === tag ? ' active' : '');
    btn.textContent = tag;
    btn.addEventListener('click', () => { activeFilter = tag; renderFilterBar(); renderList(); });
    bar.appendChild(btn);
  });
}

function renderList() {
  const list = document.getElementById('post-list');
  const countEl = document.getElementById('post-count');
  list.innerHTML = '';
  if (posts.length === 0) {
    list.innerHTML = `<div class="empty-state">${t('blog.empty')}</div>`;
    countEl.textContent = '';
    return;
  }
  const q = searchQuery.trim().toLowerCase();
  const tagFilter = activeFilter && activeFilter !== RECENT;
  let sorted = [...posts]
    .filter(p => !tagFilter || (p.tags && p.tags.includes(activeFilter)))
    .filter(p => {
      if (!q) return true;
      if (pagefindUrls) return pagefindUrls.has(p.html);
      const haystack = [p.title, p.description, ...(p.tags || [])].join(' ').toLowerCase();
      return haystack.includes(q);
    })
    .sort((a, b) => b.date.localeCompare(a.date));

  // "Recent" limits to the N newest (after any active search).
  if (activeFilter === RECENT) sorted = sorted.slice(0, RECENT_N);

  const noun = sorted.length === 1 ? t('blog.post') : t('blog.posts');
  const inLabel = activeFilter === RECENT ? ' ' + t('blog.filter.recent').toLowerCase()
                : tagFilter ? ' ' + t('blog.in') + ' "' + activeFilter + '"' : '';
  countEl.textContent = `${sorted.length} ${noun}${inLabel}`;

  if (sorted.length === 0) {
    list.innerHTML = `<div class="empty-state">${t('blog.emptyCat')}</div>`;
    return;
  }

  // Reset paging when the filter/search changes; keep it when loading more.
  const key = (activeFilter || '') + '|' + searchQuery;
  if (key !== lastRenderKey) { shownCount = PAGE_SIZE; lastRenderKey = key; }
  const visible = sorted.slice(0, shownCount);

  visible.forEach((post, i) => {
    const el = document.createElement('a');
    el.className = 'post-card' + (post.tags && post.tags.includes('htb') ? ' post-card-htb' : '');
    el.href = post.html;
    el.style.setProperty('--i', i);

    const title = document.createElement('div');
    title.className = 'post-title';
    title.textContent = post.title;

    const desc = document.createElement('div');
    desc.className = 'post-desc';
    desc.textContent = post.description;

    const meta = document.createElement('div');
    meta.className = 'post-meta';
    const date = document.createElement('span');
    date.textContent = formatDate(post.date);
    meta.appendChild(date);
    if (post.reading_time) {
      const rt = document.createElement('span');
      rt.className = 'post-reading';
      rt.textContent = `${post.reading_time} min ${t('blog.read') || 'read'}`;
      meta.appendChild(rt);
    }
    if (post.tags) {
      post.tags.forEach(t => {
        const tag = document.createElement('span');
        tag.className = 'post-tag post-tag-' + t;
        tag.textContent = t;
        meta.appendChild(tag);
      });
    }

    el.appendChild(title);
    el.appendChild(desc);
    el.appendChild(meta);
    list.appendChild(el);
  });

  if (sorted.length > visible.length) {
    const more = document.createElement('button');
    more.className = 'load-more';
    more.textContent = `${t('blog.loadMore') || 'Load more'} (${sorted.length - visible.length})`;
    more.addEventListener('click', () => { shownCount += PAGE_SIZE; renderList(); });
    list.appendChild(more);
  }
}

fetch('posts.json')
  .then(r => r.json())
  .then(data => {
    posts = data;
    renderFilterBar();
    renderList();
  });

const searchEl = document.getElementById('post-search');
let searchDebounce = null;
if (searchEl) {
  searchEl.addEventListener('input', () => {
    searchQuery = searchEl.value;
    renderList();
    if (searchDebounce) clearTimeout(searchDebounce);
    searchDebounce = setTimeout(async () => {
      await runPagefind(searchQuery);
      renderList();
    }, 140);
  });
}

// Focus search with `/` from anywhere on the blog page (when not already in an input).
document.addEventListener('keydown', (e) => {
  if (e.key === '/' && document.activeElement?.tagName !== 'INPUT') {
    e.preventDefault();
    if (searchEl) searchEl.focus();
  }
});

document.addEventListener('langchange', () => {
  if (posts.length) {
    renderFilterBar();
    renderList();
  }
});
