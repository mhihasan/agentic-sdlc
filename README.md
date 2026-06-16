# coding-agent-skills

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Last commit](https://badgen.net/github/last-commit/mhihasan/coding-agent-skills)](https://github.com/mhihasan/coding-agent-skills/commits/main)
[![Stars](https://badgen.net/github/stars/mhihasan/coding-agent-skills)](https://github.com/mhihasan/coding-agent-skills/stargazers)

**Skills for AI coding agents** — a full Jira-to-PR pipeline with self-review gates at every artifact boundary and an independent AI-as-judge before you ship.

> *Review early, review often.* A finding caught after one task costs one task to fix. A finding caught after five can invalidate all five.

Works with Claude Code, OpenCode, Cursor, and any tool that reads `~/.claude/skills/`.

## Use cases

**Agentic workflow**
- Pull a Jira ticket, plan it, generate TDD tasks, implement, review, and open a PR — without leaving the agent
- Enter the pipeline at any step — if you already have a plan file, skip straight to implementation

**Code review**
- Review a branch before opening a PR — parallel AI judges, domain-filtered diff, triage-first report with BLOCKER/SHOULD-FIX/NIT severity
- Review any existing PR or diff without needing a plan file

**Planning & design**
- Turn a ticket or spec into a structured implementation plan with scope, risks, and breaking changes surfaced upfront
- Block implementation until the plan passes an AI-as-judge gate — never implement a flawed design
- Generate an architecture design doc from an existing codebase

**Implementation**
- Execute TDD tasks one by one — auto-selects pytest or Vitest, enforces the TDD Iron Law (no code before a failing test)
- Dispatch parallel agents on multi-failure test runs instead of fixing one failure at a time

**Craft coaching**
- Architecture review — Dependency Rule violations, boundary placement, Clean Architecture compliance
- DDD modeling — identify Aggregates, Bounded Contexts, and Ubiquitous Language gaps in a codebase
- System design Q&A — grounded in DDIA; covers replication, sharding, consistency, stream processing
- Code quality critique — Clean Code and Pragmatic Programmer lens on functions, naming, error handling

**Commit hygiene**
- Rewrite a messy branch history into clean conventional commits — human-gated before anything is pushed

## Quickstart

**Option A — review any branch right now (zero setup):**

```
/reviewing-code branch
```

Point it at your current branch. It dispatches parallel AI judges, filters the diff by domain, and produces a triage-first report. No plan file needed.

---

**Option B — full pipeline from a Jira ticket:**

```bash
# 1. Install dependencies
/plugin install superpowers@claude-plugins-official       # in Claude Code
/plugin marketplace add mhihasan/coding-agent-skills      # in Claude Code
/plugin install coding-agent-skills@coding-agent-skills   # in Claude Code

# 2. Pull a ticket
/fetching-tickets https://yoursite.atlassian.net/browse/PROJ-123

# 3. Plan it
/planning-from-ticket tickets/PROJ-123/PROJ-123.md

# 4. Generate TDD tasks
/generating-tasks tickets/PROJ-123/PLAN-PROJ-123.md

# 5. Judge the plan (AI-as-judge — blocks implementation if findings are blockers)
/reviewing-plan tickets/PROJ-123/PLAN-PROJ-123.md

# 6. Implement (refuses to start without a PROCEED verdict marker)
/implementing-tasks tickets/PROJ-123/PLAN-PROJ-123.md auto

# 7. Review the code
/reviewing-code branch

# 8. Clean up commits
/crafting-commits
```

Each step is independently usable — enter at any point if the upstream artifact already exists.

## Agentic Coding Workflow

These skills chain into a single feature-development pipeline — ticket in,
reviewed code out.

```mermaid
flowchart TD
    classDef pipe fill:#dbeafe,stroke:#3b82f6,color:#1e3a5f
    classDef judge fill:#fef3c7,stroke:#d97706,color:#78350f
    classDef sp fill:#dcfce7,stroke:#16a34a,color:#14532d
    classDef gate fill:#fee2e2,stroke:#dc2626,color:#7f1d1d

    W(["[0] using-git-worktrees\nisolate workspace"]):::sp
    FT["[1] fetching-tickets\nJira → TICKET-KEY.md · ✔ self-review"]:::pipe
    PFT["[2] planning-from-ticket\nticket → PLAN-KEY.md · ✔ self-review"]:::pipe
    GT["[3] generating-tasks\nPLAN + Tasks section · ✔ self-review"]:::pipe
    RP["[4] reviewing-plan\nAI-as-judge · fresh-context · strong model\nemits verdict marker"]:::judge
    GATE{"verdict marker\nin PLAN file?"}:::gate
    IT["[5] implementing-tasks\nTDD · pytest-expert / vitest-react\n↺ mid-task review gate"]:::pipe
    RC["[6] reviewing-code\nAI-as-judge · fresh-context · strong model"]:::judge
    CC["[6.5] crafting-commits\nclean history · ✔ self-review · human-gated"]:::pipe
    FDB(["[7] finishing-a-development-branch\nprint merge/PR commands"]):::sp

    W --> FT --> PFT --> GT --> RP
    RP -->|PROCEED| GATE
    RP -.->|"DO NOT PROCEED — fix plan"| GT
    GATE -->|present| IT
    GATE -.->|"missing — halt"| RP
    IT --> RC
    RC -->|PASS| CC --> FDB
    RC -.->|"FAIL — fix code"| IT
```

> 🔵 pipeline steps · 🟡 AI-as-judge · 🟢 superpowers steps · dotted = fix & retry

### Superpowers sub-skills

| Step | Requires / adopts |
|---|---|
| [2] `planning-from-ticket` | REQUIRED: `superpowers:brainstorming` · ADOPT: `superpowers:writing-plans` rigor |
| [3] `generating-tasks` | ADOPT: `superpowers:writing-plans` bite-sized-task discipline |
| [5] `implementing-tasks` | REQUIRED: `superpowers:test-driven-development` + `pytest-expert` / `vitest-react` · `superpowers:systematic-debugging` on wrong-reason RED · `superpowers:dispatching-parallel-agents` on multi-failures · `superpowers:verification-before-completion` before marking done · `superpowers:requesting-code-review` mid-task |
| [6] `reviewing-code` | ADOPT: `superpowers:requesting-code-review` (SHA convention) · `superpowers:receiving-code-review` (verify-before-fix) |

| Skill | What it does |
|---|---|
| `fetching-tickets` | Pull a Jira ticket to a local markdown file with all images downloaded |
| `planning-from-ticket` | Turn a local ticket/spec file into a reviewed implementation `PLAN-<KEY>.md` beside it |
| `generating-tasks` | Append TDD-ready task specs into the `PLAN-<KEY>.md` |
| `reviewing-plan` | Judge the PLAN+TASKS against the ticket *before* any code is written |
| `implementing-tasks` | Implement a task spec via TDD, auto-selecting the project's testing skill |
| `reviewing-code` | Triage-first code review of implemented code / a PR / a diff |
| `crafting-commits` | Rewrite branch commit history into clean conventional commits (human-gated) |

Each step is independently usable — you can enter at any point if the upstream
artifact already exists (e.g. run `reviewing-code` on any PR with no plan).

## Composes with superpowers

This pipeline is the **spine** — artifact-centric, Jira-native, resumable. The
[superpowers plugin](https://claude.com/plugins/superpowers) provides cross-cutting
discipline at key points (TDD Iron Law, debugging, verification, git worktrees, close-out).

**The superpowers plugin is a required dependency for the full pipeline.**

Install in Claude Code:
```
/plugin install superpowers@claude-plugins-official
```
Then re-run `./install.sh` here.

### Review tiers

The pipeline uses two complementary review layers, split to avoid self-preference bias:

| Tier | Who | Scope | When |
|---|---|---|---|
| **Self-review** | The producing skill checks its own output | *Objective / mechanical* checks only (placeholders, file coverage, format) — verifiable yes/no | Every artifact boundary; runs in both modes |
| **AI-as-judge** | Independent fresh-context subagent on a strong model | *Subjective* quality calls (scope, over-engineering, breaking changes, design) with BLOCKER/SHOULD-FIX/NIT severity gate | `reviewing-plan` (before code) · `reviewing-code` (after code) |

Self-review is cheap and always runs. AI-as-judge is expensive and targeted. The split exists because a producer judging its own subjective quality is the strongest failure mode in AI evaluation (self-preference bias).

### Mode contract

Every pipeline skill accepts an optional `auto` argument. **Collaborative is the default.**

| Behavior | Collaborative | Auto |
|---|---|---|
| Forward-progress pauses (approve plan, confirm test plan, triage scope) | Pause for human | Proceed on own judgment |
| Git writes (commit/push/merge/PR) | Human-initiated | **Never self-initiated** (invariant) |
| Destructive overwrite of existing PLAN/ticket file | Ask | **Ask** (invariant) |
| Judge halt (DO NOT PROCEED / FAIL verdict) | Halt | **Halt** (invariant) |
| Unresolvable ambiguity | Ask | **Ask** (invariant) |

`auto` means "no forward-progress pauses" — not "self-ship." The git boundary and judge halts are invariants in both modes.

### Recommended model tiers

Skills keep `model: inherit` (honoring your session model). Judge subagents are dispatched with a strong model at dispatch time — not pinned in brittle frontmatter.

| Step | Role | Recommended tier |
|---|---|---|
| `fetching-tickets`, `generating-tasks` | Mechanical / extraction | Any capable model |
| `planning-from-ticket`, `crafting-commits` | Reasoning + writing | Default session model |
| `implementing-tasks` | TDD cycle | Default session model |
| `reviewing-plan` judge subagent | Subjective quality judgment | **Strong model** (e.g. `claude-opus-4-8`) |
| `reviewing-code` check subagents | Subjective quality judgment | **Strong model** (e.g. `claude-opus-4-8`) |

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
| `crafting-commits` | Analyzes a branch and rewrites commit history using conventional commits (human-gated) |

## Installation

**Option A — Claude Code plugin (recommended):**

```shell
/plugin marketplace add mhihasan/coding-agent-skills
/plugin install coding-agent-skills@coding-agent-skills
```

**Option B — manual symlink (OpenCode, Cursor, any tool reading `~/.claude/skills/`):**

```bash
git clone git@github.com:mhihasan/coding-agent-skills.git
cd coding-agent-skills
./install.sh
```

`install.sh` symlinks all skills into `~/.claude/skills/`. Safe to re-run — existing symlinks are updated, real directories are never overwritten.

