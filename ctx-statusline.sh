#!/usr/bin/env bash
# Status line for Claude Code. Two jobs, in this order:
#   1. record context usage for this session into ctxmgr/ledger/<session_id>.json
#   2. print the status line
# Recording never blocks the display: every step is guarded.
#
# Optimized for MSYS/Git-Bash process-spawn overhead (each external process
# costs real time on Windows): in steady state exactly one external process
# (jq) is spawned. Everything else - reading stdin, timestamps, throttle
# check, basename - uses bash builtins only.
#
# Portable: resolves the home dir from HOME, then USERPROFILE (always present in
# the Windows env that Claude Code spawns bash with), so it works on any machine
# without editing. Set CTX_DIR to override the ledger location.

_home="${HOME:-$USERPROFILE}"
_home="${_home//\\//}"
CTXMGR_DIR="${CTX_DIR:-$_home/.claude/ctxmgr}"
LEDGER="$CTXMGR_DIR/ledger"
# Create the ledger dir once (builtin test guards the external mkdir).
[ -d "$LEDGER" ] || mkdir -p "$LEDGER" 2>/dev/null

IFS= read -r -d '' input

now=${EPOCHSECONDS:-$(printf '%(%s)T' -1)}

# --- single jq call: line 1 = ledger JSON, line 2 = tab-separated display fields
raw=$(printf '%s' "$input" | jq -r --arg now "$now" '
  [
    ({
      sessionId:      .session_id,
      transcriptPath: .transcript_path,
      cwd:            .cwd,
      sessionName:    (.session_name // null),
      model:          (.model.display_name // null),
      usedPct:        (.context_window.used_percentage // null),
      totalInput:     (.context_window.total_input_tokens // null),
      windowSize:     (.context_window.context_window_size // null),
      recordedAt:     ($now | tonumber)
    } | tojson),
    ([
      (.session_id // ""),
      (.workspace.current_dir // .cwd // "unknown"),
      (.model.display_name // "unknown"),
      ((.context_window.used_percentage // "") | tostring)
    ] | @tsv)
  ] | .[]
' 2>/dev/null)

ledger_json="${raw%%$'\n'*}"
display_line="${raw#*$'\n'}"
IFS=$'\t' read -r sid cwd model used <<< "$display_line"

# --- 1. record (best-effort, never blocks display) -------------------------
{
  if [ -n "$sid" ]; then
    row="$LEDGER/$sid.json"
    last=0
    if [ -f "$row" ]; then
      existing=$(<"$row")
      last=${existing##*\"recordedAt\":}
      last=${last%%[,\}]*}
      last=${last//[!0-9]/}
      [ -z "$last" ] && last=0
    fi
    if (( now - last >= 3 )); then
      printf '%s' "$ledger_json" > "$row" 2>/dev/null
    fi
  fi
} 2>/dev/null

# --- 2. display --------------------------------------------------------------
[ -z "$cwd" ] && cwd="unknown"
[ -z "$model" ] && model="unknown"
dir="${cwd//\\//}"
dir="${dir##*/}"

if [ -n "$used" ]; then
    used_int=${used%.*}
    if   [ "$used_int" -ge 90 ] 2>/dev/null; then ctx_display="ctx: ${used}% used [!!!]"
    elif [ "$used_int" -ge 75 ] 2>/dev/null; then ctx_display="ctx: ${used}% used [!!]"
    elif [ "$used_int" -ge 50 ] 2>/dev/null; then ctx_display="ctx: ${used}% used [!]"
    else                                          ctx_display="ctx: ${used}% used"
    fi
    printf "%s | %s | %s" "$dir" "$model" "$ctx_display"
else
    printf "%s | %s | ctx: --" "$dir" "$model"
fi
