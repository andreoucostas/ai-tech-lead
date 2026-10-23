# Upgrading and removing the framework

For whoever looks after AI Tech Lead in this repository. It covers updating to a newer release, the
one-off migrations an older install may need, and removing the framework. Which files the framework
owns, and which are yours, is in [reference.md](reference.md#files-and-ownership).

## Update to the newest release

1. **See what you have and what is new.** Your installed version is in
   `.claude/framework-version.json`; it is authoritative if the protected `AGENTS.md` header
   disagrees. Read your distribution's `CHANGELOG.md` in the new release (step 3) for anything marked
   as something you must do.

2. **Leave a clean working tree.** Commit, stash or copy your changes first, including any edits to
   files the framework owns, which the update replaces. The update refuses a dirty tree; do not
   bypass that. Keep `.claude/ai-audit.log` local rather than committing it (see
   [Migrations](#migrations-from-older-installs) if Git tracks it).

3. **Get the newest release, outside your repository.** Install from a release tag, never from
   `master`, which carries unreleased work stamped with the previous version:

   ```powershell
   git clone https://github.com/andreoucostas/ai-tech-lead.git C:\src\ai-tech-lead
   git -C C:\src\ai-tech-lead checkout "$(git -C C:\src\ai-tech-lead describe --tags --abbrev=0)"
   ```

   With an existing clone, fetch its tags and check out the newest instead. The installer checks the
   clone against its remote and stops if a newer release exists.

4. **Preview.** The installer finds your distribution from `.claude/framework-version.json`:

   ```powershell
   pwsh -NoProfile -File C:\src\ai-tech-lead\install.ps1 -WhatIf C:\path\to\your-repo
   ```

   Without PowerShell 7, use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File` instead of
   `pwsh -NoProfile -File`. Review every `PLAN` line, especially `replace` and `delete`, and inspect
   `create`. A preview lists file operations only: it is not a content diff, does not compare final
   settings, skips the dirty-tree check, and does not prove the real update will pass. A protected path
   that is missing receives a template; if one of your populated files is unexpectedly missing,
   recover it before applying rather than accept a placeholder as project policy.

5. **Apply.** Run the same command without `-WhatIf`. Keep the preview and apply output, and act on
   every line it prints (see [What the installer's messages ask of you](#what-the-installers-messages-ask-of-you)).

6. **Reconcile your settings.** `.claude/settings.json` is shared: the update saves your copy to
   `.claude/.state/settings.json.pre-update`, then refreshes it and adapts it to the PowerShell host it
   found. Re-apply your own settings selectively from the diff; never restore the whole old file over
   the new hook registrations. `.claude/framework-update-backup/` holds an update's other backups for
   review; it is not a fresh snapshot of every update.

7. **Copy the version into `AGENTS.md`.** Copy `version` and `applied` from
   `.claude/framework-version.json` into the header comment at the top of `AGENTS.md`. Do not replace
   a populated `AGENTS.md` with the template.

8. **Verify, review, commit.** From your repository root:

   ```powershell
   pwsh -NoProfile -File scripts/framework-doctor.ps1
   pwsh -NoProfile -File scripts/docs-sync-check.ps1
   ```

   Resolve every finding, or anything it could not examine, before calling the update verified. These
   check the framework's state, not your application, and not that a client actually reads the rules
   ([enforcement-surfaces.md](enforcement-surfaces.md) covers that). Review the full diff and commit it.

An update never runs `/bootstrap`. If adoption or bootstrap is still pending, finish that workflow
rather than deleting its marker.

## What the installer's messages ask of you

- **`MIGRATION`**: a file of yours still uses an old layout or names a retired framework path. Follow
  the instruction on that line; the installer did not change your file.
- **`CANT-VERIFY`**: the installer could not examine something it needed to. Resolve it and re-run.
- **`NOTICE`**: advice. Some notices are valid to keep, such as a dependency you intend to keep:
  record the uncertainty rather than deleting files to silence it.
- **A non-zero exit** is a refusal: resolve its cause before retrying. A collision with a legal file
  can refuse a preview or an update; follow its message rather than changing ownership markers.
- **`LAYOUT:`** reports how the instruction files were arranged; see the migrations below.

## Migrations from older installs

Most updates need none of these. Do each only when its condition holds.

- **`.claude/ai-audit.log` is tracked by Git.** From the repository root, run
  `git ls-files -- .claude/ai-audit.log`. A non-zero exit means tracking could not be examined;
  resolve that first. If it prints the path, add `ai-audit.log` to `.claude/.gitignore`, then run
  `git rm --cached -- .claude/ai-audit.log`, which keeps your local file. If Git refuses, inspect the
  staged and working copies rather than forcing the removal. Commit the ignore change and the removal
  together with intended work. This stops future telemetry commits; it does not remove history. An old
  log header may still say to keep the file in version control: this guidance supersedes it.

- **`SECURITY_FINDINGS.md` has a `File:line` or `Description` column.** A register created before
  0.52.1 has the old layout, and `/security-gate` will not write to it: its verdict ends
  `Recorded: none (legacy schema)` and the finding stays in the chat. Old rows may hold more than the
  register now allows, so a person with authority over security incidents first reads every row in
  all three tables, removes or redacts any that records a credential or names a secret's location or
  any part of it, and handles that incident outside Git (rewriting the file does not remove it from
  history). Then replace the findings table's two header lines with:

  ```markdown
  | ID | Severity | Category | Affected area (redacted when sensitive) | Repository-safe summary | Discovered | Due | Status | Owner role/team (optional) | Internal reference (optional) | Resolved |
  |----|----------|----------|-----------------------------------------|-------------------------|------------|-----|--------|----------------------------|-------------------------------|----------|
  ```

  In each row, `File:line` becomes the path without its line number, `Description` one sentence
  naming the defect and the fix, and `Assigned` an owning role or team; add an empty
  `Internal reference (optional)` cell before `Resolved`, and keep each row's ID, dates and status.
  Give `Accepted risks` and `Resolved findings` the headers in the new release's
  `SECURITY_FINDINGS.md` and map their rows the same way; a resolved row's area is the path its fix
  touched, and its `Fix PR` moves to `Internal reference (optional)` or is dropped. Commit the
  register, then re-run `/security-gate` on the change whose finding was not recorded.

- **`CLAUDE.md` lacks the framework-rules import, or `AGENTS.md` still holds old copies of the
  framework rules.** Compare only the four old framework headings: `Verification Rules`, `Leanness`,
  `SOLID` and `Agentic Workflow`. Keep deliberate project-specific additions, make sure `CLAUDE.md`
  has this line, then remove only the superseded framework copies:

  ```markdown
  @.github/instructions/framework-rules.instructions.md
  ```

  Do not edit that framework-owned file. Keep `Conventions` and `Boy Scout Rule`; neither is one of the
  four headings. Do not remove customised sections wholesale.

- **The old Boy Scout mandate.** This BEFORE text is an example, not an exact match; inspect your own
  wording and keep the team mandates and numbered items you intend:

  ```markdown
  When touching any file, leave it cleaner than you found it.
  ### Always apply (low-effort, low-risk — do these on every touched file):
  **When to skip**: ... add a comment `// TODO: Boy Scout skipped — [reason]` ...
  ```

  Change it as one unit; changing only the introduction leaves contradictory instructions. To adopt the
  shipped boundary on outcome, compatibility and verification, use:

  ```markdown
  **Bug-fix scope.** See the framework-owned workflow scope.
  ### Always apply (low-effort, low-risk — subject to Bug-fix scope above):
  ```

  Remove the old skipped-cleanup TODO requirement. This keeps bug-fix cleanup within the requested
  outcome, caller or extension compatibility, and meaningful verification; it neither requires copying
  every fresh-template convention nor erases a stricter policy your team keeps on purpose.

  An older Boy Scout interface item may still end "are required by SOLID/DIP even with one
  implementation; never inline those". The framework rules no longer require an interface or
  abstraction for every service. Unless your team keeps that rule on purpose, keep the item's number
  and replace its text with:

  ```markdown
  Inline single-consumer interfaces or abstract bases that are not a project-evidenced DI service seam — per Leanness. Preserve an existing project boundary when its evidence or correctness need requires it.
  ```

- **Instructions still in `CLAUDE.md`.** When `AGENTS.md` is still the generated copy, the first
  update to this layout moves `CLAUDE.md`'s text into `AGENTS.md` and writes the `CLAUDE.md` stub,
  keeping both originals under `.claude/framework-update-backup/instruction-files/`; review the moved
  `AGENTS.md`'s opening note. If the `LAYOUT:` line reported a hand-written `AGENTS.md`, merge
  `CLAUDE.md`'s content into it and replace `CLAUDE.md` with the template stub. Give the merged
  `AGENTS.md` the template's **Framework rules** line as the second line of its opening note, so agents
  that read only `AGENTS.md` find the framework rules:

  ```markdown
  > **Framework rules** (Verification Rules, Leanness, SOLID, Agentic Workflow) are in [.github/instructions/framework-rules.instructions.md](./.github/instructions/framework-rules.instructions.md). If your agent has not already loaded that file, read it before planning or editing.
  ```

- **`.github/copilot-instructions.md` exists.** The framework no longer generates or checks it; it is
  yours to delete or maintain.

## Remove the framework

The installer wrote only inside your repository and changed no Git configuration.

- **If nothing has been committed on top of the install** (no `/bootstrap`, `/adopt` or update yet),
  revert the install commit and delete the ignored `.claude/.state/` folder.
- **Otherwise,** delete every path that `framework-ownership.json` marks
  `framework-owned/overwritten`; the list includes both manifests and `.claude/framework-version.json`.
  Paths marked `consumer-owned/protected` are yours to keep or delete; they may still hold template
  text. `.claude/settings.json` is shared: delete it, or restore your copy from
  `.claude/.state/settings.json.pre-update` if that local backup exists. A brownfield install moved
  your earlier files to `docs/pre-adoption/`; move back what you want.
  `.claude/framework-update-backup/` holds an update's backups for review and is not needed after.
