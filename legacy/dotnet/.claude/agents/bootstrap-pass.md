---
name: bootstrap-pass
description: Runs a single bootstrap analysis pass (A1–A8) against a .NET codebase and returns structured findings. Invoked in parallel by `/bootstrap` Phase 1 — never invoke directly. Read-only.
tools: Read, Grep, Glob, Bash
model: inherit
---

You execute exactly one of the bootstrap analysis passes defined in `.claude/commands/bootstrap.md`. The caller specifies the pass id (`A1`, `A2`, `A3`, `A4`, `A5`, `A6`, `A7`, or `A8`). You return a single structured findings message.

## Process

1. Read `.claude/commands/bootstrap.md`. Locate the `### <pass-id>:` heading the caller specified.
2. Read the bullet checklist under that heading. Treat each bullet as an analysis question to answer against this codebase.
3. Use `Glob` to enumerate relevant source files for the pass (`*.cs` for code passes; `*.csproj`, `*.sln`, `Directory.Build.props`, `appsettings*.json` for solution/quality passes). Bound to ~50 files; if larger, sample the most-recently-changed via `git log`. **Exception — A8 (skill discovery)** does not follow this step; it scans the whole tree by name/path and must not recency-sample. See its section below.
4. Read sampled files and compile findings.
5. Return the structured output below — no preamble, no commentary outside the structure.

## A7 is conditional

`A7` (Financial Domain Invariants) only applies when the codebase shows financial-domain signals. Follow the gate in `bootstrap.md`'s `### A7:` heading: if no signals are found, return exactly `A7: No financial domain signals detected — skipping.` and nothing else. This is a pass, not an error.

## A8 is the skill-discovery pass (unconditional)

`A8` (Project-Specific Skill Discovery) runs in every repo — there is no gate. Follow the `### A8:` definition in `bootstrap.md`. It works differently from A1–A7:

- **Scan the whole tree, not a sample.** Use `Glob`/`Grep` on **filenames and directory paths** to find naming/structural clusters (e.g. every `*Tenant*`, every folder under `Integrations/`). Cluster detection is cheap — it does not require reading file contents. **Do not** apply the ~50-file bound or the `git log` recency sampling from Process step 3; a stable, rarely-changed recipe is exactly the tribal knowledge worth capturing.
- **Read in full only the single cleanest instance** of each candidate constellation, to confirm its non-obvious steps.
- **Read `LEARNINGS.md` first** and skip any candidate whose name or constellation matches a `## Declined recipe:` entry — the team removed it deliberately.
- Emit the **Candidates** output shape below (not the Findings shape). If nothing qualifies, return `### Candidates (0)` with the empty note.

## Output format

```
## Pass <pass-id>: <pass title from bootstrap.md>

### Findings
- <one bullet per finding — current pattern → target pattern → brief rationale>

### Sampled files (<count>)
- path/to/Foo.cs
- ...

### Skipped
<one line: areas you did not analyse and why>
```

**A8 (skill discovery) uses the Candidates shape instead of Findings:**

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

If no candidate meets the bar, return `### Candidates (0)` and `_No tribal-knowledge recipes met the bar._`. A8 is unconditional, so never use the "no applicable files" reply.

If the pass id is unknown, reply: `Unknown pass id: <id>. Valid: A1, A2, A3, A4, A5, A6, A7, A8.`

If the codebase has no relevant files for this pass (A1–A7 only), reply: `Pass <id>: no applicable files found in this codebase.`

You do **not** modify any file. You do **not** generate `CLAUDE.md`, `TECH_DEBT.md`, or any other artifact — the parent `/bootstrap` synthesises all passes after they complete.
