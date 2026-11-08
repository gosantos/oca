# opencode-artifacts

An agent skill that turns answers into clean, minimalist HTML pages (reports, dashboards, charts, comparisons, timelines, long-form text) and shares them through a private HTTPS link served from your own machine via a Cloudflare quick tunnel.

```bash
npx skills add gosantos/opencode-artifacts
```

Works with OpenCode, Claude Code, Codex, Cursor and any agent that supports [Agent Skills](https://agentskills.io).

## What you get

Ask your agent for something like *"make me a dashboard of these numbers and send me a link"* and it will:

1. Write a single HTML page: white background, black text, Tailwind utilities, Chart.js for charts.
2. Start a tiny static server bound to `127.0.0.1` on a random high port, using a runtime you already have.
3. Open a Cloudflare quick tunnel and give you `https://<random>.trycloudflare.com/<secret>/<page>/`.

Five reference layouts ship with the skill: long-form text, data report, market dashboard, comparison and incident brief.

## Requirements

Only [`cloudflared`](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/):

```bash
brew install cloudflared                  # macOS
winget install Cloudflare.cloudflared     # Windows
# Linux: your distro package or the .deb/.rpm from Cloudflare
```

No Cloudflare account needed. Nothing else gets installed. The server uses the first runtime it finds:

| Runtime | Typically present on |
|---|---|
| `node` / `deno` | dev machines |
| `python3` / `python` | most Linux, macOS with Xcode tools |
| `perl` | macOS, Debian/Ubuntu, Git for Windows |
| `busybox httpd` | Alpine and minimal containers |
| PowerShell `HttpListener` | every Windows (`publish.ps1`) |

## Security model

- The server listens on **127.0.0.1 only**, so nothing is exposed on your LAN.
- The tunnel is **outbound-only**: no inbound ports on your machine or router.
- Every link carries a **256-bit secret path** from the OS CSPRNG (`openssl rand`, `/dev/urandom`, or .NET `RandomNumberGenerator`). Without it, every request is a 404.
- The static server is GET/HEAD only, with no directory listing; dotfiles and `..` are blocked, and it sends `nosniff`, `no-referrer` and `noindex` headers.
- The ports are random (30000–59999), so they never collide with your dev servers.

The link is the credential, so anyone you send it to can open it. It dies when you run `stop` or the machine sleeps or reboots. For a stable URL behind SSO, use a named tunnel with Cloudflare Access instead.

## Manual use

```bash
cp report.html "${TMPDIR:-/tmp}/opencode-artifacts/site/report/index.html"
bash skills/opencode-artifacts/scripts/publish.sh   # prints BASE=...
open "$BASE/report/"
bash skills/opencode-artifacts/scripts/stop.sh
```

## Layout

```
skills/opencode-artifacts/
├── SKILL.md                 instructions for the agent
├── assets/base.html         page template
├── references/              layout guide + 5 example pages
└── scripts/                 publish/stop (bash + PowerShell), static servers (node/deno, python, perl, powershell)
```

## License

MIT
