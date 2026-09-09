# B-234 implementation review and native evidence (2026-09-09)

Frozen contract: `2026-09-09-consumer-quickstart.md`, external locked copy SHA256
`652E20099A58E8C432A82CAD4CC14D824CFCD5CB9BA662336BA6DD6F23E47FCC`.
Immutable implementation range: `f67eb0312be5838bb17066fa9fdd2847785a812f` to
`108ad0bc681aca2f7f22391f335982f08c28e912`. Sol (gpt-5.6-sol) implemented the seven authored
product files and composed six generated siblings. Root verified the full 13-path commit,
source/composed README byte identity and unchanged README prefix/hook aside/suffix.

## Independent review
Fresh read-only `claude-opus-5` session `720390d5-30e9-449e-b42a-da16c0d78ec3` returned ACCEPT,
no blockers, process exit 0 and is_error false. Model-reported cost USD0.766454. The reviewer did
not implement and stated its threat model after the frozen contract/range but before candidate
files and evidence. It read the authored diff, final README siblings, unchanged installer/guide,
and temporary smoke code and four logs; it independently reconstructed assertion totals.
It executed no tests. Its evidence is static review of attributed executions, not a second host.

The authored diff SHA256 was `F1FDEBBD884340A860911714F80E4A9D44792BD6724A480B139D4D472978B75A`.
Opus asked whether generated files were in the range because that filtered packet diff excluded
them. Root observed all six generated README/changelog paths in the immutable commit and verified
README byte identity; the smoke consumes dist. No product change is needed for this packet gap.

Keep non-blocking suggestions out of this locked delivery: trailing qualification colons preserve
verbatim stack text; the two host alternatives say run one; the relative upgrade link points to
the incoming README's sibling guide. These are not expanded into new behavior or adjacent cleanup.
The reviewer listed the template marker as untested; the instrument's exclusion set does examine
its absence in every disposable target. This establishes that narrow file fact only.

## Observed native red/green evidence
Temporary instrument: `$env:TEMP/ai-tech-lead-b234-quickstart-20260909/quickstart-smoke.ps1`,
SHA256 `E47CBB9DDDAA2CAEC4EC7DF5FC4FBFCA0BDF7307BFDE0F783602256A7352363F` (BOM present).
It is external one-off evidence, not a new shipped/meta gate. Invocation in each native host:
`-NoProfile -File <instrument> -FrameworkRoot <authoring-root> -HostLabel ps7`; native PS5.1
uses `-NoProfile -ExecutionPolicy Bypass -File <instrument> ... -HostLabel ps51`.

- Baselines: amendment_review directly ran PS7 7.6.5 and native PS5.1 5.1.26100.9444 at CP437;
  root inspected logs and script. Each returned exit 1: 75 checks, 39 failures, 0 cannot-examine,
  6 literal old inventories copied and 0 installer invocations. Whole directories were copied.
  Four required paths were missing, installer exclusions were violated, and brownfield archive/
  marker evidence was absent. The settings.windows.json and version stamp copies passed.
- Candidates: root directly ran both same hosts at CP437; each returned exit 0: 102 checks,
  0 failures, 0 cannot-examine, 6 actual installs and 0 manual inventories. Greenfield and brownfield
  across dotnet/angular/monorepo exercised documented commands from matching distribution roots,
  actual delivery, preserved displaced rules, exclusions and printed developer handoff.
- A prior attempt labelled PS5.1 actually self-reported PS7. That attempt is preserved but excluded
  from PS5.1 evidence; the final instrument rejects host-label/version disagreement. Root did not
  claim to execute the agent's baseline runs, despite the Opus summary's loose attribution.

The desired success is constructible and observed: actual installer routes deliver the required
files and preserve displaced policy with correct handoff. RED is not just a missing-command regex:
the same filesystem requirements inspect real materialized inventory and installed candidate.
Source/host examination failures are separately reported as cannot-examine, never as a pass.

## Limits and next gates
Not measured: consumer human/model comprehension, actual bootstrap/adopt, consumer report migration,
PS7-unavailable automatic adaptation, spaced/UNC/long paths, runtime update reinstallation, or business
results. The stamped-target guide diversion is inspected prose; the installer is unchanged. The
normal release must still pass compose/validation/footprint/full meta/selftest/budgets and eight
native Windows execution jobs plus case parity before tag; no waiver or completed release inferred.