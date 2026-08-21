# B-156 — content-check execution failures

## Locked design

- In `framework-doctor.sh`, capture each in-scope `grep -q` status: 0 keeps the present path, 1
  keeps the absent/product path, and any other value emits `CANT-VERIFY` for that diagnostic row.
  Reuse the import probe result for the delivery and protected-sync rows, and suppress heading
  content conclusions if any heading probe could not run.
- In `impact-run.sh`, separate the solution-file probe from the `find | grep -q` project probe and
  exit 2 with a host/resource message when grep returns anything other than 0 or 1.
- Give the PowerShell twins the same contract. They do not invoke grep, but their caught/suppressed
  in-process read/enumeration failures currently collapse into the same false content/routing
  verdicts.

## Adversarial critique and proportionality

Doing nothing preserves a false actionable doctor diagnosis and a silent impact-run routing change.
A shared shell helper would add abstraction for only a few differently-shaped branches; explicit
status capture is smaller and matches B-155. Expanding into extractor-shaped `|| true` sites would
require contract decisions that this item deliberately has not made. The cheap half named above
therefore removes the sharpest observed class exposure without broad parser work.

## Verification contract

- Host/resource forcing: a PATH-prepended `grep` stub exiting 2 must produce the new message and no
  content verdict on the Bash leg; equivalent PowerShell failure paths must not infer content.
- A genuinely absent pattern must retain its existing product finding.
- A healthy fixture/tree must retain its clean result.
- Parse and BOM-check both PowerShell scripts. Bash execution is reviewer-owned on this host.
