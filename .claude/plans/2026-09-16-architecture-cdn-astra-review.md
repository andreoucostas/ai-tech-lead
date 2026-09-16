# Architecture viewer: Astra value and security review

Date: 2026-09-16. Frozen baseline: `0ca62573c1b10a16026c28cb19c5d66e50a92a04`, framework v0.86.7.
The user requested an Astra adversarial review of the original finding and plan, explicitly adding
what value the artifact provides and whether it is needed. This expands the review question; it
does not authorize product retirement or implementation.

## Review receipt and scope

Root dispatched a separate collaboration agent with the explicit `gpt-6-astra` model selection,
task `/root/astra_architecture_value_review`, without inherited conversation turns or implementation
participation. The prompt supplied the original field finding and immutable commit, required
source/value assessment before reading either prior plan/review, and allowed premise rejection.
Astra sent a preliminary assessment before its message saying it would read the proposals. Its
detailed tool-read order is reviewer-reported; root did not capture an independent internal trace.
Root supplied neutral source pointers to the optional `/impact` caller and retirement code, then
specific ownership constraints for the reviewer to check; no prior verdict was supplied before
the preliminary assessment.

The reviewer reports native PowerShell read-only Git/source inspection and official web research;
its only write was the temporary report. Root read the complete report and independently verified
its SHA-256: `F95C0E2D02F9D7101290D2EC6F7FF2D1C24695FB6C671FF161C2798827C1C56A`.
The original report is retained verbatim below. No browser, exploit, asset-download, mutation,
installation, user-value experiment or product implementation was performed by this review.

## Root disposition

**Finding valid; revise the preservation premise.** Accept Astra's conclusion that the earlier
"smallest sufficient fix" assumed a surviving runtime viewer. The HTML offers styled direct
browser viewing of existing Markdown and diagrams, with no additional architectural knowledge.
The source describes framework operation, and the documented readers are humans. That convenience
has value, but the inspected contracts do not make a custom runtime essential. The report itself
shows inspection; neither it nor absent telemetry establishes how often people depend on the view.

Prefer a retirement/transition proposal before investing in the hardening plan. Retain canonical
Markdown and evaluate a small inert page at the existing HTML pathname, delivered by the current
ordinary overwrite policy, plus separate generator retirement. The consequence is explicit:
opening architecture.html would no longer display the diagrams. A demonstrated essential direct-
browser use case could justify retaining and hardening the viewer instead. This is a proposed
direction, not an implementation lock or a claim that retirement takes less initial work.

Root checked the source facts independently: installer ownership/retirement conditions; the
optional generator reference in `src/core/.claude/commands/impact.md:39`; protected Markdown and
overwritten HTML/generator entries; and DocTruth's CR-normalized string comparison. The original
Opus record's literal byte-comparison description must not be reused as the freshness contract.
History `af52460` introduces the viewer; `0232765` parameterizes the generator for other outputs.
Root also checked current [GitHub diagram documentation](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams)
and [VS Code Mermaid preview documentation](https://code.visualstudio.com/docs/languages/markdown#_mermaid-diagram-rendering).
These support possible substitutes, not verified rendering on each consumer's host/version.

The next design must distinguish ordinary stub replacement from ledger retirement, since the
same incoming path cannot be both. Known generators may be retired with existing ownership/hash
checks; unknown files, missing manifests and previously generated impact/custom reports require
explicit residual handling. Preserve consumer Markdown and avoid blanket deletion of reports.
Update all live callers, review instructions and freshness/test assumptions to the chosen product
contract. A stub is a compatibility measure, not an additional renderer. No script, embedded
Markdown, external asset or automatic redirect belongs in that proposed stub.

The retained-viewer security findings remain applicable if retention is selected. They do not
establish that every extra hardening mechanism is needed when the runtime can be removed. Preserve
both previous reports as history; B-239 and WSD-087 now record the reopened product decision.

## Planning verification

Root ran the existing complete BacklogHygiene suite directly under PS7 and PS5.1: each reported
10 passed, 0 failed, 0 skipped and exit 0, including its positive/negative consistency fixtures.
Root verified that the recorded original report ends with the exact text of the hashed temporary
report, `git diff --check` passed, and `src/` and `dist/` had no changes. These are planning-record
checks, not evidence that the proposed transition works. The previous review commit's CI was also
observed complete: run `35091611350`, all eight required Windows execution jobs and parity green.

## Original Astra report (verbatim)

Astra independent architecture HTML review — 2026-09-16

Baseline: 0ca62573c1b10a16026c28cb19c5d66e50a92a04, framework v0.86.7. Reviewer: user-requested Astra agent; no implementation participation. Repository references below are immutable baseline paths and line numbers. This is design/product review, not release approval.

Verdicts

The original finding is valid. src/core/scripts/build-architecture-html.ps1:68–69 emits third-party script URLs with major-version selectors and no integrity metadata; the .NET source HTML:235–236 contains them. The committed document therefore does not determine the executable bytes. This is browser-context script exposure, not demonstrated machine compromise, local-file access, or exploitation. The report establishes inspection, not a compromised CDN.

The revised proposal is technically much stronger than the original, but REVISE its product premise before locking it. “Smallest sufficient fix” in the original plan:14 assumes the viewer must survive. That assumption was never established. Root's dispositions appropriately correct Opus's lossy closing-tag substitution and assertion that CSP must authorize the CDN hostname.

Value and necessity

The artifact adds a styled, directly browser-openable presentation of Markdown and Mermaid diagrams. This is a real convenience for a reviewer without a suitable Markdown viewer. It adds no separate architecture knowledge. The inspected .NET ARCHITECTURE.md:1–13 describes the framework, not the consuming application's architecture; its workflow, carrier and hook diagrams explain framework operation. Keeping that overview is useful, but its title/location can invite confusion in installed projects. Do not turn this security fix into a documentation relocation.

README:157 and docs/REVIEW-GUIDE.md:12 establish a human review use case. They do not establish a need for a custom runtime. GitHub documents Mermaid rendering in Markdown, and current VS Code documentation describes built-in Mermaid preview ([GitHub](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams), [VS Code](https://code.visualstudio.com/docs/languages/markdown#_mermaid-diagram-rendering)). These are credible substitutes, not verified equivalents on consumers' installed versions or Bitbucket deployments. Markdown remains readable as text when diagrams cannot render.

The viewer is unnecessary to the framework's executable function in the inspected contracts. Whether its convenience justifies maintenance is a product choice; absent telemetry is not proof of non-use. History af52460 introduced the reviewer view in v0.9.1; 0232765 generalized the generator for impact reports. Today src/core/.claude/commands/impact.md:32,39 retains canonical Markdown and makes HTML optional. This weakens, without disproving, a necessity argument.

Prioritized findings

1. High — Decide whether to preserve the runtime before buying its security maintenance. Prefer retiring the runtime viewer, retaining canonical Markdown, and shipping an inert transition page at docs/architecture.html through ordinary overwrite. It should contain only a local Markdown link and brief viewing instructions: no embedded Markdown, script, external assets or automatic redirect. This retains old links and neutralizes that installed pathname without adding a renderer. Loss: directly opening that file no longer displays diagrams. If an evidenced essential review flow requires that convenience, retain and harden instead.

2. High — Retirement must include installed and generated copies. dist/dotnet/framework-ownership.json:82,85,100 classifies Markdown as protected and HTML/generator as overwritten. src/core/scripts/install.ps1:280–331 deletes a retired file only with previous ownership and recognized bytes; missing manifests or consumer-generated hashes preserve it. A shipped stub is an ordinary replacement, not ledger retirement: :212 rejects simultaneous incoming ownership and retirement. Retire the generator separately using existing machinery and disclose preserved legacy scripts. Old impact.html or custom-output pages are not repaired by replacing architecture.html. Supply explicit migration guidance for those copies; do not delete arbitrary reports or consumer Markdown. Unupdated installations remain exposed under every proposed option.

3. Medium — If retained, distinguish three trust boundaries. Exact version/file pins plus independently cross-checked SRI bytes address later substitution, not a malicious selected release. Registry/CDN equality is useful corroboration, not publisher innocence. SRI needs compatible cross-origin delivery ([SRI](https://www.w3.org/TR/2016/REC-SRI-20160623/)). Lossless embedding must round-trip the actual Markdown, including Unicode, mixed-case closing tags, backslashes and comment/script sequences; escaping only a closing tag is an inadequate contract ([HTML](https://html.spec.whatwg.org/multipage/scripting.html#restrictions-for-contents-of-script-elements)). Title encoding is separate. Marked output remains unsanitized ([Marked](https://marked.js.org/)); CSP does not convert this into a general safe-untrusted-document viewer.

4. Medium — Keep the corrected CSP and evidence boundaries. Hash-authorized external scripts are specified; a broad CDN source is unnecessary. Meta CSP excludes sandbox, frame-ancestors and report-uri and cannot protect preceding content ([CSP3](https://www.w3.org/TR/CSP3/)). Select actual assets and demonstrate minimal resource/style exceptions. Tamper tests must hold policy/integrity constant, observe genuine/altered/genuine delivery, and distinguish SRI rejection from CORS, CSP and network failure. Test preserved content as well as absent execution. No browser behavior was executed here.

5. Medium — Update the contracts to the chosen destination. BuildArchitectureHtml.Tests.ps1:8–43 exercises formatting, not script trust. docs-sync-check.ps1:150–157 is only a conditional source-hash advisory. DocTruth.Tests.ps1:244–280 regenerates pages and compares CR-normalized text, not literal byte equality or security. Retirement requires removing generator invocation/freshness obligations and updating all three README/review-guide/architecture sources plus /impact. Do not merely delete tests while leaving unsafe output possible.

Ranked options

1. Inert transition page plus runtime/generator retirement: preferred ongoing scope; migration work remains.
2. Exact pins + SRI plus bounded embedding/title fixes: narrowest retained-viewer response to the field finding; retains network dependence and residual rendered-HTML risk.
3. Revised CSP hardening: reasonable if preserving the viewer is justified; greater compatibility and evidence burden.
4. Vendoring or pre-rendering: justified by an actual offline/export requirement. Vendoring still runs dependencies and requires provenance/licences/upgrades; pre-rendering removes runtime libraries only if output is actually inert, while adding generation tooling.
5. Unchanged: preserves convenience and the reported trust gap without compensating evidence.

Smallest next direction and acceptance

Re-lock a retirement/transition design, not implementation. Preserve ARCHITECTURE.md byte-for-byte in upgrade fixtures, demonstrate ordinary HTML replacement, known generator retirement and unknown/missing-manifest preservation, and provide actionable legacy-report guidance. Keep the stub policy simple; verify local navigation and no external requests. Red-test focused assertions on unsafe output and clean transition states directly under PS7/PS5.1; compose all distributions, update release records and RCA, and obtain implementation review. No installer redesign or generic browser framework is justified.

Evidence limits

I used native PowerShell read-only Git inspection at the frozen commit and official web documentation. Blind-first source/use/ownership/freshness inspection and preliminary assessment preceded both prior proposals; the maintainer DocTruth implementation was inspected afterwards. No builds, mutations, browser execution, asset downloads, exploitation, user study, timing or size measurement occurred. No claim establishes substitute rendering on the user's host, actual demand, or complete historical-copy cleanup. The only write is this temporary review.
