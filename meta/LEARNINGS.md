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
twin, `.claude/plans/` / `meta/workspace-decisions.md` / this file were conventions nobody had ever
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

[2026-07-12] **A byte-for-byte fidelity guarantee copies the bugs too.** The v0.25.5 freeze proved
the merge changed nothing shipped — and it was telling the truth. What nobody asked was whether what
it was faithfully preserving was *correct*. It wasn't: the legacy `CHANGELOG.md` was a maintainer's
engineering log (backlog ids, `WSD-nnn`, "Fable-exit", "lockstep with the .NET twin", a literal
`_Maintainer-only (does not ship)_` note) and the freeze carried all 192 lines of it forward across
three dists. The merge got blamed for the bleed; the merge only made it *visible* by putting the meta
layer in the same tree. Rule changed: a fidelity gate answers "did this change?", never "should this
exist?" — when freezing content, run the correctness gates against the frozen baseline at least once,
or you have pinned the defect, not just the behavior.

[2026-07-12] **Measure the blast radius on the real install, not on the repo.** The instinct was to
report "192 lines shipped to consumers" — the number the gate prints. An `install.sh` smoke run into
a temp target said otherwise: only **22** of them land in a consumer's working tree (the ids in the
shipped hooks/scripts/tests, which *are* copied). The other ~170 are in `dist/*/CHANGELOG.md`, and
the installer has excluded `CHANGELOG.md`/`README.md` from the copy since v0.20.0 — so they are
product-*visible* but never installed. Both deserved fixing and the gate covers both, but they are
not the same severity, and this framework's own enforcement-honesty doctrine forbids inflating one
into the other. Rule: before you write a number into a CHANGELOG or an ADR, run the artifact the
consumer actually runs and count what actually arrives.

[2026-07-12] **A character class with a non-ASCII char in it is a byte trap — and it broke the
composer twins.** `sed -E 's/[[:space:]]*[-—]{1,2} B-19a\)/)/'` looks like "an ASCII hyphen or an
em-dash". `sed` matches **bytewise**, so `[-—]` is really "any of the bytes `-`, `E2`, `80`, `94`" —
it ate the em-dash's two continuation bytes and left the `E2` lead byte stranded. That single invalid
byte made `build.sh` and `build.ps1` **disagree by construction**: bash copies raw bytes through,
PowerShell decodes-and-re-encodes and turns the bad byte into `U+FFFD`. The committed dist matched
whichever composer wrote it, so the *other* CI leg failed a freshness diff two steps removed from the
cause. Rules changed: (1) never put a multi-byte character inside a `sed`/`grep` bracket expression —
match the literal string or use `perl -CSD`; (2) `git ls-files | xargs -I{} iconv -f UTF-8 -t UTF-8`
is now a repo gate (`WorkspaceBom.Tests.ps1`), because invalid UTF-8 is not a cosmetic issue here, it
is a *twin-divergence* issue. Note the irony worth remembering: I had already run a corruption check
and it passed — I grepped for `U+FFFD`, which is what the *PowerShell* composer produces downstream,
not the raw `E2` actually sitting in the source. **Check for the bug you can make, not the bug you can
picture.**

[2026-07-12] **Local-green + CI-red means a gate is missing locally, not that CI is fussy.** Every
local gate passed v0.26.1 — validate-dist ×3 on both legs, all four hook suites, the install smoke —
and CI still went red, because the only check that compares the *two composers against each other* is
CI's cross-leg rebuild. That asymmetry is the hole: any defect that makes the twins disagree is
invisible to a single-machine run. The fix isn't to run CI more; it's to pull the check down to where
the defect is made. Rule: when CI catches something local gates cannot, the deliverable is not just
the fix — it is the local gate that makes that class impossible to push again.

[2026-07-12] **We wrote the rule, quoted the rule, and still broke the rule.** Invariant #6 was the
don't-ship boundary. The entry four lines above this one already says "instructions enforced only by
a model reading them are wishes; the fix was machine checks." Both were sitting in the file the whole
time the framework shipped maintainer vocabulary to consumers. Knowing the lesson is not the same as
having applied it *here*: the fix wasn't a better-worded invariant, it was `validate-dist` check 6
reading `scripts/meta-denylist.txt`. Rule changed: when an invariant says "must never", ask in the
same breath **"which command fails if it does?"** — and if the answer is "none", the invariant is
decoration.

[2026-07-12] **Write the gate before the cleanup; a gate that has never seen the defect is unproven.**
`no-meta-leak` was built first and run against the dirty tree: red on 81/83/28 real lines with checks
1–5 still green, both twins agreeing. That ordering paid for itself immediately — it caught a twin
asymmetry *in the gate itself*. Check 5 invokes the dist's own `template-checks.ps1`, which
`Set-Location`s into the dist and never restores it, so my relative denylist path resolved against the
wrong root on the PowerShell leg, while the bash leg was fine because it runs `template-checks` in a
subshell. Had I cleaned first, the gate would have gone green on both legs for the wrong reason and
the asymmetry would have shipped. Resolve paths to absolute *before* any step that can move the cwd.

[2026-07-12] **Deny the ID, not the word — the allowlist size tells you if your gate will survive.**
The denylist targets `\bB-[0-9]{2}[a-z]?\b` and `\bWSD-[0-9]{3}\b`, and deliberately does *not* deny
the bare words `BACKLOG` or `twin`: the product legitimately reads the consumer's own `BACKLOG.md`
(`adopt.md`, the installers' adoption signals), and the shipped `.ps1`/`.sh` twins are a real feature
consumer docs must name. Result: the `ALLOW` list is **empty**. That is the signal to aim for — a gate
carrying a long allowlist is one people eventually switch off, and every entry is a hole. Also: two
sed traps. `perl -pe 's/…\s*$//'` eats the trailing newline (`\s` matches `\n`, `$` matches before it),
silently gluing bullets together; `sed` is safe because its pattern space excludes the newline. And
never anchor with `^` when editing a `.ps1` — the UTF-8 BOM [#4] sits at the start of line 1, so `^#`
does not match.

[2026-07-12] **A merge can preserve every artifact and still retire the entrypoint they were reached
through.** Asked whether the merge dropped the README's *For AI agents (LLMs)* section, the answer was
no: §1 is byte-identical in `dist/{dotnet,angular}`, was authored fresh for `dist/monorepo`, and
`git log -S` over the whole history returns **only additions**. Nothing was deleted, no ADR proposed
deleting it. But consumers reach this framework by pointing an agent at *a repo*, and the merge changed
which repo that is — from a template repo whose README opened with §1, to an authoring repo whose root
README was written fresh for maintainers. Every file survived; the **path to them** did not.
Migration checklists inventory artifacts. Nobody inventories entrypoints — so when the front door moves,
audit the *contracts the old door carried*, not just the files behind it.

[2026-07-12] **Baseline the failure, or you will fix the wrong file — this is the same lesson as
"a gate you have never seen fail is not a gate", applied to diagnosis.** The first plan for the above
was confident and wrong. It asserted the root README had "dropped" the install contract (commit the
files, hand off, don't hand-replicate `/adopt`) and proposed restoring it there. An adversarial pass
killed it on evidence: `src/core/scripts/install.{sh,ps1}` **already print** that contract at the moment
the agent acts, so three of the four "missing" items were never missing. The plan had diagnosed from a
README without reading the installer. Worse, its *primary* lever — rewriting the always-loaded root
`CLAUDE.md`/`AGENTS.md` banner on the theory that maintainer governance captures an installing agent and
its unqualified *"commit to `master` and push"* aims it at **this** repo — did not reproduce when finally
tested: a real agent (Opus 4.8, cwd = this repo, prompt *"install this framework into `<target>`"*) picked
the right installer, detected greenfield, refused to run `/bootstrap`, and never once mistook itself for a
maintainer. **The one thing it did get wrong was the thing nobody predicted:** it declined to *commit* the
copied files — step 1 of the contract. Which the greenfield installer branch, unlike brownfield, never
insisted on. The real defects were only visible from *running* things: a dead `install.ps1` path in
`dist/monorepo/README.md` §1 (that dist has only `scripts/install.ps1`), and greenfield/brownfield
asymmetry in the installer. Both were found by execution, neither by reading. **Prose review generates
hypotheses; only execution ranks them.** Two further notes for next time: (1) the harness will (rightly)
refuse to spawn a nested `claude -p --permission-mode bypassPermissions` — plan mode plus running the
installer directly gave the same signal without an unsandboxed autonomous agent; (2) one agent sample is
evidence, not proof — it was a single model on a single surface, and this framework ships dual-surface.
