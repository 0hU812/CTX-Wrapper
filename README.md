# CTX-Wrapper

A context-usage **status line for Claude Code** on Windows. It shows the current
directory, model, and context-window usage, and records per-session usage to a
ledger you can read later.

```
Claude-Repos | Opus 4.8 | ctx: 42.5% used [!]
```

Severity markers appear as context fills: `[!]` at 50%, `[!!]` at 75%, `[!!!]` at 90%.

> **Why this exists:** the native Windows build of Claude Code spawns the status
> line command *without a shell*, so quoted paths and paths containing spaces
> silently fail and the status line never appears. The installer here builds a
> correct, unquoted, space-free command automatically. Full story in
> [`DEBUGGING.md`](DEBUGGING.md).

---

## Requirements

- **Claude Code** on Windows.
- **Git for Windows** — provides `bash.exe` and `cygpath` (you already have these
  if you can run `git`).
- **`jq`** on your PATH — check with `jq --version`.
  Install if missing: `winget install jqlang.jq`

---

## Quick start

From **Git Bash**:

```bash
git clone https://github.com/<you>/CTX-Wrapper.git
cd CTX-Wrapper
./install.sh
```

Then **fully quit and relaunch Claude Code** (close the whole process — `/clear`
is not enough; `statusLine` is read only at startup).

That's it. The status line appears at the bottom, and a per-session file starts
showing up under `~/.claude/ctxmgr/ledger/`.

> 💡 Install the repo to a **space-free path** if you can (e.g. `C:/Tools/CTX-Wrapper`).
> The installer handles spaces via 8.3 short names, but a space-free path is
> bullet-proof.

### Uninstall

```bash
./uninstall.sh
```

Removes only the `statusLine` key from `settings.json` (backs it up first) and
leaves the rest alone. Relaunch Claude Code to apply.

---

## What the installer does

1. Confirms `jq` and `cygpath` (Git Bash) are available.
2. Resolves Windows-style, forward-slash, **space-free** paths for `bash.exe` and
   `ctx-statusline.sh` (using 8.3 short names so `C:/Program Files/Git` works).
3. Backs up `~/.claude/settings.json`, then merges in:
   ```json
   "statusLine": {
     "type": "command",
     "command": "C:/.../bash.exe C:/.../CTX-Wrapper/ctx-statusline.sh"
   }
   ```
   All your other settings (model, theme, plugins…) are preserved.

It never hard-codes a username — everything is detected on the machine it runs on.

---

## Manual install (no installer)

If you'd rather edit config by hand, add this to `C:\Users\<you>\.claude\settings.json`,
substituting your real paths:

```json
{
  "statusLine": {
    "type": "command",
    "command": "C:/Users/<you>/AppData/Local/Programs/Git/usr/bin/bash.exe C:/Users/<you>/CTX-Wrapper/ctx-statusline.sh"
  }
}
```

**Rules that make or break it on native Windows:**
- Forward slashes `/`, never backslashes.
- **No quotes** around the paths.
- **No spaces** in either path (if Git is under `C:/Program Files/Git`, use the
  installer — it substitutes the 8.3 short name `C:/PROGRA~1/Git/...`).

Relaunch Claude Code afterward.

---

## The ledger

Every few seconds (throttled to once per 3s, never blocking the display) the
script writes the current session's context usage to
`~/.claude/ctxmgr/ledger/<session-id>.json`:

```json
{"sessionId":"...","model":"Opus 4.8","usedPct":42.5,"totalInput":85000,"windowSize":200000,"recordedAt":1790437789}
```

Point the ledger elsewhere by setting `CTX_DIR` in the environment, or editing
the default at the top of `ctx-statusline.sh`.

---

## Publishing / sending to others

To put this on GitHub (first time):

```bash
cd CTX-Wrapper
git init
git add .
git commit -m "CTX-Wrapper: Claude Code context status line for Windows"
git branch -M main
git remote add origin https://github.com/<you>/CTX-Wrapper.git
git push -u origin main
```

Recipients just run the three **Quick start** commands above.

---

## Files

| File                 | Purpose                                             |
|----------------------|-----------------------------------------------------|
| `ctx-statusline.sh`  | The status-line script Claude Code runs each render.|
| `install.sh`         | Auto-detecting installer (merges into settings.json).|
| `uninstall.sh`       | Removes the statusLine key again.                   |
| `README.md`          | This file.                                          |
| `DEBUGGING.md`       | Root-cause writeup + troubleshooting checklist.     |
| `LICENSE`            | MIT.                                                |

---

## Troubleshooting

Status line blank after install + relaunch? The usual culprit is quotes or a
space in the command. Walk through the checklist in [`DEBUGGING.md`](DEBUGGING.md).
