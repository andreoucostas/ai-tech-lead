# B-18 — opt-in git-hook convenience net

## Premise and proportionality

B-18 was filed against v0.26.0. Its premise remains live: the current shipped tree has no consumer
git-hook setup script, while B-100's maintainer-only staged scanner and hooks remain under the
authoring-only `.claude/` tree. The observed harm is guard-bypassing shell/external writes documented
in B-100; an opt-in added-lines scan reduces that noise-prone gap without claiming enforcement.

The proportional fix is two shipped setup/scan twins and one explicit installer option. A hook-chain
manager, default installation, prompt, copied pattern list, or rules-carrier text would add scope
without removing more of the observed harm.

## Locked design

1. Add `src/core/scripts/setup-git-hooks.ps1` and `.sh`. Normal mode resolves the target Git repo,
   refuses an effective `core.hooksPath`, `.git/hooks/pre-commit`, or `.husky/`, then writes one
   pre-commit hook. Scan mode reads staged zero-context diffs, retains only added lines, and invokes
   the matching shipped `.claude/hooks/guard.*` with a synthetic write event per changed path.
2. The generated hook delegates to the shipped setup script's scan mode. Guard patterns therefore
   remain canonical in `guard.*`; neither setup twin contains a pattern list.
3. Add `-GitHooks` / `--git-hooks` to both root dispatchers and both shipped installers. The default
   remains unchanged and non-interactive. The shipped installer invokes setup only when opted in.
4. Document the option in `docs/enforcement-surfaces.md` as a bypassable convenience net, explicitly
   including `--no-verify`; do not add static-context prose.
5. Recompose all distributions, check generated ownership classification, run PowerShell validation
   and the four required scratch-repository red-test arms, and report Bash legs as UNRUN.

## Adversarial critique

- Full-file scanning would flag inherited content and violate the retention requirement; zero-context
  staged diffs avoid it.
- Writing through `core.hooksPath` or composing another owner's hook would create ambiguous ownership;
  refusal is safer and required.
- A generated hook containing the scan or guard patterns could drift. Delegation to the shipped setup
  scanner, which itself invokes the shipped guard, keeps one guard implementation.
- A successful hook run cannot support an enforcement claim because `git commit --no-verify` bypasses
  it. Documentation and output must use “convenience net”, not gate/protection/guarantee language.
- Diff parsing must not confuse Git examination failure with clean content. Each Git subprocess error
  is reported as an operational failure and exits non-zero.

