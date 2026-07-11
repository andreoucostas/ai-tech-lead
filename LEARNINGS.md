# Meta-dev learnings (workspace level)

> Append-only. Lessons about developing the framework itself; per-repo learnings live in each
> repo's `LEARNINGS.md`. Format: `[YYYY-MM-DD] observation — what worked, what didn't, what changed.`

[2026-07-01] **A gate that skips the template repo protects nothing.** `docs-sync-check` early-exited
on `.template-repo`, so the framework's own repos had zero effective CI — and exactly the drift the
framework lectures consumers about shipped three releases running (CLAUDE.md stamp two versions
stale in both repos; AGENTS.md §1 paraphrased despite a "verbatim, hard drift finding" rule; the
`/generate-copilot` Part A artifact never generated at all). Instructions enforced only by a model
reading them are wishes; the fix was machine checks (`template-checks.*`, `template-ci.yml`,
`check-lockstep.ps1`) plus release automation (`release.ps1`) that refuses to ship on a red gate.
Rule changed: invariant #2/#7 now name the deterministic gate, and the manual release checklist is
retired.

[2026-07-01] **"Identical behavior" twin claims need a test, not intent.** `docs-sync-check.ps1`
counted lines with `Measure-Object -Line` (skips blanks) while its `.sh` twin used `wc -l` — the
same check could pass on one surface and fail on the other near the 80-line limit. Same class as
the historic guard.sh drift the 0.23.1 harness caught. Twin parity holds only where a test pins it.

[2026-07-01] **The meta layer must obey its own invariants or they decay.** `bom-fix` had no `.sh`
twin, `.claude/plans/` / `docs/workspace-decisions.md` / this file were conventions nobody had ever
instantiated, and the guard's fail-open path contradicted its own header. Self-application failures
were concentrated exactly where no gate looked.

[2026-07-04] **A sentinel canary settles "does the surface consume our hook output" that fixture
tests can't.** B-03 asked whether Copilot actually injects hook `additionalContext` into the model
(v0.25.0 shipped it fixture-tested but never live-verified). The decisive test: a hook emits
`{"additionalContext":"... begin/append the token ZEBRA-…"}` where the token appears in **no file**;
if it surfaces in the reply, that surface consumed the output. Result on **Copilot CLI 1.0.68**:
`userPromptSubmitted` **is** consumed (routing salience reaches the model), `postToolUse` is **not**
(so `post-write`/`audit-trail`'s Copilot leg is dead — corrected the false "consumes postToolUse"
comment in the twins). Trap that cost real time: repo-level `.github/hooks/hooks.json` hooks fire
**only after the workspace folder is trusted** (`~/.copilot/config.json` `trustedFolders`);
non-interactive `copilot -p` on an untrusted folder silently runs **none** of the four events and
there is no non-interactive trust flag — so any headless Copilot canary must trust the folder first
(interactive first-entry), else you measure nothing and misread it as "not consumed." Feeds
`framework-doctor` (B-16) and the enforcement-matrix rows (B-08).

[2026-07-04] **A file-mirror gate must EOL-normalize, or `core.autocrlf` makes it lie.** The B-07
skills-mirror gate first used a raw byte compare (`Get-FileHash` / `diff -rq`) and went red on
`.claude/skills` vs `.github/skills` though they are identical: `.gitattributes` pins only `*.sh`/`*.ps1`
to LF, so with `core.autocrlf=true` the two `*.md` copies can sit in the working tree with different
EOLs (one written LF out-of-band, one checked out CRLF) while byte-identical in the index and a clean
checkout. `git ls-files --eol` is the diagnostic (`w/lf` vs `w/crlf`). Fix: normalize before comparing
-- CRLF->LF in the `.ps1`, `diff --strip-trailing-cr` in the `.sh` -- the same reason `check-lockstep`'s
`Get-Normalized` strips CRLF+BOM. Any new content-equality gate over shipped files must do this, and
the two twins must normalize the SAME way or they diverge on an EOL-only diff. Corollary trap:
`git checkout -- <one-file>` re-runs the autocrlf smudge and can flip a single file's EOL, manufacturing
a working-tree-only mismatch; re-checkout the sibling too, or just normalize in the gate.

[2026-07-09] **Three Windows twin-authoring traps from the Phase-3 composer work** (each produced a
silent wrong result or a mid-script death, caught only by evidence gates — none by code review):
1. **pwsh 7.3 changed `-split`'s negative limit to "split from the RIGHT"** — `-split "`n", -1`
   returns 3 parts on PS 5.1 but **1 part** (the whole string) on pwsh ≥7.3. In `build.ps1` this made
   every snippet insertion vanish under pwsh while PS 5.1 output was byte-perfect. Use .NET
   `String.Split([char]10)` (edition-stable) in twins, and always verify under BOTH hosts — the
   byte-compare matrix (2 hosts × 2 stacks vs `build.sh` output) is what caught it.
2. **PS 5.1 + `$ErrorActionPreference='Stop'` + a native command writing to a REDIRECTED stderr =
   terminating `NativeCommandError`.** `bash -n broken.sh 2>$null` killed `validate-dist.ps1`
   mid-check exactly when a planted syntax error should have printed FAIL; clean runs never trip it.
   Gates that shell out must run under EAP=Continue with explicit `$LASTEXITCODE` checks — and every
   gate needs a planted-failure red test, or this class stays invisible.
3. **On a box with Git Bash, bare `tar.exe`/`bash` resolve to MSYS/WSL variants that break on
   `C:\` paths or missing distros.** MSYS tar parses `C:\...` as a remote host ("Cannot connect to
   C"); System32 `bash.exe` is a WSL stub that fails without a distro. Resolve explicitly
   (`$env:SystemRoot\System32\tar.exe`; `$env:ProgramFiles\Git\bin\bash.exe`) and probe the binary
   (`bash -c 'exit 0'`) before trusting it — FATAL loudly if absent, never skip the check silently.
Harness corollary: `cmd | head` (SIGPIPE → exit 141) and `... | Select-Object -First 1` (pipeline
stop before the child exits) both corrupt exit-code observations — capture exit codes without
truncating pipes when the exit code is the thing under test.

[2026-07-10] **"Additive-safe snippet" is a per-twin property — it does not transfer between a
.sh and its .ps1 twin.** The migration plan asserted route-prompt's security greps were additive-
safe ("two independent greps that each set sensitive=1"), and for `route-prompt.sh` that was true
(`if …; then sensitive="1"; fi` lines compose by concatenation). The `.ps1` twin expresses the
same logic as an *assignment* (`$sensitive = $lc -match '…'`), so concatenating both stacks' lines
makes the second assignment OVERWRITE the first — a .NET-only keyword like "ledger" would set it
true and the Angular line would reset it to false, silently disabling half the security overlay.
Caught only by the per-marker audit (all 116 markers classified CONCAT vs AUTHOR before composing);
fixed with an authored `(-match A) -or (-match B)` monorepo snippet and proven by keyword fixtures
on bash + pwsh 7 + PS 5.1. Rule: when a union/concat mechanism touches twin scripts, verify
additive-safety in EACH language's idiom, and fixture-test the composed hook on both surfaces.

[2026-07-10] **Subagent-authored files can carry tool-syntax leakage; sweep for it before
committing.** Three of eight docs authored by a delegated agent ended with stray `</content>` /
`</invoke>` lines (its file-write tool syntax leaking into the artifact). None of the composer,
validate-dist, or template-checks gates could catch this — it is valid markdown to every parser.
A one-line grep sweep (`grep -rn '</content>\|</invoke>' src/stacks/monorepo`) found all three.
Any batch of agent-authored artifacts gets that sweep before commit, and the final line of every
agent-authored file gets eyeballed (the leak is always at EOF).
