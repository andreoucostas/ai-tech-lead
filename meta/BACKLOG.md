# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-18 (WSD-090, WSD-091); WP rows added 2026-09-19 (WSD-093); B-276, B-257, B-258, B-293, B-259, B-295 and B-299 closed 2026-09-25; B-296 to B-302 filed; B-261 closed 2026-09-26 (WSD-102); B-303 filed; B-284 first slice 2026-09-26 (WSD-103), trial 2026-09-27; B-304 and B-305 filed; B-284, B-298, B-302, B-300, B-286, B-301, B-287, B-307, B-309, B-312, B-313, B-294, B-263, B-282, B-310, B-297, B-314, B-306, B-304, B-242, B-270, B-289, B-251, B-285, B-290, B-303, B-268, B-319, B-318, B-308, B-292, B-305, B-320, B-321, B-252, B-322 and B-311 closed 2026-09-28; B-273 and B-291 closed by decision; B-315, B-269, B-316, B-317 and B-274 closed by decision; B-256, B-267, B-271 and B-296 closed by decision; B-306 to B-323 filed

| Rank | Item | Why here |
|---|---|---|
| Held | B-222, B-223, B-224 | WSD-097 (user, 2026-09-21): held after B-253's first report; everything already shipped stays. A defect in shipped behaviour is still fixable as its own item |
| Held | B-216, B-226, B-232 | Shipped; what remains is live host observation or target-host acceptance that a session cannot authorize for itself |
| Blocked | B-42 independent FS2 pair | Needs a participant; B-262 lowers the barrier |
| Low | B-265 | Not now (Fable, 2026-09-28): no field request; measure a workflow before shipping it |
| Low | B-323 | Cosmetic: a maintainer command's closing line; take with the next validate-dist change |
| Deferred | B-49 drill redesign | Instrument invalid under WSD-062; no execution authority |

## Open entries

### B-232 · Repair adoption instruction delivery and archive-plan documentation
**Filed against:** v0.86.0 (2026-09-09).
**Priority / effort:** P2 / M.
**Status:** PARTIALLY DONE. Delivery A released in v0.86.1. Delivery B's read-only observation did
not pass an overconstrained frozen acceptance test; comprehension or execution failure is not
established. No candidate paragraph shipped; B remains deferred.

### B-222 · Discover repository knowledge broadly, not only recurring recipes
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** L · **Invariants:** #1 #2 #3 #6 #7
**Status:** PARTIALLY DONE; held by WSD-097. Shipped in v0.84.0; synthetic observations exercised
quiet facts, 40-file exhaustion and capture routing but retained source-grounding and report-fidelity
misses. Representative enterprise and target-host behaviour remain unobserved.

### B-223 · Capture and refresh grounded knowledge in existing project-owned artifacts
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** L · **Invariants:** #1 #2 #3 #6 #7
**Status:** PARTIALLY DONE; held by WSD-097. Shipped in v0.84.0; the skill-path write route is
proven, but factual capture retained grounding misses and refresh refused an owner-approved
application. Broad recall and target-host efficacy are not established.

### B-224 · Make ordinary Copilot tasks consult relevant project knowledge
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** M · **Invariants:** #1 #2 #5 #6 #7
**Status:** PARTIALLY DONE; held by WSD-097. Shipped in v0.84.0; one ordinary CLI run read scoped
knowledge and passed hidden grading, but its fixture failed the shipped validity check. A conforming
fixture, VS Code, enterprise scale and outcome comparison remain unobserved.

### B-216 · Project-adapt instance-shaped skills instead of imposing framework defaults
**Filed against:** v0.81.0 (2026-09-03)
**Priority:** P1 · **Effort:** L · **Invariants:** #1 #2 #3 #6 #7
**Status:** PARTIALLY DONE under the WSD-074 re-lock. Shipped in v0.84.0; source, lifecycle
preservation and one Unity composition-root observation are accepted. Alternative .NET/Angular,
conflicting or unreadable sidecar, and target-host semantic behaviour remain unobserved.

### B-226 · Give every review participant the same explicit change scope
**Filed against:** v0.83.0 (2026-09-05)
**Priority:** P1 · **Effort:** M · **Invariants:** #1 #3 #5 #6 #7
**Status:** PARTIALLY DONE under the accepted bounded contract. Snapshot and scanner mechanics and
all 39 carrier changes shipped in v0.84.0. Actual model Task or sequential dispatch and
installed-host end-to-end behaviour remain unobserved.

### B-42 · Obtain balanced independent field outcomes using FS2
**Filed against:** v0.31.0 (2026-07-17)
**Priority:** P1 when a participant exists · **Effort:** M setup plus diary time · **Invariants:** #6
**Status:** PARTIALLY DONE. Production use and maintainer replay exist; the missing outcome is a
balanced non-author FS2 Module A pair and associated independent friction evidence.

### B-49 · Re-design the live-fire drill and consumer self-assessment when justified
**Filed against:** v0.31.0 (2026-07-17)
**Priority:** P3 · **Effort:** M redesign, execution separately authorized · **Invariants:** #3 #5 #6
**Status:** DEFERRED; instrument INVALID under WSD-062. The value outcome remains open. No automatic
quarterly execution or general host recertification is required by this entry.

### B-265 · Missing consumer workflows: PR description, read-only codebase explanation, major-version upgrade, Angular perf/accessibility
**Filed against:** v0.86.7 (2026-09-18)
**Priority:** P3 · **Effort:** M · **Invariants:** #1
**Status:** Open. Measure each new workflow on a scenario with `-TargetPatch` (B-253) before shipping it;
split into one item per workflow when taken.

### B-323 · `validate-dist --update-rail-sync` prints an object instead of the dist path in its closing line
**Filed against:** v0.90.0 (2026-09-28)
**Priority:** P3 · **Effort:** S · **Invariants:** —
**Status:** Open; seen during B-311. The record loop's `$dist` is the dist path `$Dist` (PowerShell names are
case-insensitive), so the update path ends "passed for System.Management.Automation.PSCustomObject …". Verdicts are
unaffected: rail-sync runs last and full runs print the path. Rename the loop variable.

## Archived

B-219 and B-221 — see `meta/BACKLOG-DONE.md`.
B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
