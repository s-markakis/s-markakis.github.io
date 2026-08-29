#!/usr/bin/env python3
"""
Inject schema.org BlogPosting JSON-LD into each writeup HTML based on
posts.json. Idempotent: replaces any existing block with the same id.
"""
import json
import re
from pathlib import Path

SITE = 'https://sp1r4.github.io'
MARKER_ID = 'sp1r4-jsonld'

with open('posts.json') as f:
    posts = json.load(f)

for post in posts:
    html = Path(post['html'])
    if not html.is_file():
        continue
    text = html.read_text()

    payload = {
        '@context': 'https://schema.org',
        '@type': 'BlogPosting',
        'headline': post['title'],
        'description': post['description'],
        'datePublished': post['date'],
        'dateModified': post['date'],
        'author': {'@type': 'Person', 'name': 'S. Markakis', 'url': f'{SITE}/'},
        'publisher': {'@type': 'Person', 'name': 'S. Markakis', 'url': f'{SITE}/'},
        'url': f'{SITE}/{post["html"]}',
        'image': f'{SITE}/writeups/assets/og/{post["slug"]}.png',
        'keywords': post.get('tags', []),
        'mainEntityOfPage': {'@type': 'WebPage', '@id': f'{SITE}/blog.html#{post["slug"]}'},
    }
    if post.get('reading_time'):
        payload['timeRequired'] = f'PT{post["reading_time"]}M'

    block = (
        f'<script id="{MARKER_ID}" type="application/ld+json">\n'
        + json.dumps(payload, ensure_ascii=False, indent=2)
        + '\n</script>\n'
    )

    text_no_old = re.sub(
        rf'<script id="{MARKER_ID}"[^>]*>.*?</script>\n?',
        '',
        text,
        flags=re.DOTALL,
    )
    new_text = re.sub(r'</head>', block + '</head>', text_no_old, count=1)
    if new_text != text:
        html.write_text(new_text)
        print(f'  {post["slug"]}: injected')
    else:
        print(f'  {post["slug"]}: unchanged')
