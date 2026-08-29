#!/bin/bash
# Generates sitemap.xml from posts.json + static pages.
# Usage: ./generate-sitemap.sh

set -e

SITE="https://s-markakis.github.io"
OUTPUT="sitemap.xml"
TODAY=$(date +%Y-%m-%d)

python3 - > "$OUTPUT" <<PYEOF
import json
from xml.sax.saxutils import escape

with open('posts.json') as f:
    posts = json.load(f)

static = [
    ('/', '1.0'),
    ('/services.html', '0.8'),
    ('/starlink.html', '0.9'),
    ('/starlink-el.html', '0.9'),
    ('/writeups/guest-wifi-isolation-el.html', '0.7'),
    ('/writeups/what-is-a-pentest-el.html', '0.7'),
    ('/pentest.html', '0.9'),
    ('/consulting.html', '0.9'),
    ('/projects.html', '0.8'),
    ('/blog.html', '0.8'),
    ('/writeups/start-here.html', '0.7'),
    ('/privacy.html', '0.3'),
]

print('<?xml version="1.0" encoding="UTF-8"?>')
print('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
for path, priority in static:
    print(f'  <url>')
    print(f'    <loc>$SITE{path}</loc>')
    print(f'    <lastmod>$TODAY</lastmod>')
    print(f'    <priority>{priority}</priority>')
    print(f'  </url>')
for p in posts:
    loc = escape(f"$SITE/{p['html']}")
    print(f'  <url>')
    print(f'    <loc>{loc}</loc>')
    print(f"    <lastmod>{p['date']}</lastmod>")
    print(f'    <priority>0.6</priority>')
    print(f'  </url>')
print('</urlset>')
PYEOF

echo "Generated $OUTPUT"
