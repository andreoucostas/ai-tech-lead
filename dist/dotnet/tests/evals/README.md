# Eval cases

Documentary examples of the AI Tech Lead Framework rules in this repo. Read `cases.yaml` to see
the behavior each rule is intended to encourage or prevent.

## What each case proves

Each case is one focused probe: does the model follow exactly one framework rule when prompted in the natural form a developer would use?

Each case records two kinds of expected evidence:
- **Patterns** — `must_match` / `must_not_match` examples of confident, fast-to-detect violations.
- **Rubric** — a plain-English question capturing nuance the patterns cannot express.

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
