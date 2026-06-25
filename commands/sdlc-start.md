---
name: sdlc-start
description: >
  Universal pipeline entry point. Use when starting any new work — accepts a
  free-form idea ("add dark mode"), a Jira ticket URL, a Jira key (PROJ-42),
  or a local ticket file path. Routes ideas to brainstorming and tickets to
  picking-up-task, then proceeds to planning-from-spec. Also use with no
  argument to resume in-progress work.
license: MIT
---

# /sdlc-start — Universal Pipeline Entry Point

Single entry point for all new work. Detects input type and routes accordingly.

## Mode

Parse the argument list for `auto`. **Collaborative is the default.**

```
/sdlc-start PROJ-42              → collaborative
/sdlc-start PROJ-42 auto         → auto
/sdlc-start "add dark mode" auto → auto
```

Store the resolved mode and **pass it to every downstream skill invocation** — `picking-up-task`, `planning-from-spec`, `generating-tasks`. No downstream skill defaults independently.

**What `auto` does not remove:**
- Human gate in `picking-up-task` (branch creation requires your approval)
- Human gate in `planning-from-spec` (plan review requires your approval)
- Resume prompt when multiple active tasks exist (you must pick which)

## Where You Sit in the Pipeline

```
[0] /sdlc-start         ← YOU ARE HERE
      │
      ├─ idea ──────────→ brainstorming → local-dev/specs/<slug>-design.md
      │                                                    │
      └─ ticket/key/file → picking-up-task → ticket file  │
                                                           ↓
[1] planning-from-spec  ← converges here
[2] generating-tasks
[3] reviewing-plan
[4] implementing-tasks
[5] reviewing-code
[6] crafting-commits
```

## Step 1 — Detect input type

Apply detection rules in order:

| Priority | Matches | Example | Routes to |
| --- | --- | --- | --- |
| 1 | Starts with `http://` or `https://` | `https://site.atlassian.net/browse/PROJ-42` | `picking-up-task` |
| 2 | Pattern `[A-Z]+-[0-9]+` | `PROJ-42` | `picking-up-task` |
| 3 | Path to a file that exists on disk | `local-dev/tickets/PROJ-42/PROJ-42.md` | `picking-up-task` |
| 4 | Any other non-empty string | `"add dark mode toggle"` | brainstorming |
| 5 | No argument | — | resume check (Step 2c) |

Detection is deterministic — no model judgment. If input is ambiguous between rules, ask before routing.

## Step 2a — Ticket path

Invoke `picking-up-task <argument> [auto]` — pass mode flag if set. Do not duplicate fetch, branch, or review gate logic — `picking-up-task` owns all of it.

After it completes and the user approves, write `.agentic-sdlc/active/<KEY>.md` (schema below). Then invoke `planning-from-spec <ticket-file> [auto]`.

## Step 2b — Idea path

Run the brainstorming dialogue yourself: ask clarifying questions one at a time, propose 2–3 approaches where the design is non-obvious, and write the output spec to `local-dev/specs/YYYY-MM-DD-<topic>-design.md`.

After the user approves the spec, derive a slug from the spec filename. Write `.agentic-sdlc/active/<slug>.md` (schema below). Then invoke `planning-from-spec <spec-file> [auto]`.

## Step 2c — Resume check (no argument)

Read `.agentic-sdlc/active/` at repo root.

**No active files** — ask for new input. Re-apply detection rules 1–4.

**One active file** — show the in-progress task and ask `continue? (yes / no / new)`:

```
In progress: PROJ-42 · implementing-tasks · "Task 3 — add toggle component"
Branch: feat/PROJ-42/add-dark-mode

Continue? (yes / no / new)
```

**Multiple active files** — list all, ask which to resume or whether to start new:

```
Active work:
  [1] PROJ-42 · implementing-tasks · "Task 3 — add toggle component"
  [2] PROJ-55 · planning-from-spec

Continue which? (1 / 2 / new)
```

When resuming, pass the stored mode (default collaborative unless `auto` was given at invocation).

## Step 3 — Converge at planning-from-spec

Both paths end at `planning-from-spec`. After it completes, continue with:

```
/generating-tasks <plan-file> [auto]
```

## Active state file schema

Each in-progress work item writes `.agentic-sdlc/active/<KEY>.md`. Updated by each pipeline skill as work advances. Deleted by `crafting-commits` on completion.

```markdown
key: PROJ-42
step: implementing-tasks
task: "Task 3 — add toggle component"
branch: feat/PROJ-42/add-dark-mode
ticket: local-dev/tickets/PROJ-42/PROJ-42.md
plan: local-dev/tickets/PROJ-42/PLAN-PROJ-42.md
```

| Field | Set by | Value |
| --- | --- | --- |
| `key` | `sdlc-start` / `picking-up-task` | Jira key or idea slug |
| `step` | each skill on completion | name of the next skill to run |
| `task` | `implementing-tasks` | current task description |
| `branch` | `picking-up-task` | git branch name |
| `ticket` | `sdlc-start` | path to ticket or spec file |
| `plan` | `planning-from-spec` | path to PLAN file |

## Entering the pipeline mid-way

If the upstream artifact already exists, invoke any skill directly — `/sdlc-start` is a convenience wrapper, not a gate:

```bash
/planning-from-spec local-dev/tickets/PROJ-42/PROJ-42.md
/generating-tasks   local-dev/tickets/PROJ-42/PLAN-PROJ-42.md
/reviewing-code                          # reviews current branch diff
```

## You Must NOT

- Duplicate ticket-fetching, branch-creation, or brainstorming logic — delegate entirely
- Proceed past a no-argument case without checking `.agentic-sdlc/active/` first
- Accept ambiguous input silently — ask when detection is uncertain between rules
- Invoke `planning-from-spec` before the upstream skill has completed and produced its output file
- Write to `.agentic-sdlc/active/` before the upstream skill completes and the user approves
