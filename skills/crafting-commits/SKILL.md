---
name: crafting-commits
description: >
  Analyze a feature branch against a target branch, evaluate existing commit quality, and produce a clean conventional-commit history plan with a human-review step before any git commands run. Use this skill whenever the user wants to clean up commits, rewrite git history, apply conventional commits, squash messy commits, prepare a branch for PR review, or says things like "clean up my commits", "fix my commit history", "rewrite commits", "prepare commits for PR", "conventional commits", "squash and rewrite", "tidy my branch", or "commits are a mess". Also trigger when a user shares a diff or branch and asks how to structure commits for a reviewer.
---

# crafting-commits

Analyzes changes on a feature branch, evaluates the semantic quality of existing commits, and produces a clean conventional-commit history that helps reviewers navigate a PR. Outputs a human-readable plan (markdown) for approval before touching anything.

**No auto-commit:** This skill proposes the rewritten history and prints the exact git commands. The developer reviews and runs all git operations — this skill never self-initiates `git commit`, `git reset`, `git push`, or `git merge`. The human-review gate in Step 5 is mandatory and cannot be skipped.

**Modes:** Check the arguments for `auto`; **collaborative is the default.** In collaborative mode you produce the plan, present it, and execute on confirmation (Step 6). In `auto` mode you produce and self-review the plan with no conversational pauses, then **stop at the execution boundary** — `auto` does **not** relax the git gate. Even in `auto`, the developer triggers every git command. `auto` only removes the chit-chat, never the Step 5 gate.

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

### Step 4 — Produce the plan document

**Determine the output path before writing:**

1. Check the conversation for a Jira ticket number (patterns: `ABC-123`, `PROJ-456`, any `[A-Z]+-[0-9]+`). Also check the current branch name — branches are often named `feature/ABC-123-description` or `ABC-123/something`.
2. If a ticket number is found:
   - Check if `tickets/<TICKET>/` exists in the repo root.
   - If it exists, write to `tickets/<TICKET>/commit-plan-<TICKET>.md` — co-located with the ticket and plan files.
   - If it does not exist, fall back to `local-dev/plans/commit-plan-<TICKET>.md`. Create the directory if needed: `mkdir -p local-dev/plans`.
3. If no ticket number is found, write to `local-dev/plans/commit-plan.md`. Create the directory if needed: `mkdir -p local-dev/plans`.

Final path examples:
- With ticket dir present: `tickets/ABC-123/commit-plan-ABC-123.md`
- With ticket but no ticket dir: `local-dev/plans/commit-plan-ABC-123.md`
- Without ticket: `local-dev/plans/commit-plan.md`

Output a markdown file at that path. Structure:

```markdown
# Commit Plan — <branch> → <target_branch>

Merge base: <hash>
Files changed: <N>
Existing commits: <N> | Keeping: <N> | Rewriting: <N>

---

## Existing Commit Assessment

| Commit | Short SHA | Verdict | Reason |
|--------|-----------|---------|--------|
| `feat: add login` | `abc1234` | keep | Conventional, atomic, semantic |
| `wip stuff` | `def5678` | rewrite | Vague, mixed concerns |
| `fix` | `ghi9012` | rewrite | Missing scope, non-semantic |

---

## Proposed Commit Sequence

### Commit 1 of N
**Message:** `type(scope): description`
**Why:** <one sentence explaining why this is a logical unit>
**Files:**
- `path/to/file.ts`
- `path/to/other.ts`

**Git commands:**
```bash
git reset <merge_base>           # unstage everything back to merge base
git add path/to/file.ts path/to/other.ts
git commit -m "type(scope): description"
```

### Commit 2 of N
...

---

## Full Execution Script

> Review the plan above before running. This script rewrites history.
> If you have a remote branch, you will need to force-push: `git push --force-with-lease`

```bash
#!/usr/bin/env bash
set -e

MERGE_BASE="<hash>"

# Reset to merge base (keeps all changes in working tree)
git reset "$MERGE_BASE"

# Commit 1 — type(scope): description
git add <files>
git commit -m "type(scope): description"

# Commit 2 — ...
git add <files>
git commit -m "..."

# ... etc

echo "Done. Review with: git log --oneline"
echo "Force push when ready: git push --force-with-lease"
```
```

---

### Step 4.5 — Self-review the commit plan

Before presenting the plan to the developer, review it against this checklist and fix any failure.
These are objective checks — they run in **both** modes (the developer reviews a pre-vetted plan, not
a first draft).

| Check | Pass condition |
|---|---|
| File reconciliation | Every changed file from the diff appears in exactly one proposed commit — no dropped files, none duplicated across commits |
| Concern separation | No commit mixes unrelated concerns (refactor + feature + fix split apart) |
| Ordering | Follows the infra → model → logic → integration → UI → tests sequence from Step 3 |
| Format | Every message is valid `type(scope): description` with a meaningful (non-filename) scope |
| Linear history | Merge commits excluded; binary/generated files flagged |
| Script matches | The execution script's `git add` file list reconciles exactly with the diff's file list |

### Step 5 — Human review

After producing the plan file, stop and tell the user the exact path it was saved to, then say:

> "Plan saved to `<resolved-path>`. Review the proposed commits and the execution script. Edit the file if anything needs changing, then tell me to proceed — or give me feedback and I'll revise the plan."

**Do not run any git reset or commit commands until the user explicitly confirms.**

---

### Step 6 — Execute (on confirmation)

Once the user confirms:
1. Run the execution script from the plan
2. Show `git log --oneline` output after completion
3. Remind user to force-push if the branch has a remote: `git push --force-with-lease`

If any step fails (merge conflict, wrong file state, etc.), stop immediately and report the exact error before attempting recovery.

---

## Edge Cases

**No existing commits (fresh branch with uncommitted changes):**
Skip the assessment table. Go straight to designing the commit plan from the diff.

**All existing commits are clean:**
Still produce the plan document. Show the assessment table with all ✅, confirm the sequence looks right, and offer to either proceed as-is or re-evaluate if the user wants different groupings.

**Merge commits in the range:**
Note them in the assessment. Do not include merge commits in the rewritten history — the clean sequence should be linear.

**Binary files or large generated files:**
Flag them explicitly in the plan. Ask the user whether to include them in a dedicated commit or whether they're already gitignored.

**Monorepo:**
Use the top-level package/app/service directory as the scope. E.g. `feat(api): ...`, `fix(web): ...`, `chore(infra): ...`.

---

## Reference files

- `references/conventional-commits.md` — Valid types, scope guidance, examples
