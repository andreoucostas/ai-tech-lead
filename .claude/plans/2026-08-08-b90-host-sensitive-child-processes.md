# B-90/B-93 — host-sensitive child-process evidence

## Decision to lock

B-90 remains live. A test launched by Windows PowerShell 5.1 can call `Get-PsExe`, spawn its
subject under `pwsh` 7, and then report evidence as though the subject ran under 5.1. That exact
false-green class already concealed two 5.1-only release defects. B-93 is one concrete instance of
B-90 and will be absorbed rather than delivered separately.

The first audit incorrectly classified most remaining call sites as intentionally modelling a
preferred production host. Independent critique rejected that claim: the shipped
`settings.windows.json` explicitly invokes hooks with Windows PowerShell, and the installers and
doctor support 5.1 too. Re-auditing every current use found no subject-spawning call site that needs
to upgrade a 5.1 parent to `pwsh`:

- the meta harness and its installer, update-delivery, framework-doctor, twin-parity, root-installer,
  release-staging, and other consumers all exercise scripts that support both hosts;
- the shipped harness likewise exercises hooks and scripts registered for either host; and
- `BuildArchitectureHtml.Tests.ps1` verifies output encoding whose historical behavior differed
  specifically under 5.1.

The suite runners themselves may continue preferring `pwsh`; changing that orchestration contract
would broaden this item into a runner redesign. A suite invoked directly under 5.1 must keep its
PowerShell subjects under 5.1. The existing `Get-PsExe` name can safely implement that contract for
all current consumers; no second preferred-host helper is needed.

## Proportionality

The observed harm is serious: this false-green mechanism already hid release-affecting 5.1 defects.
The materially smaller remedy removes the entire current exposure by correcting `Get-PsExe` in the
two harness definitions, rather than editing every consumer. No new resolver, second helper, static
gate, runner rewrite, or blanket call-site replacement is justified.

## Implementation

1. In both harness definitions, make `Get-PsExe` cache and return
   `(Get-Process -Id $PID).Path`. Document that subject children deliberately inherit the suite host
   so a direct 5.1 run cannot upgrade itself to 7.
2. Do not add per-call-site substitutions: every current consumer has been classified as a
   dual-host subject, and central self-hosting is the smaller complete fix.
3. Recompose all three distributions; never edit `dist/` directly.
4. Close B-90 and B-93 together in `meta/BACKLOG.md`, with the required RCA and an honest record of
   red/green observations. Because the core harness is a shipped test artifact and changes all
   three distributions, prepare root and consumer-facing changelog entries for a patch release;
   version stamping remains the release script's job when Claude reviews/releases the branch.

## Red and reachable-green evidence

Before implementation, traverse the real helper: dot-source each unchanged harness under the
absolute Windows PowerShell 5.1 executable and compare `(Get-Process -Id $PID).Path` with
`Get-PsExe`. The filed defect is red when the actual helper reports `pwsh` for a 5.1 parent. The
success world is the same 5.1 parent receiving its identical `powershell.exe` path; a `pwsh` parent
must likewise receive its identical `pwsh` path.

After the change, repeat that real-helper identity test for both harnesses under both hosts, using a
fresh child process for every probe so the helper cache cannot contaminate the result. Run the
release-staging and architecture suites directly under absolute 5.1 and `pwsh`; the restored staging
suite must pass 6/6 under both. No synthetic `@(...).Count` mutation is claimed: second-pass critique
verified that removing those wrappers does not recreate the historical singleton shape and can stay
green. For architecture output, the existing static guard already rejects the historical
`Set-Content` implementation; prove the corrected helper path is used and retain byte parity on
restored source.

Then run parser/BOM checks, compose and freshness for all distributions, relevant focused/meta and
dist suites, and `validate-dist` for all three distributions. A green result is not claimed for any
broader suite that contains an unrelated failure.

## Risks and boundaries

- `(Get-Process -Id $PID).Path` must resolve under both supported hosts; fail the test rather than
  silently selecting a different host.
- Generated copies must come only from the composer.
- Do not infer that launching the aggregate runner under 5.1 makes every nested suite a 5.1 run.
- Do not add a preferred-host escape hatch unless a concrete production contract requires one.
- B-71's PATH-only discovery of whether 5.1 exists is adjacent but separate work.
