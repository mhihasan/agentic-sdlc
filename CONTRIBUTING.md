# Contributing to agentic-sdlc

Thank you for wanting to improve this pipeline. Contributions are welcome — new skills, improvements to existing ones, and bug reports.

## What belongs here

**Good candidates:**
- A skill that closes a gap in the pipeline (a step with no self-review, a missing handoff, an unhandled error mode)
- A craft skill grounded in a specific book or methodology
- An improvement to an existing skill that fixes a real failure mode you observed

**Not a fit:**
- Project-specific conventions (put those in your project's CLAUDE.md)
- Skills that duplicate something already in [superpowers](https://claude.com/plugins/superpowers)
- Vague "best practices" not grounded in a specific source

## Skill format

Each skill lives in `skills/<name>/` and follows this layout:

```
skills/<name>/
  SKILL.md          # YAML frontmatter + markdown body
  references/       # optional: large reference files the skill loads on demand
```

Frontmatter fields:

```yaml
---
name: skill-name        # matches the directory name and slash command
description: "..."      # one paragraph — when to use (NOT what it does)
license: MIT
model: inherit          # always inherit unless you have a specific reason
---
```

**Key rule on descriptions:** describe *when to use*, not *what the skill does*. A description that summarizes the workflow creates a shortcut the model takes instead of reading the full skill body.

## Adding a skill

1. Create `skills/<name>/SKILL.md` with frontmatter and body.
2. Run `./install.sh` to symlink it.
3. Invoke it in Claude Code and verify it behaves as documented.
4. Open a PR with a one-line summary of what gap it fills.

## Editing an existing skill

- For bug fixes: describe the failure mode you observed and how the edit fixes it.
- For new checks or steps: explain why they belong in self-review (objective/mechanical) vs AI-as-judge (subjective).
- Do not add subjective quality checks to self-review steps — those belong in `reviewing-plan` or `reviewing-code`. See the [review tiers](README.md#review-tiers) section.

## Authoring guidance

Before writing or editing a skill, read [docs/SKILL-BEST-PRACTICES.md](docs/SKILL-BEST-PRACTICES.md). It covers conciseness rules, description anti-patterns, and how to structure skill bodies so the model reads them rather than short-circuits.

## Evals

Every skill must have ≥3 evals covering all three categories: **gate** (bad input → halt), **core** (valid input → correct artifact), and **discipline** (pressure → holds the line).

Evals live in `evals/skills/<skill>.eval.json`. Fixtures live in `evals/fixtures/`.

```bash
# Validate all eval files + check coverage (deterministic, safe in CI)
python3 evals/run.py validate

# Print the RED baseline prompt — run WITHOUT the skill to confirm the baseline failure
python3 evals/run.py baseline <skill>

# Print the GREEN judge prompt — run WITH the skill, paste the transcript in
python3 evals/run.py render <skill>
```

A scenario only means something if the baseline genuinely fails without the skill (RED). If the base model already passes, the scenario is too easy — make it harder. See [evals/README.md](evals/README.md) for the full RED→GREEN method and schema.

## Pull requests

- One skill per PR unless the changes are tightly coupled.
- PR title: `feat:`, `fix:`, or `docs:` prefix + what changed.
- Include or update evals when adding or significantly changing a skill.
