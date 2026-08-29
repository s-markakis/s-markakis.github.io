#!/usr/bin/env python3
"""
Render the per-page Open Graph cards as PNG (1200x630).

Social platforms (LinkedIn, Facebook, X) don't render SVG og:image, so we
ship PNGs. Layout mirrors the og/*.svg cards: dark gradient + grid, accent
top bar, tracked tag label, bold title, description, wordmark, footer.

Self-contained: uses Pillow + a macOS system sans (Arial, the SVG's declared
fallback). No SVG renderer required.

Output: og/<name>.png    Usage: ./generate-og-png.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path('og')
W, H = 1200, 630

ACCENT = (198, 61, 31)      # #c63d1f
WHITE = (255, 255, 255)
GRAY = (160, 160, 160)      # #a0a0a0
GRAY2 = (136, 136, 136)     # #888
GRAY3 = (102, 102, 102)     # #666
GRID = (34, 34, 34)         # #222
BG_TOP = (10, 10, 10)       # #0a0a0a
BG_BOT = (26, 26, 24)       # #1a1a18

FONT_BLACK = '/System/Library/Fonts/Supplemental/Arial Black.ttf'
FONT_BOLD = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
FONT_REG = '/System/Library/Fonts/Supplemental/Arial.ttf'

# Each card: tag (tracked label), title, description, footer (tracked label).
CARDS = {
    'index': ('CYBERSECURITY · IT', 'S. Markakis',
              'Penetration testing · Network engineering · Backup systems · Automation. Based in Crete, available remotely worldwide.',
              'CYBERSECURITY · IT'),
    'services': ('SERVICES', 'Cybersecurity & IT',
                 'Penetration testing, network engineering & design, IT consulting, and Starlink deployment.',
                 'CYBERSECURITY · IT'),
    'projects': ('PROJECTS', 'Open Source Tools',
                 'Security tools and automation scripts — Python, Bash, and C.',
                 'CYBERSECURITY · IT'),
    'blog': ('BLOG', 'Research & Writeups',
             'HackTheBox walkthroughs, MikroTik RouterOS notes, and security research.',
             'CYBERSECURITY · IT'),
    'starlink': ('STARLINK · CRETE', 'Starlink Installation',
                 'Site survey, install, and MikroTik network integration with failover & remote management.',
                 'MANAGED CONNECTIVITY · CRETE'),
    'starlink-el': ('STARLINK · ΚΡΗΤΗ', 'Εγκατάσταση Starlink',
                    'Αυτοψία, εγκατάσταση και ενσωμάτωση δικτύου MikroTik με failover και απομακρυσμένη διαχείριση.',
                    'MANAGED CONNECTIVITY · CRETE'),
    'pentest': ('PENETRATION TESTING', 'Offensive Security',
                'Web, API, network & cloud testing — find the vulnerabilities before attackers do.',
                'PENETRATION TESTING · REMOTE WORLDWIDE'),
    'consulting': ('IT CONSULTING · NETWORK ENGINEERING', 'Networks & Architecture',
                   'MikroTik network design, infrastructure & security strategy — grounded in real engineering.',
                   'IT CONSULTING · REMOTE WORLDWIDE'),
}


def font(path, size):
    return ImageFont.truetype(path, size)


def text_w(draw, s, f):
    return draw.textlength(s, font=f)


def baseline(draw, x, by, s, f, fill):
    """Draw with `by` as the text baseline (matches SVG y coords)."""
    ascent, _ = f.getmetrics()
    draw.text((x, by - ascent), s, font=f, fill=fill)


def tracked(draw, x, by, s, f, fill, tracking, right=None):
    """Letter-spaced text on a baseline. If `right` is set, right-align to it."""
    if right is not None:
        total = sum(text_w(draw, c, f) + tracking for c in s) - tracking
        x = right - total
    ascent, _ = f.getmetrics()
    top = by - ascent
    for c in s:
        draw.text((x, top), c, font=f, fill=fill)
        x += text_w(draw, c, f) + tracking


def wrap(draw, s, f, maxw):
    words, lines, cur = s.split(), [], ''
    for word in words:
        trial = (cur + ' ' + word).strip()
        if text_w(draw, trial, f) <= maxw or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def gradient():
    img = Image.new('RGB', (W, H))
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        col = tuple(round(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = col
    return img


def render(name, tag, title, desc, footer):
    img = gradient()
    d = ImageDraw.Draw(img)

    for gx in range(0, W + 1, 40):
        d.line([(gx, 0), (gx, H)], fill=GRID, width=1)
    for gy in range(0, H + 1, 40):
        d.line([(0, gy), (W, gy)], fill=GRID, width=1)

    d.rectangle([0, 0, W, 6], fill=ACCENT)

    tracked(d, 80, 160, tag, font(FONT_BOLD, 24), ACCENT, 6)

    # Title: shrink to fit one line within the content width.
    tw = 1040
    size = 78
    tf = font(FONT_BLACK, size)
    while text_w(d, title, tf) > tw and size > 48:
        size -= 4
        tf = font(FONT_BLACK, size)
    baseline(d, 80, 290, title, tf, WHITE)

    df = font(FONT_REG, 26)
    dy = 360
    for line in wrap(d, desc, df, 1040):
        baseline(d, 80, dy, line, df, GRAY)
        dy += 36

    d.line([(80, 480), (200, 480)], fill=ACCENT, width=2)
    baseline(d, 80, 540, 'S. MARKAKIS', font(FONT_BLACK, 32), WHITE)
    tracked(d, 80, 570, footer, font(FONT_REG, 16), GRAY2, 3)
    tracked(d, 0, 570, 'sp1r4.github.io', font(FONT_REG, 16), GRAY3, 0, right=1120)

    out = OUT / f'{name}.png'
    img.save(out, 'PNG')
    print(f'  wrote {out}')


def main():
    for name, (tag, title, desc, footer) in CARDS.items():
        render(name, tag, title, desc, footer)


if __name__ == '__main__':
    main()
