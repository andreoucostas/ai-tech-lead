# B-90/B-93 — host-sensitive child-process evidence

## Decision to lock

B-90 remains live. A test launched by Windows PowerShell 5.1 can call `Get-PsExe`, spawn its
subject under `pwsh` 7, and then report evidence as though the subject ran under 5.1. That exact
false-green class already concealed two 5.1-only release defects. B-93 is one concrete instance of
B-90 and will be absorbed rather than delivered separately.

The repository-wide call-site audit found two current subjects whose result is genuinely
host-sensitive:

- `.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1` extracts 5.1-hardened release logic but runs
  the extracted child through `Get-PsExe`.
- `src/core/tests/hooks/BuildArchitectureHtml.Tests.ps1` verifies output encoding whose historical
  behavior differed specifically under 5.1, but also runs its PowerShell child through
  `Get-PsExe`.

Other current `Get-PsExe` call sites intentionally model the preferred available production host,
not the current test host. The suite runners themselves also prefer `pwsh`; changing that contract
would broaden this item into a runner redesign and is out of scope. Host-sensitive suites must be
invoked directly under each host.

## Proportionality

The observed harm is serious: this false-green mechanism already hid release-affecting 5.1 defects.
The materially smaller remedy removes the current exposure with two child-host substitutions plus a
warning at the two harness definitions. No new resolver, shared abstraction, static gate, runner
rewrite, or blanket call-site replacement is justified.

## Implementation

1. In the two host-sensitive suites, resolve the current executable with
   `(Get-Process -Id $PID).Path` once and use that path for the subject child. State why self-hosting
   is load-bearing.
2. At both `Get-PsExe` definitions, document that it selects the preferred available host and is not
   necessarily the host running the suite. Retain intentional call sites.
3. Recompose all three distributions; never edit `dist/` directly.
4. Close B-90 and B-93 together in `meta/BACKLOG.md`, with the required RCA and an honest record of
   red/green observations. Record shipped-test-artifact release treatment in the root changelog.

## Red and reachable-green evidence

Before implementation, run a detached/temporary copy of `ReleaseStagingGuard.Tests.ps1` under the
absolute Windows PowerShell 5.1 executable with an instrumented child that prints its executable.
The filed defect is red when the 5.1 parent reports a `pwsh` child. The success world is the same
5.1 parent reporting the identical `powershell.exe` path for the extracted subject; a `pwsh` parent
must likewise report `pwsh`.

After the change, run both focused suites directly under absolute 5.1 and `pwsh`. For
`ReleaseStagingGuard`, additionally mutate one load-bearing `@(...).Count` wrapper in an isolated
copy: the self-hosted 5.1 suite must fail, while the restored source passes 6/6 under both hosts.
For architecture output, the existing static guard already rejects the historical `Set-Content`
implementation; prove child identity under both hosts and retain byte parity on restored source.

Then run parser/BOM checks, compose and freshness for all distributions, relevant focused/meta and
dist suites, and `validate-dist` for all three distributions. A green result is not claimed for any
broader suite that contains an unrelated failure.

## Risks and boundaries

- `(Get-Process -Id $PID).Path` must resolve under both supported hosts; fail the test rather than
  silently selecting a different host.
- Generated copies must come only from the composer.
- Do not infer that launching the aggregate runner under 5.1 makes every nested suite a 5.1 run.
- Do not mechanically replace intentional preferred-host calls.
- B-71's PATH-only discovery of whether 5.1 exists is adjacent but separate work.
