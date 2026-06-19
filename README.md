# agentic-sdlc

A gate-enforced SDLC pipeline for AI coding agents. Ticket in, reviewed PR out — with an independent AI judge at every artifact boundary before you ship.

> *Review early, review often.* A flaw surfaced before coding costs nothing. The same flaw after five tasks can invalidate all five.

Works with Claude Code, OpenCode, Cursor, and GitHub Copilot.

## Agentic Coding Workflow

```mermaid
flowchart TD
    classDef pipe fill:#dbeafe,stroke:#3b82f6,color:#1e3a5f
    classDef judge fill:#fef3c7,stroke:#d97706,color:#78350f
    classDef sp fill:#dcfce7,stroke:#16a34a,color:#14532d
    classDef gate fill:#fed7aa,stroke:#ea580c,color:#7c2d12

    ST(["① pick up ticket\nset up a branch\n/picking-up-task"]):::sp
    PFT["② read the codebase\nwrite an implementation plan\n/planning-from-ticket"]:::pipe
    HG0{{"✋ you approve the plan\nor ask to revise it"}}:::gate
    GT["③ break the plan into\nsmall testable tasks\n/generating-tasks"]:::pipe
    HG1{{"✋ you approve the tasks\nor ask to revise them"}}:::gate
    RP{"④ AI reviews the plan\nbefore any code is written\n/reviewing-plan"}:::judge
    RPR["challenge or accept each finding\nupdate the plan\n/receiving-plan-review"]:::pipe
    HG2{{"✋ you approve the plan\nor ask to revise it"}}:::gate
    IT["⑤ write tests first, then code\ntask by task\n/implementing-tasks"]:::pipe
    RC{"⑥ AI reviews the code\nindependent of who wrote it\n/reviewing-code"}:::judge
    RCR["challenge or accept each finding\nfix the code"]:::sp
    HG3{{"✋ you approve the code\nor ask to fix it"}}:::gate
    CC(["⑦ clean up the commit history\nready to merge\n/crafting-commits"]):::sp

    ST --> PFT --> HG0 --> GT --> HG1 --> RP
    RP -->|PROCEED| HG2
    RP -->|DO NOT PROCEED| RPR
    RPR --> RP
    HG2 --> IT
    IT -->|all tasks done| RC
    RC -->|PASS| HG3
    RC -->|FAIL| RCR
    RCR --> RC
    HG3 --> CC
```

## Design Principles

**Review early, review often.** A flaw before coding costs nothing. The same flaw after five tasks can invalidate all five.

**Two review tiers, split by role.** Self-review handles mechanical checks: cheap, always runs, catches placeholders and format issues. AI-as-judge handles subjective quality calls: fresh context, targeted, catches design and scope problems. Neither replaces the other.

**Human gates are not optional.** Every AI verdict requires your approval before the next step starts. `REVIEW-LOG.md` is the audit trail.

**No self-preference bias.** Judge subagents run in a fresh context with no access to the producing session's framing or justifications.

**Auto mode removes pauses, not safeguards.** Git boundaries and judge halts hold in both modes. `auto` is a speed setting, not a bypass.

**Enter at any step.** Every skill is independently usable. Start wherever the upstream artifact already exists.

## Use cases

**Full pipeline** — ticket in, reviewed code out. Enter at any step if the upstream artifact already exists.

**Standalone review** — review any branch or PR without a plan file. Domain-filtered diff, triage-first report with BLOCKER / SHOULD-FIX / NIT severity.

**Architecture docs** — generate a design document from an existing codebase.

## Installation

**One-liner (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/mhihasan/agentic-sdlc/main/install.sh | bash
```

Installs for all tools (Claude Code, Copilot) at user scope. Skills land in `~/.claude/skills/` and `~/.copilot/skills/`. Re-run the same command to update.

**Options:**

```bash
# Claude only
curl -fsSL https://raw.githubusercontent.com/mhihasan/agentic-sdlc/main/install.sh | bash -s -- --tool=claude

# Copilot only
curl -fsSL https://raw.githubusercontent.com/mhihasan/agentic-sdlc/main/install.sh | bash -s -- --tool=copilot

# Project-scoped (Claude only)
curl -fsSL https://raw.githubusercontent.com/mhihasan/agentic-sdlc/main/install.sh | bash -s -- --scope=project --tool=claude /path/to/your-project
```

**Local clone (if you prefer):**

```bash
git clone git@github.com:mhihasan/agentic-sdlc.git
cd agentic-sdlc

# User scope — available in all projects
./install.sh --scope=user --tool=claude     # → ~/.claude/skills/   (Claude Code, OpenCode, Cursor)
./install.sh --scope=user --tool=copilot    # → ~/.copilot/skills/  (GitHub Copilot)
./install.sh --scope=user --tool=all        # → both

# Project scope — current project only
./install.sh --scope=project --tool=claude  /path/to/project   # → .claude/skills/
./install.sh --scope=project --tool=copilot /path/to/project   # → .github/skills/
./install.sh --scope=project --tool=all     /path/to/project   # → both
```

Safe to re-run: existing symlinks are updated, real directories are never overwritten.

## Quickstart

**Option A: full pipeline from a Jira ticket**

```bash
/picking-up-task https://yoursite.atlassian.net/browse/PROJ-123

# Each skill tells you what to run next. The full sequence:
# /planning-from-ticket → /generating-tasks → /reviewing-plan
# → /implementing-tasks → /reviewing-code → /crafting-commits
```

Each skill is independently usable — enter at any point if the upstream artifact already exists.

---

**Option B: review any branch right now**

```
/reviewing-code
```

Reviews your staged diff by default, or pass `branch`, a PR number, or a diff file. Dispatches parallel AI judges, filters the diff by domain, and produces a triage-first report. No plan file needed.

## Skills Reference

Per-skill input/output tables, flags, usage examples, and flow details: [SKILLS.md](docs/SKILLS.md).

## Collaborative vs auto mode

Every pipeline skill accepts an optional `auto` argument. **Collaborative is the default.**

| | Collaborative | Auto |
|---|---|---|
| Forward-progress pauses (approve plan, confirm test plan, triage scope) | Pause for human | Proceed on own judgment |
| Git writes (commit / push / merge / PR) | Human-initiated | **Never self-initiated** |
| Destructive overwrite of existing PLAN file | Ask | **Ask** |
| Judge halt (DO NOT PROCEED / FAIL verdict) | Halt | **Halt** |
| Unresolvable ambiguity | Ask | **Ask** |

`auto` removes conversational pauses but does not remove safeguards. Git boundaries and judge halts are invariants in both modes.

**`auto` does not chain skills.** Even in auto mode, each skill is a discrete command. `/picking-up-task PROJ-123` fetches the ticket, sets up the branch, and stops. You decide when to invoke the next step.

## Review tiers

| Tier | Who | Scope | When |
|---|---|---|---|
| **Self-review** | The producing skill checks its own output | Objective, mechanical checks only (placeholders, file coverage, format): verifiable yes/no | Every artifact boundary; runs in both modes |
| **AI-as-judge** | Independent fresh-context subagent on a strong model | Subjective quality calls (scope, over-engineering, breaking changes, design) with BLOCKER/SHOULD-FIX/NIT severity gate | [`reviewing-plan`](skills/reviewing-plan/SKILL.md) (before code) · [`reviewing-code`](skills/reviewing-code/SKILL.md) (after code) |

Self-review is cheap and always runs. AI-as-judge is targeted. The split exists because a producer evaluating its own subjective quality is the primary failure mode in AI evaluation.

## Model selection

In Claude Code, each skill pins its own model — you don't need to switch manually. Other tools (OpenCode, Cursor, Copilot) ignore the `model` field and use their session model.

| Skill | Model | Why |
|---|---|---|
| [`picking-up-task`](skills/picking-up-task/SKILL.md) | Haiku | Mechanical: fetch ticket, create file |
| [`generating-tasks`](skills/generating-tasks/SKILL.md) | Sonnet | Task decomposition, no deep design judgment needed |
| [`implementing-tasks`](skills/implementing-tasks/SKILL.md) | Sonnet | TDD cycle needs solid reasoning, not Opus-level |
| [`crafting-commits`](skills/crafting-commits/SKILL.md) | Haiku | Mechanical: read history, format commits |
| [`planning-from-ticket`](skills/planning-from-ticket/SKILL.md) | Opus | Highest-stakes reasoning: codebase exploration + design decisions |
| [`reviewing-plan`](skills/reviewing-plan/SKILL.md) | Opus | Subjective judgment before any code is written |
| [`reviewing-code`](skills/reviewing-code/SKILL.md) | Opus | Where self-preference bias gets caught — model quality matters most here |
