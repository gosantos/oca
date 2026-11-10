#!/usr/bin/env bash
# Usage: slug.sh <name>   -> creates <site>/<6hex>-<name>/ and prints SLUG=<6hex>-<name> and DIR=<that folder>
# The 6 hex chars are openssl rand -hex 32 truncated to 6, so an artifact path can't be guessed from its name.
set -euo pipefail
[[ $# -eq 1 && -n ${1:-} ]] || { echo "usage: slug.sh <kebab-case-name>" >&2; exit 2; }
source "$(dirname "$0")/root.sh"; SITE="$OCA_ROOT/site"
out() { echo "SLUG=$1"; echo "DIR=$SITE/$1"; exit 0; }
# Strip accents first (ação -> acao) when perl is around; otherwise non-ASCII just becomes a separator.
NAME=$(printf '%s' "$1" | { perl -CS -MUnicode::Normalize -pe '$_ = NFD($_); s/\pM//g' 2>/dev/null || cat; } |
  LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')
[[ -n $NAME ]] || { echo "ERROR: name has no a-z0-9 characters" >&2; exit 2; }
mkdir -p "$SITE"
# Same name -> same folder, so adding a page never breaks a link already shared.
for d in "$SITE"/*-"$NAME"; do
  # Exact match only: "*-report" also matches "abc123-q3-report".
  [[ -d $d && $(basename "$d") =~ ^[0-9a-f]{6}-$NAME$ ]] && out "$(basename "$d")"
done
HEX=$(openssl rand -hex 32 2>/dev/null | cut -c1-6 || true)
[[ ${HEX:-} =~ ^[0-9a-f]{6}$ ]] || HEX=$(od -An -tx1 -N3 /dev/urandom | tr -d ' \n')
[[ $HEX =~ ^[0-9a-f]{6}$ ]] || { echo "ERROR: could not generate the random component" >&2; exit 5; }
mkdir -p "$SITE/$HEX-$NAME"
out "$HEX-$NAME"
