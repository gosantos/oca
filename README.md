# oca

An agent skill that turns answers into clean, minimalist HTML pages (reports, dashboards, charts, comparisons, timelines, long-form text) and shares them through a private HTTPS link served from your own machine via a Cloudflare quick tunnel.

```bash
npx skills add gosantos/oca
```

Works with OpenCode, Claude Code, Codex, Cursor and any agent that supports [Agent Skills](https://agentskills.io).

## What you get

Ask your agent for something like *"make me a dashboard of these numbers and send me a link"* and it will:

1. Write a single HTML page: white background, black text, Tailwind utilities, Chart.js for charts.
2. Start a tiny static server bound to `127.0.0.1` on a random high port, using a runtime you already have.
3. Open a Cloudflare quick tunnel and give you `https://<random>.trycloudflare.com/<secret>/<6hex>-<page>/`.

Five reference layouts ship with the skill: long-form text, data report, market dashboard, comparison and incident brief.

## Requirements

Only [`cloudflared`](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/):

```bash
brew install cloudflared                  # macOS
winget install Cloudflare.cloudflared     # Windows
# Linux: your distro package or the .deb/.rpm from Cloudflare
```

No Cloudflare account needed. Nothing else gets installed. The server uses the first runtime it finds, in this order:

| Runtime | Typically present on |
|---|---|
| `perl` | macOS, Debian/Ubuntu, most Linux, Git for Windows |
| `node` / `deno` | dev machines |
| `busybox httpd` | Alpine and minimal containers |
| `python3` / `python` | last resort |
| PowerShell `HttpListener` | every Windows (`publish.ps1`) |

Perl goes first because it is preinstalled almost everywhere outside Windows and was the fastest in local benchmarks (keep-alive, gzip). Force a runtime with `OCA_RUNTIME=node`.

## Security model

- The server listens on **127.0.0.1 only**, so nothing is exposed on your LAN.
- The tunnel is **outbound-only**: no inbound ports on your machine or router.
- Every link carries a **256-bit secret path** from the OS CSPRNG (`openssl rand`, `/dev/urandom`, or .NET `RandomNumberGenerator`). Without it, every request is a 404. The server refuses to start with a missing or malformed secret.
- Every artifact folder starts with **6 random hex chars** (`3f9a1c-q3-report`), and the site root is never served, so there is no listing: someone holding the link to one page can't find the others.
- The static server is GET/HEAD only, with no directory listing; dotfiles and `..` are blocked, and it sends `nosniff`, `no-referrer`, `noindex` and anti-framing headers.
- Files live in a **private per-user folder** (your temp dir, `$XDG_RUNTIME_DIR`, or `/tmp/oca-<uid>`), mode 700. The scripts refuse a folder owned by someone else, so other users on a shared machine can't read or swap your pages.
- CDN scripts are **version-pinned**, and Chart.js carries a **Subresource Integrity** hash. Tailwind's Play CDN builds its script per request, so it is pinned but can't be hashed.
- The ports are random (30000–59999), so they never collide with your dev servers.

The link is the credential, so anyone you send it to can open it. It dies when you run `stop` or the machine sleeps or reboots. For a stable URL behind SSO, use a named tunnel with Cloudflare Access instead.

## Manual use

```bash
eval "$(bash skills/oca/scripts/slug.sh report)"   # sets SLUG and DIR
cp report.html "$DIR/index.html"
bash skills/oca/scripts/publish.sh   # prints BASE=...
open "$BASE/$SLUG/"
bash skills/oca/scripts/stop.sh
```

## Layout

```
skills/oca/
├── SKILL.md                 instructions for the agent
├── assets/base.html         page template
├── references/              layout guide + 5 example pages
└── scripts/                 publish/stop/slug (bash + PowerShell), static servers (perl, node/deno, python, powershell)
```

## License

MIT
