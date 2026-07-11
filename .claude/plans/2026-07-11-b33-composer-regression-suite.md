# B-33 — Composer regression suite + sibling-drift gate (Phase-6 precondition)

**Status: EXECUTING 2026-07-11.** Meta-only (no shipped content — freeze-compatible under
WSD-012). Sequenced before Phase 6 because v0.26.0 retires the fidelity legs, today's only
end-to-end composition-correctness proof (see BACKLOG B-33 for the full rationale).

## Deliverables

1. **`.claude/hooks/tests/ComposerFixtures.Tests.ps1`** — fixture-based composer regression
   suite. Auto-picked-up by `Invoke-HookTests.ps1` (globs `*.Tests.ps1`), so it wires into
   `release.ps1` and both `ci.yml` legs with zero runner changes.
2. **`scripts/check-sibling-drift.ps1` / `.sh` twins** [#3] — the WSD-015 gate — plus
   `.claude/hooks/tests/SiblingDrift.Tests.ps1` red/green tests, and a `ci.yml` step per leg.
3. **`.claude/hooks/tests/SrcHygiene.Tests.ps1`** — the tool-syntax leakage sweep
   (`</content>` / `</invoke>` under `src/`, LEARNINGS 2026-07-10) as a permanent gate.
4. **`.claude/hooks/tests/RoutePromptUnion.Tests.ps1`** — the additive-safety canary: the
   composed `dist/monorepo` route-prompt twins must flag a dotnet-only keyword (`ledger`) AND
   an angular-only keyword (`bypasssecuritytrust`); negative control included. (Pins the
   LEARNINGS 2026-07-10 `-or`-merge fix; lives meta-side because dist tests are
   shipped content and frozen until v0.26.0 — candidate for promotion into the dist suites
   at/after the release.)
5. Docs: DEVELOPING.md sections, BACKLOG B-33 → Done, this plan.

## Design: composer fixture harness (deliverable 1)

- **Sandbox, don't parameterize:** both composer twins anchor to `<script-dir>/..`
  (`cd "$(dirname "$0")/.."` / `$MyInvocation.MyCommand.Path`). The test copies the repo's
  real `scripts/build.sh` + `build.ps1` (the bytes under test — unmodified) into
  `<tmp>/scripts/`, writes a fixture `src/` tree next to them, runs the composer, and
  inspects `<tmp>/dist/<mode>`. No composer changes.
- **Fixtures are programmatic, never committed files** — committed fixture bytes would be
  exposed to `core.autocrlf`/BOM mangling (LEARNINGS 2026-07-04). Tests write exact bytes
  via `[IO.File]::WriteAllBytes` / UTF8-no-BOM `WriteAllText`.
- **Both twins on the same fixture**, invoked as child processes (`& (Get-PsExe) -NoProfile
  -File … <mode>`; bash via the harness `Get-BashPath`, self-skip if absent), capturing
  `$LASTEXITCODE` + stderr to a temp file (never set `$ErrorActionPreference='Stop'` around
  native calls — LEARNINGS 2026-07-09 #2).
- **Assertions:** per-file byte-compare against expected bytes defined in the test, plus a
  recursive byte-compare of the `.ps1`-composed tree vs the `.sh`-composed tree (local twin
  proof over fixtures, stronger than CI's shared-golden-dist proof).
- Fixture `src/` skeleton always creates `src/stacks/{dotnet,angular,monorepo}/{snippets,files}`
  dirs (the `.ps1` collision check `Resolve-Path`s them under EAP=Stop).
- Trailing-newline semantics to encode in expectations: marker-substituted files always end
  with `\n` (awk `print` / `join+"\n"`); plain copies preserve a missing trailing newline.

### Fixture matrix (defect classes; RED cases plant the defect and assert non-zero exit)

| # | Class | Assert |
|---|-------|--------|
| F1 | HTML marker substitution, single-stack | marker line replaced by snippet lines |
| F2 | `#` hash marker substitution (scripts) | same |
| F3 | Absent snippet | marker line removed, no residue |
| F4 | Monorepo authored override precedence | monorepo snippet only — NOT the concat |
| F5 | Monorepo concat union | dotnet lines then angular lines; one-sided works |
| F6 | Whole-file override | `files/` beats core in that stack's dist; core intact in the other |
| F7 | Stack-only file | lands in dist |
| F8 | RED: monorepo `files/` collision, no override | exit 1 + `ERROR:` names the rel path; with an override → exit 0 + override content |
| F9 | RED: unresolved marker (inline, non-exact-line `@stack:` text) | exit 1 + `ERROR: unresolved` |
| F10 | Byte fidelity | BOM preserved (plain copy AND through substitution); CRLF→LF; missing trailing NL preserved on plain copy |
| F11 | RED: usage | invalid mode → exit 2, both twins |
| F12 | Twin agreement | every green fixture: `.ps1` tree ≡ `.sh` tree byte-for-byte |

## Design: sibling-drift gate (deliverable 2)

`scripts/check-sibling-drift.{sh,ps1} [base-ref]` — diff-scoped, twins with identical
decisions, anchored to `<script-dir>/..` (so tests sandbox-copy them like the composer).

- Base: arg, default `HEAD~1`. `git rev-parse --verify --quiet <base>^{commit}` fails (zeros
  SHA on force-push/branch-create, root commit) → `NOTICE: … skipped (base unresolvable)` +
  exit 0 (loud fail-open: the range is unknowable, and blocking every branch-create push is
  worse; the PR leg always has a real base).
- Range: `MB = git merge-base <base> HEAD` (fallback `<base>`); touched =
  `git diff --name-only MB HEAD`.
- For each touched path `src/stacks/(dotnet|angular)/(snippets|files)/<rest>`: sibling =
  `src/stacks/monorepo/<kind>/<rest>`. Violation ⇔ sibling exists in the worktree AND is not
  itself in the touched set AND no override trailer.
- Override trailer (the "reviewed, sibling already correct" escape hatch — reviewable in
  history, unlike a warning nobody reads): any commit body line in `MB..HEAD` matching
  `Sibling-Reviewed: <value>` where `<value>` is `*` or a substring of either path.
- Output: `FAIL: <stack-path> changed but monorepo sibling <sibling> untouched (WSD-015 —
  update it or add a 'Sibling-Reviewed:' trailer)` per hit, exit 1; else `OK` exit 0.
- `SiblingDrift.Tests.ps1`: scratch `git init` repos (local user.name/email,
  `core.autocrlf false`), both twins, cases: violation → exit 1 naming sibling; sibling
  touched too → 0; no sibling exists → 0; trailer (exact + `*`) → 0; monorepo-only edit → 0;
  unresolvable base → NOTICE + 0. Red-before-green ordering in the file.
- `ci.yml`: one step per leg, base = `${{ github.event.pull_request.base.sha ||
  github.event.before }}`; windows runs the `.ps1`, linux the `.sh`.

## Verification (evidence per Definition of done — composer/gate class)

- Meta suite `pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1` → 0 failures,
  with the RED fixtures demonstrably failing when their planted defect is (temporarily)
  neutralized — shown once during review, not committed.
- Compose ×3 + `git status --porcelain dist/` empty (this work must not touch dist).
- validate-dist ×3 exit 0; dist hook suites ×3 exit 0 (unchanged, but re-run as regression).
- Both twins of check-sibling-drift red/green-tested via SiblingDrift.Tests.ps1 on this box
  (pwsh 7 + bash); PS 5.1 leg rides the CI windows leg (powershell fallback in the harness).

## Delegation (model-per-job)

Fixture suite + sibling gate implemented by Sonnet subagents against this spec (the B-14
pattern: Sonnet delivery, stronger-model plan + adversarial review). Plan, SrcHygiene,
RoutePromptUnion, CI wiring, docs, review, and all verification runs: Fable (this session).
Known traps the review must check: BOM on every new `.ps1` [#4], no EAP=Stop around natives,
`String.Split` not `-split -1`, EOL-normalization where files are compared, exit codes not
observed through truncated pipes (LEARNINGS 2026-07-09).
