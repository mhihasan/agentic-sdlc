---
name: picking-up-task
description: Use when the user wants to start a new task — accepts a Jira ticket URL, Jira key, or local ticket file path. Triggers on "start task", "begin PROJ-42", "set up a branch for", "start working on PROJ-42".
model: claude-haiku-4-5  # Claude Code only; other tools use their session model
color: cyan
license: MIT
---

# picking-up-task

Bootstrap a new task: fetch the ticket (if remote) and set up a clean branch — so you can jump straight into planning.

**Next step:** once the branch is ready, run `planning-from-ticket` on the ticket file.

## Where You Sit in the Pipeline

```
[1] picking-up-task     ← YOU ARE HERE
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
| Local file | `./$ARTIFACTS_ROOT/PROJ-42/PROJ-42.md` | Read file directly — no fetch |
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

Once `fetching-tickets` completes, the ticket is at `$ARTIFACTS_ROOT/PROJ-42/PROJ-42.md`.

## Workspace Setup

After the ticket is on disk (fetched or read from local file), set up the branch. This is **required** — do not skip it, do not hand off to `planning-from-ticket` before completing it.

### 0. Resolve artifacts root

Check for `.claude/artifacts-root` in the project root:

```bash
cat .claude/artifacts-root 2>/dev/null
```

- **If the file exists:** use its value as `ARTIFACTS_ROOT` for all path construction this run (e.g. `local-dev/tickets`).
- **If the file does not exist:** ask the developer:

  > "Where should ticket and plan files go? Press Enter for the default.
  > Default: `local-dev/tickets`"

  Write their answer (or the default) to `.claude/artifacts-root`:

  ```bash
  echo "local-dev/tickets" > .claude/artifacts-root   # or their chosen value
  ```

  Then tell them:
  > "Saved to `.claude/artifacts-root`. Commit this file to share the setting with your team, or add it to `.gitignore` to keep it local:
  > ```bash
  > echo '.claude/artifacts-root' >> .gitignore
  > ```"

**One-time setup (first run only):** Ensure `local-dev/` is excluded from git globally so ticket and plan files are never accidentally committed to any project.

Check whether `local-dev` is already in the global gitignore:
```bash
GITIGNORE_FILE="$(git config --global core.excludesfile 2>/dev/null || echo ~/.gitignore_global)"
grep -q 'local-dev' "$GITIGNORE_FILE" 2>/dev/null \
  && echo "already excluded" \
  || echo "local-dev/" >> "$GITIGNORE_FILE"
```
If the global excludes file does not exist yet, create it:
```bash
echo "local-dev/" >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

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
/picking-up-task PROJ-42 --worktree
```

After confirming the branch name, invoke `superpowers:using-git-worktrees` instead of `git checkout -b`. Pass the constructed branch name to it. All worktree logic is owned by that skill.

Use `--worktree` when you have in-flight work on another branch, are dispatching an agent to implement in parallel, or need full isolation between concurrent tasks.

## Handoff

Once the branch (or worktree) is ready, print the ticket summary and open the Review Gate.

### Review Gate

Present to the developer:

```
Branch `feat/PROJ-42/add-user-auth` ready (based off `develop`).
Ticket saved to `$ARTIFACTS_ROOT/PROJ-42/PROJ-42.md`.

Review the ticket file above to confirm its content is correct before planning starts.
Type `approve` to stamp it and proceed, or describe what needs fixing.
```

**Collaborative mode (default):** Wait for the developer to type `approve`. Any other response is a change request — address it and re-present. On `approve`:

1. Write (or upsert) this line in `$ARTIFACTS_ROOT/PROJ-42/REVIEW-LOG.md` (create the file if absent, overwrite any existing `picking-up-task` line if present):
   ```
   > **Human Review:** APPROVED — YYYY-MM-DD — picking-up-task
   ```
2. Print:
   ```
   Stamped REVIEW-LOG.md. Next: /planning-from-ticket $ARTIFACTS_ROOT/PROJ-42/PROJ-42.md
   ```

**Auto mode:** Write the stamp automatically with `AUTO`:
```
> **Human Review:** AUTO — YYYY-MM-DD — picking-up-task
```
Then print: `Next: /planning-from-ticket $ARTIFACTS_ROOT/PROJ-42/PROJ-42.md`

No push commands. No extra guidance beyond the next-step line.

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
