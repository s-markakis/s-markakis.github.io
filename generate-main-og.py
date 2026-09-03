#!/usr/bin/env python3
"""
Generate per-page Open Graph SVG cards for the top-level site pages
(index, services, projects, blog, 404) and rewrite each page's
og:image / twitter:image meta to point at its own card. Idempotent.

Output: og/<page>.svg, sized 1200x630 (standard OG card).

Usage: ./generate-main-og.py
"""
import re
from pathlib import Path
from xml.sax.saxutils import escape

OG_DIR = Path('og')
OG_DIR.mkdir(exist_ok=True)

SITE = 'https://s-markakis.github.io'

PAGES = [
    {
        'slug': 'index',
        'html': 'index.html',
        'url': f'{SITE}/',
        'kicker': 'CYBERSECURITY · IT',
        'title': 'S. Markakis',
        'description': 'Penetration testing · Network design · Backup systems · Automation. Based in Crete, available remotely.',
    },
    {
        'slug': 'services',
        'html': 'services.html',
        'url': f'{SITE}/services.html',
        'kicker': 'SERVICES',
        'title': 'Cybersecurity & IT',
        'description': 'Penetration testing, security audits, IT infrastructure, Starlink deployment, and consulting.',
    },
    {
        'slug': 'projects',
        'html': 'projects.html',
        'url': f'{SITE}/projects.html',
        'kicker': 'PROJECTS',
        'title': 'Open Source Tools',
        'description': 'Security tools and automation scripts — Python, Bash, and C.',
    },
    {
        'slug': 'blog',
        'html': 'blog.html',
        'url': f'{SITE}/blog.html',
        'kicker': 'BLOG',
        'title': 'Research & Writeups',
        'description': 'HackTheBox walkthroughs, MikroTik RouterOS notes, and security research.',
    },
    {
        'slug': '404',
        'html': '404.html',
        'url': f'{SITE}/404.html',
        'kicker': 'ERROR',
        'title': '404 — Not Found',
        'description': 'The page you were looking for has moved or never existed.',
    },
]

SVG_TEMPLATE = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630" width="1200" height="630">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0a0a0a"/>
      <stop offset="100%" stop-color="#1a1a18"/>
    </linearGradient>
    <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
      <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#222" stroke-width="0.5"/>
    </pattern>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)"/>
  <rect width="1200" height="630" fill="url(#grid)"/>
  <rect x="0" y="0" width="1200" height="6" fill="#c63d1f"/>
  <text x="80" y="160" font-family="Inter, Helvetica, Arial, sans-serif" font-size="24" font-weight="500" fill="#c63d1f" letter-spacing="6">{kicker}</text>
  <text x="80" y="290" font-family="Inter, Helvetica, Arial, sans-serif" font-size="78" font-weight="900" fill="#ffffff" letter-spacing="-2">{title}</text>
  <text x="80" y="370" font-family="Inter, Helvetica, Arial, sans-serif" font-size="26" font-weight="400" fill="#a0a0a0">{description}</text>
  <line x1="80" y1="480" x2="200" y2="480" stroke="#c63d1f" stroke-width="2"/>
  <text x="80" y="540" font-family="Inter, Helvetica, Arial, sans-serif" font-size="32" font-weight="900" fill="#ffffff" letter-spacing="-1">S. MARKAKIS</text>
  <text x="80" y="570" font-family="Inter, Helvetica, Arial, sans-serif" font-size="16" font-weight="400" fill="#888" letter-spacing="3">CYBERSECURITY · IT</text>
  <text x="1120" y="570" font-family="Inter, Helvetica, Arial, sans-serif" font-size="16" font-weight="400" fill="#666" text-anchor="end">s-markakis.github.io</text>
</svg>
'''


def truncate(s: str, n: int) -> str:
    return s if len(s) <= n else s[: n - 1].rstrip() + '…'


def render_svg(page: dict) -> str:
    return SVG_TEMPLATE.format(
        kicker=escape(page['kicker'][:50]),
        title=escape(truncate(page['title'], 32)),
        description=escape(truncate(page['description'], 90)),
    )


def update_meta(html_path: Path, page: dict) -> bool:
    text = html_path.read_text()
    # Point at the PNG, not the SVG we just wrote: LinkedIn, Facebook, WhatsApp
    # and Telegram do not render an SVG og:image. generate-og-png.py renders the
    # matching PNG from the same layout; the SVG stays as the editable source.
    og_url = f'{SITE}/og/{page["slug"]}.png'

    new_text = text
    new_text = re.sub(
        r'(<meta\s+property="og:image"\s+content=")[^"]*("\s*>)',
        rf'\g<1>{og_url}\g<2>',
        new_text,
        count=1,
    )
    new_text = re.sub(
        r'(<meta\s+name="twitter:image"\s+content=")[^"]*("\s*>)',
        rf'\g<1>{og_url}\g<2>',
        new_text,
        count=1,
    )

    if new_text == text:
        return False
    html_path.write_text(new_text)
    return True


def main():
    for page in PAGES:
        html = Path(page['html'])
        svg = render_svg(page)
        (OG_DIR / f'{page["slug"]}.svg').write_text(svg)
        if html.is_file():
            updated = update_meta(html, page)
            print(f'  {page["slug"]}: og/{page["slug"]}.svg written, meta {"updated" if updated else "unchanged"}')
        else:
            print(f'  {page["slug"]}: og/{page["slug"]}.svg written, html not found (no meta update)')


if __name__ == '__main__':
    main()
