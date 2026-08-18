# B-68 implementation report — derived Instructed files

## Outcome and design choice

Changed both `scripts/context-footprint.ps1` and `.sh` to derive `Instructed` as `FRAMEWORK-CONTEXT.md` plus every `docs/**/*.md`, sorted ordinally. Derivation wins over a deliberate allowlist because it has no separate list that can silently omit a new Markdown document. The PowerShell twin uses `Get-ChildItem -Filter '*.md' -File -Recurse -Force`; it does not use the Windows PowerShell 5.1-broken `-Include` form. The shell twin is POSIX-compatible and uses no conditional `grep` idiom.

Updated `meta/context-footprint.json` to the newly measured set.

## Scratch red-test

A scratch repo copy was baselined with the old implementation, then `dist/dotnet/docs/b68-new.md` containing `new instructed doc` was added.

```text
UPDATED: meta/context-footprint.json
OK: context footprint matches meta/context-footprint.json.
OLD_WITH_NEW_DOC_EXIT=0
FAIL: context footprint differs from meta/context-footprint.json. Review the change, then run -Update.
NEW_WITH_NEW_DOC_EXIT=1
```

Thus the old implementation silently ignored the new doc, while the new implementation made the omission loud. The scratch copy, not the working tree, was mutated.

## Footprint before and after

Command: parse the committed and regenerated `meta/context-footprint.json` files with `ConvertFrom-Json`, sum each dist's `instructed[].chars`, and print the existing derived metrics.

```text
BEFORE
dotnet instructed.chars=15450 instructed.tok=3862 static.claude.chars=39501 static.copilot.chars=43561 prompt.max.chars=2253
angular instructed.chars=15567 instructed.tok=3892 static.claude.chars=38239 static.copilot.chars=44352 prompt.max.chars=2323
monorepo instructed.chars=24668 instructed.tok=6167 static.claude.chars=47917 static.copilot.chars=52437 prompt.max.chars=2668
AFTER
dotnet instructed.chars=70093 instructed.tok=17523 static.claude.chars=39501 static.copilot.chars=43561 prompt.max.chars=2253
angular instructed.chars=70810 instructed.tok=17702 static.claude.chars=38239 static.copilot.chars=44352 prompt.max.chars=2323
monorepo instructed.chars=83217 instructed.tok=20804 static.claude.chars=47917 static.copilot.chars=52437 prompt.max.chars=2668
```

The Instructed totals moved because previously unmeasured docs are now counted; static Claude, static Copilot, and prompt maximums did not move.

## Host/twin evidence

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/context-footprint.ps1 -Check
```

Observed: `OK: context footprint matches meta/context-footprint.json.` and `PS51_CONTEXT_EXIT=0`.

```powershell
bash -n scripts/context-footprint.sh
```

Observed: `BASH_SYNTAX_EXIT=0`. A first full check exceeded a 120-second observation window; rerunning with a 240-second window completed in 130.7 seconds with `OK: context footprint matches meta/context-footprint.json.` and `BASH_CHECK_EXIT=0`.

## Assertions not shown failing

The decisive new-doc assertion was shown failing. No requested assertion remains unobserved; the timed-out bash attempt was followed by a completed green run.

## RCA

No completeness relationship connected the literal three-file list to the growing `docs/` tree, so the baseline faithfully preserved an incomplete measurement. Any hand-maintained inventory used as a budget input is exposed to the same fail-open omission class.
