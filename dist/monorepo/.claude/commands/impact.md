---
description: "Descriptive adoption inventory and repository scorecard. The former A/B experiment is retired because its baseline is invalid. Developer-initiated only."
disable-model-invocation: true
---

Produce a descriptive adoption record. Do not present it as a before/after experiment or evidence
that adoption caused a repository outcome.

## Why the former experiment is retired

The earlier workflow captured its supposed pre-adoption reference after the framework had already
been installed. That reference is not an old-framework arm, so no comparative or causal claim can
be made from it. Do not invoke the retired runner or create a replacement baseline inside `/adopt`.

## Steps

### 1. Inventory and capability comparison

Read the archived configuration under `docs/pre-adoption/`, when present, and compare its stated
capabilities with the installed framework. Describe only what the files show: missing or added
guidance, commands, hooks, and documentation. This is an inventory comparison, not a measurement
of behavioural value.

### 2. Current repository scorecard

Run the installed `scripts/metrics.ps1` against the current repository and
record the returned values as a **current repository scorecard**. Do not calculate or imply a delta
from the retired reference, and do not attribute any value to adoption.

### 3. Write the record

Write `docs/impact/IMPACT.md` with the capability inventory and the current scorecard. Include this
plain-language qualification:

> The former pre/post experiment is invalid because its supposed pre-adoption reference was captured
> after installation. This report is descriptive only: it is not an A/B comparison and does not show
> that adoption caused a change.

If HTML is useful, render the markdown with `scripts/build-architecture-html.ps1`.
