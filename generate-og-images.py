#!/usr/bin/env python3
"""
Generate per-writeup Open Graph SVG images and inject the meta tags
into each writeup HTML <head>. Idempotent.

Output: writeups/assets/og/<slug>.svg
Each SVG is 1200x630 (standard OG card size).

Usage: ./generate-og-images.py
"""
import json
import re
from pathlib import Path
from xml.sax.saxutils import escape

OG_DIR = Path('writeups/assets/og')
OG_DIR.mkdir(parents=True, exist_ok=True)

SITE = 'https://s-markakis.github.io'

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
  <text x="80" y="160" font-family="Inter, Helvetica, Arial, sans-serif" font-size="24" font-weight="500" fill="#c63d1f" letter-spacing="6">{tag_label}</text>
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

def render_svg(post: dict) -> str:
    title = truncate(post['title'], 32)
    desc = truncate(post['description'], 70)
    tag_label = ' · '.join(t.upper() for t in post.get('tags', []))[:50]
    return SVG_TEMPLATE.format(
        title=escape(title),
        description=escape(desc),
        tag_label=escape(tag_label),
    )

def inject_og(html_path: Path, slug: str, post: dict) -> bool:
    text = html_path.read_text()
    # Platforms don't render SVG og:image, so meta tags point at the PNG
    # (rendered by generate-writeup-og-png.py); the SVG is the design source.
    rel = f'assets/og/{slug}.png'
    abs_url = f'{SITE}/writeups/{rel}'
    desc = post['description']
    title = f"{post['title']} — S. Markakis"

    block = (
        f'<meta name="description" content="{escape(desc)}">\n'
        f'<meta property="og:title" content="{escape(title)}">\n'
        f'<meta property="og:description" content="{escape(desc)}">\n'
        f'<meta property="og:type" content="article">\n'
        f'<meta property="og:url" content="{SITE}/writeups/{slug}.html">\n'
        f'<meta property="og:image" content="{abs_url}">\n'
        f'<meta name="twitter:card" content="summary_large_image">\n'
        f'<meta name="twitter:image" content="{abs_url}">\n'
        f'<link rel="canonical" href="{SITE}/writeups/{slug}.html">\n'
    )

    text = re.sub(r'\s*<meta\s+(?:name|property)="(description|og:[^"]+|twitter:[^"]+)"[^>]*>', '', text)
    text = re.sub(r'\s*<link\s+rel="canonical"[^>]*>', '', text)
    new_text, n = re.subn(
        r'(<title>[^<]*</title>)',
        r'\1\n' + block,
        text,
        count=1,
    )
    if n == 0:
        return False
    if new_text == text:
        return False
    html_path.write_text(new_text)
    return True


def main():
    posts = json.loads(Path('posts.json').read_text())
    for post in posts:
        slug = post['slug']
        html = Path(post['html'])
        if not html.is_file():
            print(f'  skip {slug}: html not found')
            continue
        svg = render_svg(post)
        (OG_DIR / f'{slug}.svg').write_text(svg)
        injected = inject_og(html, slug, post)
        print(f'  {slug}: og.svg written, meta {"injected" if injected else "unchanged"}')


if __name__ == '__main__':
    main()
