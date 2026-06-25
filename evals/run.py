#!/usr/bin/env python3
"""Skill-evaluation harness for the agentic-sdlc plugin.

This harness is a loader + validator + judge-prompt renderer. It does NOT drive a live CLI
session itself (no network/API assumed). The flow is:

  1. Load every evals/skills/*.eval.json and validate its schema.
  2. For each scenario, render a ready-to-run judge prompt (from judge_prompt.md) with the
     query, expected_behavior, and a TRANSCRIPT placeholder.
  3. Report coverage: which skills have >=3 evals, which categories are present.

To actually score a skill: run the skill on the scenario's query (answering AskUserQuestion
with scripted_answers), paste the transcript into the rendered judge prompt, and have a strong
model judge it. See evals/README.md.

Usage:
  python evals/run.py validate               # validate all eval files, print coverage
  python evals/run.py render <skill> [name]  # print GREEN judge prompt(s) (skill present)
  python evals/run.py baseline <skill> [name] # print RED prompt(s) (skill ABSENT) to capture baseline
  python evals/run.py coverage               # coverage table only

Method (from superpowers:writing-skills — TDD for skills):
  An eval only means something if the skill FAILS it without the skill present (RED), then
  PASSES with the skill (GREEN). Each scenario records a `baseline` field: the expected
  no-skill behavior the skill must fix. `discipline` scenarios add a `pressure` field naming
  the pressure(s) applied (time / sunk-cost / authority / exhaustion). See evals/README.md.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

EVALS_DIR = Path(__file__).parent
SKILLS_EVAL_DIR = EVALS_DIR / "skills"
JUDGE_PROMPT = EVALS_DIR / "judge_prompt.md"
REPO_SKILLS_DIR = EVALS_DIR.parent / "skills"

REQUIRED_SCENARIO_KEYS = {"name", "category", "query", "expected_behavior", "baseline"}
VALID_CATEGORIES = {"gate", "core", "discipline"}
MIN_EVALS_PER_SKILL = 3


def load_eval_files() -> dict[str, list[dict]]:
    """Return {skill_name: [scenario, ...]} for every *.eval.json."""
    result: dict[str, list[dict]] = {}
    for path in sorted(SKILLS_EVAL_DIR.glob("*.eval.json")):
        skill = path.name[: -len(".eval.json")]
        data = json.loads(path.read_text())
        if not isinstance(data, list):
            raise ValueError(f"{path.name}: top level must be a JSON array of scenarios")
        result[skill] = data
    return result


def validate(evals: dict[str, list[dict]]) -> list[str]:
    """Return a list of problems; empty list means valid."""
    problems: list[str] = []
    known_skills = {p.name for p in REPO_SKILLS_DIR.iterdir() if p.is_dir()}

    for skill, scenarios in evals.items():
        if skill not in known_skills:
            problems.append(f"{skill}: no matching skill dir under skills/")
        if len(scenarios) < MIN_EVALS_PER_SKILL:
            problems.append(f"{skill}: only {len(scenarios)} evals (need >= {MIN_EVALS_PER_SKILL})")

        seen_names: set[str] = set()
        categories: set[str] = set()
        for i, sc in enumerate(scenarios):
            loc = f"{skill}[{i}]"
            missing = REQUIRED_SCENARIO_KEYS - sc.keys()
            if missing:
                problems.append(f"{loc}: missing keys {sorted(missing)}")
                continue
            if sc["name"] in seen_names:
                problems.append(f"{loc}: duplicate scenario name {sc['name']!r}")
            seen_names.add(sc["name"])
            if sc["category"] not in VALID_CATEGORIES:
                problems.append(f"{loc}: category {sc['category']!r} not in {sorted(VALID_CATEGORIES)}")
            categories.add(sc["category"])
            if not isinstance(sc["expected_behavior"], list) or not sc["expected_behavior"]:
                problems.append(f"{loc}: expected_behavior must be a non-empty array")
            if not isinstance(sc.get("baseline"), str) or not sc.get("baseline", "").strip():
                problems.append(f"{loc}: baseline must describe the no-skill (RED) behavior the skill fixes")
            # Discipline scenarios are pressure tests — they must name the pressure applied.
            if sc["category"] == "discipline" and not sc.get("pressure"):
                problems.append(f"{loc}: discipline scenario must carry a 'pressure' field (time/sunk-cost/authority/...)")

        # Each skill should cover all three categories (gate / core / discipline).
        missing_cats = VALID_CATEGORIES - categories
        if missing_cats and skill in known_skills:
            problems.append(f"{skill}: missing eval categories {sorted(missing_cats)}")

    return problems


def coverage(evals: dict[str, list[dict]]) -> None:
    known_skills = sorted(p.name for p in REPO_SKILLS_DIR.iterdir() if p.is_dir())
    print(f"{'skill':<24} {'evals':>5}  {'gate':>4} {'core':>4} {'disc':>4}  status")
    print("-" * 60)
    for skill in known_skills:
        scenarios = evals.get(skill, [])
        cats = {c: 0 for c in VALID_CATEGORIES}
        for sc in scenarios:
            if sc.get("category") in cats:
                cats[sc["category"]] += 1
        n = len(scenarios)
        ok = n >= MIN_EVALS_PER_SKILL and all(cats[c] >= 1 for c in VALID_CATEGORIES)
        status = "OK" if ok else ("MISSING" if n == 0 else "PARTIAL")
        print(f"{skill:<24} {n:>5}  {cats['gate']:>4} {cats['core']:>4} {cats['discipline']:>4}  {status}")


def render(evals: dict[str, list[dict]], skill: str, name: str | None) -> None:
    template = JUDGE_PROMPT.read_text()
    scenarios = evals.get(skill)
    if not scenarios:
        sys.exit(f"no evals for skill {skill!r}")
    for sc in scenarios:
        if name and sc["name"] != name:
            continue
        eb = "\n".join(f"{i + 1}. {item}" for i, item in enumerate(sc["expected_behavior"]))
        out = (
            template.replace("{{SKILL}}", skill)
            .replace("{{SCENARIO_NAME}}", sc["name"])
            .replace("{{QUERY}}", sc["query"])
            .replace("{{EXPECTED_BEHAVIOR}}", eb)
            .replace("{{TRANSCRIPT}}", "<<< PASTE THE SKILL'S TRANSCRIPT HERE >>>")
        )
        print(out)
        print("\n" + "=" * 80 + "\n")


def baseline(evals: dict[str, list[dict]], skill: str, name: str | None) -> None:
    """Print the RED prompt(s): run the scenario WITHOUT the skill, expect the baseline failure.

    Per superpowers:writing-skills, an eval is only meaningful if a no-skill agent fails it.
    Capture this baseline once; if the no-skill agent already passes, the eval tests the base
    model, not the skill — rewrite the scenario to be harder.
    """
    scenarios = evals.get(skill)
    if not scenarios:
        sys.exit(f"no evals for skill {skill!r}")
    for sc in scenarios:
        if name and sc["name"] != name:
            continue
        pressure = f"\nPressure applied: {sc['pressure']}" if sc.get("pressure") else ""
        print(f"# BASELINE (RED) — {skill} — {sc['name']}")
        print(f"# category: {sc['category']}{pressure}")
        print("# Run this query in a FRESH session with the skill NOT loaded. Capture what the")
        print("# agent does. The eval is valid only if the no-skill agent exhibits the baseline below.")
        print(f"\n## Query\n{sc['query']}")
        print(f"\n## Expected baseline failure (what a no-skill agent does)\n{sc['baseline']}")
        print(f"\n## The skill must instead produce (GREEN — see `render`)")
        for i, item in enumerate(sc["expected_behavior"]):
            print(f"  {i + 1}. {item}")
        print("\n" + "=" * 80 + "\n")


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "validate"
    evals = load_eval_files()

    if cmd == "validate":
        problems = validate(evals)
        coverage(evals)
        print()
        if problems:
            print(f"FAIL — {len(problems)} problem(s):")
            for p in problems:
                print(f"  - {p}")
            sys.exit(1)
        print("OK — all eval files valid, every skill has >= 3 evals across gate/core/discipline.")
    elif cmd == "coverage":
        coverage(evals)
    elif cmd == "render":
        if len(sys.argv) < 3:
            sys.exit("usage: run.py render <skill> [scenario-name]")
        render(evals, sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    elif cmd == "baseline":
        if len(sys.argv) < 3:
            sys.exit("usage: run.py baseline <skill> [scenario-name]")
        baseline(evals, sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    else:
        sys.exit(f"unknown command {cmd!r} — use validate | coverage | render | baseline")


if __name__ == "__main__":
    main()
