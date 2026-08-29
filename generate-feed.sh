#!/bin/bash
# Generates feed.xml from posts.json
# Usage: ./generate-feed.sh

set -e

SITE="https://s-markakis.github.io"
POSTS_JSON="posts.json"
OUTPUT="feed.xml"

if [ ! -f "$POSTS_JSON" ]; then
  echo "Error: $POSTS_JSON not found" >&2
  exit 1
fi

cat > "$OUTPUT" << 'HEADER'
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>S. Markakis — Blog</title>
    <link>https://s-markakis.github.io/blog.html</link>
    <description>Cybersecurity research, CTF writeups, and development notes by S. Markakis.</description>
    <language>en</language>
    <atom:link href="https://s-markakis.github.io/feed.xml" rel="self" type="application/rss+xml"/>
HEADER

python3 -c "
import json
from datetime import datetime
from xml.sax.saxutils import escape

with open('$POSTS_JSON') as f:
    posts = json.load(f)

posts.sort(key=lambda p: p['date'], reverse=True)

for post in posts:
    date = datetime.strptime(post['date'], '%Y-%m-%d')
    rfc822 = date.strftime('%a, %d %b %Y 00:00:00 GMT')
    tags = ''.join(f'      <category>{escape(t)}</category>\n' for t in post.get('tags', []))
    title = escape(post['title'])
    desc = escape(post['description'])
    slug = escape(post['slug'])
    print(f'''    <item>
      <title>{title}</title>
      <link>$SITE/blog.html#{slug}</link>
      <guid>$SITE/blog.html#{slug}</guid>
      <pubDate>{rfc822}</pubDate>
      <description>{desc}</description>
{tags.rstrip()}
    </item>''')
" >> "$OUTPUT"

cat >> "$OUTPUT" << 'FOOTER'
  </channel>
</rss>
FOOTER

echo "Generated $OUTPUT with $(python3 -c "import json; print(len(json.load(open('$POSTS_JSON'))))" ) posts"
