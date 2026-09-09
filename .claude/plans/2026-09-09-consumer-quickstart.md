# B-234 proposed contract: one supported Quick Start install route

Status: LOCKED after Opus critique and root source adjudication; Sol implementation authorized.
Baseline: f67eb0312be5838bb17066fa9fdd2847785a812f (v0.86.3).
Scope authority: after the completed upgrade guide, user requested the next consumer improvement
with plan, Opus critique, Sol implementation, testing, and the same delivery pattern.

## Evidence and proportionality
All three distribution READMEs first describe the supported installer, but Quick Start step 1
then instructs readers to copy a selective inventory. That inventory omits installed material
including upgrade/enforcement guidance and ownership/legal machinery. It bypasses mode detection,
archive protection, exclusions and host adaptation. Source mismatch is observed; consumer confusion
or damage has NOT been measured. README itself is excluded from installation and remains incoming
framework-checkout guidance. This is a small entry-point correction, not an installer change.

Alternatives: (A) leave the conflicting route, (B) replace the inventory with a terse pointer to the
existing agent-install section, (C) replace it with a short human Quick Start invocation and mode
routing. Select C: this section should stand alone for humans with explicit working directory and
separate target. Reuse the existing upgrade guide and steps 2-4, not duplicate their procedures.
No new documentation system, skill, always-loaded rule, installer option, or permanent prose test.

## Proposed locked contract
1. Edit only step 1 of src/stacks/{dotnet,angular,monorepo}/files/README.md (plus release notes
   and required maintainer records). Replace 'Copy into your project', selective inventory and
   'Do not copy .template-repo' prose with installation instructions via existing installer.
2. Preserve each stack's Git-root and profile-evidence qualifications verbatim apart from the
   introductory copy verb. No new stack assumptions, required .sln, Angular marker or DW profile.
3. Show native Windows PS7 and PS5.1 alternatives: use PS7 if available, otherwise PS5.1; run ONE, from the incoming
   matching distribution directory (dist/dotnet, dist/angular, or dist/monorepo in a framework
   checkout), targeting the separate repository Git root already named by these READMEs. Exact command shape:
   pwsh -NoProfile -File scripts/install.ps1 -Target 'C:\path\to\consumer-repo'
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Target 'C:\path\to\consumer-repo'
   The script's named Target parameter exists; no changes to installer or root wrapper.
4. BEFORE the initial-install commands, route targets already carrying .claude/framework-version.json
   to docs/upgrade-checklist.md in the incoming distribution. They must follow that guide instead of
   the initial-install steps, so they preserve work/preview/reconcile before apply. If the installer
   reports update unexpectedly, use the upgrade checklist; never continue blindly to bootstrap/adopt.
5. For new installations preserve/reinforce the existing mode/handoff contract: review and commit
   installed shared configuration in target, then follow printed next steps and step 2 for developer
   bootstrap (greenfield) or adopt (pre-existing tooling). Do not weaken the existing developer
   handoff or offer to imitate workflows. Don't claim docs-sync-check must already pass beforehand.
6. Leave the hook prerequisite/doctor aside and all remaining README sections unchanged. Avoid
   broad cleanup of adjacent prose. No script/ownership changes, new flags, or new feature claims.
7. Add root and all3 consumer CHANGELOG 0.86.4 Unreleased heads. Author src, compose all3 dists.
   Static context should be unchanged because READMEs are not always-loaded rule carriers.

## Verification and delivery
A temporary bounded smoke instrument reads the composed Quick Start section, selects the native
host's command and exercises actual disposable greenfield and brownfield installations for all3.
For the unfixed README, materialize its literal listed files and WHOLE directories into disposable
fixtures: required delivered ownership, rules carrier and guide paths must be absent (RED). The
missing-command check is only navigation evidence. Do not claim nested .claude files are absent.
On the candidate,
commands must run from the documented source directory against the separate target (GREEN), with
expected installed ownership/guides/marker exclusion and mode-specific handoff/archive evidence.
Run directly on PS7 and native PS5.1 (host/executable/codepage recorded); no host relaunch substitution.
A separate reading checks that stamped update targets are diverted before initial apply and that
other README sections/profile evidence are preserved. Do not claim this proves a human's comprehension
or successful consumer adoption. Existing installer behavior is not under redesign.

After Sol implements, freeze product range and get a separate independent Opus final review with
blind-first threat model, red and clean evidence, environment and gaps. Root verifies findings.
Normal release automation performs all3 build/validation, footprint, full PS7 meta suite and
selftest; normal push waits for eight direct Windows PS7/PS51 execution jobs plus case parity before
tagging. No failing-gate or CI waiver. Close backlog delivery with RCA and commit/push metadata.

## Expected RCA
Parser gates establish syntax/paths; installer contract executes installer output but never chooses
which README route a human follows. Alternate manual-copy instructions can drift independently.
Sweep other active getting-started guidance for equivalent partial-copy routes, record findings,
and keep this fix bounded to demonstrated conflicts instead of building a generic prose validator.
## Pre-lock Opus critique and root adjudication (2026-09-09)
Fresh read-only claude-opus-5 session cca89895-b735-425f-bddc-e5b0525b893e returned REVISE,
process exit 0, is_error false. Contract reviewed at SHA256
324C40843E7A92189B18712CFB626E9E38020623481617BC540A92A0000D22FE. Opus stated its threat
model before reading source; it did not implement or execute tests. Model-reported cost USD1.111533.

Accept B1: explicit PS7-primary/PS5.1-fallback selection now above. Accept B2's proportional
strengthening: materialize literal manual-copy inventory and compare actual installed requirements,
then run candidate commands with the same expectations. The absent-command check alone establishes
only a navigation discrepancy. Reject the review's claim that .claude/settings.windows.json was
omitted: the inventory copies .claude/ recursively. Also reject the adjective 'permanently' for
missing ownership degradation; a subsequent installer writes the current manifest. Required missing
paths are verified directly instead of repeating reviewer counts or unverified omissions.

Accept B3 as bounded RCA disclosure: remaining 'after copying the template into your repo' prose
in setup-verification sections describes installed state; it is not another selective copy
instruction and stays outside this step-1 fix. Active source/root documentation sweep found the
three Quick Start inventories as the concrete conflicting routes; other matches were installer-backed
commands, generated-mirror/adoption instructions or historical changelogs. The top AI-agent section's
positional Target remains valid; no release-note burden or adjacent wording change is warranted.

The current README already asks for a Git root; preserving it adds no runtime Git prerequisite.
The installer accepts an existing directory and handles its own Git checks. Reviewer's final claim
that it read composed instead of authoring READMEs is incorrect: packet files are exact copies from
src/stacks/*/files/README.md. Root independently read the installer completion branches and confirmed
new-install review/commit and developer bootstrap/adopt handoff. Reviewer did not read that tail and
ran no tests; those gaps remain attributed. Final immutable implementation review follows Sol.