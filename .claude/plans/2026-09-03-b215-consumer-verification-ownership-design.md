# B-215 — Consumer verification ownership boundary

## Observed harm

In a real consumer repository, agents discovered the framework-owned
`tests/hooks/Invoke-HookTests.ps1`, treated it as the application's test suite, and executed it.
The path is currently installed and classified `framework-owned/overwritten`; the broad verification
discovery rules do not exclude framework-owned or retired paths. A green hook suite can therefore be
misreported as application verification, and bootstrap can persist the wrong command.

## Frozen decision

1. Keep `src/core/tests/hooks/**` and the composed `dist/*/tests/hooks/**` suites. Maintainer and
   template CI continue to execute them from the distributions.
2. Exclude `tests/hooks/**` from consumer ownership manifests, so installers no longer copy that
   tree. Add every formerly installed path and every supported historical content digest to the
   cumulative retirement ledger. Existing known-clean files are deleted; modified, unsafe, or
   unverifiable files are preserved with the installer's existing `CANT-VERIFY` contract.
3. In the unprotected framework-rules carrier, state that framework-owned or retired artifacts do
   not evidence application build, test, format, lint, migration/deploy, or data-validation
   commands. Explicit framework workflows and developer-requested framework diagnosis may run
   framework checks, which must be reported separately from application verification.
4. Bootstrap and rebootstrap must load ownership and retirement boundaries before command
   discovery. They reject normalized slash variants, quoted invocations, aggregate runners, and
   direct leaf tests under `tests/hooks`; a stale saved command is not run and triggers
   rebootstrap/remediation.
5. `scripts/docs-sync-check.* -> scripts/template-checks.*` remains the consumer framework-state
   gate. It is never presented as application test coverage.

## Scope and compatibility

This narrowly supersedes B-157's inference that a suite required by template CI must also be
installed into consumers. It does not supersede the ownership model or remove the suite from source
or dist. The only recorded compatibility evidence for consumer-local execution is historical
changelog/backlog prose; no current consumer CI, support runbook, or field need has been found.
If such evidence appears, an explicit diagnostic distribution or guarded opt-in can be designed
separately rather than retaining a misleading top-level test tree by default.

## Work slices

- **Slice A — installer mechanics (Claude CLI, Sonnet):** manifest prefix exclusion, cumulative
  content-qualified retirements, focused composer/installer tests. No prose policy or generated
  dist edits.
- **Slice B — model-facing ownership contract (Codex):** carrier, bootstrap/rebootstrap across all
  stacks, mirrors required by composition, and focused contract tests.
- **Slice C — release truth (Codex):** notice/docs, root and three consumer changelogs, WSD/RCA,
  compose, full verification, independent implementation review, commit and push.

## Acceptance contract

- Greenfield installs contain no `tests/hooks/**` path.
- Updating a prior clean install retires every known framework copy; consumer-modified, unknown,
  non-regular, or unsafe paths survive with an honest diagnostic.
- All three dist suites remain present and template/release CI invocations remain valid.
- Framework-owned and retired paths cannot populate or refresh application Verification Commands,
  including separator, quoting, aggregate, and direct-leaf variants.
- Consumer framework-state verification remains available through `docs-sync-check`; application
  verification is explicitly separate and may truthfully be `not available`.
- Both installer/composer twins and all three distributions remain equivalent.

## Adversarial review

A fresh-context `gpt-5.5` reviewer formed a blind threat model before seeing the candidate. Its first
pass returned `REVISE`, identifying false-green reporting, aggregate/leaf bypasses, context-shape
coverage, normalized stale-command variants, and the need to supersede B-157 narrowly. After direct
inspection showed that `template-checks` skips an absent `tests/hooks` directory and template CI can
retain the suite in dist, the reviewer corrected its recommendation to structural non-installation.
Final verdict: **REVISE to the frozen decision above**. Runtime refusal remains only a fallback if
current evidence establishes consumer-local diagnostics as a supported surface.

## Proportionality

Excluding one framework-owned prefix removes the misleading structural trigger without deleting the
maintainer suite or adding a new skill, router, CI leg, test framework, or runtime protocol. Existing
retirement machinery supplies the safe update behavior. The ownership rule and command-discovery
filter cover preserved modified remnants and protected stale instructions that physical removal
alone cannot reach.
