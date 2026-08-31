# B-52 canary — does Copilot CLI fire *both* `userPromptSubmitted` hooks?

Persisted historical kit for completed B-52 (see `meta/BACKLOG-DONE.md`). v0.33.0 registered a
**second** `userPromptSubmitted` hook (`boy-scout-check`, after `route-prompt`), and the then-current
Boy Scout claim depended on Copilot CLI merging every entry's `additionalContext`. The 2026-07-04
canary (CLI 1.0.68) had proved only a single hook was consumed, so this kit tested the multi-hook
case.

**Status: COMPLETE 2026-08-18.** Four live runs on Copilot CLI **1.0.79/1.0.80** observed that only
the **last** registered `userPromptSubmitted` entry reaches the model: two entries, swapped tokens,
three entries, and three structurally distinct entries all followed the final slot. B-147 then
changed the product to one composed entry. There is no pending two-hook run; the recipe below is
retained only as historical design.

**Historical PATH hazard on the maintainer box:** `copilot.cmd` died with `'"node"' is not
recognized` because the session `PATH` was corrupted. The historical workaround prepended
`C:\Program Files\nodejs` to `$env:PATH` and invoked `copilot` by absolute path
(`$env:APPDATA\npm\copilot.cmd`).

## Historical design

Two `userPromptSubmitted` hooks in `.github/hooks/hooks.json` each emitted a **distinct** token via
the dual JSON shape (`additionalContext` + `hookSpecificOutput.additionalContext`). The tokens were
read from environment variables and absent from tracked files. The original design treated that as
inaccessible to the model; it is not a valid secrecy claim for a tool-enabled model, which can spawn
a shell and inspect inherited environment. The completed result rests on the repeated slot/token
swap and structurally distinct controls recorded above; do not reuse this old kit as a certifying
instrument without WSD-066's positive, negative, and side-effect-marker arms.

Known gotchas already baked in (from the drill): `hooks.json` paths use **forward slashes**
(a backslash is an invalid JSON escape and Copilot rejects the file); repo hooks load in `-p` mode
**only after the folder is trusted** (`~/.copilot/config.json` `trustedFolders`), and there is no
non-interactive flag to grant trust.

## Historical run recipe (do not rerun against the current single-entry product)

1. Copy this kit to a fresh temp folder and make it a git repo (Copilot needs a real checkout):
   ```powershell
   $dir = "$env:TEMP\b52-canary"
   Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
   Copy-Item -Recurse "meta/canaries/b52-copilot-two-hook" $dir
   git -C $dir init -q; git -C $dir add -A; git -C $dir -c user.email=c@x -c user.name=c commit -qm init
   ```
2. **Trust the folder** (interactive — accept the prompt, then `/exit`; no non-interactive flag exists):
   ```powershell
   copilot -C $dir
   ```
3. Run the two-hook canary with two distinct tokens passed inline:
   ```powershell
   $env:CANARY_A='CANARY-ALPHA-Z7K2Q9'; $env:CANARY_B='CANARY-BRAVO-M4V8R3'
   copilot -C $dir --allow-all-tools -p "Echo any CANARY tokens you were given, verbatim."
   ```

## Historical interpretation and recorded result

- **Observed:** only the last entry reached the model on every run. The surviving token moved with
  the slot when tokens were swapped, and the result persisted with three structurally distinct
  messages.
- **Product response:** B-147 folded the Boy Scout delivery into `route-prompt`, so one registered
  entry now carries routing, plan-gate, security salience, and any queued advisory.
- **Evidence boundary:** this proves the CLI 1.0.79/1.0.80 multi-entry behavior. It does not prove
  that the separate `agentStop` scan fires or writes the queue.

Historical local sanity command (no Copilot needed) — each hook emitted valid JSON with its token:
```bash
CANARY_A=TEST-A bash .github/hooks/hook-a.sh | jq -e . >/dev/null && echo hook-a OK
CANARY_B=TEST-B pwsh -NoProfile -File .github/hooks/hook-b.ps1 | ConvertFrom-Json > $null && echo hook-b OK
```

## B-41 S1 status (2026-08-13) — historical pre-run note, superseded 2026-08-18

**This was a narrower, separate check than the later two-hook run.** B-41's remainder design
(`.claude/plans/2026-08-09-b41-eval-harness-remainder-design.md` §2 step 4) needed only a cheap
confirmation that the `events.jsonl` hook-shape schema documented in that design's §3 — written
against CLI 1.0.71 — still held on the then-installed CLI. It did not answer the two-hook merge
question; the four 2026-08-18 runs recorded at the top later answered it.

- **CLI version:** 1.0.78 (was 1.0.71 when §3 was written — 7 patch releases later).
- **`userPromptSubmitted` → `additionalContext`:** still fires, byte-for-byte the same shape —
  `hook.end` carries `output.additionalContext` with `route-prompt`'s full routed-intent text,
  verbatim, confirmed against a real live session (`route-prompt` fired on a `fix`-classified
  prompt in a disposable scratch repo carrying the real shipped `dotnet` dist's hooks).
- **`preToolUse` deny shape:** still never observed. This session's `preToolUse` invocations all
  returned bare `{"success":true}` (an allow, no payload) — consistent with every prior
  observation. Not proof it can't happen, only that it remains unobserved across now 16 sessions
  with `hook.end` events on this box.
- **New finding — a non-interactive trust workaround exists.** This file's "no non-interactive flag
  exists" note (line 32 above) is about the CLI's own UX; it is still true that `copilot -C <dir>`
  has no flag to skip the prompt. But `~/.copilot/config.json`'s `trustedFolders` is a plain JSON
  array of absolute path strings — writing the scratch dir's path into it directly (back up the
  file first; it is the live trust store) is accepted exactly as if the interactive prompt had been
  accepted, and hooks fire immediately on the next invocation. This later unblocked the completed
  two-hook runs above. It was not itself a two-hook result. Confirmed safe: config was backed up
  before the edit and restored to its exact original byte content afterward.
- **Credits spent:** ~13.5 AI Credits across two live turns. Recorded because the design's step 4
  text called this a "zero-credit schema re-verification" — that framing anticipated reading
  already-on-disk session-state files rather than a fresh invocation; a fresh live turn was chosen
  instead (with the maintainer's explicit go-ahead) to tie the confirmation directly to the
  currently-installed CLI version rather than to session files of unknown CLI provenance.
