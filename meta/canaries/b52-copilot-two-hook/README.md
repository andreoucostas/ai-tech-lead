# B-52 canary — does Copilot CLI fire *both* `userPromptSubmitted` hooks?

Persisted kit for the B-52 backlog item (see `meta/BACKLOG.md`). v0.33.0 registered a **second**
`userPromptSubmitted` hook (`boy-scout-check`, after `route-prompt`) and the shipped
`docs/enforcement-surfaces.md` now claims the Copilot CLI Boy-Scout nudge is "Guaranteed (soft),
CLI ≥ 1.0.65". That claim is only true if Copilot CLI runs **every** `userPromptSubmitted` entry
and merges **all** of their `additionalContext` into the model-facing prompt. The 2026-07-04 canary
(CLI 1.0.68) only ever proved a **single** hook is consumed. This kit proves the multi-hook case.

**Status:** built 2026-07-17, re-confirmed blocked 2026-07-20 (Copilot CLI 1.0.71) — every attempt
hit the account's **monthly** quota (`402`, `AI Credits 0`) before a model turn. Re-run once
monthly Copilot credits reset.

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
