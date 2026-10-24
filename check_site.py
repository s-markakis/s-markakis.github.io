#!/usr/bin/env python3
"""Deep static checks for the site — the recurring bug classes that browsers
silently auto-recover (so they're invisible without a check). Exits non-zero on
any problem. Run locally before pushing, and in CI.
Checks: per-HTML tag balance (pre/details/div/span), JSON-LD parses, bx-data JSON
parses, every local og:image file exists, every writeups/*-el.html is in sitemap."""
import re,json,glob,sys
from pathlib import Path
errs=[]
def bal(h,t): return h.count('<'+t+(' ' if t in('div','pre','span','details') else ''))  # not used
for f in sorted(glob.glob('**/*.html',recursive=True)):
    if f.startswith('pagefind/'): continue
    h=open(f,encoding='utf-8').read()
    for t in ('pre','details'):
        o=len(re.findall(r'<'+t+r'[ >]',h)); c=h.count('</'+t+'>')
        if o!=c: errs.append(f"{f}: <{t}> {o} open / {c} close")
    for t in ('div','span'):
        o=len(re.findall(r'<'+t+r'[ >]',h)); c=h.count('</'+t+'>')
        if o!=c: errs.append(f"{f}: <{t}> {o} open / {c} close")
    for m in re.finditer(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',h,re.S):
        try: json.loads(m.group(1))
        except Exception as e: errs.append(f"{f}: JSON-LD parse error: {e}")
    m=re.search(r'<script[^>]*id="bx-data"[^>]*>(.*?)</script>',h,re.S)
    if m:
        try: json.loads(m.group(1))
        except Exception as e: errs.append(f"{f}: bx-data JSON error: {e}")
    for mm in re.finditer(r'<meta property="og:image" content="([^"]+)"',h):
        u=mm.group(1)
        p=u.split('s-markakis.github.io/',1)[-1].lstrip('/') if 's-markakis.github.io' in u else u.lstrip('/')
        if p and not u.startswith('data:') and '://' not in p and not Path(p).exists():
            errs.append(f"{f}: og:image missing file: {p}")
# every -el writeup must be in sitemap
sm=Path('sitemap.xml').read_text(encoding='utf-8') if Path('sitemap.xml').exists() else ''
for el in glob.glob('writeups/*-el.html'):
    if el not in sm:
        errs.append(f"sitemap.xml: missing {el}")
if errs:
    print("check_site FAILED:"); [print("  - "+e) for e in errs]; sys.exit(1)
print(f"check_site OK: {len(glob.glob('**/*.html',recursive=True))} html files, markup/JSON-LD/bx-data/OG/sitemap all consistent")
