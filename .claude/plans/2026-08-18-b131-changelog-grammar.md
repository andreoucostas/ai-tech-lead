# B-131 changelog-head grammar comparison

## Exact release grammar

`.claude/scripts/release.ps1` first selects the literal first column-zero H2 using:

```regex
(?m)^## [^\r\n]*
```

It then requires that entire selected line to match:

```regex
^## ([0-9]+\.[0-9]+\.[0-9]+) — (Unreleased|[0-9]{4}-[0-9]{2}-[0-9]{2})$
```

Therefore the release grammar is exactly `## X.Y.Z — Unreleased` or `## X.Y.Z — YYYY-MM-DD`: ASCII spaces as shown, a literal em dash, numeric triplet, and no trailing text. A non-version first H2 is fatal even if a valid version H2 appears later. Later release logic also requires the requested version and consistent state/date across the four authored heads.

## Exact template-checks grammars

PowerShell scans line by line and stops at the first version-shaped H2:

```regex
^## (\d+\.\d+\.\d+)
```

Bash selects the first matching line and extracts its numeric prefix with:

```regex
^## [0-9]+\.[0-9]+\.[0-9]+
^## ([0-9]+\.[0-9]+\.[0-9]+).*
```

Both twins then compare only that captured version with `framework-version.json`. If it matches, they reject the selected line only when the word `Unreleased` appears. They do not require an em dash, a date, a whole-line match, or the version-shaped heading to be the literal first H2. If no version-shaped line exists, both treat the changelog as absent and pair-check only Claude/JSON stamps.

## Divergence and failure direction

Release is strictly narrower. For example, a file headed `## Unreleased` followed by `## 0.58.0 — 2026-08-17` is rejected by release (the literal first H2 is malformed) but accepted by both template twins (they skip to `0.58.0`). Likewise `## 0.58.0 arbitrary text` is rejected by release but accepted by template-checks unless that text contains the word `Unreleased`.

The operational failure direction is fail-safe but self-inflicted: template-checks can report green and release can later refuse. The converse is not available for the same target/current-version state: a line accepted by release has a version prefix template-checks recognizes; its dated state avoids the template `Unreleased` rejection.

## Four live heads

Command: read each file with explicit UTF-8 and select its literal first `## ` line. Observed:

```text
CHANGELOG.md => ## 0.58.0 — 2026-08-17
src/stacks/dotnet/files/CHANGELOG.md => ## 0.58.0 — 2026-08-17
src/stacks/angular/files/CHANGELOG.md => ## 0.58.0 — 2026-08-17
src/stacks/monorepo/files/CHANGELOG.md => ## 0.58.0 — 2026-08-17
```

All four live heads are accepted by both grammars. None is accepted by one and rejected by the other. Later historical/unreleased sections do not affect either parser because both stop at their respective first match.

## Recommendation

The release grammar should win for framework-owned changelogs: literal first H2, exact two-state whole-line grammar. It matches this repo's atomic four-head release workflow, keeps the visible head authoritative, and fails before mutating an ambiguously structured file. The full B-131 implementation should apply that grammar to marked template repos only; consumer-owned changelogs must remain outside this framework gate, as the backlog's ownership constraint requires.

No behavior was changed for B-131 in this task.
