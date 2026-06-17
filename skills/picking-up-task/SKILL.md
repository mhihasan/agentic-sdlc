---
name: picking-up-task
description: Use when the user wants to start a new task — accepts a Jira ticket URL, Jira key, or local ticket file path. Triggers on "start task", "begin PROJ-42", "set up a branch for", "start working on PROJ-42". Do not trigger automatically.
model: inherit
color: cyan
---

# Start Task

Bootstrap a new task: fetch the ticket (if remote) and set up a clean branch — so you can jump straight into planning.

**Next step:** once the branch is ready, run `planning-from-ticket` on the ticket file.

## Where You Sit in the Pipeline

```
[1] start-task          ← YOU ARE HERE
[2] planning-from-ticket
[3] generating-tasks
[4] reviewing-plan
[5] implementing-tasks
[6] reviewing-code
[7] crafting-commits
```

## Input Detection

Accepts one required argument. Detect the source type:

| Input | Example | Action |
|---|---|---|
| Jira URL | `https://site.atlassian.net/browse/PROJ-42` | Extract key → invoke `fetching-tickets` skill |
| Jira key | `PROJ-42` | Invoke `fetching-tickets` skill |
| Local file | `./tickets/PROJ-42/PROJ-42.md` | Read file directly — no fetch |
| Anything else | `"add password reset"` | **STOP — reject immediately** |

**When input is unrecognized, say exactly this and do nothing else:**
> "I need a Jira ticket URL, Jira key (e.g. `PROJ-42`), or a local ticket file path to start a task. For work without a ticket, use `/planning-from-ticket` directly with a spec file."

**Do not:**
- Accept ad-hoc descriptions, even under time pressure
- Create a Jira ticket on the developer's behalf
- Find a creative workaround to proceed

The rejection is not negotiable. A branch without a ticket has no anchor for planning.

## Fetching the Ticket

When input is a Jira URL or key:

**REQUIRED:** Invoke the `fetching-tickets` skill. Do not call Jira APIs directly (no MCP calls, no curl). `fetching-tickets` owns all Jira fetch logic — custom field discovery, image download, self-review. Do not re-implement it here.

Once `fetching-tickets` completes, the ticket is at `tickets/PROJ-42/PROJ-42.md`.

## Workspace Setup

After the ticket is on disk (fetched or read from local file), set up the branch. This is **required** — do not skip it, do not hand off to `planning-from-ticket` before completing it.

### 1. Detect base branch

```bash
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
```

Show the result and ask the developer to confirm:
> "Base branch detected as `develop`. Branch off this, or a different one?"

Wait for confirmation. Do not assume.

### 2. Check for dirty working tree

```bash
git status --porcelain
```

If output is non-empty, **stop and ask**:
> "You have uncommitted changes on `<branch>`. Should I stash them, or would you prefer to handle this first?"

Do not proceed until the developer explicitly says to continue. Do not reassure them that worktrees are isolated and proceed anyway — get explicit confirmation.

### 3. Sync

```bash
git fetch origin
git checkout <base-branch>
git pull origin <base-branch>
```

### 4. Construct branch name

Pattern: `{type}/{ticket-key}/{slug}`

Examples: `feat/PROJ-42/add-user-auth`, `fix/PROJ-55/null-pointer-payment`

**Derive type from Jira issue type:**

| Jira issue type | Branch type |
|---|---|
| Bug | `fix` |
| Story, Task, Feature | `feat` |
| Sub-task | Inherit parent type, or ask |
| Anything else | Ask developer |

**Derive slug:** 2–4 word kebab-case from ticket title. Drop articles, prepositions, helper verbs. Keep core action and object. Only `[a-z0-9-]` characters.

**Confirm before creating:**
> "I'll create branch `feat/PROJ-42/add-user-auth` based off `develop` — sound good?"

Wait for confirmation.

### 5. Create branch (default)

```bash
git checkout -b feat/PROJ-42/add-user-auth
```

**No push.** Branch stays local. `superpowers:finishing-a-development-branch` handles push and PR.

### `--worktree` flag

When `--worktree` is passed:

```
/start-task PROJ-42 --worktree
```

After confirming the branch name, invoke `superpowers:using-git-worktrees` instead of `git checkout -b`. Pass the constructed branch name to it. All worktree logic is owned by that skill.

Use `--worktree` when you have in-flight work on another branch, are dispatching an agent to implement in parallel, or need full isolation between concurrent tasks.

## Handoff

Once the branch (or worktree) is ready, print exactly this and stop:

```
Branch `feat/PROJ-42/add-user-auth` ready (based off `develop`).
Ticket saved to `tickets/PROJ-42/PROJ-42.md`.

Next: /planning-from-ticket tickets/PROJ-42/PROJ-42.md
```

No push commands. No extra guidance. No reminders.

## You Must NOT

- **Skip branch creation.** Fetching the ticket and handing off to `planning-from-ticket` without creating a branch is wrong. Branch creation is part of this skill's job.
- **Accept ad-hoc descriptions.** Not even under time pressure. Not even if the developer says "just figure it out." Reject and redirect.
- **Create a Jira ticket.** That is not in scope. The developer must provide an existing ticket or file.
- **Call Jira APIs directly.** Delegate to `fetching-tickets`. No MCP Atlassian calls, no curl to Jira REST.
- **Proceed past a dirty working tree without explicit confirmation.** Informing the developer that worktrees are isolated is not the same as getting confirmation — ask and wait.
- **Push the branch.** That is `superpowers:finishing-a-development-branch`'s job.
- **Trigger automatically.** This skill is opt-in only.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Fetching the ticket and stopping — no branch created | Branch creation is mandatory. Always complete workspace setup. |
| Accepting "add password reset" as input | Reject immediately with the exact wording above. No creative workarounds. |
| Calling `mcp__claude_ai_Atlassian__getJiraIssue` directly | Invoke `fetching-tickets` skill instead. |
| Reassuring developer about worktree isolation, then proceeding | Get explicit "go ahead" before any git operation on a dirty tree. |
| Pushing the new branch | Don't. `superpowers:finishing-a-development-branch` handles it. |
