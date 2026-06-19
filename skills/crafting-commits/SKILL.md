---
name: crafting-commits
description: >
  Use when the user wants to clean up commits, rewrite git history, squash messy commits, apply conventional commits, or prepare a branch for PR review. Triggers on "clean up my commits", "fix my commit history", "prepare commits for PR", "commits are a mess", or when a user shares a diff or branch and asks how to structure commits for a reviewer.
model: claude-haiku-4-5  # Claude Code only; other tools use their session model
color: lavender
license: MIT
---

# crafting-commits

Analyzes changes on a feature branch, evaluates the semantic quality of existing commits, and produces a clean conventional-commit history that helps reviewers navigate a PR.

**No auto-commit:** This skill proposes the rewritten history and prints the exact git commands. The developer reviews and runs all git operations — this skill never self-initiates `git commit`, `git reset`, `git push`, or `git merge`. The human-review gate in Step 5 is mandatory and cannot be skipped.

**Modes:** Check the arguments for `auto`; **collaborative is the default.** In collaborative mode you produce the plan, present it in chat, and execute on confirmation (Step 6). In `auto` mode you produce and self-review the plan with no conversational pauses, then **stop at the execution boundary** — `auto` does **not** relax the git gate. Even in `auto`, the developer triggers every git command. `auto` only removes the chit-chat, never the Step 5 gate. In both modes, the plan is presented in chat for human approval before any git operations run.

**`auto` invariants:** No self-commit (the bash script is presented, not executed). No self-push. Halt if the branch cannot be analyzed (e.g., merge conflicts). Ask on unresolvable ambiguity.

---

## Input Validation

Before doing anything, verify:

| Check | Action on failure |
|---|---|
| Inside a git repo | Stop — tell the developer this skill requires a git repository |
| Current branch is not the default branch (`main` / `master` / `develop`) | Stop — commits on the default branch should not be rewritten |
| At least one commit ahead of the target branch | Stop — nothing to rewrite; tell the developer |
| No active rebase or merge in progress (`git status`) | Stop — resolve the rebase/merge first |
| `REVIEW-LOG.md` has `reviewing-code` stamp | Halt — "This step requires a human review stamp from `reviewing-code`. Run `/reviewing-code` first and approve the review before crafting commits." Note `AUTO` stamps with a visibility note but do not block. |

---

## Workflow

### Step 1 — Gather context

Run these commands and collect all output before analysis:

```bash
# 1. Confirm we're in a git repo and get current branch
git rev-parse --abbrev-ref HEAD

# 2. Fetch target branch (always fetch fresh)
git fetch origin <target_branch>

# 3. Find the merge base
git merge-base HEAD origin/<target_branch>

# 4. Full diff from merge base to HEAD (stat + patch)
git diff <merge_base>..HEAD --stat
git diff <merge_base>..HEAD

# 5. Existing commits since merge base (with full messages)
git log <merge_base>..HEAD --pretty=format:"%H %s%n%b" --reverse

# 6. List of files changed
git diff <merge_base>..HEAD --name-only
```

If the user hasn't provided a target branch, ask for it before proceeding.

---

### Step 1.5 — Rebase onto target branch

Before evaluating commits, rebase onto `origin/<target_branch>` so the commit history reflects the final state against an up-to-date base:

```bash
git rebase origin/<target_branch>
```

**If rebase conflicts:** Stop immediately. Report the conflicting files and say:

> "Rebase conflict on `<file>`. Resolve the conflict, run `git rebase --continue`, then re-run `/crafting-commits`."

Do not proceed past a rebase conflict — commit evaluation on a partial rebase is meaningless.

**If rebase succeeds:** Re-run the diff and log commands from Step 1 to get the updated merge base and commit list before proceeding.

---

### Step 2 — Evaluate existing commits

For each existing commit, assess:

**Keep as-is** if ALL of:
- Follows conventional commit format: `type(scope): description`
- Type is valid (see reference below)
- Description is specific and semantic — not "fix stuff", "wip", "updates", "misc"
- Scope is meaningful (module, component, or feature name — not a filename)
- The commit is atomic: it changes one logical thing

**Rewrite or merge** if ANY of:
- Missing type prefix
- Vague or non-semantic description
- Multiple unrelated changes bundled together
- Scope is a filename, ticket number, or absent when it should be present
- Message is a draft placeholder (wip, temp, fixup, etc.)

**Split** if:
- One commit touches logically unrelated areas (e.g. auth changes + UI styling + migration)

Record your evaluation per commit. This feeds into Step 3.

---

### Step 3 — Design the clean commit plan

Build a new commit sequence from the diff. The goal is a history a reviewer can walk linearly and understand.

**Splitting heuristics (in priority order):**
1. **By concern type first** — separate refactors/renames from feature additions from bug fixes from tests from config/infra changes. A reviewer should never be surprised by what a commit touches.
2. **By module/component/feature** — within a concern type, group by where the change lives. Use the directory structure and import graph as signals.
3. **Avoid micro-commits** — don't split a 3-line change into its own commit unless it's genuinely distinct (e.g. a schema migration that must precede the feature code).
4. **Test commits stay with their subject** — unless the test suite is large enough to be its own commit, keep tests in the same commit as the code they test. If splitting, put tests after the implementation commit they cover.

**Commit ordering:**
- Infrastructure / config changes first
- Data model / schema changes second
- Core logic / domain changes third
- Integration / wiring changes fourth
- UI / presentation changes fifth
- Test-only additions last (if separated)
- Cleanup / formatting / docs last

**Conventional commit format:**
```
type(scope): short imperative description

Optional body: why this change was made, not what (the diff shows what).
Only include a body if the reason isn't obvious.
```

See `references/conventional-commits.md` for valid types and scope guidance.

---

### Step 4 — Self-review the commit plan

Before presenting the plan, review it against this checklist and fix any failure. These are objective checks — they run in **both** modes.

| Check | Pass condition |
|---|---|
| File reconciliation | Every changed file from the diff appears in exactly one proposed commit — no dropped files, none duplicated across commits |
| Concern separation | No commit mixes unrelated concerns (refactor + feature + fix split apart) |
| Ordering | Follows the infra → model → logic → integration → UI → tests sequence from Step 3 |
| Format | Every message is valid `type(scope): description` with a meaningful (non-filename) scope |
| Linear history | Merge commits excluded; binary/generated files flagged |
| Script matches | The execution script's `git add` file list reconciles exactly with the diff's file list |

---

### Step 5 — Present plan in chat (human gate)

Present the full plan directly in chat. **Do not write it to a file.** Use this structure:

````markdown
## Commit Plan — <branch> → <target_branch>

Merge base: `<hash>`
Files changed: <N> | Existing commits: <N> | Keeping: <N> | Rewriting: <N>

---

### Existing Commit Assessment

| Commit | Short SHA | Verdict | Reason |
|--------|-----------|---------|--------|
| `feat: add login` | `abc1234` | keep | Conventional, atomic, semantic |
| `wip stuff` | `def5678` | rewrite | Vague, mixed concerns |

---

### Proposed Commit Sequence

**Commit 1 of N — `type(scope): description`**
Why: <one sentence explaining why this is a logical unit>
Files: `path/to/file.ts`, `path/to/other.ts`

**Commit 2 of N — `type(scope): description`**
...

---

### Execution Script

> Review the commits above before running. This script rewrites history.
> If you have a remote branch, you will need to force-push: `git push --force-with-lease`

```bash
#!/usr/bin/env bash
set -e

MERGE_BASE="<hash>"

git reset "$MERGE_BASE"

git add <files>
git commit -m "type(scope): description"

git add <files>
git commit -m "type(scope): description"

echo "Done. Review with: git log --oneline"
echo "Force push when ready: git push --force-with-lease"
```
````

After presenting the plan, say:

> "Review the proposed commits and execution script above. Tell me to proceed, or give me feedback and I'll revise."

On developer confirmation (`approve` or equivalent explicit go-ahead), before running the execution script, write (or upsert) in `REVIEW-LOG.md` (same directory as the plan/ticket file, or the repo root if no ticket directory is in context):
```
> **Human Review:** APPROVED — YYYY-MM-DD — crafting-commits
```

**Auto mode:** Step 5 still halts for the developer — `auto` does not relax the git gate (as documented in the skill header). Write the stamp when the developer confirms, same as collaborative.

**Do not run any git reset or commit commands until the user explicitly confirms.**

---

### Step 6 — Execute (on confirmation)

Once the user confirms:
1. Run the execution script
2. Show `git log --oneline` output after completion
3. Remind user to force-push if the branch has a remote: `git push --force-with-lease`

If any step fails (merge conflict, wrong file state, etc.), stop immediately and report the exact error before attempting recovery.

After successful execution, say:

> "Commits are clean. Run `superpowers:finishing-a-development-branch` when you're ready to merge, open a PR, or discard the branch. If opening a PR, always create it as a draft (`gh pr create --draft`)."

---

## Edge Cases

**No existing commits (fresh branch with uncommitted changes):**
Skip the assessment table. Go straight to designing the commit plan from the diff.

**All existing commits are clean:**
Show the assessment table with all keep verdicts. Since no rewrite is needed, skip Steps 5–6 (no execution script to run). Say:

> "All commits are already clean — no rewrite needed. Ready to proceed? `/superpowers:finishing-a-development-branch` (yes/no)"

On yes, invoke `superpowers:finishing-a-development-branch`.

Do not write a `REVIEW-LOG.md` stamp — there is nothing to approve.

**Merge commits in the range:**
Note them in the assessment. Do not include merge commits in the rewritten history — the clean sequence should be linear.

**Binary files or large generated files:**
Flag them explicitly in the plan. Ask the user whether to include them in a dedicated commit or whether they're already gitignored.

**Monorepo:**
Use the top-level package/app/service directory as the scope. E.g. `feat(api): ...`, `fix(web): ...`, `chore(infra): ...`.

---

## Reference files

- `references/conventional-commits.md` — Valid types, scope guidance, examples
