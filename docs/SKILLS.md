# Skills Reference

## [`picking-up-task`](../skills/picking-up-task/SKILL.md)

Fetches a Jira ticket (or reads a local file) and sets up a git branch — the single entry point for starting any new task.

| | |
|---|---|
| **Input** | Jira ticket URL, Jira key (`PROJ-123`), or local file path |
| **Output** | `local-dev/tickets/PROJ-123/PROJ-123.md` + branch `{type}/PROJ-123/{slug}` |
| **Flags** | `--worktree` — create a git worktree instead of a plain branch |
| **Requires** | `JIRA_EMAIL` and `JIRA_API_TOKEN` env vars (for Jira inputs) |

```bash
/picking-up-task https://yoursite.atlassian.net/browse/PROJ-123
/picking-up-task PROJ-123
/picking-up-task PROJ-123 --worktree
/picking-up-task ./local-dev/tickets/PROJ-123/PROJ-123.md
```

---

## [`planning-from-spec`](../skills/planning-from-spec/SKILL.md)

Reads a local ticket or spec file, explores the codebase, surfaces decisions, and writes a `PLAN-<KEY>.md` beside the ticket.

| | |
|---|---|
| **Input** | Local ticket or spec file (`local-dev/tickets/PROJ-123/PROJ-123.md`) |
| **Output** | `local-dev/tickets/PROJ-123/PLAN-PROJ-123.md` |
| **Auto mode** | Supported, picks recommended option and skips chat presentation |

```bash
/planning-from-spec local-dev/tickets/PROJ-123/PROJ-123.md
/planning-from-spec local-dev/tickets/PROJ-123/PROJ-123.md auto
```

---

## [`generating-tasks`](../skills/generating-tasks/SKILL.md)

Appends TDD-ready task specs into an existing plan file. Each task includes a test plan, scope boundaries, and files expected.

| | |
|---|---|
| **Input** | Plan file (`local-dev/tickets/PROJ-123/PLAN-PROJ-123.md`) |
| **Output** | `# Tasks` section appended to the same plan file |
| **Auto mode** | Supported, drafts and appends without pausing |
| **Writes** | `generating-tasks` stamp in `REVIEW-LOG.md` after you approve |

```bash
/generating-tasks local-dev/tickets/PROJ-123/PLAN-PROJ-123.md
/generating-tasks local-dev/tickets/PROJ-123/PLAN-PROJ-123.md auto
```

---

## [`reviewing-plan`](../skills/reviewing-plan/SKILL.md)

AI-as-judge that evaluates the plan + tasks against the ticket before any code is written. Dispatches a fresh-context subagent to avoid self-preference bias.

| | |
|---|---|
| **Input** | Plan file with tasks (reads the ticket file alongside it automatically) |
| **Output** | Verdict report with BLOCKER/SHOULD-FIX/NIT findings; appends `> **Plan Review:** PROCEED — YYYY-MM-DD` marker to the plan on pass |
| **Auto mode** | Supported, appends verdict marker automatically; on DO NOT PROCEED automatically invokes `receiving-plan-review`, fixes the plan, and re-runs review |
| **Verdict** | `PROCEED` / `PROCEED WITH CHANGES` / `DO NOT PROCEED` |
| **Checks** | `generating-tasks` stamp in `REVIEW-LOG.md` |
| **Writes** | `reviewing-plan` stamp in `REVIEW-LOG.md` after you approve |

```bash
/reviewing-plan local-dev/tickets/PROJ-123/PLAN-PROJ-123.md
```

`implementing-tasks` refuses to start without a PROCEED marker in the plan file.

**If the verdict is DO NOT PROCEED (collaborative mode):**

1. Use `receiving-plan-review` to work through the findings:
   - Verify each finding against the ticket and codebase before accepting it
   - Push back with evidence if a finding is wrong
   - Fix only what holds up under scrutiny
2. Re-run `/reviewing-plan` — fresh verdict against the updated plan
3. Once verdict is PROCEED, continue to `implementing-tasks`

---

## [`receiving-plan-review`](../skills/receiving-plan-review/SKILL.md)

Works through `reviewing-plan` findings. Verifies each one against the ticket and codebase before accepting it — pushes back on wrong findings, fixes genuine ones.

| | |
|---|---|
| **Input** | Plan review findings (from `reviewing-plan` output) + ticket file + plan file |
| **Output** | Per-finding verdict (accept / push back) with targeted plan edits; prompt to re-run `reviewing-plan` |

```bash
# Invoke after a DO NOT PROCEED or PROCEED WITH CHANGES verdict
/receiving-plan-review
```

---

## [`implementing-tasks`](../skills/implementing-tasks/SKILL.md)

Implements a task spec via TDD. Auto-selects `testing-pytest` (Python) or `testing-vitest` (React) and enforces RED → GREEN → REFACTOR per test.

| | |
|---|---|
| **Input** | Plan file + task number (`T1`, `T2`, …) |
| **Output** | Working code with passing tests; task status updated to `done` in plan file |
| **Auto mode** | Supported, runs full TDD cycle without pausing; stops on unexpected failures |
| **Requires** | PROCEED verdict marker in plan file |
| **Checks** | `reviewing-plan` stamp in `REVIEW-LOG.md` |

```bash
/implementing-tasks local-dev/tickets/PROJ-123/PLAN-PROJ-123.md        # collaborative, pauses for approval
/implementing-tasks local-dev/tickets/PROJ-123/PLAN-PROJ-123.md auto   # auto, no forward-progress pauses
```

Never self-commits or pushes. Code is left staged/unstaged for you to review.

---

## [`reviewing-code`](../skills/reviewing-code/SKILL.md)

Triage-first code review. Dispatches parallel AI judges filtered by domain (TypeScript agent sees `.tsx/.jsx`, DB agent sees query/model files, etc.).

| | |
|---|---|
| **Input** | Branch name, PR number, staged diff, or diff file — defaults to staged diff if no target given; optionally a plan/spec file for pipeline context (ticket file read automatically if found beside the plan) |
| **Output** | `CODE-REVIEW-{identifier}.md` with severity-tiered findings (🔴 Critical → ⚠️ Manual) |
| **Auto mode** | Supported, skips triage confirmation and proceeds directly to review; on FAIL automatically fixes findings and re-runs review |
| **Verdict** | Pipeline: `PASS` / `PASS WITH FINDINGS` / `FAIL` · General: `APPROVE` / `APPROVE WITH COMMENTS` / `REQUEST CHANGES` |
| **Writes** | `reviewing-code` stamp in `REVIEW-LOG.md` after you approve |

```bash
/reviewing-code                                                              # review staged diff (default)
/reviewing-code branch                                                       # review current branch against main
/reviewing-code PR-456                                                       # review a specific PR
/reviewing-code branch local-dev/tickets/PROJ-123/PLAN-PROJ-123.md          # pipeline mode with plan context
```

**If the verdict is FAIL (collaborative mode):**

1. Work through the findings:
   - Verify each finding against the actual code before accepting it
   - Push back with reasoning if a finding is wrong
   - Fix only what holds up under scrutiny
2. Re-run `/reviewing-code` — it produces a delta report against the original, not a full re-review
3. Once verdict is PASS, continue to `crafting-commits`

---

## [`crafting-commits`](../skills/crafting-commits/SKILL.md)

Rewrites a messy branch history into clean conventional commits. Presents the plan in chat for approval, never runs git commands without your confirmation.

| | |
|---|---|
| **Input** | Current git branch (reads history automatically) |
| **Output** | Commit plan presented in chat with proposed sequence and ready-to-run bash script |
| **Auto mode** | Supported, produces plan without pausing; always halts before executing any git commands |
| **Checks** | `reviewing-code` stamp in `REVIEW-LOG.md` |

```bash
/crafting-commits
/crafting-commits auto
```

Review the plan in chat, confirm, and the script runs.

---

## [`testing-pytest`](../skills/testing-pytest/SKILL.md)

Expert pytest coach. Enforces six strict rules on every test written or reviewed.

| | |
|---|---|
| **Input** | Python source file or existing test file |
| **Output** | Tests written or reviewed against fixed rule set |

```bash
/testing-pytest
```

---

## [`testing-vitest`](../skills/testing-vitest/SKILL.md)

Expert Vitest coach for React + TypeScript projects. Tests behavior, not implementation.

| | |
|---|---|
| **Input** | React/TypeScript source file or existing test file |
| **Output** | Tests written or reviewed following sociable, DAMP, behavior-first principles |

```bash
/testing-vitest
```

---

## [`fetching-tickets`](../skills/fetching-tickets/SKILL.md)

Standalone Jira ticket fetcher. Normally invoked by `picking-up-task` — use directly only if the branch is already set up.

| | |
|---|---|
| **Input** | Jira ticket URL or key |
| **Output** | `local-dev/tickets/PROJ-123/PROJ-123.md` with all assets downloaded locally |
| **Requires** | `JIRA_EMAIL` and `JIRA_API_TOKEN` env vars |

```bash
/fetching-tickets PROJ-123
/fetching-tickets https://yoursite.atlassian.net/browse/PROJ-123
```
