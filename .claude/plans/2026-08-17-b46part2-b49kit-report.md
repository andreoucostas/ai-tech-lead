# B-46 part 2 + B-49 drill-kit implementation report

Date: 2026-08-17. No drill was run. No commit or staging operation was performed.

## Delivered

- `session-start.ps1` and `session-start.sh` read the installed version from
  `.claude/framework-version.json`, make no network call, and at most once per seven days emit:
  `- **Framework version:** v<installed> installed; check for updates: https://github.com/andreoucostas/ai-tech-lead/releases`
- The throttle is `.claude/.state/last-version-awareness`, stored as a UTC epoch. The hook writes
  the throttle before emitting; inability to persist it is silent and exits zero.
- `SessionStartVersionAwareness.Tests.ps1` covers absent/current/expired throttle, unwritable state,
  and twin output/state agreement.
- WSD-044 pins the B-49 repository names but explicitly leaves SHA, source-count, build, and
  domain-logic qualification to drill #0. `meta/drill-kit.md` contains the cold checklist, fixed
  pass criteria, toolchain paths, planted probes, and frozen A/B rubric.
- Root and all three consumer changelogs have `## 0.57.0 — Unreleased` heads. Consumer wording does
  not claim detection of an available update.

## Red observations before implementation

Command:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File src/core/tests/hooks/SessionStartVersionAwareness.Tests.ps1
Write-Output "EXIT=$LASTEXITCODE"
```

Observed output:

```text
[FAIL] version awareness fires when no throttle exists: session-start.ps1 -- nudge missing: ## Session preload
[ok] version awareness is throttled within seven days: session-start.ps1
[FAIL] version awareness fires after seven days: session-start.ps1 -- nudge missing after window
[ok] unwritable state does not break the session: session-start.ps1
[FAIL] version awareness fires when no throttle exists: session-start.sh -- nudge missing: ## Session preload
[ok] version awareness is throttled within seven days: session-start.sh
[FAIL] version awareness fires after seven days: session-start.sh -- nudge missing after window
[ok] unwritable state does not break the session: session-start.sh
[FAIL] version-awareness twins emit identical text and state -- Exception calling "ReadAllText" with "1" argument(s): "Could not find file '<temp>\.claude\.state\last-version-awareness'."
SessionStartVersionAwareness.Tests: 4 passed, 5 failed, 0 skipped
EXIT=5
```

The temp GUID in the final failure was
`session-version-6719dc0c-3746-46e4-b3e7-070ea850c7b7`; it was removed by the test's `finally`.

Could not show failing: the two unwritable-state assertions were already green on the untouched
hook because the existing liveness write already swallowed state-path failures. This is recorded as
pre-existing soft-failure behavior, not claimed as a red test. The within-window assertions were
also green before implementation only because no version nudge existed at all; the absent/expired
and state-agreement reds establish that the new behavior was missing.

## Targeted green tests

Source command:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File src/core/tests/hooks/SessionStartVersionAwareness.Tests.ps1
```

Observed: `SessionStartVersionAwareness.Tests: 9 passed, 0 failed, 0 skipped`, `EXIT=0`.
The same file was then run from each composed distribution:

```powershell
foreach($d in 'dotnet','angular','monorepo'){
  & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File "dist/$d/tests/hooks/SessionStartVersionAwareness.Tests.ps1"
  Write-Output "EXIT=$LASTEXITCODE"
}
```

Observed for dotnet, angular, and monorepo independently:

```text
[ok] version awareness fires when no throttle exists: session-start.ps1
[ok] version awareness is throttled within seven days: session-start.ps1
[ok] version awareness fires after seven days: session-start.ps1
[ok] unwritable state does not break the session: session-start.ps1
[ok] version awareness fires when no throttle exists: session-start.sh
[ok] version awareness is throttled within seven days: session-start.sh
[ok] version awareness fires after seven days: session-start.sh
[ok] unwritable state does not break the session: session-start.sh
[ok] version-awareness twins emit identical text and state
SessionStartVersionAwareness.Tests: 9 passed, 0 failed, 0 skipped
EXIT=0
```

No full hook or meta suite was run, per task instruction.

## Composition and propagation

Command:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 dotnet
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 angular
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 monorepo
```

Observed:

```text
composed dist/dotnet (167 files)
composed dist/angular (163 files)
composed dist/monorepo (177 files)
BUILD_EXITS dotnet=0 angular=0 monorepo=0
```

Command and observed output:

```powershell
git status --porcelain dist/
```

```text
 M dist/angular/.claude/hooks/session-start.ps1
 M dist/angular/.claude/hooks/session-start.sh
 M dist/angular/CHANGELOG.md
 M dist/dotnet/.claude/hooks/session-start.ps1
 M dist/dotnet/.claude/hooks/session-start.sh
 M dist/dotnet/CHANGELOG.md
 M dist/monorepo/.claude/hooks/session-start.ps1
 M dist/monorepo/.claude/hooks/session-start.sh
 M dist/monorepo/CHANGELOG.md
?? dist/angular/tests/hooks/SessionStartVersionAwareness.Tests.ps1
?? dist/dotnet/tests/hooks/SessionStartVersionAwareness.Tests.ps1
?? dist/monorepo/tests/hooks/SessionStartVersionAwareness.Tests.ps1
```

Direct propagation check observed `hook_line=1 test_present=1` for each of dotnet, angular, and
monorepo.

## Manual fixture: first emission then throttle

The manual fixture created a temp repo, copied the composed dotnet
`.claude/framework-version.json`, and piped `{"hook_event_name":"SessionStart"}` twice into the
composed PowerShell hook from that fixture root:

```powershell
$eventJson = '{"hook_event_name":"SessionStart"}'
$first = $eventJson | & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File $hook
$second = $eventJson | & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File $hook
```

Observed:

```text
FIRST_EXIT=0 FIRST_NUDGE_COUNT=1
- **Framework version:** v0.56.0 installed; check for updates: https://github.com/andreoucostas/ai-tech-lead/releases
SECOND_EXIT=0 SECOND_NUDGE_COUNT=0
THROTTLE=1786988160
```

The fixture was at
`%LOCALAPPDATA%\Temp\b46-manual-<guid>`.
An attempted sandboxed recursive cleanup was rejected before execution, so this small temp fixture
may remain; nothing machine-local was written under `src/`.

## Syntax, BOM, network-token, and diff hygiene

Commands and observations:

```powershell
[Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'src/core/.claude/hooks/session-start.ps1'),[ref]$tokens,[ref]$errors)
# PS_PARSE_ERRORS=0

& 'C:\Program Files\Git\bin\bash.exe' -n src/core/.claude/hooks/session-start.sh
# BASH_N_EXIT=0

$bytes=[IO.File]::ReadAllBytes((Resolve-Path 'src/core/.claude/hooks/session-start.ps1'))
# PS1_BOM=EF BB BF

rg -n "curl|wget|Invoke-WebRequest|Invoke-RestMethod|last-version-awareness|Framework version" src/core/.claude/hooks/session-start.ps1 src/core/.claude/hooks/session-start.sh
```

The `rg` output contained only the throttle and version-line matches; no `curl`, `wget`,
`Invoke-WebRequest`, or `Invoke-RestMethod` match appeared.

```powershell
git diff --check
# DIFF_CHECK_EXIT=0
```

## Evidence limits

- No target repo was cloned, so no SHA, source-file count, domain-logic claim, or baseline build is
  recorded as observed. Those fields remain explicitly “to be pinned at drill #0.”
- No drill, `/bootstrap`, representative task, planted-defect probe, or A/B run occurred.
- No full suites were run.
- The installed fixture version was 0.56.0 because release stamping is intentionally deferred;
  the hook reads the installed stamp dynamically and the 0.57.0 changelogs remain Unreleased.

> Concrete home paths are generalised in this report: the authoring repo is public and the
> privacy gate refuses them (B-122). The gate caught this file on the first release attempt.
