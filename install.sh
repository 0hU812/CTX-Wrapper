#!/usr/bin/env bash
# CTX-Wrapper installer.
# Run from Git Bash:   ./install.sh
#
# What it does:
#   1. Verifies jq and cygpath (Git Bash) are available.
#   2. Resolves Windows-style, forward-slash, SPACE-FREE paths for bash.exe and
#      ctx-statusline.sh (using 8.3 short names so "C:/Program Files/Git" works).
#   3. Merges a correct, UNQUOTED statusLine command into ~/.claude/settings.json,
#      backing up the existing file first and preserving all other keys.
#
# The quoting/space handling is the whole point: the native Windows build of
# Claude Code spawns the statusLine command argv-style with NO shell, so quoted
# or space-containing paths silently fail. See DEBUGGING.md.

set -euo pipefail

say()  { printf '%s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SH="$SELF_DIR/ctx-statusline.sh"

say "CTX-Wrapper installer"
say "  repo: $SELF_DIR"

# --- 1. dependencies --------------------------------------------------------
command -v cygpath >/dev/null 2>&1 || die "cygpath not found. Run this from Git Bash (not WSL / PowerShell / cmd)."
command -v jq      >/dev/null 2>&1 || die $'jq not found. Install it, then re-run:\n  winget install jqlang.jq'
[ -f "$SCRIPT_SH" ] || die "ctx-statusline.sh not found next to this installer ($SCRIPT_SH)."

# --- 2. resolve space-free Windows paths ------------------------------------
BASH_UNIX="$(command -v bash)"
[ -f "${BASH_UNIX}.exe" ] && BASH_UNIX="${BASH_UNIX}.exe"   # /usr/bin/bash -> .../bash.exe

# Prefer the clean long path (stable). Fall back to 8.3 short names (cygpath -ms)
# ONLY when the long path contains a space, since the native build can't quote.
to_win() {
  local full; full="$(cygpath -m "$1")"            # long, forward slashes
  case "$full" in
    *" "*) cygpath -ms "$1" ;;                      # space -> 8.3 short, no spaces
    *)     printf '%s' "$full" ;;
  esac
}
BASH_WIN="$(to_win "$BASH_UNIX")"
SCRIPT_WIN="$(to_win "$SCRIPT_SH")"

# Belt and suspenders: if 8.3 names are disabled, a space may survive -> fail loudly.
case "$BASH_WIN"   in *" "*) die "bash.exe path still contains a space: $BASH_WIN"$'\n(8.3 short names appear disabled; move Git to a space-free path.)';; esac
case "$SCRIPT_WIN" in *" "*) die "script path still contains a space: $SCRIPT_WIN"$'\n(Move this repo to a space-free path, e.g. C:/Tools/CTX-Wrapper.)';; esac

COMMAND="$BASH_WIN $SCRIPT_WIN"
say "  bash:   $BASH_WIN"
say "  script: $SCRIPT_WIN"

# --- 3. merge into settings.json --------------------------------------------
CLAUDE_DIR="${HOME}/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
mkdir -p "$CLAUDE_DIR"

if [ -f "$SETTINGS" ]; then
  jq empty "$SETTINGS" >/dev/null 2>&1 || die "$SETTINGS is not valid JSON. Fix or remove it, then re-run."
  BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  say "  backup: $BACKUP"
else
  printf '{}\n' > "$SETTINGS"
  say "  created new $SETTINGS"
fi

tmp="$(mktemp)"
jq --arg cmd "$COMMAND" '.statusLine = {type:"command", command:$cmd}' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"

say ""
say "Installed. statusLine command written to settings.json:"
say "  $COMMAND"
say ""
say ">>> FULLY QUIT and relaunch Claude Code for the status line to load. <<<"
say "    (statusLine is read only at startup — /clear is not enough.)"
