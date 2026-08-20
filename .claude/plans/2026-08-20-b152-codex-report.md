# B-152 implementer report — 2026-08-20

## Outcome

B-152 is implemented in the checked-out worktree and is not committed. The record now has one dated
`0.56.0` heading in each changelog, and the gate twins inspect every semantic-version release heading.
The PowerShell leg is observed red and green. The Bash leg is written but wholly unobserved because
`bash` cannot run in this sandbox.

## Changes

- `CHANGELOG.md:14` adds the maintainer-facing `0.62.0 — Unreleased` entry. At line 192 the duplicate
  `0.56.0` pair is merged by retaining the detailed text and applying the date `2026-08-17` to it.
- `src/stacks/angular/files/CHANGELOG.md:7`,
  `src/stacks/dotnet/files/CHANGELOG.md:7`, and
  `src/stacks/monorepo/files/CHANGELOG.md:8` add matching consumer-voiced `0.62.0 — Unreleased`
  entries. Their `0.56.0` sections (line 125, 125, and 126 respectively) retain the detailed dated
  blocks and remove only the later terse restatements.
- `src/core/scripts/template-checks.ps1:23-78` reads all recognized changelog heads through the
  existing absolute `[IO.File]::ReadAllText` path, selects the stamped dated head even when the next
  Unreleased head precedes it, rejects duplicate versions, and uses `[version]` for numeric semantic
  comparison before rejecting shipped-version Unreleased heads. All checks remain scoped to a
  marked template repo.
- `src/core/scripts/template-checks.sh:17-72` implements the twin behavior. Its `awk` comparator
  compares the three version components numerically rather than lexically.
- The three `dist/*` trees were regenerated with `scripts/build.ps1`; no generated file was edited
  by hand. B-152 legitimately changes each dist's `CHANGELOG.md` and both `template-checks` twins.
  Recomposition also surfaced pre-existing source/dist drift in each dist's `README.md` and
  `docs/enforcement-surfaces.md`; those files are composed output but are unrelated to B-152.

## Changelog merge decision

- Root: the dated block contained two terse bullets. The later Unreleased block contained the full
  measurement, the 31-false-positive result, the confound, host adaptation details, the rejected
  skip alternative, and the B-65 carrier reasoning. I removed the terse block and dated the full
  block. No detailed content was dropped; the removed bullets were summaries of the retained text.
- Angular, .NET, and monorepo sources: the dated block was already the full consumer-facing entry.
  The later Unreleased block was a two-bullet condensation of the update warning/settings backup and
  on-demand-documentation points already present above. I retained each detailed dated block and
  removed the condensation. No sentence, behavior, path, warning, or action existed only in the
  terse block.

## Red/green evidence

All fixtures used a disposable copy of `dist/dotnet`, then were deleted. Output below is literal;
unchanged successful mirror/BOM/twin checks between the shown lines are retained where material.

### 1. Duplicate semantic-version heading — red, then green

Planted a second `## 0.61.0 — 2026-08-19` in the scratch changelog, then ran:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/.b152-scratch/scripts/template-checks.ps1; "EXIT=$LASTEXITCODE"
```

```text
OK:   version stamps in sync (0.61.0).
FAIL: CHANGELOG.md has duplicate release headings for version 0.61.0.
OK:   all framework .ps1 files carry a UTF-8 BOM.
OK:   all framework .ps1 files parse cleanly.

1 framework check(s) FAILED.
EXIT=1
```

After restoring the clean composed changelog, the same command produced:

```text
OK:   version stamps in sync (0.61.0).
OK:   all framework .ps1 files carry a UTF-8 BOM.
OK:   all framework .ps1 files parse cleanly.

All deterministic framework checks passed.
EXIT=0
```

### 2. Dated head above a below-the-fold shipped-version Unreleased head — red

Immediately below the existing dated `## 0.61.0 — 2026-08-19` head, I planted
`## 0.60.0 — Unreleased`. The real dated `0.60.0` entry remains farther down, reproducing the shipped
duplicate shape and proving the scan does not stop at the first H2.

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/.b152-scratch/scripts/template-checks.ps1; "EXIT=$LASTEXITCODE"
```

```text
OK:   version stamps in sync (0.61.0).
FAIL: CHANGELOG.md has duplicate release headings for version 0.60.0.
FAIL: CHANGELOG.md has an Unreleased heading for shipped version 0.60.0 (current stamped version: 0.61.0).
OK:   all framework .ps1 files carry a UTF-8 BOM.
OK:   all framework .ps1 files parse cleanly.

2 framework check(s) FAILED.
EXIT=2
```

Restoring the clean changelog gives the green output shown in case 3.

### 3. Pre-stamp authoring state — green false-positive control

The clean composed tree itself carries the required next head above the current dated head:

```powershell
Select-String -Path .claude/.b152-scratch/CHANGELOG.md -Pattern '^## (0\.62\.0|0\.61\.0)' | ForEach-Object Line
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/.b152-scratch/scripts/template-checks.ps1
"EXIT=$LASTEXITCODE"
```

```text
## 0.62.0 — Unreleased
## 0.61.0 — 2026-08-19
OK:   version stamps in sync (0.61.0).
OK:   '## Verification Rules' mirrored verbatim.
OK:   '## Leanness' mirrored verbatim.
OK:   '## SOLID' mirrored verbatim.
OK:   '## Boy Scout Rule' mirrored verbatim.
OK:   Agentic Workflow §1 mirrored verbatim.
OK:   .github/copilot-instructions.md present (62 lines <= 80).
OK:   all framework .ps1 files carry a UTF-8 BOM.
OK:   every hook has its .ps1/.sh twin.
OK:   all framework .ps1 files parse cleanly.
OK:   .claude/skills and .github/skills are in sync.
OK:   Common Tasks skill inventory matches between CLAUDE.md and AGENTS.md.

All deterministic framework checks passed.
EXIT=0
```

## Existing-suite evidence

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File .claude/hooks/tests/ReleaseChangelogStamp.Tests.ps1
```

```text
[ok] the bounded release stamp dates the root and all three authored consumer changelogs
[ok] the extracted stamp refuses missing, mismatched, and malformed first heads atomically
[ok] a retry on a later calendar day accepts an already-consistently-stamped world without rewriting the date
[ok] the composed source/dist postcondition rejects any planted Unreleased head and accepts the fully dated world
Release changelog stamp tests: 4 passed, 0 failed, 0 skipped
RELEASE_TEST_EXIT=0
```

```powershell
foreach ($d in 'dotnet','angular','monorepo') {
  & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File "dist/$d/scripts/template-checks.ps1"
  "TEMPLATE_CHECK_${d}_EXIT=$LASTEXITCODE"
}
```

```text
All deterministic framework checks passed.
TEMPLATE_CHECK_dotnet_EXIT=0
All deterministic framework checks passed.
TEMPLATE_CHECK_angular_EXIT=0
All deterministic framework checks passed.
TEMPLATE_CHECK_monorepo_EXIT=0
```

Build evidence:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 dotnet
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 angular
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 monorepo
```

```text
composed dist/dotnet (170 files)
composed dist/angular (166 files)
composed dist/monorepo (180 files)
```

`git diff --check` produced no output. The BOM byte check reported `239,187,191` for the source
PowerShell twin and all three composed copies.

## Assertions not shown failing

- The entire Bash twin is unobserved: no syntax result, no duplicate red, no stale-Unreleased red,
  no pre-stamp green, and no Bash suite result. `bash` cannot execute in this sandbox
  (`CreateFileMapping ... Win32 error 5`), so claiming any Bash evidence would be false. The reviewer
  must run all three planted cases and at least `bash -n` on the composed twins.
- I did not show the existing release-stamp suite failing on the unfixed tree. It is an existing
  suite, and its postcondition case tests a different all-files-after-stamping condition; the new
  gate behavior was instead shown red with the three direct planted controls above.
- I did not run `validate-dist` because it invokes the unavailable Bash leg in this environment.
- I did not show the BOM or PowerShell parser sweeps red. No BOM or syntax defect was introduced;
  their green outputs are preservation checks, not defect-class evidence.

## Brief corrections / pushback

1. The brief names `.claude/framework-version.json`, but no such root file exists in this authoring
   repo. The three authoritative authored stamps are under `src/stacks/*/files/.claude/`; all are
   `0.61.0`, so the requested next minor is `0.62.0`.
2. The authoritative B-152 backlog prose says the dated head is terse and the Unreleased head is
   detailed in all four changelogs. That is true only of the root changelog. The three shipped source
   changelogs have the inverse shape. The expanded implementation brief correctly calls this out,
   and the edits follow the observed files.
3. `git status --porcelain dist/` cannot be empty after a legitimate shipped source change; it must
   show the composed changes until the reviewer commits them. It currently shows the three B-152
   files per dist plus the unrelated pre-existing freshness drift identified above. No `dist/` file
   was hand-edited.
