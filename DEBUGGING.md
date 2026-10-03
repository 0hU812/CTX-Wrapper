# CTX-Wrapper — debugging log & troubleshooting

## TL;DR — the root cause

On the **native Windows build** of Claude Code (e.g. v2.1.283,
`C:\Users\<you>\.local\bin\claude.exe`), the `statusLine.command` string is
spawned **argv-style, without a shell**. If the command wraps paths in quotes:

```json
"command": "\"C:/.../bash.exe\" \"C:/.../script.sh\""   // BROKEN on native Windows
```

the surrounding quotes become **part of the filename**. Claude Code tries to
launch a program literally named `"C:/.../bash.exe"` (quotes included), fails
instantly with no error, and the status line silently never runs. Meanwhile the
rest of `settings.json` (model, theme) still applies, so it *looks* like the file
is being ignored only for the status line.

`cmd.exe`, PowerShell, and `bash` all strip those quotes for you, which is why
the exact same command **works in every manual test** but not inside Claude Code.

### The fix

Remove the quotes (safe when neither path contains a space):

```json
"command": "C:/.../bash.exe C:/.../script.sh"           // WORKS
```

---

## How we got there (the diagnostic path)

Symptom: status line blank, and nothing recorded to the ledger, even though the
script had worked weeks earlier.

Each step below either confirmed or eliminated a suspect. Reuse them if it breaks
again.

1. **Run the script by hand with a sample payload.**
   Piped a fake session JSON into the script via `bash`, `cmd.exe /c`, and
   `powershell -Command`. All three printed a correct status line and exited 0.
   → **Script, jq, and quoting were all fine.** Problem was outside the script.

2. **Check the ledger for freshness.**
   `~/.claude/ctxmgr/ledger/` had entries only from weeks ago — nothing for the
   live session. → Claude Code was **not invoking the command at all**.

3. **Confirm `jq` is on PATH** in both login and non-login Git-Bash
   (`bash -lc 'command -v jq'` / `bash -c 'command -v jq'`). It was.
   → Not a PATH problem.

4. **Check for competing/overriding settings files.**
   Looked at user `settings.json`, project `.claude/settings.json`,
   `settings.local.json`, `~/.claude.json`, `remote-settings.json`,
   `managed-settings.json`. Only the user file had a `statusLine`, it was valid
   JSON, no BOM, and parsed cleanly. → Config was correct and un-overridden.

5. **Prove settings.json is actually being read.**
   `model` and `theme` from it were in effect. → Claude Code reads the file but
   specifically never acts on the `statusLine` command.

6. **Add an unconditional probe to the script** (temporary):

   ```bash
   printf '%(%Y-%m-%dT%H:%M:%S)T invoked pid=%d\n' -1 "$$" >> "$CTXMGR_DIR/probe.log" 2>/dev/null
   ```

   Put it at the very top so it fires on *any* invocation, before jq. After a
   full relaunch the probe log stayed empty, while manual runs *did* append to
   it. → **Definitive proof Claude Code never spawns the command.**

7. **Check install health.** `claude doctor` → "No installation issues found"
   (a failed auto-update had not corrupted anything). → Not an install problem.

8. **Identify the mechanism.** Native Windows build spawns `statusLine` argv-style
   with no shell, so quoted paths are mis-tokenized. Removing the quotes fixed it;
   the probe fired and the ledger started recording on the next relaunch.

---

## Troubleshooting checklist (if it stops working again)

Work top to bottom:

- [ ] **Status line blank?** Confirm `settings.json` `command` has **no quotes**
      around the paths and uses **forward slashes**. This is the #1 cause.
- [ ] **Did you relaunch?** `statusLine` is read only at startup. Fully quit and
      reopen Claude Code — not `/clear`.
- [ ] **Run it manually** (substitute a real session id):
      ```powershell
      '{"session_id":"t","cwd":"C:/tmp","model":{"display_name":"X"},"context_window":{"used_percentage":42},"workspace":{"current_dir":"C:/tmp"}}' |
        & "C:/Users/<you>/AppData/Local/Programs/Git/usr/bin/bash.exe" "C:/.../ctx-statusline.sh"
      ```
      Expect: `tmp | X | ctx: 42% used`. If this fails, the problem is the script
      or jq, not Claude Code.
- [ ] **`jq` present?** `jq --version`. If missing: `winget install jqlang.jq`.
- [ ] **Paths have no spaces?** If a path *must* contain a space, you need a
      wrapper (e.g. a `.cmd` shim) because the native build can't quote reliably.
      Easiest fix: move the script to a space-free path.
- [ ] **Still dead?** Re-add the probe line from step 6, relaunch, and check
      `~/.claude/ctxmgr/probe.log`. Empty = Claude Code isn't spawning it (config
      / version issue); populated = the script runs but something inside fails.
- [ ] **Check ledger freshness:** a new
      `~/.claude/ctxmgr/ledger/<session-id>.json` should appear within seconds of
      launching a session.

---

## Notes

- A `.txt` vs `.sh` extension does **not** matter — `bash` runs the file either
  way. We use `.sh` here for clarity.
- Output is pure ASCII, so Windows codepage (cp1252 vs UTF-8) is not a concern.
- The native build also spawns **hook** commands the same way, so the "no quotes,
  forward slashes, space-free paths" rule applies to hooks too.
