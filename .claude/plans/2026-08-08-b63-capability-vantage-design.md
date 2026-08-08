# B-63 · Capability probes must use the consumer’s vantage point

## Absorbs B-56

**Status:** LOCKED — independently adversarially reviewed and approved 2026-08-08. Implementation must preserve this contract.
**Base:** `origin/master` at `085045b`
**Effort:** M · **Priority:** P2 · **Invariants:** #1, #3, #4, #5, #7
**Decision owner:** WSD-026 establishes the governing rule, but its absolute-path consequence was superseded by v0.38.1. This item applies the surviving vantage-point rule and appends the missing correction rather than rewriting history.

## 1. Premise and audit conclusion

B-56’s original concrete defect was fixed in v0.35.0, but its class remained open as B-63. The completed audit finds one remaining structurally invalid production probe and two adjacent truth defects:

1. `src/core/scripts/framework-doctor.ps1` uses `Invoke-BashProbe` for the `Guard JSON parser` row. The child Bash inherits the doctor’s environment, not the `PATH` the agent host later supplies to `guard.sh`; `[OK]` or `[MISSING]` therefore cannot prove the claimed runtime condition.
2. Both doctors still tell a consumer with a portable bare interpreter name to rerun the installer to pin an absolute path. That remediation was valid only for v0.38.0 and was deliberately reversed in v0.38.1 because committed settings must work across teammates and operating systems.
3. The `Stack toolchain` and part of the `Copilot surface` details describe a command found or absent in the doctor process as though that proved what an agent-hosted hook will see. The checks may remain useful, but their wording and canaries must expose their observation boundary.

The current test evidence exposes the first mismatch. At `085045b`, `FrameworkDoctor.Tests.ps1` reports 21 passed and one failure on this host: the PowerShell doctor cannot observe Bash while the shell twin can, so the Copilot-arguments whole-output comparison fails. Conversely, when Bash is visible to PowerShell, the current code may promote the parser row to `[OK]` from the equally invalid child environment.

The audit does not justify a general capability-resolution framework. Filesystem and repository-state probes observe the repository they are given; hook liveness consumes evidence written by the actual host; and the Bash doctor can make a useful shell-local observation when it labels it as such. The proportional response is to remove the one cross-vantage child probe, correct the two misleading detail families, make registration demand exact, and preserve every other probe’s boundary explicitly.

## 2. Per-probe consumer/observation audit

This table is the required B-63 inventory. Implementation must keep it in the plan and record its disposition in the backlog closure; it is not permission to expand unrelated behavior.

| Doctor row | Capability consumer | Environment that matters | What the doctor actually observes | Disposition |
|---|---|---|---|---|
| `Install state` | Developer running installed framework machinery | The repository being diagnosed | Local framework stamp existence and JSON | Valid self-vantage filesystem check; no change. |
| `Framework rules delivery` | Claude Code through the `CLAUDE.md` import; Copilot through the carrier | The diagnosed checkout | Carrier and import text in that checkout | Valid structural check; it does not claim a host consumed the file. No change. |
| `Protected-file sync` | Agent reading protected `CLAUDE.md` plus installed machinery | The diagnosed checkout | Version text and local framework stamp | Valid structural comparison; no change. |
| `Bootstrap/adoption state` | Session-start/docs-sync workflow | The diagnosed checkout | Existing pending sentinel and `CLAUDE.md` marker | Valid repository-state check; no change. |
| `Wired hook shell` | Claude Code’s hook launcher | Agent-host hook process environment | Registered executable spelling plus local filesystem for absolute paths; never the host’s `PATH` for a bare name | Keep `CANT-VERIFY` for bare names, but correct the remediation to the v0.38.1 portable policy and direct the user to liveness/canaries. Scope absolute-path results to this machine. |
| `Hook liveness` | Actual Claude Code hook process | Agent-host hook environment | A timestamp written by the actual `session-start` hook | Valid positive evidence. Absence remains `CANT-VERIFY`, never `MISSING`. |
| `Hook files` | Claude and Copilot hook launchers | The diagnosed checkout | Registration targets and local file existence | Valid structural check only; wording must not imply execution. Existing contract is sufficient. |
| `Guard JSON parser` | A registered `guard.sh` process | The Bash environment supplied by the agent host | PowerShell doctor: no valid observation. Bash doctor: its current Bash `PATH` and execution-probed parser | Remove `Invoke-BashProbe`; PowerShell always reports `CANT-VERIFY` when a Bash guard is registered. Bash reports only on “this Bash environment.” Actual-host write canary stays authoritative. |
| `Stack toolchain` | Registered `post-write.ps1` or `post-write.sh` | The shell environment supplied by the agent host | `dotnet`, `node`, and `npx` resolution in the current doctor process | Retain the small local check, but lock both twins to the byte-identical phrase “this doctor process environment,” never a shell-specific label and never “the post-write hook can/cannot run.” Add an actual-host post-write canary and deterministic wording tests. |
| `Copilot surface` | Copilot CLI or VS Code agent mode | The actual Copilot process and feature policy | `hooks.json` validity plus CLI name resolution in the current doctor process; the shell twin may be unable to parse JSON or the two processes may resolve `copilot` differently | Preserve both legitimate evidence asymmetries. Use the byte-identical phrase “this doctor process environment” for CLI visibility whenever JSON state permits the CLI detail; actual Copilot canaries remain authoritative. |
| `Mirror and version integrity` | Maintainer/consumer scripts reading generated mirrors and stamps | The diagnosed checkout | A local `template-checks` sub-call over that checkout | Valid self-vantage repository check; no change. |
| `Audit trail substrate` | Audit hook writing as the same local user | Checkout path and local filesystem permissions | Existence and an append-open attempt by the doctor process | Useful local evidence, but not proof of host invocation; liveness/canaries remain the host proof. Existing state contract can remain. |

The `Finish` canaries are deliberately outside the script-verifiable counts. Tests must distinguish the script rows above from the canary block after the blank separator.

## 3. Locked behavior contracts

### 3.1 Decide whether the guard parser is required from registrations, not shell presence

Introduce one derived fact in each twin, named equivalently to `bashGuardRegistered`. It is true only when a declared hook target is `.claude/hooks/guard.sh` on either supported registration surface:

- **Claude settings:** inspect commands from `.claude/settings.json`; recognize an interpreter token whose basename is `bash` or `bash.exe`, whether it is bare, quoted, slash-qualified, or an absolute Windows/POSIX path, and require that the command’s actual script target normalize to `.claude/hooks/guard.sh` before optional arguments.
- **Copilot hooks:** inspect the `bash` command members in `.github/hooks/hooks.json` and require that their normalized command target be `.claude/hooks/guard.sh` before optional arguments. This counts even when Claude settings contain only PowerShell hooks or no Bash hook at all.

The same narrow extraction grammar already used for `Hook files` should be factored or reused inside each script rather than inventing a second contradictory interpretation. A declared target in malformed Copilot JSON may be extracted conservatively, while the independent `Copilot surface` row owns whether the file is valid enough for Copilot to consume.

The fact is false when:

- Claude and Copilot registrations target only `guard.ps1`;
- Bash is merely installed or present on `PATH`;
- a Bash registration targets some `.sh` hook other than `guard.sh`;
- `guard.sh` merely exists on disk but is not registered.

Do not infer parser need from `$shells`, from the presence of a `bash` executable, or from the opposite-language twin on disk.

### 3.2 `Guard JSON parser` row

| Registered guard and invoking surface | Required result | Exit effect | Meaning |
|---|---|---:|---|
| No `guard.sh` target in either Claude or Copilot registrations | `[OK]` | none | The registered write guards parse JSON natively through PowerShell; the mere presence of Bash or an unregistered `guard.sh` does not create a dependency. |
| `guard.sh` registered in Claude with bare `bash` or `bash.exe`; doctor invoked through `.ps1` | `[CANT-VERIFY]` | none | PowerShell cannot observe the runtime `PATH` supplied to that Bash guard. |
| `guard.sh` registered in Claude with an absolute path whose basename is `bash` or `bash.exe`; doctor invoked through `.ps1` | `[CANT-VERIFY]` | none | Knowing the executable path still does not reveal the later guard process’s parser `PATH`. |
| `guard.sh` registered only by Copilot; Claude uses PowerShell; doctor invoked through `.ps1` | `[CANT-VERIFY]` | none | Copilot-only Bash wiring still creates the guard dependency, and PowerShell cannot observe Copilot’s Bash environment. |
| Any `guard.sh` registration; doctor invoked through `.sh`; `jq` resolves | `[OK]` | none | This Bash invocation exposes the common parser path used by `guard.sh`; it is not a claim about an unseen agent host. |
| Any `guard.sh` registration; direct `.sh`; no `jq`, but `python3`, `python`, or `py` passes the existing JSON execution probe | `[OK]` | none | This Bash invocation exposes a working fallback accepted by `guard.sh`. |
| Any `guard.sh` registration; direct `.sh`; only a resolvable but non-working Store-style Python stub exists | `[MISSING]` | exit 1 | This Bash invocation cannot supply a parser accepted by `guard.sh`. |
| Any `guard.sh` registration; direct `.sh`; no parser exists | `[MISSING]` | exit 1 | In this Bash environment, `guard.sh` allows writes with its loud inactive warning. |

PowerShell 7 and Windows PowerShell 5.1 have the same contract. Whether the PowerShell process can resolve Bash must not change its row.

The PowerShell detail must say that it cannot observe the runtime `PATH` supplied to `guard.sh`, recommend the Bash doctor only for a specific Bash environment, and name the write-guard canary as the only actual-host proof. The shell detail must say “this Bash environment.”

### 3.3 `Wired hook shell` row and WSD-026 correction

The row continues to diagnose Claude’s explicit command interpreter; Copilot’s `bash`/`powershell` members are host-selected surfaces and do not become fake executable paths in this row.

| Claude interpreter registration | Required result and remediation |
|---|---|
| No readable interpreter command | `[MISSING]`; rerun the installer to restore hook registrations. |
| Bare name, including the shipped `pwsh`, `powershell`, or `bash` policy | `[CANT-VERIFY]`; explain that the bare name is intentionally portable committed configuration since v0.38.1, that this script cannot observe the agent host’s `PATH`, and that `Hook liveness` plus the exact host canaries decide whether it works. Do **not** recommend pinning an absolute path. |
| Absolute path exists on this machine | `[OK]`; say only that the registered path exists on this machine. Do not call it portable or prove host invocation. |
| Absolute path is absent on this machine | `[MISSING]`; say the configured machine-specific path is absent and rerun the current installer to restore portable bare-name wiring. Do not say the installer will pin another absolute path. |

Append, without editing or deleting the historical WSD-026 text, a dated correction under WSD-026 in `meta/workspace-decisions.md`:

> **Correction (2026-08-08; B-63/B-56).** v0.38.1 superseded the v0.38.0 absolute-path policy recorded above. Committed `.claude/settings.json` is team configuration, so the installer intentionally writes a portable bare interpreter name; an installing developer’s absolute path breaks teammates on another OS or profile. The vantage-point rule remains accepted: a doctor cannot convert its own `PATH` into a claim about the agent host. Therefore a bare registration is `CANT-VERIFY`, with hook liveness and host canaries as remediation—not a request to pin an absolute path. Existing absolute paths can be checked only on the current machine, and rerunning the current installer restores the portable policy. B-63 also removes the remaining child-Bash inference for `Guard JSON parser`.

This is an append-only correction to an immutable decision record, not a rewrite that makes the v0.38.0 decision appear never to have happened.

### 3.4 `Stack toolchain` row and actual-host canary

Both twins retain their current template markers and command sets. The state reports only what the current doctor process can observe. The wording is deliberately generic and byte-identical so merely invoking a different twin does not create a textual exception:

- `[OK]`: **exact shared template** — “required `<template>` toolchain commands are available in this doctor process environment; this does not prove the agent host’s post-write environment.”
- `[MISSING]`: **exact shared template** — “the required toolchain commands are absent from this doctor process environment: `<comma-separated commands>`; this does not prove the agent host’s post-write environment. Fix: install them on this machine if the actual-host canary also fails.”
- `[PENDING]`: unchanged until bootstrap/adoption completes.

Do not emit “PowerShell doctor environment” in one twin and “Bash doctor environment” in the other. Tests pin the same visible command set where parity is expected and require byte-identical normalized `Stack toolchain` rows; ambient PATH is never allowed to decide that comparison.

Add one uncounted `Finish` canary to both twins. In consumer language it must instruct the developer to make and then revert a harmless, deliberate compile/type error through the actual agent in a real build-relevant file. A pass is the hook’s own output beginning `## dotnet build failed` or `## tsc --noEmit failed`; the model merely noticing the error, or a direct terminal build, is not a pass. The canary must mention the post-write throttle so a prior run is not mistaken for silence.

The existing write-guard canary remains the authoritative parser/guard proof. The new post-write canary is authoritative for the actual host’s toolchain visibility and feedback path.

### 3.5 `Copilot surface` wording and known JSON asymmetry

PowerShell always has native JSON parsing and can classify valid versus malformed `hooks.json`. The Bash doctor can reach a pre-existing `CANT-VERIFY` branch when neither `jq` nor a working Python is available. That is a valid, known evidence asymmetry independent of B-63’s new parser-row asymmetry. A second valid divergence exists when a controlled fixture makes the `copilot` command resolvable in only one doctor process.

When both twins can classify the same JSON and see the same CLI state, their `Copilot surface` row must be byte-identical. Lock the valid-JSON details to these shared templates:

- CLI resolves: “hooks.json is valid and Copilot CLI is available in this doctor process environment.”
- CLI does not resolve: “hooks.json is valid; Copilot CLI is absent from this doctor process environment. Claude-only teams need no action; Copilot teams must use the actual-surface canaries below.”

Do not name PowerShell or Bash in those details. Malformed-JSON and Bash-cannot-parse-JSON branches keep their state-specific remediation and do not make a CLI-visibility claim. The existing Copilot CLI/VS Code canaries remain the actual-host proof; command presence alone never upgrades Preview enablement, folder trust, or model consumption to verified.

## 4. Exact implementation files

### Authored source and tests

- `src/core/scripts/framework-doctor.ps1`
  - Delete `Invoke-BashProbe` completely.
  - Derive parser demand from actual Claude and Copilot `guard.sh` targets.
  - Implement the unconditional PowerShell `CANT-VERIFY` parser contract when demanded.
  - Correct `Wired hook shell`, `Stack toolchain`, and `Copilot surface` details.
  - Add the uncounted post-write actual-host canary.
  - Preserve Windows PowerShell 5.1 compatibility and UTF-8 BOM.

- `src/core/scripts/framework-doctor.sh`
  - Derive parser demand from the same two registration surfaces and target grammar.
  - Retain the existing `jq`/execution-probed Python selection behavior.
  - Scope parser, wired-shell, stack-toolchain, and Copilot CLI details to the current environment.
  - Add the same post-write actual-host canary.

- `src/core/tests/hooks/FrameworkDoctor.Tests.ps1`
  - Split fixture construction so Claude and Copilot registrations can be independently selected.
  - Add the registration, vantage, stack, canary, mutation, and fixture-specific parity cases below.
  - Preserve UTF-8 BOM and PowerShell 5.1 syntax.

- `src/core/docs/enforcement-surfaces.md`
  - State the PowerShell/Bash/current-agent-host observation boundaries.
  - Document the portable bare-name policy and both authoritative host canaries.

### Meta, decision, and release-note records

- `meta/workspace-decisions.md`
  - Append the dated WSD-026 correction verbatim or substantively identically; do not revise the historical paragraphs.
- `meta/BACKLOG.md`
  - Finalize B-63 and B-56 together **before** invoking `release.ps1`.
  - Include the complete per-probe disposition, observed red/green evidence, and closure RCA using only evidence available before release; do not promise or later backfill a CI/release result.
- `CHANGELOG.md`
- `src/stacks/dotnet/files/CHANGELOG.md`
- `src/stacks/angular/files/CHANGELOG.md`
- `src/stacks/monorepo/files/CHANGELOG.md`
- `.claude/plans/2026-08-08-b63-capability-vantage-design.md`

Do not append `meta/LEARNINGS.md` unless implementation reveals a genuinely new lesson beyond the corrected WSD-026 rule.

### Generated files from composition

Compose all three distributions. Expected B-63 generated families are:

- `dist/{dotnet,angular,monorepo}/scripts/framework-doctor.ps1`
- `dist/{dotnet,angular,monorepo}/scripts/framework-doctor.sh`
- `dist/{dotnet,angular,monorepo}/tests/hooks/FrameworkDoctor.Tests.ps1`
- `dist/{dotnet,angular,monorepo}/docs/enforcement-surfaces.md`
- `dist/{dotnet,angular,monorepo}/CHANGELOG.md`

Do not edit `dist/` manually.

## 5. Test design

### 5.1 Registration-demand fixtures

Refactor `Fixture` so it accepts independent Claude and Copilot hook registrations; do not continue deriving both surfaces from one `-Shell` value. Add these deterministic cases against both doctor twins:

1. **Genuine no-Bash fixture:** Claude registers only a PowerShell interpreter targeting `guard.ps1`; Copilot contains only a `powershell` member targeting `guard.ps1`, with no `bash` member and no `guard.sh` target anywhere. Pin `copilot` absent from both doctor processes (or present in both in a separately named variant) rather than inheriting ambient CLI visibility, and expose a controlled working JSON parser to the Bash doctor so Copilot JSON classification is equal. Both parser rows are `[OK] ... not required`, the two `Copilot surface` rows are byte-identical, and the expected divergence set is exactly empty regardless of whether Bash or Copilot exists on the test host.
2. Claude bare `bash` targeting `guard.sh`: parser required.
3. Claude bare `bash.exe` targeting `guard.sh`: parser required.
4. Claude quoted absolute path ending in `bash` targeting `guard.sh`: parser required.
5. Claude quoted absolute Windows-style path ending in `bash.exe` targeting `guard.sh`: parser required.
6. **Copilot-only Bash:** Claude registers only PowerShell/`guard.ps1`; Copilot’s `bash` member targets `guard.sh`. Parser required in both doctors.
7. Bash targets a non-guard `.sh` hook and no surface targets `guard.sh`: parser not required.
8. `guard.sh` exists but is unregistered: parser not required.

Each case must assert the derived row, exact exit contribution, and summary. Cases 4 and 5 test recognition only and may use a fixture file path; they must not depend on the host’s Bash installation to decide whether parser demand exists.

### 5.2 Semantic comparison with fixture-specific exceptions

Replace whole-output equality with a parser that separates script-verifiable rows from the canary block and maps each row to `State`, `Name`, and `Detail`. It must:

1. Require exactly one instance of every expected script row in each twin.
2. Reject duplicate, missing, or unexpected names.
3. Apply only the existing narrow slash, `powershell.exe`, and sibling `docs-sync-check.<ext>` lexical normalizations.
4. Receive an `ExpectedDivergentRows` set from each fixture, never a global ignore list.
5. Compare normalized state/detail for every row not in that set.
6. Independently assert the exact per-twin state/detail contract for every row in the set.
7. Compute the actual divergent-row set and require set equality with `ExpectedDivergentRows`, so a stale permission or unexpected new divergence fails.
8. Recompute `ok` and `missing` counts from each twin’s script rows and compare them to that twin’s printed summary; assert each exit is 1 iff its own rows contain `MISSING`.

Expected exceptions are fixture facts:

- `Guard JSON parser` only when a `guard.sh` target exists, because PowerShell is `CANT-VERIFY` while direct Bash is `OK` or `MISSING`.
- `Copilot surface` when the fixture deliberately creates **either** of its two evidence asymmetries: the Bash doctor has no JSON parser while PowerShell parses `hooks.json` natively, or `copilot` resolves in exactly one doctor process. A fixture with both causes still lists the row once.
- No exception for a genuine no-Bash fixture.

If a registered Bash guard and either Copilot asymmetry apply, the fixture’s expected set is exactly `{ Guard JSON parser, Copilot surface }`. If only a Copilot asymmetry applies, it is exactly `{ Copilot surface }`; if neither applies and no Bash guard is registered, it is empty. Do not regex-delete either row or compare one twin’s summary to the other’s.

### 5.3 Red before production change

Add the PowerShell Copilot-only Bash contract first because it proves both the wrong-vantage defect and the old demand-detection defect:

- Claude registers only `powershell`/`guard.ps1`.
- Copilot registers `bash: .claude/hooks/guard.sh` and `powershell: .claude/hooks/guard.ps1`.
- Prepend a controlled real Bash directory and a parser-capable fake-bin directory to the child’s `PATH`.
- Run unchanged `framework-doctor.ps1` and require `[CANT-VERIFY] Guard JSON parser`.

On `085045b`, `$bashWired` is derived only from Claude settings, so the row is `[OK] ... not required`; the new test must fail for that exact reason.

Add a second controlled red with Claude Bash wiring and the same parser-capable `PATH`: unchanged `Invoke-BashProbe` reports `[OK]`, while the locked result is `[CANT-VERIFY]`. Record both observed reds separately so registration demand and observation vantage are not conflated.

Run the PowerShell contract cases under pwsh and Windows PowerShell 5.1 where available. Genuine 5.1 absence remains an invariant skip through the existing resolver.

### 5.4 Reachable green and host-boundary controls

Required green controls are:

- The same Bash-visible PowerShell fixture reports parser `CANT-VERIFY`, exit-neutral, under pwsh and 5.1.
- The same fixture with Bash removed from PowerShell’s `PATH` reports the identical parser state/detail and summary contribution.
- The genuine no-Bash fixture reports parser `OK ... not required` in both twins.
- Direct Bash with no `jq` but a working interpreter exposed only as `python` reports parser `OK` scoped to this Bash environment.
- Direct Bash with no parser reports parser `MISSING`, exit 1, and the known `Copilot surface` asymmetry is separately asserted.
- The Store-alias stub reports parser `MISSING`.
- Bare wired-shell wording says portable and points to liveness/canaries; it never says “pin an absolute interpreter path.”
- Missing absolute wired-shell wording tells the user to restore portable wiring; existing absolute wording says only “on this machine.”
- `dotnet`, `angular`, and `monorepo` non-pending fixtures use controlled fake command bins to force both `OK` and `MISSING` stack rows. Every detail uses the exact generic “this doctor process environment” wording and disclaims proof of the agent-host environment.
- The post-write canary appears in both twins outside the counted rows, names the exact `## dotnet build failed` / `## tsc --noEmit failed` signals, mentions reverting the edit and the throttle, and those pinned prefixes still exist in the corresponding post-write hook twins.
- Stack fixtures require the exact generic phrase `this doctor process environment` and byte-identical normalized rows; `PowerShell`, `pwsh`, `Bash`, and `shell` must not appear in the environment qualifier.
- Copilot command-presence details use the same generic phrase `this doctor process environment`; existing CLI and VS Code canaries stay present.
- Controlled valid-JSON Copilot fixtures use PowerShell-only guard registrations and a working Bash-side JSON parser, then cover: CLI visible to both twins, visible to neither, visible only to PowerShell, and visible only to Bash. This isolates CLI resolution from the guard-parser row. The both/neither cases require byte-identical `Copilot surface` rows and an exactly empty divergence set; each one-twin case requires the exact set `{ Copilot surface }` and asserts which detail says available versus absent.
- A separate no-JSON-parser Bash fixture requires `Copilot surface` divergence even when CLI visibility is pinned equal. Combine it once with a one-twin CLI fixture to prove multiple reasons for the same row still yield one exact exception name.

The Copilot fixtures must build isolated command bins and give each doctor invocation an explicit `PATH`; do not rely on PATHEXT, an installed `copilot.cmd`, or the maintainer’s ambient PATH. When visibility is intended to be equal, expose the same executable wrapper to both or expose none. When it is intended to differ, the runner supplies separate controlled paths and asserts that the setup probe itself sees the intended resolution before invoking either doctor.

### 5.5 Exact self-contained historical mutation

Keep the existing shell-side mutation proving that a name-only Python probe wrongly accepts the Store stub.

Add one PowerShell mutation test against a scratch copy of the fixed real doctor. It must not depend on any function retained in production. Normalize the scratch text to LF for matching, preserve the original BOM when writing, and perform exactly two bounded insertions:

1. Find the unique line:

   ```powershell
   function Has($Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
   ```

   Assert it occurs exactly once and that `function Invoke-BashProbe` occurs zero times in the fixed source. Insert immediately after it the complete historical function:

   ```powershell
   function Invoke-BashProbe($Command) {
       $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
       if (-not $bashCommand) { return $null }
       try {
           $startInfo = New-Object System.Diagnostics.ProcessStartInfo
           $startInfo.FileName = $bashCommand.Source
           $startInfo.Arguments = '--noprofile --norc -c "' + $Command + '"'
           $startInfo.UseShellExecute = $false
           $startInfo.CreateNoWindow = $true
           $process = New-Object System.Diagnostics.Process
           $process.StartInfo = $startInfo
           if ($process.Start()) {
               if ($process.WaitForExit(3000)) { $result = ($process.ExitCode -eq 0) }
               else { $process.Kill(); $result = $null }
           } else { $result = $null }
           $process.Dispose()
           return $result
       } catch { return $null }
   }
   ```

2. The fixed production branch must be bounded by unique comments `# PARSER-VANTAGE-BRANCH-BEGIN` and `# PARSER-VANTAGE-BRANCH-END`. Assert each marker occurs exactly once and replace only the text between them with this historical inference, retaining the corrected registration-demand boolean. These neutral names correct the original design's backlog-ID-prefixed anchors: the test is shipped to consumers, so invariant #6 forbids a `B-63` maintainer token in either the production marker or its test literal.

   ```powershell
   if ($bashGuardRegistered) {
       $bashParser = Invoke-BashProbe 'command -v jq >/dev/null 2>&1 && exit 0; for c in python3 python py; do command -v $c >/dev/null 2>&1 && printf ''{}'' | $c -c ''import json,sys; json.load(sys.stdin)'' >/dev/null 2>&1 && exit 0; done; exit 1'
       if ($null -eq $bashParser) { Row CANT-VERIFY 'Guard JSON parser' 'bash is wired but this script could not observe its PATH.' }
       elseif ($bashParser) { Row OK 'Guard JSON parser' 'jq or a working python interpreter is available.' }
       else { Row MISSING 'Guard JSON parser' 'the bash write guard is INACTIVE and allows writes with only a warning. Fix: install jq.' }
   } else { Row OK 'Guard JSON parser' 'not required by the registered PowerShell guards.' }
   ```

Use one fixture with a real Bash executable and a controlled fake `jq` that exits 0. Run the fixed copy and mutant with the **same exact `PATH`**, registrations, files, and host executable:

- fixed result: parser is `CANT-VERIFY`, exit-neutral, and its summary excludes that row from both `ok` and `missing`;
- mutant result: parser is `[OK]`, exit-neutral, and its summary has exactly one additional `ok`;
- the semantic contract helper accepts the fixed row and rejects the mutant row for the same fixture.

Assert the two anchor replacements each changed exactly one location, the resulting mutant parses under the current host and Windows PowerShell 5.1 where available, and cleanup touches only the scratch fixture. This makes the historical wrong behavior self-contained after `Invoke-BashProbe` is deleted from production.

### 5.6 Focused and release verification matrix

Required focused runs:

- `FrameworkDoctor.Tests.ps1` directly under pwsh.
- The same file directly under Windows PowerShell 5.1.
- Git Bash on Windows for direct shell parser cases.
- Linux CI for the POSIX Bash path and absolute `/.../bash` registration case.
- Parser/BOM sweep for changed `.ps1` files and `bash -n` for changed `.sh` files.

Required release gates:

- compose all three distributions and require freshness-empty diffs after the second compose;
- hook suites for all three dists;
- `validate-dist` for all three dists, including freshness;
- maintainer meta suite;
- CI watch to green before the release tag, following the existing release contract.

## 6. Deterministic generation, version, and release outputs

Author the next available patch release, no earlier than `0.51.3`; if another item consumes it, use the next available version. Do not hand-stamp version machinery. Before invoking release automation, all four changelog heads must carry the same selected numeric version and the B-63/B-56 notes in their correct maintainer or consumer voice.

The release session has these deterministic outputs and all must appear in the release commit diff or its append-only release evidence. They do not exist yet during the pre-release implementation review and must not be invented in the pre-release backlog closure:

1. **Authored release notes before release**
   - `CHANGELOG.md`
   - `src/stacks/dotnet/files/CHANGELOG.md`
   - `src/stacks/angular/files/CHANGELOG.md`
   - `src/stacks/monorepo/files/CHANGELOG.md`
   - composed copies `dist/{dotnet,angular,monorepo}/CHANGELOG.md`

2. **Files stamped by `.claude/scripts/release.ps1`**
   - root `CHANGELOG.md`: head `Unreleased` is replaced with the release date;
   - `src/core/CLAUDE.md`: `version` and `applied` header fields;
   - `src/stacks/dotnet/files/.claude/framework-version.json`;
   - `src/stacks/angular/files/.claude/framework-version.json`;
   - `src/stacks/monorepo/files/.claude/framework-version.json`;
   - root `README.md`: “Current shipped version” line.

3. **Composed stamp copies after the release rebuild**
   - `dist/{dotnet,angular,monorepo}/CLAUDE.md`;
   - `dist/dotnet/.claude/framework-version.json` from the dotnet source overlay;
   - `dist/angular/.claude/framework-version.json` from the angular source overlay;
   - `dist/monorepo/.claude/framework-version.json` from the monorepo source overlay;
   - the five B-63 generated families enumerated in §4.

4. **Deterministic release evidence written by the release path**
   - `meta/context-footprint.json`, updated by `scripts/context-footprint.ps1 -Update`;
   - `meta/review-ledger.md`, with the independent reviewer evidence appended for the selected version.

The three source consumer changelogs are not stamped by the current release script (B-54 owns that automation gap); their composed dist copies reproduce exactly what was authored. B-63 must neither claim release automation dated them nor absorb B-54 silently. Review the final consumer headings explicitly before release.

Finalize the B-63/B-56 Done entry and RCA before invoking `.claude/scripts/release.ps1`, using only implementation, mutation, focused-suite, composition, and deterministic-gate evidence already observed. Release only through `release.ps1`. Its review-ledger row and the handoff report own the later release/CI outcome; do not edit `meta/BACKLOG.md` after the release commit, create a hidden post-CI commit, or imply that pre-release closure predicted CI. The user retains the final Claude review and release action.

## 7. Implementation sequence

1. Record this amended plan and obtain independent adversarial approval.
2. Add the Copilot-only and Claude-Bash red cases; record their distinct failures on `085045b`.
3. Add registration-demand, semantic comparison, stack wording/canary, and exact mutation controls.
4. Derive `bashGuardRegistered` from both registration surfaces in both twins.
5. Delete `Invoke-BashProbe`; implement the fixed parser branch with its unique mutation markers.
6. Correct wired-shell, stack-toolchain, Copilot wording, Finish canaries, and consumer documentation.
7. Append the WSD-026 correction without altering its history.
8. Run the focused host matrix and parser/BOM/shell syntax checks.
9. Write root and consumer release notes.
10. Compose all three dists and verify every generated family.
11. Run all deterministic pre-release gates.
12. Finalize the B-63/B-56 Done entry and RCA from the evidence observed through step 11; rerun the affected meta check after this final backlog edit, then obtain the required independent review over the complete pre-release diff. No backlog work remains after this step.
13. Release in the next available patch slot through `release.ps1`; inspect every deterministic output in §6 and let the existing release path watch CI before tagging.
14. Report the release/CI result in the release ledger and user handoff only. Make no post-release backlog edit or follow-up commit merely to add that outcome.

## 8. Explicit exclusions

- **B-85:** do not add well-known PowerShell/MSIX discovery to Bash scripts or gates. B-85 owns local Bash gate-host discovery and its diagnostics.
- Do not change which stack tools `post-write` consumes, its trigger grammar, throttles, build commands, or feedback JSON. B-63 changes doctor wording/canaries and tests only for that row.
- Do not modify `guard.ps1`, `guard.sh`, parser resolution in hooks, or registration files.
- Do not bundle or pin `jq`/Python.
- Do not add a shared capability-probe framework.
- Do not reconstruct an agent host’s environment from registry entries, well-known paths, profiles, or the developer terminal.
- Do not make `CANT-VERIFY` affect exit status.
- Do not weaken parity assertions globally; permitted differences are fixture-specific and set-equal to observed divergence.
- Do not absorb B-54, B-85, or unrelated stack-toolchain behavior into the B-63 closure.

The previous unconditional exclusion of `Stack toolchain` is intentionally removed: its capability set remains unchanged, but its overclaiming detail and missing actual-host canary are in scope.

## 9. Residual risks

- The Bash doctor observes its own invocation’s `PATH`, not necessarily the environment Claude Code or Copilot later supplies. Its wording and the write canary preserve that boundary.
- Parser and toolchain availability can change between doctor execution and hook invocation.
- A command named `jq` is accepted by the current guard’s common-path grammar without the Python-style round-trip probe. This plan does not redesign `guard.sh`; a broken `jq` binary remains a separate residual.
- Tests construct shell environments but cannot reproduce every vendor host’s environment injection or Preview policy.
- Absolute interpreter existence on the doctor’s machine does not make committed wiring portable.
- A declared Copilot `bash` target can be extracted from malformed JSON even though Copilot will reject the file; `Copilot surface` owns that independent failure.
- The post-write canary is intentionally manual and reversible because a deterministic test cannot prove a vendor host’s environment. Throttling and model-side diagnosis can obscure the result unless the exact hook prefix is required.
- Honest `CANT-VERIFY` gives less automated reassurance than the previous inferred `[OK]`; that loss is deliberate.

## 10. Proportionality and alternatives

### Chosen: remove one invalid inference and correct the audited claims

Delete one child-process probe, reuse existing registration extraction, correct three detail families, add one canary, and strengthen one fixture suite. The stack-toolchain commands and all hook behavior remain untouched. This is the smallest change that closes the audited class rather than only the initially failing comparison.

### Rejected: probe Bash or toolchains harder from PowerShell

Searching profiles, registry entries, Git installations, or well-known paths cannot reconstruct the environment the agent host supplies later. WSD-026’s surviving rule and direct measurements reject this approach.

### Rejected: pin every hook interpreter absolutely

v0.38.1 proved that a developer-specific absolute path in committed team settings breaks teammates across OS and profiles. The correct response to an unobservable bare-name lookup is liveness/canary evidence, not restoring the reverted v0.38.0 policy.

### Rejected: make both twins always `CANT-VERIFY`

That discards useful shell-local evidence. The Bash doctor is executing in an environment whose commands it can test; the result remains useful when scoped honestly.

### Rejected: keep production code and normalize rows away in tests

That would retain false `[OK]` claims and hide the pre-existing Copilot JSON asymmetry. Fixture-specific set equality makes every permitted difference explicit and rejects new drift.

### Rejected: shared capability or registration framework

The audit found one invalid child probe plus bounded wording defects. A new abstraction across hooks, doctors, and gates would exceed observed harm, recreate B-108’s disproportional parser/resolver design, and enlarge twin maintenance.

### Rejected: bundle or absolutely pin a JSON parser

That takes ownership of interpreter distribution, updates, platform compatibility, and security to repair an honesty defect in a developer diagnostic.

## 11. Closure RCA requirements

The Done entry must answer:

- **Why no gate caught it:** the original twin tests coupled Claude and Copilot registrations through one `-Shell` fixture and demanded whole-output equality while inheriting ambient host tools. They had no genuine no-Bash fixture, no Copilot-only Bash fixture, no absolute `bash`/`bash.exe` target cases, no pinned child-Bash success case requiring PowerShell `CANT-VERIFY`, and no fixture-specific model for the already documented Copilot JSON asymmetry.
- **What else was exposed:** every doctor probe was classified by capability consumer and observation vantage. The audited additional changes are limited to portable wired-shell remediation, current-environment scoping for stack/Copilot command details, and an actual-host post-write canary. B-85 remains separately owned; hook parser/toolchain behavior is unchanged; B-54 remains the consumer-changelog stamp gap.
- **Why the tests are load-bearing:** record both pre-fix reds, the fixed/mutant contrast under the same `PATH`, reachable no-Bash/PS-only success, direct-Bash parser outcomes, controlled Copilot both/neither/one-twin visibility, exact summary/exit derivation, pwsh and 5.1 results, and the fixture-specific divergence-set checks.

The Done/RCA text is frozen before `release.ps1` and cites only pre-release evidence. A release commit SHA, CI run conclusion, or tag is not closure evidence available at that point and must not be added later to `meta/BACKLOG.md`; those facts belong to `meta/review-ledger.md` where the release path records review evidence and to the final handoff. If release or CI fails, follow the release tool’s existing recovery contract rather than silently amending the already-pushed release commit or creating a bookkeeping-only post-CI commit.
