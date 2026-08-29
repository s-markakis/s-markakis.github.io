// Renders the projects page from the GitHub API with a static fallback.

const t = (k) => (window.Sp1r4I18n ? window.Sp1r4I18n.t(k) : k);

const LANG_COLORS = {
  Python: '#3572A5', JavaScript: '#f1e05a', TypeScript: '#3178c6',
  Go: '#00ADD8', Rust: '#dea584', C: '#555555', 'C++': '#f34b7d',
  'C#': '#178600', Java: '#b07219', Ruby: '#701516', PHP: '#4F5D95',
  Shell: '#89e051', HTML: '#e34c26', CSS: '#563d7c', Lua: '#000080',
  Nix: '#7e7eff', Dart: '#00B4AB', Kotlin: '#A97BFF', Swift: '#F05138',
};

const EXCLUDE = ['SP1R4', 's-markakis', 's-markakis.github.io'];
const FEATURED = ['BackupHandler', 'PhantomTrap', 'Qsafe', 'hashcracker', 'sentrynotch'];

const FALLBACK_REPOS = [
  { name: 'BackupHandler', description: 'Full-featured backup solution with local/SSH/S3/MySQL support, Tailscale VPN, system snapshots for OS rebuild, AES-256 encryption, dedup, scheduling, and Telegram notifications', language: 'Python', stargazers_count: 0, forks_count: 0, html_url: 'https://github.com/s-markakis/BackupHandler', topics: ['automation', 'backup', 'encryption', 'linux', 'python', 'restore', 'sftp', 'snapshot', 'ssh', 'sysadmin', 'tailscale', 'telegram'] },
  { name: 'PhantomTrap', description: 'High-interaction honeypot framework with behavioral fingerprinting, campaign detection, and real-time dashboard', language: 'Python', stargazers_count: 0, forks_count: 0, html_url: 'https://github.com/s-markakis/PhantomTrap', topics: ['blue-team', 'cybersecurity', 'dashboard', 'honeypot', 'network-security', 'python', 'security', 'threat-intelligence'] },
  { name: 'Qsafe', description: 'Post-quantum file encryption tool using Kyber1024 + AES-256-GCM', language: 'C', stargazers_count: 0, forks_count: 0, html_url: 'https://github.com/s-markakis/Qsafe', topics: ['aes-256', 'c', 'cryptography', 'encryption', 'kyber', 'post-quantum', 'quantum-resistant', 'security'] },
  { name: 'hashcracker', description: 'Professional hash identification and cracking toolkit for security experts. Identifies 60+ hash types with confidence scoring, cracks via hashcat & John the Ripper.', language: 'Python', stargazers_count: 0, forks_count: 0, html_url: 'https://github.com/s-markakis/hashcracker', topics: ['cli', 'cybersecurity', 'hash-cracking', 'hashcat', 'john-the-ripper', 'penetration-testing', 'python', 'security-tools'] },
  { name: 'FundsForwarder', description: 'Non-custodial ETH/ERC-20 forwarding smart contract — Solidity, Hardhat, OpenZeppelin, 100% test coverage, timelocked ownership', language: 'JavaScript', stargazers_count: 0, forks_count: 0, html_url: 'https://github.com/s-markakis/FundsForwarder', topics: ['automation', 'blockchain', 'crypto', 'erc20', 'ethereum', 'funds', 'javascript', 'transaction', 'wallet', 'web3'] },
  { name: 'plexus-network-planner', description: 'Plexus — cross-platform network site planner: WiFi + IP cameras + switches/PoE. Predictive wall-aware ray-cast coverage, SNR/throughput heatmaps, topology & cabling, branded PDF/BoM exports. Desktop apps for macOS/Windows/Linux, or runs offline in the browser.', language: 'JavaScript', stargazers_count: 2, forks_count: 0, html_url: 'https://github.com/s-markakis/plexus-network-planner', topics: ['access-points', 'coverage', 'desktop-app', 'electron', 'floor-plan', 'heatmap', 'ip-camera', 'mikrotik', 'network-planning', 'poe', 'ray-casting', 'rf-planning', 'site-survey', 'spa', 'unifi', 'vanilla-js', 'vite', 'wifi', 'wifi-planner', 'wireless'] },
  { name: 'sentrynotch', description: "A permission checkpoint for coding agents, living in your Mac's notch.", language: 'Swift', stargazers_count: 1, forks_count: 0, html_url: 'https://github.com/s-markakis/sentrynotch', topics: ['agentic-ai', 'ai-agents', 'claude', 'claude-code', 'developer-tools', 'llm', 'macos', 'menubar', 'notch', 'permissions', 'swift', 'swiftui'] },
  { name: 'ctf-toolkit-setup', description: 'Architecture-aware CTF toolkit installer for Ubuntu (apt/pip/gem/GitHub)', language: 'Shell', stargazers_count: 0, forks_count: 0, html_url: 'https://github.com/s-markakis/ctf-toolkit-setup', topics: [] },
  { name: 'CMDR', description: 'A command manager for CTF players and pentesters: store, parameterize, and run shell commands with workspaces, hosts, output→env chaining, playbooks, findings/reporting, and encrypted workspaces.', language: 'Shell', stargazers_count: 0, forks_count: 0, html_url: 'https://github.com/s-markakis/CMDR', topics: ['bash', 'cli', 'command-line', 'command-manager', 'ctf', 'jq', 'offensive-security', 'pentesting', 'productivity', 'redteam', 'shell', 'snippets', 'terminal'] },
];

function buildCard(repo, i, featured) {
  const a = document.createElement('a');
  a.className = 'project-card';
  a.href = /^https:\/\/github\.com\//i.test(repo.html_url) ? repo.html_url : '#';
  a.target = '_blank';
  a.rel = 'noopener';
  a.style.setProperty('--i', i);

  const name = document.createElement('div');
  name.className = 'proj-name';
  name.innerHTML = `<svg viewBox="0 0 24 24"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>`;
  const nameText = document.createElement('span');
  nameText.textContent = repo.name;
  name.appendChild(nameText);
  if (featured) {
    const badge = document.createElement('span');
    badge.className = 'featured-badge';
    badge.textContent = t('projects.featured.badge');
    name.appendChild(badge);
  }

  const desc = document.createElement('div');
  desc.className = 'proj-desc';
  desc.textContent = repo.description || t('projects.noDesc');

  const meta = document.createElement('div');
  meta.className = 'proj-meta';

  if (repo.language) {
    const lang = document.createElement('span');
    lang.className = 'proj-lang';
    const dot = document.createElement('span');
    dot.className = 'proj-lang-dot';
    dot.style.background = LANG_COLORS[repo.language] || '#888';
    const langName = document.createElement('span');
    langName.textContent = repo.language;
    lang.appendChild(dot);
    lang.appendChild(langName);
    meta.appendChild(lang);
  }

  if (repo.stargazers_count > 0) {
    const stars = document.createElement('span');
    stars.className = 'proj-stat';
    stars.innerHTML = `<svg viewBox="0 0 24 24"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`;
    const count = document.createElement('span');
    count.textContent = repo.stargazers_count;
    stars.appendChild(count);
    meta.appendChild(stars);
  }

  if (repo.forks_count > 0) {
    const forks = document.createElement('span');
    forks.className = 'proj-stat';
    forks.innerHTML = `<svg viewBox="0 0 24 24"><circle cx="12" cy="18" r="3"/><circle cx="6" cy="6" r="3"/><circle cx="18" cy="6" r="3"/><path d="M18 9v1a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V9"/><line x1="12" y1="12" x2="12" y2="15"/></svg>`;
    const count = document.createElement('span');
    count.textContent = repo.forks_count;
    forks.appendChild(count);
    meta.appendChild(forks);
  }

  if (repo.topics && repo.topics.length > 0) {
    repo.topics.slice(0, 3).forEach(t => {
      const tag = document.createElement('span');
      tag.className = 'proj-tag';
      tag.textContent = t;
      meta.appendChild(tag);
    });
  }

  a.appendChild(name);
  a.appendChild(desc);
  a.appendChild(meta);
  return a;
}

function renderProjects(repos) {
  const featuredEl = document.getElementById('featured');
  const container = document.getElementById('projects');
  container.innerHTML = '';

  const allRepos = repos
    .filter(r => !r.fork && !r.private && !EXCLUDE.includes(r.name))
    .sort((a, b) => (b.stargazers_count - a.stargazers_count) || new Date(b.updated_at || 0) - new Date(a.updated_at || 0));

  if (allRepos.length === 0) {
    container.innerHTML = `<div class="loading">${t('projects.empty')}</div>`;
    return;
  }

  let fi = 0;
  FEATURED.forEach(name => {
    const repo = allRepos.find(r => r.name === name);
    if (repo) {
      featuredEl.appendChild(buildCard(repo, fi++, true));
    }
  });

  const remaining = allRepos.filter(r => !FEATURED.includes(r.name));
  remaining.forEach((repo, i) => {
    container.appendChild(buildCard(repo, i, false));
  });
}

let lastRepos = null;
fetch('https://api.github.com/users/s-markakis/repos?sort=updated&per_page=30')
  .then(r => {
    if (!r.ok) throw new Error('API error');
    return r.json();
  })
  .then(repos => { lastRepos = repos; renderProjects(repos); })
  .catch(() => { lastRepos = FALLBACK_REPOS; renderProjects(FALLBACK_REPOS); });

document.addEventListener('langchange', () => {
  if (lastRepos) {
    document.getElementById('featured').innerHTML = '';
    renderProjects(lastRepos);
  }
});
