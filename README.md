# coding-agent-skills

Generic engineering craft skills for AI coding assistants.

Book-grounded, employer-neutral, and reusable by any engineer. Works with
Claude Code, OpenCode, Cursor, and any tool that reads `~/.claude/skills/`.

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

```bash
git clone git@github.com:mhihasan/agent-skills.git
cd agent-skills
./install.sh
```

`install.sh` symlinks all skills into `~/.claude/skills/` (and any other
agent tool directories detected on your machine). Safe to re-run — existing
symlinks are updated, real directories are never overwritten.

