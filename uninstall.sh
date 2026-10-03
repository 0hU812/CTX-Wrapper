#!/usr/bin/env bash
# CTX-Wrapper uninstaller. Removes the statusLine key from ~/.claude/settings.json
# (backing up first) and leaves every other setting untouched.
# Run from Git Bash:   ./uninstall.sh

set -euo pipefail
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq not found."
SETTINGS="${HOME}/.claude/settings.json"
[ -f "$SETTINGS" ] || { printf 'Nothing to do: %s does not exist.\n' "$SETTINGS"; exit 0; }
jq empty "$SETTINGS" >/dev/null 2>&1 || die "$SETTINGS is not valid JSON."

cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
tmp="$(mktemp)"
jq 'del(.statusLine)' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"

printf 'Removed statusLine from %s (backup saved alongside).\n' "$SETTINGS"
printf 'Relaunch Claude Code to apply. The ctxmgr/ledger folder was left in place.\n'
