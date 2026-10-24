#!/bin/bash
# Generates sitemap.xml from posts.json + static pages.
# Usage: ./generate-sitemap.sh

set -e

SITE="https://s-markakis.github.io"
OUTPUT="sitemap.xml"
TODAY=$(date +%Y-%m-%d)

python3 - > "$OUTPUT" <<PYEOF
import json, glob
from xml.sax.saxutils import escape

with open('posts.json') as f:
    posts = json.load(f)

# Date of each EN writeup, so its Greek twin can reuse it as lastmod.
en_date = {p['html']: p['date'] for p in posts}

static = [
    ('/', '1.0'),
    ('/services.html', '0.8'),
    ('/managed.html', '0.9'),
    ('/managed-el.html', '0.9'),
    ('/starlink.html', '0.9'),
    ('/starlink-el.html', '0.9'),
    ('/starlink-rethymno.html', '0.8'),
    ('/starlink-rethymno-el.html', '0.8'),
    ('/wifi-airbnb-chania.html', '0.8'),
    ('/wifi-airbnb-chania-el.html', '0.8'),
    ('/cctv-villas-crete.html', '0.8'),
    ('/cctv-villas-crete-el.html', '0.8'),
    ('/writeups/guest-wifi-isolation-el.html', '0.7'),
    ('/writeups/what-is-a-pentest-el.html', '0.7'),
    ('/pentest.html', '0.9'),
    ('/consulting.html', '0.9'),
    ('/projects.html', '0.8'),
    ('/blog.html', '0.8'),
    ('/writeups/start-here.html', '0.7'),
    ('/privacy.html', '0.3'),
]

seen = set()

def emit(loc, lastmod, priority):
    if loc in seen:
        return
    seen.add(loc)
    print(f'  <url>')
    print(f'    <loc>{loc}</loc>')
    print(f'    <lastmod>{lastmod}</lastmod>')
    print(f'    <priority>{priority}</priority>')
    print(f'  </url>')

print('<?xml version="1.0" encoding="UTF-8"?>')
print('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
for path, priority in static:
    emit(f'$SITE{path}', '$TODAY', priority)
for p in posts:
    emit(escape(f"$SITE/{p['html']}"), p['date'], '0.6')
# Greek writeup twins live on disk but not in posts.json (kept out of the EN
# feed); include every one so it's sitemap-discoverable, dated from its EN twin.
for f in sorted(glob.glob('writeups/*-el.html')):
    en = f[:-len('-el.html')] + '.html'
    emit(escape(f'$SITE/{f}'), en_date.get(en, '$TODAY'), '0.5')
print('</urlset>')
PYEOF

echo "Generated $OUTPUT"
