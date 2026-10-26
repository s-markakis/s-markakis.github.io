#!/usr/bin/env python3
"""
Generate the Greek editions of the service pages — services-el.html,
consulting-el.html, pentest-el.html — as static twins of their English sources.

Why static: the site's i18n is client-side, so crawlers mostly index the English
strings and the root pages' hreflang pointed at `?lang=el` (same HTML per param =
a weak signal). These twins give Google real Greek HTML on its own URL, with
reciprocal hreflang and Greek JSON-LD.

How: reads the English source, swaps every data-i18n / data-i18n-attr-* node for
its Greek string from js/i18n.js (translations already live there), rewrites the
head (title/description/keywords/OG/canonical/hreflang) and the JSON-LD into
Greek, and pins the page to Greek via <body data-lang="el" data-lang-target=...>.
OG card images are REUSED from the English edition (no -el cards exist in
generate-og-png.py's CARDS dict, and the card art is brand/domain, not prose).

Companion to generate-starlink-el.py (same approach, generalised to N pages).
Re-run after editing a source page or its *.* strings in i18n.js:
    python3 generate-el.py
"""
import json
import re
from pathlib import Path

SITE = 'https://s-markakis.github.io'
I18N = Path('js/i18n.js')

PROVIDER = {
    "@type": "Person",
    "name": "S. Markakis",
    "url": f"{SITE}/",
    "image": f"{SITE}/avatar.jpeg",
    "email": "sp1r4.work@gmail.com",
    "address": {"@type": "PostalAddress", "addressRegion": "Crete", "addressCountry": "GR"},
}
AREA_REMOTE = {"@type": "Place", "name": "Παγκόσμια (απομακρυσμένα)"}

PAGES = [
    {
        'name': 'services',
        'title': 'Υπηρεσίες — S. Markakis',
        'description': ('Υπηρεσίες Cybersecurity & IT από τον S. Markakis — penetration '
                        'testing, IT consulting & network engineering, εγκατάσταση Starlink '
                        'και εγκατάσταση καμερών CCTV. Έδρα στην Κρήτη· απομακρυσμένα παγκοσμίως.'),
        'og_desc': ('Penetration testing, IT consulting & network engineering, εγκατάσταση '
                    'Starlink και εγκατάσταση καμερών CCTV.'),
        'keywords': ('υπηρεσίες IT Κρήτη, penetration testing, δικτύωση, network engineering, '
                     'εγκατάσταση Starlink Κρήτη, κάμερες CCTV Κρήτη, IT consulting, Cisco, '
                     'MikroTik, UniFi'),
        'service': None,
        'faq_keys': [],
        'extra_faq': [],
        'rich_keys': [],
    },
    {
        'name': 'consulting',
        'title': 'IT Consulting & Δικτύωση — S. Markakis',
        'description': ('Ανεξάρτητο IT consulting και network engineering — σχεδιασμός δικτύου '
                        '(Cisco, MikroTik, UniFi), αρχιτεκτονική συστημάτων και cloud, υποδομές '
                        'και στρατηγική ασφάλειας, με πρακτική υποστήριξη υλοποίησης. '
                        'Απομακρυσμένα παγκοσμίως, επιτόπου σε όλη την Κρήτη.'),
        'og_desc': ('Σχεδιασμός δικτύου, αρχιτεκτονική υποδομών, επιλογή τεχνολογίας και '
                    'στρατηγική ασφάλειας — απομακρυσμένα και επιτόπου στην Κρήτη.'),
        'keywords': ('IT consulting Κρήτη, network engineering, σχεδιασμός δικτύου, Cisco, '
                     'MikroTik, UniFi, αρχιτεκτονική δικτύου, στρατηγική ασφάλειας, '
                     'σύμβουλος IT Κρήτη'),
        'service': {
            'serviceType': 'IT Consulting & Network Engineering',
            'name': 'IT Consulting & Δικτύωση',
            'description': ('Ανεξάρτητο IT consulting και network engineering — σχεδιασμός '
                            'δικτύου (Cisco, MikroTik, UniFi), αρχιτεκτονική συστημάτων και '
                            'cloud, υποδομές και στρατηγική ασφάλειας, με πρακτική υποστήριξη '
                            'υλοποίησης. Απομακρυσμένα παγκοσμίως, επιτόπου σε όλη την Κρήτη.'),
            'catalog_name': 'Υπηρεσίες συμβουλευτικής',
            'offer_keys': ['consulting.pkg.call.t', 'consulting.pkg.project.t',
                           'consulting.pkg.retainer.t'],
        },
        'faq_keys': [(f'consulting.faq.q{i}', f'consulting.faq.a{i}') for i in range(1, 6)],
        'extra_faq': [],
        'rich_keys': [],
    },
    {
        'name': 'pentest',
        'title': 'Penetration Testing — S. Markakis',
        'description': ('Ανεξάρτητο, χειροκίνητο penetration testing για web εφαρμογές, APIs, '
                        'δίκτυα και cloud — με μεθοδολογία (OWASP, PTES), σαφή και ιεραρχημένη '
                        'αναφορά εστιασμένη στις διορθώσεις, και δωρεάν επανέλεγχο. '
                        'Απομακρυσμένα παγκοσμίως.'),
        'og_desc': ('Χειροκίνητο penetration testing για web, API, δίκτυα και cloud — '
                    'μεθοδολογία OWASP/PTES, σαφής αναφορά και δωρεάν retest.'),
        'keywords': ('penetration testing Κρήτη, έλεγχος διείσδυσης, pentest, web application '
                     'testing, API security, δοκιμές ασφάλειας, OWASP, PTES, ethical hacking, '
                     'red team, Ελλάδα'),
        'service': {
            'serviceType': 'Penetration Testing & Offensive Security',
            'name': 'Υπηρεσίες Penetration Testing',
            'description': ('Ανεξάρτητο, χειροκίνητο penetration testing για web εφαρμογές, '
                            'APIs, δίκτυα και cloud — με μεθοδολογία (OWASP, PTES), σαφή και '
                            'ιεραρχημένη αναφορά εστιασμένη στις διορθώσεις, και δωρεάν '
                            'επανέλεγχο. Απομακρυσμένα παγκοσμίως.'),
            'catalog_name': 'Αναθέσεις penetration testing',
            'offer_keys': ['pentest.pkg.focused.t', 'pentest.pkg.full.t', 'pentest.pkg.cont.t'],
        },
        'faq_keys': [(f'pentest.faq.q{i}', f'pentest.faq.a{i}') for i in range(1, 6)],
        'extra_faq': [(
            'Βρήκατε ευπάθεια σε αυτό το site ή στα open-source εργαλεία μου;',
            'Αναφέρετέ τη απευθείας — καλόπιστη έρευνα στο s-markakis.github.io, στον '
            'Cloudflare Worker του ή στα δημοσιευμένα open-source projects είναι ευπρόσδεκτη. '
            'Δεν υπάρχει πρόγραμμα bounty αυτή τη στιγμή, αλλά γρήγορη απόκριση και αναφορά '
            '(credit) κατόπιν αιτήματος, υπό ένα τυπικό καλόπιστο safe harbor.'
        )],
        'rich_keys': ['pentest.authz'],
    },
]


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


def build_jsonld(cfg, el):
    """Greek Service + FAQPage blocks (in the page's source order)."""
    name = cfg['name']
    blocks = []
    svc = cfg['service']
    service = {
        "@context": "https://schema.org",
        "@type": "Service",
        "serviceType": svc['serviceType'],
        "name": svc['name'],
        "description": svc['description'],
        "inLanguage": "el",
        "url": f"{SITE}/{name}-el.html",
        "provider": PROVIDER,
        "areaServed": AREA_REMOTE,
        "hasOfferCatalog": {
            "@type": "OfferCatalog",
            "name": svc['catalog_name'],
            "itemListElement": [
                {"@type": "Offer", "itemOffered": {"@type": "Service", "name": el[k]}}
                for k in svc['offer_keys']
            ],
        },
    }
    blocks.append(service)
    qa = [(el[q], el[a]) for q, a in cfg['faq_keys']] + cfg['extra_faq']
    faq = {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "inLanguage": "el",
        "mainEntity": [
            {"@type": "Question", "name": q,
             "acceptedAnswer": {"@type": "Answer", "text": a}}
            for q, a in qa
        ],
    }
    blocks.append(faq)
    return blocks


def generate(cfg, el):
    name = cfg['name']
    src = Path(f'{name}.html')
    out = Path(f'{name}-el.html')
    t = src.read_text()

    # ── rich elements (data-i18n node that contains child markup): replace the
    # whole inner content with the plain EL text. i18n.js assigns textContent,
    # so the child markup is flattened on the live page anyway. ──
    for rk in cfg['rich_keys']:
        if rk not in el:
            raise SystemExit(f'missing EL translation: {rk}')
        pat = re.compile(r'(<(\w+)[^>]*?)\s*data-i18n="' + re.escape(rk) + r'"([^>]*)>.*?(</\2>)', re.S)
        t, n = pat.subn(lambda m: f'{m.group(1)}{m.group(3)}>{esc(el[rk])}{m.group(4)}', t, count=1)
        if n != 1:
            raise SystemExit(f'rich_key not matched exactly once: {rk}')

    # ── content: data-i18n → static Greek text, attribute dropped ──
    def sub_text(m):
        pre, key, post, _old = m.groups()
        if key not in el:
            raise SystemExit(f'missing EL translation: {key}')
        return f'{pre}{post}>{esc(el[key])}'

    t = re.sub(r'(<[^>]*?)\s*data-i18n="([\w.]+)"([^>]*)>([^<]*)', sub_text, t)

    # ── attributes: data-i18n-attr-X="key" → X="<greek>" ──
    def sub_attr(m):
        attr, key = m.groups()
        if key not in el:
            raise SystemExit(f'missing EL translation: {key}')
        return f'__el__{attr}="{esc_attr(el[key])}"'

    t = re.sub(r'data-i18n-attr-([\w-]+)="([\w.]+)"', sub_attr, t)
    for attr in ('aria-label', 'placeholder', 'alt', 'title'):
        t = re.sub(rf'\s{attr}="[^"]*"(?=[^<>]*__el__{attr}=)', '', t)
        t = re.sub(rf'(__el__{attr}="[^"]*"[^<>]*?)\s{attr}="[^"]*"', r'\1', t)
    t = t.replace('__el__', '')

    # ── head ──
    t = t.replace('<html lang="en">', '<html lang="el">', 1)
    t = re.sub(r'<title>[^<]*</title>', f'<title>{esc(cfg["title"])}</title>', t, count=1)
    t = re.sub(r'<meta name="description" content="[^"]*">',
               f'<meta name="description" content="{esc_attr(cfg["description"])}">', t, count=1)

    # keywords: replace if present, else insert after description
    if re.search(r'<meta name="keywords" content="[^"]*">', t):
        t = re.sub(r'<meta name="keywords" content="[^"]*">',
                   f'<meta name="keywords" content="{esc_attr(cfg["keywords"])}">', t, count=1)
    else:
        t = re.sub(r'(<meta name="description" content="[^"]*">)',
                   rf'\1\n<meta name="keywords" content="{esc_attr(cfg["keywords"])}">', t, count=1)

    t = t.replace(f'<link rel="canonical" href="{SITE}/{name}.html">',
                  f'<link rel="canonical" href="{SITE}/{name}-el.html">', 1)
    t = re.sub(r'<meta property="og:title" content="[^"]*">',
               f'<meta property="og:title" content="{esc_attr(cfg["title"])}">', t, count=1)
    t = re.sub(r'<meta property="og:description" content="[^"]*">',
               f'<meta property="og:description" content="{esc_attr(cfg["og_desc"])}">', t, count=1)
    t = t.replace(f'<meta property="og:url" content="{SITE}/{name}.html">',
                  f'<meta property="og:url" content="{SITE}/{name}-el.html">', 1)
    # twitter:title / twitter:description (present on some pages only)
    t = re.sub(r'<meta name="twitter:title" content="[^"]*">',
               f'<meta name="twitter:title" content="{esc_attr(cfg["title"])}">', t, count=1)
    t = re.sub(r'<meta name="twitter:description" content="[^"]*">',
               f'<meta name="twitter:description" content="{esc_attr(cfg["og_desc"])}">', t, count=1)
    # og:locale
    t = t.replace('<meta property="og:type" content="website">',
                  '<meta property="og:type" content="website">\n'
                  '<meta property="og:locale" content="el_GR">', 1)

    # hreflang: clean EN/EL pair shared by both editions
    t = re.sub(
        r'<link rel="alternate" hreflang="en"[^>]*>\s*\n\s*'
        r'<link rel="alternate" hreflang="el"[^>]*>\s*\n\s*'
        r'<link rel="alternate" hreflang="x-default"[^>]*>',
        f'<link rel="alternate" hreflang="en" href="{SITE}/{name}.html">\n'
        f'<link rel="alternate" hreflang="el" href="{SITE}/{name}-el.html">\n'
        f'<link rel="alternate" hreflang="x-default" href="{SITE}/{name}.html">',
        t, count=1)

    # ── JSON-LD (Service + FAQ) in Greek ──
    if cfg['service']:
        new = build_jsonld(cfg, el)
        found = re.findall(r'<script type="application/ld\+json">.*?</script>', t, re.S)
        if len(found) != len(new):
            raise SystemExit(f'{name}: expected {len(new)} JSON-LD blocks, found {len(found)}')
        for old_block, obj in zip(found, new):
            t = t.replace(old_block, '<script type="application/ld+json">\n'
                          + json.dumps(obj, ensure_ascii=False, indent=2) + '\n</script>', 1)

    # ── pin the page to Greek; lang button navigates to the EN edition ──
    t = re.sub(r'<body\b([^>]*)>',
               lambda m: f'<body{m.group(1)} data-lang="el" data-lang-target="{name}.html">',
               t, count=1)
    t = t.replace('<a href="#main-content" class="skip-link">Skip to content</a>',
                  '<a href="#main-content" class="skip-link">Μετάβαση στο περιεχόμενο</a>', 1)
    t = t.replace('aria-label="Contact methods"', 'aria-label="Τρόποι επικοινωνίας"')
    t = t.replace('<a href="privacy.html">Privacy &amp; Legal</a>',
                  '<a href="privacy.html">Απόρρητο &amp; Νομικά</a>', 1)

    out.write_text(t)
    print(f'wrote {out}')


def main():
    el = load_el_translations()
    for cfg in PAGES:
        generate(cfg, el)


if __name__ == '__main__':
    main()
