# AI Tech Lead (.NET + Angular monorepo) — Changelog

> Release notes for the mixed .NET + Angular distribution, written for the teams who install it:
> what changed in **your** repo, and what (if anything) you need to do. This distribution carries
> the rails of both stacks, so entries may apply to one side or both.
> Architecture decisions you record live in `docs/architecture-decisions.md`.

## 0.26.2 — 2026-07-12 (housekeeping)

> No behavior change, nothing to do. Keeps this distribution's version in step with the .NET and
> Angular distributions, which had a mangled character repaired in a hook comment.

## 0.26.1 — 2026-07-12 (these release notes are now written for you)

> Documentation and comments only — **no behavior change, nothing to do**. Re-run the installer
> whenever convenient.

### Changed
- **These release notes are written for the teams who install the framework**, not for its
  maintainers: what changed in your repo, and what you need to do.
- **Internal tracking ids removed from the comments in shipped code** — the hooks
  (`.claude/hooks/post-write.*`), the scripts (`scripts/template-checks.*`,
  `scripts/build-architecture-html.ps1`), and the hook tests. Comments now state the rule the code
  enforces instead of the ticket that produced it, so they read as intended in *your* repo. Behavior
  is untouched; the hook test suites pass unchanged.
- **Stale cross-references removed** from `README.md` and this changelog — they pointed at two
  predecessor repositories that are now archived.

## 0.26.0 — 2026-07-12 (first release of the mixed .NET + Angular distribution)

> This is the first release of the monorepo distribution — for repos that hold **both** a .NET
> solution and an Angular workspace. It carries the union of both stacks' rails, and dispatches
> per file type: a `.cs` edit runs the .NET gate, a `.ts` edit runs the Angular one.
>
> **What you need to do:** if you have a mixed repo, the installer now auto-detects it and selects
> this distribution. Pass `--stack monorepo` to force it.

### Changed
- The framework's own CI workflows (`template-ci.yml`, `docs-sync-check.yml`) now pin
  `actions/checkout@v5`, following GitHub's Node 20 runtime deprecation. No change to your
  application code.

---

## 0.25.5 — 2026-07-06 (monorepo template debut)

> First release of the combined template for repos that carry **both** a .NET backend and an
> Angular frontend in one repository. It ships both stacks' rails — conventions, hooks, skills,
> subagents, and workflows — from a single source of truth, at parity with the two per-stack
> templates as of v0.25.5.

### Added
- **Monorepo template** installing both stacks' rails together: the .NET Common-Task skills
  (add-endpoint, add-entity, register-service, perf) alongside the Angular ones (add-component,
  add-service, add-lazy-route, add-signal-store), the shared skills (add-tests, dependency-audit,
  create-adr, enforce-architecture, enforce-standards), the seven subagents, and the seven
  workflow commands — one `CLAUDE.md` / `AGENTS.md` covering both stacks.
- **Both stacks' deterministic hooks** wired in one `.claude/settings.json`: the PreToolUse guard
  (blocks warning-suppressions & secrets in `.cs` and `.ts`), the PostToolUse `dotnet build`
  (`.cs`) and `tsc --noEmit` (`.ts`) checks, the SR 11-7 / DORA audit trail, and the Stop Boy
  Scout scanner with each stack's always-apply patterns.
- **Merged CI guardrail and Bitbucket Data Center guidance** covering both legs — .NET
  (`dotnet build -warnaserror` + `dotnet test`) and Angular (`eslint` + `ng build` + `ng test`) —
  in `docs/ci-integration.md`.
