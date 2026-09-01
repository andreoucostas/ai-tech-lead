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

## 2026-08-12 — a crashed implementer round still leaves real work on disk; verify what's there before assuming zero progress

B-135's codex implementer round lost network connectivity to the model backend partway through
(`No such host is known` on the codex websocket endpoint) and exited non-zero. The failure looked
total, but `git status` showed 19 of ~20 target files already patched — codex applies edits as it
goes, not in one commit at the end, so a mid-run crash still leaves genuine, checkable progress.
Treating the non-zero exit as "nothing happened" would have discarded real, mostly-correct work and
re-run the whole round from scratch. The right move was to diff what actually landed against the
locked design, keep what was correct, and finish the rest by hand.

Two of the four defects a from-scratch run of the freshly-written tests caught were in the tests
themselves, not the implementation: (1) `"catch \{ \$rel = ...\}"` inside a **double-quoted**
PowerShell string interpolates `$rel` — there is no `\$` escape in PS double-quoted strings, only
backtick (`` `$ ``) suppresses interpolation — so an undefined `$rel` silently vanished, weakening
the regex until it matched almost anything. The sibling assertion one line above happened to still
pass afterward, but only because its weakened form coincidentally still matched real source text; it
was not actually testing what its failure message claimed. Lesson: a static-guard regex built from a
double-quoted string containing `$` needs a code-reading check, not just a green run, because the
green run it "always" produced was for the wrong reason. (2) Two required literal substrings for a
`.Contains()`-style check were split across a markdown line-wrap in the source prose it was checking
— exact-substring assertions over hand-wrapped prose are one reflow away from a false red **and**,
as this run showed, mask a missing phrase behind whichever required string happens to be checked
first in a loop, since `Assert` throws and stops the remaining checks in that `It` block.

B-135 also confirmed a second same-class disclosure surface beyond the one the field report named:
`.claude/hooks/audit-trail.ps1`/`.sh` fell back to the original absolute path (leaking local
username/drive layout) on `Resolve-Path`/`realpath` failure — found and fixed inside the same item
per Maintenance model rule 5, not deferred. `TECH_DEBT.md` was checked as a same-shaped committed
free-text register and found low-risk (its schema has no field that naturally invites operational
identifiers), so it was not treated as a third instance — but it is the same append pattern and
worth a glance if this class resurfaces.

## 2026-08-16 — a shipped gate must be judged from the consumer's vantage point, not the author's

B-58's first design compared, per skill, the set of backtick-quoted code spans in `CLAUDE.md` and
`AGENTS.md`, and put that comparison in `template-checks` alongside the slug-inventory check. It was
correct on our three stock dists (1 real hit, 0 false positives across 38 lines) and would have been
wrong the moment it shipped: `docs-sync-check.sh:138-141` runs `template-checks` **inside every
consumer repo**, and `generate-copilot.md:79` specifies `## Common Tasks` as "the skills list" — a
condensed, model-authored mirror with no verbatim requirement. The gate would have failed consumers
for doing exactly what the framework told them to do.

The distinction that survived, and is the reusable one: **the slug inventory is contractual on both
surfaces; the prose is explicitly the generator's to condense.** So the inventory check ships and the
description check does not — it now lives in an authoring-only meta test over the three stock dists,
whose header says why, so nobody promotes it back later. A gate that is true of *our* hand-authored
files is not automatically true of a consumer's *generated* ones, and `template-checks` runs in both
worlds. Ask which world an assertion is true in before choosing the file it lives in.

Two more from the same cluster, both found by reviewing a **green** implementer round:

1. **A brand-new instrument passed while parsing nothing.** `SkillListParity.Tests.ps1` reported
   `1 passed` after the list-prefix grammar was broken in all six stock files: zero slugs parsed,
   zero drift found, green. Non-empty inputs were not enough — the guard that mattered was asserting
   the *shared* population actually compared, since two non-empty inventories with no overlap also
   compare nothing. This is B-64/B-72/B-74/B-75's class arriving on a gate written *by people who
   had just read that rule*. Point the probe at the new instrument before believing its first green.

2. **A twin can pass `bash -n` and still raise the floor of a shipped script.** The bash twin used
   `mapfile` and `declare -A` — bash 4.0+, where `grep -rn 'mapfile|declare -A|readarray|coproc'`
   over `src/core` and `scripts` had previously returned *nothing*. macOS ships bash 3.2 as
   `/bin/bash`, and we tell consumers to run these scripts there. Syntax-checking on a bash 5.2 box
   cannot see this; the check that found it was asking "has any shipped script ever used this
   construct before?" Worth making a habit when a twin gains a builtin it never used.

And a working hazard that cost real diagnosis time: a dist hook suite failed with
`[MISSING] Mirror and version integrity` under Windows PowerShell 5.1, on baseline as well as on the
change — the cause was this box's corrupted `PATH` (no `C:\Windows\System32`, so the doctor's bare
`powershell` spawn resolves to nothing), not 5.1 semantics and not the doctor. Repairing `PATH` took
that suite from `29 passed, 1 failed, 1 skipped` to `31 passed, 0 failed, 0 skipped` — note it also
un-skipped a case, so the broken `PATH` was silently *removing coverage*, not just adding noise. Any
5.1-only failure on this box is PATH-suspect before it is an encoding bug; see B-130, whose original
hypothesis was encoding and was wrong for this member.

## 2026-08-17 — a defect class the maintainer box cannot observe, and what that costs

v0.53.0 needed three release attempts. The gate-runtime budget refused the first (the laptop slept
mid-stage and `Measure-Stage` is wall-clock; the fix is re-run, never a ceiling raised to absorb a
sleep — that would blind the one instrument built to catch a genuine multi-fold slowdown). CI
refused the next two, both times with **all six Windows legs green and all three linux-hooks legs
red**.

The cause, and the reason it is worth a permanent entry: **MSYS opens files in text mode.** Under
Git Bash, `awk`/`sed`/`grep` are handed a CRLF file with the CR already removed by the platform —
through a file open *and* through a pipe. I confirmed it the only way that settles it: I deleted a
script's CR-strip entirely and the check still passed locally. So a CR-handling bug in any shipped
`.sh` is not "untested" here, it is **unobservable** here, on the box where all authoring happens.

Two distinct defects came out of that blind spot in one release:

1. **Self-inflicted.** The shared `TemplateFixture` was switched to CRLF to give a new check an EOL
   control, which fed carriage returns to four older checks for the first time ever and broke tests
   unrelated to the change. *Do not buy coverage for a new check by mutating a fixture that older
   checks depend on* — scope the new input to the new case.
2. **Genuine and shipped.** `template-checks.sh`'s `section()` stripped CR from body lines but
   compared the heading with an exact string test, so on a CRLF checkout `## Leanness` + CR did not
   equal `## Leanness` and the mirror check declared four sections missing from a perfectly correct
   repo. The PowerShell twin was never affected — a twin-parity violation that had presumably been
   latent for as long as the function existed, because nothing on this box could ever see it.

The technique that made it tractable: reproduce **in memory**, where the platform cannot interfere —
`awk 'BEGIN{ cr=sprintf("%c",13); line="## X" cr; ... sub(/\015$/,"",line); ... }'` shows both the
failure and the fix locally. And use octal `\015` rather than `\r` in awk regexes: implementations
differ on which escapes they honour, and an unrecognised `\r` degrades to a literal `r`, which would
silently reinstate the bug on a consumer's Debian box. A CRLF assertion in a twin fixture is
linux-leg-only coverage and must be labelled as such; a Windows green on it is not evidence.

**The cheapest thing that helped was not a fix at all.** `ScriptTwinParity`'s exit-mismatch assert
reported two bare exit codes, which is useless when the only failing host is one you cannot
reproduce. Making it print both twins' stdout/stderr turned an opaque red leg into a named check in
a single CI cycle — and, unprompted, identified the last unexplained failure in B-130 (open since
2026-08-08 on an encoding hypothesis) as the maintainer box's corrupted `PATH`: a bare `powershell`
spawn resolving to nothing. Both members of that entry were one environment defect in an encoding
costume. When a diagnostic is cheap and the failure is remote, improve the diagnostic first.

## 2026-08-20 — Preserve a subprocess's third outcome

Shell content checks often treat exit 0 as "present" and exit 1 as "absent", but external tools
also have an execution-error outcome. Negation and `|| true` erase that distinction and can turn a
host/resource failure into a precise-looking defect in the artifact. Capture the status at the
subprocess boundary, reserve content findings for the tool's documented no-match code, and make
every other code a host FATAL. The same boundary rule applies to path dialects: translate MSYS paths
before handing them to a Windows host, and fail explicitly when the translator is unavailable.

## 2026-08-22 — A lifecycle fixture must make the destructive branch reachable

A minimal update fixture initially reported that the PowerShell installer preserved an unknown
GitHub-only skill even though the committed code plainly removed the whole directory. The apparent
contradiction was in the fixture: without a protected file or existing `.claude/skills`, the
temporary snapshot directory was never created, so the old installer's entire post-copy update block
was skipped. Seeding `CLAUDE.md` made the destructive branch reachable and both old twins failed as
the source predicted. A mode stamp proves only mode selection; every stateful regression fixture must
also construct and assert the prerequisites for the exact mutation branch under test.

Two review corollaries landed with it. First, an incoming manifest is not automatically a collision
list: `docs/wiki/INDEX.md` is listed but copied only when absent, so archiving it would have regressed
an existing consumer-owned contract. Intersect manifest membership with the actual operation policy.
Second, a `sed` address range cannot close on the same line that opens it; parsing a single-line
PowerShell array that way silently absorbed the following policy declaration. Keep the extracted
shape explicit and exercise the unmodified green path as well as the mismatch red path.

A path that is lexically beneath the target is not necessarily physically contained there. The
first archive preflight accepted a `docs/pre-adoption` junction and moved consumer originals into its
outside target while reporting an in-repository archive path. Check every existing source and
destination component for links/reparse points before mutation, including dangling link leaves;
string prefixes and `PathType Container` establish neither physical containment nor ownership.

## 2026-08-22 — A comparison label cannot create the pre-treatment state it needs

The retired impact workflow had careful-looking controls — fixed tasks, repeated trials, a stated
same-model rule, and a tag named `pre-adoption` — but `/adopt` ran after installation had copied the
framework. The tag therefore recorded a treated repository, not the old setup. The experiment was
not merely missing an optional CLI run; its claimed comparison arm was impossible, so no resulting
delta could support an A/B or causal value claim.

The corrective pattern is deliberately small: stop the claim, keep only descriptive evidence that
the available files can support, and turn the old executable surface into a stable non-zero
compatibility tombstone until ownership-aware removal is safe. Direct invocation belongs in the
regression suite even when a command no longer reaches the script: the original harm included what
an explicit runner call could launch. A reachable mutation of the tombstone output made the focused
suite fail, which distinguishes the new test from a static green check that never observes its
subject.

The first retirement sweep still missed the bootstrap pre-flight carrier, which repeated the same
`impact baseline` instruction even after `/adopt` stopped creating one. Active guidance is a path,
not just a command: the regression scan now covers bootstrap, session-start, and installer twins as
well as adoption/impact prompts, while deliberately leaving historical changelogs and the broader
claim-correction sweep out of scope. For direct tombstone invocation, stable output and a non-zero
exit prove only the contract; a controlled working-directory fingerprint plus `git worktree list`
before/after now also proves the tested call made no observable file-tree or worktree change.

## 2026-08-22 — Local release breadth is not CI breadth

The same full hook suite has a different cost model on a maintainer workstation and on CI. CI gives
each dist/host leg its own runner, so dotnet/angular/monorepo coverage on Windows and Linux is genuine
breadth. A local release put three complete suites, their child processes, and an outer-parallel meta
suite on one host; the result was contention, not a stronger proof. A sequential representative was
also not a useful compromise: it passed all 20 files with 0 failures but took 924.1s, making
dist-gates 1004.0s. Preserve every assertion, leave all shipped-hook coverage to the all-dist/all-host
CI matrix before tag, and keep the full root meta suite locally because it protects authoring and
release mechanics before push. Do not call any final speedup until a measured release transcript
proves one.

## 2026-08-22 — A mirror can make a false claim look more authoritative

Verbatim carriers, generated copies, and polished presentations answer distribution consistency;
they do not answer whether the repeated sentence is true. The strongest assurance language needs a
small maintainer-owned test tied to the actual event/host boundary, with history excluded so the
instrument cannot erase the record it is meant to correct. Keep the denylist narrow: universal
write coverage, regulatory satisfaction, and unwired deterministic enforcement have a high cost
when wrong and a clear qualified form when right; general persuasive prose does not.

The first composed validation after the correction caught the complementary failure: AGENTS and the
portable rule carrier had been edited to equivalent meanings but were no longer verbatim. Truth and
consistency are separate gates, and both are necessary. The fix shortened one shared sentence,
restored exact mirroring, and increased static-context headroom without weakening the qualification.

A routing marker has the same boundary problem. Two warehouse signal categories prove that a
repository is warehouse-shaped; they do not prove the selected stack can complete adoption without
a solution. Until that lifecycle is supported end to end, refusing before mutation and naming an
explicit informed override is more honest than silently choosing the nearest implementation.

## 2026-08-23 — Ownership metadata says who supplied a path, not whose bytes are there now

A previous manifest entry and a trusted incoming tombstone can establish that the framework once
owned a path and now wants it gone. They cannot establish that the file still contains framework
bytes: consumers edit framework-owned files, and the previous manifest itself is mutable. Safe
retirement therefore needs a third fact—the current digest matches a known shipped digest authored
into the cumulative ledger. A mismatch is a preservation decision, not a deletion failure.

Operation planning exposed a cost trap in the first implementation. Applying 165 manifest entries
with one shell process per file made the Windows/Git Bash installer several minutes slower across
the lifecycle suite. Keep the file-level authority and plan, but batch the already-validated list
through one archive stream. Precision in policy does not require process-per-file execution.

The same proportionality rule applies to tests. Once inert compatibility code is deleted, hostile
argument permutations against that code no longer protect a live boundary. Replace them with the
distinct destructive worlds—known bytes, custom bytes, malformed authority, reparse escape,
dry-run, and downgrade—and remove repeated full installs where composition already proves the core
installer is identical across distributions.
## 2026-08-23 — A matching dry/apply plan can be identically incomplete

Comparing dry-run output with apply-run output proves determinism, not truth. Both installer twins
printed the same incomplete plan while post-copy skill backup, disable, and mirror logic mutated
additional paths. The useful oracle is the target transition: every changed leaf must be covered by
a planned write or a planned tree deletion, and a deliberate omitted-plan mutation must make that
assertion red. Refactoring protected files from snapshot/restore to direct skip also removed writes
that existed only to compensate for the old bulk-copy implementation.

A generated artifact is similarly not independent history. Comparing a retirement ledger only with
the current mutable dist permits source and dist to forget the same entry together. The first
ledger-bearing release needs a required maintainer baseline because neither its current HEAD nor its
preceding tag contains that history yet; committed and nearest-release ledgers then continue the
chain. Use Git history only when the composer root is the worktree root—an archive nested below an
unrelated repository must not inherit its authority. Test synchronized source/dist/baseline deletion
as well as source/dist drift.

Planning also exposed an ownership boundary hidden inside content carry-forward. A pre-existing
skill can contain a framework exemplar sentence without being an incoming framework skill. Treating
that sentence as sufficient authority rewrites an unknown consumer file outside the operation plan.
Scope exemplar merging to names in the incoming manifest; consumer-only skills may be mirrored, but
their active bytes are not framework payload.

The release retry exposed the same distinction at the test-host boundary. The agent-eval recurrence
test meant to prove that Windows PowerShell 5.1 reaches and rejects a PowerShell-7-only runner, but
its child invocation omitted `-ExecutionPolicy Bypass`; on a host where 5.1's effective policy was
Restricted, policy refusal happened before version parsing and the intended assertion was
unreachable. A test of an interpreter boundary must neutralize unrelated host script policy just as
the hook harness already does, then assert the specific version failure it was built to observe.

## 2026-08-24 — A distribution name is a delivery decision, not repository evidence

Successfully copying a bundle into a repository says nothing about whether the bundle's next-step
commands apply. The original warehouse fixture proved root selection and installation, then stopped
before `/bootstrap`, `/adopt`, workflow rails, CI guidance, and the doctor inherited a nonexistent
solution. That made B-115 look complete while the developer handoff remained unusable. Bind each
lifecycle stage to fresh Git-root evidence and keep one durable inventory for exact commands;
`not available` is more truthful and more actionable than a default command that happens to be
common in the distribution's usual consumer.

This is also a test-design lesson. Executing Markdown through a real language model would be slow,
nondeterministic, and still would not isolate the carrier contract. More installer permutations
would only prove the same copy seam again. The proportionate boundary is a real greenfield and
brownfield install plus a finite inspection of the installed handoff carriers, then focused tests
for the deterministic router and doctor decisions. Fold a new world into an existing matrix when
it exercises the same decision; do not create a new test merely to give the finding its own title.

## 2026-08-24 — A green carrier check can still certify the wrong sentence

Positive keyword checks proved that workflow files mentioned repository evidence and `not
available`, while contradictory unconditional application/test instructions survived elsewhere in
the same carriers. The useful contract needs both sides: require the evidence-bound branch and
reject the exact unconditional assumption. Keep the negative predicate narrow—a substring such as
"write a failing regression test" also appears in the correct conditional rule and creates a false
failure that rewards weaker wording.

The Bash warehouse classifier exposed a second test-quality trap. Piping `basename` plus file
content into `grep -q` under `pipefail` lets an early filename match close the pipe while the writer
is still active; the writer's SIGPIPE can turn a true match into failure. Check filename and content
separately. A cross-platform oracle should assert the ordered category result, because merely
asserting the selected distribution would not reveal one twin silently dropping a category.

Testing guidance must also be proportional in the product, not only in this framework's own suite.
"Every public behavior has a test" and incidental suite bootstrapping invite low-value, framework-
shaped tests. Prefer the smallest set that protects consequential branches, boundaries, and known
regressions; establishing a new harness is an explicit design choice rather than a side effect of
feature or cleanup work.

The same audit found a concrete framework-suite example: one protected-sync arm reran every state
already exercised by arms 1-7 and 9, adding 16 child doctor launches without a distinct oracle.
Deleting that arm was safer than retaining it for a larger pass count. New adversarial worlds—deep
warehouse paths, false package-string evidence, cross-template markers, and generated-tree decoys—
were folded into the existing decision matrices instead of receiving duplicate top-level tests.

## 2026-08-24 — A container filename and property-shaped text are not technology evidence

A solution file identifies a container, not the project types inside it. SSDT commonly puts only
`*.sqlproj` projects in a `.sln`; treating that filename as a C# application activated .NET
analysis, toolchain checks, and post-write builds in a warehouse-only repository. Require an actual
`*.csproj` to select the application profile, and inspect a solution for C# project references
before choosing it as a build target.

The same rule applies inside JSON. Regex over raw package/Nx text accepted escaped script prose,
arbitrary notes, and even malformed files as Angular evidence; regex extraction from malformed
Copilot hook JSON invented registrations that were not active. Parse first, require the property in
a field whose semantics establish the technology, then extract. An unreadable or unparseable
candidate is incomplete evidence (`CANT-VERIFY`/refusal), not proof of absence and not a live
registration. These adversarial worlds belong in existing decision matrices because they exercise
the same classifier boundary rather than deserving separate suites.

“Parse first” still needs a named grammar. PowerShell's `ConvertFrom-Json` and `jq` accept
different JavaScript/number extensions from Python's standard decoder, so three successful parses
can describe three different evidence boundaries. Put a strict lexical/grammar check in front of
the permissive parser, reject non-finite and leading-zero numeric forms explicitly on the `jq`
path, and keep valid decimal/exponent controls in the same matrix so strictness does not become
accidental rejection.

An inventory is also not authority to execute what it discovers. Deployment-shaped commands can
be perfectly evidenced and still mutate the wrong environment; record them as manual/CI-only until
the exact invocation is a non-mutating validation/dry-run or a developer authorizes a known target.
Likewise, a post-install adoption scan must distinguish archived legacy bytes from the live framework
it just installed: use the ownership manifest as an exclusion set, and keep the pending marker until
all pre-bootstrap archive and merge phases are genuinely complete.

Shared regex data is executable dialect, not inert configuration. A token such as `\s` can agree in
.NET and GNU grep yet diverge on BSD grep; stay within the actual common subset or translate at each
consumer boundary. Reads are part of classification too—an unreadable candidate is an incomplete
scan, never an ordinary non-match.

## 2026-08-24 — Cross-carrier consistency does not require cross-carrier repetition

A rule can be correct everywhere and still be over-engineered in aggregate. The first v0.77.0
release attempt repeated the same six-category verification and execution-authority contract in
workflow classification, subtask execution, self-review, and stack-specific fragments. Every
carrier agreed, but the always-loaded Claude footprint exceeded all three declared ceilings by
6.7–10.9%. The release gate refused before commit.

State a cross-cutting contract once in the canonical always-loaded rules and make workflows refer
to it. Keep routing frontmatter about applicability, not the agent body's full checklist. This
removed roughly 4.6–5.5K static characters per profile without raising a ceiling or losing the
negative carrier assertions. When an authoritative data table replaces duplicated prose, update
deterministic evals to consume that table too; otherwise the test preserves the duplication the
production change intentionally removed.

## 2026-08-24 — Compare the contract, not its neighbouring report

A parity assertion for one canary compared the complete doctor footer. The canary bytes agreed,
but a Linux host legitimately produced one fewer unrelated `OK` row, so its footer summary differed
and all three Linux shipped-hook jobs went red. The redundant mutation probe failed independently
on the three Windows jobs, leaving every shipped-hook job red. Extract and compare the named record
whose parity matters; whole-report equality is appropriate only when the whole report is the contract.

Mutation tests need the same proportionality check as production tests. A parser mutation recreated
an obsolete branch shape and failed without saying anything new: the neighbouring black-box cases
already accept a real interpreter available only as `python` and reject a name-resolving Store stub.
Those paired outcomes protect the behavior directly. Delete a mutation proof when it duplicates that
oracle and adds structural coupling rather than independent fault detection.

Enabling Bash `nocaseglob` does not make a literal pathname case-insensitive: a word such as
`$dir/package.json` has no wildcard, so there is no glob operation for the option to influence.
This passed on Windows and missed `PACKAGE.JSON` on Linux. Enumerate directory entries with a real
glob, then apply `nocasematch` to the basename when the supported marker set is deliberately
case-insensitive.

## 2026-08-26 — An improvement ledger and a balanced evidence ledger answer different questions

The field-report ledger contained negative reports because the maintainer recorded feedback that
could drive a change and did not record the positive feedback also received. Reading that shape as
user sentiment would be a category error: it is the output of an actionability filter. The positive
feedback cannot repair the inference either because its count, context, and denominator were never
captured. Preserve issue intake for defect diagnosis; use a protocol that records benefit, harm,
mixed effects, and no detectable difference symmetrically for value claims.

Designing that protocol exposed a second version of the same mistake. `meta/drill-kit.md` called its
table the frozen B-49 rubric, but its fifth row was review findings; the locked design's fifth row was
leanness, with review findings scored separately. Two plausible-looking copies had silently become
different instruments. A shared measurement contract needs one executable copy, even when it is
prose. `meta/value-rubric.md` now serves both the maintainer drill and field study; changing it starts
a new series rather than rewriting the meaning of old results.

## 2026-08-26 — Repository age does not select the framework lifecycle

An existing application repository can still be a `greenfield` framework install. The first field-
study packet called the codebase brownfield and therefore prescribed `/adopt`, but exact v0.77.0
correctly selected its own lifecycle and printed `/bootstrap`. Bind instructions and measurement
fields to the installer's observed handoff, not to an experimenter's informal label for the repo.

That handoff is also a real experimental boundary. Bootstrap is developer-initiated by design; an
AI coordinator cannot turn a maintainer-only replay into a fully autonomous test by silently
reproducing it. A protocol dry run should record that stop, correct the packet, and preserve the
partial result. Doing so measures usability while keeping human-governed setup genuinely human.

## 2026-08-26 — A detached checkout still carries the answer key

Removing a remote and detaching at a pre-fix commit isolates push risk, not history. The object
database and refs still contain later fixes; a locally planted latest commit is worse because its
parent and one-line diff state the intended answer directly. In the first field-study run, the BARE
agent used `git show` on that planted commit and solved the task from its diff. Historical replay
arms must therefore be exported as identical content snapshots and re-initialised with one neutral
root commit. Confirming empty remotes is necessary but not sufficient.

Bootstrap discovery creates a different, legitimate asymmetry. In the same run, FRAMEWORK wrote the
exact bug and recommended regression test into its generated debt register, then the task agent used
that diagnosis. Do not delete that output to make the comparison look cleaner: repo understanding is
part of the installed treatment. Disclose it and limit attribution to the complete package. If the
question is task-time rails alone, design a separate execution-only ablation whose framework context
was prepared on the accepted clean state before the history-free defective snapshot is created.

Finally, rubric rows can be individually reasonable and jointly double-count the same behavior. Two
of the three frozen convention checks were test-style checks, so an omitted regression test lost R2
and R3. Require R2 checks to be independent of test existence/order and leanness before a run; do
not repair the scores after seeing the result.

## 2026-08-26 — Exit zero is not evidence that the expected test ran

The corrected field replay's private probe rebuilt both test projects. One arm executed and passed;
Windows Application Control blocked the other arm's test assembly, yet `dotnet test` exited zero
and printed that no test matched. Treating process status alone as green would have converted
`cannot examine` into `passed`—the same maintenance-rule-7 failure this framework has already
fixed in several product gates. A targeted verifier needs positive execution evidence: the expected
name/count ran and passed. Preserve load/skip/no-match output as a host failure and do not retry it
until green.

The same run exposed a staging hazard. `git add --force --all` is appropriate when turning an
exported source tree into its first neutral root, before any build exists. Reusing it after baseline
tests force-tracked thousands of ignored `bin/` and `obj/` files. The error was caught before an
agent ran by inspecting the prepared commit, and a fresh arm replaced it. Scope destructive or
override-shaped commands to the phase that needs them; later commits use ordinary add plus a staged-
path inspection.

Setup model is also part of the treatment record, not an incidental host detail. Opus usage was
unavailable, so the developer bootstrapped with Sonnet. That path took 23.9 minutes and 11 follow-ups,
then claimed completion with docs sync red; a Sonnet mirror repair also claimed parity while leaving
one line stale. The deterministic gate, not either completion statement, established readiness.
Record setup and task models separately, including quota-driven selection, and never attribute a
lower-tier onboarding result to the intended higher-tier path.

## 2026-08-26 — History isolation removed the apparent value delta

Once the answer-bearing Git history was removed, BARE no longer read the planted mutation's diff.
Both Sonnet arms independently produced byte-identical production changes and the same regression
test. FRAMEWORK demonstrated the test red first and scored `10/10`; BARE changed production first
and scored `9/10`. The frozen material threshold is two points, so the valid result is no
detectable difference. The void run's apparent `+3` benefit was therefore mostly an instrument
artifact, not evidence that should have been rescued.

This does not prove the framework has no value. It proves one small, obvious boundary fix did not
need enough repository guidance for the measured outcome to diverge. FRAMEWORK's route/session/audit
surfaces were reached and its sequence was stronger, but BARE solved the task acceptably with zero
intervention. The next useful evidence is a non-author run or a more discriminating predeclared task
series—not lowering the threshold or choosing a task after seeing likely performance.

## 2026-08-27 — A synchronized ownership policy can still synchronize the wrong owner

The v0.78.0 installer twins, composer, generated ownership manifests, and 47-case update suite all
agreed that `docs/architecture-decisions.md` was framework-owned. The framework's own `create-adr`
workflow simultaneously defined that exact path as the consumer's append-only history. Agreement
therefore made the destructive behavior consistent on both hosts; it did not make the classification
true. Ownership needs a semantic assertion derived from every writer and lifecycle, not only parity
between policy copies. When framework scaffolding becomes consumer state after onboarding, test the
exact colliding path through greenfield, brownfield, and update transitions with sentinel bytes.

A neighbouring fixture is not evidence for a collision boundary. The mature-document eval preserved
files under `docs/architecture/` and `docs/decisions/`, while the installer test preserved
`docs/ARCHITECTURE.md`; neither exercised `docs/architecture-decisions.md`. Use the production
canonical name when the risk is path identity, even if broader-looking directory fixtures already
exist.

The same review found a contract/oracle version of the error. Bootstrap prose now requires a complete
status token and an exact repository-relative path, but the older hazard checker deliberately accepts
pure prose, prefix statuses, and tree-wide bare-filename matches. A new completion gate inherits the
truth boundary of every delegated checker. Tightening authored instructions without planting the old
accepted worlds against that checker creates a stronger claim, not stronger enforcement. Supported
host commands are part of that boundary too: if Windows PowerShell 5.1 is advertised and the script
runs there, mandatory workflow prose must expose that invocation rather than naming only `pwsh`.

## 2026-08-27 — A manifest assertion needs the path in its fixture

The first B-185 composer assertion went red on both twins, but for an invalid reason: the minimal
composer subject did not contain `docs/architecture-decisions.md`, so the manifest could not emit a
row under either ownership class. That red did not prove the old classification was rejected. The
fixture was corrected to copy the canonical source file before the assertion was accepted; the
independent lifecycle instrument had already produced the valid pre-fix red—four failures showing
the sentinel overwritten or relocated on both twins. A test about a path's metadata must first
assert or construct the path's presence, just as a routing test must prove its branch was reached.

## 2026-08-27 — Runtime compatibility is not a delivered command

`docs-sync-check.ps1` already ran under Windows PowerShell 5.1, and the READMEs already supported a
Windows-without-`pwsh` configuration, yet every new mandatory completion block named only `pwsh` or
bash. Compatible bytes do not help a consumer who is given no command that starts them. A finite
host matrix must assert exact, separately labelled invocations inside the workflow section that
owns them; checking only that a `.ps1` path appears lets one PowerShell host stand in for another.

Delegation is also part of the boundary. `/adopt` consumes `/bootstrap`'s one completion result, so
copying the commands into adopt would create a second authority rather than improve support. Add the
missing command at direct execution points and keep delegating carriers single-sourced.

## 2026-08-27 — Evidence identity includes its resolution scope

The old hazard checker made a bare `PaymentService.cs` look robust by searching the whole repository.
That convenience changed the claimed identity: a root-level reference silently became whichever
nested file shared the name. Wildcard-prefix validation did the same thing, turning a pattern into a
directory assertion. An evidence oracle must resolve the exact identifier at the scope its authoring
contract names. Broader search is discovery, not validation; labels, URLs, symbols, and globs can
remain explanatory only when a separate exact reference carries the proof.

String prefixes are likewise not token grammars. `[REVIEWED: not a hazard` accepted truncated text,
garbage suffixes, impossible dates, and a date contradicting the adjacent column. Anchor the whole
token, validate captured values semantically, and bind duplicated facts to each other. Finally, test
the delegating completion wrapper: leaf parity alone would not have demonstrated that malformed
hazards actually made `docs-sync-check` withhold its final success line.

## 2026-08-29 — Remaining budget is not evidence that the budget is wrong

The static-context ceilings began with roughly 16% growth room and later approached their hard
limits. Treating that initial margin as something to restore would create a ratchet: every addition
could consume the allowance and then cite low headroom as evidence for the next increase. A stable
budget becomes useful precisely when it forces new permanent material to displace, consolidate, or
out-rank old material.

Separate capacity from cost. A model's larger context window says it can accept more input; it does
not show that repeatedly loading more framework prose is free or improves instruction salience.
Likewise, do not compress proven rails merely to make a dashboard look spacious. Keep an absolute
cross-host budget stable until a separately reviewed, observed benefit cannot fit after reasonable
displacement or new measurements change the cost trade. The payload that wants room must not also
decide that the room exists.

## 2026-08-29 — An artifact oracle must include framework side effects and destination semantics

A one-file live oracle initially rejected correct SQL because the installed `PostToolUse` audit hook
appended its own telemetry. Directly constructing the file in self-tests had bypassed that side
effect. Exact-tree grading must distinguish narrowly validated framework-owned consequences from
agent-authored scope: here, only append-only audit rows naming the requested artifact are allowed,
and unrelated rows, rewrites, staging, commits, or other paths still fail.

The next run exposed the other half of the same lesson. The fixture declared `analysis/` as the
home for ad-hoc queries, but its SDK-style SQL project included every `**/*.sql`; a build-safe agent
therefore edited the project, violating the one-file oracle for a good reason. Prompts, fixtures, and
tree assertions form one contract. Before measuring model behavior, prove that the requested output
is valid in the destination without a forbidden companion change. Correct shared confounds in both
worlds and invalidate affected samples—never relabel a mechanically accurate failure as the desired
semantic result.

## 2026-08-29 — A useful proxy must remain defeasible

The maintenance rules equated reviewer rank with review validity even though the ledger's own
peer-tier reviews found blocking defects. Rank had been a proxy for the things that actually varied:
fresh context, independent hypotheses, another host or toolchain, and hostile evidence the
implementer had not chosen. Once frontier models reach the top available tier, the proxy becomes
both impossible to satisfy and less informative than the work the reviewer demonstrably performs.

Keep the valuable invariant—no implementer self-certification—but specify observable independence.
Record the immutable range, blind-first threat model, applied red case, clean rerun, environment,
and gaps. Add an orthogonal vantage where the harm warrants it. More generally, a dated decision is
not a command to ignore changed dependencies: preserve why it was made, then re-audit and supersede
it explicitly when evidence changes. “The model is better” opens that audit; a task-shaped result,
not optimism, decides it.

## 2026-08-29 — A valid null can expose a low-information task class

RERUN-02 was methodologically valid and its no-difference result remains exactly that. Its one-line
fix also revealed that the chosen task left three rubric dimensions near their ceiling for any
competent agent. Repeating the same shape would add samples without necessarily adding information.
That is a reason to start a prospective series with a stronger construct, not permission to alter or
bury the null.

For convention-sensitive value, select tasks objectively before arm order, require several
independent architectural decisions, and prove the grader recognizes both valid and violating
worlds. Keep those decisions as a vector: compressing three different failures into one small score
hides severity and identity. New model capability should push measurements toward tasks where
judgment can vary, while chronological selection, frozen oracles, and first-result retention prevent
that move becoming outcome shopping.

## 2026-08-29 — A caller can turn a valid skip into a false-green completion

B-77's hazard checker was an optional drift detector, so missing, pending, and placeholder input
could reasonably mean “nothing to validate yet.” v0.78.0 later put that checker beneath a mandatory
completion wrapper without re-auditing its null states. The same exits then meant “the framework is
complete.” The old decision was not foolish; its caller and consequence changed. Whenever an
instrument moves from advisory observation to completion authority, re-derive every absent,
pending, empty, placeholder, duplicate, and mixed outcome from the new caller contract instead of
inheriting historical green states.

The remaining parser bypasses shared the same finite-list mistake. Tests named familiar examples
but did not partition the grammar: quoted versus unquoted tokens, wildcard families, terminated
versus unterminated records, raw versus display-normalized paths, or real-row versus sentinel
cardinality. Bash then reused an untrusted regex capture while rewriting its own search string, and
both twins trimmed punctuation before asking whether the original token carried safety-significant
evidence. Each local operation looked harmless because the suite asserted examples rather than
transform boundaries.

For completion oracles, capture every subject before asserting, gate the expected subject count,
exercise leaf and wrapper states, and mutate each independent twin after green. Preserve raw and
display forms until safety classification is complete, make sentinels exact whole outcomes, and
test both false acceptance and false rejection. A better model is useful here because it can
re-derive the state space and challenge old assumptions; it is not itself evidence that the new
grammar is sound.

Green is not closure when the grammar transform itself has not been partitioned. The first B-193
candidate passed its expanded suite but fresh reviewers still found bare-dot, punctuation-order,
and exterior-suffix bypasses. Repeatedly peeling only matching lexical endpoints while preserving
one detached safety suffix made the transformation finite and reviewable. The review then found an
oracle defect too: ten positive spellings in one row proved only that *one* spelling resolved. Put
each independently claimed positive in its own required-evidence row, even when all rows share one
fixture and execution, then plant a mutation that skips exactly one. Coverage cardinality counts
executions; it does not by itself prove that each token inside an execution is discriminating.

The same-class sweep found two plain Bash `read` loops in session-start advisories that can drop a
final non-newline security or hazard row. Their consequence is lost or downgraded visibility, not a
completion false green, so B-195 owns that smaller P2 fix instead of silently widening B-193. Sweep
mechanisms across the repository, but size and schedule each disposition from its actual caller and
harm.

## 2026-08-30 — Parse accepted records once; do not validate and extract with different grammars

The disabled-skill reader first used an anchored `grep` to admit trailing whitespace, then a second
prefix-only `sed` to remove only the heading. A line could therefore pass validation while leaving
HT, spaces, or CR attached to the lookup key and silently reactivating the skill. The surrounding
`grep || true` also collapsed a genuine read/tool failure into the same empty ledger as an ordinary
no-match. Each command looked reasonable in isolation; their composed language and failure model
were different.

At a byte-sensitive parser boundary, normalize only the exact encoding marker the contract admits,
only in the parsing stream, and keep that stage visible to `pipefail`. Then use one anchored capture
to both recognize the record and emit its normalized key. Prefer strengthening an existing
end-to-end outcome with independently specified hostile bytes and orthogonal mutations over adding
a new result that recounts the same behavior. Test count is not evidence density.

Release metadata is linear too. Do not put a future `Unreleased` H2 above a still-pending release:
the release tool deliberately treats the first H2 as the only release head, so parallel heads make
the earlier candidate unreleasable. Either finish the current release first or explicitly replan
the new work into it, then exercise the release-head parser—not just generic documentation gates.

## 2026-08-30 — Repairing an EOF false negative can expose a malformed-record false positive

B-195 began as two ordinary Bash loops dropping a final non-newline record. Re-deriving the whole
reader contract found more than the familiar `read ... || [ -n "$line" ]` fix: CRLF and already-
admitted heading whitespace also suppressed the hazard section, while making EOF reachable caused
Bash to count an unterminated four-cell row that PowerShell correctly skipped. A local correctness
change can move the parser boundary and create the opposite error unless the negative frame is
tested at the newly reachable boundary.

Stage that evidence instead of manufacturing it twice. The unchanged hook made the three valid
hostile worlds red. Adding EOF, CR normalization, and the accepted heading grammar made those green
but deliberately left the malformed world red. Adding the minimum frame last made the suite green.
Those intermediate product states prove why every line exists more directly than replaying five
equivalent mutations after green. Mutation is a means to discriminate behavior, not a ritual.

One grouped result is only honest if it evaluates every world before failing. A throwing assertion
inside the first hostile case would have hidden the CRLF and heading defects behind the EOF failure;
collecting the named failures first preserved one result without collapsing its evidence. The same
value test rejected an EOF-fresh world: the ordinary terminated fresh controls already pin the
threshold, and the extra shape passed both old and new readers. Test count should grow only when a
new product decision does—as it did for the previously untested overdue-security severity branch.

## 2026-08-30 — Count logical diagnostics, not renderer metadata

B-203's first locked oracle required a unique child stderr sentinel to occur literally once. That
was true under PowerShell 7 and false under Windows PowerShell 5.1 even though the product invoked
the child once: `RunArg` renders native stderr as an ErrorRecord whose primary line contains the
sentinel, then repeats the same token inside `CategoryInfo`. A literal count therefore measured the
host renderer as though it were product duplication. The hostile host run caught the test, not a
wrapper defect.

Do not weaken this class to `Contains` or “at least once”; either would miss a child invoked twice.
Count the logical record at the narrowest stable boundary instead. Here, split physical stderr
lines, trim each, and require exactly one line ending ordinally in an ASCII world-specific sentinel.
The real diagnostic line matches under both hosts, renderer metadata does not, and two child writes
still produce two matches. Keep literal exact counts for stdout and wrapper-owned notes, where the
renderer does not manufacture copies.

Hostile execution is also a design input, not a final ceremony. The product status mapping was
already correct when the 5.1 run failed; changing the runner or discarding the assertion would have
expanded scope or lost duplicate-execution coverage. Freezing the evidence-driven oracle amendment
before correcting the assertion preserved the reason for the change and added no suite, result, or
wrapper run.

## 2026-08-30 — Executing teardown is not evidence that teardown happened

`RootInstallerWarehouse.Tests.ps1` put recursive cleanup in `finally`, yet a Windows sharing
violation was non-terminating: the path survived while the harness reported 12/0. Making only the
command terminating would have created the inverse defect, because cleanup could then mask the
product assertion that failed first. A fixture lifecycle has two outcomes, not one. Capture the body
and cleanup independently, verify the required absent postcondition after both successful and failed
removal calls, and retain both causes when they fail together.

Recursive deletion deserves narrower trust than ordinary test setup. A generated-looking basename
is insufficient on a case-insensitive provider, and `Get-Item` can echo caller casing rather than the
stored directory entry under Windows PowerShell 5.1. Derive the one permitted parent and basename,
compare canonical paths ordinally, enumerate the parent to validate the actual entry, and reject root
or interior links before recursion. Retries should address only transient removal/provider failures;
containment and link-policy violations are decisions, not flaky operations.

The value check matters as much as the safety check. B-204 adds substantial local machinery, but no
suite or result, and every nontrivial branch was demanded by an observed false green or an
adversarially reproduced wrong-tree, link, retry, or diagnostic boundary. A shorter wrapper would
look leaner while silently dropping proven protections. Conversely, the same incident did not
justify sweeping other cleanup sites or old residue: mechanism similarity is not consequence
equivalence, and unowned historical paths are not ours to delete.

## 2026-08-30 — A tested state is not automatically a valuable state

B-202 began with a seemingly tidy repair: make an existing `declined` checker result reachable by
teaching a skill to write its exact marker. Revalidation found that this would turn a fixture into a
product feature without evidence of user harm. No shipped path wrote or taught the marker, its only
caller consequence was a non-failing advisory, and the proposed append-only preference could not be
revoked. A later map deletion could silently reactivate the old decision.

The useful move was subtraction. Remove the dormant branch and its one fixture-only result, preserve
the ordinary missing/current/stale worlds, and use a disposable old-red/new-green oracle for the
compatibility boundary. Do not invert the deleted result into a permanent assertion about hidden
prose: that would retain the same maintenance cost under a different name. Historic decisions and
existing tests are evidence to inspect, not obligations to preserve when their value premise fails.

## 2026-08-30 — Provider-specific evidence should be narrower than a generic third test leg

B-70 correctly rejected another broad CI runner for a Windows/Linux process gap, but its absolute
wording became wrong when the product promised stock macOS Bash 3.2 and neither required runner
could execute it. Historic infrastructure constraints deserve the same premise revalidation as
product decisions. The useful distinction is not “two jobs versus three”; it is whether the added
provider observes a shipped contract that every existing provider literally cannot.

Pay only for that missing fact. Composition already proves one authored installer reaches all three
distributions, and the existing convergence suite exercises its modes and reconciliation policies.
The recurring macOS work therefore needs one committed-dist greenfield smoke under an asserted
`/bin/bash` 3.2, not another three-dist or hook/meta matrix. A frozen-parent failure is valuable once
to prove the new instrument discriminates; retaining that history dependency after the first
observed red/green would turn evidence into recurring archaeology.

Hostile-host runs can also uncover unrelated test truth. The required Windows PowerShell 5.1 run
passed B-198's changed result but failed an older junction cleanup through a headless confirmation
path. Diagnose and preserve that red, file the distinct consequence, and do not either absorb it
into the current product patch or weaken the run until it looks green. Test count, runner count, and
green count are all proxies; the valuable unit is a reachable decision with a trustworthy verdict.

## 2026-08-30 — Link teardown is a provider contract, not ordinary directory cleanup

`Remove-Item -Force` looks non-interactive, yet Windows PowerShell 5.1 prompts when the exact entry
is a populated directory junction; even `-Confirm:$false` reached the same headless null-reference
failure. Use a primitive whose contract matches the object being removed. For this Windows-only
junction boundary, non-recursive `Directory.Delete` unlinks the verified entry without traversing
its target; keep the existing non-recursive symlink operation on POSIX instead of assuming one host
proves the other.

Unlink success alone is not the fixture verdict. First prove the installer left the path as a link,
then prove the link is absent and the outside bytes are unchanged before recursively deleting either
generated root. Capture body and cleanup errors independently because `finally` otherwise replaces
the first failure with the second. A temporary failure placed after normal body assertions and a
second placed after successful teardown demonstrated both causes in one existing result; no new
test was needed.

The census boundary should follow consequence, not syntax. A second `Remove-Item` junction cleanup
in the same file targets an empty directory and passed the exact hostile-host baseline without
leaking state. Record it as exposed, but do not widen the repair until that site reproduces the
failure class or masks a verdict.

## 2026-08-30 — Temporary-path ownership is identity plus disposition

A temporary filename is not safe cleanup authority merely because `mktemp` returned it. Relative
spelling depends on a working directory, whitespace and glob characters change unquoted iteration,
links and case aliases can hide containment, and a later move can end ownership while leaving the
old name available for reuse. Register each allocation before any fallible inspection, resolve the
caller-facing and cleanup-facing value to one physical identity, and represent release explicitly
when ownership transfers. Cleanup should consume only those retained identities, attempt all of
them, and preserve a body failure even when cleanup also fails.

Failure disposition belongs at the caller boundary. An allocator failure while validating a prior
manifest is host failure, not evidence that the manifest is merely malformed; using `if !` or
unguarded `set -e` paths can erase that distinction. Return a distinct internal status, map it
deliberately at each caller, and keep the EXIT trap responsible for every allocation registered
before the failure.

Test economy applies after design lock too. A proposed mutation can become redundant when the exact
permanent result has already failed against the untouched shipped implementation and named the real
consequence. Preserve that old-red evidence and do not rebreak generated output just to satisfy a
ceremonial checklist. The question is whether the oracle discriminated the reachable product
decision, not whether every planned way of making it red was performed.

## 2026-08-30 — Capability absence needs an explicit outcome

An optional-capability probe cannot safely encode “unavailable” as exit 0 plus empty output. The
same shape can mean the script was omitted, stdin was never read, argument quoting was corrupted, or
the child stopped before its decision. Treating all of those as an invariant skip turns transport
failure into reported coverage. Make both terminal states explicit—such as exact `yes` and `no`—and
fail setup for empty, noisy, differently cased, stderr, or nonzero outcomes.

Cross-shell quoting is a transport concern, not product logic. When a supported orchestrator has a
legacy native-argument marshaller, pass a multi-layer script through the child's stdin and keep the
native argument list simple. Reuse an existing raw-stream helper if it already preserves exit,
stdout, and stderr; adding a second helper or a new test result only duplicates machinery. A
controlled negative capability world and a disposable unexpected-output mutation can validate both
branches without growing the permanent suite.

## 2026-08-30 — Decorative telemetry is not worth a new portability contract

An informational count can become the least reliable part of an otherwise successful mutation.
The skill mirror first resolved bare `find` to Windows FIND.EXE, then replaced it with Bash-4-only
recursive globbing; both providers failed only after the useful copy was complete. No caller used
the number to make a decision. Removing the metric from both twins preserved the actionable
completion verdict while deleting PATH, traversal, symlink, newline, zero-match, and shell-version
semantics that existed solely to decorate stdout.

Twin equality is also weaker than correctness. Two implementations can return the same nonzero
exit, empty output, or identically incomplete tree. Strengthen the existing result at the decision
boundary: require exact success, empty stderr, and each generated tree's independent equality with
the canonical source. A disposable equal-failure mutation proved that boundary without adding a
permanent result. Test economy means retaining the smallest oracle that can reject the wrong state,
not preserving every historical observation or growing cardinality whenever an assertion improves.

## 2026-08-30 — Reviewer agreement does not make a fixture fact true

Both independent B-175 reviews said the existing `9.9.9` mutation produced two findings. The first
captured red run returned one: version validation is a single `if`/`elseif` chain, so one input
cannot trigger both branches. The correction was to preserve that observation in the locked record
and construct a second independent finding, not to reinterpret the output or silently rewrite the
evidence. Adversarial review improves a design, but every factual premise still needs execution.

Finding counts belong in human output, not an overlapping process-status namespace. A fixed finite
protocol lets a caller distinguish verified findings from incomplete examination; every unassigned
nonzero must degrade to unknown. The caller should also stay at the checker's abstraction level:
“integrity findings—run the checker” is truthful, while guessing mirror drift and prescribing
`/generate-copilot` is false for syntax, BOM, hook-twin, skill, or version findings.

Hostile evidence can expose valid work outside the current consequence. B-175's changed doctor
matrix passed under native Windows PowerShell 5.1, while a different Copilot-visibility fixture
failed because another nested Bash `-c` argument was mangled. Keep the current verdict intact,
record the distinct test-truth debt as B-207, and do not either widen the product patch or call the
whole host suite green.

## 2026-08-30 — Status capture must be reachable under the caller's fail-fast mode

A binary wrapper can pass every ordinary status test and still leak a child's richer exit code.
B-175 initially ran its Bash child as a simple command and captured `$?` on the next line. Under
`bash -e` or inherited exported `SHELLOPTS`, a nonzero child terminated the wrapper before that next
line, so “capture immediately” was not enough. Put a deliberately fallible child in an `if`
condition, capture `$?` inside the `else`, and only then normalize it; Bash exempts conditional
commands from errexit while leaving their stdout/stderr attached.

Test economy is about discriminating value, not byte immutability. The first design reasonably left
the existing B-149 result unchanged because its planted drift already proved ordinary nonzero-to-1.
Once immutable review found a real `bash -e` escape, adding `-e` to that same Bash invocation became
the smallest permanent oracle: it was red on the rejected candidate and green on the correction,
without another test, result, fixture, invocation, or runtime pass. New evidence should overturn an
earlier no-test decision when it strengthens a reachable decision at zero cardinality cost.

Do not generalise a hostile preference into product work without a changed consequence. PowerShell
7's opt-in native-error preference can terminate through a different mechanism, but the wrapper
still returned its documented `0/1` and retained both child streams in the tested matrix. Expanding
that branch would add complexity without repairing an observed contract failure.

Interpreter-local fail-fast and process-tree strict mode are different contracts. Passing `-e`
directly before one wrapper path tests whether that wrapper can reach the status branches it owns.
Exporting `SHELLOPTS=errexit` also changes every Bash descendant and can expose a much broader set of
manual captures. B-203 repaired three proven unreachable branches in one wrapper; B-208 separately
asks whether supporting inherited strict mode across all shipped scripts creates enough value to
justify a complete census. Do not turn that hostile discovery into piecemeal fixes or an accidental
public promise.

## 2026-08-31 — Re-triage residual obligations, not entry age

`PARTIALLY DONE`, blocked, and old entries are not interchangeable. The first v0.79.1 triage tried
to archive nineteen records by broad category; adversarial review showed that several still carried
an exact grader repair, frozen live batch, field trigger, or decision. The corrected pass named every
remaining obligation and either preserved it or explicitly completed/rejected it with a reopen
trigger. Age and inconvenience are prompts to revalidate a premise, never evidence that it is gone.

A related execution lesson arrived in B-207. Standard `bash -s` reasoning said the placeholder after
`-s` would be `$0`, but the actual Git-for-Windows process launched through `Start-Process` fixed
`$0` to `/usr/bin/bash` and exposed the placeholder as `$1`. The existing result failed 32/1 before
the candidate could be called green. When stdin programs receive ordinary path arguments across a
Windows native-process boundary, observe the real positional contract and normalize from the final
required arguments; do not infer it from a different shell launch shape.

## 2026-08-31 — A capability override is only evidence if its own probe survives the legacy host

B-211's documented `ATL_TEST_PYTHON` escape hatch named a real interpreter, yet native Windows
PowerShell 5.1 removed the nested quotes from `sys.stdout.write("ok")` before Python saw the `-c`
program. The helper then called the interpreter unavailable and converted a supported capability
into an invariant skip. An override does not prevent false skips merely because the named file
exists; its execution probe must be exercised through every host contract that relies on it.

The smallest correction preserved the JSON parse and exact-output oracle while removing the fragile
quote boundary: `chr(111)+chr(107)` is ASCII-only and still emits exactly `ok`. A scratch `ox`
mutation proved the comparison red. Two maintainer-only PowerShell 7 tests use the old quoted shape,
but no observation or native-5.1 contract gives that exposure a current consequence. Name and bound
same-class exposure instead of widening a verified supported-host fix into an opportunistic sweep.

## 2026-08-31 — A dated host version is not a blanket certificate

B-43 had live evidence, an evidence table, and several persisted canaries, yet still called an
unobserved chain guaranteed. The Copilot CLI date beside prompt and post-tool observations migrated
through generic README wording into apparent certification of `agentStop`; at the same time, the
real 2026-06-25 VS Code guard denial was flattened into both “the full lifecycle is uncertified” and
a current guarantee. Consistent repetition can preserve an unsupported inference as effectively as
drift preserves a stale sentence.

Record host evidence at the capability boundary that was actually observed. A direct fixture,
registration, vendor document, fired marker, delivered payload, and multi-event chain are different
facts. An observed final delivery leg does not prove an unobserved producer leg. Unknown host
versions stay unknown, and inability to launch or observe a canary is not evidence that the target
artifact is defective.

Persisting an unrun kit is not execution evidence. A certifying canary needs a known-good delivery
control, a no-hook control under the same model/tool exposure that invalidates the instrument if a
token arrives by another route, and a separate firing marker. “The token is only in the
environment” is insufficient when the model has shell tools and can read that environment. Keep
such historical kits for provenance, but do not promote their echo or null into a claim until the
instrument can distinguish firing, delivery, leakage, and inability to examine.

Calendar recertification was the wrong repair. Re-run only before strengthening a claim or after
contrary evidence or a host-facing mechanism change when the result could change a decision. An
explicit unverified row is often the truthful finished state; recurring provider spend and an
unexecuted checklist add no value by themselves.

## 2026-08-31 — A constructible hostile world is not evidence that hardening it is worth shipping

B-174 began as three small parser asymmetries. Once the candidate was made honest across decoded
values, provider fallback, recursive registration positions, shell framing, ordinal comparison,
control characters, and legacy PowerShell encoding, it occupied eight artifacts and `+1163/-222`
lines. The hostile inputs were real and the first implementation was wrong in several observable
ways, but neither fact established consumer harm or selected one synthetic edge as the valuable
boundary. Preserving the experiment and reverting it was the higher-quality delivery.

The same stop-loss applies to evaluations. B-129's two paid attempts stayed void, then the unmerged
probe drifted materially behind the product. Honest void classification prevented a false result;
it did not make a third run valuable. B-72 and B-112 likewise retained the general instrument rules
while retiring nondiscriminating historical probes. Before expanding a gate or live experiment,
separate four questions: can the hostile/success world be constructed; does the instrument detect
it; has the resulting defect harmed a current decision or consumer; and would the smallest repair
change that outcome enough to justify its permanent cost. Passing the first two is necessary
measurement evidence, not a product-value verdict.

## 2026-08-31 — A capability-claim repair must search by meaning across every assurance surface

The first B-43 candidate corrected the enforcement matrix, hook commentary, README hook tables,
canary records, and presentation, yet independent review still found the same unsupported assurance
in stack update prose, review guides, the always-loaded carrier, security snippets, and AGENTS
mirrors. Source/dist fidelity faithfully preserved the wrong meaning; an artifact list derived from
the first reported sentence was not a complete claim inventory.

Scope review for a host-evidence correction must search every assurance surface for the underlying
inference: file arrival versus consumption, registration versus firing, and one observed event
versus a whole lifecycle. Once concrete historical spellings are found, narrow exact-pattern gates
can prevent their return and prove both match and rejection directions. That does not justify a
general prose classifier: semantic completeness still belongs to an independent review of the
frozen claim boundary.

## 2026-08-31 — Executable comments and diagnostics are assurance surfaces too

The second B-43 review found the same registration-to-consumption inference after the narrative
carrier sweep was already clean. It lived in hook headers and dispatch comments, a direct-fixture
heading, two null-result diagnoses, maintenance-command instructions, and generated architecture
diagrams. These artifacts do not become less persuasive because they sit beside executable code or
inside a generated page; composition can preserve a false assurance perfectly.

A claim-boundary inventory must include what a consumer reads while operating and diagnosing the
feature, not only canonical documentation. Direct invocation proves script I/O, a generated arrow
can show a registered conditional path, and a visible marker can prove one successful run. None
turns absence into a cause or registration into delivery. Protect recovered concrete spellings with
narrow controls, but leave semantic completeness to scope review rather than building a prose
classifier.

## 2026-09-01 — Reconcile causal truth, not a named artifact inventory

B-136's old Agentic Workflow Step 6 permitted completion after flagging four named drift classes.
The replacement makes the actor that changed repository truth reconcile the actual effects in the
same task while respecting each artifact's ownership, evidence, history, and security rules. An
affected artifact the actor cannot read or safely update remains a blocker rather than becoming an
unexamined `none` result, and uncertain human intent remains uninferred.

A static artifact table is not the durability mechanism: inventories rot and make omitted artifacts
look unaffected. The durable rule is causal—update writable canonical truth that this task made
stale, regenerate derivatives from source, and preserve artifact-specific boundaries. The exact
470-byte source block, its seven-byte reduction, composition, and structural gates prove delivery
only. Behavioral compliance remains **UNMEASURED**.
