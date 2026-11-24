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

   The installer needs PowerShell 7; under Windows PowerShell 5.1 it stops with one line and changes
   nothing. Review every `PLAN` line, especially `replace` and `delete`, and inspect
   `create`. A preview lists file operations only: it is not a content diff, does not compare final
   settings, and does not prove the real update will pass. It runs the same Git checks as the real
   update, but only reports a refusal: on a tree the update would refuse (uncommitted changes, say)
   it prints `dry run: the real run would refuse: ...` and exits 4 instead of 0, and a `-Stack` that
   differs from the stamp's stack is refused the same way (`-AllowStackChange` moves to the other stack
   on purpose; the files only the old stack shipped stay in place, unowned). A protected path
   that is missing receives a template; if one of your populated files is unexpectedly missing,
   recover it before applying rather than accept a placeholder as project policy.

5. **Apply.** Run the same command without `-WhatIf`. Keep the preview and apply output, and act on
   every line it prints (see [What the installer's messages ask of you](#what-the-installers-messages-ask-of-you)).

   **When the update refuses and names `-Reinstall`:** your install is older than any release the
   installer can clean up after, so a plain update would leave the old hooks, commands and settings
   beside the new ones. Commit everything, then re-run with `-Reinstall` (preview it with `-WhatIf`
   first). It deletes every file Git tracks under `.claude/` (except `.claude/ai-audit.log`),
   `.github/instructions/`, `.github/chatmodes/`, `.github/skills/`, `.agents/skills/` and
   `tests/hooks/`, plus every file this release or its retirement list names, then installs the
   release fresh. Your `AGENTS.md` and `CLAUDE.md`, which an old release wrote in its own format,
   move to `docs/pre-adoption/` and this release's take their place: the installer then names
   `/adopt` as the next step, which merges your project text into the new `AGENTS.md` for you to
   review. It refuses while an earlier adoption's `docs/pre-adoption/AGENTS.md` or `CLAUDE.md` is
   still there (move it out and commit that first), and leaves both files in place, saying so on a
   `LAYOUT:` line, while an adoption is still pending. The other protected files, files Git does not
   track, and your own files outside those folders stay; it refuses a file whose bytes your last
   commit does not hold. It writes no backup: your
   last commit holds what it deleted, and it prints that commit's id with the commands to bring
   files back. Team skills, commands and hooks kept under
   `.claude/` are deleted with the rest; restore the ones you want from that commit. It refuses a
   tree with uncommitted changes and cannot be combined with `-AllowDirtyTree`.

6. **Reconcile your settings.** `.claude/settings.json` is shared: the update saves the file as it
   was to `.claude/.state/settings.json.pre-update` (Git ignores it, so it exists on one machine
   only), refreshes the file, and carries every top-level
   key of it that the release does not define (`permissions`, `model`, `statusLine` and the like)
   into it, unchanged and after the release's own keys. Inside `env` and `hooks` it carries what is
   yours the same way: each `env` variable the release does not set, and each hook entry whose
   command no release of the framework registered, kept under its event and matcher (in the
   release's group of that matcher when it has one, else in your own group). A `NOTICE` names what
   it carried: keys, variables by name, hook entries by event and matcher. For a value both define
   (`defaultShell`, an `env` variable the release sets) the release's wins, and a `NOTICE` names
   each one of yours it replaced, an `env` variable by name and never by value. A hook entry that
   runs a command the framework shipped is the framework's, and the release's entries replace it with
   your edits in it. The update compares those entries in your file, as a whole, with the ones the
   release your `.claude/framework-version.json` names shipped, and a `NOTICE` names each event and
   matcher where they differ (a raised timeout, a narrowed matcher, a copy, a removed group); when the
   stamp names no release it knows, one `NOTICE` says they differ. Make a change of your own as an
   entry with a command of your own. A key
   or `env` variable an earlier release set and this one no longer does is dropped, not carried, and
   named. If the installer could not
   read your copy as strict JSON (a comment, a trailing comma, an empty file, two keys that differ
   only in case) it carries nothing and says so on a `NOTICE`: re-add your keys from the backup by
   hand. A key you later delete from the file stays deleted, because the next update reads the file
   as it then is. Commit the result: your teammates get the carried keys from your commit, not from
   the backup.

   **Where your other old files are.** Except for the settings, an update saves no copy of a file
   your last commit holds as it is on disk. Each `NOTICE` about such a file it replaced (a file of
   yours at a path the framework now owns, a skill, the moved `CLAUDE.md`) names that commit and the line that gives
   the file back: `git -C <repo> show <commit>:./<path>` prints it, or, where Git writes the file
   with other line endings than it stores (`core.autocrlf`), `git -C <repo> checkout <commit> -- <path>`
   puts it back as it was. A `recover from Git:` line
   says how to list what changed (`git diff --stat <commit>`) and restore a file
   (`git checkout <commit> -- <path>`). Only a file that commit does not hold is copied: one you
   gitignored, one Git is told not to see the changes of (skip-worktree or assume-unchanged), one
   with uncommitted edits (`-AllowDirtyTree`), or any file in a folder without Git. Those copies go
   to `.claude/framework-update-backup/`, which Git ignores. Copies an older release left there
   stay until you delete them; keep what you need first.

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
- **A non-zero exit:** 2 means the target is not a directory or is the framework's own repository; 4 means a
  check stopped it, usually before any change; 3 is a refusal or a copy that stopped part-way. Read the
  message: if it says files were written or "every other step is done", the tree changed, so follow its
  re-run line. Otherwise resolve the cause before retrying. A collision with a legal file can refuse a
  preview or an update; follow its message rather than changing ownership markers.
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
  and the `LAYOUT:` line names the commit that holds both originals (an original that commit does
  not hold as it is on disk is kept under `.claude/framework-update-backup/instruction-files/`); review the moved
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

1. **Nothing changed since the install (or update) commit?** Revert that commit and stop. It leaves
   `.claude/ai-audit.log`, and `.claude/.state/` if present, for you to delete by hand.
2. **Otherwise,** delete every path that `framework-ownership.json` (at the repository root) marks
   `framework-owned/overwritten`; the list includes both manifests, `.claude/framework-version.json`,
   `.claude/.gitignore` and `.github/hooks/hooks.json`. Paths marked `consumer-owned/protected` are yours
   to keep or delete; they may still hold template text. A brownfield install moved your earlier files
   to `docs/pre-adoption/`; move back what you want. `.claude/framework-update-backup/` holds an
   update's backups and is not needed after.
3. In `.claude/settings.json` (shared with you), remove every entry under `hooks` whose command names
   `.claude/hooks/`, and the framework's `_comment`, `env` and `defaultShell` unless you use them; keep keys of
   your own, and delete the file if nothing of yours is left. If you added your own hooks to
   `.github/hooks/hooks.json`, restore the file from Git and remove only the entries naming `.claude\hooks\`.
   Do steps 2 and 3 yourself: the write guard refuses an agent's file-tool change to the hook files and to
   its own entry in `.claude/settings.json`.
4. In `CLAUDE.md`, remove the framework's import lines, `@.github/instructions/framework-rules.instructions.md`
   (and `@AGENTS.md` only if you delete `AGENTS.md` as well).
5. Delete `.claude/.state/` and `.claude/ai-audit.log`, then any directory left empty.
6. Check: `git grep -n ".claude/hooks/"` (PowerShell: `git grep -n '.claude/hooks/'`) prints nothing.

`.claude/.state/settings.json.pre-update` still holds the framework's hook registrations, so restoring it
brings them back; copy only your own entries from it.
