# B-187 — Windows PowerShell 5.1 completion-command design

Status: **LOCKED 2026-08-27 after premise revalidation and adversarial critique**

## Premise and observed harm

The premise still holds on v0.78.1. All three shipped READMEs explicitly support Windows hosts
without `pwsh` by selecting Windows PowerShell 5.1, but each direct deterministic-completion section
offers only PowerShell 7 (`pwsh`) and bash. The supported host therefore reaches a mandatory gate
whose documented commands it cannot run.

This is a documentation-delivery defect, not an interpreter defect. From `dist/dotnet`, the shipped
`scripts/docs-sync-check.ps1` was observed on 2026-08-27 under both `pwsh` 7.6.5 and Windows
PowerShell 5.1: each exited 0 and ended with `All deterministic framework checks passed.`. The
missing capability is only the explicit invocation.

## Authored boundary

There are seven direct canonical completion carriers:

- `src/core/.claude/commands/generate-copilot.md`, composed into all three distributions;
- `src/stacks/{dotnet,angular,monorepo}/files/.claude/commands/bootstrap.md`; and
- `src/stacks/{dotnet,angular,monorepo}/files/.claude/commands/rebootstrap.md`.

The three `/adopt` commands deliberately delegate completion to the Phase-7 `/bootstrap` gate. They
must continue to name that one authority rather than gain a duplicate command matrix. Copilot prompt
files delegate to the canonical commands and are not authored copies. General README and CI command
examples are outside this completion-contract defect; widening this patch to every PowerShell
example would mix distinct lifecycle claims without evidence that the same mandatory-gate harm
applies.

## Options considered

1. **Add an explicit Windows PowerShell 5.1 command beside the existing PowerShell 7 and bash
   commands, and gate the exact three-command matrix. Chosen.** It makes the documented supported
   host executable without changing checker behavior or weakening completion.
2. Replace the two PowerShell variants with one vague "run this script in PowerShell" instruction.
   Rejected: it removes a copy-pasteable command and cannot distinguish `pwsh` from Windows
   PowerShell on the host where that distinction is the defect.
3. Replace `pwsh` everywhere with `powershell`. Rejected: that regresses the documented
   cross-platform PowerShell 7 path and silently changes which runtime consumers use.
4. Add the matrix to `/adopt`, every prompt wrapper, and CI docs. Rejected: `/adopt` delegates to
   bootstrap, wrappers have a canonical target, and unrelated examples are not completion carriers.

## Locked command matrix

Each direct completion section must contain these exact, separately labelled invocations:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/docs-sync-check.ps1
pwsh -NoProfile -File scripts/docs-sync-check.ps1
bash scripts/docs-sync-check.sh
```

`powershell` matches the repository's existing Windows-5.1 command convention and
`settings.windows.json`; `-ExecutionPolicy Bypass` avoids making the mandatory check depend on a
machine's script execution policy. The existing `pwsh` and bash commands remain unchanged.

## Adversarial review and proportionality

- **False green from a path appearing elsewhere:** the gate must inspect only the
  `## Deterministic completion gate` section, not the whole Markdown file.
- **One command standing in for both PowerShell hosts:** exact ordinal strings make `powershell` and
  `pwsh` independent requirements.
- **A new command weakening completion:** the same section must still require exit code 0 and the
  exact final success line; command presence alone is insufficient.
- **A missing carrier hidden by composition:** the finite check runs over bootstrap, rebootstrap,
  and generate-copilot in every composed distribution.
- **A duplicated `/adopt` gate:** rejected; adopt must continue to consume bootstrap's result.
- **Cost versus harm:** seven short prose insertions and one existing finite gate remove the entire
  observed P1 blocker. No script, installer, CI topology, or host-detection change is proportionate.

## Implementation and evidence

1. Strengthen `DocClaims.Tests.ps1` first. Extract each direct completion section, require all three
   exact invocations plus the existing exit-0/final-line contract, and include a cheap negative
   control proving removal of each invocation is rejected.
2. Observe that strengthened test fail on the current v0.78.1 distributions because the Windows
   PowerShell command is absent.
3. Add the separately labelled 5.1 block to the seven authored carriers and compose all three
   distributions; do not edit `dist/` directly.
4. Re-run `DocClaims.Tests.ps1`, mutate each supported-host command out in turn to demonstrate a
   reachable red world, and validate all distributions.
5. Run the shipped dotnet checker under both `pwsh` and Windows PowerShell 5.1, requiring exit 0 and
   the final success line. Record the RCA, exposed class, consumer changelog, and release as a patch.

## Non-goals

- No checker implementation change.
- No interpreter auto-detection or fallback wrapper.
- No second completion gate in `/adopt`.
- No change to the PASS, failure, or `CANT-VERIFY` semantics.
- No B-186 hazard-oracle work in this release.
