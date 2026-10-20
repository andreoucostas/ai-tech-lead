---
name: reports-feature-flags-path
description: ReportsController reads config/feature-flags.json from the content root, which the Api project does not copy
type: gotcha
scope: src/Orders.Api/**
status: unverified
last-verified: never
---
`ReportsController` reads `<ContentRootPath>/config/feature-flags.json` in its constructor, but `Orders.Api.csproj` has no item that copies the repo-root `config/feature-flags.json` into the Api project or its output. Only `Orders.Tests.csproj` links it. Unless deployment places the file there, constructing the controller would throw `FileNotFoundException`.
**Confidence:** inferred
**Provenance:** requested /bootstrap discovery, 2026-10-20
**Evidence:** `src/Orders.Api/Controllers/ReportsController.cs:17-18`; `src/Orders.Api/Orders.Api.csproj` (no content/None item); `tests/Orders.Tests/Orders.Tests.csproj:17`
**Counterevidence / exceptions:** a deploy script or container image outside this repo may place the file; none is evidenced here.
**Dependencies / unresolved:** deployment packaging is not in the repo; the Api was not run.
**Verify by:** run `Orders.Api` from `src/Orders.Api` and `GET /api/reports`, or inspect the publish output for `config/feature-flags.json`.
**Semantic refresh:** trigger: change to `Orders.Api.csproj`, `ReportsController`, or deployment packaging; result: decisive source lines reread at creation, runtime behaviour not checked.
**Draft status:** draft pending PR review; not team-approved policy
