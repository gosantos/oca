---
name: oca
description: Turn any answer into a clean, minimalist HTML page (report, brief, dashboard, chart, comparison table, timeline, long-form text) and share it as a private public-HTTPS link served straight from the user's machine through a Cloudflare quick tunnel. Use this whenever the user says "oca" or asks for an "artifact", a page, a link, a shareable report or dashboard, wants to "show", "send" or "publish" a result, wants charts or a visual summary of data, or wants to expose a local HTML file, even if they don't say "artifact" or "Cloudflare".
---

# oca

Write a single HTML page, drop it in a local folder, and hand the user a link like
`https://<random>.trycloudflare.com/<256-bit-secret>/<6hex>-<name>/`. Nothing gets installed besides `cloudflared`; the server runs on whatever runtime the machine already has.

Paths below are relative to this skill's directory (the folder containing this file).

## 1. Write the page

Start from `assets/base.html`. Replace `{{LANG}}` and `{{DIR}}` (see Languages below), `{{TITLE}}`, `{{EYEBROW}}` (short mono label, e.g. "Report · Q3"), `{{SUBTITLE}}`, `{{DATE}}`, `{{WIDTH}}` (`max-w-3xl` for reading, `max-w-5xl` for dashboards) and put the body where `<!-- CONTENT -->` is.

Before writing, open the example in `references/examples/` closest to what you're building and reuse its patterns. `references/layouts.md` lists them and the building blocks they share.

The look is deliberately quiet: white page, near-black text, one column, thin rules. That's what makes these pages read as finished documents instead of templates, so hold the line on it:

- **Tailwind utility classes only** (Play CDN is in the template). Don't invent CSS classes; a `<style>` block is only for something Tailwind can't express. Keeping to utilities keeps every artifact consistent.
- **Logical sides.** Use `text-start`/`text-end`, `ps-`/`pe-`, `ms-`/`me-`, `border-s`/`border-e` instead of left/right, so the same markup works in right-to-left pages.
- **Monochrome.** `neutral-*` greys for everything. Color is reserved for data meaning: `emerald-600` up/good, `red-600` down/bad. Nothing else gets color.
- **No decoration.** No shadows, gradients, emoji, icons-for-the-sake-of-icons, or cards nested in cards. Hierarchy comes from size, weight, spacing and `border-neutral-200` rules.
- **Type.** Inter for text, JetBrains Mono for eyebrows, labels and numbers. Numbers get `tabular-nums` and are end-aligned (`text-end`) in tables.
- **Charts** use Chart.js (already loaded; the template sets muted defaults). Use `#171717` for the main series, `#a3a3a3`/`#d4d4d4` for the rest, `borderWidth: 1.5`, `pointRadius: 0`, no legend when there's one series, `x.grid.display: false`. Create charts inside `addEventListener('load', ...)` so Chart.js is ready.
- **Long text** goes in `<article class="prose prose-neutral max-w-none">`.
### Languages

Write the page in the language the user wrote to you in, including chart labels, table headers, eyebrows and dates. Set `{{LANG}}` and `{{DIR}}` from this table:

| Language | `lang` | `dir` | Extra font link (put it where the template's comment says) |
|---|---|---|---|
| English | `en` | `ltr` | none |
| Spanish | `es` | `ltr` | none |
| French | `fr` | `ltr` | none |
| German | `de` | `ltr` | none |
| Russian | `ru` | `ltr` | none (Inter covers Cyrillic) |
| Chinese (Simplified) | `zh-CN` | `ltr` | `Noto+Sans+SC:wght@400;500;700` |
| Japanese | `ja` | `ltr` | `Noto+Sans+JP:wght@400;500;700` |
| Hindi | `hi` | `ltr` | `Noto+Sans+Devanagari:wght@400;500;700` |
| Bengali | `bn` | `ltr` | `Noto+Sans+Bengali:wght@400;500;700` |
| Arabic | `ar` | `rtl` | `Noto+Sans+Arabic:wght@400;500;700` |

The font link is `<link href="https://fonts.googleapis.com/css2?family=<value>&display=swap" rel="stylesheet">`. Inter has no CJK, Indic or Arabic glyphs, so without it those pages fall back to whatever the phone has. For any other language, use its BCP 47 tag, `rtl` for Hebrew, Persian and Urdu, and the matching Noto Sans family if Inter lacks the script.

Script-specific rules:

- **Number formatting** follows the page locale: write numbers with `toLocaleString(document.documentElement.lang)` or pre-format them the same way (`1,234.5` in en, `1.234,5` in de/es, `1 234,5` in fr/ru, `12,34,567` lakh grouping in hi/bn). Chart.js picks the locale up from `<html lang>` automatically.
- **No `uppercase` or wide `tracking-widest`** on Chinese, Japanese, Hindi, Bengali or Arabic text: those scripts have no case, and letter-spacing breaks Arabic joining and Indic conjuncts. Drop those classes on eyebrows and section headings for these languages.
- **Right-to-left (Arabic):** `dir="rtl"` plus logical classes mirror the layout. Leave numbers, code and Latin brand names as they are; the browser isolates them. Keep chart x-axes in chronological order (oldest at the start of the reading direction) with `scales.x.reverse: true`.
- **CJK** prose reads better slightly larger and looser: add `leading-loose` to the `prose` article.

### Links must be relative

Every page lives under a secret prefix, so `href="/report/"` escapes it and 404s. Use `href="report/"` or `href="../"`.

## 2. Put it in the site folder

Get the slug from the script; don't make it up:

```bash
bash scripts/slug.sh <short-kebab-name>      # prints e.g. 3f9a1c-q3-report and creates the folder
powershell -ExecutionPolicy Bypass -File scripts\slug.ps1 <short-kebab-name>
```

Then write the page to:

```
${TMPDIR:-/tmp}/oca/site/<slug>/index.html     (Windows: %TEMP%\oca\site\...)
```

The 6 random hex chars in front of the name mean someone holding the link to one artifact can't guess the others. Calling `slug` again with the same name returns the same folder, so updating a page keeps its link. Don't create `site/index.html`: the server never serves the site root, and a listing would hand out every artifact to anyone with one link. Everything in that folder is reachable by whoever has the link, so put only artifact files there; never copy secrets, `.env` files or source trees in.

## 3. Publish

macOS / Linux / Git Bash / WSL:

```bash
bash scripts/publish.sh          # prints URL=, BASE=, PORT=, DIR=, RUNTIME=
bash scripts/stop.sh             # stops server and tunnel
```

Windows PowerShell (no Git Bash/WSL):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\publish.ps1
powershell -ExecutionPolicy Bypass -File scripts\stop.ps1
```

Give the user **`BASE/<slug>/`**. `publish` is idempotent: if the server and tunnel are already up it reprints the same `BASE`, so new pages appear under the existing link without a restart. Don't restart just to add a page, because a restart changes both the hostname and the secret and breaks links already shared. If `publish` prints `WARNING: previous tunnel ... expired`, Cloudflare dropped the old tunnel (usually after the machine slept); tell the user the old link is dead and give them the new one.

If `cloudflared` is missing, stop and tell the user to install it (`brew install cloudflared`, `winget install Cloudflare.cloudflared`, or their distro's package). It's the only dependency; don't install anything else.

Then check it worked (the tunnel can take a few seconds to resolve):

```bash
curl -s -o /dev/null -w "%{http_code}" BASE/<slug>/   # expect 200
curl -s -o /dev/null -w "%{http_code}" URL/<slug>/    # expect 404 (no secret)
```

## What the scripts do, and why

- **Runtime detection, no installs.** Tries `perl`, `node`, `deno`, `busybox httpd`, `python3`, `python` in that order; on Windows, PowerShell's built-in `HttpListener`. Perl comes first because it ships with macOS and nearly every Linux and was the fastest server in benchmarks; python is the last resort. Every common OS ships at least one. The macOS `/usr/bin/python3` stub is skipped when Xcode tools are missing, because calling it pops an install dialog. Force one with `OCA_RUNTIME=perl`.
- **127.0.0.1 only, random port 30000–59999.** Nothing listens on the LAN, and there are no clashes with dev servers on 3000/8080.
- **Outbound-only tunnel.** `cloudflared tunnel --url` opens no inbound ports on the machine or the router and needs no Cloudflare account.
- **256-bit secret path.** Generated with `openssl rand -hex 32`, falling back to `/dev/urandom` (on Windows, `RandomNumberGenerator`), both of which read from the OS CSPRNG. The server answers only under `/<secret>/`; every other path is 404, so the tunnel looks empty without the link.
- **Hardened static server.** GET/HEAD only, no directory listing, the site root is always 404, dotfiles and `..` traversal blocked, plus `nosniff`, `no-referrer` (so the secret doesn't leak to the CDNs the page loads), `noindex` and anti-framing headers. It refuses to start if the secret isn't 64 hex chars, unless `--public` was passed explicitly.
- **Fast.** HTTP/1.1 keep-alive, `Content-Length`, `TCP_NODELAY` and gzip for text files, so pages load quickly through the tunnel.
- State and logs live in `<tmp>/oca/.state/` (mode 700).

When it's relevant, tell the user: the link *is* the credential, so anyone they send it to can open it. It stops working when they run `stop` or the machine sleeps or reboots. A stable or SSO-protected URL needs a named Cloudflare tunnel plus Cloudflare Access, which this skill doesn't set up.
