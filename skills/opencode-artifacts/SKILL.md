---
name: opencode-artifacts
description: Turn any answer into a clean, minimalist HTML page (report, brief, dashboard, chart, comparison table, timeline, long-form text) and share it as a private public-HTTPS link served straight from the user's machine through a Cloudflare quick tunnel. Use this whenever the user asks for an "artifact", a page, a link, a shareable report or dashboard, wants to "show", "send" or "publish" a result, wants charts or a visual summary of data, or wants to expose a local HTML file, even if they don't say "artifact" or "Cloudflare".
---

# opencode artifacts

Write a single HTML page, drop it in a local folder, and hand the user a link like
`https://<random>.trycloudflare.com/<256-bit-secret>/<slug>/`. Nothing gets installed besides `cloudflared`; the server runs on whatever runtime the machine already has.

Paths below are relative to this skill's directory (the folder containing this file).

## 1. Write the page

Start from `assets/base.html`. Replace `{{TITLE}}`, `{{EYEBROW}}` (short mono label, e.g. "Report · Q3"), `{{SUBTITLE}}`, `{{DATE}}`, `{{WIDTH}}` (`max-w-3xl` for reading, `max-w-5xl` for dashboards) and put the body where `<!-- CONTENT -->` is.

Before writing, open the example in `references/examples/` closest to what you're building and reuse its patterns. `references/layouts.md` lists them and the building blocks they share.

The look is deliberately quiet: white page, near-black text, one column, thin rules. That's what makes these pages read as finished documents instead of templates, so hold the line on it:

- **Tailwind utility classes only** (Play CDN is in the template). Don't invent CSS classes; a `<style>` block is only for something Tailwind can't express. Keeping to utilities keeps every artifact consistent.
- **Monochrome.** `neutral-*` greys for everything. Color is reserved for data meaning: `emerald-600` up/good, `red-600` down/bad. Nothing else gets color.
- **No decoration.** No shadows, gradients, emoji, icons-for-the-sake-of-icons, or cards nested in cards. Hierarchy comes from size, weight, spacing and `border-neutral-200` rules.
- **Type.** Inter for text, JetBrains Mono for eyebrows, labels and numbers. Numbers get `tabular-nums` and are right-aligned in tables.
- **Charts** use Chart.js (already loaded; the template sets muted defaults). Use `#171717` for the main series, `#a3a3a3`/`#d4d4d4` for the rest, `borderWidth: 1.5`, `pointRadius: 0`, no legend when there's one series, `x.grid.display: false`. Create charts inside `addEventListener('load', ...)` so Chart.js is ready.
- **Long text** goes in `<article class="prose prose-neutral max-w-none">`.
- Write in the user's language and set `<html lang>` to match (the template uses it for Chart.js number formatting). Format numbers in the page with that locale too, e.g. `toLocaleString('pt-BR')`.

### Links must be relative

Every page lives under a secret prefix, so `href="/report/"` escapes it and 404s. Use `href="report/"` or `href="../"`.

## 2. Put it in the site folder

```
${TMPDIR:-/tmp}/opencode-artifacts/site/<slug>/index.html     (Windows: %TEMP%\opencode-artifacts\site\...)
```

`<slug>` is short kebab-case. Also keep `site/index.html` as a plain list of every artifact (relative links) and update it when you add one. Everything in that folder is reachable by whoever has the link, so put only artifact files there; never copy secrets, `.env` files or source trees in.

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

Give the user **`BASE/<slug>/`**. `publish` is idempotent: if the server and tunnel are already up it reprints the same `BASE`, so new pages appear under the existing link without a restart. Don't restart just to add a page, because a restart changes both the hostname and the secret and breaks links already shared.

If `cloudflared` is missing, stop and tell the user to install it (`brew install cloudflared`, `winget install Cloudflare.cloudflared`, or their distro's package). It's the only dependency; don't install anything else.

Then check it worked (the tunnel can take a few seconds to resolve):

```bash
curl -s -o /dev/null -w "%{http_code}" BASE/<slug>/   # expect 200
curl -s -o /dev/null -w "%{http_code}" URL/<slug>/    # expect 404 (no secret)
```

## What the scripts do, and why

- **Runtime detection, no installs.** Tries `node`, `deno`, `python3`, `python`, `perl`, `busybox httpd` in that order; on Windows, PowerShell's built-in `HttpListener`. Every common OS ships at least one. The macOS `/usr/bin/python3` stub is skipped when Xcode tools are missing, because calling it pops an install dialog. Force one with `OA_RUNTIME=perl`.
- **127.0.0.1 only, random port 30000–59999.** Nothing listens on the LAN, and there are no clashes with dev servers on 3000/8080.
- **Outbound-only tunnel.** `cloudflared tunnel --url` opens no inbound ports on the machine or the router and needs no Cloudflare account.
- **256-bit secret path.** Generated with `openssl rand -hex 32`, falling back to `/dev/urandom` (on Windows, `RandomNumberGenerator`), both of which read from the OS CSPRNG. The server answers only under `/<secret>/`; every other path is 404, so the tunnel looks empty without the link.
- **Hardened static server.** GET/HEAD only, no directory listing, dotfiles and `..` traversal blocked, plus `nosniff`, `no-referrer` (so the secret doesn't leak to the CDNs the page loads) and `noindex` headers.
- State and logs live in `<tmp>/opencode-artifacts/.state/` (mode 700).

When it's relevant, tell the user: the link *is* the credential, so anyone they send it to can open it. It stops working when they run `stop` or the machine sleeps or reboots. A stable or SSO-protected URL needs a named Cloudflare tunnel plus Cloudflare Access, which this skill doesn't set up.
