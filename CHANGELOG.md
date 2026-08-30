# ai-tech-lead — Changelog

> **This is the *maintainer's* changelog — the engineering log for the authoring repo.** It may
> reference tracking ids, decisions (`WSD-nnn`), and internal tooling. The **consumer-facing**
> release notes are the ones that ship inside each dist (`dist/*/CHANGELOG.md`, authored at
> `src/stacks/*/files/CHANGELOG.md`); those are written in the consumer's voice and are gated by
> `no-meta-leak` [#6]. Do not blur the two.
>
> This file starts at the merge (v0.26.0). Earlier framework history — everything before
> `ai-tech-lead-dotnet` and `ai-tech-lead-angular` combined into this repo — lives in the two
> preserved legacy changelogs: [`meta/changelogs/legacy-dotnet.md`](meta/changelogs/legacy-dotnet.md)
> and [`meta/changelogs/legacy-angular.md`](meta/changelogs/legacy-angular.md).

## 0.78.4 — Unreleased

**The skill-mirror sync no longer depends on Bash 4 for a decorative count.** B-205 removes the
recursive count from both script twins and emits one exact count-free completion verdict. The
mirror operation, missing-source behavior, and Git-root fallback are unchanged; consumers that
parse the old count-bearing stdout must match the new documented line.

No permanent result was added. The existing recursive twin result now requires each implementation
to exit 0, keep stderr empty, emit exact stdout, and independently reproduce the canonical source
paths and SHA-256 bytes. It first failed 8/2 against the unchanged count-bearing scripts, later
rejected an equal-exit-47 mutation of both twins at 8/2, and returned to 10/0/0 after exact byte
restoration under PowerShell 7 and native Windows PowerShell 5.1; the composed dotnet copy passed
the same two host runs. Both composers converged at 173/169/183 files, both validator twins passed
all three distributions, YAML parsed, and the mutation-tested CI topology/watch gates stayed green.
Exact frozen-red/current-green stock macOS `/bin/bash` 3.2 evidence and final candidate CI remain
required before completion or release. Two independent read-only implementation reviews approved
the stable local diff with no findings while explicitly withholding completion approval until those
provider runs are observed.

Independent immutable review approved exact candidate
`49bcbe9ecc39d987045e98d7b8d68c8709b1a372`, tree
`ae45d5129e0599f5db0444ee6a5fde9ff6bab0da`, from design parent `f766e87`. It reconfirmed the exact
24-file scope, functional blob identity, source/generated carrier parity, and clean worktree. Native
macOS evidence, frozen-arm retirement, and final candidate CI remain unclaimed.

**The Bash installer now treats each temporary pathname as exact owned state.** B-197 replaces its
space-delimited cleanup scalar with one Bash-3.2-safe counted indexed registry shared by all five
allocation sites. Each entry is registered before inspection, canonicalized to physical identity,
removed as one quoted argument, and explicitly released when a successful settings move ends
ownership. Cleanup attempts every retained entry, reports its own failures without masking an
earlier body failure, and returns exit 3 when target work succeeded but cleanup did not. A temp
parent physically inside the selected target now refuses with exit 3 and no persistent target
mutation instead of making the installer's own files trigger a false dirty-tree exit 4.

One Bash-only UpdateDelivery result covers the two observed consequences without a new suite or
PowerShell twin. Before product editing it failed 50/1 and named both exit-0 deletion of an unrelated
split-prefix sentinel plus 17 leaked temps and the target-contained false refusal; the candidate
passed 51/0/0 under PowerShell 7 and native Windows PowerShell 5.1/CP437. Disposable probes covered
allocator, link/case identity, cleanup-status, all-attempted, and released-path boundaries. The
planned post-green unquoted-element mutation was intentionally omitted because the exact old-red run
already provided stronger discrimination evidence; repeating an expected nonzero would test no new
decision.

Both composers converged at 173/169/183 files, source and all three distributed installers share
SHA-256 `26e97642f1326272ad59d12072445305cface41381de0967879a04e2aeac031d`, and
InstallerConvergence 12/0/0 plus ScriptTwinParity 10/0/0 passed. Native Linux, stock macOS Bash 3.2,
and first candidate CI remain required before completion or release.

Independent read-only immutable review approved exact candidate
`66bc95e5eafdf977dac59aea6a5f3e2c159b2d4e`, tree
`eb00500eec59b3ab5313b120926583845d072245`, from design parent `fe193fd`. It found no code, test,
source/dist-parity, or record defect, while explicitly leaving native Linux, stock macOS Bash 3.2,
and candidate CI unclaimed.

**Windows PowerShell 5.1 no longer turns broken Bash capability-probe transport into false test
coverage.** B-201 sends the three existing session-start JSON probes to Bash through `-s` stdin
using the harness's raw process path. Each probe now emits exact `yes` or `no`; nonzero exit, stderr,
empty/unexpected stdout, and non-exact sentinels fail test setup instead of becoming an invariant
“no encoder” skip. No product hook, harness helper, suite, result, or CI leg was added.

The unchanged Windows PowerShell 5.1 suites moved from syntax-error false skips at 18/0/1, 12/0/1,
and 9/0/1 to Hazard 19/0/0, Wiki 14/0/0, and FrameworkRules 10/0/0; PowerShell 7 and composed dotnet
passed the same counts. A probe-local absent-capability world retained the honest named skips, and an
unexpected-output mutation made all three files fail setup before exact restoration. Both composers,
source/generated hash and BOM parity, all three distribution validators, and independent
implementation review were clean. The original ≥v0.78.5 target is superseded because including this
zero-growth test-truth repair improves the still-unreleased v0.78.4 evidence without changing
product behavior. First exact-candidate Windows/Linux CI remains required.

**The shipped Bash installer no longer requires Bash 4 for manifest validation.** B-198 replaces
the two associative arrays and two lowercase expansions introduced in v0.76 with one guarded,
C-locale `awk` preprocessing pass per validator. ASCII case-variant duplicate paths remain a
pre-mutation error, normalized validator output and PowerShell behavior are unchanged, and all
three distributions still come from the one authored script.

The existing forged-manifest convergence result now uses a case-variant duplicate and requires its
exact diagnostic; no suite or result was added. WSD-061 narrowly supersedes B-70's absolute
“third CI leg” wording with one required, non-matrix `macos-portability` job because neither existing
runner can execute the supported stock macOS `/bin/bash` 3.2 provider. Its first run must show the
frozen old installer red/no-mutation and the candidate green; that historical arm is then removed
and the stable candidate must pass macOS plus the normal Windows/Linux CI before completion or
release. Local newer-Bash evidence is not reported as macOS or Bash 3.2 proof.

Independent immutable review approved exact candidate
`f71473f4830e8696e6b220ffb7e07eebe82e01a3` from design parent `0062e990` and tree
`9d543e1e50c03ddfb736a41b7534760771024dd9`. In a detached no-hardlinks clone, the reviewer
reconfirmed exact 20-file scope and source/dist hashes, replayed ownership and retirement case/glob
collisions plus a forced `awk` failure with no target mutation, and made the strengthened existing
result fail 11/1 by suppressing only the Bash ownership duplicate decision before exact restoration
to 12/0. Focused topology/watch suites, YAML/BOM/AST/Bash syntax, and six record/release gates were
green. Native macOS/Bash 3.2, transitional CI, removal of the frozen-history arm, and final
Windows/Linux/macOS CI remain pending, so this is candidate approval rather than completion or
release approval.

**Installer convergence teardown no longer masks its reparse-retirement verdict on Windows
PowerShell 5.1.** B-206 keeps the existing six cases/twelve results but makes that one fixture
lifecycle explicit: body and cleanup failures are retained separately, the post-installer link must
still be a link, Windows unlinks the verified junction non-recursively, POSIX retains its symlink
unlink, and exact link/root absence plus unchanged outside bytes gate success before recursion. No
product, distribution, suite, result, retry policy, or shared cleanup framework changed.

The native 5.1/CP437 file moved from the preserved 10/2 cleanup failure to 12/0; PowerShell 7 also
passed 12/0 and both left no current fixture entry. A temporary post-body/post-cleanup mutation made
both twin results fail with both unique causes before exact-byte restoration returned 12/0. The only
other generated-junction cleanup targets an empty outside directory and passed the old and current
runs, so it was not widened without observed consequence.

Independent immutable review approved exact candidate
`aa374fdd7c17f641021adc58b1db00609fe1efb1`, tree
`e573c69d3e30c4e2f94493f4367c7d5cd2ca6fd8`, from sole design parent `bf1bd247`. In a detached
no-hardlinks clone, native Windows PowerShell 5.1/CP437 reproduced the parent at 10/2 with four
residues and the candidate at 12/0 with none; PowerShell 7/Git Bash also passed 12/0 without residue.
Dual-failure mutation retained both causes, while non-link, ambiguity, access, and outside-byte
hostile worlds all blocked recursion and retained both roots. Exact scope/hash, cardinality,
BOM/AST, and record gates were clean. Native POSIX/Linux and CI remain unobserved, so B-206 stays an
implemented candidate rather than complete or releaseable.

**Warehouse maps no longer have a hidden declined state.** B-202 revalidates and supersedes the
explicit-decline clause of WSD-033: no shipped workflow wrote or taught the exact protected
`LEARNINGS.md` heading, its append-only preference had no revocation state, and its only permanent
result constructed otherwise unreachable product state. Both checker twins now classify every
applicable warehouse without `docs/warehouse-map.md` as `missing`/1, the four agent-surface skill
copies describe only missing/stale/current, and the fixture-only declined result is deleted rather
than replaced. The map remains optional; docs-sync remains advisory; and warehouse writes still
require a current map or equivalent live table/key/relationship/load-order evidence.

This intentionally changes one undocumented compatibility edge: a manually authored
`## Declined artifact: warehouse-map` heading is preserved but inert, so a direct checker caller
sees `missing`/1 instead of `declined`/0 and custom CI that treated the old exit 0 as authoritative
may need adjustment. A disposable old-red/new-green twin oracle proved that boundary without adding
another permanent prose-search test. Both composers emitted byte-identical distributions, both
validator twins passed all three modes, and the remaining three-result checker suite passed under
PowerShell 7, Windows PowerShell 5.1, and Git Bash. First Windows/Linux candidate CI still gates
completion and release.

Independent immutable review approved exact candidate
`fb689c2daec4c54ffb68a5e1769eefd061d96b85` from contract `235055c` and tree
`7b54539fdaf6facfe4cc1bb45ddbfaf870379659`. In a no-hardlinks isolated clone, the reviewer
reproduced old `declined`/0 versus candidate `missing`/1 on both checker twins with byte-identical
`LEARNINGS.md`, then made an exit-1-to-0 mutation fail the intended missing world 2/1 before restoring
3/0. PowerShell 7 and Windows PowerShell 5.1 at code page 437 exercised Git Bash; all source,
mirror, and generated hashes agreed; both composers reproduced all three distributions; and both
validator twins plus the four record gates passed. Native Linux and first candidate CI remain
unavailable, so B-202 stays open.

**Root-installer maintainer teardown now fails honestly and verifies absence.** B-204 replaces twelve
non-terminating recursive fixture cleanups in the existing `RootInstallerWarehouse` suite with one
exactly allowlisted, reparse-safe remover and a lifecycle wrapper that preserves product-body and
cleanup failures independently. Transient handle contention gets six bounded attempts (1.5 seconds
total backoff); a surviving fixture is terminal, and simultaneous body/cleanup failures expose both
causes. The existing mutation callbacks now reject cleanup-only reds by requiring their intended
warehouse assertion and sentinel. No suite or test result was added.

Native Windows PowerShell 5.1 execution also exposed a pre-existing false-red premise in the two
solution-free assertions: recursive `Get-ChildItem -Include` counted every file on that host. Only
those expressions now filter enumerated files by extension, retaining the assertions and their
cardinality. Two independent adversarial reviews approved keeping the larger local remover after
hostile path, link, lock, partial-deletion, aggregation, and post-inspection probes under PowerShell
7 and 5.1. The unchanged 12-result file passed 12/0 under both hosts and concurrently; the standard
maintainer runner passed all 31 files with zero failures and no new residue. Native-Linux dangling-
link evidence and first Windows/Linux candidate CI still gate completion; this is not release
approval.

Independent immutable review approved exact candidate
`2e72fecd088c85cf0a7c98803aa76d64513b28fd` from contract `617dd4f`. In a detached no-hardlinks
clone, the reviewer reproduced the old locked-file false green, then passed the candidate's exact
retry cadence, containment, case-alias, junction, partial-deletion, post-inspection, dual-failure,
PATH-restoration, and Windows PowerShell oracle probes under PowerShell 7 and 5.1. A sentinel
mutation made the outer anti-vacuity result red before byte-identical restoration; focused
PowerShell, Windows PowerShell, and Git Bash runs returned 2/0. Blob hash, BOM/AST, result cardinality,
scope, RCA census, record gates, and residue were independently reconfirmed. Native Linux and first
candidate CI remain unavailable, so B-204 stays open.

**Docs-sync now distinguishes verified warehouse-map debt from a checker it could not run.** B-203
captures the `warehouse-map-check` status once in both wrapper twins, preserves the existing
missing/stale note only for exit 1, and emits an explicit unable-to-verify advisory for every other
observed nonzero status. The checker still runs once, its stderr remains visible, the warehouse
branch remains non-failing, and the final docs-sync success policy is unchanged.

One existing ScriptTwinParity result now reaches status 0, 1, 2, and an unexpected negative/nonzero
pair without adding a suite or result. Against the unchanged wrappers it passed 9/10 and named both
unable worlds for both twins; the minimal product branches made PowerShell 7 pass 10/10. A native
Windows PowerShell 5.1 run then caught a false test premise: its `RunArg` renderer repeats a child
stderr token inside ErrorRecord metadata. Three adversarial reviews approved counting exactly one
physical diagnostic line ending in the sentinel instead. The amended result passes 10/10 under
PowerShell 7 and Windows PowerShell 5.1 at code page 437. A separate direct, no-redirection 5.1
probe preserved the child diagnostic, emitted only the new wrapper note, reached the final success
line, and exited 0. The exact candidate's first Windows/Linux CI remains mandatory before
completion or release.

Independent immutable review approved exact candidate
`4e847b422f0267f65c474bb2091301905f956650` from contract `76cde44`. In an isolated no-hardlinks
clone, candidate tests over the exact contract wrapper blobs reproduced 9/10 with all eight
wrong-status symptoms named; restoring the candidate returned source and all three composed results
to 10/0. The reviewer also reproduced the Windows PowerShell renderer boundary and direct
unredirected behavior, then reconfirmed byte parity, BOM/AST integrity, Bash syntax, unchanged test
cardinality, both composers and validators, and the focused maintainer gates. Native Linux,
Bash 3.2, and first candidate CI remain pending.

PowerShell and login-shell Bash composition produced the same 525-file aggregate (173/169/183).
Both validator twins passed all three distributions, and all 12 changed authored/composed carrier
pairs are byte-identical. The dotnet, Angular, and monorepo standard hook runners each passed 20
files with zero failures, including their composed ScriptTwinParity 10/0 and warehouse checker 4/0.
The maintainer runner passed 31 files with zero failures, including Composer 16/0,
BacklogHygiene 10/0, DocTruth 13/0, DocClaims 8/0, and release-head 8/0. BOM, PowerShell AST, and Bash
syntax checks are clean. These remain local Windows/Git Bash results rather than the required native
CI evidence.

**Bash session start now preserves time-sensitive advisory rows across supported text shapes.**
B-195 gives the security and hazard scans separate initialized EOF state, so a final non-newline
record is consumed rather than silently dropped. The hazard reader also strips one CR in its parsing
stream, accepts the same trailing horizontal whitespace on its exact heading as the deterministic
hazard checker, and requires the PowerShell-equivalent five pipe delimiters before extracting cells.
PowerShell behavior, advisory thresholds, status/date semantics, messages, consumer bytes, and exit
0 remain unchanged. The separately found GNU-only macOS cutoff provider is recorded as B-200 rather
than hidden inside this candidate without native BSD/macOS evidence.

The existing security parity matrix retains its no-open and future-open controls and adds one result
for the distinct overdue-EOF severity branch; the existing hazard twin result now aggregates EOF,
CRLF, heading-whitespace, and malformed-EOF worlds, so no hazard result or suite was added. Against
the unchanged hook, security was 6/1 and hazard 18/1 with all three valid hazard misses named. An
EOF/CR/heading intermediate made security 7/0 and left hazard 18/1 only because the newly reachable
malformed row produced a Bash-only warning; adding the frame guard made TwinParity 7/0/1 and
SessionStartHazard 19/0/0 under PowerShell 7/Git Bash. Native Windows PowerShell 5.1 also passed the
modified branches. Independent implementation and oracle reviews approved the source diff. The
exact candidate's first Windows/Linux CI remains mandatory before completion or release.

Independent immutable review approved exact candidate
`f84bc093ba6a7d9e68a4f02d29d1f037e28df7a2`. In an isolated clone, the candidate tests over its
parent hook reproduced TwinParity 6/1/1 and hazard 18/1, then restored to source 7/0/1 and 19/0/0
and composed-dotnet 14/0 and 19/0 on the exact candidate. The review also reconfirmed byte parity,
BOM/AST integrity, both validator twins, and the B-200/B-201 boundaries. Its PowerShell 7, Windows
PowerShell 5.1, and Git Bash evidence is not native Linux, BSD/macOS, or Bash 3.2 evidence.

PowerShell and Bash composition produced the same 525-file aggregate. All three distributions
passed TwinParity (14/0 dotnet, 9/0/1 angular, 14/0 monorepo), SessionStartHazard 19/0, and both
173/169/183-file validators; the full dotnet hook battery passed with zero failures across 20 files.
Composer 16/0, BacklogHygiene 10/0, DocTruth 13/0, DocClaims 8/0, and release-head 8/0 also passed.
Source and every composed hook/test copy are byte-identical. These are local Windows/Git Bash
results, not the still-required first native Windows/Linux candidate CI.

**Bash updates now preserve durable disabled-skill intent in protected ledgers written by Windows
PowerShell.** B-196 removes exactly one standard UTF-8 BOM only at byte zero of the parsing stream,
then uses one anchored capture to emit the validated skill name without admitted horizontal
whitespace or a CRLF carriage return. The consumer's `LEARNINGS.md` remains byte-identical;
doubled, partial, misplaced, or leading-space BOMs do not expand the heading grammar, and a selected
file that cannot be parsed fails before target mutation. PowerShell installer behavior is
unchanged.

Adversarial review rejected the proposed extra test subject and instead strengthened an existing
UpdateDelivery fixture with an independently specified 85-byte BOM + HT + CRLF oracle. The suite
therefore remains 50 results. Against the unchanged Bash reader it passed 49 and failed only the
existing skill-reconciliation result; the implementation passes 50/0 under PowerShell 7 and native
Windows PowerShell 5.1 with code page 437. The BOM-less InstallerConvergence control passes 12/0,
InstallerContract 13/0, and Composer 16/0; both validator twins pass all 173/169/183-file
distributions, and both composers produce the same 525-file aggregate. Direct probes preserve
BOM-less input, accept only one byte-zero BOM, reject misplaced/malformed variants, and propagate a
selected-file read failure. In separate exact-`49420ad` copies, removing only BOM stripping and
restoring only prefix-based name extraction each made that same Bash result fail at 49/1 while all
PowerShell results stayed green. The exact candidate's first Windows/Linux CI run remains mandatory
before completion or release.

**The hazard completion oracle now refuses incomplete discovery instead of reporting framework
completion.** B-193 explicitly supersedes the B-77-era skip behavior after v0.78.0 made this
formerly optional drift check part of a mandatory completion gate. A missing context file, a
pending marker, a missing or duplicate exact hazard heading, the exact bootstrap placeholder, and
an empty or arbitrary-prose section now fail. A completed section contains real rows or the exact
no-notable sentinel, never both.

The path grammar now preserves every backticked token without reusing untrusted text as a Bash
pattern, treats balanced bracket classes as ancillary wildcard syntax, and consumes a final line
with no newline in both Bash loops. Its bounded lexical transform repeatedly peels terminal
comma/semicolon and matching `()`/`""`/`''` frames while detaching at most one sentence-final
`.`/`:` for display. Safety retains that suffix, unmatched wrappers remain literal data, and exact
`.`/`..` segments or drive prefixes cannot disappear during normalization. Legitimate dot-named
paths such as `.github/...` and `.cache/...` remain valid.

The red-first 67-case matrix passed 40 and failed 27 against the unchanged v0.78.3 checkers. A first
green candidate was still blocked by fresh reviewers who reproduced bare-dot, framed traversal,
exterior-punctuation, and grouped-positive-oracle false greens; those findings amended both parser
and test design before the current candidate was frozen. The current candidate passes all 67 cases
locally while proving 63 leaf and 14 wrapper subjects per twin (154 executions total) under
PowerShell 7/Git Bash and under native Windows PowerShell 5.1 with code page 437. Separate
PowerShell and Bash hostile mutations each made 12 discriminating cases fail; a later one-token skip
mutation made the strengthened suite 66/67; each byte-identical restore returned to 67/67. All three
composed distributions pass the same suite and their validators locally. Its first Windows/Linux
candidate CI run remains mandatory, so B-193 remains open.

**Update and brownfield installation now distinguish an ordinary non-Git target from Git state that
cannot be examined safely.** B-194 fixes the supported native Windows PowerShell 5.1 path, where
expected non-repository stderr previously became a terminating `NativeCommandError`. Both installer
twins now reject ambient Git routing—including Windows Git Bash casing variants—repository evidence
that Git cannot classify, unexpected worktree output, and unreadable status before target mutation;
a plain target with no repository evidence still proceeds when Git is absent or broken. Worktree
status disables optional Git locks so a dirty-tree refusal preserves Git administrative bytes as
well as project files.

Exactly three grouped UpdateDelivery results exercise 15 Windows installer children without
duplicating the existing clean/dirty controls. Against the unchanged installer the revised 50-case
suite was 48/2. A fresh review then made candidate `6818a4a` fail 49/1 by reproducing a lowercase
Git-for-Windows routing bypass; the corrected candidate passed 50/0 under PowerShell 7 and native
Windows PowerShell 5.1/CP437 with Bash observed. InstallerConvergence passed 12/0,
InstallerContract 13/0, and RootInstallerWarehouse 12/0; both composers produced identical
525-file trees and all three validators passed. Native Windows/Linux candidate CI remains required,
so B-194 remains open.

## 0.78.3 — 2026-08-27

**The hazard oracle now enforces the completion contract that v0.78.0 put in front of it.** B-186
requires every real hazard row to contain a literal, resolving, repository-root-relative path.
Pure prose, symbols, URLs, and globs remain valid ancillary text but cannot supply that evidence; a
bare filename resolves only at the repository root, and absolute/traversal paths are rejected.
Status values are case-sensitive complete tokens. A reviewed-not-hazard token must contain a
calendar-valid ISO date identical to the `Reviewed` column.

The old 27/27 suite encoded the false behavior as green. Against the unchanged v0.78.2 oracle, the
revised 38-case matrix passed 23 and failed 15, including the full `docs-sync-check` wrapper accepting
a pure-prose row. After the twin fix, authored and all three composed suites pass 38/38; both
PowerShell 7 and Windows PowerShell 5.1 pass under code page 437 with Bash exercised alongside them.
A case-sensitivity weakening in the PowerShell twin made the suite exit 1, while bypassing Bash path
existence made it exit 5; both scratch copies restored byte-identically. The stricter calendar case
also closed a year-zero divergence where Bash passed a date that .NET correctly rejected.

## 0.78.2 — 2026-08-27

**The mandatory completion gate is now executable on the documented Windows-PowerShell-5.1-only
host.** B-187 adds a separately labelled `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/docs-sync-check.ps1` invocation to the seven direct bootstrap, rebootstrap, and
generate-copilot completion carriers. PowerShell 7 and bash remain distinct choices, `/adopt`
continues to consume its one Phase-7 bootstrap gate, and the exit-0 plus exact-final-line completion
contract is unchanged.

The prior finite claim test required only the two script-path substrings, so one `pwsh` example could
satisfy the PowerShell path check without exposing every supported host. The strengthened check
extracts the actual completion section in every composed distribution and requires three exact
label/command pairs plus the result contract. It failed on v0.78.1 at 7/1 for the missing 5.1 label,
then passed 8/0. Removing the 5.1, PowerShell 7, or bash invocation independently made the suite exit
1 in isolated scratch dists, and swapping the two PowerShell commands beneath the wrong labels was
also rejected. A consumer-shaped dotnet install reached the exact final success line with exit 0
under both PowerShell 7 and Windows PowerShell 5.1 with `pwsh` absent from `PATH`.

## 0.78.1 — 2026-08-27

**Hotfix: updates no longer erase the consumer's append-only architecture-decision history.**
B-185 reclassifies the exact canonical `docs/architecture-decisions.md` path as
consumer-owned/protected and copy-if-absent in both installer twins. Update now preserves its bytes;
brownfield installation keeps it live for the v0.78.0 in-place mature-document screen; greenfield
still receives the seed. All three generated ownership manifests carry the corrected class.

The regression was observed before the fix on both twins: `UpdateDelivery.Tests.ps1` failed 4 cases
covering update replacement and brownfield relocation, then passed 47/47 with exact bytes, operation
plans, archive absence, and adoption-marker state asserted. `Composer.Tests.ps1` passes 16/16 with
the canonical file present in its fixture and protected in both generated manifests. v0.78.0 cannot
reconstruct decisions it already overwrote; affected consumers must restore them from version
control or another backup.

## 0.78.0 — 2026-08-27

**Onboarding now preserves reviewed project knowledge and cannot claim completion over red generated
artifacts.** Bootstrap, rebootstrap, adopt, and Copilot/AGENTS regeneration bind their completion
claim to the existing deterministic docs-sync gate. Hazard output requires bare accepted status
tokens and resolving repository paths. A current installed dotnet bootstrap executed programmatically
with Sol passed the first post-generation gate and an independent rerun; the carrier result is
deliberately limited to final artifacts and does not stand in for Claude/Copilot hook evidence.

Debt workflows now preserve a compact dismissed-proposal registry and suppress a matching claim
until materially changed evidence is named. Mature architecture/ADR corpora are provenance-screened
in place: clean files keep their bytes, paths, and relative links; unsafe material is quarantined;
competing indexes remain a human authority choice. Bootstrap/rebootstrap no longer turn finite debt
into Boy Scout guidance. Shared skill discovery excludes framework-owned installation machinery and
accepts mixed paths only when consumer-authored evidence is corroborated outside framework-owned
paths. The exact answer-only question `Why is this tech debt?` no longer triggers cleanup routing.

Three full repeatability trials confirmed high discovery variance, but all hit a 60-minute ceiling
and only one generated artifact set was green. Default three-run bootstrap and a `3/3` truth vote
were therefore rejected in favor of the smaller controls above. Retained focused fixtures passed
three fresh runs each for dismissal reopening, skill ownership, and mature-document filesystem
preservation. Installer collision recovery protects a pre-existing `docs/ARCHITECTURE.md`, and the
Bash skill-sync script no longer resolves Windows `find.exe` accidentally. Release bookkeeping now
allocates automatic post-ship-review IDs across both open and completed backlog history.

The full installed-hook gate exposed the same non-login Git Bash PATH collision in Boy Scout,
hazard, and wiki checks: Windows `sort.exe`/`find.exe` could erase candidate streams or reject a
clean index. Those scripts now select Git's POSIX tools explicitly. The gate also exposed that
Git Bash `realpath` can successfully render an outside path as `../../...`; both audit twins now
record the constant redaction sentinel for every path outside the repository, including existing
paths, and retain only contained repository-relative paths.

## 0.77.0 — 2026-08-24

**Recovery increment 5 restores warehouse-only installation after making the selected lifecycle
solution-free.** Root installers again route repositories with at least two independent shared
warehouse signal categories to the dotnet delivery profile; Angular plus warehouse evidence selects
monorepo so neither profile is discarded. `/bootstrap` now selects evidenced
.NET, Angular, and warehouse-SQL profiles from the Git root, dispatches only applicable analysis
passes, and records exact build, test, format, lint, migration/deploy, and data-validation commands
under `Conventions > Verification Commands`; an unsupported category is `not available`, not an
invented distribution default. Migration/deploy entries are inventory, not execution authority:
they remain manual/CI-only unless the exact command is a non-mutating validation/dry-run or the
developer authorizes a known target. `/rebootstrap` recomputes the same profile, command, and
execution-policy inventory. `/adopt` remains the brownfield archive/merge workflow and carries the
selected profiles into its Phase-7 `/bootstrap` run. It now protects every live path in
`framework-ownership.json` from re-archival and retains the adoption marker until merge/custom-asset
work is complete, deleting it only immediately before that embedded bootstrap.

Feature, fix, refactor, review, test, and debt carriers, route-prompt rails, verification-bearing
skills, greenfield defaults, CI guidance, READMEs, architecture views, and generated AGENTS mirrors
now use the same repository-evidence boundary. Defaults no longer demand one test per public member
or introduce a new harness as incidental verification: new suites are explicit, agreed work and
tests target the smallest consequential risk set. The doctor requires .NET/Angular tooling only
when corresponding application markers exist, including Angular package/Nx evidence, so a
warehouse-only dotnet install reports the application toolchain and app canary as not applicable.
Its marker walk is bounded, excludes generated/dependency trees, and reports `CANT-VERIFY` rather
than inferring absence when enumeration or marker reads fail. A C# project, not a solution
container by itself, is .NET application evidence; SSDT `.sln` + `.sqlproj` repositories remain on
the warehouse-only path through bootstrap, doctor, and post-write canaries. Angular package/Nx
evidence, including `angular.json` itself, is structurally parsed from supported workspace,
dependency, plugin, executor, and generator fields, so malformed manifests and property-shaped prose
cannot activate the profile. Hook registration JSON
is likewise validated before its apparent commands are trusted. The Jenkins reference is a
self-contained, framework-only reference shape and tells consumers to add a code-gate stage
only when bootstrap recorded real commands.

Framework-shipped skills now remain byte-stable as an applicability-gated delivery-profile
superset. Bootstrap advertises only evidenced tasks and adds distinct consumer-owned discovered
skills where needed; it no longer deletes, rewrites, or appends repository-specific exemplars to
shipped recipes merely because a profile is absent or its implementation differs.

The test change is deliberately smaller than the behavior surface: the two obsolete warehouse-
refusal cases became real greenfield/brownfield lifecycle installs, and those existing cases inspect
a finite set of installed handoff carriers. The warehouse/SSDT doctor scenarios were folded into
the existing toolchain matrix rather than added as another test. A redundant protected-sync arm that
only replayed already-covered states was removed, saving 16 child doctor launches; deep warehouse,
generated-marker, cross-template, malformed-registration, structural-package, and package-string
worlds were added inside existing matrices. Route parity now compares exact normalized rail content,
and two post-write routing cases were consolidated while adding the SSDT no-build boundary. The
shared warehouse regex table now stays inside the .NET/POSIX-ERE intersection, artifact read
failures are explicit instead of false absence, and a test of PowerShell's own null semantics was
removed because it could not catch a framework regression.
The first release CI run exposed two more test-only couplings in that matrix: stack-canary parity
compared the entire report footer, including unrelated host-dependent OK totals, and a mutation-only
parser probe depended on an obsolete control-flow shape. Canary parity now compares only the named
stack-canary contract. The mutation probe was removed because the adjacent black-box cases already
prove both outcomes: a working interpreter exposed only as `python` is accepted, while a
name-resolving Microsoft Store stub is rejected.
That correction exposed a real Bash classifier defect behind the earlier assertion failure:
`nocaseglob` does not affect literal `package.json`/`angular.json` paths, so the Bash doctor missed
uppercase application markers on case-sensitive filesystems. It now enumerates directory entries
once and applies the existing case-insensitive exact-name filter to the resulting basenames.
This corrects B-115's premature v0.51.0 closure: that release proved selection/install only; it did
not prove the downstream lifecycle.

## 0.76.0 — 2026-08-23

**Recovery increment 4 makes updates convergent, inspectable, and downgrade-safe.** Both installer
twins validate incoming/previous ownership metadata and a cumulative framework-authored retirement
ledger before mutation, then print deterministic create/replace/preserve/archive/delete plans.
`-WhatIf` / `--dry-run` returns after planning with a byte-stable target. An older incoming release
is refused before mutation unless `-AllowDowngrade` / `--allow-downgrade` is explicit; root
dispatchers forward both controls for dotnet, angular, and monorepo.

The five v0.74.0 impact compatibility files now retire only when the previous manifest classified
the exact path as framework-owned and the current bytes match a hash authored into the incoming
ledger. Missing/malformed/unsafe previous metadata takes an explicit additive `CANT-VERIFY` path;
consumer-modified, unknown, protected, mixed, out-of-root, and reparse paths survive. Both composers
reject unsafe/duplicate ledger paths, a retirement still present in incoming ownership, and any
cumulative path/version/hash that disappears. A required maintainer baseline closes the first-
release bootstrap gap; this repository's committed HEAD and nearest release continue the history
chain, while an unrelated parent worktree is ignored. Plans include settings and per-file skill
backup, disable, and mirror mutations; every installer-owned target path is containment-checked
first, and unknown consumer skills remain byte-identical.

Test cost was reduced at the same time: the obsolete tombstone invocation suite was replaced by
twelve destructive-boundary convergence cases; twenty-two repeated full installs were removed from
`UpdateDelivery`; root routing checks now use dry-run instead of mutating full installs. The new
coverage keeps the materially distinct loss worlds. Recoverable mid-apply rollback remains open and
is not claimed because no reliable cross-platform induced-failure proof ships in this increment.
The maintainer eval recurrence check also bypasses ambient Windows PowerShell script policy so its
PowerShell-7 prerequisite assertion reaches the version boundary it is intended to test.

## 0.75.0 — 2026-08-23

**Recovery increment 3 replaces assurance language with the framework's observable boundaries.**
Active READMEs, presentations, review guides, architecture docs, hook comments, doctor output, and
portable rule carriers now distinguish supported editor/file-write events from shell/external
writes; describe `.claude/ai-audit.log` as mutable local hook telemetry rather than regulatory or
compliance evidence; and call NetArchTest/dependency-cruiser scaffoldable until a consumer wires the
gate into CI. Copilot CLI evidence remains dated, while VS Code hooks are explicitly Preview,
off-by-default, organization-gated, and uncertified across the full lifecycle.

Root delivery documentation now defers file counts to each distribution's ownership manifest,
states the licence/notice paths that physically ship, and removes stale numeric status summaries.
`ClaimTruth.Tests.ps1` narrowly rejects the three harmful current-claim families with independent
red fixtures; `DocTruth.Tests.ps1` checks manifest authority, legal delivery, and non-numeric status
pointers without turning general prose into a linter.

**Warehouse-only auto-detection now refuses before mutation.** Two distinct warehouse signal
categories with no .NET, Angular, or mixed marker no longer silently enter the .NET lifecycle,
which still cannot certify solution-free adoption. Both root installer twins name the observed
signals, exit 2, and offer explicit `dotnet` stack selection as an informed override. Focused tests
cover refusal, override, ordinary .NET, mixed routing, and reachable mutations on both twins.

All three composed distributions validate. Static-context limits are unchanged and the corrected
wording reduces the v0.74.0 totals by 142 characters for .NET, 94 for Angular, and 206 for monorepo.

## 0.74.0 — 2026-08-22

**Recovery increment 2 retires the invalid impact A/B path.** The former `/adopt` workflow tagged
its supposed pre-adoption reference after installation, so it could not support an old-versus-new
comparison or a causal value claim. Adoption now completes without an impact baseline, a headless
agent, or an impact report. It retains only an optional descriptive archived-configuration capability
comparison and current repository scorecard.

The shipped `impact-run` twins are now stable non-zero tombstones: they ignore all arguments, invoke
no agent, tool, or worktree, and explain why no comparative claim can be made. Their five retained
compatibility paths remain installed until the planned ownership-reconciliation retirement release.
Focused composed-dist coverage exercises hostile direct invocation, the no-execution scan, stale
adoption claims, and a reachable tombstone mutation.

**Release-gate recovery keeps shipped-hook coverage exclusively in CI.** Local release runs
`validate-dist` for all three distributions plus the footprint update, then the full root meta suite
on its existing default throttled runner; it runs no shipped dist hook suite. The attempted sequential
monorepo representative was functionally green (20 files, 0 failures) but took 924.1s, making
dist-gates 1004.0s, so it was rejected rather than called an improvement. A normal tag still waits
for CI's complete dotnet/angular/monorepo hook matrices on both Windows and Linux, while the root meta
suite continues to guard local authoring and release mechanics before push. No assertion or CI matrix
was removed, and no final speedup is claimed.

## 0.73.0 — 2026-08-22

**Recovery increment 1 closes the known installer data-loss paths.** Brownfield installation now
derives the complete inventory of incoming paths the copy would replace from the ownership
manifest, validates every archive destination before the first target mutation, and preserves each
displaced file at its exact relative path under `docs/pre-adoption/`. A pre-existing archive
destination is an explicit refusal, never an overwrite.

`.claude/ai-audit.log` is now persistent copy-if-absent state and is emitted as
`consumer-owned/protected` in every distribution manifest. Existing bytes survive both brownfield
installation and update. GitHub skill mirroring now upserts framework skills without deleting
unknown `.github/skills` descendants. Brownfield and update installs also refuse dirty Git
worktrees unless the stack installer receives its explicit, named override.

The proof is a composed-dist lifecycle suite on both installer twins: the corrected v0.72.0
fixture produced 22 independent failures, including both audit paths, settings/hooks/command/skill
collisions, archive replacement, both GitHub-skill resets, and dirty update/brownfield mutation;
the patched distribution passes all cases. Composer mutation fixtures also prove both composers
reject a one-twin persistent-policy change, while normal extraction emits protected audit ownership.

One review correction mattered: `docs/wiki/INDEX.md` was already copy-if-absent and therefore was
not a bulk-copy collision. The first manifest-driven draft would have archived it unnecessarily;
the final policy leaves it active and unarchived, with a regression sentinel.

The independent review found and blocked a physical-containment escape in the first draft: a
`docs/pre-adoption` junction could redirect archive moves outside the repository. Both twins now
refuse reparse/symlink collision sources and archive destinations—including dangling link leaves—
before any move; the old exploit is a composed-dist red fixture.

## 0.72.0 — 2026-08-22

**B-48 is complete after a year open, and the durable output is WSD-047 rather than the three fixes.**
The entry stalled because three known guard bypasses kept being treated as one problem needing one
answer. They are not alike, and the recorded rule is what makes the next one tractable: **harden**
where the defect has a canonical form to normalise to, **advise** where it is distinguishable from
correct work only by intent, **document** where the control would have to guess at side effects it
cannot observe.

**Shipping now: the test-weakening advisory.** `scripts/test-weakening-scan.{ps1,sh}` reports
assertion-shaped removals in test-file diffs, and `/review` consults it. **It always exits 0.**

That exit code is the design, not an oversight. Assertions removed or weakened in a diff cannot be
separated from a legitimate refactor by any rule available to us — deleting a duplicated case,
replacing three assertions with one stronger one, migrating an assertion library, and removing a test
for deleted behaviour all look identical to the defect. So the moment this can fail a run, it starts
refusing correct work, and B-94 already measured where that leads: `-AllowExtraStagedPaths` passed
reflexively once a guard began refusing correct releases. **A false positive on correct work teaches
people to bypass the control entirely**, which is strictly worse than the gap.

Both twins and `/review` describe it identically: *"a reviewable signal that can be defeated by
ignoring it; it is not enforcement."* Its own test asserts that phrase is present **and** that the
script never says "guarantees", "prevents" or "blocks the commit" — overclaiming is the specific
failure WSD-047 exists to prevent, so it is machine-checked rather than left to review habit.

**Two limits written down rather than discovered later.** The heuristic counts assertion-shaped
*lines*, so three assertions collapsed onto one line and deleted register as a single removal — that
is inherent to a diff-line heuristic and is now stated in both twins. And an advisory is defeated by
an agent that ignores it; what it buys is a raised cost and a reviewable signal, nothing more.

**A twin-rendering defect was caught by comparing bytes, not output.** The two scripts used an em dash
and a hyphen respectively, and the first check "passed" only because the console mangled the em dash
into a hyphen on display. Both are ASCII now and byte-identical [#3].

## 0.71.0 — 2026-08-22

**B-48(3): a real guard bypass is closed — and it existed in only ONE twin, which the entry did not
know.** `[Test,` newline ` Ignore("flaky")]` is legal C# that no formatter forbids, and B-48 records
it as a one-line evasion of a gate the framework advertises as deterministic, with a prescribed fix
"not yet built". Probing before building changed the picture entirely:

| content written to a test file | `guard.ps1` | `guard.sh` |
|---|---|---|
| `[Test, Ignore("flaky")]` one line | BLOCK | BLOCK |
| `[Test,` ⏎ ` Ignore("flaky")]` | **BLOCK** | **ALLOW** |
| `[Fact(` ⏎ `  Skip="flaky")]` | **BLOCK** | **ALLOW** |
| `[Theory,` ⏎ ` InlineData(1),` ⏎ ` InlineData(2)]` | ALLOW | ALLOW |

`guard.ps1` was **already correct**: .NET's negated character class `[^]]` matches a newline, so its
pattern spanned the break unaided. `guard.sh` allowed it because `grep` evaluates one physical line
at a time. So the bypass was never uniform — it was an **unrecorded invariant #3 divergence**, live
for every consumer whose hooks run through bash and absent on Windows. Building the prescribed
normaliser in both twins would have been redundant work in the more sensitive one.

`guard.sh` now folds newlines **only inside bracketed attribute lists**, tracking bracket depth so
newlines at depth zero survive and line-anchored patterns cannot be made to match text that never
began a physical line. **No pattern was loosened or rewritten** — the existing patterns run unchanged
against a normalised input, which is what B-48 prescribed. Verified bash-3.2 safe (no `mapfile`,
`readarray`, `declare -A`, or case conversion), since the shipped scripts run on macOS.

**The durable half is the coverage hole, not the fix.** The guard case table had **no multi-line
content at all** across 40 cases, which is exactly why this survived. Three cases now sit beside
their single-line originals: both split forms, and a **legitimate** `[Theory, InlineData, InlineData]`
spread over lines that must still ALLOW. That third one is the one that matters — a false positive on
correct work is what teaches people to bypass a guard entirely, which B-94 already measured with
`-AllowExtraStagedPaths`.

Red-tested: with the normalisation reverted the new cases report *"expected BLOCK, got ALLOW"* — four
failures naming the exact evasion. Restored: **88 passed / 0 failed**, on pwsh 7 and Windows
PowerShell 5.1 alike.

## 0.70.0 — 2026-08-22

**`docs-sync-check` no longer reports a machine problem as documentation drift, in both twins — and
the instance was found by tooling rather than by an incident.** B-164 established that maintenance
rule 7 (*a gate must distinguish "the artifact is wrong" from "I could not examine the artifact"*)
cannot be a hard gate but does admit a cheap advisory sweep. That sweep — *invokes an external tool,
exits non-zero, emits no host/resource marker* — flags **2 of 11 shipped scripts**, and both flags
were genuine. This is the harmful one.

`grep -q "GENERATED FILE" AGENTS.md || missing="banner"` turned an unrunnable `grep` into
*"AGENTS.md is not a current generated mirror — run `/generate-copilot`"*: a specific, confident,
actionable instruction to regenerate a file that was never actually inspected.

**The PowerShell twin was not exempt either**, which is the third time in this release series that a
twin looked safe because it does not shell out. `Select-String -Quiet` returns nothing when it cannot
**read** a file, which is indistinguishable from "the pattern is absent" — so a locked or unreadable
`AGENTS.md` would have been reported as drift. `-ErrorAction Stop` separates the two.

Three arms, both twins agreeing: a clean tree reports the mirror OK; a genuinely stripped banner still
reports drift with the same `/generate-copilot` fix; and a `grep` that cannot execute reports a host
condition and says explicitly that it is **not** evidence of drift.

The other flag, `install.sh:72`, carries the same conflation but **fails safe** — a broken `grep`
makes the installer refuse to overwrite rather than overwrite wrongly. Left as it is, deliberately,
and recorded in B-164: it is the class without the harm, and a gate that refused it would be refusing
correct code.

## 0.69.0 — 2026-08-22

**B-130: the shipped hook suite passes under Windows PowerShell 5.1 — 41 passed / 41 failed becomes
82 / 0.** A consumer without pwsh 7 can now run `tests/hooks/` and get true results instead of 41
phantom failures.

**The recorded diagnosis was wrong, and correcting it was most of the work.** The entry attributed
the failures to 5.1's `ConvertTo-Json` escaping an apostrophe as `'`. That is a real divergence
but a *separate* one, on stdout. The 41 failures came from 5.1 rendering the child's stderr as an
**ErrorRecord** before writing it to the redirect file — adding the executable name *and a stack
trace naming the parent harness's own call site*. Which is exactly why the earlier attempt, which
stripped the `powershell.exe : ` prefix, measured **41/41 again**: it removed the prefix and left the
trailing `At …` block.

`Invoke-RawProcess` now reads the child's streams directly, so neither host's native-command adapter
can decorate them. Chosen over pattern-stripping deliberately — stripping is a denylist, and the next
rendering variant defeats it, which is how the first attempt failed.

**A regression that only running it could catch.** Reading the streams raw also stops *hiding* that a
PowerShell child terminates lines with CRLF while a bash child uses LF (measured on one guard
message: stderr ending `13,10` against `10`). The twins are compared byte-for-byte, so the first cut
of this fix took **pwsh 7 from 82/0 to 54/28** — repairing one host by breaking the healthy one. The
harness now normalises the line ending and nothing else; content differences survive intact.

**The arm that mattered, and why the number was suspicious.** With `exit 2` mutated to `exit 0` the
suite reports **54/28 on both hosts** — the comparison still detects real differences. That check was
not ceremony: **54/28 is also what a broken comparison produces**, and a suite that jumps from
failing to passing has the same signature as one that quietly stopped comparing. Full shipped suite:
**0 failures across 19 files**.

## 0.68.0 — 2026-08-21

**B-18: an opt-in pre-commit convenience net, labelled as exactly that.** `setup-git-hooks.{ps1,sh}`
ships, wired to `-GitHooks` / `--git-hooks` on both installers. **Opt-in only** — the entry recorded
that silent default wiring was explicitly rejected, and it stays rejected.

The hook sends **only staged added lines** through the shipped guard, reusing B-100's property that
the guard is *invoked* rather than its patterns copied, so the scan cannot drift from what the guard
actually enforces.

**Setup refuses rather than clobbers.** An existing `core.hooksPath`, an existing
`.git/hooks/pre-commit`, or a `.husky/` directory each stop it with a message naming what was found
and confirming nothing was written. A framework that silently disables a team's existing checks has
done real harm, and this is the same failure shape as B-97, where a correct protective change severed
delivery because nobody traced its consequence.

**It is documented as a bypassable convenience net, not enforcement, in those words** — in
`docs/enforcement-surfaces.md`, the file B-100 corrected for precisely this reason, and the honesty
B-48 exists to keep. `git commit --no-verify` skips it; clients that do not run local hooks never see
it. One of the red-test arms *demonstrates the bypass*, so the documentation matches observed
behaviour rather than intent.

**The arm that decides whether a team keeps it or disables it on first contact** is the diff scoping,
and it was verified by construction rather than by reading the code: a **clean** addition to a file
that already contains a secret **passes**, while a new bad line in that same file still blocks. A
scan that flagged inherited content would block a developer for someone else's code, and would be
switched off permanently the first time it happened.

Verified on the bash legs by the reviewer — the implementer has no working bash, and a git hook is an
extensionless POSIX script, so it declined to claim arms it could not run rather than fabricating
them.

**Documentation deliberately did not go in `CLAUDE.md`:** monorepo static context has 83 characters
of headroom (see v0.67.0's `HEADROOM` reporting), and the figures are unchanged after this change.

## 0.67.0 — 2026-08-21

**B-156 is complete: the extractor sites no longer fail open when `grep` cannot run.** The cheap half
(`framework-doctor`, `impact-run`) shipped in v0.64.0. This is the half the entry deferred pending a
per-site contract decision, and the decision is that **none of them should swallow** — the entry's
hedge that some might legitimately do so does not survive reading them.

The reason is uniform across all three. An empty extraction is indistinguishable from a failed one,
and in every case **the empty path is the permissive one**: `warehouse-map-check` concludes the repo
is not a warehouse and skips itself, `template-checks` finds no changelog heads and therefore no
duplicates, `wiki-check` finds no index entries and therefore no bad ones. All three report success
for work that never happened — *worse* than the sites fixed first, where `framework-doctor` at least
said something false and visible.

Each now discriminates: **0** found, **1** genuinely empty and handled exactly as before, **2+** a
distinct host/resource condition naming the file, never a content verdict.

**The arm that mattered in review was the legitimate-empty one.** A repo genuinely may have no
warehouse artifacts and a wiki index genuinely may be empty, so a careless fix trades a silent false
pass for a noisy false failure. Verified on the bash legs: stub `grep` exiting 2 → exit 2 with the
host/resource message on all three; clean tree → exit 0 on all three; a genuinely non-warehouse repo
proceeds with no host claim. That is the same distinction the first cut of the cheap half got
backwards, reporting an absent `CLAUDE.md` as a host problem — because `grep` exits 2 for a missing
file as well as for a failure to run.

**Correction to the entry, recorded rather than quietly dropped:** `docs-sync-check.sh` is listed as
carrying extractor-shaped `|| true` sites. It has none. It does still carry the older conditional
content-verdict patterns, which are a different shape and were deliberately left alone.

## 0.66.0 — 2026-08-21

**B-163: `GuardPatternErrors.Tests.ps1` drops from 234s to 15s — and the speedup that produced it was
inert for half its cases until review caught it.** This file is the meta suite's dominant cost, and
the reason was structural: each of its four mutation cases ran the **entire 40-case `Guard.Tests`
suite** — 160 guard invocations, ~137s — in order to observe that **one** pattern had stopped
matching. `Guard.Tests` now accepts an opt-in `GUARD_TEST_POLICY` filter, and the mutation harness
asks only for the case that exercises the pattern it broke. That is logically sufficient rather than
a weakening: the suite's exit code is its failure count, so a filtered subset going red proves the
full suite goes red.

**The defect, recorded because it is the more useful half of this entry.** The first implementation
exited **1** when the filter matched no cases. But the harness decides "the mutation was caught" from
a **non-zero exit**, and this suite's ordinary exit code *is* its failure count — so "no cases
matched" was byte-identical to "one case failed". Removing the `secret` tag produced
**4 passed while two mutations tested nothing**. It now exits **111**, a sentinel outside any
plausible failure count, which the harness rejects by name. Re-verified in both directions: tag
removed → 2 passed / 2 failed; restored → 4 passed / 0 failed.

That is the B-59/B-64/B-75 inert-check class arriving inside the gate that protects the write guard,
disguised as a 14x speedup. **A faster test that silently stops testing is worse than the slow one it
replaced.** The generalisable rule: **when a test's exit code carries data, every new exit path
collides with it** — and reading the diff was not enough to see it. Only deliberately breaking the
tagging exposed it.

With the filter unset the shipped suite is unchanged: 82 passed, 0 failed, and the composed copies
are byte-identical to source.

## 0.65.0 — 2026-08-21

**B-157: each dist now ships `framework-ownership.json`, a generated manifest of every installed path
and who owns it.** Installing the framework lands ~164 committed paths, and nothing in the tree said
which of them the framework silently overwrites on update. 163 paths are classified into B-46's three
existing classes — 152 framework-owned/overwritten, 10 consumer-owned/protected, 1 mixed
(`.claude/settings.json`). It is generated during composition, so it cannot describe a tree other
than the one that shipped.

**The consistency check is the deliverable as much as the manifest.** It reads the preservation
policy out of **both** installers and refuses to compose when they disagree — a manifest that can
silently drift from the behaviour it describes is worse than none, because a reviewer will believe
it. Red-tested by removing `CLAUDE.md` from `install.ps1`'s `$protected` list: *"ownership policy
disagreement: consumer-owned/protected in install.sh but not install.ps1: CLAUDE.md"*, exit 1 from
`build.ps1` **and** `build.sh`, exit 0 once restored.

**B-162 (meta-only): the test harness now sweeps abandoned scratch trees at start-up, because a
killed process never runs its `finally`.** `ValidateDist.Tests.ps1` and `Invoke-MutationRedTest`
create per-case scratch copies under the temp root and remove them on teardown — correct for a run
that finishes and for one that fails, useless for one that is killed. Measured after a day of release
attempts: **2,075 temp entries**, including **223 `validate-dist-*` directories** (each a full ~170-
file dist copy, roughly **38,000 files**) and 569 loose `.tmp` files. Debris slows every later temp
operation, `GetTempFileName()` included, so a killed run makes the next run slower — and `dist-gates`
drifted **533.4s → 579.2s → 638.9s → 677.3s across four runs of identical work**. Whether that loop
fully explains the drift is *not* established and the entry says so; the run that would have tested
it was itself killed before emitting a stage timing.

The sweep removes only `validate-dist-*` and `mutation-helper-*` directories older than **six hours**.
The age threshold is load-bearing rather than decorative: the release runs three dist jobs in
parallel and each owns a live scratch tree, so a sweep matching by pattern alone would delete a
concurrent run's working directory and surface as a baffling dist failure. A removal that fails —
locked, permissions — is swallowed and never reported as a test result, which is the same
discrimination B-155 and B-156 apply to `grep`: a housekeeping problem is not a product verdict.
Red-tested on all three arms, with the one that matters being a **fresh** directory surviving.

The existing `finally` blocks are untouched; they are right for every case they can reach. This is
meta-side only — `scripts/validate-dist.ps1` does not create scratch trees, the meta test does — so
no shipped file changes and WSD-005 means no `.sh` twin.

**A twin-parity defect was found in review and fixed [#3].** PowerShell's `Sort-Object` is
culture-aware and case-insensitive; `sort(1)` collates by locale. The two composers therefore emitted
**byte-different manifests for an identical 163-path set** — `.github/PULL_REQUEST_TEMPLATE.md` and
the upper-case root files landed in different positions. Both sides are now ordinal
(`[StringComparer]::Ordinal` and `LC_ALL=C`). This is the Windows-only blind-spot class: the
implementer has no working bash, so only running the twin exposed it, and a byte-comparison gate
would have started failing on whichever composer ran last.

**Deletion remains rejected, on the measurement already recorded in B-157.** `tests/` is load-bearing
for the shipped `template-ci.yml` workflow, and the update path restores framework-owned files
anyway, so a cleanup step would fight the delivery model rather than tidy it. The complaint the entry
actually identified was never volume — it was that the first commit is unreviewable and that nothing
states ownership. One generated file answers both.

## 0.64.0 — 2026-08-21

**B-156 (cheap half): `grep`'s exit status is no longer read as a content verdict.** A non-zero
`grep` means either "the pattern is absent" (exit 1) or "grep could not run" (exit 2+), and
`framework-doctor` and `impact-run` conflated them — so a host or resource problem reached a
consumer as a specific, false, actionable claim about their files. `framework-doctor` is what
someone runs *when something is already wrong*, which is exactly when their machine is most likely
to be short of resources; `impact-run` was sharper still, because there a failed `grep` silently
changed which project type the tool decided it was looking at. Both twins of both scripts now
discriminate: `0` found, `1` a genuine product finding, anything else a distinct host/resource
condition. Verified on the bash leg with a stub `grep` exiting 2 — `CANT-VERIFY` naming the host
problem; with the import genuinely removed — `[MISSING]` with a fix; clean — 6 ok / 0 missing. The
PowerShell twins were **not** exempt: they never invoke `grep` but carried the same fail-open shape
through swallowed read and enumeration errors. The extractor-shaped `|| true` sites in
`docs-sync-check`, `warehouse-map-check`, `template-checks` and `wiki-check` are deliberately
untouched — each needs its own contract decision first, and for some, swallowing may be intended.

**The first cut of that change got the discrimination backwards in the bash twin, and the twin-parity
gate caught it.** `grep` exits 2 for a file that *cannot be read* **and** for a file that *is not
there* — so an absent `CLAUDE.md`, which is a content fact, was reported as a host/resource problem.
The `.ps1` twin was already correct, because its `Test-Path` guard happens to encode the distinction
for free; the two therefore disagreed, and `FrameworkDoctor.Tests` failed on all three dists
(36 passed / 2 failed) before anything was committed. Both probes now check that the file exists
before reading `grep`'s exit code as "could not run" (38 passed / 0 failed). Recorded because it is
the entry's own thesis failing in the opposite direction: the fix for conflating a host problem with
a content verdict introduced a conflation of a content fact with a host problem.

**B-138: the dist hook suites can finally be attributed per file.** They are ~97% of `dist-gates`
(515.5s / 514.7s / 515.4s of a 533.4s stage at v0.63.0) and had no per-file attribution at all,
because there are two hook runners and only the meta one emitted `TIMING`. The shipped runner —
the one `dist-gates` actually executes — now emits `TIMING <file> <seconds>` when
`HOOKTESTS_TIMING` is set, and `release.ps1` sets it for the dist jobs alongside
`HOOKTESTS_THROTTLE`. **Opt-in on purpose:** that runner ships, and a consumer running their own
suite has no release budget to blow and no ceiling to diagnose. With the variable unset the output
is byte-identical to before (verified by `cmp` against the pre-change runner on the same fixture),
and a `TIMING` line is not matched by the release's `^RESULT\s+(\S+)\s+(\d+)\s*$` parser. This is
the measurement prerequisite the entry has asked for since 2026-08-13; the re-architecture it also
describes remains deliberately not done, because three prior measurements each redirected it.

## 0.63.0 — 2026-08-21

**B-100: the enforcement-surface guide now states the write guard's actual boundary.** The guard
does not run for shell-authored or externally written files, so it is a deterministic floor only
for editor/file-write tool calls, not for all writes. An authoring-only, opt-in pre-commit
convenience scan now checks staged PowerShell BOMs and sends staged blobs through the canonical
guard; it is deliberately not presented as enforcement and does not ship.

Meta-only: B-83 adds filed-against release stamps to all 22 open backlog entries plus two meta-suite
checks. The delivery-ledger correlation — an entry id appearing in a shipped changelog or the
red-test coverage ledger while its heading still reads open — **reports** candidates for a human to
resolve and never auto-closes anything. The filed-against stamp check **blocks**: it shipped as an
advisory `Assert $true`, which is the inert-check shape B-59 and B-64 exist to remove, and since
compliance was already 22/22 enforcing it cost nothing. Note that the meta suite *is* a release gate,
so a future entry filed without a stamp will refuse a release until it is added.

Meta-only: the B-154 tag-reconciliation check refused this very release, twice. It reports a dated
changelog head with no git tag, and on a release commit that is unavoidable: the tag follows
CI-verified green (WSD-029), CI runs this suite, and the suite was waiting on the tag — a cycle with
no exit. A first fix exempted the in-flight version through an environment variable set by
release.ps1; that cleared the local gate and then failed CI on both legs, because CI is not
release.ps1. The check now reconciles every dated head **except the newest**, deciding from the
changelog''s own ordering rather than from the environment, so it returns the same answer locally, in
CI, and on a clone. Nothing is given up: a release that was dated and never tagged is only knowable
as abandoned once a later release is dated above it, at which point it is checked normally. The
decision is a pure function with fixtures, including the assertion that detection is deferred by one
release rather than disabled.
## 0.62.0 — 2026-08-20

**B-152: changelog validation now reads every release head instead of trusting only the first.**
The shipped changelogs carried duplicate `0.56.0` heads for five releases, including a stale
`Unreleased` entry below the dated one, while the gate built for that defect examined only the
first H2. The record is merged without losing the detailed release rationale. Both gate twins now
reject duplicate semantic-version heads and reject an `Unreleased` head at or below the stamped
framework version, while allowing the next version's required pre-release authoring head.

A third rule was added in review. Dropping the first-H2 read was necessary — the intended pre-stamp
state puts the next version's `Unreleased` head on top — but that read was also the only thing
rejecting a **dated** head for a version *above* the stamped one, which is B-152's defect one notch
over. Measured on a scratch dist: a planted `## 0.99.0 — 2026-01-01` above a stamped `0.61.0` passed
as "version stamps in sync". Both twins now reject it, and both were observed red on that exact
plant. There is no legitimate case for one: after a release the top dated head *is* the stamped
version, and during authoring the top head is `Unreleased`.

**B-50: the shipped enforcement matrix no longer contradicts itself about Copilot `postToolUse`.**
The matrix row had been updated after the B-49 drill, while two other passages in the same document
still stated flatly that the channel was dead — so a consumer reading the matrix and a consumer
reading the status note got opposite answers. Settled by an isolated three-arm canary on **CLI
1.0.80** (`meta/canaries/b50-copilot-posttooluse/`): the channel **is** live. Treatment echoed an
out-of-band token verbatim after a real write; a positive control on `userPromptSubmitted` proved a
null would have been readable; a no-hook control proved the token was not reachable through the
inherited environment, which a `--allow-all-tools` model could otherwise have read.

**B-143: the `applyTo` advice now states only what was observed.** All three READMEs asserted that
"Copilot's coding agent and inline completions both honour `applyTo`". Nothing here had ever verified
that, and a non-matching `applyTo` fails *silently*. On CLI 1.0.80 any **narrow** `applyTo` delivered
nothing even with a matching file named in the prompt — braces, commas and plain globs alike, so it
is narrowness rather than syntax — and only `"**"` arrived. VS Code agent mode, the surface the
advice targets, remains unverified and escalates with B-43. The advice is kept and caveated, not
deleted: the mechanism is vendor-documented; what was wrong was asserting a delivery we never saw.

## 0.61.0 — 2026-08-19

**B-97 (partial): `framework-doctor`'s `Protected-file sync` row now reports migration state instead
of comparing version strings.** The old row compared `CLAUDE.md`'s `version:` frontmatter against
`.claude/framework-version.json`. After v0.45.0 moved the four framework-owned blocks into the
carrier (WSD-031), that comparison stopped meaning anything: `CLAUDE.md` is consumer-owned and its
stamp is *expected* to lag, so the row reported `DIVERGED` permanently to every consumer who
installed earlier and never hand-edited their stamp — naming no block, offering no fix, and unable
to see an actual hand-edit. A diagnostic that cries wolf trains people to ignore the only
machine-checkable signal the delivery gap has.

It now reports whether the migration actually completed: import present and no framework headings
left inline → `OK`; import present but some of the four still inline → `PENDING`, naming them and
saying to delete them; import or carrier absent → deferred to the `Framework rules delivery` row
that already owns that state with its fix text; `CLAUDE.md` absent or unreadable → `MISSING`.

This checks something nothing verified before: `session-start` already tells consumers to add the
import *"where those sections are, **and delete them**"*, and no gate ever confirmed the second half
happened. It also targets the state behind B-97's open successor question — a consumer holding both
the fresh carrier and a stale inline copy — and resolves it by removing the duplicate rather than
waiting on a measurement of which copy a model follows.

**Rev 1 of this design was rejected by adversarial critique, and the rejection is the useful part.**
It proposed shipping `meta/block-manifest.json` and classifying each inline block by hash. Four
independently sufficient objections: (1) a materially smaller fix — redefining the row around the
carrier/import state already computed one row above — was never evaluated, a Maintenance model #6
failure; (2) shipping the manifest violates invariant #6, because its own `purpose` field contains a
`B-nn` tracking id that `no-meta-leak` denies; (3) the `.sh` twin declares "No jq/python dependency
by design" and ships no SHA-256 anywhere, so nested-JSON querying plus a portable hash cascade was a
large new dependency surface for one diagnostic row; (4) it would not have fixed the stated harm
anyway, since it still warned at the same population with different wording. The manifest stays in
`meta/`, unread, until something legitimately consumes it.

**Implementation RCA.** Codex implemented the eight specified arms and all eight were genuinely
red-tested; independent re-testing with different mutations confirmed arms 4 and 7 are not inert.
The review still found a defect none of the eight could see: `Get-Content -Raw` returns `$null`
(not `''`) for an empty file, so an unguarded `.Contains()` threw and **both** the
`Protected-file sync` and `Framework rules delivery` rows vanished from the PowerShell report
entirely — an inert diagnostic reading as a clean run — while the `.sh` twin still reported
`deferred`, a twin divergence [#3]. The original code was null-safe and the rewrite dropped the
guard. Arm 9 now covers it. **Why no gate caught it:** every arm was written from the design's state
table, which enumerates *consumer states*, not *file-read failure modes*; no arm supplied a
degenerate file. **Same class exposed:** any doctor row that dereferences a `Get-Content -Raw`
result without a null guard. Swept the file — the remaining reads are already guarded.

**Also carried by this release: B-131**, which shipped in `a34ba8c` without a changelog entry and
would otherwise have reached consumers unannounced. `template-checks` now parses `CHANGELOG.md` only
in a marked template repo, so a consumer following Keep a Changelog (or anything else) no longer
fails our gate over our own release grammar. Found while assembling this release; the release
process not stating a delivery/announcement surface per item is the same class B-97's changelog
sweep already flagged.

Meta-only in the same release: B-55's superseded-vendor-claim denylist, and the B-42/B-49 record
corrections.

**Gate runtime: the meta suite went back under its ceiling by fixing the cause, not the ceiling.**
Four release attempts refused on `gate budget: meta-suite took 671.5s, ceiling 650s` while every
functional gate passed. `GuardPatternErrors.Tests.ps1` (added the day before, B-59) ran its four
mutation cases in a plain `foreach`, and measured **651.1s of a 677.6s wall clock — 96%**: that one
file *was* the suite, with every other file finishing inside its shadow. The cases were never
coupled — `Invoke-MutationRedTest` gives each invocation its own `mutation-helper-<guid>` scratch
tree and removes it in a `finally` — so they now run as throttled jobs honouring
`HOOKTESTS_THROTTLE`, which matters because this file runs *inside* the outer parallel loop and
ignoring the throttle would reproduce the 2026-08-07 oversubscription trap one level down.
**Measured: 418.5s → 230.3s standalone (1.82x); full suite 671.5s → 529.8s, 0 failures across 25
files.** The runner also now emits `TIMING <file> <seconds>` — on its own line, because
`release.ps1` parses `^RESULT\s+(\S+)\s+(\d+)\s*$` anchored at both ends and a third field there
would have silently broken the `-AllowFailingGate` path into "emitted no per-file RESULT lines".

**RCA on the diagnosis, which was wrong twice before it was right.** The first fix — longest-first
launch ordering — was modelled to cut the makespan to ~418s and delivered nothing (689.2s vs
671.5s). Both wrong diagnoses came from feeding a **serial** per-file timing pass into a **parallel**
schedule. A serial pass runs each file with the throttle env vars unset, i.e. at full internal
width; the parallel loop hands each file `$innerLanes`. `GuardPatternErrors` measured 418.5s serial
against 651.1s parallel — a 1.56x contention inflation on a file with *no* internal parallelism at
all — so serial costs cannot predict a parallel makespan, and no reordering escapes a single job
that outlasts the whole schedule. **Why no gate caught it:** the budget gate measures the aggregate
and names the stage, but nothing measured *per file*, so every diagnosis was inference. That is what
the `TIMING` lines close. **Same class exposed:** `dist-gates` has the identical shape and still has
no per-file attribution. Also: B-138 still names `ValidateDist.Tests.ps1` as "the single largest
cost (339.6s, 67% of serial)" and prescribes a reused-runspace re-architecture; that premise is now
stale — `ValidateDist` was not the binding constraint and the real one yielded to scheduling — so
the entry needs rewriting before anyone acts on it.

## 0.60.0 — 2026-08-18

**The write-guard can no longer go inert, and its error policy is split by confidence (B-59,
WSD-046).** All 20 `grep` sites in `guard.sh` route through an error-aware helper: exit 0 match /
1 no-match / 2+ *could not answer*, where the third case was previously folded into "no match" and
allowed the write. `grep -Eq --` matters — the private-key pattern begins with `-----`, so without
`--` grep parses it as an option and returns 2; the first design's helper dropped it and would have
made the first secret rule permanently inert, inside the helper written to prevent exactly that.
On a pattern error the **7 secret patterns fail closed** (high-confidence any-file rules whose
shipped header already promises this) while **test-defeat/suppression patterns warn and allow**
(our bad regex must not brick an ordinary refactor — B-48's trust judgment).

**Case policy has two halves, and collapsing them was the first design's blocking error.** Content
patterns are exact (`-cmatch`); the three file-routing predicates deliberately fold, in both twins,
spelled inline. A blanket `-cmatch` sweep would have stopped inspecting `src/Foo.CS` and
`src/app.TS` **entirely** — verified, `'src/Foo.CS' -match '\.cs$'` → True, `-cmatch` → False.

**A live twin gap was found and closed while doing it.** `guard.sh` routed with
`case "$fp" in *.cs)`, which is case-sensitive, so `Foo.CS` was guarded by `guard.ps1` and **not**
by `guard.sh` on the shipped release. Bash was brought up to correct behaviour rather than
PowerShell blinded down to match.

**The entry's own thesis is now testable.** `GuardPatternErrors.Tests.ps1` plants an invalid regex
in each twin and asserts the suite goes red, across both error policies, on B-84's mutation helper
so each mutation is proven to have applied and the restore verified byte-identical.

**Reached-set assertions on the remaining parity suites (B-75)** — and they immediately caught a
genuinely **inert** `WikiCheck` "malformed frontmatter" fixture. `FrameworkDoctor` was correctly
skipped: `Parse-DoctorResult` already asserts the exact set of all 12 row names on every run.

**`meta/gate-redtest-coverage.md` (B-64)** — the inventory the rewritten entry asked for:
49 COVERED, 10 HAPPY-PATH-ONLY, 9 UNKNOWN, 0 with no test at all. The composer, `docs-sync-check`,
`InstallerContract` and `RootInstallerWarehouse` are the happy-path-only gaps worth closing next.

Deliberately **not** done: B-59 §3e, the NUnit POSIX grep. The replacement the entry called
"verified equivalent" misses the canonical bare `[Ignore]` (measured, GNU grep 3.0), so the shipped
grep was left alone rather than swapped for an unverified one.

## 0.59.0 — 2026-08-18

**Copilot CLI delivers only the LAST `userPromptSubmitted` hook, so `route-prompt` was silently
discarded (B-147, P1).** Established by live canary on CLI 1.0.79/1.0.80: four runs, the decisive
control swapping tokens between two scripts so the surviving token moved with the *slot* rather than
the script, and a fourth with structurally distinct messages ruling out context de-duplication.
`.github/hooks/hooks.json` registered `route-prompt` first and `boy-scout-check --mode deliver`
second, so the routing/plan-gate/security salience never reached the model while
`docs/enforcement-surfaces.md` asserted in three rows that it did — the security-pass row among
them. The framework now registers **one** entry and composes both payloads inside `route-prompt`:
surface is decided first, the three early exits are gated to the Claude path, and the Copilot path
falls through to drain the Boy Scout queue. The queue read sits behind the *surface* gate rather
than behind "routing text is empty", because `boy-scout-check` is registered independently on
Claude's `Stop` event and a drain on that path would double-deliver. Found by B-52's canary, whose
own question is answered as a footnote: the Boy Scout row it was filed to doubt was the only one of
the three that was true, by the accident of being registered last.

**The doctor said "your docs have drifted" when it could not start an interpreter (B-130).** The
*Mirror and version integrity* row ran `template-checks` through a bare interpreter name, so on a
host whose `PATH` does not resolve it the row reported drift — a specific, false, actionable
diagnosis — instead of reporting that it could not run. Both twins now separate the two: the `.ps1`
self-hosts through this process's own executable, and each emits a distinct "drift is UNKNOWN rather
than found; this is a host problem, not a documentation problem" row. This had been reddening all
three dist hook suites, including at the `v0.58.0` tag: 29/1 → 30/0.

Also: `no-meta-leak`-clean corrections to the Routing, Plan-gate, Security-pass and Boy Scout rows
of `docs/enforcement-surfaces.md`, naming the CLI version and date observed.

## 0.58.0 — 2026-08-17

- B-77: added the read-only `hazard-check` PowerShell/bash gate and wired it into
  `docs-sync-check` so malformed hazard status/date cells and dangling named paths block CI. Until
  now `session-start` measured only a hazard row's *age*, so a `[VERIFIED]` row pointing at a
  long-deleted file stayed fresh-looking forever. Path resolution is deliberately narrow — a bare
  filename matches tree-wide, a `/`-bearing path resolves from the repo root, a wildcard checks only
  its longest wildcard-free directory prefix, and prose/symbol cells are ignored — because the gate
  blocks and `/bootstrap` drafts that cell in free text. Read-only per WSD-027.

## 0.57.0 — 2026-08-17

- B-46 part 2: added honest, offline-only version awareness to both `session-start` twins. Once
  every seven days, the hook names the installed framework version and points to the releases page;
  it does not contact the network or claim that an update exists. The throttle is best-effort under
  `.claude/.state/`, and an unwritable state path remains a soft failure.
- B-49: built the meta-only quarterly drill kit and pinned its two repository targets without
  inventing commit or build evidence; exact SHAs and target qualification remain drill-#0 work.

## 0.56.0 — 2026-08-17

- B-46 (verification + the actionable half): **measured** that an update silently clobbers every
  consumer edit to shipped machinery — skills, hooks, `scripts/`, `.claude/settings.json` — while
  printing "consumer-owned content files untouched". Protected and consumer-added files survive
  correctly. Now shipped: an update-mode preflight disclosure that prints **before** the first
  mutation, a rolling pre-overwrite backup of `.claude/settings.json` at
  `.claude/.state/settings.json.pre-update`, an honest closing line, three documented ownership
  classes across four READMEs and both installer headers, and WSD-043.
  **The first design was rejected by measurement, not by argument.** It proposed reporting per-file
  "local modifications" by comparing incoming against installed content — but a difference means a
  consumer edit *or* an ordinary version change. Installing v0.51.0 and touching nothing leaves **31
  files** differing from the current dist; all 31 would have been false positives, and a warning that
  is ~100% noise trains consumers to ignore it. The first experiment only looked convincing because
  it updated with the *same* dist version, so every difference genuinely was a consumer edit — the
  confound was in the method. Independently fatal: `settings.json` is host-adapted at install,
  refreshed skills gain an exemplar line, discovered/disabled skills are deliberately restored, and
  `.github/skills` is regenerated — all *supposed* to differ.
  Skipping was rejected on the record: `settings.json` carries hook registrations that must evolve,
  and withholding them is B-97's failure mode. Backup-then-refresh keeps both properties.
  The message deliberately does **not** say "recover from git history": the installer requires
  neither git nor a clean tree, so that is a promise we cannot keep.
- B-65: **dropped the pointer, shipped only the documentation correction.** The proposed carrier was
  a line in `CLAUDE.md` — which is protected, so update restores the consumer's copy and the line
  would reach new installs only, missing exactly the population it exists to help (B-97's wall).
  `docs/enforcement-surfaces.md` gained an honest on-demand/discoverable tier that claims no routing
  improvement; the single 2026-07-31 unaided-open observation is named as insufficient.

## 0.55.0 — 2026-08-17

- B-66 (remaining half): shipped the prescriptive Angular forms guidance into `docs/defaults.md`
  § Forms (both the angular and monorepo siblings [#1]) and a self-contained custom-form-control
  branch in the `add-component` skill, with its frontmatter `description` extended so selection
  fires on "custom form control"/"ControlValueAccessor". `### Component Design`'s @Input/@Output
  line gained the form-control carve-out.
  **This ships on the field report, not on a probe.** The gate that held it since v0.40.0 was
  "the behavioural probe is already green so improvement cannot be demonstrated" — which inverts the
  evidence hierarchy, since a real field report is the strongest evidence this repo has. The
  instrument that would have graded it was itself rejected (B-145). The effect on model behaviour is
  **unmeasured**, and nothing in the shipped text implies otherwise.
  The three precision traps from the drafted content were all honoured and verified in the diff:
  circular DI is qualified to the *self-referencing* `useExisting: forwardRef(() => Self)` provider;
  the text says `@Input() disabled` *fights* `control.disable()` via `setDisabledState()` and never
  claims "Angular warns" (that claim would be false — `grep -rn "Angular warns" dist/` is empty);
  and signal inputs are noted read-only, so a CVA's value cannot be an `input()`.
- `DEVELOPING.md`: corrected the PATH-repair advice added in v0.53.0. It is PowerShell-only —
  prepending `C:\Windows\System32` inside Git Bash shadows GNU `find`/`sort` with the Windows
  binaries, which made a validator's file scan see zero files and fail. A broken shell wearing the
  costume of a broken dist; caught only because that check has a zero-files guard.

## 0.54.0 — 2026-08-17

- Installer, Bash twin: two `set -euo pipefail` landmines on the UPDATE path. The disabled-skill
  restore piped a `grep` whose **no-match case is the normal one**; `pipefail` promoted that to a
  pipeline failure and `-e` aborted the installer after the copy but before the completion banner,
  so every update exited 1 silently while `install.ps1` exited 0 — a twin-parity violation shipped
  to consumers. A bare `[ -d ... ] && cp` two lines later is the same shape and was fixed with it.
  Found by the Definition-of-done install smoke test while shipping B-81, and confirmed pre-existing
  at the v0.53.0 tag. `UpdateDelivery.Tests.ps1` now asserts every dist × both twins exits 0 **and**
  prints "Done (update)" — exit code alone would not have caught the abort, since greenfield masked
  it by ending on a different branch.
- B-81: every distribution now carries the framework's verbatim MIT text under `LICENSES/` and a
  framework-owned root notice identifying the governed framework paths. Both installer twins
  preflight those paths: an identical licence is retained, a marked notice refreshes, and either
  kind of consumer-owned collision refuses with exit 3 before the target is mutated. An
  authoring-only drift gate keeps the shipped legal text LF-normalised byte-identical to `LICENSE`.

## 0.53.0 — 2026-08-16

- B-58: `template-checks` check 8 now compares the exact Common Tasks skill-slug inventory in
  `CLAUDE.md` and `AGENTS.md`, catching one-sided and duplicate entries while continuing to allow
  their deliberately different description prose. Corrected Angular's live `add-tests` mirror to
  name the same test stack on both surfaces. A separate authoring-only `SkillListParity` test checks
  description code spans in the three stock outputs; it stays authoring-only because generated
  consumer mirrors are intentionally condensed rather than verbatim.
- B-60: `validate-dist` check 12 (`step-references`) now catches broken top-level ordered-list runs
  and unresolved numbered step references in shipped workflow content.
- Follow-up (same version, after the first release attempt went red on CI's linux legs only): the
  shared `TemplateFixture` had been switched to CRLF to give the new check an EOL control, which fed
  carriage returns to checks 1-7 for the first time on the one leg that can perceive them — MSYS
  opens files in text mode, so Git Bash strips CR before `sed`/`grep`/`awk` ever run and no Windows
  leg can see this class. Fixture reverted to LF; the CRLF control is now its own scoped case,
  marked as linux-only coverage because it provably cannot fail on Windows. `template-checks.sh`
  now strips CR with an octal escape rather than a backslash-r escape, since awk implementations
  differ on which escapes they honour inside a regex.
  `ScriptTwinParity`'s exit-mismatch assertion now prints both twins'
  stdout/stderr — which immediately identified B-130's remaining unexplained 5.1 divergence as the
  maintainer box's corrupted `PATH` (a bare `powershell` spawn that resolves to nothing), not the
  encoding bug that entry had hypothesised for both of its members.
- Fixed a real `template-checks.sh` twin divergence that the above turned up: its section
  extractor stripped CR from body lines but compared the HEADING with an exact string test, so on a
  CRLF checkout `## Leanness` plus a carriage return did not equal `## Leanness` and the mirror
  check reported four sections MISSING on a repo that was perfectly correct. The PowerShell twin was
  never affected, so this violated twin parity in a way no Windows run could reveal — under MSYS,
  `awk` receives the file already CR-stripped by the platform, through a file open OR a pipe. Only
  the linux leg can perceive it, and that is where it was caught.
- B-82: `DocTruth` now requires every root `CLAUDE.md` and `AGENTS.md` level-two heading to
  participate in an explicit mirror mapping, forcing a new mirror decision when either topology
  changes without pretending to prove the mirrored prose is complete.

## 0.52.1 — 2026-08-13

- B-41/B-23: retired the unmaintained API-backed eval runner while preserving its case catalogue as
  readable framework evidence, and taught `no-dead-instruction` to catch missing Python scripts.
- B-135: security review now keeps active or suspected credential incidents out of Git and durable
  chat detail, minimises ordinary security rows, fails closed on legacy registers, and records a
  constant audit sentinel instead of a path when normalisation fails.

## 0.52.0 — 2026-08-10

- B-125: `map-warehouse` now emits evidence-ranked modelling-health findings for grain,
  additivity, conformance, special members, allocation gaps, and fact-stream multiplication, with
  scoped deepening and stricter SCD false-positive suppression.

## 0.51.5 — 2026-08-09

- B-54: `release.ps1`'s changelog stamping now dates the root **and** all three shipped consumer
  changelogs atomically, with a post-composition postcondition checking all seven heads (root, 3
  source, 3 composed dist) before any commit. Previously only the root changelog was ever stamped —
  the shipped ones kept whatever placeholder they were authored with, and shipped that way twice
  (v0.35.0, v0.46.0) and a third time silently in v0.51.4 itself (corrected separately, see the
  v0.51.4 entry below). `template-checks` now also fails when a shipped changelog head carries the
  current stamped version but still reads `Unreleased`, in both twins — belt and braces for a
  hand-authored entry outside `release.ps1`.
- B-54: fixed a Windows PowerShell 5.1-only encoding bug found while building the check above
  (BOM-less `Get-Content` misreads a UTF-8 em dash under 5.1, garbling the failure message) by
  switching to an absolute-path `[IO.File]::ReadAllText`, matching `release.ps1`'s existing idiom.
- B-54: fixed a defect the stamping logic itself introduced, caught by independent (Opus-tier)
  review — a release retried on a later calendar day after a gate failure would falsely refuse with
  a "date mismatch" and instruct the operator to rewrite an already-published release date, breaking
  the script's own documented retry-safety promise. Fixed by resolving the release date from any
  single already-agreeing stamped value across the four heads instead of requiring exact equality
  with a freshly recomputed "today", and explicitly refusing a genuine mix of disagreeing dates.

## 0.51.4 — 2026-08-08

- B-63/B-56: `framework-doctor` now reports capability evidence from the environment it actually
  observes. Guard-parser demand comes from registered Claude and Copilot `guard.sh` targets;
  PowerShell reports the agent host's Bash `PATH` as unobservable, while a directly invoked Bash
  doctor reports only on its own environment. Wired-shell remediation follows the portable
  bare-name policy, stack/Copilot command resolution names the doctor-process boundary, and a new
  post-write canary covers the actual host. Deterministic registration, vantage, mutation, and
  canary fixtures lock those boundaries under pwsh, Windows PowerShell 5.1, and Bash. The Bash
  registration grammar also matches shell-valid single quoting and case-insensitive `bash.exe`
  basenames without treating a target mentioned inside `bash -c` as an invoked guard.
- B-89: `sync-agent-files.ps1` no longer dies with a raw `NativeCommandError` under Windows
  PowerShell 5.1 when run outside a Git worktree -- the `git rev-parse --show-toplevel 2>$null`
  fallback now inspects the exit code instead of relying on the error record, matching the fix
  B-90 already shipped for the architecture-HTML generator. `fidelity-check.ps1` (maintainer-only)
  had the identical idiom and was fixed in the same pass.
- **Correction (2026-08-08, post-ship):** all three shipped consumer changelogs
  (`src/stacks/*/files/CHANGELOG.md`, composed to `dist/*/CHANGELOG.md`) still had their `## 0.51.4`
  head entry reading `Unreleased` after this release actually shipped -- exactly the B-54 defect
  class, still unfixed at the time this version was cut. Corrected in place to `2026-08-08` to match
  this file's own head date; no other content changed. Found while resuming and validating B-54,
  whose gate (once implemented) would have refused this exact release.

## 0.51.3 — 2026-08-08

- B-67: `validate-dist` now checks rendered relative inline Markdown links in shipped docs, with
  document-relative, case-exact resolution, path-escape rejection, and a separate anti-vacuity
  floor. The sweep also corrected bootstrap examples that rendered as dangling warehouse-map links
  from inside `.claude/commands/`.

## 0.51.2 — 2026-08-08

- B-71/B-74: the shipped hook test suite's Windows PowerShell 5.1 compatibility case no longer
  depends on `powershell.exe` being directly on `PATH` — it now falls back to the well-known
  `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`, so a host where 5.1 exists but
  isn't PATH-exposed gets a genuine run instead of a silent skip counted inside a green summary.
  B-74's already-shipped (v0.44.0) backlog heading was also corrected; no behavior change there.

## 0.51.1 — 2026-08-08

- B-90/B-93: PowerShell test subjects now remain on the host that launched their individual suite.
  A test file invoked directly under Windows PowerShell 5.1 can no longer silently exercise hooks,
  installers, release guards, or generators under PowerShell 7 and report that result as 5.1
  evidence. The aggregate runner still selects its preferred host. The honest direct run exposed
  and fixes a 5.1-only architecture generator failure when invoked outside a Git worktree.

## 0.51.0 — 2026-08-08

- B-78/B-115: added shared warehouse detection, `warehouse-map-check` twins, current-evidence
  gating for warehouse writes, and pure SQL/SSDT/dbt installation plus solution-free adoption.
- Update mode refreshes framework skills while preserving standardized exemplars and discovered
  skills; explicitly disabled framework skills stay inactive but current.
- B-118/B-120: instance recipes now check for an existing owner, and no-output dimension-binding
  evidence reports `n/a` instead of desirable false values.

## 0.50.0 — 2026-08-07

**`add-warehouse-load` never asked whether the dimension already existed. It does now — and the
change ships with a write-side baseline that refuses the delivery half of its own plan.**

Design LOCKED at `.claude/plans/2026-08-07-dimension-binding-eval-design.md`, adversarially reviewed
before implementation (codex `sol`, read-only: 6 blocking findings, 5 accepted).

- **The gap.** The recipe went from step 1 "find a load pattern to copy" straight to "design the
  entity" and never posed the question the commonest warehouse task turns on: *does this dimension
  already exist?* Adjacent guidance was all present — surrogate-key FKs, SCD, load ordering,
  late-arrival handling — so the omission was invisible to every gate we have. New step 2 sorts each
  non-measure source column into reaches-an-existing-dimension / degenerate / genuinely-new, matched
  on **business key rather than column name**, and adds the three checks a name match misses:
  indirect (snowflake) reach, grain compatibility, conformed use. Output is a written key list that
  the fact-design step now transcribes instead of re-deciding.
- **Budget: zero.** Static context is unchanged (47,884 of 48,000; 116 chars still free). The whole
  change is skill **body**, which the footprint counts as `ondemand-info` — the only lines that moved
  in `meta/context-footprint.json` are two `SKILL.md#body` entries, 6,062 → 10,413 chars.
- **Steps 2–9 renumbered to 3–10.** The skill carries no internal step cross-references; sibling
  steps in the new text are referenced **by name**, which is the fix for B-60's rot class rather than
  a workaround. Three maintainer files cite the old numbers and were deliberately left alone — they
  are dated records of what was true when written.

**The measurement, and what it refused.** `meta/eval-results.md` carries the full pre-registration,
written before any run.

- New `warehouse-bind-sql` / `warehouse-bind-mixed` scenarios and a `warehouseDimensionBinding`
  grader scoring four **independent** outcomes: map reached, skill reached, `add-entity` reached
  instead, binding correct. Separating them is what distinguishes "the skill never fired" from "the
  wrong skill fired" — different defects, different remedies.
- **New `warehouse-mixed` fixture** — the SQL tree plus a genuine EF Core side. Until now **no
  fixture put two plausible competing skills in one repo**, so a roster's likeliest failure was
  structurally unobservable across the whole suite. That gap is B-117.
- **Result (v0.49.0 dist, `n=2` per fixture, every verdict re-verified against the produced DDL):
  pure-SQL bound correctly 2/2; mixed failed 2/2**, both times putting `RegionKey` directly on the
  new fact where this warehouse reaches region through `DimCustomer.RegionKey`. Had only the old
  pure-SQL fixture existed, the honest conclusion would have been "no behavioural cost, ship as
  documentation" — the pre-registration says so in those words.
- **The planned Stage D was REFUSED by its own pre-registered rule.** It was to copy write-side
  guidance into the emitted `docs/warehouse-map.md`, justified by v0.48.0's `Skill` 0/6. That
  justification does not transfer: the 0/6 was measured on **query-writing** prompts, and on a
  **load-shaped** prompt the `Skill` tool fired **6/6**. `map-warehouse` is untouched.
- **Which corrects a standing conclusion in the opposite direction.** B-98 step 2 concluded skill
  routing was bypassed, not repaired. That is now shown to be **task-class-specific**: the roster is
  write-side by construction (B-98 step 3), so write tasks find their skill and read tasks do not.
  First direct confirmation from the write side.
- **`reachedAddEntity` was 0/6, so the mixed-repo boundary line is NOT justified by measurement.**
  It stays in the body as a cheap clarification, labelled unmeasured. B-117 is not discharged.

**Three grader defects and one voided batch — all false negatives, none caught by running it.**
Recorded because the pattern is the finding, not the individual fixes:
1. The fixture map stated *"Region is not a direct fact dimension"* — the exact conclusion
   `regionOnFact` scores. **A live batch was voided.** The hazard was already written down twelve
   lines above, in the same file, about the fixture's `CLAUDE.md`; it was reproduced one artifact
   over. Filed as B-112 instance 4, which now has the generalisable guard it lacked: for each scored
   outcome, assert no fixture artifact states that outcome's conclusion.
2. `newDimensions` keyed on a `Dim` name prefix and reported **none** for a run that created
   `dim.CustomerXref` and `dim.ProductXref`. Now matches on schema.
3. `naturalKeyOnFact` enumerated spellings and reported **False** for a fact declaring
   `SupplierCustomerRef`. Now matched by shape.

Every fix is red-tested; the grader was shown to go red on six axes and green on the correct
positive. **All three were false negatives** — these numbers more likely understate the failure rate
than overstate it, and that is why the verdicts above were re-verified against DDL on disk rather
than read off the `Detail` string.

**Also filed:** B-114 (two live entries both claim `B-113`), B-115 (pure SQL/SSDT/dbt repos cannot be
installed and `/adopt` requires a `.sln`), B-116 (`route-prompt` has no data vocabulary), B-117,
B-118 (RCA: a recipe listing what to build with no preceding *should this exist* decision, plus the
sweep of other `add-X` skills exposed to it).

**Known shortfall, not smoothed over:** `n=2` per fixture against a pre-registered `n=3`, stopped to
stay inside the approved budget. The 3/3-vs-0/3 `regionOnFact` split is consistent, not a
significance claim.

## 0.49.0 — 2026-08-07

**B-96: `map-warehouse` mapped the ETL, not the warehouse. It now carries the schema and the
relationships — and the read-side rules travel in the artifact the measurement says gets opened.**

Implements the LOCKED design at `.claude/plans/2026-08-05-b96-warehouse-schema-map-design.md`, with
one deviation recorded as **WSD-032**.

- **The gate is discharged, not waived.** B-96 was blocked on B-98 step 1's `r=0/6`. Step 2 shipped
  Verification Rule 11 in v0.48.0 and measured `r=6/6` (`p≈0.002`). The `BLOCKED` note in
  `meta/BACKLOG.md` was stale and is now corrected in place rather than deleted.
- **What the skill gained:** table inventory with primary/surrogate/natural keys; a fact → dimension
  **edge list as the primary artifact**, carrying `version resolution`, `evidence` and `confidence`
  per edge with `UNRESOLVED`/`CONFLICTING` as first-class states; dimensional semantics (fact type,
  role-playing, conformed, degenerate, per-measure additivity); a Coverage section; and a
  "Querying this warehouse" section with six read-side rules plus the fan and chasm traps.
- **WSD-032 — the deviation, and why.** Design §3.4 sited the read-side rules in `SKILL.md` only.
  The v0.48.0 arm measured the map opened **6/6** and the `Skill` tool fired **0/6** on exactly this
  task class, so skill-only siting reaches nobody when it matters. Step 9 now copies the section
  into the emitted `docs/warehouse-map.md`. The rules ride the 6/6 channel; costs no static context.
- **§3.5 implemented budget-neutrally, deliberately.** Broadening a `description` is the mechanism
  step 2 §2.2 says the `r=0` observation weakens. The report-writing phrase is added and the
  frontmatter compressed elsewhere: **+96 chars**. The always-loaded Common Tasks line, which still
  described the skill as ETL-only, was corrected for **+2 chars**.
- **Budget after this release: monorepo `static.claude` 47,774 → 47,884 of 48,000 — 116 characters
  left.** Stated because B-98 §5.1's lesson was that static context gets spent incidentally and
  nobody names what it was spent instead of. This was spent on: accuracy of the one always-loaded
  line describing a skill, and one report-writing phrase in its USE FOR.

**Adversarial review (`sol`, independent session): 4 blocking, 6 non-blocking. 8 accepted, 1
rejected, 1 deferred.** The two that mattered:
- Read-side rule 6 was written as an absolute ("never put effective-date predicates on a
  surrogate-key join"). That is **wrong** for a late-binding design where the fact stores a durable
  key shared by every version row — there the temporal predicate is required. Rewritten around the
  real discriminator (does the key identify one version?), which also moved `version resolution`
  from the per-entity loading table onto the **edge**, where it belongs: two facts can reach the
  same Type 2 dimension differently.
- "One row per foreign-key column per fact" permits an **empty edge list**, since an agent may read
  that as constraint-backed only. Confirmed against the ship-gate fixture itself, where
  `fact.FactSales` declares **no** `FOREIGN KEY` — the gate would have graded a map with zero edges.
  Now requires an explicit candidate sweep, with unconfirmed candidates emitted as `UNRESOLVED`.
- Rejected: that `/map-warehouse` names a non-existent command. It is pre-existing convention
  (`bootstrap.md:327`, shipped changelog) and valid on Claude Code; changing it here would have
  desynchronised two lines in the same file.

**New ship-gate instrument: the `warehouse-map-quality` eval scenario.** Criterion 4 ("the skill
emits `UNRESOLVED` where evidence is naming-only") is verified on a produced artifact, not by reading
prose. It grades the content of the emitted `docs/warehouse-map.md` and its fixture starts with **no
map** (`Initialize-WarehouseScenario -OmitMap`). Reuses the B-41 harness — no second harness, per the
design's constraint.

**Verification.** `validate-dist` ×3 EXIT 0; shipped hook suites ×3, 0 failures; eval self-test 20
PASS. The new grader was red-tested on **two axes I chose myself**, distinct from the implementer's:
`edgeRows` threshold 3→99 and a broken `hasQueryRules` regex, both EXIT 1 on a compliant map, then
green on restore. The context ceiling was red-tested (+200 chars of monorepo frontmatter → `FAIL:
monorepo static.claude is 48081 chars, ceiling 48000`) before being trusted green.

**Known-failing, and NOT caused by this change:** the meta suite reports 5 failures, all in
`ReleaseCiWatch.Tests` (`watch-ci.ps1` stub timeouts, `EXIT=3 ... timeout 30s`). This diff touches no
file under `scripts/`, no `watch-ci`, and no release script — verified by `git diff --name-only`.
B-113 records that `68cf0aa` extended the watcher's `ExpectedJobs` and has never had a green run,
which is the likely cause. **Indicated, not independently confirmed on a clean HEAD** — the check was
interrupted. Do not treat this as cleared.

**Still owed:** both behavioural arms pre-registered in `meta/eval-results.md`
(`warehouse-map-quality` n=1, then `warehouse-route-p1..p3` ×2 against the enriched fixture). The
harness refuses to run live unless `dist/` matches HEAD *and* the dist version matches the root
CHANGELOG head — this release satisfies both, so the arms are runnable for the first time.

**And B-113 is fixed in the same release, which is what makes the tag reachable.** CI run
`31168445026` produced all eight jobs — `windows`, `linux`, `windows-hooks (dotnet|angular|monorepo)`,
`linux-hooks (dotnet|angular|monorepo)` — with the six split legs running in **1:21–3:16**. The
15-minute cancellation is gone: `68cf0aa`'s split worked and the Actions outage that masked it has
passed. That also **answers by observation** the question B-113 flagged as *assumed, not observed* —
the `<job> (<value>)` matrix naming is real, so `watch-ci.ps1`'s widened default is correct.

The five failing stubs are fixed **structurally**: `New-Jobs` now derives the leg list from
`watch-ci.ps1`'s own `-ExpectedJobs` default by AST instead of restating it, because restating it is
what drifted. Red-tested both ways — widening `ExpectedJobs` with a new leg (the exact `68cf0aa`
scenario) leaves the suite 18/18 green, and removing the parameter fails loudly rather than silently.
Meta suite: **0 failures across 10 files.**

---

**Also in this release: the gate suite was reined in. 399s → 148s, with no test removed.**

Releasing had become impractical, and a documentation-only skill change was blocked by five stale
stubs in an unrelated CI-watch test. Both halves of that are addressed.

- **Where the time went, measured rather than guessed:** meta suite 399s serial, of which
  `ValidateDist.Tests` was **259s (65%)**; one full `validate-dist` was 28s of checks, of which
  `section-path` was **18.2s (65%)**.
- **The PowerShell `section-path` check was quadratic** — ~2M freshly-compiled regexes per run, and
  a re-read of the cited file on every hit. The **bash twin already did it correctly** and said so
  in its own comment; the twins had diverged and only one was ever optimised. Porting the proven
  strategy across: **18.2s → 2.8s**, identical findings and identical scanned-file counts.
- **`-Check <names>` on both twins.** `ValidateDist.Tests` ran the whole 11-check validator 20 times
  to test 11 checks one at a time; each red case now runs only the check owning its defect.
  **259.1s → 83.2s.** An unknown *or empty* name exits 2, never 0.
- **The meta runner** was a serial loop over 9 already-isolated processes; now throttled-parallel
  with deterministic output ordering. **399s → 148.1s.**
- **The trap, recorded because it nearly shipped:** the first cut of that runner launched all ten
  files at once and measured **1,335s against a 399s baseline — 3.3× slower**. These suites are
  bound by process creation, not CPU, and `ValidateDist.Tests` parallelises its own cases, so
  unthrottled outer concurrency multiplied into hundreds of competing children.
- **`-AllowFailingGate 'File.Tests.ps1=B-nn'`** — deliberately *not* a skip: the file still runs and
  still reports, and only its power to block is suspended. Owning id mandatory; stale waivers and
  unattributable totals are refused; recorded in both the release commit and the tag annotation.
  Diff-based gate selection was considered and **rejected** — this repo has been burned four times
  by instruments that could not fail, and "skip the tests that look unrelated" is that failure mode
  with a build-speed justification.
- **`meta/gate-budget.json`** — B-110's ceiling pattern applied to time: per-stage stopwatch,
  declared ceilings, routed through `Gate` so a breach **fails** rather than prints.
- **A twin divergence found by re-verification**, not by the implementer: `-Check ''` exited 2 on
  PowerShell but ran **all eleven checks** on bash, because `[ -n "$CHECK_ARG" ]` cannot distinguish
  "flag absent" from "flag present but empty". The implementing session had verified under
  PowerShell 5.1 and could not run bash at all, and said so.
## 0.48.0 — 2026-08-06

> **Deliberately untagged.** CI failed on the release commit, so the release process correctly
> withheld `v0.48.0`; the content was superseded by the subsequent green release.

**Verification Rule 11 — "read the repository's own description of a subsystem before writing against
it" — and it is the first shipped rule whose effect on behaviour was measured before it shipped, not
after (B-98 step 2).**

The chain that produced it: B-98 step 1 measured `r=0/6` — across six `sonnet` runs on a warehouse
fixture, the model never invoked `map-warehouse` **and never opened `docs/warehouse-map.md`**, a plain
markdown file one `Read` away, while brute-forcing every table DDL and reporting view by hand. Step 3
then found the roster is write-side by construction: every skill is named for the artifact it
*produces*, so "write a query against this warehouse" was unclaimed by anything.

- **Measured result: `r=6/6` against the `0/6` baseline. Fisher exact two-sided `p≈0.002`.** Same
  scenarios, grader, fixture, model and host; only the rule differs. The threshold (`r≥5`) was
  pre-registered in `.claude/plans/2026-08-06-b98-step2-routing-remedy-design.md` §6 **before any run**
  and was not moved. Full record, including limitations: `meta/eval-results.md`.
- **Ships via the unprotected carrier**, so it reaches already-installed consumers on their next
  update — the delivery path B-97 established and the reason this rule was buildable at all.
- **The `Skill` channel did not move (0/6 both arms).** The remedy **bypasses** skill routing rather
  than repairing it. Recorded as a finding, not smoothed over: B-98 step 2's general question is still
  open, and `map-warehouse` is still not being reached.
- **`usedDeadColumn` did not fall (4/6 → 5/6), as pre-registered.** The fixture map is ETL-only and
  cannot carry the information that measure needs — §6.3 predicted this *before* the runs, which is
  why it is confirmation rather than failure. Moving it needs B-96's map content, now unblocked on the
  reach axis.
- **Two of four pre-registered controls did not take effect** and are recorded rather than dropped:
  run-order randomisation was defeated by the harness selecting scenarios in file order
  (`run-agent-evals.ps1:1043`), and grading was not blinded.
- **Budget:** monorepo `static.claude` 47,354 → **47,774 of 48,000 — 226 characters left.** The next
  always-on addition now requires deliberately raising a ceiling, which B-110 makes a hard failure
  rather than a warning.

Method note worth keeping: the harness **refused** to run against a dirty tree
(*"dist/ differs from the checked-out release"*, `run-agent-evals.ps1:1039`), so the rule was committed
to a branch and measured there before touching `master`. That guard is why this result is traceable to
an exact SHA, and it should not be worked around.

## 0.47.0 — 2026-08-06

**The four Angular authoring skills shipped with no routing clauses at all (B-98 step 3).**
`add-component`, `add-lazy-route`, `add-service` and `add-signal-store` carried a single descriptive
sentence, while every .NET counterpart *and* the Angular `add-tests` carried full `USE FOR` /
`DO NOT USE FOR` clauses. Found by the roster sweep run for B-98 step 3, not by any gate — nothing
asserts that a shipped skill declares its own boundaries.

- Authored once in `src/stacks/angular/files/{.claude,.github}/skills/` as byte-identical pairs.
  Reaches `dist/angular` **and** `dist/monorepo`: the monorepo inherits the Angular authoring files
  directly for these four, so there is no `src/stacks/monorepo/` sibling to update [#1]. Verified by
  normalized compare — an earlier raw `cmp` said "differs" and that was CRLF, not content.
- **Every `DO NOT USE FOR` names a destination that exists**, asserted mechanically: 16/16 resolve
  to a real command or skill in `dist/angular`. Deliberate, because the same sweep found ~12
  *orphaned* exclusions already in the roster (tasks named as out-of-scope with nowhere to go), and
  this change must not add more.
- Context cost, measured rather than estimated — skill frontmatter **is** in the static budget.
  Monorepo `static.claude` 45,824 → 47,354 chars against a 48,000 ceiling (**646 left**); angular
  36,305 → 37,835 against 40,000. A first draft cost 1,709 and was trimmed to 1,530 before landing.
  Monorepo headroom is now thin enough that the next static-context change needs a deliberate
  decision, not an incidental one.

**Found while doing this, and filed rather than fixed here: the context-footprint ceiling is
advisory.** `scripts/context-footprint.ps1:323-331` emits `WARN:` on a breach of 40,000/48,000 and
never exits non-zero; the gate fails only on *baseline drift*, so `-Update` would absorb a real
breach silently. B-64's class — a check that reports but cannot fail — in the one instrument
guarding the budget every static-context decision is weighed against. Filed as **B-110**.

## 0.46.0 — 2026-08-05

**The post-ship review of v0.45.0 (B-103), and the four defects it found.** B-102 was found,
implemented and verified in one session by one model; the review ledger filed the debt automatically.
Paying it turned up **nine findings, five of them live**. B-102's record claimed the parser fix landed
"in all ten shipped `.sh` hooks and the doctor" and "also fixes a false skip". `git show --stat
6eb7752` contains no `route-prompt.sh`, no `framework-doctor.{ps1,sh}` and no test file.

- **B-104 (P1) — `route-prompt.sh` silently routed nothing on Windows.** Its `elif` chain reached
  `command -v python`, which resolves the Microsoft Store alias stub (not an interpreter, exits 49),
  and **an `elif` chain commits to the branch it selects** — so the regex fallback was never
  re-entered. Measured, no `jq` + stub `python`: `EXIT=0` and **zero bytes** before, 1379 bytes of
  routed context after. A second, subtler leg: with a *real* interpreter named `python`, extraction
  worked but the output-encode site still name-probed `python3`, so it emitted plain stdout instead
  of JSON — which Copilot drops. Resolution is now lazy (only when `jq` is absent), memoised, and
  probes by execution.
- **B-105 — the doctor reported the write floor backwards.** With no `jq` and a working interpreter
  named `python`, `guard.sh` returned `EXIT=2` "Blocked write … AKIA…" while `framework-doctor.sh`
  printed `[MISSING] Guard JSON parser — the bash write guard is INACTIVE`. Both twins now implement
  one verdict table; the `.ps1` twin's PowerShell-PATH fallback guess is deleted in favour of
  `CANT-VERIFY`, because that row reports on a hook that runs under bash.
- **B-106 — the fallback branch had no test, and five skips lapsed where it mattered.** New
  sandboxed cases drive the no-`jq` path; the five `command -v python3` skip-guards now probe by
  execution. `ValidateDist.Tests` went from `1 skipped` behind the false message "python3 is
  unavailable on this host" to **0 skipped**. Host-capability skips now print under an
  `INVARIANT-GUARDING SKIPS` heading instead of scrolling past inside a green total.
- **B-107** — comments that contradicted the code beneath them.

Also filed: **B-108** (one resolver, three grammars — *how* B-104 was missed, since the original
change was scoped by grepping one of them) and **B-109** (`no-meta-leak` denies our vocabulary but
not machine-local absolute paths — caught mid-review, when a shipped test harness briefly carried
`C:\Users\…`, which the gate passed without comment).

## 0.45.0 — 2026-08-05

**B-97 (delivery) + B-102 (a P1 found while verifying it).**

- **B-97 — framework-owned rules move to an unprotected carrier.** Verification Rules, Leanness,
  SOLID and Agentic Workflow move out of `CLAUDE.md` into
  `.github/instructions/framework-rules.instructions.md`. `$protected` is unchanged; this routes
  around it rather than through it. **One carrier serves both legs** — Copilot reads it natively,
  Claude reaches it via `@import` — which canary 5 established (`.claude/scripts/canary-single-carrier.ps1`;
  control arm reproduced canary 1, subject positive, zero `tool_use` in either transcript). That
  killed the two-carrier scheme in the plan's rev 1, which duplicated authored content in `src/` and
  collided with [#1].
  - Boy Scout Rule deliberately stays in `CLAUDE.md` (`bootstrap.md:179` rewrites it from the repo's
    debt). Consequence recorded rather than hidden: framework changes to the Boy Scout scaffold stay
    greenfield-only.
  - `AGENTS.md` keeps its inline copy — only Copilot reads `.github/instructions/`, so stripping it
    would delete the ruleset for Codex/Cursor/Gemini/Aider.
  - **B-97 does not fully close.** For an un-migrated Claude consumer this is *discovery*, not
    delivery. The successor question (does a model follow the fresh carrier or the stale inline copy?)
    is stochastic and needs B-98's six-run rule.

- **B-102 — the JSON-parser fallback probed a name Windows does not install.** Every shipped `.sh`
  hook resolved its parser with `command -v python3`; a python.org install on Windows ships
  `python.exe` and no `python3.exe`. With `jq` absent the write guard printed `INACTIVE` and allowed
  the write on a box with a working interpreter. Measured before/after, same input, Python 3.14.5
  present: `exit 0` allowed → `exit 2` blocked. Probe now resolves by **execution** over
  `python3 → python → py`, because the Store alias resolves and exits 49 — a name-only probe would
  select it and fail open *silently*, worse than the original bug.
  - **CORRECTION (2026-08-05, B-103's post-ship review):** "every shipped `.sh` hook" is wrong.
    The commit fixed **five** — `guard`, `session-start`, `audit-trail`, `boy-scout-check`,
    `post-write`. It did **not** touch `route-prompt.sh` (which still selects the Store stub and
    then silently routes nothing — **B-104, P1**), `framework-doctor.{ps1,sh}` (which now reports
    the write floor backwards — B-105), or any test file (B-106). The commit message's "14 files ×
    3 dists" verification names files the commit does not contain. Left visible, not rewritten.

- **Three new `validate-dist` checks**, each red-tested: marker-expansion inventory, section-path
  citation resolution, and carrier-import presence.

**Four defects fixed during verification that the implementer's report did not contain** — all found
by re-running instruments rather than by reading the diff:
1. The `.ps1` marker gate matched only `<!-- @stack:X -->`, so it was blind to the 15 hash-form
   markers in `route-prompt`/`audit-trail`/`.gitignore`/CI — the shipped hooks. Both twins now use
   the composer's anchored patterns; counts agree at 117 (were 102 vs 117).
2. The `.sh` citation check forked a `sed`+`grep` per (line × cited file × heading) and **never
   completed**, exhausting the Git-for-Windows process table, while the `.ps1` twin took 10s. CI's
   linux leg runs that twin. Rewritten as one batched grep pass: 77s, exit 0. Filed as **B-101**.
3. A markdown link in the moved Verification Rule #7 dangled from the carrier's new location
   (B-67's class — nothing gates link targets).
4. `.sh` accepted any non-alphanumeric citation separator where `.ps1` accepts only `>`/`›`.

**New:** `.claude/hooks/tests/UpdateDelivery.Tests.ps1` — `InstallerContract` covered greenfield and
brownfield but never **update**, the mode every existing consumer runs. Asserts both directions of
the contract that must never swap (protected `CLAUDE.md` byte-identical; unprotected carrier
overwritten even when edited), plus the pointer on both surfaces, both doctor rows, post-migration
silence, and brownfield archival. 16/16 both twins; seen red (8 failures) when delivery is broken.

**Filed:** B-101 (gate runtime is measured by nothing — a twin that cannot finish is as broken as one
that answers wrong), B-102.

## 0.44.0 — 2026-08-02

Two instruments that could not fail, and one that was never built. B-74, B-62 and B-80.

**The test harness can now prove it reports failure (B-74).** The v0.41.0 RCA found that
`Write-TestSummary` returned `$null` under Windows PowerShell 5.1, so `exit (Write-TestSummary …)`
became `exit 0` while the summary printed `[FAIL]`. The bug was fixed then; nothing was added that
would have *caught* it. `tests/hooks/HarnessIntegrity.Tests.ps1` now plants a fixture with exactly
one failing test — one, because two or more returned a real integer and were always caught — and
asserts both the file's exit code and the runner's.

Two findings while building it, both the same class it exists to close:

1. **The first cut ran its fixtures under the wrong host.** It used the harness's `Get-PsExe`, which
   prefers pwsh 7 whenever it resolves, so every fixture ran under pwsh 7 even when the suite ran
   under 5.1 — the one host where the defect exists was never the host under test. With the `@()`
   fix reverted, the file passed. It now runs fixtures under `(Get-Process -Id $PID).Path`.
2. **It was scored by the component it tests.** With the defect planted it correctly printed
   `[FAIL]` and then exited **0**, because the summary it used to score itself was the broken one.
   It now computes its own exit code from the recorded results. Every other suite file can trust
   the harness; this one provably cannot.

Verified red-then-green on both hosts: defect planted → 5.1 EXIT=1, restored → EXIT=0. Under pwsh 7
the file is green either way, which is a documented blind spot, not a pass — pwsh returns 1 for the
expression that returns `$null` on 5.1.

**`validate-dist` check 8: hook registrations (B-62).** Nothing read the registration files at all —
check 2 proved they were valid JSON, check 7 scanned only `*.md` — so a registration naming a script
absent from the dist would ship silently, and the consumer-side symptom is a hook that never runs
and never complains. Check 8 resolves every reference in `.claude/settings.json`,
`.claude/settings.windows.json` and `.github/hooks/hooks.json`, requires the opposite-language twin
[#3], and rejects an unsanctioned interpreter. 26 registrations per dist.

**B-62's written premise was wrong, and is corrected rather than executed.** The entry said to fail
on a *bare interpreter name*. That contradicts v0.38.1, which deliberately reverted absolute-path
pinning because `.claude/settings.json` is committed team configuration and a machine-specific path
breaks every teammate. A bare name is the intended shipped value; whether it *resolves* is a runtime
property no build-time check can see, and v0.39.0's `Hook liveness` doctor row already reports that
from the consumer's machine. Check 8 does the build-time half only. **Band judgement: the delivered
check is P2-shaped, not P1** — the P1 severity came from silent dead hooks, which v0.39.0 covers.

Red-tested on both twins against a scratch dist across three defect classes (renamed hook in
`settings.json`; missing target in `hooks.json`; a hook stripped of its `.sh` twin). Both legs
produced byte-identical findings. Extraction is textual and identical in both twins deliberately:
the bash leg's JSON parser is python3-or-jq depending on the box, so parsing there would leave
whichever branch a machine lacks untested. A normalization bug surfaced during the red-test —
translating each backslash separately turned `.claude\\hooks\\x.ps1` into `.claude//hooks//x.ps1`,
which resolves on both platforms and so hid the sloppiness; runs of backslashes now collapse to one.

**`release.ps1` now refuses staged paths outside the repo's known top-level locations (B-80).** The
blanket `git add -A` is deliberate — the stamps, the rebuilt `dist/` and the footprint baseline must land together — but it
also swept in anything else present, and the script printed no manifest. v0.42.0 and v0.43.0 each
shipped a stray worktree gitlink that way. The staged set is now classified before commit: a
mode-`160000` gitlink is a **hard refusal with no escape hatch** (this repo has no submodules), and
a path outside where the repo keeps files refuses unless `-AllowExtraStagedPaths` is passed. The
manifest prints either way, and a refusal `git reset`s the index while leaving the worktree
untouched.

Classification happens *after* staging because that is the only point mode `160000` exists — an
unadded worktree is merely untracked (verified against `90f331d`).

**The allowlist's first cut would have refused every release from v0.39.0 to v0.43.0.** Written from
B-80's own wording (`src/`, `dist/`, `CHANGELOG.md`, the stamps) it produced 10 false positives when
replayed over the last 8 tags — each release touches `README.md`, and v0.41.0 touched
`.claude/hooks/tests/`. It now asks "is this file somewhere this repo keeps files at all?", which is
the actual hazard. `.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1` replays those tags on every
release so the allowlist cannot silently narrow again; it extracts the guard verbatim from
`release.ps1` rather than re-typing it. Red-tested by mutation: narrowing the allowlist and making
the gitlink check inert each turned the suite red.

## 0.43.0 — 2026-08-01

Release-time profiling, prompted by the banner claiming "roughly 30 minutes".

**The banner was the defect.** A measured release is **7.4 minutes** (v0.42.0: 12:52:26 → 12:59:48),
about a quarter of what the script announced. That figure had never been measured. It is now
`5-7 minutes` with a comment requiring re-measurement rather than padding — an estimate that wrong
is what makes a release feel unaffordable and invites skipping it.

**What the profiling found.** The gates are bound by *process creation*, not CPU. Every assertion
spawns a fresh interpreter, deliberately, so each one is a real hook invocation with a real exit
code — roughly 1350 spawns across three dists. Measured on the maintainer box: `pwsh` 265 ms,
`bash` 55 ms, `powershell.exe` 5.1 143 ms. `validate-dist` is 2.3 s and was never worth touching.

Two plausible fixes were measured and **discarded**:

- *More lanes.* A throttle sweep on one dist suite: 160.7 s (4) / 152.6 s (6) / 150.3 s (8) /
  151.4 s (12). It plateaus — process creation serialises, and raw spawn throughput only improves
  ~1.9x from 8-way parallelism.
- *Splitting the 101 s `TwinParity.Tests.ps1`.* Rejected once the sweep landed: splitting moves
  spawns between files without reducing them, so it would have bought approximately nothing. This
  was the plan of record until the data killed it.

**What shipped instead**, all measured:

- Guard's `.ps1`/`.sh` parity moved into `Guard.Tests.ps1`, so each case runs once per twin instead
  of three times total (the `.ps1` leg was executed by both files against the same fixture).
  One dist suite: **150.3 s → 132.3 s**. Red-tested both ways — neutering `guard.sh` and neutering
  `guard.ps1` each produce 44 failures, clean on restore.
- `context-footprint -Update` (~39 s) now runs alongside the three dist legs instead of serially
  ahead of them. It writes `meta/context-footprint.json`, which no gate reads, so there is no race.
- Each dist suite is handed `cores / 3` lanes instead of all three assuming they own the machine.
- Shipped runner lane count is core-aware rather than a hardcoded 4.

Gate phase: **385.3 s → 284.7 s (26%)**, all gates green.

*Correction recorded for honesty:* the merge was initially justified as closing a coverage hole —
the claim that `guard.sh` was never checked against an expected decision. That was wrong. The old
split asserted `ps == expected` and `sh == ps` including exit and streams, so `sh == expected` held
transitively and a fault shared by both twins would still have failed `Guard.Tests`. The merge is an
efficiency and diagnosability change, not a correctness fix.

*What else is exposed:* **B-79** — the maintainer box has only the MSIX/Store build of PowerShell 7,
which starts at 265 ms against native 5.1's 143 ms. PowerShell 7 starting 1.85x slower than 5.1 is
backwards and points at MSIX per-launch overhead. An MSI install is the largest remaining win and
needs no code change. Defender real-time scanning taxes every spawn too; left alone by decision.

## 0.42.0 — 2026-08-01

Started as "does `/docs-sync` keep `docs/warehouse-map.md` up to date?" (it does not — `grep -rn
warehouse src/core/` returned zero). Answering that surfaced three defects of one class: **a
documented maintenance duty with no implementation behind it.**

- **`/rebootstrap` gained Phase 3c, re-confirming `FRAMEWORK-CONTEXT.md > Known Hazard Areas`** —
  making its own frontmatter `description` ("refresh conventions, **hazards**, and mined skills")
  true for the first time. `grep -i hazard` over its body previously returned only that description
  line, in all three stacks. 3c reuses `/bootstrap` 3d-bis verbatim in shape (single-message
  confirmation, the (a)/(b)/(c) status mapping, the skip-all escape, never self-upgrading an
  `[UNVERIFIED]` row) and adds a **referential-drift pass that nothing previously owned**:
  `session-start` parses the `Reviewed` date only, so a `[VERIFIED]` row pointing at a deleted file
  stayed fresh-looking indefinitely.
- **Struck the false `/docs-sync` hazard claim** from `FRAMEWORK-CONTEXT.md:6` and `README.md` in all
  three stacks. The "Detected Framework Packages" half of that sentence was true (Step 4's
  `fwctx-packages` marker), which is why it survived to v0.41.0.
- **Warehouse-map freshness caveat in `add-warehouse-load` step 1**, where the map is read and where
  the damage happens — plus a one-bullet staleness pointer in `/docs-sync` Step 1 via a new
  dotnet-only `docs-sync-warehouse` marker. Angular resolves it to nothing; monorepo gets it through
  the per-marker-name concat fallback with **no monorepo sibling** (verified in the composed output,
  not just traced).
- **`.github/prompts/docs-sync.prompt.md` enumerated four of six steps**, omitting Step 4 and the
  AGENTS.md/rails half of Step 2 — a `src/core` file, so all three dists shipped Copilot a narrower
  workflow than Claude Code ran.

Design record: WSD-027 (site a maintenance duty on the surface whose invocation model matches it).

An adversarial review pass rejected the first draft of this work, which added a full
`/docs-sync` warehouse cross-check step. Four reasons, all recorded in WSD-027: it re-derives grain
and load ordering (warehouse discovery, which WSD-021 declined to automate); `docs-sync.md` carries
no `disable-model-invocation: true`, so a full SQL-tree scan would be model-triggerable against a
command advertised as "read-mostly, safe to run anytime"; it would be the first `/docs-sync` target
with no shipped template or schema; and its own recommended action was "re-run `map-warehouse`",
making the developer pay the scan twice. The shipped fix is roughly a tenth of that diff.

*Why did no gate catch it:* `no-dead-instruction` matches script invocations only; `DocTruth` covers
authoring-repo facts. Nothing checks *"this prose describes that command"* — filed as **B-76**, which
must cover three shapes (third-party attribution, frontmatter self-description, step enumeration),
since a check aimed at only the first would have caught one of the three.

*What else is exposed to the same class:* the deterministic half of hazard-row checking is filed as
**B-77** (`hazard-check.{ps1,sh}`, modelled on `wiki-check`); the four warehouse-map populations that
no signal reaches are filed as **B-78**. Other `checked by /X` / `asserted by /X` phrasings across
`dist/*` were **not** swept — only the exact `refreshed by /docs-sync` string was.

## 0.41.0 — 2026-08-01

Closes B-61: behavioural twin parity covered `.claude/hooks/` but almost none of the shipped
`scripts/`. The gap was found the hard way — `framework-doctor.ps1` and `.sh` once returned opposite
verdicts on the same machine at the same moment and no gate noticed, because running either twin
alone looked healthy.

Writing the harness immediately surfaced three divergences that were **already shipping**, which is
the point of the item rather than a surprise:

- **`metrics.sh` was missing its test-integrity counters**, and by a different amount per stack:
  dotnet lacked `tests_skipped` and `tautological_assert`; angular lacked `tests_skipped_focused`
  and `tautological_expect`; monorepo lacked all four. The PowerShell twins had them throughout, so
  the two twins emitted different JSON key sets. (An earlier draft of this work asserted three keys
  common to all stacks — that was wrong, caught by a second adversarial review pass.)
- **`docs-sync-check` twins printed different prose**: four ASCII-vs-em-dash advisory suffixes plus
  two genuinely different sentences (the CLAUDE.md size NOTE and the README NOTE, which also used a
  different separator).
- **The shipped test harness could not go red.** Under Windows PowerShell 5.1,
  `(… | Where-Object …).Count` on a pipeline yielding exactly ONE object returns `$null`, so
  `Write-TestSummary` returned `$null`, `exit $null` became exit 0, and a test file with exactly one
  failing test scored green while printing `[FAIL]`. Two or more failures returned an int and were
  caught, so this hid precisely the lone-regression case. pwsh 7 returns 1 for the same expression,
  which is why CI and the maintainer box never saw it. Fixed in both the shipped and meta harnesses
  and red-tested under 5.1 (exit 0 before, exit 1 after).

New `tests/hooks/ScriptTwinParity.Tests.ps1` (ships) runs both twins of `template-checks`,
`docs-sync-check`, `sync-agent-files` and `metrics` against one fixture and compares them.
`framework-doctor` gained two non-pending cases, so `Stack toolchain`, `Mirror and version
integrity` and `Audit trail substrate` are twin-compared for the first time — the failing-mirror
case is the one that matters, because the passing branch is trivially identical.
A maintainer-only `ScriptTwinCoverage.Tests.ps1` makes an unclassified twin pair fail, so a newly
added script cannot silently escape coverage.

Contract notes, deliberately narrow: comparison is of the **ordered** `OK:`/`FAIL:` sequence, not a
set — a set would hide ordering and duplication defects. Exactly two normalizations exist, both
commented: `template-checks`' by-design check 6 asymmetry (`.ps1` parses `.ps1` files, `.sh` parses
`.sh` files), and a script naming its own sibling twin. A static assertion fails if the check-6
exemption ever widens. The fixture also asserts which checks it *reached*, after an early version of
it silently exercised only 5 of 7 checks and a planted defect in check 5 failed to go red.

Known limitation, stated rather than papered over: the metrics corpus uses canonically-cased source.
`Select-String` is case-insensitive and `grep -E` is not, so case parity is not asserted — that
belongs to B-59(b), which owns the case-sensitivity policy. Also unexercised: the `Stack toolchain`
row's regex-vs-glob branch, noted in the test.

Housekeeping: the three shipped changelogs still headed `0.40.0 — Unreleased` for a version released
2026-07-31, because `release.ps1` stamps only the root changelog. Dated here; the automation half
remains open as B-54.

## 0.40.0 (2026-07-31)

Closes the delivery half of B-66: the Angular stack shipped **no forms guidance at all**. A
case-sensitive grep for `ControlValueAccessor`, `NgControl`, `FormControl`, `FormGroup`,
`FormBuilder`, `Validators`, `ngModel`, `NG_VALUE_ACCESSOR`, `formControlName` and
`ReactiveFormsModule` returned zero hits across `src/stacks/angular/`, `src/core/` **and**
`dist/angular/`. Forms are the largest surface of a line-of-business Angular app, and this is the
standing defect behind field report #2 (`meta/field-reports.md`), where a developer reported the
model using `@Input()` on a custom form control instead of participating in the forms API.

`/bootstrap` and `/adopt` now carry a `Forms` subsection in the Conventions structure they author,
and `/bootstrap`'s A3 pass probes for it (reactive vs template-driven, where validators live,
whether any component is a custom form control and how it participates). `docs/defaults.md` gains a
matching detect-only `### Forms` section — HTML comments in the house style of `### SSR / Hydration`,
telling the analysis what to observe rather than prescribing a greenfield default. Two shipped
surfaces that asserted the opposite were carved out: `copilot-instructions.md` said dumb components
use `@Input`/`@Output` **only**, and `defaults.md` § Component Design said the same less forcefully.

**Deliberately trimmed, and this is the interesting part.** The plan originally shipped prescriptive
greenfield forms guidance — reactive-over-template-driven, typed forms, and a `NG_VALUE_ACCESSOR`
vs `NgControl` trade-off table — plus an `add-component` skill branch. That was cut after the
`angular-form-control` baseline **passed with no forms guidance shipped** (`meta/eval-results.md`).
The agent self-injected `NgControl`, set `valueAccessor = this`, used `setDisabledState` rather than
an `@Input() disabled`, and commented that this avoids the circular-DI `forwardRef` that
`NG_VALUE_ACCESSOR` would need — the exact hazard the guidance was going to teach. Writing
prescriptive guidance against a probe that is green before the fix would have been shipping on
faith. What ships here is only the part justified independently of the probe: making the framework
*capture* a repo's forms conventions, which it previously could not do at all.

**No eval validates this release.** B-72 records why: the probe's prompt telegraphs the mechanism,
so it cannot reproduce its own field report; and its `cva` signal conflates the correct `NgControl`
pattern with the double-registration circular-DI bug. The grader was also found **defeatable by the
idiom the cut guidance recommended** — `@Input() set disabled(v)` and `disabled = input.required<boolean>()`
both scored PASS while being exactly the reported defect. Fixed and red-tested in `790e42c` before
the baseline ran, which is the only reason the baseline result can be trusted at all.

## 0.39.0 (2026-07-31)

Adds the framework's first observed-behaviour diagnostic. Every check before this release inspected
configuration, but configuration cannot prove that a hook runs. Two real installations exposed that
gap in succession: first a bare `bash` did not resolve, then a bare `pwsh` did not resolve. In both
cases the registrations looked correct while the write guard, build feedback, and audit trail were
inactive.

`session-start` now makes a best-effort write of an ISO-8601 UTC timestamp to
`.claude/.state/last-session-start` whenever it runs. Failure to write the record can never affect
the session preload, and `.claude/.state/` remains gitignored. Both `framework-doctor` twins gained
a `Hook liveness` row: a present record is `[OK]` evidence that the hook wiring is alive and reports
the most recent timestamp; an absent record is `[CANT-VERIFY]` with guidance to check the wired
interpreter and `docs/enforcement-surfaces.md` if a Claude Code session has already been started in
the repo.

This proves only that a hook actually started, not that enforcement works: a live hook can still
fail later at runtime. Absence is deliberately `CANT-VERIFY`, not `MISSING`, because a fresh install
where nobody has started a session is indistinguishable from dead wiring. That preserves WSD-023's
`Exit = 1 iff any MISSING` contract; the new row does not change the doctor's exit code or CI
behaviour.

Instrumentation is deliberately limited to `session-start`. It fires unconditionally, so after a
session its silence is unambiguous. The other hooks depend on user actions; reporting that one of
them had “never fired” would create false alarms when no matching action had occurred.

## 0.38.1 (2026-07-31)

Reverts v0.38.0's installer pinning of hook interpreters to absolute paths. `.claude/settings.json`
is committed team configuration, so recording the installing developer's machine-specific path made
hooks fail for teammates on another OS or user profile. The installers again retain their existing
`pwsh` / Windows PowerShell 5.1 / `bash` selection but write the selected interpreter's bare name.

A pin in `settings.local.json` is not a safe alternative: Claude Code merges hook entries additively
across settings levels and deduplicates only exact command-string matches. A bare registration and a
pinned registration would therefore both fire, running every hook twice.

Corrects `enforcement-surfaces.md`: an interpreter resolution failure kills the controls carried by
the hook and is invisible to the model and framework checks, but Claude Code does show the developer
a non-blocking hook-error notice in the transcript. This is the second field-reported occurrence of
the same class: a bare `bash` silently no-opped, was replaced by a bare `pwsh`, which silently
no-opped. Detection, not a better default, is the actual fix; that work comes next.

## 0.38.0 (2026-07-31)

Fixes a silent failure that disabled every Claude Code hook on a Windows maintainer machine. Hook
registrations invoked the bare name `pwsh`; Claude Code launches them through Git Bash, whose PATH on
that machine ended in a literal unexpanded `${PATH}` token and no longer contained PowerShell.
Every invocation failed command-not-found with exit 127 before the hook could emit anything: no write
guard, post-write type-check, Boy Scout nudge, routing context, or audit trail.

`framework-doctor.ps1` made the failure more dangerous by reporting `[OK] Wired hook shell —
available: pwsh.` and exiting 0. It asked `Get-Command` from inside the already-running PowerShell
process, while the `.sh` twin correctly reported `[MISSING]` from bash on the same machine. This is
the second vantage-point defect in the doctor after the earlier `jq` probe checked PowerShell's view
of a dependency consumed by bash.

The installer now resolves and writes an absolute PowerShell interpreter path into hook
registrations. It prefers `%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe`, the stable app-execution
alias, over the versioned `Program Files\WindowsApps\Microsoft.PowerShell_<ver>_…` executable whose
path changes on upgrade. Existing consumers must rerun the installer to replace bare registrations.

The doctor now reports absolute interpreter paths as `OK` or `MISSING`, and reports a bare name as
`CANT-VERIFY`. It deliberately does not “probe harder from bash”: a bash spawned by the doctor
inherits the doctor's PATH, not the host shell's PATH, and measurement showed it could resolve
`pwsh` even when host-launched bash could not. A diagnostic cannot observe the environment of a
process it does not launch (WSD-026). The remaining `Invoke-BashProbe` use for the Guard JSON parser
row is documented as unsuitable for predicting host-launched resolution.

## 0.37.0 (2026-07-31)

The enforcement half of B-57, split from 0.36.0 because a regex in the write-time guard can hard-block
ordinary C# and that risk should not ride along with prose changes.

The guard blocked xUnit's `[Fact(Skip=…)]` but let NUnit's and MSTest's `[Ignore]` through, so an
NUnit repo got a strictly weaker floor than an xUnit one while the framework advertised a
deterministic backstop. Both twins now also block `[Ignore]`, including NUnit's per-case
`[TestCase(…, Ignore = "…")]` — the direct structural analogue of `[Fact(Skip=…)]` and the pattern most
likely to be reached for.

The pattern is anchored to an attribute-list line rather than matching `Ignore` anywhere, and this
matters: the `.cs` branch is not scoped to test files, so an unanchored pattern hard-blocks
`public enum Mode { None, Ignore, All }` — ordinary production C#. Four properties are load-bearing and
were each verified by execution on both engines before shipping:

1. **Line-anchored** (`^\s*\[`), or the enum above blocks on both twins.
2. **`-cmatch`, not `-match`.** PowerShell's default is case-insensitive and bash's `grep -E` is not,
   so `Handle(evt, ignore, ctx);` would block on Windows and pass on Linux. Twin parity is asserted
   byte-for-byte, so that divergence fails the release.
3. **POSIX bracket syntax in the bash twin**: `]` first in the class (`[](,=]`), and `[[:space:]]`
   rather than `\s`, which BSD grep does not support. An earlier draft used `[\](,]` and `\s`, which
   makes `grep` exit 2 — and because the check is `grep -Eq … && reasons+=(…)`, that silently disables
   the check on the `.sh` twin while `.ps1` blocks.
4. **`=` in the trailing class**, without which `[TestCase(1, Ignore = "flaky")]` is missed.

`[Explicit]` is deliberately **not** blocked. It is a legitimate NUnit marker for opt-in
long-running or manual tests and xUnit has no blocked equivalent; blocking it would make the framework
stricter on NUnit than on xUnit — the mirror image of the complaint that started this. Known limitation,
shared with the existing `[Fact(Skip=)]` check and not papered over: both engines are line-oriented, so
a multi-line attribute list is not caught.

Seven fixture cases were added to the shared table that feeds both `Guard.Tests` and `TwinParity.Tests`,
so they run across both twins and both surfaces. Four are `block=$false` — `[JsonIgnore]`, the enum, a
lowercase `ignore` argument, and `[Explicit]` — because the false positives are the failure mode that
would actually hurt a consumer. Red-tested before the fix (all three skip forms exited 0, with
`[Fact(Skip=)]` exiting 2 as a control) and after (8/8 Claude surface, 9/9 bash twin, Copilot surface
emitting `permissionDecision: deny`).

`enforce-standards` no longer claims the guard blocks only `[Fact(Skip=…)]`, which this change would
otherwise have made false on exactly the NUnit repos it now protects.

## 0.36.0 (2026-07-31)

Stops the framework asserting xUnit at repos that already use something else. A field report from a
brownfield .NET install on NUnit: the reviewer's complaint was that the framework kept pushing xUnit
instead of following the suite already in place. It was right. Verification Rule #10
("Derive, don't assume") already names *test framework* as a category requiring evidence, and
`/bootstrap` Phase 3a already forbids naming an unevidenced technology — but six shipped surfaces
bypassed both and stated xUnit as fact. Brownfield is where it bit hardest: the installer detects
pre-existing AI tooling, `/bootstrap` hard-stops and redirects to `/adopt`, so there is a real window
where `Conventions` is unpopulated and those surfaces are the only thing reaching the model.

This release fixes the guidance half (B-57). `docs/defaults.md` § Testing is restructured into
evidence-keyed blocks exactly as B-35 did for Data Access — a **Detect** step, an **existing suite →
mirror it** block, and a **greenfield only** block that is now the sole home of xUnit + NSubstitute
and of `MethodName_Scenario_ExpectedResult` (an xUnit house style that an NUnit repo has no reason to
adopt). `copilot-instructions.md` drops the unconditional `xUnit + NSubstitute` line for a mirror-first
pair within the file's 120-char-per-rule contract, and `generate-copilot` is told to emit the
*evidenced* framework. `add-tests` gains a Step-1 evidence gate naming Rule #10, and its suite-bootstrap
mode must now confirm the whole solution is test-free before proposing anything — the .NET branch had
hardcoded while the Angular branch already derived the runner from `angular.json`. `enforce-standards`
step 2 becomes evidence-keyed across xUnit (`xUnit1004`), MSTest (`MSTEST0015` — verified against
Microsoft's docs: ships in MSTest.Analyzers 3.3+, severity Info, opt-in from 3.8 and not enabled even
by `MSTestAnalysisMode=All`), and NUnit, which genuinely has no ignored-test analyzer and so gets a
build-failing CI grep instead. `ArchitectureTests.sample.cs` — copied verbatim into consumer repos —
now says how to translate off xUnit, since it would not otherwise compile on an NUnit repo.

The enforcement half ships separately in 0.37.0: the write-time guard blocks `[Fact(Skip=…)]` but lets
NUnit and MSTest skips through, so an NUnit repo currently gets a weaker floor than an xUnit one. It is
split out because a regex there can hard-block ordinary C#, and that risk should not ride along with
prose changes.

Deliberately unchanged: `tests/impact/tasks.json` names xUnit in its prompt, which is a direct
instruction to the agent (and the harness runs against a scratch repo with no suite, i.e. the
greenfield branch), plus the held-constant prompt is what makes A/B scoring meaningful.

Two gaps found while verifying and **not** fixed here. `template-checks` mirrors only Verification
Rules / Leanness / SOLID / Boy Scout — the `## Common Tasks` skills list is ungated and had already
drifted between `CLAUDE.md` and `AGENTS.md` in all three dists with every gate green. Adding a verbatim
section diff is the wrong fix: `AGENTS.md`'s Common Tasks is deliberately condensed. A skill-slug-set
comparison is the right one, logged as B-58. Also, this repo was on a detached HEAD with local `master`
two commits behind `origin/master` (an abandoned scratchpad worktree held the branch) — precisely the
B-53 condition. Resolved by detaching that worktree rather than deleting it.

## 0.35.0 (2026-07-30)

Fixes the Copilot Boy Scout nudge firing on the wrong event. It was originally registered on
`userPromptSubmitted` because Copilot had no known turn-end event and, since CLI v1.0.65 (hardened
in v1.0.76), that event injects `additionalContext` into the model-facing prompt. That meant the
hook ran before the prompt's work, including read-only turns, and could only report the previous
turn's diff. CLI v1.0.72 introduced `agentStop`, the true per-turn analogue of Claude Code's
unchanged `Stop` registration, but its documented output supports blocking rather than context
injection. WSD-024 therefore separates timing from delivery: `agentStop` scans and queues findings;
the next `userPromptSubmitted` delivers them without scanning.

We deliberately rejected `decision: "block"` at `agentStop`: the Boy Scout check is advisory, and
blocking would force extra turns on one surface while still terminating after Copilot's
eight-consecutive-block loop cap. VS Code agent mode remains unverified because agent hooks are
Preview/off by default and may spell the event `Stop`. The shipped hook headers also correct a
long-standing false claim: a Claude Stop hook's blocking `reason` is delivered to Claude as a
system reminder, not shown only to the user (that behavior belongs to the separate `stopReason`).

Fixes `framework-doctor` falsely reporting the guard JSON parser as MISSING on Windows when `jq`
is an extensionless binary, or is otherwise invisible to PATHEXT-based command resolution. The
PowerShell doctor consequently diverged from its bash twin and broke invariant #3 twin parity.
The parser probe now runs from bash's vantage point because `guard.sh` is the component that needs
the parser.

## 0.34.3 (2026-07-21)

Sharpens Leanness rule #7 ("no comments that restate code") with a concrete Bad/Good example in the
always-loaded `CLAUDE.md`/`AGENTS.md` rule set, so agents pattern-match against the rule rather than
an abstract imperative — comment-noise is one of the most persistent LLM habits. Authored once per
stack in `src/stacks/*/snippets/CLAUDE.md/lean-4-8` and its `files/AGENTS.md` mirror; the
`## Leanness` verbatim-mirror gate covers both. Docs-only; no behavioral surface changed.

This is the change developed in parallel on the `claude/lean-rule7-example` branch as a
same-numbered v0.34.1; replayed here as v0.34.3 to resolve the version collision with the
presentation (v0.34.1) and warehouse (v0.34.2) releases that shipped on `master`.

## 0.34.2 (2026-07-20)

Closes a discoverability gap for data-warehouse repos in `/bootstrap`. When A2 detects warehouse
signals and Phase 3a keeps the `map-warehouse` / `add-warehouse-load` skills, the Phase 4 report now
emits a one-line nudge pointing the developer at `/map-warehouse` for a full layer/grain/load-
ordering/idempotency map before their first warehouse change, and names `add-warehouse-load` as the
task-triggered recipe for the change itself. WSD-021 deliberately rejected *auto-running* warehouse
discovery inside bootstrap (it is a re-runnable perf-class task); this is the report-nudge middle
ground, gated on the same evidence that kept the skills, so non-warehouse repos see nothing. dotnet +
monorepo only (angular ships no warehouse skills; it gets a no-op changelog entry to satisfy the
version-stamp gate). Design-reviewed with an adversarial pass — the gate was hardened from
"A2 detected signals" to "Phase 3a kept the skills" (an observable artifact state, not agent memory).

## 0.34.1 (2026-07-20)

Rebuilds the technical presentation after team feedback that v0.34.0 was accurate but too abstract.
The deck now follows one CSV-export feature through the actual installer, bootstrap, session context,
prompt payload and routing output, plan gate, Feature contract, pre-write allow/deny path, post-write
build and audit, subtask tests, review, CI, knowledge updates, and human responsibilities. The
one-page architecture poster is replaced by a functional twelve-stage event trace and operational
failure guide.

## 0.34.0 (2026-07-20)

Adds the technical architecture presentation requested after an adversarial review of the existing
persuasive briefing: a 12-slide offline deck that separates instruction, context, advisory review,
hard local blocks, deterministic gates, and human authority; a printable one-page system map; and a
claim-to-evidence appendix tying strong claims to shipped implementations and tests. The three
distribution READMEs now distinguish the briefing deck from the technical companion.

## 0.33.0 (2026-07-17)

Closes five gaps found by a real onboarding review. Copilot CLI now receives the Boy Scout nudge
through its consumed per-prompt channel; the write guard recognizes fine-grained and all classic
GitHub PAT prefixes while allowing passwordless connection strings; credential-bearing keyed and
URI connection strings remain blocked. The framework-state check now fails an incomplete install
missing the enforcement matrix, and a Bamboo Specs example documents repository-specific wiring.

## 0.32.2 (2026-07-17)

Second CI-linux fix for the B-16 test harness. v0.32.1 fixed the doctor itself (builtin root
resolution — proven: the failing row moved past install-state), but the no-parser sandbox test
still failed on the linux runner: pwsh-created symlinks in the restricted-PATH bin resolved as
"command not found", so the sandbox was empty. The sandbox is now built inside bash (`ln -sf`
with full PATH; only the doctor invocation sees the restricted PATH); the Git-bash copy branch
is unchanged. Dead `UnixTool` helper removed with it.

## 0.32.1 (2026-07-17)

Post-release fix for B-16, caught by the CI linux leg (the Windows-only local runs were green —
MSYS bash tolerates what POSIX bash does not). `framework-doctor.sh` now resolves its own
location with shell builtins only (no `dirname`): under a hostile PATH its root resolution
failed and every subsequent row silently vanished — the exact failure mode a survival-
constrained diagnostic must not have. `FrameworkDoctor.Tests` fixtures now wire a hook shell
that exists on the test host (CI linux has `pwsh`, not `powershell` — the doctor was *correctly*
reporting the fixture's shell as missing), and the no-parser test now asserts install-state
resolution and carries stderr in its failure messages.

## 0.32.0 (2026-07-17)

### Added — B-16: honest developer-machine enforcement diagnostic

- Added `framework-doctor.{ps1,sh}` to report which enforcement prerequisites are verified on
  the current machine, which are missing, and which require a human-observed agent canary.
- The diagnostic reuses the installed pending-state signals and shipped `template-checks`, runs
  without agent machinery, and never claims full enforcement from script-visible facts alone.
- Installer handoff and consumer docs now tell each developer to run the doctor once locally.
  Design: WSD-023 and `.claude/plans/2026-07-17-b16-framework-doctor-design.md`.

## 0.31.0 (2026-07-17)

### Added — B-40: SQL / data-warehouse guidance

- Two new .NET-stack skills, `map-warehouse` (discovery: layers, fact/dim entities and grain,
  load orchestration, batch/watermark control, SCD strategy, partitioning) and
  `add-warehouse-load` (change recipe: follow the existing load pattern, idempotent re-runnable
  loads, no double-loading, SCD handling, partition alignment). Ship to dotnet + monorepo dists.
- `/bootstrap` A2 now detects SQL-project/stored-procedure codebases and data-warehouse signals
  (two-tier evidence, per B-35 doctrine); Phase 3a applies a three-way keep/delete rule for the
  warehouse skills and exemplar-pins `add-warehouse-load`.
- `docs/defaults.md` Data Access gains evidence-keyed raw-SQL and data-warehouse blocks; the
  section preamble widened to file-tree evidence. `add-entity` gained a cross-routing
  DO-NOT-USE-FOR clause for warehouse tables.
- Design locked in `.claude/plans/2026-07-16-b40-sql-dw-guidance-design.md` (WSD-021); plan was
  adversarially reviewed pre-implementation (11 findings folded in, incl. angular changelog
  version-stamp gate and generated architecture.html).

## 0.30.1 (2026-07-16)

### Fixed — B-34: rendered-output parity for hook twins

- Guard messages and Copilot deny JSON now render byte-identically from the PowerShell and bash
  twins. Audit-trail was confirmed to have no model-visible output; its PowerShell comments were
  aligned to the bash house style as a Boy Scout cleanup.

## 0.30.0 (2026-07-16)

### Changed — B-36/WSD-020: testing strategy for repos with no suite

- The testing strategy now handles zero-test repositories end to end: `add-tests` has an
  interactive suite-bootstrap mode, Feature rails name the test-level decision procedure, and
  `/bootstrap` reports suite absence, records a target test shape, and routes the repair as
  Severity-High debt.

### Changed — B-39 phase 2: parallelize shipped hook-test files

- The shipped hook-test runner now executes up to four isolated test-file child processes in
  parallel while retaining deterministic, per-file output and the existing aggregate exit-code
  contract. On the maintainer machine, the .NET suite fell from 136.611 s to 91.999 s (32.7%).

## 0.29.1 (2026-07-16)

### Fixed — B-35: derive persistence guidance from repository evidence

- Implements the locked WSD-020 design: technology-specific rules now require repository evidence;
  .NET data-access defaults, bootstrap analysis, `add-entity`, Copilot guidance, and the Boy Scout
  hook no longer assume EF Core. MongoDB-style async query methods no longer trigger EF-only
  `AsNoTracking()` advice.

## 0.29.0 (2026-07-16)

### Added — B-22: headless `/adopt` (Path A — prepare autonomously, human applies the merge)

Implements the LOCKED design `.claude/plans/2026-07-06-b22-headless-adopt-design.md` (WSD-014,
**Path A**), unblocked now that its hard dependency B-21 D1 (the PR judgment checklist) has shipped.
Closes the last manual step of adoption without breaking the prompt-injection trust boundary that
made `/adopt` developer-initiated. Authored as **three-stack whole-file edits** of `adopt.md` and
`bootstrap.md` (invariant #1 — they are stack whole-file overrides, only the prompt wrapper +
installers are core), plus the two core installer twins (invariant #3). Implemented this session by
principal-engineer direct edit after the intended codex (gpt-5.6-sol) implementer was blocked by the
bypass-authorization boundary (see `meta/LEARNINGS.md`).

- **`adopt.md` gains a normative `## Headless mode` section** (byte-identical across all three
  stacks). When `$ARGUMENTS` carries a `--headless` directive, the workflow **prepares** adoption
  autonomously — auto-branch `adopt-ai-framework`, archive, provenance + adversarial screen, impact
  baseline, PR structuring — and **stages** every proposed `CLAUDE.md`/`TECH_DEBT.md` merge as a
  clearly-marked, attributed, normalized block for a human to apply at PR review. A per-gate
  override table makes each interactive gate's headless behavior normative (skip ambiguous, exclude
  quarantine with no auto-upgrade, record-not-apply the plan, stage-don't-apply merges with the
  `<!-- DEFAULTED -->` marker on 4a contradictions, unset TECH_DEBT severity/effort, never auto-add
  custom commands, commit to the branch only). Everything deferred lands in the Phase-8 report +
  B-21 checklist.
- **The trust boundary is preserved by construction (constraint 2), not by the flag.** Nothing
  derived from an untrusted discovered file is ever *applied* to canonical guidance without a
  person; `disable-model-invocation: true` stays on `adopt.md`/`bootstrap.md`. Works on both Claude
  Code (`claude -p`) and Copilot CLI (its `-p` equivalent), reusing the read-and-execute prompt
  pattern — so the boundary holds even where the flag is irrelevant (Copilot). A restricted tool
  surface (deny network egress / secret access / git-config changes) bounds mid-run exposure.
- **Marker/guard lifecycle:** the install is committed to the **default branch** (precondition);
  headless deletes `.claude/adoption-pending.json` only on the adoption branch, so SessionStart +
  `docs-sync-check` keep firing on the default branch until a human merges the reviewed PR — guards
  release on human merge, not on the headless run.
- **Embedded Phase-7 `/bootstrap` runs headless too (HIGH-2 fix):** the `--headless` directive
  propagates in; `bootstrap.md` Phase 3d-bis no longer stalls — it takes the "skip all — mark as
  unverified" path automatically, writing every candidate hazard `[UNVERIFIED]` onto the checklist,
  never auto-confirming a hazard unattended.
- **Installer twins + marker `nextStep`** now offer the headless entry alongside the developer path
  (`src/core/scripts/install.{sh,ps1}`): the brownfield agent-handoff block tells an installing
  agent it may EITHER hand off to a developer OR run headless adoption (which prepares a PR branch
  for human review and does not auto-merge or open the PR). The `InstallerContract` gate confirms
  the full agent contract still prints in both modes × both twins × all three dists.

## 0.28.0 (2026-07-16)

### Added — B-21: reviewer-profile systemic fixes (judgment items stop scattering and expiring silently)

Implements the LOCKED design `.claude/plans/2026-07-06-b21-reviewer-profile-design.md` (WSD-013).
The reviewer profile (competent engineers, limited AI understanding): the pipeline makes every
AI-architecture call itself; reviewers only answer plain questions about their own code. The
residual gap the design named — judgment-needed items are created with good UX but then scatter
and expire silently — is closed by three deltas. Implemented via a codex (gpt-5.6-sol) implementer
under principal-engineer review (this session); shipped as **three-stack whole-file edits**, not
the single `src/core` edit the pre-merge spec assumed (`bootstrap.md`/`adopt.md`/`FRAMEWORK-CONTEXT.md`
are stack whole-file overrides — the spec's "one src/core edit per artifact" was stale; only the
`session-start` twins are core).

- **D1 — one "Needs a human decision" checklist emitted for the PR/commit.** `bootstrap.md`
  Phase 4 and `adopt.md` Phase 8 now emit a prioritized (~10-cap) fenced block titled
  *"Paste this into your PR (or commit message)"*, each item a plain yes/no question with a file
  pointer. Sources: `<!-- INFERRED -->` conventions, `(c) unsure`/tooling-only hazards,
  adopt-4a contradictions resolved by default, and `origin: discovered` skills. bootstrap
  **suppresses** its block under `/adopt` (Phase 8 is the sole emitter, reusing the existing
  Phase-2b adopt-context signal, M1); bootstrap gains a commit/PR nudge since it has no branch
  step of its own (H2a). adopt Phase 4a writes a durable `<!-- DEFAULTED: … -->` marker at
  resolution time so the choice survives the full `/bootstrap` pipeline that runs between 4a and
  8 (H2b); Phase 8 re-scans it. Empty categories are omitted; all-empty prints one line.
- **D2 — hazard staleness becomes a mechanism.** `session-start.{ps1,sh}` (core twins) parse
  `FRAMEWORK-CONTEXT.md > Known Hazard Areas` and resurface areas whose `Reviewed` date is >90
  days old — real interval math (`cutoff = today − 90d`, ISO-pinned, GNU-`date` guard on the sh
  side per H1; no `date -j`/epoch, avoiding the B-02 skew class). Open items (`[UNVERIFIED]`/
  `[SUSPECTED]`) get an open-question line; `[VERIFIED]` a lighter re-confirm nudge. Excludes
  `[REVIEWED: not a hazard]`, the `_` placeholder row, and files still carrying
  `KNOWN_HAZARD_AREAS_PENDING` (M4). Block lives inside `$body`/`emit_body` so the Copilot
  surface gets it via JSON `additionalContext` (M5). `bootstrap.md` 3d-bis now pins `Reviewed`
  and the not-a-hazard status to ISO `YYYY-MM-DD` (the parser keys on it). Header "keep fast"
  comment updated to include FRAMEWORK-CONTEXT.md + the ~12-row cap (L2).
- **D3 — rendered legend + "merge ≠ verified".** `FRAMEWORK-CONTEXT.md` gains a visible
  (non-comment) one-line ladder legend and the sentence *"Merging the PR does not confirm these
  …"* directly above the hazard table — the prior explanation lived inside an HTML comment that
  never renders in GitHub file view (M3). The `[VERIFIED]/[SUSPECTED]/[UNVERIFIED]` tokens stay
  (machine anchors for D2's parser and 3d-bis's writer).

**Verification:** new `src/core/tests/hooks/SessionStartHazard.Tests.ps1` (19 cases: resurface /
fresh-silent / unparseable-skip / REVIEWED-excluded / placeholder-skip / PENDING-silent /
confirmed-stale lighter nudge / suspected-resurface / twin-agreement / Copilot dual-shape on both
twins) — red-tested against the pre-D2 HEAD hook (no resurface line), green after. Cross-stack
sibling parity confirmed byte-identical (D1/D3 inserts). Gates green: build ×3 + dist freshness;
validate-dist ×3 (markers, template-checks/AGENTS mirror, no-meta-leak, no-dead-instruction);
dotnet dist hook suite 0 failures across 10 files (TwinParity 40/40). Full gate battery via
`release.ps1`.

## 0.27.1 (2026-07-16)

### Fixed — B-37: post-ship review findings on v0.27.0 (team wiki memory)

Post-ship review of `60dd04c` against the locked B-27 spec (WSD-010) found six defects, all
fixed here. Review/verification: Fable 5; implementers: Opus 4.8 (scripts + tests), Sonnet 5
(docs). Full evidence in `meta/BACKLOG.md` B-37.

- **F1 (P1)** `wiki-check.sh` used GNU-only `date -d` — the only occurrence in any shipped
  script — so on BSD/macOS every *valid* `last-verified` FAILed as "invalid last-verified",
  turning macOS consumer CI red via the `docs-sync-check` chain on the first wiki entry.
  Replaced with pure-shell calendar validation (rejects 2026-02-30 deterministically on every
  platform) + a feature-detected 90-day cutoff (GNU `date -d` → BSD `date -v` → skip the
  staleness WARN); the per-entry staleness check is a lexical YYYY-MM-DD compare.
- **F2** Both `wiki-check` twins read `$Root` from **stdin** when no argument was given, so an
  interactive `docs-sync-check` run blocked waiting for a keyboard line (CI survived only via
  /dev/null stdin). The stdin path is removed: root comes from the argument — `docs-sync-check`
  now passes it explicitly — or self-anchors to `scripts/..` like `template-checks`.
- **F3** The sorted-index check was locale-dependent (bare `sort` in .sh vs culture-sensitive
  `Sort-Object` in .ps1 — glibc UTF-8 locales collate hyphens differently, the B-02 skew
  class). Pinned to byte/ordinal order in both twins (`LC_ALL=C sort`;
  `[StringComparer]::Ordinal`); `remember-for-team` step 4 documents the order.
- **F4** Locked-spec omissions (D4/D9) shipped: the "What We've Learned" boundary sentence in
  `CLAUDE.md` and the LEARNINGS-vs-wiki boundary table in `docs/wiki/INDEX.md`.
- **F5** `SessionStartWiki.Tests` now cover the `.sh` hook's Copilot-JSON `additionalContext`
  delivery (jq/python3-gated, skip otherwise); red tests added for the F1 (non-calendar date)
  and F3 (hyphen adjacency) defect classes — both run both twins and assert verdict agreement.
- **F6 (pre-existing, found while verifying)** `_HookHarness.ps1` `Invoke-Hook` decoded child
  stdout with `[Console]::OutputEncoding`, so the em-dash summary-line assertions failed on any
  non-UTF-8 console (reproduced under ibm850) — v0.27.0's "hook suites green" was
  environment-dependent. The capture now pins UTF-8 and restores the prior encoding in
  `finally` — the harness-side leg of the v0.26.5 rendering fix.

Logged-not-fixed (locked design, revisit only on consumer evidence): the D6 injection-marker
list hard-FAILs benign prose descriptions containing `instead of` (observation in B-37).

## 0.27.0 (2026-07-16)

### Added — B-27 team wiki memory (WSD-010)
- New `docs/wiki/` per dist: `INDEX.md` (normative grammar, sorted by slug) + `_template.md`,
  a flat one-fact-per-file team wiki (gotcha/context/recipe/failed-approach) with frontmatter
  (`name`, `description`, `type`, `scope`, `status`, `last-verified`).
- `remember-for-team` skill (human-gated write path: triage/redirect, dedup-before-create, draft
  from template, sorted-insert into `INDEX.md`, honest "draft until PR review" close). Mirrored
  to `.github/skills/` for Copilot parity.
- `wiki-check.ps1/.sh` twins: structural validation (index↔file bijection, frontmatter schema,
  enum values, sort order) plus an injection screen — FAIL on INDEX-line/description-level
  matches, WARN (advisory only) on body-level matches. Wired into `docs-sync-check` (both twins).
- `session-start.ps1/.sh` preload the wiki index (inline when small, summarized above a size
  threshold, silent when absent), on both Claude Code and Copilot surfaces.
- `CLAUDE.md`/`AGENTS.md` companion-preamble line + Common Tasks/self-review pointers to the wiki.
- `install.ps1/.sh`: `docs/wiki/INDEX.md` is copy-if-absent (joins `$adoptionSignals`), everything
  else under `docs/wiki/` copies normally — a consumer's own wiki survives a framework update.
- `adopt.md` D7: `docs/wiki/**` is a **screen-in-place** candidate class — clean entries stay
  where they are (never archived/merged); flagged entries quarantine to
  `docs/pre-adoption/quarantine/` with their INDEX line intact, keeping `wiki-check` red until a
  human resolves them.

### Fixed (found during B-27 implementation review)
- `wiki-check.sh`'s injection-signal character class matched the INDEX grammar's own mandatory
  em-dash under real UTF-8 collation, failing every syntactically valid entry. Rewritten as
  `LC_ALL=C` byte-exact UTF-8 matching, mirroring the `.ps1` twin's codepoint ranges.
- `wiki-check.sh` failed to resolve a native Windows-style root path; now normalizes separators
  (and uses `cygpath` when available) before building `docs/wiki` paths.
- `install.ps1`'s D8 fix had diverged structurally from the `.sh` twin (a full per-file rewrite of
  the copy loop vs. the twin's surgical `docs/`-only special case) — restored to the same shape.
- The shipped `_template.md` carried a leading HTML comment that broke its own frontmatter
  contract the moment it was used literally; removed to match the locked design's D2 template.

## 0.26.5 (2026-07-15)

### Added — B-32 context-footprint gate (WSD-017)
- Added deterministic context measurement and a reviewed-baseline CI gate with advisory ceilings.
- Release automation re-measures the baseline after version stamping.

### Fixed
- Aligned PowerShell session-start and prompt-routing guidance with canonical bash rendering
  byte-for-byte. The new rendered-hook check exposed Unicode, blank-line, and whitespace drift.
- PowerShell hooks now emit UTF-8 whenever their output is captured, preventing Windows OEM
  output encoding from garbling the Unicode guidance.

## 0.26.4 — 2026-07-12

> **The gates that should have caught v0.26.3's defects.** Every gate this repo had was a *parser*
> gate — markers resolve, JSON parses, `bash -n`, PS-AST, twins agree, no meta vocabulary leaks. The
> product is prose aimed at a model, and **nothing tested whether the prose works.** Three defects
> walked straight through. Two of them were mechanically catchable and now are.
>
> Written before the cleanup, red-tested first, per `DEVELOPING.md`: *a gate you have never seen fail
> is not a gate.* Each one found a live defect on its first run.

### Added — `no-dead-instruction` (`validate-dist` check 7, both twins)
Every script a shipped doc tells someone to **run** must exist, resolved from the dist root.
Check 6 (`no-meta-leak`) proves shipped docs don't say the wrong *words*; nothing proved they don't
give the wrong *commands*.
**Found on first run:** a **second, un-noticed instance of the v0.26.3 defect** —
`dist/monorepo/README.md:137` (the update-mode section) still told consumers to run
`bash install.sh` / `pwsh install.ps1`, which do not exist in that dist. I fixed the §1 occurrence
this morning by hand and missed this one. The gate did not.

### Added — `InstallerContract.Tests.ps1` (meta suite)
Runs the **shipped installer for real** — 3 dists × greenfield/brownfield × `.ps1`/`.sh` = 12 installs
into temp targets — and asserts its **stdout** states the whole agent contract: commit the files;
your task is NOT complete until you hand off; do not hand-replicate `/bootstrap`|`/adopt`;
`docs-sync-check` is red **by design**. Asserted as *behavior*, not as prose in a source file — the
only way to catch a mode branch that quietly stops printing it, which is exactly what greenfield did.
Red-tested by regressing greenfield to its pre-v0.26.3 wording: fails on both twins, other dists stay
green.

### Added — `DocTruth.Tests.ps1` (meta suite)
The authoring docs must describe the repo that exists: one version stamp everywhere, README's claimed
version == what's shipped, no phantom marker syntax, every `scripts/…` path in a root doc resolves,
every script `ci.yml` invokes exists. Docs that lie to the *maintainer* are how the next defect gets
authored.
**Found on first run:** `CLAUDE.md:63` pointed at `scripts/template-checks.*` as if it were a root
script. It is per-dist (`dist/<stack>/scripts/`); no root one has ever existed. Flagged by the
adversarial review earlier today and still not fixed until a machine insisted.

### Fixed
- **`dist/monorepo/README.md:137`** — update-mode install command (see above). Shipped.
- **`CLAUDE.md:63`** — `template-checks` path now unambiguous.
- **Both new test files initially swallowed their own failures.** They ended with
  `Write-TestSummary`, not `exit (Write-TestSummary …)`, so the meta runner (which sums
  `$LASTEXITCODE`) saw 0 regardless. `DocTruth` reported *2 failed* while the suite reported *0
  failures* — a gate lying about itself, caught only because the numbers disagreed on screen. The
  established files had it right; the new ones didn't. Fixed and regression-tested: a planted failure
  now propagates to the suite exit code.

### Known blind spot (stated, not solved)
Whether the prose actually **steers a model** is still untested. That needs a real agent driven
end-to-end, which needs standing permission to spawn one non-interactively — a deliberate trade not
taken. The other two v0.26.3 defects (an installing agent mistaking this repo for its target; the
archived repos sending agents to install the frozen v0.25.5 template) were found *only* by driving
agents by hand, and no gate here would catch their like. Recorded in `DEVELOPING.md` so the next
maintainer doesn't mistake green gates for coverage.

## 0.26.3 — 2026-07-12

> Started as "did the merge drop the README's *For AI agents (LLMs)* section?" It did not — §1 is
> intact in all three dists and `git log -S` shows only additions. But the merge **moved the front
> door** (the legacy template repos → this authoring repo), and chasing that turned up a dead install
> command in `dist/monorepo` and an installer branch that under-instructs installing agents.
>
> **The diagnosis was baselined before anything was fixed**, and the baseline killed the original
> hypothesis — see `meta/LEARNINGS.md`.

### Fixed (shipped)
- **`dist/monorepo/README.md` §1 told installing agents to run a command that does not exist.** It
  said `pwsh install.ps1 <target>`; that dist contains only `scripts/install.ps1` (`dist/{dotnet,
  angular}` correctly said `scripts/install.ps1`). Root-installer wording had been copied into a dist
  README during Phase 4 monorepo authoring. Since the root README's blockquote routes readers straight
  into `dist/<stack>`, an agent following that trail hit `No such file or directory` — on the mixed
  .NET + Angular path, i.e. exactly the audience `dist/monorepo` exists for. Fixed in
  `src/stacks/monorepo/files/README.md`.
- **The greenfield branch of the shipped installer under-instructed AI agents relative to brownfield.**
  Brownfield printed a standalone *"IF YOU ARE AN AI AGENT … your task is NOT complete until you have
  done step 1 [commit] and then told the developer … Do not attempt /adopt yourself or replicate it by
  hand"* block. Greenfield printed only a weaker parenthetical: no "or replicate it by hand", and no
  warning that `docs-sync-check` fails **by design** until `/bootstrap` runs — so an agent would see
  red CI and try to fix it. Greenfield now prints the same contract, naming `/bootstrap`.
  Single-sourced in `src/core/scripts/install.{sh,ps1}` [#1], twins in lockstep [#3].
  **Observed, not theorised:** a baseline run (Opus 4.8, cwd = this repo, prompt *"install this
  framework into `<target>`"*) chose the right installer, detected greenfield, was **not** captured by
  this repo's maintainer `CLAUDE.md`, and correctly refused to run `/bootstrap` — but explicitly
  declined to **commit** the copied files in the target. Step 1 of the contract, silently dropped.

### Docs (authoring repo — not shipped)
- **`@@INCLUDE` was phantom syntax.** Documented in `README.md`, `CLAUDE.md`, `AGENTS.md` and
  `DEVELOPING.md`; implemented nowhere. The composer's marker is `<!-- @stack:NAME -->`
  (`scripts/build.ps1:6-7`). Corrected in all four. (The historical v0.26.0 entry below is left as
  written — it is a dated record, not live guidance.)
- **Root `README.md` had no acquisition step.** Every install instruction presumed a local clone the
  reader was never told to make (`grep -i clone README.md` → zero hits). `## Quick start` now opens
  with `git clone`.
- **`fidelity-check` was still described as a live CI gate** in `README.md` and `DEVELOPING.md`. It was
  retired from CI at v0.26.0 (`ci.yml:11-15`); it remains a manual re-audit tool. Corrected.
- Root `README.md` claimed shipped v0.26.1 against an actual stamp of v0.26.2.

### Not done (deliberately)
- **No rewrite of this repo's root `CLAUDE.md`/`AGENTS.md` banner.** The pre-fix hypothesis was that
  the always-loaded maintainer governance captures an installing agent and its unqualified *"commit to
  `master` and push"* would make it push to **this** repo. The baseline did not reproduce either. One
  sample (Opus 4.8, plan mode, .NET target) is not proof — but it is evidence against, and a prose
  change with no observed failure behind it is exactly what this repo's own record warns off.

## 0.26.2 — 2026-07-12

> Hotfix for a defect v0.26.1 introduced, plus the machine check that would have caught it.
> v0.26.1's CI went **red on the linux leg** — the two composers disagreed on
> `dist/{dotnet,angular}/.claude/hooks/post-write.sh`.

### Fixed
- **A lone `0xE2` byte in two `src/stacks/*/files/.claude/hooks/post-write.sh` files.** Introduced by
  a v0.26.1 `sed` whose character class contained an em-dash (`[-—]`). `sed` matches **bytewise**, so
  it stripped the em-dash's two continuation bytes (`80 94`) and left the lead byte stranded —
  invalid UTF-8. The two composers then disagreed by construction: `build.sh` copies the raw byte
  through, while `build.ps1` decodes and re-encodes it into `U+FFFD`. The committed dist matched
  whichever composer produced it, so the *other* CI leg failed the freshness diff. Comment text only;
  the hook's behavior was never affected.

### Added
- **A repo-wide valid-UTF-8 sweep in the meta test suite** (`WorkspaceBom.Tests.ps1`, alongside the
  BOM gate [#4]). Every file must decode under a **strict** UTF-8 decoder — one that throws rather
  than silently substituting `U+FFFD`, since a lenient decode would make the test vacuous. It carries
  a positive control that plants the exact byte sequence this release fixes. This closes a real hole:
  every local gate passed on v0.26.1, and **only** CI's cross-leg rebuild caught the divergence — a
  failure that surfaces far from its cause. It is now caught at the source, locally, before a push.

## 0.26.1 — 2026-07-12

> Seals the meta/product boundary. A sweep of the composed dists found **192 lines of maintainer
> vocabulary in shipped content** (81 dotnet / 83 angular / 28 monorepo), in two tiers. **22 lines
> genuinely installed into a consumer's repo:** tracking ids baked into live shipped hooks, scripts,
> and tests — including a pointer to the maintainer-only `release.ps1`, a script that does not exist
> in a consumer repo. **~170 lines product-visible but not installed:** almost all in the shipped
> changelogs, which were maintainer engineering logs (backlog ids, `WSD-nnn`, the "Fable-exit"
> codename, "lockstep with the .NET twin", links to the archived legacy repos, and a literal
> `_Maintainer-only (does not ship)_` note). The installer excludes `CHANGELOG.md` from the copy, so
> that tier never reached a working tree — but it is the surface a team reads when evaluating the
> framework. **The merge inherited this rather than causing it:** the legacy
> `ai-tech-lead-dotnet/CHANGELOG.md` carries the identical markers, and the v0.25.5 fidelity freeze
> copied them byte-for-byte. Full decision record: WSD-019.
>
> No behavior change — shipped *content* and repo layout only.

### Added
- **`no-meta-leak` — `validate-dist` check 6.** Scans each composed dist against the new
  `scripts/meta-denylist.txt` and fails if the framework's own development vocabulary appears in a
  shipped file. One denylist file, read by **both** the `.ps1` and `.sh` twins, so it cannot drift.
  It denies the *ID* forms (`B-nn`, `WSD-nnn`) rather than the words — `BACKLOG` and `twin` stay
  legal, because the product legitimately reads the consumer's own `BACKLOG.md` and the shipped
  `.ps1`/`.sh` twins are a real feature. The `ALLOW` list is consequently empty. CI already runs
  `validate-dist` per dist on both legs, so no workflow change was needed.

### Changed
- **The shipped changelogs are now written in the consumer's voice** — what changed in *their* repo
  and what they must do. Every version heading is preserved (37 / 38 / 2, unchanged); only the
  framing changed. Safe because the full engineering history is preserved verbatim in
  `meta/changelogs/legacy-*.md`.
- **Tracking ids stripped from shipped code comments** — `post-write.{ps1,sh}` (all three stacks),
  `template-checks.{ps1,sh}` (which also referenced the maintainer-only `release.ps1`),
  `build-architecture-html.ps1`, and four `tests/hooks/*.Tests.ps1`. Each comment now states the
  invariant the code holds rather than the ticket that produced it.
- **Stale pointers to the archived legacy repos removed** from the shipped `README.md`s and the
  monorepo changelog; the cross-stack advice now points at the monorepo distribution instead.
- **The maintainer layer moved to `meta/`** (`BACKLOG.md`, `workspace-decisions.md`, `LEARNINGS.md`,
  `ci-handover.md`, `changelogs/`), and **root `docs/` is gone** — that name belongs to the consumer
  (`dist/*/docs/`). `CLAUDE.md`/`AGENTS.md`/`.claude/` stay at the root because Claude Code loads
  them from there; their "you are in the authoring repo" banner remains the tie-breaker.

### Fixed
- **`validate-dist.ps1` resolved paths against the wrong root after check 5.** The dist's own
  `template-checks.ps1` does a `Set-Location` into the dist and never restores it, so any relative
  path used afterwards broke — on the PowerShell leg only, since the bash twin runs it in a subshell.
  Found by building the new gate before the cleanup. Paths are now resolved up front.

## 0.26.0 — 2026-07-12

> The single biggest structural change in the framework's history: two independently-versioned
> template repos (`ai-tech-lead-dotnet`, `ai-tech-lead-angular`) become one authoring repo,
> `ai-tech-lead`, that composes three installable distributions. The decision, rationale, and
> execution record live in `meta/workspace-decisions.md` (WSD-012 and its Phase 0–6 execution
> deltas, plus WSD-015, WSD-016, and WSD-018). Phase 6
> validation is green (real-toolchain install + `docs-sync-check` across all three dists, the
> monorepo security-overlay smoke, and the composer/validate/hook/meta gates — WSD-018); the two
> legacy repos are archived at this release with pointer READMEs, frozen at their last independent
> release, v0.25.5.

### Added
- **One authoring repo, three installable distributions.** Shared framework content — skills,
  commands, agents, hooks, `CLAUDE.md`/`AGENTS.md` templates, scripts — is now authored **once**
  under `src/`, and a deterministic composer emits `dist/dotnet`, `dist/angular`, and
  `dist/monorepo`, each a complete, installable, single-stack (or mixed-stack) copy of the
  framework. Composition is concat-by-default with authored overrides where stacks genuinely
  diverge (`@@INCLUDE` markers in `src/core`, per-stack snippets/whole-file overrides under
  `src/stacks/<stack>/`) and an explicit-collision-is-an-error rule for the monorepo dist — no
  silent last-wins when the same path exists in more than one stack (WSD-015).
- **`dist/monorepo` — a new distribution for mixed .NET + Angular repos.** Previously a consumer
  with both a .NET backend and an Angular frontend in one repo had no first-class option; this
  dist carries the union of both stacks' content, with 111 authored merged/sectioned snippets and
  38 authored whole-file overrides where union-by-default wasn't safe (WSD-015). 148 files total.
- **Root installers with stack auto-detection.** `install.ps1` / `install.sh` at the repo root
  are thin wrappers: they resolve the target's stack (explicit flag → an existing update stamp →
  auto-detection from `*.csproj`/`*.sln` vs `angular.json`, checked at the root and two levels
  down → both found routes to `dist/monorepo` → neither found exits with a clear ask for the
  flag) and then delegate to the chosen dist's own byte-frozen installer. No install logic is
  duplicated outside `dist/`.
- **Full git history preserved from both legacy repos.** The merge used `git filter-repo` to
  relocate each legacy repo's history under `legacy/{dotnet,angular}/` before merging with
  `--allow-unrelated-histories` (zero conflicts — the trees were disjoint at merge time); `git log
  --follow` on any long-lived file (e.g. `CLAUDE.md`) traces back through the merge to its
  original v4.0 commit in whichever legacy repo it came from.

### Changed
- **Zero shipped-behaviour change, proven by a strict fidelity gate.** Every one of the 138
  tracked files in each legacy repo (dotnet, Angular) reproduces byte-for-byte (EOL-normalized)
  from the new `src/` composition — `scripts/fidelity-check.ps1/.sh` diffs the rebuilt
  `dist/dotnet` and `dist/angular` against the `freeze-v0.25.5` tags taken on both legacy repos
  before any restructuring began, with an **empty allowlist** (no version-stamp or
  stack-flavoured exclusions needed). This is the migration's central acceptance criterion: a
  consumer already running v0.25.5 of either template gets an update, not a behavior change, when
  they eventually move to a dist built from this repo.
- **The workspace meta-development layer moved into this repo (D7, WSD-016).** The maintainer
  workflow for developing the framework itself — previously governed by a separate, untracked
  workspace root one level up — now lives here: root `CLAUDE.md`/`AGENTS.md`/`DEVELOPING.md`
  (rewritten for single-repo composition instead of dual-repo lockstep), the `bom-fix` hook +
  its meta test suite, `meta/BACKLOG.md` and `meta/workspace-decisions.md` (this repo's ADR
  log), and the maintainer's `.claude/plans/`. The two-repo-specific `check-lockstep.ps1` gate is
  retired — its job is now structural (one source, three composed dists) rather than a
  cross-repo diff.
- **Shipped CI workflows use `actions/checkout@v5`.** The `template-ci.yml` and
  `docs-sync-check.yml` workflows that install into consumer repos were bumped from
  `actions/checkout@v4` to `@v5` (GitHub's Node 20 runtime deprecation). This is the first
  release to deliberately change shipped content since the freeze, so it also retires the
  authoring repo's strict fidelity-check CI legs (dist == `freeze-v0.25.5`) — the freeze tags
  are no longer the baseline; `src/ → dist/` freshness (rebuild + diff) plus per-dist
  `validate-dist` and hook suites remain the CI guardrails.

### Notes
- Phase 6 (`MERGE-MIGRATION-PLAN.md`) validation completed green (WSD-018); the two legacy repos
  — `ai-tech-lead-dotnet` and `ai-tech-lead-angular` — are archived at this release with pointer
  READMEs directing consumers here. They remain readable, frozen at v0.25.5.
- Legacy framework history predating the merge: [`meta/changelogs/legacy-dotnet.md`](meta/changelogs/legacy-dotnet.md),
  [`meta/changelogs/legacy-angular.md`](meta/changelogs/legacy-angular.md).

---

## How to update this changelog

- One section per release (or per "Unreleased" working window). Date the heading once released.
- Group entries by **Added / Changed / Fixed / Removed / Decided**.
- One line per change. Reference the file or workflow touched, not the implementation detail.
- Framework-level decisions (the merge, composition rules, hook semantics) go in
  `meta/workspace-decisions.md`; this file is the consumer-facing summary of what shipped.
