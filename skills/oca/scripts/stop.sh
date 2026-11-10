#!/usr/bin/env bash
source "$(dirname "$0")/root.sh"
STATE="$OCA_ROOT/.state"
for p in tunnel server; do [[ -f "$STATE/$p.pid" ]] && kill "$(cat "$STATE/$p.pid")" 2>/dev/null; rm -f "$STATE/$p.pid"; done
rm -f "$STATE/url" "$STATE/port" "$STATE/dir" "$STATE/base" "$STATE/metrics"; echo stopped
