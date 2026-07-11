# B-25-EXEC Phase 4 — monorepo mode (execution plan)

> Date: 2026-07-09. Executes MERGE-MIGRATION-PLAN.md §5 Phase 4 against `ai-tech-lead@bf68742`.
> **EXECUTED 2026-07-10 — all work items done; mechanism recorded as WSD-015; evidence in
> MERGE-MIGRATION-PLAN.md Phase 4 checkboxes. Kept for the design rationale.**

## Measured inputs (this session)

- All **114** shared snippet pairs are **divergent** (zero identical); 2 one-sided
  (`security-auditor.agent.md/findings-note` dotnet-only, `.gitignore/prepend` angular-only).
- **38 colliding whole-file overrides** (same relpath in both `stacks/*/files/`), from 2-line
  (`settings.json` `_comment`, `framework-version.json`) to full merges (`bootstrap.md` 192/318,
  `post-write.*`, `cases.yaml`).
- Script snippets are additive-safe as the signed plan predicted: `route-prompt` grep snippets are
  self-contained `if …; then sensitive="1"; fi` lines; `audit-trail` skip snippets are independent
  `case` branches. Raw concatenation = union semantics.
- Prose snippet pairs are mostly **parallel variants of the same rules** (e.g. `verif-rules` = two
  1–7 lists differing in flavour words). Raw concatenation would duplicate rule lists — unusable.
- Root installer already stubs monorepo ("arrives in Phase 4"); CI/validate-dist enumerate
  dotnet|angular only; `tests/hooks/` is core-identical and must pass against merged hooks.

## Design: monorepo composition mechanism (keeps the composer dumb)

`build.{sh,ps1} monorepo`:

1. **Snippet resolution order** at each marker: `src/stacks/monorepo/snippets/<rel>/<NAME>` if
   present (authored merged/sectioned content) → else **concat** dotnet snippet then angular
   snippet (either may be absent; one-sided passes through). Marker removed if none exist.
2. **File overlay**: union of `dotnet/files`, `angular/files`, `monorepo/files`.
   `monorepo/files` wins. A path present in **both** stack dirs with **no** monorepo override is a
   **build error** — no silent last-wins; every collision is an explicit authored decision.
3. Same unresolved-marker validation as single-stack.

Rejected alternatives: (a) qualified include-markers (`@stack:dotnet:NAME`) inside monorepo
snippets — keeps derivation but adds a templating feature with <5 real consumers (Leanness #8);
(b) composer-inserted `### .NET`/`### Angular` headings — composer can't know prose vs frontmatter
vs script context (would corrupt YAML descs).

Accepted cost: authored monorepo snippets/files are a third authoring surface for *divergent*
content. Mitigations: concat-by-default keeps derived everything that can be derived (all script
snippets); build error pins file collisions; discipline recorded in DEVELOPING.md ("editing a
stack snippet/file with a monorepo sibling requires reviewing that sibling"); CI dist-freshness
still proves src→dist for all three.

Acceptance-criterion-5 note: a *core* edit reaches all three dists automatically; a *stack
snippet* edit reaches monorepo automatically **iff** no monorepo override exists — the audit
below minimizes overrides.

## Work items

1. **Composer twins** `build.sh`/`build.ps1` + `validate-dist` + CI + root installers accept
   `monorepo` (fidelity-check stays dotnet/angular — no freeze baseline for a new dist). *(me)*
2. **Marker audit** — all 116 names classified CONCAT vs AUTHOR; table in scratchpad, outcome
   summarized in the WSD entry. *(me)*
3. **Monorepo snippets** for AUTHOR-class markers. CLAUDE.md's 28 *(me — flagship, token-budgeted:
   merged shared wording once; `### .NET`/`### Angular` only for genuinely disjoint content, per D4)*;
   commands/agents/prompts/misc batches *(subagents: Opus for content merges, Sonnet for formulaic
   one-liner desc/summary merges)*.
4. **38 monorepo whole files**: hooks (`post-write.*` per-extension dispatch, `boy-scout-check.*`),
   `metrics.*`, `settings.json`, `framework-version.json` (`"template": "monorepo"`), AGENTS.md +
   copilot-instructions.md (generated from composed monorepo CLAUDE.md per /generate-copilot rules)
   *(me)*; commands (bootstrap/adopt gain the monorepo instruction), agents, 4 shared-name skills
   (sectioned; `.github` mirrors = byte copies), docs set, README/FRAMEWORK-CONTEXT/CHANGELOG,
   cases.yaml/tasks.json unions *(subagents, my review)*; `architecture.html` regenerated via
   `scripts/build-architecture-html` from merged ARCHITECTURE.md.
5. **Verification**: 3-host byte-determinism (bash / PS5.1 / pwsh7) for dist/monorepo;
   validate-dist monorepo green (incl. template-checks AGENTS.md verbatim gate); core
   `tests/hooks` suite green against merged hooks; route-prompt union fixtures (.NET `money` and
   Angular `sanitiz` keywords each fire the overlay; both fire together coherently); post-write
   dispatch fixtures (.cs → dotnet path, .ts under src/ → tsc path); installer smoke incl.
   mixed-repo auto-detect → monorepo; **token measurement** of monorepo CLAUDE.md vs single-stack
   recorded (D4 fallback trigger >~1.5×).
6. **Records**: MERGE-MIGRATION-PLAN checkboxes, WSD entry, LEARNINGS (if traps found), BACKLOG,
   commit+push `ai-tech-lead` and meta repo.

## Out of scope (Phase 5/6)

release.ps1 retarget, D7 meta-layer move, root README/CHANGELOG freeze, scratch-repo install
validation matrix, archive/tag.
