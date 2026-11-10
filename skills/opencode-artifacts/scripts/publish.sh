#!/usr/bin/env bash
# Usage: publish.sh [--public] [dir]   (secret path prefix by default; --public disables)   -> serves dir (default $TMPDIR/opencode-artifacts/site) on 127.0.0.1:<random> + Cloudflare quick tunnel
set -euo pipefail
PUBLIC=0; [[ "${1:-}" == "--public" ]] && { PUBLIC=1; shift; }
T="${TMPDIR:-/tmp}"; T="${T%/}"
DIR="${1:-$T/opencode-artifacts/site}"; DIR="${DIR%/}"
STATE="$T/opencode-artifacts/.state"; mkdir -p "$DIR" "$STATE"; chmod 700 "$STATE"
HERE="$(cd "$(dirname "$0")" && pwd)"

# cloudflared's metrics server answers /ready with 200 only while the tunnel is registered with Cloudflare.
ready() { local r; { exec 3<>"/dev/tcp/127.0.0.1/$1"; } 2>/dev/null || return 1
  printf 'GET /ready HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n' >&3; read -r r <&3; exec 3<&-; [[ $r == *" 200"* ]]; }

# Already running? reuse. A live process isn't enough: after sleep Cloudflare drops quick tunnels while cloudflared keeps running.
if [[ -f "$STATE/url" ]] && kill -0 "$(cat "$STATE/server.pid")" 2>/dev/null && kill -0 "$(cat "$STATE/tunnel.pid")" 2>/dev/null; then
  if [[ -f "$STATE/metrics" ]] && ready "$(cat "$STATE/metrics")"; then
    echo "URL=$(cat "$STATE/url")"; echo "BASE=$(cat "$STATE/base")"; echo "PORT=$(cat "$STATE/port")"; echo "DIR=$(cat "$STATE/dir")"; exit 0
  fi
  echo "WARNING: previous tunnel $(cat "$STATE/url") expired; starting a new one. Links shared earlier no longer work." >&2
fi
"$HERE/stop.sh" >/dev/null 2>&1 || true

command -v cloudflared >/dev/null || { echo "ERROR: cloudflared not found (only hard dependency)"; exit 2; }

port_free() { ! (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
for _ in $(seq 1 50); do PORT=$(( (RANDOM<<15 | RANDOM) % 30000 + 30000 )); port_free "$PORT" && break; done
for _ in $(seq 1 50); do MPORT=$(( (RANDOM<<15 | RANDOM) % 30000 + 30000 )); [[ $MPORT != "$PORT" ]] && port_free "$MPORT" && break; done

# 256 bits from the OS CSPRNG as hex: path prefix that must be known to reach anything (everything else is 404).
SECRET=""
if [[ $PUBLIC == 0 ]]; then
  SECRET=$(openssl rand -hex 32 2>/dev/null || od -An -tx1 -N32 /dev/urandom | tr -d ' \n')
  [[ $SECRET =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: could not generate secret"; exit 5; }
fi

# Use a runtime that already works on this machine; never install anything. Server binds 127.0.0.1 only.
# On macOS /usr/bin/python3 is a stub that prompts to install Xcode tools, so skip it unless they're present.
works() {
  local p; p=$(command -v "$1") || return 1
  [[ $(uname) == Darwin && $p == /usr/bin/python3 ]] && ! xcode-select -p >/dev/null 2>&1 && return 1
  "$p" "${@:2}" >/dev/null 2>&1
}
pick() {
  case $1 in
    node)    works node -e 0          && CMD=(node "$HERE/server.mjs" "$DIR" "$PORT") ;;
    deno)    works deno --version     && CMD=(deno run --allow-net=127.0.0.1 --allow-read="$DIR" --allow-env=ARTIFACTS_SECRET "$HERE/server.mjs" "$DIR" "$PORT") ;;
    python3) works python3 -c 0       && CMD=(python3 -I "$HERE/server.py" "$DIR" "$PORT") ;;
    python)  works python -c 'import http.server' && CMD=(python -I "$HERE/server.py" "$DIR" "$PORT") ;;
    perl)    works perl -MIO::Socket::INET -MCwd -e 0 && CMD=(perl "$HERE/server.pl" "$DIR" "$PORT") ;;
    busybox) command -v busybox >/dev/null && busybox --list 2>/dev/null | grep -qx httpd || return 1
             # busybox can't check a prefix, so its docroot holds only a symlink named after the secret.
             WWW="$STATE/www"; rm -rf "$WWW"; mkdir -p "$WWW"; chmod 700 "$WWW"
             if [[ -n $SECRET ]]; then ln -s "$DIR" "$WWW/$SECRET"; else rmdir "$WWW"; ln -s "$DIR" "$WWW"; fi
             CMD=(busybox httpd -f -p "127.0.0.1:$PORT" -h "$WWW") ;;
    *) return 1 ;;
  esac
}
CMD=()
for r in ${OA_RUNTIME:-node deno python3 python perl busybox}; do pick "$r" && break; done
[[ ${#CMD[@]} -gt 0 ]] || { echo "ERROR: no usable runtime (node/deno/python/perl/busybox)"; exit 3; }

ARTIFACTS_SECRET="$SECRET" nohup "${CMD[@]}" >"$STATE/server.log" 2>&1 & echo $! >"$STATE/server.pid"
for _ in $(seq 1 30); do port_free "$PORT" || break; sleep 0.1; done

# Quick tunnel: outbound-only, no inbound ports opened, random trycloudflare.com hostname.
nohup cloudflared tunnel --no-autoupdate --metrics "127.0.0.1:$MPORT" --url "http://127.0.0.1:$PORT" >"$STATE/tunnel.log" 2>&1 & echo $! >"$STATE/tunnel.pid"
URL=""; for _ in $(seq 1 60); do URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$STATE/tunnel.log" | head -1 || true); [[ -n "$URL" ]] && break; sleep 0.5; done
[[ -z "$URL" ]] && { echo "ERROR: tunnel did not come up"; tail -20 "$STATE/tunnel.log"; exit 4; }
for _ in $(seq 1 40); do ready "$MPORT" && break; sleep 0.5; done

echo "$URL" >"$STATE/url"; (umask 077; echo "$URL${SECRET:+/$SECRET}" >"$STATE/base"); echo "$PORT" >"$STATE/port"; echo "$MPORT" >"$STATE/metrics"; echo "$DIR" >"$STATE/dir"
echo "URL=$URL"; echo "BASE=$(cat "$STATE/base")"; echo "PORT=$PORT"; echo "DIR=$DIR"; echo "RUNTIME=${CMD[0]}"
