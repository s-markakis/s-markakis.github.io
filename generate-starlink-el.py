#!/usr/bin/env python3
"""
Generate starlink-el.html — a static Greek edition of starlink.html.

Why static: the site's i18n is client-side, so search engines mostly index
the English strings. Greek customers search «εγκατάσταση Starlink Κρήτη»;
this page gives Google real Greek HTML to rank.

How: reads starlink.html, swaps every data-i18n / data-i18n-attr-* element
for its Greek string from js/i18n.js (the translations already exist there),
rewrites the head (title/description/OG/canonical/hreflang/JSON-LD) and pins
the page to Greek via <body data-lang="el">. The nav language button links
back to the English page (data-lang-target).

Re-run after editing starlink.html or the starlink.* strings in i18n.js:
    ./generate-starlink-el.py
"""
import json
import re
from pathlib import Path

SITE = 'https://sp1r4.github.io'
SRC = Path('starlink.html')
OUT = Path('starlink-el.html')
I18N = Path('js/i18n.js')

TITLE = 'Εγκατάσταση Starlink στην Κρήτη — S. Markakis'
DESCRIPTION = ('Επαγγελματική εγκατάσταση Starlink σε όλη την Κρήτη — Ηράκλειο, Χανιά, '
               'Ρέθυμνο, Λασίθι. Αυτοψία, τοποθέτηση και πλήρης ενσωμάτωση δικτύου με '
               'multi-WAN failover, ασφάλεια και απομακρυσμένη διαχείριση.')
OG_DESC = ('Ολοκληρωμένη εγκατάσταση Starlink και διαχειριζόμενη σύνδεση σε όλη την Κρήτη '
           '— αυτοψία, τοποθέτηση και ενσωμάτωση δικτύου με failover και '
           'απομακρυσμένη παρακολούθηση.')
KEYWORDS = ('Starlink Κρήτη, εγκατάσταση Starlink, Starlink εγκατάσταση Κρήτη, '
            'δορυφορικό ίντερνετ Κρήτη, Starlink Ηράκλειο, Starlink Χανιά, '
            'Starlink Ρέθυμνο, Starlink Λασίθι, multi-WAN failover, Cisco, MikroTik, UniFi')


def load_el_translations():
    """Pull the el: { ... } dictionary out of js/i18n.js."""
    js = I18N.read_text()
    start = js.index('    el: {')
    end = js.index('\n    },\n  };', start)
    block = js[start:end]
    pairs = {}
    for m in re.finditer(r"'([\w.]+)':\s*(?:'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\")", block):
        key, sq, dq = m.groups()
        val = sq if sq is not None else dq
        val = val.replace("\\'", "'").replace('\\"', '"').replace('\\u2014', '—')
        pairs[key] = val
    return pairs


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def esc_attr(s):
    return esc(s).replace('"', '&quot;')


def main():
    t = SRC.read_text()
    el = load_el_translations()

    # ── content: data-i18n → static Greek text, attribute dropped ──
    def sub_text(m):
        pre, key, post, _old = m.groups()
        if key not in el:
            raise SystemExit(f'missing EL translation: {key}')
        return f'{pre}{post}>{esc(el[key])}'

    t = re.sub(r'(<[^>]*?)\s*data-i18n="([\w.]+)"([^>]*)>([^<]*)', sub_text, t)

    # ── attributes: data-i18n-attr-X="key" → X="<greek>" ──
    # Substitute through a sentinel name first, then drop the original English
    # attribute wherever a Greek sentinel exists in the same tag (the English
    # copy may sit before or after it), and finally rename sentinel → real.
    def sub_attr(m):
        attr, key = m.groups()
        if key not in el:
            raise SystemExit(f'missing EL translation: {key}')
        return f'__el__{attr}="{esc_attr(el[key])}"'

    t = re.sub(r'data-i18n-attr-([\w-]+)="([\w.]+)"', sub_attr, t)
    for attr in ('aria-label', 'placeholder', 'alt'):
        # English before the sentinel in the same tag
        t = re.sub(rf'\s{attr}="[^"]*"(?=[^<>]*__el__{attr}=)', '', t)
        # English after the sentinel in the same tag
        t = re.sub(rf'(__el__{attr}="[^"]*"[^<>]*?)\s{attr}="[^"]*"', r'\1', t)
    t = t.replace('__el__', '')

    # ── head ──
    t = t.replace('<html lang="en">', '<html lang="el">', 1)
    t = re.sub(r'<title>[^<]*</title>', f'<title>{esc(TITLE)}</title>', t, count=1)
    t = re.sub(r'<meta name="description" content="[^"]*">',
               f'<meta name="description" content="{esc_attr(DESCRIPTION)}">', t, count=1)
    t = re.sub(r'<meta name="keywords" content="[^"]*">',
               f'<meta name="keywords" content="{esc_attr(KEYWORDS)}">', t, count=1)
    t = t.replace(f'<link rel="canonical" href="{SITE}/starlink.html">',
                  f'<link rel="canonical" href="{SITE}/starlink-el.html">', 1)
    t = re.sub(r'<meta property="og:title" content="[^"]*">',
               f'<meta property="og:title" content="{esc_attr(TITLE)}">', t, count=1)
    t = re.sub(r'<meta property="og:description" content="[^"]*">',
               f'<meta property="og:description" content="{esc_attr(OG_DESC)}">', t, count=1)
    t = t.replace(f'<meta property="og:url" content="{SITE}/starlink.html">',
                  f'<meta property="og:url" content="{SITE}/starlink-el.html">', 1)
    t = re.sub(r'<meta name="twitter:title" content="[^"]*">',
               f'<meta name="twitter:title" content="{esc_attr(TITLE)}">', t, count=1)
    t = re.sub(r'<meta name="twitter:description" content="[^"]*">',
               '<meta name="twitter:description" content="Επαγγελματική εγκατάσταση Starlink &amp; διαχειριζόμενη σύνδεση σε όλη την Κρήτη.">', t, count=1)
    t = t.replace('og/starlink.png', 'og/starlink-el.png')
    t = t.replace('<meta property="og:type" content="website">',
                  '<meta property="og:type" content="website">\n<meta property="og:locale" content="el_GR">', 1)

    # hreflang: clean EN/EL pair shared by both editions
    t = re.sub(
        r'<link rel="alternate" hreflang="en"[^>]*>\n'
        r'<link rel="alternate" hreflang="el"[^>]*>\n'
        r'<link rel="alternate" hreflang="x-default"[^>]*>',
        f'<link rel="alternate" hreflang="en" href="{SITE}/starlink.html">\n'
        f'<link rel="alternate" hreflang="el" href="{SITE}/starlink-el.html">\n'
        f'<link rel="alternate" hreflang="x-default" href="{SITE}/starlink.html">',
        t, count=1)

    # ── JSON-LD in Greek ──
    service = {
        "@context": "https://schema.org",
        "@type": "Service",
        "serviceType": "Εγκατάσταση Starlink & Διαχειριζόμενη Σύνδεση",
        "name": "Εγκατάσταση Starlink στην Κρήτη",
        "description": OG_DESC,
        "inLanguage": "el",
        "url": f"{SITE}/starlink-el.html",
        "provider": {
            "@type": "Person",
            "name": "S. Markakis",
            "url": f"{SITE}/",
            "image": f"{SITE}/avatar.jpeg",
            "email": "sp1r4.work@gmail.com",
            "address": {"@type": "PostalAddress", "addressRegion": "Crete", "addressCountry": "GR"},
            "areaServed": {"@type": "AdministrativeArea", "name": "Crete, Greece"},
        },
        "areaServed": [
            {"@type": "AdministrativeArea", "name": "Κρήτη"},
            {"@type": "City", "name": "Ηράκλειο"},
            {"@type": "City", "name": "Χανιά"},
            {"@type": "City", "name": "Ρέθυμνο"},
            {"@type": "City", "name": "Λασίθι"},
        ],
        "hasOfferCatalog": {
            "@type": "OfferCatalog",
            "name": "Πακέτα Starlink",
            "itemListElement": [
                {"@type": "Offer", "itemOffered": {"@type": "Service", "name": el['starlink.pkg.install.t']}},
                {"@type": "Offer", "itemOffered": {"@type": "Service", "name": el['starlink.pkg.managed.t']}},
                {"@type": "Offer", "itemOffered": {"@type": "Service", "name": el['starlink.pkg.business.t']}},
            ],
        },
    }
    faq = {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "inLanguage": "el",
        "mainEntity": [
            {"@type": "Question", "name": el[f'starlink.faq.q{i}'],
             "acceptedAnswer": {"@type": "Answer", "text": el[f'starlink.faq.a{i}']}}
            for i in range(1, 5)
        ],
    }
    blocks = re.findall(r'<script type="application/ld\+json">.*?</script>', t, re.S)
    assert len(blocks) == 2, 'expected 2 JSON-LD blocks'
    t = t.replace(blocks[0], '<script type="application/ld+json">\n'
                  + json.dumps(service, ensure_ascii=False, indent=2) + '\n</script>', 1)
    t = t.replace(blocks[1], '<script type="application/ld+json">\n'
                  + json.dumps(faq, ensure_ascii=False, indent=2) + '\n</script>', 1)

    # ── pin the page to Greek; lang button navigates to the EN edition ──
    t = re.sub(r'<body class="has-nav"[^>]*>',
               '<body class="has-nav" data-lang="el" data-lang-target="starlink.html">', t, count=1)
    t = t.replace('<a href="#main-content" class="skip-link">Skip to content</a>',
                  '<a href="#main-content" class="skip-link">Μετάβαση στο περιεχόμενο</a>', 1)
    t = t.replace('aria-label="Contact methods"', 'aria-label="Τρόποι επικοινωνίας"')
    t = t.replace('<a href="privacy.html">Privacy &amp; Legal</a>',
                  '<a href="privacy.html">Απόρρητο &amp; Νομικά</a>', 1)

    OUT.write_text(t)
    print(f'wrote {OUT}')


if __name__ == '__main__':
    main()
