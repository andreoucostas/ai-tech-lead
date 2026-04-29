# Eval harness

Tiny regression suite for the AI Tech Lead Framework rules in this repo. Probes whether the model, given this repo's `CLAUDE.md` + `FRAMEWORK-CONTEXT.md`, actually follows the rules they encode.

Run quarterly, after framework version bumps, or when you change a rule that you want to keep verifying.

## Setup

```bash
pip install -r requirements.txt
export ANTHROPIC_API_KEY=<your-key>
```

## Run

```bash
# Full suite
python run_evals.py

# Single case (id prefix match)
python run_evals.py --case dotnet-002

# Different model
python run_evals.py --model claude-sonnet-4-6
```

Exit code is 0 on full pass, 1 if any case fails. Useful in CI.

## What each case proves

Each case is one focused probe: does the model follow exactly one framework rule when prompted in the natural form a developer would use?

Two grading layers per case:
- **Deterministic** — `must_match` / `must_not_match` regex over the response text. Catches confident, fast-to-detect violations.
- **Rubric** — model-graded check using a cheap model (Haiku) for nuance the regex can't capture.

A case passes when deterministic checks all pass AND (rubric is `null` OR rubric returns `PASS`).

## Adding a case

Add to `cases.yaml`:

```yaml
- id: dotnet-006-<short-name>
  rule: CLAUDE.md > <Section>
  prompt: |
    The natural-language prompt a developer would type.
  must_match:        # optional regex list
    - 'pattern'
  must_not_match:    # optional regex list
    - 'forbidden'
  rubric: |          # optional
    Plain-English question for the grader.
```

Guidelines:
- One framework rule per case. If a case probes more than one rule, split it.
- Cases should be **prompts a real developer would type**, not contrived edge cases.
- Add a case only when you have observed (or expect) silent regression of that rule. The suite is a regression net, not coverage theatre.

## Prompt caching

The runner sends `CLAUDE.md` + `FRAMEWORK-CONTEXT.md` as system context with a `cache_control` breakpoint at the end of `CLAUDE.md`. After the first case in a run, subsequent cases hit the cache, dropping cost and latency substantially. Match this pattern when integrating Claude into your own tooling.
