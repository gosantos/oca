#!/usr/bin/env python3
"""Check a published artifact against the skill's objective rules.

usage: check.py <site-dir> <slug> <lang> [BASE]
Prints one JSON object with an `expectations` list of {text, passed, evidence}.
"""

import json, os, re, sys, urllib.request, urllib.error

LANGS = {  # lang -> (dir, Noto family or None)
    "en": ("ltr", None),
    "es": ("ltr", None),
    "fr": ("ltr", None),
    "de": ("ltr", None),
    "ru": ("ltr", None),
    "zh-CN": ("ltr", "Noto+Sans+SC"),
    "ja": ("ltr", "Noto+Sans+JP"),
    "hi": ("ltr", "Noto+Sans+Devanagari"),
    "bn": ("ltr", "Noto+Sans+Bengali"),
    "ar": ("rtl", "Noto+Sans+Arabic"),
}
SCRIPT = {
    "zh-CN": r"[一-鿿]",
    "ja": r"[぀-ヿ]",
    "hi": r"[ऀ-ॿ]",
    "bn": r"[ঀ-৿]",
    "ar": r"[؀-ۿ]",
    "ru": r"[Ѐ-ӿ]",
}


def status(url):
    try:
        return urllib.request.urlopen(url, timeout=20).status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception as e:
        return str(e)


def main():
    site, slug, lang = sys.argv[1:4]
    base = sys.argv[4].rstrip("/") if len(sys.argv) > 4 else None
    out = []
    add = lambda text, ok, ev="": out.append(
        {"text": text, "passed": bool(ok), "evidence": str(ev)[:200]}
    )
    try:
        html = open(f"{site}/{slug}/index.html", encoding="utf-8").read()
    except OSError as e:
        add("page exists", False, e)
        print(json.dumps({"expectations": out}, ensure_ascii=False))
        return
    add("page exists", True, f"{len(html)} bytes")
    add(
        "slug is <6hex>-kebab-case",
        re.fullmatch(r"[0-9a-f]{6}-[a-z0-9]+(-[a-z0-9]+)*", slug),
        slug,
    )
    add(
        "no template placeholders left",
        not re.search(r"\{\{[A-Z_]+\}\}", html),
        re.findall(r"\{\{[A-Z_]+\}\}", html),
    )
    want_dir, font = LANGS[lang]
    m = re.search(r"<html[^>]*>", html)
    tag = m.group(0) if m else ""
    add(f"html lang={lang}", re.search(rf'lang="{re.escape(lang)}"', tag, re.I), tag)
    add(f"html dir={want_dir}", f'dir="{want_dir}"' in tag, tag)
    if font:
        add(f"loads {font}", font in html, font)
        body = html.split("<body", 1)[-1]
        bad = re.findall(
            r'class="[^"]*\b(uppercase|tracking-widest|tracking-wider)\b', body
        )
        add("no uppercase/wide tracking in non-Latin page", not bad, bad[:5])
    phys = re.findall(
        r"\b(text-right|text-left|p[lr]-\d+|m[lr]-\d+|border-[lr](?:-\d)?)\b",
        html.split("<body", 1)[-1],
    )
    add("logical (start/end) classes only", not phys, sorted(set(phys)))
    colors = set(
        re.findall(
            r"\b(?:text|bg|border)-(red|green|emerald|blue|sky|indigo|violet|purple|pink|rose|orange|amber|yellow|lime|teal|cyan)-\d{2,3}\b",
            html,
        )
    )
    add("only emerald/red accents", colors <= {"emerald", "red"}, sorted(colors))
    deco = re.findall(r"\b(shadow(?:-\w+)?|bg-gradient-\w+)\b", html)
    add("no shadows or gradients", not deco, deco[:5])
    abs_links = re.findall(r'href="/(?!/)[^"]*"', html)
    add("internal links are relative", not abs_links, abs_links[:5])
    if lang in SCRIPT:
        text = re.sub(
            r"<script.*?</script>|<style.*?</style>|<[^>]+>", " ", html, flags=re.S
        )
        n = len(re.findall(SCRIPT[lang], text))
        add(f"visible text uses the {lang} script", n > 50, f"{n} chars")
    if lang == "ar" and "new Chart" in html:
        add("RTL chart x-axis reversed", re.search(r"reverse\s*:\s*true", html), "")
    add("no site/index.html listing", not os.path.exists(f"{site}/index.html"), "")
    if base:
        add(
            "BASE/ (site root) returns 404",
            status(f"{base}/") == 404,
            status(f"{base}/"),
        )
        add(
            "BASE/<slug>/ returns 200",
            status(f"{base}/{slug}/") == 200,
            status(f"{base}/{slug}/"),
        )
        origin = re.match(r"https://[^/]+", base).group(0)
        add(
            "URL/<slug>/ without secret returns 404",
            status(f"{origin}/{slug}/") == 404,
            status(f"{origin}/{slug}/"),
        )
    print(json.dumps({"expectations": out}, ensure_ascii=False))


if __name__ == "__main__":
    main()
