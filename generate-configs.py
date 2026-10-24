#!/usr/bin/env python3
"""Extract the full per-vendor config of each Build post from its vt-panes and
write writeups/configs/<slug>-{mikrotik.rsc,cisco.txt}. Run after editing a Build
post's configs. Lets readers download the whole config instead of copy-pasting."""
import re,html,glob,os,json,sys
from pathlib import Path
OUT=Path('writeups/configs'); OUT.mkdir(exist_ok=True)
def unesc(s):
    s=re.sub(r'<span class="cmt">','',s).replace('</span>','')
    s=re.sub(r'<[^>]+>','',s)
    return html.unescape(s)
made=[]
for f in sorted(glob.glob('writeups/build-*.html')):
    if f.endswith('build-index.html'): continue
    slug=Path(f).stem; h=open(f,encoding='utf-8').read()
    title=re.search(r'<title>([^<]*)</title>',h).group(1).replace(' — S. Markakis','')
    for vendor,ext in (('mikrotik','rsc'),('cisco','txt')):
        parts=[]
        # every vt-pane for this vendor, in document order; label from the enclosing block
        for m in re.finditer(r'<span class="term-label">([^<]*)</span>.*?<pre class="term vt-pane" data-v="%s"[^>]*>(.*?)</pre>'%vendor,h,re.S):
            lab=html.unescape(m.group(1)); body=unesc(m.group(2)).strip('\n')
            parts.append(f"# ===== {lab} =====" if vendor=='mikrotik' else f"! ===== {lab} =====")
            parts.append(body)
        if not parts: continue
        cm='#' if vendor=='mikrotik' else '!'
        head=[f"{cm} {title} — full {'MikroTik RouterOS' if vendor=='mikrotik' else 'Cisco IOS'} config",
              f"{cm} s-markakis.github.io/writeups/{slug}.html  ·  illustrative / lab reference, review before use",
              f"{cm} secrets shown as ******** — replace them.",""]
        (OUT/f"{slug}-{vendor}.{ext}").write_text('\n'.join(head+parts)+'\n',encoding='utf-8')
        made.append(f"{slug}-{vendor}.{ext}")
print(f"wrote {len(made)} config files to {OUT}")
for m in made: print("  "+m)
