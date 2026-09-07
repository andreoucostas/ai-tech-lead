# CP2 proposal — critique and provenance

**Historical Sonnet disposition:** ACCEPT as a proposal for one bounded user approval. The later
user-requested Opus review and root's source-verified revisions are recorded in
`2026-09-07-cp2-opus-critique.md`; this file preserves the earlier review rather than extending its
acceptance to changed bytes. User scope approval and all
execution evidence remain pending. This is design critique, not independent release validation or
proof that an application, oracle, network boundary or Copilot run works.

**Baseline and authors.** Authoring baseline `f5814eab7b9a859ab8aea056f7e54546c537773d`.
`/root/cp2_minimal_proposal` (`gpt-5.6-sol`) authored the initial proposal. Root reviewed the original
contracts, challenged paper-only staging and whole-integration coherence, and authored the revised
curated-task proposal. Raw drafts/results remain outside authoring Git; no candidate identity,
source answer, concrete task card or oracle is included here.

**Reviewer route.** Three fresh Claude CLI 2.1.260 sessions requested `claude-sonnet-5`, low effort,
Read-only tools, strict MCP configuration and no session persistence. All returned success/exit 0;
their result JSON reports the primary model as `claude-sonnet-5`, with ancillary Haiku metadata
calls. The first two prompts requested a blind-first threat model; the reviewers reported one.
Root inspected final result JSON and source claims but does not claim an independently observed
tool-read chronology. No reviewer executed the proposed study or its instruments.

| Review | Frozen inputs (SHA-256) | Observed result and effect |
|---|---|---|
| Initial proposal | Sol `F8F3964E33C532146E81BEAD08C35B1D676997343E3DCFF1F8FB438F8DE311B0`; root alternative `E8BABD34EA8517F2A9F664D4DDE44A98EB6F54F3801B30ADFC7910995291E17B` | REVISE. Challenged another paper-only hour, retrospective selection presented as a prospective rule, unrelated documents within the whole replay, and overly strong causal language. |
| Explicit curated task | `CA0B8542BF9C8D43E3392BA1E586E6E409587193E32B29217CA34927F306E693` | ACCEPT as a proposal. The new unit and descriptive claim limits are explicit; CP1 stays stopped; one approval covers named bounded stages with independent reviews and execution stops. Suggested clarifying scope-review timing, credential-free feeds and the meaning of a network timeout. |
| Final delta check | `7715CC4789A1E349B19657D8A32B2BB39C900BCDA035584FDBD604FA814A0F7C` | ACCEPT, no remaining blocker. Includes the three clarifications and root's separation of pre-calibration network controls from model-driven transport/retrieval probes inside capped calibration. Onboarding/tasks remain blocked until calibration succeeds. |

The final Sonnet-reviewed bytes had the hash in the last row; an external frozen copy is retained.
The companion `2026-09-07-cp2-curated-replay.md` has since been revised after Opus review. Root checked the
input hashes locally. The original whole-integration proposal was superseded explicitly; it is
not retrospectively marked accepted. Root also corrected the first review's suggestion that a
fresh historical sample removes known-answer leakage: it changes selection provenance but still
requires historical inspection for grading. The revised proposal and second review retain that
distinction. Reviewer time estimates and feasibility predictions are attributed judgments, not
observed runtimes.

**Remaining execution gaps.** The curated task and three decisions are not yet qualified; no ABP
application baseline, valid/invalid acceptance evidence, dedicated network implementation, hidden
fact freeze, headless adoption or model/credit calibration ran. At this historical checkpoint,
four preparation hours remained; the later Opus review charges another half-hour. The attempt has no
contingency and may stop at any stage. Source images and free disk are prerequisites, not readiness.
The original paid allocations and disabled overage remain; no Copilot study credit was spent here.
