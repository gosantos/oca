#!/usr/bin/env bash
STATE="${TMPDIR:-/tmp}/opencode-artifacts/.state"
for p in tunnel server; do [[ -f "$STATE/$p.pid" ]] && kill "$(cat "$STATE/$p.pid")" 2>/dev/null; rm -f "$STATE/$p.pid"; done
rm -f "$STATE/url" "$STATE/port" "$STATE/dir" "$STATE/base" "$STATE/metrics"; echo stopped
