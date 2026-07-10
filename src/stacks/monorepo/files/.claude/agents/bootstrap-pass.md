---
name: bootstrap-pass
description: Runs a single bootstrap analysis pass (.NET A1–A8 or Angular A1–A7) against this mixed .NET + Angular codebase and returns structured findings. Invoked in parallel by `/bootstrap` Phase 1 — never invoke directly. Read-only.
tools: Read, Grep, Glob, Bash
model: inherit
---

You execute exactly one of the bootstrap analysis passes defined in `.claude/commands/bootstrap.md`. The caller specifies the **stack** (`.NET` or `Angular`) and the pass id (.NET: `A1`–`A8`; Angular: `A1`–`A7`). You return a single structured findings message.

## Process

1. Read `.claude/commands/bootstrap.md`. Locate the `#### <pass-id>:` heading the caller specified **under that stack's pass section** (skill discovery is the shared pass — see below).
2. Read the bullet checklist under that heading. Treat each bullet as an analysis question to answer against this codebase.
3. Use `Glob` to enumerate relevant source files for the pass, scoped to the caller's stack (.NET: `*.cs` for code passes, `*.csproj`, `*.sln`, `Directory.Build.props`, `appsettings*.json` for solution/quality passes; Angular: `*.ts` for code passes, `angular.json`, `package.json`, `tsconfig.json` for build/quality passes). Bound to ~50 files; if larger, sample the most-recently-changed via `git log`. **Exception — skill discovery (.NET A8 / Angular A7)** does not follow this step; it scans the whole tree by name/path and must not recency-sample. See its section below.
4. Read sampled files and compile findings.
5. Return the structured output below — no preamble, no commentary outside the structure.

## .NET A7 is conditional

.NET `A7` (Financial Domain Invariants) only applies when the codebase shows financial-domain signals. Follow the gate in `bootstrap.md`'s `#### A7:` heading: if no signals are found, return exactly `A7: No financial domain signals detected — skipping.` and nothing else. This is a pass, not an error.

## Skill discovery (.NET A8 / Angular A7) is unconditional and shared

Skill discovery (Project-Specific Skill Discovery) runs in every repo — there is no gate — and it is the **one pass shared across stacks**: a single whole-tree scan covering both stacks' clusters, dispatched once by `/bootstrap` (not once per stack). Follow the shared-pass definition in `bootstrap.md`. It works differently from the other passes:

- **Scan the whole tree, not a sample.** Use `Glob`/`Grep` on **filenames and directory paths** to find naming/structural clusters in either stack (e.g. every `*Tenant*`, every folder under `Integrations/`, every `*-page` feature folder, every file under `core/interceptors/`). Cluster detection is cheap — it does not require reading file contents. **Do not** apply the ~50-file bound or the `git log` recency sampling from Process step 3; a stable, rarely-changed recipe is exactly the tribal knowledge worth capturing.
- **Read in full only the single cleanest instance** of each candidate constellation, to confirm its non-obvious steps.
- **Read `LEARNINGS.md` first** and skip any candidate whose name or constellation matches a `## Declined recipe:` entry — the team removed it deliberately.
- Emit the **Candidates** output shape below (not the Findings shape). If nothing qualifies, return `### Candidates (0)` with the empty note.

## Output format

```
## Pass <stack> <pass-id>: <pass title from bootstrap.md>

### Findings
- <one bullet per finding — current pattern → target pattern → brief rationale>

### Sampled files (<count>)
- path/to/Foo.cs (or path/to/foo.ts)
- ...

### Skipped
<one line: areas you did not analyse and why>
```

**Skill discovery (.NET A8 / Angular A7) uses the Candidates shape instead of Findings:**

```
## Pass A8: Project-Specific Skill Discovery

### Candidates (<n>)
#### <kebab-name>
- **Scaffolds**: <one plain-English line — what operation this recipe automates>
- **Constellation**: <the files/steps that always travel together>
- **Cleanest instance**: <path to the single best existing example>
- **Why tribal**: <the non-obvious, repo-specific step a competent agent wouldn't infer from one instance>

### Skipped
<one line: clusters you rejected as framework-shaped, and why>
```

If no candidate meets the bar, return `### Candidates (0)` and `_No tribal-knowledge recipes met the bar._`. Skill discovery is unconditional, so never use the "no applicable files" reply.

If the stack + pass id combination is unknown, reply: `Unknown pass id: <id>. Valid: .NET A1–A8, Angular A1–A7.`

If the codebase has no relevant files for this pass (all passes except skill discovery), reply: `Pass <id>: no applicable files found in this codebase.`

You do **not** modify any file. You do **not** generate `CLAUDE.md`, `TECH_DEBT.md`, or any other artifact — the parent `/bootstrap` synthesises all passes after they complete.
