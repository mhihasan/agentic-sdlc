# agent-skills

Generic engineering craft skills for AI coding assistants.

Book-grounded, employer-neutral, and reusable by any engineer. Works with
Claude Code, OpenCode, Cursor, and any tool that reads `~/.claude/skills/`.

## Agentic Coding Workflow

These skills chain into a single feature-development pipeline — ticket in,
reviewed code out. This section is the single source of truth for the flow;
individual skills only reference their immediate neighbors, not the whole chain.

```
fetching-tickets       Jira ticket  →  local TICKET-<KEY>.md
        │
planning-from-ticket   ticket       →  reviewed PLAN-<KEY>.md (beside it)
        │
generating-tasks       plan         →  PLAN-<KEY>.md + appended "# Tasks"
        │
reviewing-plan         PLAN+TASKS   →  verdict (scope, over-engineering, breaking changes) BEFORE code
        │
implementing-tasks     task spec    →  working code via TDD
        │
reviewing-code         code/PR/diff →  triage-first review report
```

| Skill | What it does |
|---|---|
| `fetching-tickets` | Pull a Jira ticket to a local markdown file with all images downloaded |
| `planning-from-ticket` | Turn a local ticket/spec file into a reviewed implementation `PLAN-<KEY>.md` beside it |
| `generating-tasks` | Append TDD-ready task specs into the `PLAN-<KEY>.md` |
| `reviewing-plan` | Judge the PLAN+TASKS against the ticket *before* any code is written |
| `implementing-tasks` | Implement a task spec via TDD, auto-selecting the project's testing skill |
| `reviewing-code` | Triage-first code review of implemented code / a PR / a diff |

Each step is independently usable — you can enter at any point if the upstream
artifact already exists (e.g. run `reviewing-code` on any PR with no plan).

## Craft Skills

Standalone, book-grounded skills usable on their own or within the workflow above.

| Skill | Grounded in |
|---|---|
| `clean-architecture` | Robert C. Martin — *Clean Architecture* (2017) |
| `clean-coding` | Robert C. Martin — *Clean Code* (2008) |
| `ddd-expert` | Eric Evans — *Domain-Driven Design* (2003) |
| `design-patterns-expert` | Alexander Shvets — *Dive Into Design Patterns* (2022) |
| `design-doc-generator` | Generates production-grade architecture docs from a codebase |
| `pragmatic-engineer` | Thomas & Hunt — *The Pragmatic Programmer* (2019) |
| `system-designing` | Kleppmann & Riccomini — *Designing Data-Intensive Applications* (2nd ed.) |
| `pytest-expert` | Opinionated pytest best practices for Python |
| `vitest-react` | Unit testing for React + Vitest + TypeScript projects |
| `git-commit-craft` | Analyzes a branch and rewrites commit history using conventional commits |

## Installation

```bash
git clone git@github.com:mhihasan/agent-skills.git
cd agent-skills
./install.sh
```

`install.sh` symlinks all skills into `~/.claude/skills/` (and any other
agent tool directories detected on your machine). Safe to re-run — existing
symlinks are updated, real directories are never overwritten.

