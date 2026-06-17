# Human Review Gates — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit human approval gates at every artifact boundary in the pipeline, with stamped audit trail in `REVIEW-LOG.md` per ticket.

**Architecture:** Each skill gains two additions: (1) a Review Gate at its end that halts for `approve` in collaborative mode or auto-stamps in auto mode, and (2) a preflight check at its start that reads `REVIEW-LOG.md` and halts if the upstream stamp is missing. All stamps live in `local-dev/tickets/PROJ-123/REVIEW-LOG.md` — artifact files (plan, etc.) are never touched.

**Tech Stack:** Markdown skill files only — no code, no build system. Each task is a targeted edit to one `SKILL.md`.

## Global Constraints

- Never modify artifact files (plan, ticket) as part of gate logic — stamps go to `REVIEW-LOG.md` only
- Stamp format: `> **Human Review:** APPROVED — YYYY-MM-DD — <step-name>` (collaborative) or `> **Human Review:** AUTO — YYYY-MM-DD — <step-name>` (auto)
- Re-runs overwrite the matching step-name line in `REVIEW-LOG.md`, never append a duplicate
- Preflight missing stamp → hard halt with exact message naming the upstream skill
- Preflight AUTO stamp → continue with a visibility note, no block
- Skills detect mode from invocation argument (`auto` suffix); no argument = collaborative
- `crafting-commits` Step 5 is the gate for that skill — no new gate section needed, just stamp-on-confirm behavior

---

## File Map

| File | Change |
|---|---|
| `skills/picking-up-task/SKILL.md` | Add Review Gate section at end of Handoff |
| `skills/planning-from-ticket/SKILL.md` | Add Preflight Check before step 1; add gate stamp at step 6 |
| `skills/generating-tasks/SKILL.md` | Add Preflight Check before step 1; add gate stamp at step 4 |
| `skills/reviewing-plan/SKILL.md` | Add Preflight Check before step 0; add human gate wrapping step 8 |
| `skills/implementing-tasks/SKILL.md` | Add Preflight Check in "Before You Start"; add per-task gate after each GREEN cycle |
| `skills/reviewing-code/SKILL.md` | Add Preflight Check in Preflight step; add gate at end of Report |
| `skills/crafting-commits/SKILL.md` | Add Preflight Check in Input Validation; promote Step 5 to formal gate with stamp-on-confirm |

---

### Task T1: picking-up-task — Review Gate

**Files:**
- Modify: `skills/picking-up-task/SKILL.md` (Handoff section)

**Interfaces:**
- Produces: `> **Human Review:** APPROVED — YYYY-MM-DD — picking-up-task` in `$ARTIFACTS_ROOT/PROJ-123/REVIEW-LOG.md`
- Consumed by: T2 (`planning-from-ticket` preflight)

- [ ] **Step 1: Locate the Handoff section**

Open `skills/picking-up-task/SKILL.md`. Find the `## Handoff` section (currently ends with "No push commands. No extra guidance. No reminders.").

- [ ] **Step 2: Replace the Handoff section with a gate-aware version**

Replace:
```markdown
## Handoff

Once the branch (or worktree) is ready, print exactly this and stop:

```
Branch `feat/PROJ-42/add-user-auth` ready (based off `develop`).
Ticket saved to `$ARTIFACTS_ROOT/PROJ-42/PROJ-42.md`.

Next: /planning-from-ticket $ARTIFACTS_ROOT/PROJ-42/PROJ-42.md
```

No push commands. No extra guidance. No reminders.
```

With:
```markdown
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
```

- [ ] **Step 3: Verify the edit is self-consistent**

Read back the modified section. Confirm:
- The stamp path uses `$ARTIFACTS_ROOT` (not a hardcoded `local-dev/tickets`)
- The stamp step-name is exactly `picking-up-task`
- The next-step line still points to `planning-from-ticket`
- No extra guidance or reminders added

- [ ] **Step 4: Commit**

```bash
git -C /Users/hisl/repos/agentic-skills add skills/picking-up-task/SKILL.md
git -C /Users/hisl/repos/agentic-skills commit -m "feat(picking-up-task): add review gate and REVIEW-LOG stamp at handoff"
```

---

### Task T2: planning-from-ticket — Preflight + Gate

**Files:**
- Modify: `skills/planning-from-ticket/SKILL.md` (Workflow section, step 6)

**Interfaces:**
- Consumes: `picking-up-task` stamp in `REVIEW-LOG.md` (preflight)
- Produces: `> **Human Review:** APPROVED — YYYY-MM-DD — planning-from-ticket` in `REVIEW-LOG.md`
- Consumed by: T3 (`generating-tasks` preflight)

- [ ] **Step 1: Add Preflight Check before step 1 of the Workflow**

In `skills/planning-from-ticket/SKILL.md`, find the `## Workflow` section. Before `### 1. Read the source completely`, insert:

```markdown
### 0. Preflight — check upstream gate

Before any other work, locate `REVIEW-LOG.md` in the same directory as the ticket file (i.e. `<ticket-dir>/REVIEW-LOG.md`) and check for a `picking-up-task` stamp:

```bash
grep "Human Review:.*picking-up-task" <ticket-dir>/REVIEW-LOG.md
```

- **Line absent (or file missing):** halt immediately with:
  > "This step requires a human review stamp from `picking-up-task`. Run `/picking-up-task` first and approve the ticket before planning."
- **Line present with `AUTO`:** note in output — "Note: upstream `picking-up-task` was AI-conducted in auto mode" — then continue.
- **Line present with `APPROVED`:** proceed normally.
```

- [ ] **Step 2: Add stamp to step 6 (Write the plan file)**

Find `### 6. Write the plan file beside the ticket`. After the file-write instruction, append:

```markdown
After writing the plan file, open the Review Gate.

**Collaborative mode (default):** The plan was already presented and approved in step 5 — that approval is the gate. Write (or upsert) this line in `<ticket-dir>/REVIEW-LOG.md`:
```
> **Human Review:** APPROVED — YYYY-MM-DD — planning-from-ticket
```
Then tell the developer: `Plan written to <path>. Next: /generating-tasks <path>`

**Auto mode:** Write the stamp automatically with `AUTO`:
```
> **Human Review:** AUTO — YYYY-MM-DD — planning-from-ticket
```
```

- [ ] **Step 3: Verify consistency**

Read back both edits. Confirm:
- Preflight step is numbered `0` and runs before step `1`
- Stamp step-name is exactly `planning-from-ticket`
- Collaborative mode notes that step 5 approval IS the gate (no double-approval ceremony)
- Next-step line points to `generating-tasks`

- [ ] **Step 4: Commit**

```bash
git -C /Users/hisl/repos/agentic-skills add skills/planning-from-ticket/SKILL.md
git -C /Users/hisl/repos/agentic-skills commit -m "feat(planning-from-ticket): add preflight gate check and REVIEW-LOG stamp"
```

---

### Task T3: generating-tasks — Preflight + Gate

**Files:**
- Modify: `skills/generating-tasks/SKILL.md` (Conversation Flow section, step 4)

**Interfaces:**
- Consumes: `planning-from-ticket` stamp (preflight)
- Produces: `> **Human Review:** APPROVED — YYYY-MM-DD — generating-tasks` in `REVIEW-LOG.md`
- Consumed by: T4 (`reviewing-plan` preflight)

- [ ] **Step 1: Add Preflight Check at the start of the Conversation Flow**

In `skills/generating-tasks/SKILL.md`, find `## Conversation Flow`. Before `### 1. Understand the plan`, insert:

```markdown
### 0. Preflight — check upstream gate

Before reading the plan, locate `REVIEW-LOG.md` in the same directory as the plan file and check for a `planning-from-ticket` stamp:

```bash
grep "Human Review:.*planning-from-ticket" <plan-dir>/REVIEW-LOG.md
```

- **Line absent (or file missing):** halt immediately with:
  > "This step requires a human review stamp from `planning-from-ticket`. Run `/planning-from-ticket` first and approve the plan before generating tasks."
- **Line present with `AUTO`:** note — "Note: upstream `planning-from-ticket` was AI-conducted in auto mode" — then continue.
- **Line present with `APPROVED`:** proceed normally.
```

- [ ] **Step 2: Add stamp to step 4 (Append to the plan file)**

Find `### 4. Append to the plan file`. After the append instruction, add:

```markdown
After appending, open the Review Gate.

**Collaborative mode (default):** The task spec was already presented and agreed in step 3 — that agreement is the gate. Write (or upsert) this line in `<plan-dir>/REVIEW-LOG.md`:
```
> **Human Review:** APPROVED — YYYY-MM-DD — generating-tasks
```
Then tell the developer: `Tasks appended. Next: /reviewing-plan <plan-file>`

**Auto mode:** Write the stamp automatically with `AUTO`:
```
> **Human Review:** AUTO — YYYY-MM-DD — generating-tasks
```
```

- [ ] **Step 3: Verify consistency**

Read back both edits. Confirm:
- Preflight is step `0`, runs before step `1`
- Stamp step-name is exactly `generating-tasks`
- Next-step line correctly points to `reviewing-plan` (already in the skill's closing instruction — do not duplicate; only add the stamp)

- [ ] **Step 4: Commit**

```bash
git -C /Users/hisl/repos/agentic-skills add skills/generating-tasks/SKILL.md
git -C /Users/hisl/repos/agentic-skills commit -m "feat(generating-tasks): add preflight gate check and REVIEW-LOG stamp"
```

---

### Task T4: reviewing-plan — Preflight + Human Gate wrapping AI verdict

**Files:**
- Modify: `skills/reviewing-plan/SKILL.md` (Workflow section, step 8)

**Interfaces:**
- Consumes: `generating-tasks` stamp (preflight)
- Produces: `> **Human Review:** APPROVED — YYYY-MM-DD — reviewing-plan` in `REVIEW-LOG.md`
- Consumed by: T5 (`implementing-tasks` preflight)

**Note:** `reviewing-plan` already appends `> **Plan Review:** PROCEED — YYYY-MM-DD` to the plan file (step 8). The human gate is *additional* — the AI verdict runs first, then the human approves before implementation starts. The Plan Review stamp stays in the plan file as-is; the Human Review stamp goes to `REVIEW-LOG.md`.

- [ ] **Step 1: Add Preflight Check before step 0 of the Workflow**

In `skills/reviewing-plan/SKILL.md`, find `## Workflow`. Before `### 0. Dispatch the judgment as a fresh-context subagent`, insert:

```markdown
### -1. Preflight — check upstream gate

Before dispatching the judge, locate `REVIEW-LOG.md` in the same directory as the plan file and check for a `generating-tasks` stamp:

```bash
grep "Human Review:.*generating-tasks" <plan-dir>/REVIEW-LOG.md
```

- **Line absent (or file missing):** halt immediately with:
  > "This step requires a human review stamp from `generating-tasks`. Run `/generating-tasks` first and approve the tasks before reviewing the plan."
- **Line present with `AUTO`:** note — "Note: upstream `generating-tasks` was AI-conducted in auto mode" — then continue.
- **Line present with `APPROVED`:** proceed normally.
```

- [ ] **Step 2: Extend step 8 to add a human gate after the AI verdict**

Find `### 8.` (the verdict marker step). After the existing verdict-marker instructions, append:

```markdown
**Human Review Gate (after AI verdict):**

**Collaborative mode (default):** After emitting the structured verdict (step 7) and offering to append the Plan Review verdict marker, open the human gate:

> "Review the plan verdict above. Type `approve` to stamp it and unlock implementing-tasks, or describe what needs fixing."

Wait for `approve`. On approval, write (or upsert) in `<plan-dir>/REVIEW-LOG.md`:
```
> **Human Review:** APPROVED — YYYY-MM-DD — reviewing-plan
```
Then tell the developer: `Stamped REVIEW-LOG.md. Next: /implementing-tasks <plan-file>`

If the verdict is DO NOT PROCEED, do not offer the human gate — direct the developer to `receiving-plan-review` first.

**Auto mode:** If the verdict is PROCEED or PROCEED WITH CHANGES, write the stamp automatically:
```
> **Human Review:** AUTO — YYYY-MM-DD — reviewing-plan
```
If the verdict is DO NOT PROCEED, do not write a stamp — halt and invoke `receiving-plan-review`.
```

- [ ] **Step 3: Verify consistency**

Read back both edits. Confirm:
- Preflight is numbered `-1` (before step `0`)
- Human gate only fires on PROCEED/PROCEED WITH CHANGES, not DO NOT PROCEED
- Plan Review stamp (in plan file) and Human Review stamp (in REVIEW-LOG.md) are distinct and not confused
- Stamp step-name is exactly `reviewing-plan`

- [ ] **Step 4: Commit**

```bash
git -C /Users/hisl/repos/agentic-skills add skills/reviewing-plan/SKILL.md
git -C /Users/hisl/repos/agentic-skills commit -m "feat(reviewing-plan): add preflight gate check and human review gate after AI verdict"
```

---

### Task T5: implementing-tasks — Preflight + Per-task Gate

**Files:**
- Modify: `skills/implementing-tasks/SKILL.md` ("Before You Start" section and TDD cycle)

**Interfaces:**
- Consumes: `reviewing-plan` stamp (preflight)
- Produces: `> **Human Review:** APPROVED — YYYY-MM-DD — implementing-tasks-T<n>` per task in `REVIEW-LOG.md`
- Consumed by: T6 (`reviewing-code` preflight — checks all `implementing-tasks-T*` stamps present)

- [ ] **Step 1: Add Preflight Check in "Before You Start"**

In `skills/implementing-tasks/SKILL.md`, find `## Before You Start`. After step `1a` (the Plan Review PROCEED check), insert as step `1b`:

```markdown
**1b. Check the human review gate.** Look for a `reviewing-plan` stamp in `REVIEW-LOG.md` (same directory as the plan file):

```bash
grep "Human Review:.*reviewing-plan" <plan-dir>/REVIEW-LOG.md
```

- **Absent (or file missing):** halt:
  > "This step requires a human review stamp from `reviewing-plan`. Approve the plan review before starting implementation."
- **AUTO stamp:** note — "Note: upstream `reviewing-plan` was AI-conducted in auto mode" — then continue.
- **APPROVED stamp:** proceed normally.
```

- [ ] **Step 2: Add per-task gate after each task's GREEN cycle**

Find the `## After All Tests Pass` section (or the end of the TDD cycle description). Add a new subsection:

```markdown
## Per-Task Review Gate

After all tests for a task pass and before moving to the next task, open the Review Gate for that task.

**Collaborative mode (default):**

> "All tests for Task T<n> pass. Review the implementation above. Type `approve` to stamp it and move to the next task, or describe what needs fixing."

Wait for `approve`. On approval, write (or upsert) in `<plan-dir>/REVIEW-LOG.md`:
```
> **Human Review:** APPROVED — YYYY-MM-DD — implementing-tasks-T<n>
```
(Replace `<n>` with the task number, e.g. `implementing-tasks-T1`.)

**Auto mode:** Write the stamp automatically:
```
> **Human Review:** AUTO — YYYY-MM-DD — implementing-tasks-T<n>
```
Then continue to the next task.

**After the final task:** tell the developer: `All tasks complete. Next: /reviewing-code`
```

- [ ] **Step 3: Verify consistency**

Read back both edits. Confirm:
- Preflight is step `1b` (between existing `1a` and `2`)
- Per-task stamp uses `implementing-tasks-T<n>` with the actual task number substituted
- Gate fires after ALL tests for a task pass, before moving to the next task
- After the final task, next-step points to `reviewing-code`

- [ ] **Step 4: Commit**

```bash
git -C /Users/hisl/repos/agentic-skills add skills/implementing-tasks/SKILL.md
git -C /Users/hisl/repos/agentic-skills commit -m "feat(implementing-tasks): add preflight gate check and per-task review gate"
```

---

### Task T6: reviewing-code — Preflight + Gate

**Files:**
- Modify: `skills/reviewing-code/SKILL.md` (Preflight step and Report section)

**Interfaces:**
- Consumes: all `implementing-tasks-T*` stamps (preflight — one per task in the plan)
- Produces: `> **Human Review:** APPROVED — YYYY-MM-DD — reviewing-code` in `REVIEW-LOG.md`
- Consumed by: T7 (`crafting-commits` preflight)

- [ ] **Step 1: Add Preflight gate check to the existing Preflight step (step 1)**

In `skills/reviewing-code/SKILL.md`, find `### 1. Preflight`. After the existing checks (git repo, `gh` auth, etc.), add:

```markdown
**Gate check:** Locate `REVIEW-LOG.md` in the ticket directory. Count the `implementing-tasks-T*` stamps and compare against the number of tasks in the plan file. All tasks must be stamped before code review begins.

```bash
grep "Human Review:.*implementing-tasks-T" <plan-dir>/REVIEW-LOG.md
```

- **Any task stamp missing:** halt:
  > "This step requires a human review stamp for every task from `implementing-tasks`. Missing: implementing-tasks-T<n>. Approve each task before running code review."
- **All AUTO stamps:** note — "Note: all implementing-tasks gates were AI-conducted in auto mode" — then continue.
- **All APPROVED (or mixed):** proceed normally (mixed AUTO/APPROVED is fine).
```

- [ ] **Step 2: Add gate stamp at the end of the Report section**

Find `## Report`. After the Verdicts subsection, add:

```markdown
### Review Gate

After presenting the report, open the gate.

**Collaborative mode (default):**

> "Review the code review report above. Type `approve` to stamp it and proceed to crafting-commits, or describe what needs fixing."

Wait for `approve`. On approval, write (or upsert) in `<plan-dir>/REVIEW-LOG.md`:
```
> **Human Review:** APPROVED — YYYY-MM-DD — reviewing-code
```
Then tell the developer: `Stamped REVIEW-LOG.md. Next: /crafting-commits`

A ❌ FAIL or ❌ REQUEST CHANGES verdict does not offer the gate — direct the developer to `superpowers:receiving-code-review` first.

**Auto mode:** On PASS or PASS WITH FINDINGS, write the stamp automatically:
```
> **Human Review:** AUTO — YYYY-MM-DD — reviewing-code
```
On FAIL, do not write a stamp — halt and invoke `superpowers:receiving-code-review`.
```

- [ ] **Step 3: Verify consistency**

Read back both edits. Confirm:
- Preflight counts task stamps against the plan's task list (not just checks for any stamp)
- Gate only fires on non-FAIL verdicts
- Stamp step-name is exactly `reviewing-code`
- Next-step points to `crafting-commits`

- [ ] **Step 4: Commit**

```bash
git -C /Users/hisl/repos/agentic-skills add skills/reviewing-code/SKILL.md
git -C /Users/hisl/repos/agentic-skills commit -m "feat(reviewing-code): add preflight gate check and review gate after report"
```

---

### Task T7: crafting-commits — Preflight + Promote Step 5 to formal gate

**Files:**
- Modify: `skills/crafting-commits/SKILL.md` (Input Validation and Step 5)

**Interfaces:**
- Consumes: `reviewing-code` stamp (preflight)
- Produces: `> **Human Review:** APPROVED — YYYY-MM-DD — crafting-commits` in `REVIEW-LOG.md`
- Consumed by: `superpowers:finishing-a-development-branch` (not modified in this plan — it can check the stamp independently)

- [ ] **Step 1: Add Preflight Check to Input Validation**

In `skills/crafting-commits/SKILL.md`, find `## Input Validation`. After the existing four checks (git repo, not default branch, commits ahead, no rebase), add a fifth row to the table:

```markdown
| `REVIEW-LOG.md` has `reviewing-code` stamp | Halt — "This step requires a human review stamp from `reviewing-code`. Run `/reviewing-code` first and approve the review before crafting commits." Note `AUTO` stamps with a visibility note but do not block. |
```

- [ ] **Step 2: Promote Step 5 to formal gate with stamp-on-confirm**

Find `### Step 5 — Present plan in chat (human gate)`. After the existing `> "Review the proposed commits..."` instruction, add:

```markdown
On developer confirmation (`approve` or equivalent explicit go-ahead), before running the execution script, write (or upsert) in `REVIEW-LOG.md` (same directory as the plan/ticket file, or the repo root if no ticket directory is in context):
```
> **Human Review:** APPROVED — YYYY-MM-DD — crafting-commits
```

**Auto mode:** Step 5 still halts for the developer — `auto` does not relax the git gate (as documented in the skill header). Write the stamp when the developer confirms, same as collaborative.
```

- [ ] **Step 3: Verify consistency**

Read back both edits. Confirm:
- Input Validation table has five rows, not four
- AUTO stamp from `reviewing-code` gets a visibility note but does not block crafting-commits from running
- Stamp is written BEFORE Step 6 execution (on confirm, before git commands run)
- Stamp step-name is exactly `crafting-commits`
- Auto mode still halts at Step 5 (no relaxation of git gate)

- [ ] **Step 4: Commit**

```bash
git -C /Users/hisl/repos/agentic-skills add skills/crafting-commits/SKILL.md
git -C /Users/hisl/repos/agentic-skills commit -m "feat(crafting-commits): add preflight gate check and formal REVIEW-LOG stamp at Step 5"
```

---

## Self-Review

**Spec coverage:**
- ✅ `picking-up-task` gets Review Gate → T1
- ✅ `planning-from-ticket` gets Preflight + Gate → T2
- ✅ `generating-tasks` gets Preflight + Gate → T3
- ✅ `reviewing-plan` gets Preflight + Human Gate wrapping AI verdict → T4
- ✅ `implementing-tasks` gets Preflight + per-task Gate → T5
- ✅ `reviewing-code` gets Preflight + Gate → T6
- ✅ `crafting-commits` gets Preflight + promotes Step 5 → T7
- ✅ Stamp format: APPROVED/AUTO, YYYY-MM-DD, step-name
- ✅ All stamps to `REVIEW-LOG.md`, never to artifact files
- ✅ Re-runs overwrite (upsert) existing line — noted in T1, T2, T3, T4, T5, T6, T7
- ✅ AUTO stamp → visibility note, no block
- ✅ Gate only fires on non-failure verdicts (`reviewing-plan`, `reviewing-code`)
- ✅ `implementing-tasks` uses task-scoped step names (`implementing-tasks-T<n>`)
- ✅ `reviewing-code` preflight counts all task stamps against plan task list

**Placeholder scan:** No TBD, TODO, or "similar to above" in any task. All step names are exact strings. All file paths are exact.

**Type consistency:** Step names used in stamps match exactly what preflight greps for across tasks (e.g. T2 produces `planning-from-ticket`, T3 greps for `planning-from-ticket`).
