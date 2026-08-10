# Meta-dev learnings (workspace level)

> Append-only. Lessons about developing the framework itself; per-repo learnings live in each
> repo's `LEARNINGS.md`. Format: `[YYYY-MM-DD] observation — what worked, what didn't, what changed.`

## 2026-07-17 — onboarding-review hardening: verify paths and host premises before implementation

An implementation-ready plan still carried two stale facts: `postToolUse` consumption had changed
in Copilot CLI 1.0.70, and `docs/ci-integration.md` was described as core although it is a
three-stack whole-file override. Resolve every named path and re-check host claims against the
newest live-fire evidence. A cwd fix must root git commands, file reads, and state writes together.

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

[2026-07-12] **A deprecation notice written for humans is not a deprecation notice for agents — and a
reassuring one is actively dangerous.** The archived repos' pointer READMEs carried a clear
human-voice banner ("⚠️ moved and archived, new home: …") and then, under *"the original README is
preserved below for reference"*, the **entire original README** — including §1 *"If you are an AI
agent reading this repository, **start here** … Copy the files in: `pwsh scripts/install.ps1
<target>`"*. Given the old URL and *"install this framework into our repo"*, an agent read the banner,
**discounted it, and installed the frozen v0.25.5 template** — quoting the banner's own reassurance as
its justification: *"reproduces this template byte-for-byte … moving is an update, not a behavior
change"*, therefore installing the old one is fine. Two transferable rules. **(1) Rank by voice, not by
position.** The banner was *first*; §1 was *imperative and second-person*. The model obeyed the text
addressed **to it** and treated everything else as context to weigh. A notice that must bind an agent
has to be written in the same voice as the thing it overrides — put the STOP *inside* the section the
agent was going to obey, not above it. **(2) Never reassure in a redirect.** "The new thing is
byte-for-byte identical" is meant to lower a human's migration anxiety; to an agent it reads as
*explicit permission to use either*. Say what breaks if they use the old one. Deprecations are a
**deny** with an alternative, not a preference with a rationale. Deleting the equivalence claim mattered
as much as adding the STOP — and it had also quietly stopped being true (v0.26+ added a whole
distribution). Verified red→green with the same prompt and model: `0.25.5` → `0.26.3`.

[2026-07-12] **Every gate we had was a parser gate. The product is prose, and nothing tested the
prose.** Markers resolve, JSON parses, `bash -n`, PS-AST, twins agree, `no-meta-leak` — all of it
proves the artifacts are *well-formed*, none of it proves they *work*. Three defects walked straight
through: a README command that pointed at a file which does not exist, an installer branch that
under-instructed agents, and four docs teaching a marker syntax the composer has never implemented.
Green gates were mistaken for coverage. The tell was there all along and we never looked at it: ask
of any gate, *what class of defect does this catch?* — and if the honest answer is "typos and syntax
errors," you have no coverage of the thing you actually ship. Added `no-dead-instruction` (every
script a shipped doc tells you to RUN must exist), `InstallerContract` (run the installer for real ×
3 dists × 2 modes × 2 twins; assert its **stdout** carries the agent contract — behavior, not prose
in a source file, because only that catches a branch that stops printing it), and `DocTruth` (the
authoring docs describe the repo that exists).

Three things this taught, all of which cost something to learn:
**(1) Each new gate found a live defect on its first run.** `no-dead-instruction` found a *second*
instance of the same bug I'd hand-fixed hours earlier and believed was gone (`dist/monorepo`'s
update-mode section). `DocTruth` found a bad `template-checks` path that the adversarial review had
already flagged and I had still not fixed. **Hand-fixing finds the instance; a gate finds the class.**
If a bug is worth fixing by hand it is worth asking what would have caught it, immediately, before
the fix feels done.
**(2) The gate lied about itself first.** Both new test files ended `Write-TestSummary …` instead of
`exit (Write-TestSummary …)`, so the runner — which sums `$LASTEXITCODE` — saw 0 no matter what.
`DocTruth` printed *2 failed* while the suite printed *0 failures*. Caught only because the two
numbers were on screen together. A new gate's **first** red-test is not of the defect; it is of the
gate's own failure path. Watch it report a failure *through the runner*, not just print one.
**(3) Name the blind spot in the docs, or green will be read as done.** Whether the prose actually
*steers* a model is still untested — that needs a real agent driven end-to-end, i.e. standing
permission to spawn one non-interactively, which we chose not to take. The two defects that only
agent-driving found (an installing agent mistaking this repo for its target; the archived repos
sending agents to install v0.25.5) would still not be caught. That is written into `DEVELOPING.md`
next to the gates, because an undocumented blind spot behind a wall of green checkmarks is worse than
no gates at all.

[2026-07-12] **Documentation is advisory. Executable output is not. A dual-surface framework must
put its non-negotiables in the channel BOTH surfaces obey — and only a test on both can tell you
which channel that is.** The B-33 pointer-README STOP was verified twice on Claude, declared fixed,
and the backlog item closed. Then it was run on Copilot: given the archived repo's URL and *"install
this framework into our repo"*, Copilot cloned and ran `scripts/install.ps1` **directly, without ever
opening the README**, and installed the frozen v0.25.5 template. The STOP banner — the one I had
strengthened, red-team-reviewed, and proven — was simply never in its context. A fix verified on one
surface of a two-surface product is an **untested** fix, and I had already written "verified
red→green" in the changelog.

The controlled pair is the whole lesson. Same model, same prompt, two framework URLs:
`Copilot → archived URL` installed **0.25.5** and left the files **uncommitted**;
`Copilot → current URL` installed **0.26.4**, **committed**, and handed off correctly. So the
installer's *stdout* reaches Copilot perfectly (the v0.26.3 contract fix works on both surfaces — its
failure to commit in the archived run was just the old v0.25.5 weak banner, i.e. the D3 defect
reproducing on a second model), while the *README* reaches Copilot not at all. Two channels, one
obeyed, one ignored — and no amount of strengthening the prose in the ignored one would ever have
shown up as a failure.

Fix: a hard refuse-and-redirect at the top of all four frozen installer twins — print the STOP, exit
1, copy nothing — so an agent that never reads a word of prose still cannot install a stale
framework. Re-tested identically: Copilot now redirects and installs 0.26.4, committed. The Claude
path is provably unaffected (the guard commit touched only `scripts/install.*`; the README it keys
off is byte-identical to the version it passed against). **Rule for anything that must bind an
agent: put it where the machine runs, not where the human reads.** Prose is a request; a non-zero
exit is a decision. `no-dead-instruction` and `InstallerContract` exist because of the same
insight — assert on what the artifact *does*, not on what it *says*.

## 2026-07-16 — v0.27.1 (B-37): post-ship review of a lower-tier implementation, and two release-loop gotchas

v0.27.0 (B-27) shipped by a less-capable implementer was reviewed post-ship against the locked
spec: six findings (see B-37 in BACKLOG.md — macOS `date -d`, stdin-hang, sort collation, D4/D9
omissions, .sh Copilot test gap, harness console-codepage capture). Two process learnings:

1. **"Gates green" is only as strong as the environment they ran in.** The v0.27.0 hook suites
   passed on the maintainer's UTF-8 console and failed 2 cases on any OEM code page (ibm850) —
   the harness decoded child stdout with `[Console]::OutputEncoding`. A release gate that can
   pass or fail depending on `chcp` is the same lie the v0.26.5 rendering fix killed, one layer
   up. The harness now pins UTF-8 around the capture; when verifying a "green" claim, re-run at
   least one suite under a deliberately hostile code page.

2. **release.ps1 is not re-runnable after a refused release without manual un-stamping.** The
   README version stamp treats "regex replaced nothing" as FATAL (reword protection), but a
   refused run has already stamped README to the new version — so the retry dies on its own
   leftovers. Until that's made idempotent, the retry recipe is: revert the README
   `Current shipped version` line to the previous version, fix the failing gate, re-run.
   (Cost two extra runs this release; the actual gate failure was `no-meta-leak` catching a
   tracking id an implementer agent wrote into a shipped test comment — the gate worked.)

## 2026-07-16 — v0.28.0 (B-21): reviewer-profile systemic fixes, and driving codex as the implementer

B-21 (D1 judgment checklist, D2 hazard-staleness session-start mechanism, D3 rendered legend)
shipped from the LOCKED WSD-013 spec, implemented by a codex (gpt-5.6-sol) implementer under
principal-engineer review this session. Three learnings:

1. **A pre-merge design's "single `src/core` edit per artifact" can be stale.** The B-21 spec
   (written 2026-07-06, pre-merge) said each of bootstrap.md/adopt.md/FRAMEWORK-CONTEXT.md would
   be one core edit in the merged repo. In fact all three are **stack whole-file overrides in all
   three stacks** — the change was a ×3 surface (invariant #1 sibling discipline), only the
   `session-start` twins were core. Verify artifact placement in the *current* tree before
   trusting a locked spec's implementation-notes; the design's *intent* held, its file-layout
   assumption did not.

2. **Codex `workspace-write` has no sandbox backend on Windows when spawned nested inside another
   agent's shell — it degrades to read-only.** Proven-working config from the B-32 session
   (`-m gpt-5.6-sol -s workspace-write -c approval_policy=never`, writable root = the repo) works
   when the maintainer runs codex directly in a terminal, but every write was rejected
   ("workspace is mounted read-only") when Claude Code spawned it via its Bash tool — with the
   outer Claude sandbox on *or* off, and with `--full-auto`. The only config that writes while
   nested is `--dangerously-bypass-approvals-and-sandbox` (codex sandbox off entirely), which is
   broader than workspace-write and needs explicit user authorization. If you must drive codex
   nested on Windows, plan for bypass-with-authorization or hand the command to the maintainer to
   run un-nested. (Codex also stopped mid-brief on the first bypass run's predecessor and needed a
   clean re-run; and it printed proposed diffs for files it had already applied — read `git status`
   for ground truth, not the codex transcript.)

3. **D2's twin date-handling is not byte-identical by construction and that is acceptable.** The
   `.sh` twin validates the `Reviewed` cell shape with a glob (`????-??-??`) then lexically
   compares ISO strings; the `.ps1` twin uses `ParseExact`. They diverge only on
   syntactically-ISO-but-invalid dates (e.g. `2026-13-45`), which 3d-bis never writes — the twin
   tests pin genuinely-unparseable values so the verdict is identical. Documented so a future
   twin-parity audit doesn't "fix" a non-bug.

## 2026-07-16 — B-22 (headless `/adopt`, Path A): the implementer-authorization boundary is real, and the composition surface matched B-21's

B-22 shipped from the LOCKED WSD-014 (Path A) spec: headless `/adopt` **prepares** adoption
autonomously (auto-branch, archive, provenance + adversarial screen, impact baseline) and **stages**
every `CLAUDE.md`/`TECH_DEBT.md` merge for a human to apply at PR review — the prompt-injection
boundary is held by stage-don't-apply + quarantine-exclusion + a restricted tool surface, not by
`disable-model-invocation` (which a prompt wrapper ignores anyway, so the boundary also holds on the
Copilot leg). Two learnings:

1. **A relayed "the user authorized bypass" does not clear the bypass gate for a nested codex.**
   The plan was to drive codex (gpt-5.6-sol) with `--dangerously-bypass-approvals-and-sandbox` as in
   B-21. The Claude permission classifier **denied** it: the authorization arrived inside a teammate
   message, and per its User Intent Rule an agent-relayed / cross-session claim never establishes
   user intent for a bypass flag — it needs a direct user message in the *executing* agent's own
   transcript. This is a stricter boundary than the B-21 learning (which was about codex's Windows
   sandbox degrading to read-only when nested). Consequence: when a subagent is told to run codex
   with bypass, either (a) the human authorizes the bypass in that subagent's transcript, or (b) the
   subagent implements directly. Here the reviewer implemented directly (same edits, same review +
   gate verification) and flagged the deviation — net-faster than a round-trip, and the
   principal-engineer review still happened.

2. **B-21's "spec's src-layout assumption is stale" learning generalized to B-22 — verify, don't
   trust.** The B-22 spec (pre-merge, 2026-07-06) said the artifacts were `src/core` edits. In the
   current tree `adopt.md` and `bootstrap.md` are **stack whole-file overrides in all three stacks**
   (×3 byte-identical inserts), and only `adopt.prompt.md` (a core file whose `description` diverges
   via a `<!-- @stack:desc -->` marker) and the two installer twins were core. Same failure mode
   B-21 hit; confirming artifact placement in the live tree before briefing is now the default.

Verification (all green): compose ×3 + `git status dist/` self-consistent (only the 15 expected
files); `validate-dist` ×3 exit 0 (markers, template-checks/AGENTS mirror, no-meta-leak,
no-dead-instruction); meta suite 0 failures incl. `InstallerContract` 12/12 (the reworded brownfield
handoff still prints the whole agent contract in both modes × both twins × 3 dists) and generated
consumer marker JSON valid on both twins; dotnet dist hook suite 0 failures. The prose-steers-a-model
surface remains the known blind spot (no gate drives an agent through the staged-merge path).

## 2026-07-17 — B-16: diagnostics must survive the dependency they diagnose

The framework doctor cannot depend on healthy agent hooks, PowerShell 7, or a JSON parser: those
are precisely the failures it exists to expose. Its PowerShell twin stays 5.1-compatible, its bash
twin has a conservative parser-free fallback for the generated settings shape, and agent-only
facts remain explicit human canaries. The first fixture run also caught a path-normalization trap:
PowerShell `TrimStart('./')` treats its argument as a character set and changed `.claude` to
`claude`; prefix removal must be explicit when a leading dot is meaningful.

## 2026-07-17 — v0.32.1 (B-16 post-release): the linux CI leg is part of "green", and a diagnostic must not depend on what it diagnoses

v0.32.0 shipped with local gates green and CI's linux leg red — three FrameworkDoctor failures.
Two lessons, one of them a repeat offender:

1. **"Gates green" on one OS is the B-37 environment-dependent-green lie in a new coat.** The
   fixtures wired `powershell` as the hook shell — absent on the linux runner, so the doctor
   *correctly* reported it missing and the "healthy" fixture exited 1. The reviewer (Fable)
   re-ran every gate independently but on the same OS as the implementer, so the review
   inherited the blind spot. Local verification of anything with a linux CI leg must either
   run that leg's environment or explicitly name it unverified.

2. **The doctor's own root resolution used `dirname` — an external tool — inside the script
   whose design constraint is "must run where PATH is broken" (WSD-023 F1/F2).** Under the
   restricted-PATH test on real linux it failed, and the failure mode was maximally dishonest:
   `[MISSING] Install state — not a framework install` with every real row silently gone. MSYS
   bash on Windows masked it. Root resolution is now shell builtins only, and the no-parser
   test pins install-state resolution so this class can't return quietly. Corollary: a
   survival constraint applies to every line of the script, including the first one.

## 2026-07-17 — B-41: a spend cap is not a time cap, and evidence needs three outcomes

The first live agent harness attempt entered the CLI's exponential API-retry path. A maximum-dollar
flag limited spend but did not limit elapsed time; killing the shell wrapper also left inherited
output-pipe handles capable of keeping an async reader open. Live evals therefore need both a
per-scenario budget and a wall-clock process-tree kill, and the timeout path must not await pipes
owned by killed descendants.

Behavior grading also needs `PASS`, `FAIL`, and `ERROR`/`INCONCLUSIVE` as distinct outcomes. A host
timeout, invalid stream schema, or model refusal is not evidence that framework behavior failed.
The B-41 log keeps those outcomes visible, while only observable tool order, repository state,
hook blocks, and file bytes can earn a pass.

## 2026-07-30 — Hook capabilities must be verified at the event-and-output-channel level

1. **Copilot now has a true per-turn event.** CLI v1.0.72 added `agentStop`, including
   `stop_hook_active` and an eight-consecutive-block cap, so its hook lifecycle has converged on
   Claude Code's. The assumption that Copilot had no turn-end event is stale; it had become
   embedded in several shipped documents.

2. **The hooks reference table can lag shipped CLI behavior.** The docs.github.com table still
   says `userPromptSubmitted` output is not processed months after CLI v1.0.65 shipped
   `additionalContext` injection. For capability claims, trust the CLI changelog plus a local
   out-of-band canary over the reference table alone.

3. **An event firing does not prove a usable delivery channel.** `postToolUse`
   `additionalContext` is captured but not reliably forwarded to the model, so it must not carry
   findings. It also cannot represent writes made through shell tools.

4. **Hook-header prose is executable documentation without a truth gate.** We long claimed that a
   Stop hook's `decision: "block"` `reason` is shown only to the user. In fact it reaches Claude as
   a system reminder; the user-facing field is the separate top-level `stopReason`. Tests exercise
   output shapes, not comments, so this factual error survived for a long time.

---

## 2026-07-31 — the framework broke its own rule, and no gate noticed

Shipping B-57 (v0.36.0 + v0.37.0) after a consumer reported the framework pushing xUnit at an NUnit repo.

1. **A rule that ships is not a rule that binds.** Verification Rule #10 "Derive, don't assume" names
   *test framework* explicitly, and `bootstrap.md` Phase 3a forbids naming unevidenced technology. Both
   have shipped for versions. Six other surfaces stated xUnit as fact the whole time, including
   `copilot-instructions.md`, which is read on every inline completion. Writing the principle down in
   one file does nothing for the files that contradict it — the same lesson as invariant #6, which was
   written down from the start and still shipped ~190 leaking lines. When a new principle lands, sweep
   for the surfaces that already assert the opposite; that sweep is the actual work, not the principle.

2. **The self-contradicting string is the tell.** `add-tests` read "following project patterns
   **(xUnit + `WebApplicationFactory`)**" — it argues with itself in a single line. That phrasing is a
   reliable smell for an unevidenced default: the sentence knows the right rule and the parenthetical
   overrides it. Worth grepping for.

3. **Gates cover what someone thought to gate, and their absence is invisible.** `template-checks`
   mirrors four named sections; the `## Common Tasks` skills list is not one of them, and it had already
   drifted in all three dists — Angular's pair named a *different technology* on each side — with every
   gate green. The plan initially claimed the gate covered this. It did not. **Read the gate before
   citing it.** (B-58. Note the obvious fix is also wrong: `AGENTS.md`'s Common Tasks is deliberately
   condensed, so a verbatim diff goes red everywhere.)

4. **A `&&`-chained `grep` fails open.** The first-draft bash pattern used `[\](,]`, invalid POSIX ERE
   (`]` must come first in a bracket expression; `\` does not escape inside one). `grep` exits 2, and
   because the line is `grep -Eq … && reasons+=(…)`, the check silently does nothing — while the
   PowerShell twin blocks correctly. A twin divergence that looks like a working feature. Also: `\s` is
   a GNU extension (`guard.sh` uses `[[:space:]]` everywhere for exactly this reason), and PowerShell
   `-match` is case-*insensitive* by default while `grep -E` is not, so `-cmatch` is mandatory whenever
   the pattern contains a plain identifier like `Ignore`.

5. **Test the false positives, not the feature.** The guard's `.cs` branch is not scoped to test files.
   An unanchored `Ignore` pattern hard-blocks `public enum Mode { None, Ignore, All }` — ordinary
   production C#, unwritable through `Write`/`Edit`, with an error accusing the developer of skipping a
   test. Four of the seven new fixture cases are `block=$false` for this reason. The near-miss cases are
   the ones that earn their keep.

6. **Verify against the real input shape.** The 11-case regex check used single-line strings; the guard
   actually receives whole file contents. That gap was caught late and the patterns happened to be
   correct under `(?m)` and bash's line-orientation — but the check as designed would not have caught a
   multiline-only failure. Fixture content should look like the file, not like the pattern.

7. **Split the change that can regress from the change that cannot.** Guidance had no regression
   surface; the guard could hard-block valid code. Two releases (0.36.0, 0.37.0) rather than one kept
   consumer-blocking risk out of a prose release. Four of the five blocking review defects were in the
   part that got its own release.

8. **Detached HEAD, again.** `master` was held by an abandoned scratchpad worktree and sat two commits
   behind `origin/master`; `release.ps1` pushes the branch *by name*, so the release commit would have
   landed on the detached HEAD and the push been rejected — B-53's exact shape, a fourth time. Fixed
   non-destructively by detaching the worktree rather than removing it. Checking
   `git rev-parse --abbrev-ref HEAD` belongs in the release preflight, not in a postmortem.

---

## 2026-07-31 — a false `[OK]` is worse than a missing check

Every hook could fail to start with command-not-found and still leave the framework looking clean.
That is not an incidental presentation problem: silence is treated as a pass everywhere.
`convention-check` literally says “Silence is a pass”; `boy-scout-check` deduplicates on a hash, so
no output naturally reads as “nothing new”. A diagnostic that prints `[OK]` from the wrong process
vantage point turns that established meaning of silence into false assurance.

The two doctor twins disagreed on the same machine: PowerShell reported the hook interpreter
available while bash reported it missing. That disagreement was the only reason the dead hooks were
found. Running either twin alone — especially the one that printed `[OK]` — would have produced a
clean bill of health. Twin agreement is not merely a maintenance nicety; disagreement is evidence
that at least one probe is answering a different question.

---

## 2026-07-31 — the instrument agreed with the fix, so we nearly shipped on faith

B-66 was as well-evidenced as a backlog item gets: a real field report, plus a case-sensitive grep
returning zero hits for every forms token across `src/stacks/angular/`, `src/core/` and
`dist/angular/`. The plan was to ship forms guidance and prove it with the `angular-form-control`
probe. Three things went wrong in sequence, and the order matters.

1. **The grader was defeatable by the idiom the guidance was about to recommend.** `@Input() set
   disabled(v)` and `disabled = input.required<boolean>()` both scored PASS while being precisely
   the reported defect — the decorator pattern required the property name immediately after
   `@Input(...)`, and the signal pattern did not admit `.required`. The draft plan contained the
   sentence "cover both `@Input()` and Angular's signal `input()` form". Had the guidance been
   written first, the eval would have gone green and the release would have carried a behavioural
   claim produced entirely by the measurement artefact. **A probe you are about to satisfy is not a
   test; it is a mirror.** Harden the instrument before the change it will measure, never after.

2. **The baseline passed before the fix.** With no forms guidance shipped at all, the agent
   self-injected `NgControl`, assigned `valueAccessor = this`, used `setDisabledState` instead of an
   `@Input() disabled`, and commented that this avoids the circular-DI `forwardRef` that
   `NG_VALUE_ACCESSOR` would need — the hazard the guidance existed to teach. The prompt telegraphed
   the mechanism ("bind directly with `formControlName`", "show its own validation error when
   invalid and touched"), so a capable model satisfies it whether or not the repo says anything.
   A scenario written from a defect report will tend to *describe the fix*, because whoever writes
   it now knows the answer. State the business need; let the agent discover the mechanism.

3. **The grader cannot see the hazard the guidance teaches.** `cva` is `ControlValueAccessor OR
   NG_VALUE_ACCESSOR`, so the correct pattern and the double-registration circular-DI bug both score
   `cva=True ngcontrol=True`. The probe would have passed a component that fails at runtime.

**What we did with that.** Not "ship anyway, it's justified independently" — though it was — and not
"abandon B-66". The scope was cut to the half that stands without the probe: `/bootstrap` and
`/adopt` now capture a repo's forms conventions, and the surfaces asserting `@Input`/`@Output`
**only** were carved out. The prescriptive greenfield guidance and the CVA-vs-`NgControl` trade-off
table were dropped until a re-specified probe shows where the model actually fails. Evidence that
arrives against your expectation is worth more than evidence that confirms it, and the right
response to "my instrument says I was wrong about the urgency" is to ship the part that was never
in question.

**The generalisable rule, now filed as B-72(c):** a behavioural probe earns the name "red test" only
once it has been observed to **fail** on the unfixed tree, with that failing observation recorded
next to the scenario. Until then it is an unvalidated instrument, and a green result from it means
nothing. This is B-59's inert-check problem — a check that has stopped working is indistinguishable
from a check that legitimately did not match — moved from the deterministic layer to the
behavioural one.

---

## 2026-07-31 — the anomaly was the symptom; the P1 had been sitting open the whole time

A tag backfill found that v0.34.0 had no release commit. The obvious reading was a labelling slip:
its version stamp sits in a squashed PR merge whose subject says "(meta-only)", which contradicts a
version bump. The tempting fix is a gate that rejects a stamp bump in a commit labelled meta-only.

Reading the squashed body instead showed the real shape. The PR carried three commits and the third
was a full release — `release.ps1` run **on the PR branch**, gates green, stamps and all three
changelogs present. GitHub's squash then replaced that commit's subject with the PR title. Nothing
was mislabelled; a release was performed somewhere it could not survive.

And the mechanism was already written down. **B-53(a)** — "refuse to run when HEAD is detached or not
on the expected branch" — had been open as a **P1 through four occurrences**, all of them detached
HEAD. Nobody had noticed the entry also covers releasing from a feature branch, because every prior
instance wore the same costume. The anomaly was a fifth occurrence of a known P1 in unfamiliar dress.

Three things worth keeping:

1. **When something anomalous turns up, check the open P1s before inventing a new gate.** A
   meta-only-label gate would have been new machinery that fixed a symptom of a defect already
   diagnosed, and would have left the actual hole open.
2. **A recurring defect's *recorded* mechanism can be narrower than its real one.** B-53's evidence
   was four detached-HEAD cases, so "detached HEAD" became shorthand for the bug. The invariant is
   "HEAD is not master's tip"; detachment is one way to get there and a PR branch is another. When
   filing a recurrence, restate the invariant, not the costume.
3. **Reproduce the failure before fixing it, even when the entry already asserts it.** In a throwaway
   repo with a bare origin, on a detached HEAD, `git push origin master` printed
   **"Everything up-to-date"** and **exited 0** while origin stayed put. Seeing it is worth more than
   the four write-ups saying so — and it is what makes the postcondition obviously necessary rather
   than defensive.

## 2026-08-01 — B-61 (v0.41.0): what a twin-parity harness actually teaches you

1. **Building the test is how you find the bugs; expect the "test-only" change not to be one.**
   B-61 was scoped as adding coverage. Writing the fixtures immediately surfaced three divergences
   that were already shipping — two in `metrics.sh`/`docs-sync-check`, one in the harness itself. Plan
   a parity item as *fix + prove*, sequenced in that order, and put both in one release: shipping the
   harness first ships a red suite, shipping the fixes first ships them unproven.

2. **A parity fixture that doesn't trigger a branch makes both twins agree about nothing.** The first
   `template-checks` fixture reached 5 of 7 checks. A defect planted in check 5 did not go red and the
   suite still said 4/4. Agreement-about-nothing is indistinguishable from agreement, so assert the
   set of checks the fixture *reached*, not just that the two outputs match. This is B-59's inert-check
   class one level up: an inert **fixture** rather than an inert check.

3. **Verify the implementer's environment, not just their output.** Codex reported every Stage-2 test
   green — under Windows PowerShell 5.1, because `pwsh` would not launch in its sandbox. The claim was
   true and the environment was wrong; CI runs pwsh 7. This is the third recorded instance of a
   codex self-report being an environment artifact rather than a falsehood. Re-run on the host that
   matters. (Ironically the reverse also bit here: the defect in finding 5 below exists *only* on 5.1,
   so codex's "wrong" host is the one that could have caught it — nobody ran both.)

4. **When an implementer fixes something you didn't ask for, find out whether the twin has it too.**
   Codex quietly repaired the counting bug in the *meta* harness because that was the file it happened
   to be running. The **shipped** harness had the identical defect in all three dists and it did not
   look. An unrequested fix is a signal that a class exists, not that the class is closed.

5. **`(pipeline).Count` is `$null` for exactly one object under PowerShell 5.1, and 1 under pwsh 7.**
   So `exit (Write-TestSummary …)` exited 0 while printing `[FAIL]`. Two failures returned an int and
   were caught — the bug hid precisely the single fresh regression. Always `@()`-wrap. `Measure-Object`
   is safe (it returns a real object), which is why the `metrics.ps1` counters were never affected.

6. **Ordered, not set.** Comparing twin output as a *set* of `OK:`/`FAIL:` lines hides ordering changes
   and duplicated or dropped lines. Compare the ordered sequence, normalize by name and never by
   pattern, and add a static assertion that the count of legitimate asymmetries has not grown — an
   exemption that can silently widen is not an exemption, it is a hole.

7. **Two adversarial passes were worth it, and the second one corrected the first.** Pass 1 (15
   findings) reshaped the design. Pass 2 caught a **factual error in pass 1's own remediation**: the
   metrics key inventory was wrong in both count and shape, and would have produced three incorrect
   consumer changelog entries. A reviewer's corrections are input, not verdict — the inventory was
   only settled by running a key diff per stack.

## 2026-08-01 — v0.42.0: a true half is what keeps a false claim alive

1. **The sentence survived because half of it was true.** `"Detected Framework Packages" and "Known
   Hazard Areas" are also refreshed by /docs-sync` sat in four shipped files across three stacks
   from its introduction to v0.41.0. Anyone checking it would have confirmed the packages half
   immediately — Step 4 does exactly that — and stopped. A compound claim needs each conjunct
   checked separately; the plausible half is camouflage for the false one.

2. **The highest-salience instance was the one that did not match the grep.** The `/docs-sync` claim
   was found by grepping `refreshed by /docs-sync`. `/rebootstrap`'s identical defect — a
   frontmatter `description` promising it refreshes "hazards" over a body that never mentions them —
   was invisible to that pattern, because it is *self*-description, not attribution. It was found
   only because an adversarial reviewer was asked to steelman the opposite position and went looking
   for the capability's rightful home. The gate proposed in B-76 must cover all three shapes for
   this reason; a check built from the string that found the first defect would have caught one of
   three.

3. **Fixing a false claim by making it true can be the wrong repair.** The instinct was to add a
   hazard step to `/docs-sync`. That would have let a model-auto-invocable command regenerate rows
   whose `[VERIFIED]`/`[SUSPECTED]`/`[UNVERIFIED]` design exists precisely to require a human
   answer. The correct question was not "how do we make this true" but "which surface should own
   this" — see WSD-027. Two of the three properties that decided it (auto-invocability, human
   presence) are invisible from the doc making the claim.

4. **`disable-model-invocation: true` turned out to be a design signal, not a config detail.** It
   cleanly separates commands that may be handed expensive or unattended work (`/bootstrap`,
   `/rebootstrap`, `/adopt`, `/impact`) from those that may not (`/docs-sync`). Nothing had ever
   used it that way. It is now the first check in the siting rule.

5. **The adversarial pass paid for itself by attacking judgment, not mechanics.** The mechanics
   reviewer confirmed the risky structural claim (dotnet-only snippet reaching `dist/monorepo` via
   the per-marker-name concat fallback, no sibling needed) and caught a fabricated risk in the
   plan's own verification section — a `no-meta-leak` warning about prose that could not trip any of
   the 13 denylist patterns. The design reviewer rejected the plan's core change outright. Both were
   necessary; only the second changed what shipped.

6. **The fix belongs where the damage happens.** The first draft's problem statement said a stale
   map propagates the wrong pattern *because `add-warehouse-load` trusts it* — and then listed
   `add-warehouse-load` as out of scope. The shipped fix is one caveat in that skill's step 1, which
   fires on the developer who is about to be misled, at no cost to any non-warehouse repo. The
   quarterly docs command got one bullet.

## 2026-08-01 — v0.43.0: the estimate was the bug, and the plan died to its own measurement

1. **A four-times-wrong estimate cost more than the thing it described.** `release.ps1` announced
   "roughly 30 minutes" for gates that actually take about six. Nobody had measured it. The number
   was doing real damage — it framed the release as something to batch up and dread, and it is what
   prompted this whole investigation. I also repeated it back as though I had observed it, which is
   how an unmeasured number survives: each retelling launders it a little further.

2. **The plan of record was disproved by its own measurement, after approval.** The agreed fix was
   to split the 101 s `TwinParity.Tests.ps1`. A throttle sweep then showed the suite plateaus at
   ~150 s regardless of lane count (160.7 / 152.6 / 150.3 / 151.4 for 4 / 6 / 8 / 12), because
   process creation serialises. Splitting moves spawns between files without reducing them, so it
   would have bought nothing. Measuring the thing the plan assumed is not a formality — the sweep
   cost ten minutes and saved a day of work in the wrong direction.

3. **Profile before optimising, even when the structure looks obviously wrong.** The 3-legs-times-4-
   lanes nesting *looked* like the bug. It was worth ~18%. The real cost was `pwsh` process startup
   at 265 ms a spawn, ~1350 spawns per release — and `validate-dist`, which I had assumed was a
   major term, turned out to be 2.3 s.

4. **The biggest win was environmental and invisible from the code.** PowerShell 7 starting 1.85x
   *slower* than 5.1 (265 ms vs 143 ms) is backwards, and points at the Store/MSIX build rather than
   anything in this repo. Filed as B-79. No amount of restructuring would have found it; only a raw
   spawn benchmark did.

5. **I asserted a coverage hole that did not exist.** I claimed `guard.sh` was never checked against
   an expected decision. The old split asserted `ps == expected` and `sh == ps` including exit and
   both streams, so `sh == expected` held transitively. The merge is still worth having for speed
   and clearer failure messages, but it was justified on a false premise for a while, and the
   changelog now says so explicitly. Transitive coverage is easy to miss when you are looking at one
   file at a time.

## 2026-08-01 — B-45/B-47: the rule that survived was the one the tooling could refuse

1. **The adversarial pass rejected the plan's form, not its content — and was right.** The draft was
   a Maintenance model section plus a gate asserting the section exists and the rule counts match.
   The reviewer's argument was short and decisive: rewrite all the rules to say "ship when you feel
   good about it" and that gate stays green. It verifies a heading, not a practice. Four precedents
   in this repo say prose alone does not hold — invariant #6 shipped ~190 leaking lines *after* being
   written down; Verification Rule #10 was contradicted by six shipped surfaces; the Definition of
   done already demanded red-testing while `framework-doctor` shipped three self-reporting defects.
   The version that shipped enforces rules 2–4 in `release.ps1`, which can refuse.

2. **Nine rules were four rules in costumes.** "Don't trust the implementer's self-report", "verify
   the spec's file-layout claims", "measure the assumption the plan rests on", and "don't restate an
   unmeasured number" are one rule: *nothing enters the record as observed unless you observed it, in
   the environment that matters.* Consolidating to five was not tidying — a maintainer under pressure
   might follow five and will never follow nine. The instinct to add a rule per incident is how a
   process document becomes unreadable and therefore unfollowed.

3. **Testing the real source text beat testing a re-typed copy.** The ledger writer could not be
   reached without a full release, so its actual lines were extracted from `release.ps1` and executed
   against a temp repo. That immediately exposed a defect a hand-written equivalent would have
   missed: the here-string header ended without a trailing newline, so the first data row
   concatenated onto the table separator. A malformed ledger would have shipped on the first release
   that used it — the artifact whose entire job is to be the handover record.

4. **Writing one doc surfaced three others that were lying.** `DEVELOPING.md` still said "Until Phase
   6 lands" seven weeks after Phase 6 completed. Both root `## Status` paragraphs claimed "no open
   P1/P2/P3 items remain" through twelve versions while P2 and P3 items were open, and scoped the
   strategic backlog as "B-41…B-48" after it passed B-80. All three are B-76's class — a doc
   describing a state that no longer exists — and none is reachable by `DocTruth`, which checks
   version stamps and script paths but has no notion of a stale narrative claim. The Status
   paragraphs were rewritten to point at the backlog instead of summarising it, because a summary of
   a moving list is a defect with a delay fuse.

5. **The backlog was wrong in both directions at once.** B-51, B-53 and B-73 sat open after shipping
   (overstating the work); B-74 and B-75 sat *inside* the Done section while open (hiding it). The
   second is worse and was the harder to notice. An audit that only sweeps one direction confirms its
   own assumption.

6. **A rule was practised for weeks and written down nowhere.** The post-activity RCA discipline —
   close every delivery by asking why no gate caught it and what else is exposed — lives in the
   maintainer's private memory, while root `CLAUDE.md` opens by claiming it "stands on its own:
   nothing resolves to private `~/.claude` memory". That claim was false for as long as the practice
   existed. Handover risk is not only what is undocumented; it is what is documented as unnecessary.

## 2026-08-02 — v0.44.0: four instruments that could not fail, three of them mine

Shipped B-74, B-62 and B-80 in one pass. Every substantive finding came from the same act: mutate
the subject, re-run the check, see whether it goes red. Nothing here was found by reading code.

1. **A test that runs its fixtures under the wrong host tests nothing.** `HarnessIntegrity` — the
   file whose entire purpose is to catch a Windows PowerShell 5.1 defect — launched its fixtures via
   the harness's `Get-PsExe`, which prefers pwsh 7 whenever it resolves. So the fixtures ran under
   pwsh 7 even when the suite ran under 5.1, and with the defect re-planted the file passed. The
   generalisation is uncomfortable: a helper that picks the "best" host is exactly wrong inside a
   test whose subject is host-specific behaviour, and every such helper reads as neutral convenience
   at the call site.

2. **A check scored by its own subject goes quiet precisely when it matters.** With the defect
   planted, the same file printed `[FAIL]` correctly and then exited **0** — because the summary
   function scoring it was the broken one. It reported the failure and certified success in the same
   run. Anything testing the harness must compute its own verdict; "print" and "score" are different
   trust boundaries and only the second reaches CI.

3. **An inert fixture and an over-broad one are indistinguishable from the summary line.** B-75 named
   the inert case. This release hit the opposite: the guard-extraction grabbed too *much* (sweeping in
   the commit+push), and the "did we get the right region?" assertion passed, because a larger region
   still contains every expected marker. One-sided assertions only bound one side. Both fixtures now
   assert a floor **and** a ceiling.

4. **A guard calibrated from its own backlog entry would have refused every recent release.** B-80's
   text named the *stamped* file set; a real release commit carries the whole session's work. Written
   to the entry, the allowlist produced 10 false positives replayed over the last 8 tags. The entry
   was not lying — it described the stamping, and someone read that as the release. A guard that
   refuses correct work gets its escape hatch passed every time, which is indistinguishable from not
   having it. Replaying real history against a new gate cost one loop and should be the default for
   anything that can refuse.

5. **A backlog entry can be contradicted by a decision that shipped after it, silently.** B-62's *Do*
   told us to fail on a bare interpreter name; v0.38.1 had already established the bare name as
   correct and reverted the alternative. Following the entry literally would have produced a gate
   failing three dists on purpose, and the plausible recovery — weaken the gate until it passes — is
   worse than not building it. Self-contained entries were a deliberate choice for handover, and this
   is that choice's bill: self-contained also means *not updated when the world moves*. Filed as B-83
   with a sweep of everything predating v0.38.1.

6. **Three of four red-tests were hand-rolled and discarded.** Only the assertions survive; the
   mutations that proved them do not. Two of those mutations were themselves defective on the first
   attempt. "Seen to go red" is only re-verifiable if the mutation is kept — filed as B-84.

## 2026-08-02 — B-88: the release watches CI, and four defects in the instruments that watch it

1. **A release path that ends at `push` has verified the maintainer's box, not the repo.** Every
   local gate passed for v0.44.0 and CI went red on both legs; the script had already printed
   "Release complete". The fix was not "add a check" but "move what the tag *means*": the watch sits
   before the tag, so a red or unverifiable CI leaves the commit on master **untagged**. B-53 had
   already taught this shape once — a script that exits 0 without verifying its own postcondition —
   and the postcondition set simply stopped one step short.

2. **The backlog entry's own instruction was wrong, and the critique pass is what caught it.** B-88
   said "after the tag push succeeds". Step 5b's comment already claimed "a tag always means a green
   release", which watching-after-the-tag would falsify. This is B-83's class observed live, filed
   the day before by the previous session, and it is the second time in two releases that reading the
   *surrounding* code rather than the entry changed the design.

3. **Two 5.1-only defects hid behind a green suite because the suite spawned the subject under
   pwsh 7.** `Get-PsExe` prefers pwsh whenever it resolves, so "run the suite under 5.1" exercised
   the subject under 7 regardless. B-74's RCA recorded this exact trap one release ago and fixed it
   in one file; it recurred immediately in new code, which is what makes it a class (B-90) rather
   than an incident. Bound to `(Get-Process -Id $PID).Path`, the suite went from 18/18 green to 13
   red on 5.1 within seconds.

4. **Single-element fixtures cannot see wrapping bugs.** Two independent mechanisms — a unary comma
   on a return, and 5.1's `ConvertFrom-Json` not enumerating a top-level array — each wrapped the
   parsed rows one level too deep. A wrapped array answers property access like its single element,
   so every single-row case passed. Only the multi-row cases (a `pull_request` run alongside a
   `push` run; a re-run superseding a failed attempt) could ever fail, and both did. Write the
   fixture that has two of the thing.

5. **A mutation self-test passes vacuously when the subject is already broken.** "The mutant fails"
   is satisfied by a subject that never worked: under 5.1 the suite showed 13 red cases and 4 green
   SELFTESTs, and those greens meant nothing. The self-test now runs the probe against the
   *unmutated* subject first, so the mutation has to be the reason it fails. B-75's inert-fixture
   lesson, one level up again.

6. **The RCA sweep found a shipped defect, as it usually does.** Asking "what else is exposed to
   this class" turned the 5.1 `NativeCommandError` finding into B-89: two shipped scripts whose
   deliberate graceful fallback works on pwsh 7 and dies with a raw error dump on 5.1. Their tests
   pass because they run inside a git repo, where the branch never executes.

## 2026-08-03 — B-86: the owed review of v0.44.0, run adversarially by a different model

1. **A review is the one deliverable where "different session" is not enough.** Maintenance model #2
   asks for a different tier "where available", and a second Claude session is not that. Running the
   adversarial pass as **codex `gpt-5.6-sol`** and keeping Claude as the re-runner produced a split
   that earned its keep in both directions: codex found three false-green paths in check 8 that this
   session had not looked for, and this session's re-runs *corrected two of codex's own findings*
   (the quotepath case is the default, not a configuration; the in-directory stray is surfaced by the
   manifest, so it is a record overclaim rather than a rejected premise). Neither half was
   trustworthy alone.

2. **The release themed on "instruments that could not fail now can" shipped a gate that could not
   fail — in three ways.** Check 8's vacuous-pass floor is a *total* of 15 against a real 26, so an
   entire registration file can go unextracted and the gate prints `all 20 … resolve`. The lesson is
   not "the number was wrong": it is that a floor written as a single total cannot see a per-file
   failure, and the comment justifying it ("6 + 6 + 8") was itself never measured. A guard against
   vacuity that is calibrated by hand inherits the vacuity it guards against.

3. **The RCA sweep beat the review.** Asking "what else is exposed" turned check 8's two mechanisms
   into a check 7 finding within minutes: `no-dead-instruction` counts nothing at all and carries the
   same absolute-path exemption. The review looked where it was pointed; the sweep looked where the
   class lives. Check 6 guards its *input* list and not its file scan, which is the same gap one step
   earlier — three checks, three different amounts of anti-vacuity, none of it deliberate.

4. **B-90 recurred inside the release under review, in a file that release added.** The staging
   guard's `@()` hardening exists for a Windows PowerShell 5.1 defect, and its test spawns the
   subject through `Get-PsExe`, which resolves to pwsh 7 even from a 5.1 host (measured). B-74 → B-90
   → B-93 is now the same trap three times. A helper that picks the *best* host reads as neutral
   convenience at every call site, and no amount of filing the class has stopped the next author
   reaching for it. The fix that would actually hold is renaming it.

5. **The flagship instrument was sound, and only a real 5.1 run could say so.** With the v0.41.0
   defect re-planted, `HarnessIntegrity` printed `3 passed,  failed, 0 skipped` — the `$null` visible
   in its own summary — and still exited 1. Confirming that needed `powershell.exe` invoked by
   absolute path, because it is present on this box and not resolvable from `PATH` (B-71). The
   difference between "verified" and "skipped inside a green summary" was one hard-coded path.

7. **`Get-ChildItem -Recurse` without `-Force` skips `.claude/` and `.github/` on Linux — and no
   local run can show it.** PowerShell treats a leading dot as "hidden" on Linux/macOS but not on
   Windows, so `validate-dist.ps1` enumerated most of a dist on the maintainer's box and a fraction
   of it on Linux: `no-meta-leak` would have inspected zero hooks and zero skills there while
   printing a clean pass, and `no-dead-instruction` would have scanned a minority of the docs. Both
   twins agreed on Windows and diverged on Linux, which is the shape twin testing on one OS cannot
   see at all (the sibling of the `.PS1` case-resolution divergence found the same week). Found by
   the CI linux leg, via a test whose own mutation had the identical blind spot — the mutation
   deleted the visible `.md` files and left the hidden ones, so the case failed for the right reason
   by accident. **Rule: every recursive enumeration in a PowerShell twin needs `-Force`, and a
   cross-platform count is only evidence when it was taken on the platform in question.**

6. **A total vacuity floor cannot prove each input survived extraction.** Check 8 accepted 20
registrations after an entire six-handler file disappeared because its floor was a total; a second
regex over the same bytes was not independent evidence. Guard the structure and the scanned inputs,
then keep the specific mutations as executable tests rather than prose-only red-test claims.

## 2026-08-05 — v0.45.0: the implementer's report was green; four shipping defects were not in it

B-97 and B-102 shipped together. The review pipeline worked exactly as designed and still would have
shipped four defects, every one found by **re-running an instrument** rather than by reading a diff
or a report. Worth writing down because the pipeline's own output said otherwise throughout.

**The adversarial review earned its keep, and was right where I was wrong.** It returned 7 blocking
findings on the implementation plan. Its sharpest: my plan claimed the composer catches a missed
snippet rename. It does not — an absent snippet emits nothing and the marker is consumed, so the
section silently empties. My reference-count estimates were also wrong by 4x (I divided a
whole-repo grep by four; the real figure was 77 sites across six file types, including the live
hooks a markdown-only sweep would have missed).

**But a reviewer's fix can be beaten by testing its premise.** The review said the two-carrier scheme
violated single-source authoring and wanted a composer post-step. Instead of implementing either, I
tested whether one file could serve both hosts (canary 5). It can. The finding was right; the
remedy was unnecessary. *Verify what a reviewer tells you, and check whether the problem can be
deleted rather than solved.*

**What the implementer reported as "no deviation":**
1. A `.ps1` gate blind to 15 of 117 markers — the shipped hooks — because it matched only the HTML
   marker form. The gate created to catch silently-empty sections had a silently-empty blind spot.
2. A `.sh` twin that **could not finish**: a `sed`+`grep` per (line × file × heading), exhausting the
   Git-for-Windows process table, while its `.ps1` twin took 10s. CI's linux leg runs it. **Twin
   parity is asserted on decisions, never on feasibility** — a twin that cannot finish is as broken
   as one that answers wrong. Now B-101.
3. A markdown link that dangled from the moved content's new location.
4. Two twins with different citation grammars.

**A skip message lied, and the maintainer caught it, not the tooling.** The suite printed "python3 is
unavailable on this host" and summarised green. Python was installed. On Windows a python.org
install ships `python.exe` and **no** `python3.exe` — so the probe could never succeed there. That
turned out not to be a test problem at all: every shipped `.sh` hook probed the same name, so on any
Windows box without `jq` the **write guard printed INACTIVE and allowed the write** (B-102, measured
`exit 0` → `exit 2`). A permanently-skipped test hid a P1 in shipped code for as long as it existed.

**The fix for a fail-open probe can fail worse.** `WindowsApps\python.exe` resolves and exits 49 — it
is the Store alias, not an interpreter. Adding `python` to a name-based probe would have selected it,
and the parse would then return empty under `2>/dev/null`: a loud INACTIVE warning becomes a silent
fail-open. **Probe capability by execution, not by name** — the same lesson B-63 keeps teaching, now
with a case where the naive fix is worse than the bug.

**Two self-inflicted, both the class we keep finding.** A `sed` whose delimiter clashed with its
payload failed while the *follow-up* `sed` succeeded, leaving eight hooks calling an unassigned
variable — and `bash -n` passed on all eight, because a syntax check is not a behaviour check. Then a
compound `elif` the patcher did not match had its invocation rewritten anyway, putting the assignment
120 lines later in a different branch. Found by asserting *ordering* (every use follows an
assignment), not by counting occurrences — my first sweep counted, and reported a false imbalance.

**CI caught the last one, and it was mine.** I edited content after regenerating the context-footprint
baseline and never re-ran it. Both legs went red. B-70's thesis for the fifth time, this time against
me: a change is not done until its first CI run is green. The local gate set has no "run what CI runs"
entry point, so *which* gates to re-run after a late edit is a judgement call — and judgement is the
thing that fails.

---

## 2026-08-05 — B-103: the owed review of v0.45.0, and a self-report that asserted three fixes that never shipped

**The review that Maintenance model #2 forces is the only thing that found this.** B-102 was found,
designed, implemented and verified in one session by one model. The ledger filed B-103 automatically
rather than letting the absence of a review pass silently. That auto-filed debt is what got paid
today, and it came back with **nine findings, five of them live defects.**

**The defect class is not in the code. It is in the report.** B-102's record says the probe was fixed
"in all ten shipped `.sh` hooks and the doctor", and that it "also fixes a false skip".
`git show --stat 6eb7752` contains **none** of: `route-prompt.sh`, `framework-doctor.{ps1,sh}`, or a
single test file. Three asserted fixes, zero of them in the commit. The commit message even reports a
"14 files × 3 dists" verification for files it does not contain. Nothing was dishonest — the author
believed it — which is precisely why a self-report cannot be the evidence.

**The worst of it inverted the thing it fixed.** `route-prompt.sh` extracts the prompt through an
`elif` chain ending in a regex fallback. On Windows `python3` never resolves, so the chain reaches
`command -v python` — the Store alias stub — and **an `elif` chain commits to the branch it
selects**. The regex `else` is never re-entered. So the hook returns an empty prompt and routes
nothing, silently, on the primary target platform. B-102's own commit message documents that exact
trap and explains why a name-only probe would be "strictly worse than the bug being fixed". It was
right. It just never edited the file. *The reachability of the fallback was the bug — not the name.*

**And the fix created a second defect in a file it never touched.** `framework-doctor` still asks
`has python3`. Post-B-102 the guard is active on a no-`jq` Windows box while the doctor reports the
write floor **INACTIVE**. The diagnostic every other honesty claim rests on now produces a false
alarm — invented by a fix, in a file outside that fix's scope, because "the doctor" was in the
record but not in the diff.

**How it was missed is mechanical, and worth more than the individual bugs.** The change was scoped
by grepping `command -v python3`. The sites that survived are the ones spelling the probe
*differently* — `guard.sh` uses a multi-line `for`, four hooks use a 200-char one-liner,
`route-prompt` uses a third form. **One contract, three grammars, and the grep was written against
one of them.** Now B-108. The general lesson: *a claim of "fixed everywhere" is unfalsifiable unless
there is an inventory a gate can re-derive.* No gate knows which files are parser-dependent, so
nothing could contradict the claim.

**The adversarial pass was worth it, and was wrong once.** Five blocking findings on the review's own
plan: four were right and changed the design materially — resolve *lazily*, because a per-prompt hook
must not pay interpreter startups when `jq` works; reuse the existing utility-sandbox fixture rather
than "scrub PATH", which breaks the hook before the branch under test is reached; keep the findings
as separately-traceable entries instead of absorbing them into the review; and specify the doctor as
a verdict *table* rather than "ask what guard asks". The fifth claimed a test file did not exist. It
does — tracked and unignored — and the reviewer had searched a tree that skipped `.claude/`, the
search hazard documented at the top of our own backlog. **A reviewer reproducing our own documented
trap is not an argument against reviewers; it is the argument for verifying each finding.**

**The pattern worth naming: three consecutive releases whose record overclaimed what shipped.** B-94,
B-102, and v0.45.0's commit message. Every one was caught by the next independent review, never by
the authoring session and never by a gate. The failing component is not the implementation — it is
the self-report. Worth asking whether `release.ps1` should require the claimed blast radius as a file
list it can diff against the commit it is about to make.

## 2026-08-07 — an optional document can still be a mandatory evidence boundary

The warehouse map did not need to become compulsory when dimension binding raised its stakes. The
actual invariant is that a write decision cannot proceed from absent or stale evidence. Accepting a
current map *or* a live-schema inventory preserves the team's right to decline the artifact without
turning that choice into permission to guess. Encoding the warehouse predicate once also exposed the
pure-SQL installer gap and made PowerShell/Bash parity testable.

Update ownership needed the same separation of artifact from intent. A deleted shipped skill is
ambiguous; a skill under `disabled-skills` plus a durable learning is an explicit decision. That lets
the framework deliver a security or correctness refresh to the inactive copy without silently
reactivating it, while standardized exemplar lines remain the narrow consumer-owned seam in an
otherwise framework-owned recipe.

## 2026-08-08 — a child-host selector is part of the evidence, not test plumbing

Running a suite under Windows PowerShell 5.1 proves nothing about 5.1 when its helper silently
launches every subject under PowerShell 7. That false-green mechanism had already concealed two
release defects, yet it recurred because `Get-PsExe` sounded like “the PowerShell running me” while
implementing “the newest PowerShell installed here.” The smallest complete fix was at that semantic
boundary: both harness copies now return their current process executable. Aggregate runners remain
free to select their normal host, but a deliberately direct 5.1 run can no longer upgrade the code
whose compatibility it claims to measure.

The design review caught two useful errors before code moved. First, an initial audit called most
remaining uses intentional preferred-host simulations, contradicting the shipped Windows settings
that explicitly register `powershell`. Second, a proposed `@(...).Count` mutation was not actually
load-bearing for the value shapes in the release fixture. Re-running the real helper in fresh child
processes supplied the cleaner instrument: the unchanged 5.1 probes selected 7 and failed, the 7
controls selected themselves, and the same four probes selected their own host after the fix.
That honest 5.1 run immediately uncovered a third real defect: an expected failing native Git probe
was terminating under 5.1 before the architecture generator could use its documented fallback.

## 2026-08-09 — an answer-rich fixture can manufacture the case for unnecessary guidance

B-124 began with a plausible instruction gap, but its first evaluator wrote the proposed decision
matrix into the warehouse map and stated the decisive grain in the prompts. Passing that fixture
could not show the skill was already sufficient; failing it could not isolate the missing rule. Opus
forced the evidence leg back to live DDL and non-leading requests. The unchanged skill then made the
right existing/new choice twice each, so proportionality rejected the planned shipped matrix.

The grader repeated the same lesson at smaller scale: it looked for `OrderLine`, while the correct
warehouse representation was `OrderNumber + LineNumber + AllocationSequence`. Reading the artifact
turned a false behavioral failure into a measurement defect. Outcome labels are not evidence until
the code they point at has been inspected, especially when a lexical proxy stands in for grain.

## 2026-08-10 — grader reachability does not validate the answer key

A constructible green row and several red mutations can still certify the wrong warehouse claim.
B-125's first health fixture treated a running balance on transaction rows as mixed row grain and a
copied customer identifier as a proven dimension join. The matcher behaved exactly as authored;
the authored answer was false. Confidence also cannot be a class-wide exact label when stronger
repository evidence legitimately changes it.

Review the evidence premise before the matcher: define the row identity, prove the relationship,
and distinguish classification risk from an inspected unsafe consumer. Then attack success with
plausible counterexamples—omitted sections, fixture-specific false rows, correct existing bridges,
filename discovery instead of reads, and a recommendation that states the rule before contradicting
it. A grader is trustworthy only when those worlds are red, not merely when deleting the expected
row is red.
