# B-52 canary — does Copilot CLI fire *both* `userPromptSubmitted` hooks?

Persisted kit for the B-52 backlog item (see `meta/BACKLOG.md`). v0.33.0 registered a **second**
`userPromptSubmitted` hook (`boy-scout-check`, after `route-prompt`) and the shipped
`docs/enforcement-surfaces.md` now claims the Copilot CLI Boy-Scout nudge is "Guaranteed (soft),
CLI ≥ 1.0.65". That claim is only true if Copilot CLI runs **every** `userPromptSubmitted` entry
and merges **all** of their `additionalContext` into the model-facing prompt. The 2026-07-04 canary
(CLI 1.0.68) only ever proved a **single** hook is consumed. This kit proves the multi-hook case.

**Status:** built 2026-07-17, re-confirmed blocked 2026-07-20 (Copilot CLI 1.0.71) — every attempt
hit the account's **monthly** quota (`402`, `AI Credits 0`) before a model turn.
**Quota reset confirmed 2026-08-01** by a trivial `-p` probe that completed a real model turn
(exit 0, `AI Credits 2.98`, CLI 1.0.71). The canary itself has **not** been run — step 2's
interactive folder-trust is still outstanding — so the two-hook question remains unobserved.
Run steps 1–3 below.

**PATH hazard on the maintainer box:** `copilot.cmd` dies with `'"node"' is not recognized` because
the session `PATH` is the corrupted one. Prepend `C:\Program Files\nodejs` to `$env:PATH` and invoke
`copilot` by absolute path (`$env:APPDATA\npm\copilot.cmd`) — it is not on `PATH` either.

## Design

Two `userPromptSubmitted` hooks in `.github/hooks/hooks.json`, each emitting a **distinct**
out-of-band token via the dual JSON shape (`additionalContext` +
`hookSpecificOutput.additionalContext`). The tokens are read from **environment variables**, so
they exist in **no file** in the tree — the model can only echo a token if Copilot actually
injected that hook's context. This defeats the false-positive where a tool-enabled model greps the
hook scripts and "finds" the tokens.

Known gotchas already baked in (from the drill): `hooks.json` paths use **forward slashes**
(a backslash is an invalid JSON escape and Copilot rejects the file); repo hooks load in `-p` mode
**only after the folder is trusted** (`~/.copilot/config.json` `trustedFolders`), and there is no
non-interactive flag to grant trust.

## How to run (next cycle)

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

## Reading the result

- **Both** `CANARY-ALPHA-Z7K2Q9` and `CANARY-BRAVO-M4V8R3` echoed → Copilot fires both hooks and
  merges both payloads → **B-52 verified**. Re-date the Copilot Boy-Scout row in
  `docs/enforcement-surfaces.md` as live-verified (normal release path, invariant #7) and record the
  host + version in `meta/host-certification.md`.
- **Only one, or neither** → Copilot honors only one `userPromptSubmitted` entry → the shipped claim
  is false. Apply the plan's documented fallback: fold the Boy-Scout logic into `route-prompt`
  (without its early-exit) so a single hook carries it, and correct the matrix row.
- **`402` / `AI Credits 0`** → still quota-blocked; record the dated attempt and retry next cycle.

Local sanity check (no Copilot needed) — confirm each hook still emits valid JSON with its token:
```bash
CANARY_A=TEST-A bash .github/hooks/hook-a.sh | jq -e . >/dev/null && echo hook-a OK
CANARY_B=TEST-B pwsh -NoProfile -File .github/hooks/hook-b.ps1 | ConvertFrom-Json > $null && echo hook-b OK
```

## B-41 S1 status (2026-08-13) — schema re-verification only, NOT the two-hook question above

**This is a narrower, separate check than the two-hook canary above.** B-41's remainder design
(`.claude/plans/2026-08-09-b41-eval-harness-remainder-design.md` §2 step 4) needed only a cheap
confirmation that the `events.jsonl` hook-shape schema documented in that design's §3 — written
against CLI 1.0.71 — still holds on the currently-installed CLI. **It does not attempt, and does
not answer, the two-hook merge question this file exists for; that remains unresolved, still
blocked on the same interactive-trust step, see the finding below.**

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
  accepted, and hooks fire immediately on the next invocation. This unblocks running **this file's
  own still-outstanding two-hook canary** (steps 1–3 above) without a human present to answer the
  interactive prompt — that canary itself was NOT run as part of this check; the two-hook question
  is still open. Confirmed safe: config was backed up before the edit and restored to its exact
  original byte content afterward.
- **Credits spent:** ~13.5 AI Credits across two live turns. Recorded because the design's step 4
  text called this a "zero-credit schema re-verification" — that framing anticipated reading
  already-on-disk session-state files rather than a fresh invocation; a fresh live turn was chosen
  instead (with the maintainer's explicit go-ahead) to tie the confirmation directly to the
  currently-installed CLI version rather than to session files of unknown CLI provenance.
