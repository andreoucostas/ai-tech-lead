"""
AI Tech Lead Framework — eval harness.

Runs the cases in cases.yaml against the Anthropic API using this repo's
CLAUDE.md and FRAMEWORK-CONTEXT.md as system context (with prompt caching).
Reports a pass/fail summary per case and an overall score.

Usage:
    pip install -r requirements.txt
    export ANTHROPIC_API_KEY=...
    python run_evals.py [--model claude-opus-4-7] [--case <id-prefix>]

The harness is intentionally small. Add a case only when a framework rule is at
risk of silent regression. See README.md.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

import anthropic
import yaml

DEFAULT_MODEL = "claude-opus-4-7"
GRADER_MODEL = "claude-haiku-4-5-20251001"
REPO_ROOT = Path(__file__).resolve().parents[2]


@dataclass
class CaseResult:
    case_id: str
    rule: str
    deterministic_pass: bool
    deterministic_failures: list[str]
    rubric_pass: bool | None
    rubric_reason: str | None
    response_excerpt: str


def load_cases(path: Path, filter_prefix: str | None) -> list[dict]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    cases = data["cases"]
    if filter_prefix:
        cases = [c for c in cases if c["id"].startswith(filter_prefix)]
    return cases


def build_system_blocks(repo_root: Path) -> list[dict]:
    """
    Stable framework context first, with a cache_control breakpoint at the end of
    CLAUDE.md so the prefix is reused across cases.
    """
    claude_md = (repo_root / "CLAUDE.md").read_text(encoding="utf-8")
    framework_md_path = repo_root / "FRAMEWORK-CONTEXT.md"
    framework_md = framework_md_path.read_text(encoding="utf-8") if framework_md_path.exists() else ""

    blocks: list[dict] = [
        {
            "type": "text",
            "text": claude_md,
            "cache_control": {"type": "ephemeral"},
        }
    ]
    if framework_md:
        blocks.append({"type": "text", "text": framework_md})
    return blocks


def deterministic_check(text: str, case: dict) -> tuple[bool, list[str]]:
    failures: list[str] = []
    for pattern in case.get("must_match", []):
        if not re.search(pattern, text, re.MULTILINE):
            failures.append(f"missing required pattern: /{pattern}/")
    for pattern in case.get("must_not_match", []):
        if re.search(pattern, text, re.MULTILINE):
            failures.append(f"contains forbidden pattern: /{pattern}/")
    return (not failures), failures


def rubric_check(client: anthropic.Anthropic, case: dict, response_text: str) -> tuple[bool | None, str | None]:
    rubric = case.get("rubric")
    if not rubric:
        return None, None

    grader_prompt = (
        f"You are grading an AI response against a rubric.\n\n"
        f"Rubric:\n{rubric}\n\n"
        f"Response to grade:\n---\n{response_text}\n---\n\n"
        f"Reply with exactly one line in the form: PASS - <one-line reason> "
        f"or FAIL - <one-line reason>. No other commentary."
    )
    msg = client.messages.create(
        model=GRADER_MODEL,
        max_tokens=200,
        messages=[{"role": "user", "content": grader_prompt}],
    )
    out = msg.content[0].text.strip()
    is_pass = out.upper().startswith("PASS")
    reason = out.split("-", 1)[1].strip() if "-" in out else out
    return is_pass, reason


def run_case(client: anthropic.Anthropic, system_blocks: list[dict], case: dict, model: str) -> CaseResult:
    response = client.messages.create(
        model=model,
        max_tokens=2048,
        system=system_blocks,
        messages=[{"role": "user", "content": case["prompt"]}],
    )
    text = "".join(block.text for block in response.content if hasattr(block, "text"))

    det_pass, det_failures = deterministic_check(text, case)
    rub_pass, rub_reason = rubric_check(client, case, text)

    return CaseResult(
        case_id=case["id"],
        rule=case.get("rule", ""),
        deterministic_pass=det_pass,
        deterministic_failures=det_failures,
        rubric_pass=rub_pass,
        rubric_reason=rub_reason,
        response_excerpt=text[:280].replace("\n", " "),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run framework eval cases.")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Claude model id (default: %(default)s)")
    parser.add_argument("--case", default=None, help="Filter by case id prefix")
    parser.add_argument("--cases-file", default=str(Path(__file__).parent / "cases.yaml"))
    args = parser.parse_args()

    if "ANTHROPIC_API_KEY" not in os.environ:
        print("ERROR: ANTHROPIC_API_KEY is not set.", file=sys.stderr)
        return 2

    cases = load_cases(Path(args.cases_file), args.case)
    if not cases:
        print("No cases matched the filter.", file=sys.stderr)
        return 2

    client = anthropic.Anthropic()
    system_blocks = build_system_blocks(REPO_ROOT)

    results: list[CaseResult] = []
    for case in cases:
        print(f"-> {case['id']} ... ", end="", flush=True)
        try:
            result = run_case(client, system_blocks, case, args.model)
        except Exception as exc:
            print(f"ERROR: {exc}")
            continue
        marker = "PASS" if (result.deterministic_pass and result.rubric_pass is not False) else "FAIL"
        print(marker)
        results.append(result)

    det_pass = sum(1 for r in results if r.deterministic_pass)
    rub_total = sum(1 for r in results if r.rubric_pass is not None)
    rub_pass = sum(1 for r in results if r.rubric_pass is True)

    print()
    print("=" * 60)
    print(f"Cases run: {len(results)}")
    print(f"Deterministic pass: {det_pass} / {len(results)}")
    if rub_total:
        print(f"Rubric pass:        {rub_pass} / {rub_total}")
    print("=" * 60)

    for r in results:
        if r.deterministic_pass and r.rubric_pass is not False:
            continue
        print()
        print(f"FAIL: {r.case_id}  [{r.rule}]")
        for f in r.deterministic_failures:
            print(f"  - deterministic: {f}")
        if r.rubric_pass is False:
            print(f"  - rubric: {r.rubric_reason}")
        print(f"  excerpt: {r.response_excerpt}...")

    failed_total = sum(1 for r in results if not r.deterministic_pass or r.rubric_pass is False)
    return 1 if failed_total else 0


if __name__ == "__main__":
    sys.exit(main())
