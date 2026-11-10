# Sourced by publish.sh, slug.sh and stop.sh. Sets OCA_ROOT to a private, per-user folder.
# A shared /tmp lets another local user pre-create the folder and read or swap artifacts, so:
# prefer a per-user temp dir, make everything 700/600, and refuse a folder we don't own.
umask 077
if [[ -n ${TMPDIR:-} && ${TMPDIR%/} != /tmp && ${TMPDIR%/} != /var/tmp ]]; then OCA_ROOT="${TMPDIR%/}/oca"
elif [[ -n ${XDG_RUNTIME_DIR:-} && -d $XDG_RUNTIME_DIR ]]; then OCA_ROOT="$XDG_RUNTIME_DIR/oca"
else OCA_ROOT="/tmp/oca-$(id -u)"; fi
mkdir -p "$OCA_ROOT" 2>/dev/null || true
if [[ -L $OCA_ROOT || ! -d $OCA_ROOT || ! -O $OCA_ROOT ]]; then
  echo "ERROR: $OCA_ROOT is not a folder owned by you; refusing to use it" >&2; exit 6
fi
chmod 700 "$OCA_ROOT"
