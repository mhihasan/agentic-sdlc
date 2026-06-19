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

## Where You Sit in the Pipeline

```
[0] /sdlc-start         ← YOU ARE HERE
      │
      ├─ idea ──────────→ superpowers:brainstorming → local-dev/specs/<slug>-design.md
      │                                                         │
      └─ ticket/key/file → picking-up-task → ticket file       │
                                                                ↓
[1] planning-from-spec  ← converges here
[2] generating-tasks
[3] reviewing-plan
[4] implementing-tasks
[5] reviewing-code
[6] crafting-commits
```

## Input Detection

Rules applied in order:

| Priority | Input | Example | Route |
| --- | --- | --- | --- |
| 1 | URL | `https://site.atlassian.net/browse/PROJ-42` | `picking-up-task` |
| 2 | Jira key | `PROJ-42` | `picking-up-task` |
| 3 | Local file (exists on disk) | `local-dev/tickets/PROJ-42/PROJ-42.md` | `picking-up-task` |
| 4 | Free-form text | `"add dark mode toggle"` | `superpowers:brainstorming` |
| 5 | No argument | — | Check `.agentic-sdlc/active/`, then ask |

**Detection logic:**

1. Starts with `http://` or `https://` → URL → `picking-up-task`
2. Matches pattern `[A-Z]+-[0-9]+` → Jira key → `picking-up-task`
3. Argument is a path to a file that exists on disk → local file → `picking-up-task`
4. Any other non-empty string → free-form idea → `superpowers:brainstorming`
5. No argument → resume check (see Resume Logic below)

## Resume Logic (no argument)

Read `.agentic-sdlc/active/` directory:

**Empty — no active work:**
Ask: "Starting a new task — do you have a Jira ticket or URL, or do you want to brainstorm an idea from scratch?"
Re-apply rules 1–4 to their answer.

**One active file:**

```
In progress: PROJ-42 · implementing-tasks · "Task 3 — add toggle component"
Branch: feat/PROJ-42/add-dark-mode

Continue? (yes / no / new)
```

On `yes`: invoke the skill named in `step:` with paths from `ticket:` and `plan:`.
On `no` or `new`: ask for new input, re-apply rules 1–4.

**Multiple active files:**

```
Active work:
  [1] PROJ-42 · implementing-tasks · "Task 3 — add toggle component"
      branch: feat/PROJ-42/add-dark-mode
  [2] PROJ-55 · planning-from-spec
      branch: fix/PROJ-55/null-pointer-payment

Continue which? (1 / 2 / new)
```

On number: resume that item.
On `new`: ask for new input.

## Ticket Path

Invoke `picking-up-task` with the argument verbatim:

```
Using picking-up-task skill with: <argument>
```

Do not duplicate fetch, branch, or review gate logic — `picking-up-task` owns all of it.

After `picking-up-task` completes and the user approves, write
`.agentic-sdlc/active/<KEY>.md`:

```markdown
key: PROJ-42
step: planning-from-spec
task:
branch: feat/PROJ-42/add-dark-mode
ticket: local-dev/tickets/PROJ-42/PROJ-42.md
plan:
```

Then invoke `planning-from-spec` with the ticket file path.

## Idea Path

Invoke `superpowers:brainstorming` with the free-form text, instructing it to
write its spec output to `local-dev/specs/` instead of the default path:

```
Using brainstorming skill — idea: "<argument>"
Spec output path: local-dev/specs/YYYY-MM-DD-<topic>-design.md
```

Do not re-implement the clarifying-question loop or design dialogue — the
brainstorming skill owns all of it.

After brainstorming completes and the user approves the spec, derive a slug
from the spec filename (e.g. `dark-mode-toggle` from
`2026-06-19-dark-mode-toggle-design.md`). Write
`.agentic-sdlc/active/<slug>.md`:

```markdown
key: idea-dark-mode-toggle
step: planning-from-spec
task:
branch:
ticket: local-dev/specs/2026-06-19-dark-mode-toggle-design.md
plan:
```

Then invoke `planning-from-spec` with the spec file path.

## After Both Paths Converge

Both paths end at `planning-from-spec`. After it completes, the pipeline
continues with:

```
/generating-tasks <plan-file>
```

## You Must NOT

- Duplicate ticket-fetching, branch-creation, or brainstorming logic — delegate entirely
- Proceed past a no-argument case without checking `.agentic-sdlc/active/` first
- Accept ambiguous input silently — if detection is uncertain between rules, ask
- Invoke `planning-from-spec` before the upstream skill has completed and produced its output file
- Write to `.agentic-sdlc/active/` before the upstream skill completes and the user approves
