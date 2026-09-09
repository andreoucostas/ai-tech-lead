# B-233: actionable consumer upgrade checklist

Status: LOCKED after Opus ACCEPT and root adjudication; implementation by Sol authorized.
Baseline: `fd6e40b1cd370c100c04d3b3346c132f691500b5` (v0.86.2).
Authority: the user requested a plan, Opus adversarial review, then Sol implementation.

## Problem, value and proportionality

The three consumer READMEs bury required manual upgrade actions in their Framework
versioning paragraphs. The installer leaves existing protected instructions untouched,
including an old Boy Scout touched-file mandate. It updates the framework rules carrier,
but file arrival does not reconcile local rules or regenerate their derived mirrors.
The current README/CHANGELOG are excluded from installation, so a README-only improvement
would not arrive in an installed consumer repository. These are observed source facts;
confusion and reduced rework are plausible effects, not measured consumer outcomes.

Add one short shared guide that installs through the existing composer/manifest and link
it from each distribution's README. This makes the existing manual upgrade contract usable
without changing ownership, automating policy decisions, or adding an updater command.
Alternatives: retain the dense paragraphs (no new surface, same navigation burden); reformat
only the READMEs (smaller but absent from installed consumers); add a migration assistant
(more mechanism and policy risk than this source-backed need justifies). Select the guide.

This delivery covers the recommended upgrade checklist only. Quick Start restructuring,
knowledge-capture examples, read-recovery, live model studies, and other workflow defects
are outside this contract. Do not add a permanent test solely to assert prose wording.

## Locked delivery contract

1. Author `src/core/docs/upgrade-checklist.md`, aiming for at most 100 lines. Keep the
   checklist single-source and human-readable, with numbered steps and short before/after
   examples. It must work for dotnet, angular, and monorepo consumers.
2. Replace each stack README's dense Framework versioning migration guidance with a short
   pointer and essential version authority facts. The shared guide carries the full existing
   ownership/migration obligations. Review all three siblings. Do not change Quick Start.
   Add exactly one literal `Write-Output` line in the existing installer update-completion
   branch pointing readers to `docs/upgrade-checklist.md` for protected-rule reconciliation
   and verification. This makes the installed guide discoverable without changing control
   flow, mutation, ownership, or any greenfield/brownfield output.
3. Explain that the installer is run from a fresh **matching distribution directory** in a
   framework checkout, against a separate target repository. Show `scripts/install.ps1`
   with `-Target 'C:\path\to\consumer-repo' -WhatIf`, then the real invocation without
   `-WhatIf`, with native PS7 and PS5.1 alternatives. No root-wrapper flag assumptions,
   no downloading/running remote scripts, no automatic downgrade/dirty-tree overrides.
4. Start from the installed JSON stamp and incoming release notes in the framework checkout.
   Preserve local changes before applying, including committed customizations to overwritten
   files. Use the ownership manifest for classification: existing protected consumer content
   is left untouched, framework-owned files are replaced, mixed settings are backed up at
   `.claude/.state/settings.json.pre-update` and refreshed/adapted. Review and reapply intended
   settings selectively; never advise restoring the complete old file over new registrations.
   Preview is a file-operation plan, not a content diff or assurance the real update will pass:
   `-WhatIf` skips the real apply's Git-state guard. The real update needs its normal preflight.
   Review all `PLAN` categories, especially `replace` and `delete`, before apply. Read and
   retain installer output, including `MIGRATION`, `CANT-VERIFY`, and `NOTICE` diagnostics;
   follow their specific instructions, preserve intentionally retained dependencies, and
   record unresolved uncertainty. A nonzero refusal must be resolved before retrying; an
   advisory preservation notice does not require deleting files or forcing every notice away.
   Do not duplicate an exhaustive protected-path list. Legal-file collisions can refuse a
   preview/apply; follow the diagnostic rather than altering ownership markers to force it.
   Inspect `create` too: missing protected paths receive templates, so recover unexpectedly
   missing populated rules before applying rather than treating placeholders as project rules.
   Do not imply backup directories are fresh snapshots of every update. Review the actual
   settings diff, including host-selected settings; preview is not a final-content comparison.
5. Give conditional, reviewable local-rule reconciliation rather than blanket replacement:
   - Older installations missing the carrier import: compare the four old framework headings
     (Verification Rules, Leanness, SOLID, Agentic Workflow), retain deliberate project-specific
     requirements in consumer-owned content, add
     `@.github/instructions/framework-rules.instructions.md`, and remove only superseded
     framework copies. Never erase customized sections indiscriminately or edit the carrier.
     Explicitly retain `Conventions` and `Boy Scout Rule`: neither is one of the four carrier
     headings. Preserve deliberate consumer additions before removing old framework copies.
   - Old touched-file cleanup rule: show the legacy intro, the "do these on every touched file"
     heading, and the skipped-cleanup TODO mandate together; changing only the intro leaves
     contradictory instructions. Label the BEFORE wording an example, not an exact-match
     migration detector. For a team adopting the shipped default, use the current source's
     `**Bug-fix scope.** See the framework-owned workflow scope.`, scope the Always-apply
     heading to it, and remove the obsolete skipped-cleanup TODO requirement. Explain outcome,
     compatibility, and verification boundaries. Keep applicable local numbered items and
     intentional team mandates; do not copy all fresh template conventions into the target.
6. After source reconciliation, align the protected CLAUDE.md version/applied header with the
   installed authoritative JSON stamp and run `/generate-copilot` in the target agent session
   to regenerate AGENTS.md and `.github/copilot-instructions.md`. Never hand-fix derivatives
   or overwrite populated CLAUDE.md with the template. Updating alone does not run bootstrap;
   unresolved adoption/bootstrap state must follow its existing workflow, not marker deletion.
7. End with target-root doctor and docs-sync-check invocations (both Windows host alternatives),
   diff review and commit. Treat checks as framework checks, not application verification or
   proof of agent-host rule consumption. Link existing enforcement-surface guidance for the
   latter. Resolve findings or inability to examine before reporting upgrade verification done.
   Keep the guide concise; no new readiness dashboard, parser, hook or script behavior.

## Verification and release

Sol implements only after Opus review is adjudicated and this plan is locked. Sol reads the
canonical root guide, developing runbook, and standing index. Product edits are only the new
shared guide, the three README versioning sections, the one literal installer update-output
line, and required release metadata/changelogs.
Generated distributions/ownership manifests are rebuilt, never hand-edited. Target patch version
is 0.86.3 if still available when implementation starts; no concurrent writer is assumed.

Before full gates, review guide commands against actual installer/checker parameters and source
semantics. Use a disposable consumer update smoke on direct PS7 and PS5.1 at CP437: preview leaves
target bytes unchanged, real update delivers the guide and retains sentinel protected content,
and a deliberately dirty Git target permits preview but refuses real apply unchanged. This is
release-specific hostile/clean evidence for the documented distinction, not model comprehension.
Use existing fixture infrastructure where feasible; no new general harness or persistent gate.
Check every new relative link in each generated distribution and guide. Existing representative
installer/update suites provide native-host evidence; the release script owns the complete local
gates, followed by required eight-context Windows CI and case-count parity before tagging.
Also observe that each generated manifest classifies the guide as `framework-owned/overwritten`
and the real update's output points to the guide that actually arrives. Extend the one-off smoke
for these checks and rerun the baseline before implementation; retain the older baseline as its
own result series. Verify the AFTER example against the current template and preserve the exact
canonical pointer. No installer function or branch behavior may change beyond the output line.

Freeze an implementation commit/range. A separate nonimplementer session reviews the contract
and immutable sources before the implementer narrative, states a threat model, and examines:
customized old headings, intentional cleanup policy, already-current import, PS5.1-only host,
dirty preview versus apply, pending adoption, and file arrival versus rule consumption. Root
observes focused native checks directly and adjudicates findings; no reviewer self-report becomes
an observed execution claim. Supply the actual review/evidence and gaps to normal release tooling.

Record B-233 and RCA in the backlog, moving it to BACKLOG-DONE only on delivery; record the
decision and any learning in existing meta records. Commit and push master through normal release
tooling. Do not claim productivity benefits, uptake, or complete consumer adoption from doc/tests.

## Review dispatch status

Frozen proposed contract SHA-256:
`7AA802E35FE07EFCC8489C1B0618123638CD485117600F71291B7A440E10C6F4`.
Packet: `$env:TEMP/ai-tech-lead-b233-upgrade-20260909/`.
The first Claude CLI 2.1.260 Read-only safe/restricted request for `claude-opus-5`
could not connect: session `ddd15a7c-eb57-45ea-be2b-d40bac188225`, process exit 1,
`is_error: true`, reported cost USD 0. No critique was produced (the result's
`subtype: success` is not review success). Automatic approval review rejected the
network-enabled retry because it classified the packet as private repository source
and required explicit authorization to send it to Anthropic. The user has been asked
for that authorization; no alternate export route or implementation proceeded.

## Local preparation evidence (before implementation)

Root inspected the external one-off `upgrade-smoke.ps1` prepared by the read-only
source-audit agent, configured a fixture-specific Git exclude path to avoid ambient
inaccessible global-ignore state, and corrected its local native-exit variable shadowing.
The first two attempts returned CANT-VERIFY before installer execution; their logs remain
as `baseline-ps7.log` and `baseline-ps51.log`, not product red evidence.

Root then directly executed the corrected script on native PS7 and native PS5.1 at CP437.
Each completed 59 assertions with exactly three failures (the absent guide in each dist),
zero cannot-examine outcomes, and exit 1. Both observed clean and dirty previews preserving
the full target tree, real dirty apply refusing with exit 4 without changing the tree,
and clean apply preserving the three protected rule sentinels and copying the incoming
JSON stamp. Logs: `baseline-corrected-ps7.log` and `baseline-corrected-ps51.log` in the packet.
This establishes the pre-change installation oracle and the documented preview limitation;
no guide, rule reconciliation, Opus critique, or consumer model outcome has been delivered.
The fixtures remain in the packet's GUID-owned run directories; no deletion was performed.

## Approved Opus reviews and adjudication

The user explicitly approved sending the plan and relevant repository files to Anthropic.
The authorized first completed Claude CLI 2.1.260 / `claude-opus-5` high-effort Read-only
safe/restricted review returned REVISE: session `46c435fd-ff56-4077-bba2-178bfcaea2a7`,
exit 0, `is_error: false`, reported list-price USD 1.190815. Root accepted explicit retention
of Conventions/Boy Scout, a single update-output guide pointer, preview-category/diagnostic
guidance, manifest ownership verification, and removal of stale exhaustive ownership lists.
Root and the independent source-audit agent checked the proposed corrections against source.
Rejected the claims that deletion is the only irreversible/visible operation, every advisory
must disappear before commit, licence comparison is raw-byte based, or any modified NOTICE
is refused. The revised contract records the accurate distinctions.

Revised contract SHA-256 `236E0F82D82154F04879577A1AB6ACF756797C6FEBAFFFC2653B83DB2DCC9002`.
A fresh Opus review returned ACCEPT: session `4854626c-8307-4707-b2ee-8046c1b97d11`,
exit 0, `is_error: false`, reported list-price USD 1.187085. Receipt is
`revised-design-review.jsonl`; exact source filenames were supplied, resolving the first
reviewer's failure to locate the template. Both reviews ran no tests. The second review's
content clarifications are applied as follows: inspect unexpected protected-path creates;
keep the installer pointer literal; do not promise a fresh backup on every update; and
review final host-selected settings. The plan already makes the installed JSON authoritative.
Do not add a blanket rule to restore intentionally absent files, or call the PLAN target list
wrong merely because it does not describe every host-adaptation copy. Direct PS5.1 execution
is valid host evidence but does not establish the pwsh-unavailable adaptation branch on this
machine; that branch remains unexercised by this task's smoke. The first review's claim of
byte-identical complete README versioning sections is not adopted; all siblings were inspected.

Root extended the external smoke for the literal output pointer and manifest ownership, then
reran the unmodified product baseline on native PS7 7.6.5 and PS5.1 5.1.26100.9444 at CP437.
Each completed 65 assertions, exactly 9 expected failures (absent guide, manifest entry, and
output pointer for each dist), zero CANT-VERIFY, exit 1. These are the applicable RED receipts:
`revised-baseline-ps7.log` and `revised-baseline-ps51.log`. The final script SHA-256 is
`265815AEAA0F10297CA55E8FC173CDFF7FDBA12F53FA650C1CCF54709C973058`.
The earlier 59-assertion series remains historical, not pooled. Sol implements next; root
will observe the candidate's clean rerun before independent implementation review and release.

## Frozen implementation and root verification

Sol implemented and committed `3dbfa84c120b1525b24d3f331d355a80a44deb3f` on master.
The immutable range starts at `fd6e40b1cd370c100c04d3b3346c132f691500b5`.
Root independently inspected the complete range: the 99-line shared guide, the three README
versioning sections, exactly one literal installer update-output line, four changelog heads,
required meta records, and composed distributions/manifest additions. Installer BOM is retained;
no function, branch, ownership policy, or greenfield/brownfield output changed. Root's
`git diff --check` and guide/source parity, relative-link resolution, and manifest classification
checks passed. A first ad-hoc link check incorrectly required `./`; the valid equivalent relative
links resolved after correcting that instrument, without any product change.

Root directly ran the unchanged 65-assertion smoke at the frozen commit on PS7 7.6.5 and native
PS5.1 5.1.26100.9444, both CP437. Each reported 65 assertions, zero failures, zero CANT-VERIFY,
exit 0. All nine baseline delivery failures became passing observations. Preview/apply refusal
controls, guide bytes, protected sentinels, output pointer, manifest class, and stamp arrival
were exercised on all three distributions. Candidate log SHA-256s:

- `candidate-ps7.log`: `DA9C6861909531BC019159144D71ED1373B0500B3E78A20FCE11B1E33902290B`.
- `candidate-ps51.log`: `406D95920F66E1A5B177FBA8AFC1EE8991F248087C2A16BC85D20F7658FC20D4`.

The independent implementation packet contains the contract without prior design verdicts,
immutable range, full authored product diff and baseline/final sources, then separately labelled
root execution evidence. Authored diff SHA-256:
`909F872A6F8E753D9DF71B6CE864B7AC17297FB286AD807C013EE7231F8654CC`.
Implementation-review contract SHA-256:
`D51DF69429770480A644FADFE744253963D36A304CFC8C59562178EA8F5D2749`.
Normal release gates, CI, and tagging remain subsequent obligations; no consumer model
adherence or pwsh-absent adaptation is claimed.

## Implementation review and bounded amendment

Fresh nonimplementer Claude Opus 5 high, CLI 2.1.260, Read-only safe/restricted session
`0265f5a5-aede-493a-aa18-1cdb330b9cf6` returned ACCEPT with two non-blocking checks; exit 0,
`is_error: false`, reported list-price USD 1.269863. Root inspected the actual ordered
text/tool events: contract and immutable range first, explicit independent threat model
before source/diff reads, source analysis before separately labelled root receipts. No
implementation participation or test execution by this reviewer is claimed. Raw receipt:
`implementation-review.jsonl`. Total reported cost of the three completed Opus reviews for
this delivery is USD 3.647763; the refused initial connection reported USD 0.

Root verified the first concern: all three authoritative JSON stamps contain `version` and
`applied`, so the guide correctly directs consumers to copy both fields. No change there.
For the second, Sol named `dist/dotnet`, `dist/angular`, and `dist/monorepo` explicitly in
the introduction, then recomposed and froze `9d6f06cd18736a2cc5771206422db530519ab575`.
Root checked the actual SHA and amendment range from `3dbfa84`: only the guide introduction
and its three generated copies changed in the product, plus the preceding root evidence
record. The guide is 100 lines. The reviewer described a framework-root invocation as a
manifest refusal; the source guide actually names `scripts/install.ps1`, absent at that
checkout root. The practical wrong-directory ambiguity is real, but that precise exit-path
claim is not adopted. The amended locator removes the ambiguity without altering commands.

The reviewer contrasted a dirty, customized legacy consumer with a valid clean current
consumer, and checked PS5.1 command alternatives against source. These are source-reasoned
cases, not observed manual migration or pwsh-absent execution. A separate nonimplementer
Codex session is reviewing only the frozen locator amendment; root is rerunning final native
delivery checks before handing verified evidence back to Sol for normal release promotion.

## Final acceptance for promotion

The separate nonimplementer `/root/amendment_review` Codex session accepted the immutable
`3dbfa84..9d6f06c` amendment after stating its threat model before inspecting that range.
It verified the final guide and all required distribution paths, unchanged product scope
outside the intro, identical Git blob `07daa63b6417126770598e9ec073799f6b1c6d48` for source
and all three generated guides, and the actual `applied`/`version` fields in all three
frozen stamps. Its exact inherited backend model identifier was not exposed; it ran no
tests and made no edits. This bounded source review complements the independent Opus
main implementation review rather than replacing it.

Root observed the final native reruns at `9d6f06c`: PS7 7.6.5 and PS5.1 5.1.26100.9444,
CP437, each 65 assertions / 0 failures / 0 CANT-VERIFY, exit 0. Final log hashes:

- `final-ps7.log`: `0B22933A5D851587E8B52B359087ACC9F29C201881DF13350440E1CE315A0A7C`.
- `final-ps51.log`: `54D2E105B2F1311D8DFFB5C359B4BB3DED5A21E8459569DAC2CB715AD52FBA44`.

Root supplies the combined frozen review/range, actual RED and final GREEN, identities,
environment and gaps to Sol for normal v0.86.3 release. All earlier execution/model limits
remain; promotion results must come from the release command and required CI, not this note.

## Pre-publication local gate checkpoint

The attempted normal release command was rejected before process creation by automatic approval
review because explicit user authority for commit/push/tag publication was not established in this
task. No stamp, release commit, push, CI watch, tag, or release log resulted. Publication remains
paused pending that approval; no alternate release or `-NoPush` route was attempted.

Sol repaired the documented Windows PATH and ran only unaffected checks on the pre-stamp v0.86.2
tree. Full `validate-dist.ps1` for dotnet, angular, and monorepo each exited 0. The deterministic
`.claude/evals/tests/AgentEvals.Tests.ps1` self-test exited 0. The full root meta suite exited 7.
Visible output identified one `DocTruth.Tests.ps1` failure: its B-231 assertion still demanded the
protected/update-carrier distinction in each README after B-233 moved the full contract into the
linked installed guide. It also identified five `RootInstallerWarehouse.Tests.ps1` failures after
the sandbox denied creation of fixture directories beside the workspace. Those denials are an
examination-environment gap, not a product defect. The captured console stream was truncated, so
the six visible failures are not asserted to exhaust an aggregate exit of 7. No gate/source repair
or rerun followed. Exact exits are in external `local-prepublish-exits.txt`; per-command transcript
files exist, but PowerShell transcription did not capture the native child process output. Root's
already-green 65-case focused smoke was not repeated.

## README ownership clarification

Root observed the targeted DocTruth baseline at frozen `9d6f06c` on both native hosts: 15 passed,
exactly one failed, 0 skipped, exit 1, naming the missing protected/update-carrier distinction in
the shortened READMEs. Logs: `readme-red-ps7.log` and `readme-red-ps51-executable.log`. An earlier
PS5.1 launch without `-ExecutionPolicy Bypass` refused to execute and is retained separately as
cannot-examine, not red evidence.

Sol added one concise sentence to each authored Framework versioning section: existing `CLAUDE.md`,
`AGENTS.md`, and `.github/copilot-instructions.md` are protected consumer paths, while
`.github/instructions/framework-rules.instructions.md` is framework-owned and updates
automatically. The shared installed guide remains the detailed reconciliation authority. All three
distributions were recomposed; no gate or other product file changed. Direct targeted
`DocTruth.Tests.ps1` runs then reported 16 passed, 0 failed, 0 skipped and exit 0 under PS7 7.6.5
and PS5.1 5.1.26100.9444 with `-ExecutionPolicy Bypass`. Logs:
`readme-green-final-ps7.log` and `readme-green-final-ps51.log`. Release promotion is still pending.

## Final local checkpoint and publication boundary

The independent nonimplementer `/root/amendment_review` accepted the second immutable amendment
`9d6f06c..2da4bf3071c49b4130e1b92928674abfd6325cf6` after its prior threat model. It checked
existing-path preservation versus carrier refresh, missing protected paths, derivative generation,
and the guide's authority. Root independently verified the six README blobs in matching source/dist
pairs and the four named ownership entries in every manifest. No installer or gate changed in the
amendment. This review was source-only; no reviewer execution is claimed. Root also observed full
distribution validation exit 0 for all three final README variants.

Root's full PS7 local meta run with access to sibling fixtures completed 36 suites and a 379-case
manifest, aggregate exit 2. The only failing top-level RESULTs were InstallerConvergence and
RepositoryPrivacy; intentional mutation reds inside passing suites were not counted as failures.
RootInstallerWarehouse passed 6/0 with fixture access. One dangling-symlink case in UpdateDelivery
was explicitly skipped because this host could not construct it. The log and case manifest are
`amended-meta-ps7.log` and `amended-meta-ps7-counts.tsv` in the external packet.

The convergence failure was a PowerShell exit 64 before the installer could execute: its script
path was temporarily absent. This run overlapped the README recomposition; the composer deletes
and recreates each dist, which supports a build-race explanation but does not timestamp-prove it.
After composition stopped, root observed the unchanged InstallerConvergence suite at 20 passed,
0 failed, 0 skipped, exit 0 (`stable-installer-convergence-ps7.log`). Do not rebuild the shared
distribution while suites execute against it.

The privacy failure correctly found a concrete private temp path in this plan. Sol replaced it
with an environment-relative locator. A follow-up commit alone would leave that path in outgoing
history, so Sol first refreshed the remote and confirmed exactly our three unpublished commits
above `fd6e40b`, preserved the reviewed tip in local `refs/b233-review/reviewed-tip`, and consolidated
only that unpublished range as `3f0d7577af04ec06b3c8cdafc8dc55a2274b8491`. The original review objects
remain resolvable. Root checked that the reviewed and consolidated trees differ only at the plan
locator; all product bytes remain identical. Root then observed RepositoryPrivacy at 7 passed,
0 failed, 0 skipped, exit 0 (`sanitized-privacy-ps7.log`). No gate was weakened or edited.

These targeted reruns resolve both observed failures; they are not a claim that the earlier full
aggregate exited 0. The normal release must still run its fresh aggregate gates, footprint update,
and eight native Windows CI contexts plus parity before tagging. An unnecessary local shipped-hook
run was interrupted before a leg completed and supplies no result; current release tooling assigns
those full distribution/host suites to CI. No release stamp, push, tag, live efficacy trial, or
consumer model reconciliation has occurred. Publication remains pending explicit user approval.
