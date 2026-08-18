# B-147 implementation report

Date: 2026-08-18

## Outcome

Implemented rev 2. Copilot now has exactly one `userPromptSubmitted` registration. On non-Claude
events `route-prompt` composes routing first and queued Boy Scout text second, deletes the queue
unconditionally after reading it, emits either half alone, and stays silent when both are empty.
Claude events never read or delete the queue. The raw `"hook_event_name"` substring discriminator
is unchanged. The registration comment and four enforcement-surface rows now state the CLI 1.0.80,
2026-08-18 observation. No Claude registration, changelog, or version file changed.

## Red evidence

`pwsh -NoProfile -File src/core/tests/hooks/RoutePrompt.Tests.ps1` before changing either hook:
exit 1; 16 passed, 6 failed, 1 skipped. The new routing-plus-queue and queue-only cases failed for
both twins with `Boy Scout queue missing` / `queue-only context differs: ''`. Two other failures
were the source template's unexpanded security markers; composed dist cases later passed.

Not shown failing pre-change: routing with empty queue, neither half, and Claude queue preservation
already matched old behaviour. The delete-exactly-once assertion follows the missing-queue assertion
and was not reached in the red run. All ran green after composition.

## Build and focused verification

```text
pwsh -NoProfile -File scripts/build.ps1 dotnet
composed dist/dotnet (170 files)
pwsh -NoProfile -File scripts/build.ps1 angular
composed dist/angular (166 files)
pwsh -NoProfile -File scripts/build.ps1 monorepo
composed dist/monorepo (180 files)
```

`pwsh -NoProfile -File scripts/validate-dist.ps1 <dist>` passed for dotnet, angular, and monorepo,
exit 0 each. Each reported 24 resolving hook registrations: 6 from each Claude settings file and 6
Copilot entries times 2 language legs.

`pwsh -NoProfile -File dist/<dist>/tests/hooks/RoutePrompt.Tests.ps1` observed independently for all
three dists: 22 passed, 0 failed, 1 skipped, exit 0. The skip needed a working interpreter exposed
only as `python`; none was available. `bash -n src/core/.claude/hooks/route-prompt.sh` returned 0.
The source PowerShell hook BOM check returned `PS1_BOM=True`.

## Complete shipped hook suites

Command: `pwsh -NoProfile -File dist/<dist>/tests/hooks/Invoke-HookTests.ps1`.

- dotnet: 3 failures across 18 files, exit 3. RoutePrompt 22/0/1. One framework-doctor Windows
  PowerShell 5.1 failure; two live-diff-sensitive Boy Scout Mongo/EF queue-presence failures,
  TwinParity 11/2/0. Per the task correction, recorded and not chased.
- angular: 1 failure across 18 files, exit 1. RoutePrompt 22/0/1; TwinParity 8/0/1. The sole failure
  was the framework-doctor Windows PowerShell 5.1 case.
- monorepo: 3 failures across 18 files, exit 3. RoutePrompt 22/0/1. One framework-doctor Windows
  PowerShell 5.1 failure and the same two live-diff-sensitive Boy Scout failures; TwinParity 11/2/0.

## Meta suite and portability

`pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1` first returned 4 failures across 21
files, exit 4. Three were stale validator-test strings (`all 26 hook registrations resolve`) after
the intentional removal of one two-leg Copilot entry. The fourth was RepositoryPrivacy treating
Git's inaccessible global-ignore warning as a repository path. Updating those expected strings to
24 was the only implementation change not named explicitly by the design; it keeps existing
validator self-tests truthful.

Focused rerun: `pwsh -NoProfile -File .claude/hooks/tests/ValidateDist.Tests.ps1` returned 35 passed,
0 failed, 1 skipped, exit 0. The skip was jq/python parser parity because no working Python was
available. The full meta suite was not rerun after this 210-second focused confirmation; its other
observed failure remains the unrelated Git global-ignore warning. In the full run DocTruth was
9/0/0 and InstallerContract was 12/0/0.

Windows PowerShell 5.1: **NOT OBSERVED**. It is not genuinely available here; the suite's
framework-doctor attempt failed and is not treated as coverage. PowerShell 7 and GNU bash were
observed. Live Copilot CLI model consumption: **NOT OBSERVED** here; fixture verification covers the
single emitted JSON payload and relies on the supplied live 1.0.80 host observation.

## Optional validator residue and scope

Skipped the optional `userPromptSubmitted` cardinality check. Implementing and red-testing it would
touch both validator twins and their mutation suite, materially expanding this P1. The registration
now has one entry, all validators parse it, and fixture tests cover composition.

No `last-boy-scout-hash` access was added. No settings, changelog, or version file was touched.
Generated `dist/` files came only from the composer.

Final audit commands observed `git diff --check` exit 0, zero BOM failures among changed `.ps1`
files, and zero machine-local absolute paths in added lines or this report.

Commit/push: **NOT PERFORMED**. `git add` returned exit 128 because Git could not create
`.git/index.lock` (`Permission denied`); this sandbox exposes `.git` read-only. Nothing was staged
or partially committed.
