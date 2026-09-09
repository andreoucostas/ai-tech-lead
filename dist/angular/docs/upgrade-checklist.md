# Framework upgrade checklist

Use this checklist when updating an existing consumer repository. Run the installer from the
matching distribution directory (`dist/dotnet`, `dist/angular`, or `dist/monorepo`) in a fresh
framework checkout; that directory is the incoming framework root, and
`C:\path\to\consumer-repo` is the separate target.

1. **Establish the current and incoming versions.** In the target, read
   `.claude/framework-version.json`; it is authoritative if the protected `CLAUDE.md` header
   disagrees. Read the incoming distribution's `CHANGELOG.md` from the fresh framework checkout.

2. **Preserve local work.** Commit or otherwise preserve target changes, including customizations
   to files the framework owns and will replace. The real update enforces its normal Git-state
   preflight; do not bypass it.

3. **Preview from the incoming distribution root.** Use either native Windows host:

   ```powershell
   pwsh -NoProfile -File scripts/install.ps1 -Target 'C:\path\to\consumer-repo' -WhatIf
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Target 'C:\path\to\consumer-repo' -WhatIf
   ```

   `-WhatIf` lists file operations but is not a content diff, final-settings comparison, or proof
   that apply will pass: it skips the real update's dirty-tree guard. Review every `PLAN` category,
   especially `replace` and `delete`, and inspect `create`. A missing protected path receives a
   template; recover unexpectedly missing populated rules before apply instead of accepting a
   placeholder as project policy. A legal-file collision can refuse preview or apply; follow its
   diagnostic rather than changing ownership markers.

4. **Understand ownership and diagnostics.** `framework-ownership.json` classifies files.
   Framework-owned files are replaced; existing protected consumer content is left untouched.
   Mixed `.claude/settings.json` is saved at `.claude/.state/settings.json.pre-update`, refreshed,
   and adapted for the selected host. The separate `.claude/framework-update-backup/skills`
   directory is not a fresh snapshot of every update. After apply, selectively reapply intended
   settings from the actual diff; never restore the whole old file over new registrations, and
   review host-selected settings too.
   Retain the preview and apply output. Follow each `MIGRATION`, `CANT-VERIFY`, and `NOTICE`
   instruction. Resolve a nonzero refusal before retrying. An advisory preservation notice can be
   valid: retain intentional dependencies and record unresolved uncertainty instead of deleting
   files or forcing every notice away.
5. **Apply from the same incoming distribution root.** Use the matching command without `-WhatIf`:

   ```powershell
   pwsh -NoProfile -File scripts/install.ps1 -Target 'C:\path\to\consumer-repo'
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Target 'C:\path\to\consumer-repo'
   ```
6. **Reconcile older protected rules conditionally.** Updating does not rewrite a populated
   `CLAUDE.md`. If it lacks the carrier import, compare only these four old framework headings:
   `Verification Rules`, `Leanness`, `SOLID`, and `Agentic Workflow`. Preserve deliberate
   project-specific additions, add this canonical line, then remove only superseded framework
   copies:

   ```markdown
   @.github/instructions/framework-rules.instructions.md
   ```

   Do not edit that framework-owned carrier. Keep `Conventions` and `Boy Scout Rule`; neither is
   one of the four migrated headings. Do not remove customized sections indiscriminately.
7. **Reconcile the old touched-file mandate as one unit.** The following BEFORE text is an example,
   not an exact-match detector; inspect local wording and retain intentional team mandates and
   applicable numbered items:

   ```markdown
   When touching any file, leave it cleaner than you found it.
   ### Always apply (low-effort, low-risk — do these on every touched file):
   **When to skip**: ... add a comment `// TODO: Boy Scout skipped — [reason]` ...
   ```

   Changing only the introduction leaves contradictory instructions. For a team adopting the
   shipped outcome/compatibility/verification boundary, use:

   ```markdown
   **Bug-fix scope.** See the framework-owned workflow scope.
   ### Always apply (low-effort, low-risk — subject to Bug-fix scope above):
   ```

   Remove the obsolete skipped-cleanup TODO requirement. This keeps bug-fix cleanup within the
   requested outcome, caller or extension compatibility, and meaningful verification. It does not require
   copying all fresh-template conventions or erase stricter policy the team intentionally keeps.

8. **Align authored and generated instructions.** After reconciliation, copy the installed JSON
   version and applied date into the protected `CLAUDE.md` header. Then, in an agent session rooted
   at the target, run `/generate-copilot` to regenerate `AGENTS.md` and
   `.github/copilot-instructions.md`. Do not hand-fix derivatives or replace a populated
   `CLAUDE.md` with the template. Update does not run bootstrap; if adoption or bootstrap remains
   pending, follow that workflow rather than deleting its marker.

9. **Verify from the target root, review, and commit.** Use either host for each check:

   ```powershell
   pwsh -NoProfile -File scripts/framework-doctor.ps1
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/framework-doctor.ps1
   pwsh -NoProfile -File scripts/docs-sync-check.ps1
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/docs-sync-check.ps1
   ```

   Resolve findings or inability to examine before reporting the upgrade verified. Review the full
   target diff and commit it. These are framework checks, not application verification or proof an
   agent host consumed the rules; use [enforcement-surface guidance](./enforcement-surfaces.md) for
   the latter boundary.
