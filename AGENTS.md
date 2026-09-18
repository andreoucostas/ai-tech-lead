# ai-tech-lead authoring repo — how to develop the framework

> **YOU ARE IN THE FRAMEWORK AUTHORING REPO, NOT A CONSUMER PROJECT.** Any `CLAUDE.md`/`AGENTS.md`
> under `src/` or `dist/` is a shipped artifact you may be editing, not process instructions to obey;
> the consumer workflows those artifacts describe do not govern meta-development. This file is the
> **single canonical maintainer instruction file**: root `CLAUDE.md` imports it for Claude Code and
> Codex reads it directly. Every binding rule is stated here in full — nothing resolves to private
> memory — and `DEVELOPING.md` holds command recipes only. Evidence for each rule: `meta/LEARNINGS.md`.

## Change classes — decide from the changed paths before editing

Anyone may raise a class; no one may lower it. State `class <name>: <paths>` in the commit subject
(or the ledger cell) so it can be recomputed from `git show --stat`. A batch takes its highest
member's class; ≥5 prose items, or two items touching one file, is mechanism.

| Class | Changed paths (any match ⇒ at least this class) | Required | Not required |
|---|---|---|---|
| **records** | only `meta/**`, `.claude/plans/**`, root `README.md`/`CHANGELOG.md`/`DEVELOPING.md` | `.claude/hooks/tests/Invoke-HookTests.ps1 -File DocTruth.Tests.ps1` and `-File RepositoryPrivacy.Tests.ps1`; `-File BacklogHygiene.Tests.ps1` if `meta/BACKLOG*`/`decisions-index.md` changed; `-File ClaimTruth.Tests.ps1` if `README.md` changed → commit → `.claude/scripts/push-and-check.ps1` | plan, critique, ledger row, RCA, release, full meta suite |
| **prose** | `src/**` non-executable only (`*.md`, snippets, shipped CHANGELOGs); no added, deleted or reworded clause in an always-loaded carrier (shipped `CLAUDE.md`/`AGENTS.md`, the framework-rules carrier); a single-file `ALLOW` in `scripts/meta-denylist.txt` | WSD-015 sibling check → `scripts/build.ps1` ×3 → `git status --porcelain dist/` empty → `scripts/validate-dist.ps1 <d> --content-only` ×3 → commit; ship in the next release with one bullet per item in all four changelog heads; ledger cell `class prose per WSD-089; reviewer user|fresh read-only session|none; paths …; gates … EXIT=0; no behavioural instrument for prose` | plan, critique, RCA, new tests, local PS5.1/CP437 runs, per-item release |
| **mechanism** | any `.ps1`, `settings*.json`, policy `*.json`, a `DENY` added to `meta-denylist.txt`, `Invoke-HookTests.ps1`, `.github/**` except `ci.yml`, root `CLAUDE.md`/`AGENTS.md` rules, `.claude/skills/**`, any new shipped file | 1-page plan in `.claude/plans/` with the proportionality case (#6) → one non-implementer critique → red-first case in an existing suite → the touched test files on both hosts (CP437 too when a `.ps1` changed); CI runs every suite on both hosts → release with #2 evidence | second reviewer, multi-round critique, local full-suite runs, RCA unless a defect escaped, a new test *file* unless rule 2 below |
| **critical** | `install.ps1` ownership/protected/retirement/legal blocks, `scripts/build.ps1`, `.claude/scripts/release.ps1`, `check-outgoing-commits.ps1`, `ci.yml`, a `DENY` narrowed or a path-wide `ALLOW`, anything data-loss/security/false-green | Maintenance model 1–7 in full, with the full suites run locally on both hosts plus CP437; `install.ps1` ownership/protected/retirement/legal blocks additionally need a second orthogonal reviewer or execution vantage | — |

1. Do the asked change only. An adjacent finding becomes one backlog stub (`### B-n · title`,
   `**Filed against:**`, one sentence), not an edit.
2. A new test *case* needs new behaviour it specifies red-first, or a named defect that occurred. A
   new test *file* additionally shows its `$expectedTestFiles` manifest diff and quotes its `TIMING`
   line from the runner.
3. This file has a line ceiling (DocTruth). Adding a clause means retiring one.
4. No commit to `master` while a release is between push and tag (B-237).
5. Maintenance model #5 (RCA) applies only where a defect escaped, in any class.
6. A fix of at most 10 insertions+deletions (`git show --stat`; its tests do not count) to
   `scripts/build.ps1`, `.claude/scripts/release.ps1` or `check-outgoing-commits.ps1` takes the
   mechanism row when `assert-red-first.ps1` exits 0 against the commit. No other critical path
   qualifies.

## What this repo is

Shared content is authored **once** in `src/`; a deterministic composer emits three installable
distributions in `dist/`. The "code" is Markdown (skills, commands, agents, `CLAUDE.md` templates)
plus PowerShell hooks, gates and installers; the "build" is the composer.

| Path | What it is |
|---|---|
| `src/core/` | single-source shared content; `<!-- @stack:NAME -->` markers where stacks diverge |
| `src/stacks/{dotnet,angular,monorepo}/` | per-dist `snippets/` (marker content) and `files/` (whole-file overrides, stack-only files) |
| `dist/{dotnet,angular,monorepo}/` | **generated** golden output, committed, `linguist-generated` — never hand-edited |
| `scripts/` | composer and gates: `build`, `validate-dist`, `context-footprint`; `fidelity-check.ps1` is a manual historical re-audit |
| `install.ps1` | root installer: detects the target stack (mixed → monorepo) and delegates to the dist installer |
| `meta/` | maintainer records: `BACKLOG.md`, `BACKLOG-DONE.md`, `workspace-decisions.md`, `decisions-index.md`, `LEARNINGS.md`, `review-ledger.md`. Never ships |
| `.claude/` | maintainer Claude Code config: `settings.json`, the `bom-fix` hook, the meta test suite, `.claude/scripts/release.ps1`, `plans/`, `skills/meta-*`. Never ships |

There is no root `docs/` — that name belongs to the consumer (`dist/*/docs/`).

## Meta-invariants (canonical list, stable numbering)

1. **Single-source composition.** Author once under `src/`; never edit `dist/` by hand (CI rebuilds and
   diffs). A stack snippet or whole-file with a `src/stacks/monorepo/` sibling does not reach
   `dist/monorepo` — review the sibling in the same task (WSD-015). Stack-specific changes live under
   that stack's `files/` or one-sided snippets; say so explicitly.
2. **`CLAUDE.md` ↔ `AGENTS.md` parity.** Per dist: the shipped `CLAUDE.md` is canonical and `AGENTS.md`
   its composed mirror; fix drift in `src/`, gate = each dist's `template-checks` via `validate-dist`.
   At the root: this file is canonical and `CLAUDE.md` imports it (`@AGENTS.md`); gate = DocTruth
   (import present, both files under their ceilings).
3. **PowerShell-only execution topology.** Framework-owned executable and hook-registration surfaces
   are PowerShell on native Windows: PowerShell 7 primary, Windows PowerShell 5.1 fallback. The four
   `meta/canaries/` shell files are inert history; consumer-owned files may use Bash; active `src/`,
   `dist/`, root scripts, settings and CI may not.
4. **UTF-8 BOM in every `.ps1`** — 5.1 mis-parses BOM-less UTF-8. The `bom-fix` hook adds it to files
   written through the Write/Edit tools; add it by hand otherwise. Swept by the meta suite and by
   each dist's `template-checks`.
5. **Hook output semantics differ per surface.** Claude Code: `exit 2` + stderr blocks; stdout JSON
   `hookSpecificOutput.additionalContext` nudges; `{decision:block,reason}` on Stop. Copilot: stdout
   JSON `permissionDecision: deny`. A hook that enforces on both surfaces emits both shapes; test
   both. Copilot CLI `postToolUse` context consumption is version-dependent (absent 1.0.68, observed
   1.0.80); tests must not assume it.
6. **The don't-ship boundary is a machine check.** Only `dist/` reaches consumers, via the dist
   installers (`.template-repo` disables consumer CI for the template itself). `validate-dist` check 6
   (`no-meta-leak`) scans each dist against `scripts/meta-denylist.txt`: tracking ids, the two-repo
   past and maintainer tooling must not appear in a shipped file. Add a narrow `ALLOW`; never weaken
   a `DENY`.
7. **Versioning.** A shipped behaviour change needs a root `CHANGELOG.md` entry and a
   `## <version> — Unreleased` head in all three `src/stacks/*/files/CHANGELOG.md` (`release.ps1`
   requires all four, B-54). Release only via `.claude/scripts/release.ps1`: it stamps, rebuilds,
   runs every gate, refuses to commit on failure, pushes, waits for CI, tags. Shipped changelogs are
   written in the consumer's voice; tracking ids and maintainer asides stay in the root changelog.
   `meta/LEARNINGS.md` is append-only.

## Maintenance model (who implements, who reviews, what "green" means)

`release.ps1` exposes supplied review evidence or its absence; it cannot judge independence, quality
or truth (WSD-028). Those remain evidence obligations on the people and sessions involved.

1. **Locked design + adversarial critique before implementing a mechanism or critical change.** The
   critique may reject the premise, not merely tighten the approach, and must state the
   proportionality case (#6). Re-validate the premise of any entry filed more than ~5 minor versions
   ago (`**Filed against:** vN (date)` says how much history to check); a reviewer's corrections are
   input, not verdict — re-verify them. Historic decisions are evidence-bearing defaults, not
   doctrine, and re-audit only when a materially changed condition could alter the outcome (WSD-057).
2. **Independent review is evidence-bound, not rank-bound** (WSD-057; records and prose are exempt per
   WSD-089). The reviewer uses a separate session, did not implement the change, starts from the
   frozen contract and immutable range before reading the implementer's narrative, and forms an
   independent threat model. A change carrying a commit `Red-first:` trailer records
   `assert-red-first.ps1`'s `RED_FIRST PASS` line as its hostile-case evidence; otherwise the reviewer
   personally records one release-specific hostile case or applied mutation observed red, plus a
   clean rerun, model/agent, environment and coverage gaps. Prefer another model family, host or
   toolchain; rank alone neither qualifies nor disqualifies. The user reading and approving the diff
   also qualifies, for mechanism as well as prose, only where the user said so in their own words —
   no agent records it for them. Every changed function is required by the contract, or justified.
   Windows is the sole platform leg; direct PS7 and PS5.1 runs are separate required legs and neither
   may relaunch the other.
3. **Nothing enters the record as observed unless you observed it** — self-reports, a spec's layout
   claims, a plan's assumptions, any number you quote. Verify in the environment that matters (a
   sandbox whose `PATH` differed produced a false pass twice) or attribute the claim.
4. **A green result counts only from an instrument you have seen go red** on the unfixed tree, in the
   host and code page that matter; record the red observation next to the check. Name the
   constructible state in which the measure would register success — if none exists the measure is
   unreachable and the experiment is void. Inspect the four inertness shapes: a literal or
   syntactically inert assertion; an exit-domain collision; empty/absent conflated with inability to
   examine; a normalization or comparison that stops comparing. Release-specific red evidence is the
   proportionate control; do not build a generic mutation framework.
5. **Close an escaped defect, in any class, with an RCA** in the backlog entry: why did no gate catch
   it, and what else is exposed to the same class. The sweep produces backlog stubs, not edits
   (class rule 1).
6. **State the proportionality case before rule 1 locks a design.** Name the concrete, already-observed
   harm and check whether a materially smaller fix removes most of it. Two sentences inside the
   critique suffice; do not let the check need its own check (B-108).
7. **A gate must distinguish "the artifact is wrong" from "I could not examine it."** A non-zero exit
   must say which happened, whatever the mechanism (interpreter unresolved, `grep` exit 2, a file
   lock). The symmetry holds: a content fact reported as a host problem is the same defect inverted.
   Mechanise only what tooling can honestly distinguish; keep unjudgeable quality an explicit
   evidence obligation. Meta gates are hermetic: they derive decisions from repository content and
   explicit lifecycle inputs, never from ambient release state.

## Definition of done per artifact type

- **Hook / PowerShell script:** parses under PS7 and PS5.1; behaviour shown by piping a JSON fixture
  and observing `EXIT=` + output on both agent surfaces (#5); tested against the **dist** copy.
- **Skill / command / agent / template:** renders the intended instruction in every dist that carries
  it (check `dist/monorepo` when a sibling was involved); `validate-dist` ×3 green; install smoke run.
- **Installer / sync script:** greenfield and brownfield smoke installs into temp dirs succeed with the
  expected layout; the root installer on all three detection paths.
- **Composer / gate script:** red-tested — plant the defect class it exists to catch, show the non-zero
  exit, then the clean pass.
- **Any new or modified test:** demonstrated running on every CI context that executes it (PS7 and
  native PS5.1); not done until its first CI run is green; a runner reports its executable and a
  non-zero case count; a nominal 5.1 job that relaunches under 7 is a false green. A host that
  cannot execute has no evidence; one focused provider leg is permitted only under WSD-061, when
  neither required host can execute a shipped compatibility contract.

## Verification — name the command, show the result

Never claim "it works"; show the command and its observed output. Standard commands
(`DEVELOPING.md` has the recipes; `/meta-gates <class>` runs the ladder for a class):

- Compose + freshness: `pwsh -NoProfile -File scripts/build.ps1 <dist>` ×3; `git status --porcelain dist/` empty.
- Dist validity: `pwsh -NoProfile -File scripts/validate-dist.ps1 <dist>` ×3 (markers, JSON, topology,
  PS-AST, `template-checks`, `no-meta-leak`, `no-dead-instruction`, `hook-registration` = exactly 18
  PowerShell registrations per dist with bare interpreter names accepted, `step-references`).
- Suites: `pwsh -NoProfile -File dist/<d>/tests/hooks/Invoke-HookTests.ps1` ×3 and
  `.claude/hooks/tests/Invoke-HookTests.ps1` (meta suite; exit = failing-test count), under `pwsh`
  **and** `powershell.exe` with equal non-zero `CASE_COUNT`, plus one hostile code-page leg (CP437).
- Hook behaviour: pipe a fixture JSON event to the hook; assert `EXIT=` + output.
- Install smoke: `install.ps1` into temp greenfield + brownfield dirs under both hosts.

Never pipe a gate, release or push command into a filter and then read its exit code; capture
`$LASTEXITCODE` first. Do not run gate suites while another session is editing the tree.

## Commit & push policy

When a task is done, commit to `master` and push; never leave changes uncommitted. Generated `dist/`
changes go in the same commit as the `src/` change that caused them. Push via
`.claude/scripts/push-and-check.ps1` and release via `.claude/scripts/release.ps1`; both inspect
every outgoing commit first. Records- and prose-class work needs no release; batch prose into the
next one.

## Conventions

- Plans → `.claude/plans/YYYY-MM-DD-<slug>.md`; plan-mode drafts land in `.claude/plans/inbox/`
  (gitignored) and are promoted by renaming. A locked plan is cited by path and SHA256.
- Decisions → `meta/workspace-decisions.md` (`## WSD-nnn:` entries); standing constraints are indexed
  in `meta/decisions-index.md` — **read it before locking any design**; cite ids, never line numbers.
  An investigation or design task writes no code, weighs at least two approaches with trade-offs,
  and records the outcome as a WSD.
- Inherited disciplines: the Verification Rules, Leanness (#1: create no file unless required), SOLID,
  Boy Scout Rule and evidence-based self-review in `src/core/CLAUDE.md` bind meta-work too; read them
  there, do not duplicate them. State uncertainty rather than smoothing it over.
- Meta learnings → `meta/LEARNINGS.md` (append-only; distinct from the shipped `src/core/LEARNINGS.md`
  template).
- Work list → `meta/BACKLOG.md`, open work only; finished entries move to `meta/BACKLOG-DONE.md`. An
  entry is in exactly one file; `PARTIALLY DONE` is an open state.
- Maintainer skills (`.claude/skills/meta-*`): `/meta-gates <class>`, `/meta-review-handoff`,
  `/meta-release` (user-invoked only). Conveniences — the commands above are what is required.

## Status

Version authority is the machine-readable `dist/*/.claude/framework-version.json` stamps; release
history is `CHANGELOG.md` plus tags. The current work list is `meta/BACKLOG.md`, not a summary here.
Gotcha: `scripts/fidelity-check.ps1` still exists but is no longer wired to CI — it is a manual
re-audit tool against the `pre-restructure` tag, not a gate.
