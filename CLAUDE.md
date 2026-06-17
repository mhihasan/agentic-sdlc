# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

`agentic-skills` is a collection of AI coding-assistant skill definitions — pure Markdown, no build system. Skills are symlinked into `~/.claude/skills/` and invoked via slash commands in Claude Code and compatible tools (OpenCode, Cursor, GitHub Copilot).

Two directories:
- `skills/` — agentic workflow pipeline skills (installed by `install.sh`)
- `book-skills/` — standalone book-grounded coaching skills (install manually by symlinking)

## Installation

```bash
# User scope — available in all projects
./install.sh --scope=user --tool=claude      # → ~/.claude/skills/
./install.sh --scope=user --tool=copilot     # → ~/.copilot/skills/
./install.sh --scope=user --tool=all         # → both

# Project scope — one project only
./install.sh --scope=project --tool=claude /path/to/project
```

Safe to re-run. Existing symlinks are updated; real directories are never overwritten.

## Skill File Format

Each skill lives in `skills/<name>/` and follows this layout:

```
skills/<name>/
  SKILL.md          # skill definition — YAML frontmatter + markdown body
  references/       # optional: reference files the skill loads on demand via Read tool
```

**SKILL.md frontmatter fields:**

```yaml
---
name: skill-name              # matches the directory name and slash command
description: "..."            # one-paragraph trigger description — when to use, NOT what it does
model: inherit                # optional — always inherit unless you have a specific reason
color: lightgreen             # optional — UI accent color
license: MIT                  # optional
---
```

Reference files in `references/` are not auto-loaded — the skill body must explicitly tell the model which files to read and when.

**Key rule on descriptions:** describe *when to use*, not *what the skill does*. A description that summarizes the workflow creates a shortcut the model takes instead of reading the full skill body.

## Agentic Workflow Pipeline

These skills chain into a feature-development pipeline:

```
picking-up-task             Jira URL/key or local file  →  branch + tickets/TICKET-KEY/TICKET-KEY.md
        ↓
planning-from-ticket   ticket file   →  PLAN-<KEY>.md
        ↓
generating-tasks       plan file     →  PLAN-<KEY>.md (# Tasks section appended)
        ↓
reviewing-plan         plan+tasks    →  verdict before any code is written
        ↓                                (DO NOT PROCEED → receiving-plan-review → back to planning)
implementing-tasks     task spec     →  working code via TDD (auto-selects testing-pytest or testing-vitest)
        ↓
reviewing-code         code/PR/diff  →  triage-first review report
        ↓                                (FAIL → superpowers:receiving-code-review → back to implementing)
crafting-commits       branch        →  clean conventional-commit history
        ↓
superpowers:finishing-a-development-branch   →  merge / PR / cleanup
```

Each step is independently usable — enter at any point if the upstream artifact already exists.

**`fetching-tickets`** is a legacy standalone skill superseded by `picking-up-task`. It fetches a Jira ticket to disk without setting up a branch — only use it if you want the ticket file without the full `picking-up-task` setup.

**`generating-design-doc`** is an on-demand skill (not a pipeline step). Use it to generate a production-grade architecture doc from an existing codebase — invoke directly at any point, independent of the pipeline.

**`de-slop`** is an on-demand skill (not a pipeline step). Use it to strip AI writing patterns from any text — posts, docs, READMEs, emails — and rewrite to sound like a specific human wrote it.

## Review Tiers

The pipeline uses two complementary review layers to avoid self-preference bias:

| Tier | Who | Scope | When |
|---|---|---|---|
| **Self-review** | The producing skill | Objective/mechanical checks (placeholders, file coverage, format) | Every artifact boundary |
| **AI-as-judge** | Independent fresh-context subagent on a strong model | Subjective quality (scope, over-engineering, breaking changes, design) with BLOCKER/SHOULD-FIX/NIT severity | `reviewing-plan` · `reviewing-code` |

Do not add subjective quality checks to self-review steps — those belong in the AI-as-judge skills.

## Adding or Editing a Skill

1. Create `skills/<name>/SKILL.md` with the frontmatter above and a markdown body.
2. Add `skills/<name>/references/` for any large reference content the skill loads selectively.
3. Re-run `./install.sh` to update the symlink.
4. Invoke it in Claude Code and verify it behaves as documented.

There are no tests or linting steps — correctness is validated by invoking the skill in Claude Code. For rigorous skill authoring, use the `superpowers:writing-skills` skill.

## Book Skills

`book-skills/` contains standalone coaching skills grounded in specific books. Install manually:

```bash
ln -s /path/to/agentic-skills/book-skills/<name> ~/.claude/skills/<name>
```

| Skill | Grounded in |
|---|---|
| `clean-architecture` | Robert C. Martin, *Clean Architecture* |
| `clean-coding` | Robert C. Martin, *Clean Code* |
| `ddd-expert` | Eric Evans, *Domain-Driven Design* |
| `design-patterns-expert` | Alexander Shvets, *Dive Into Design Patterns* |
| `pragmatic-engineer` | Thomas & Hunt, *The Pragmatic Programmer* |
| `system-designing` | Kleppmann & Riccomini, *Designing Data-Intensive Applications* |

## Pull Requests

Always create PRs as drafts (`gh pr create --draft`). Never create a ready-for-review PR directly.

## Docs

`docs/superpowers/` contains design specs and implementation plans for skills being developed or proposed. Not auto-loaded — read on demand when working on a specific skill.
