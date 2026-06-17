# Skill Best-Practices Audit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every skill that violates the four audit dimensions (description quality, frontmatter completeness, body quality, pipeline consistency) so the repo ships a consistent, high-quality skill set.

**Architecture:** Edit-only — no new files created, no tooling changed. Each task targets one or more SKILL.md files and commits all changes for that skill atomically. Tasks are ordered: BLOCKERs first, then SHOULD-FIX clusters, then NITs.

**Tech Stack:** Markdown, YAML frontmatter, git conventional commits.

## Global Constraints

- Edit only `skills/<name>/SKILL.md` files and `README.md` — do not touch `references/` content, `install.sh`, or `book-skills/`
- All frontmatter must be valid YAML (no unquoted colons in description values)
- Descriptions must remain under ~200 words
- Preserve all existing skill body logic — fix structure/style only, never remove workflow steps
- One git commit per skill (groups all dimensions for that skill)
- Commit message format: `fix(<skill-name>): <what was fixed>`

---

## Consolidated Findings

### BLOCKERs (fix first)

| # | Skill(s) | Issue |
|---|---|---|
| B1 | `reviewing-plan` + `implementing-tasks` | PROCEED marker contract broken: `reviewing-plan` writes `PROCEED WITH CHANGES` variant but `implementing-tasks` only checks for `PROCEED` — plans that pass with non-critical findings could be blocked from implementation |
| B2 | `picking-up-task` | Uses deprecated name `start-task` in its own "Where You Sit" pipeline diagram — consumers following the diagram would invoke a non-existent skill |
| B3 | `generating-design-doc` | Description is a condensed workflow summary (with output format detail and negative-trigger cases) rich enough for a model to skip the body |

### SHOULD-FIX

| # | Skill(s) | Issue |
|---|---|---|
| S1 | `crafting-commits`, `fetching-tickets`, `generating-design-doc`, `planning-from-ticket`, `receiving-plan-review`, `reviewing-plan`, `testing-pytest`, `testing-vitest` | Missing `model: inherit` in frontmatter (8 skills) |
| S2 | `reviewing-plan` | Description partially narrates workflow; "Reviews the plan artifact, not code" and negative-case text duplicates body content |
| S3 | `planning-from-ticket` | Description leaks internal workflow details ("does not fetch from Jira", mode flag doc) |
| S4 | `generating-design-doc` + `planning-from-ticket` | Self-review gate missing an explicit "STOP — do not hand off" signal at the boundary |
| S5 | `reviewing-code` | Produces a report artifact but has no self-review checklist on the report itself |
| S6 | `fetching-tickets`, `generating-tasks`, `planning-from-ticket`, `reviewing-code`, `crafting-commits` | Support `auto` mode but missing one or more of the four invariants: no self-commit, no self-push, halt on BLOCKER, ask on unresolvable ambiguity |
| S7 | `implementing-tasks` | Uses non-canonical example plan file name (`PLAN-auth-login-flow.md` instead of `PLAN-TICKET-KEY.md`) |

### NITs

| # | Skill(s) | Issue |
|---|---|---|
| N1 | `crafting-commits`, `fetching-tickets`, `generating-design-doc`, `implementing-tasks`, `picking-up-task`, `receiving-plan-review`, `testing-pytest`, `testing-vitest` | Missing `color` and/or `license` frontmatter fields |
| N2 | `implementing-tasks`, `generating-tasks`, `picking-up-task` | Description contains a scope-delimiting or operational clause rather than a trigger phrase |
| N3 | `crafting-commits`, `generating-tasks`, `implementing-tasks`, `receiving-plan-review`, `testing-vitest` | Body opens with more than one sentence before workflow steps |
| N4 | `generating-design-doc` | Body has a "When to use this skill" section that duplicates the description |
| N5 | `picking-up-task` | "Do not trigger automatically" in description is ambiguous — not a trigger phrase |

---

## Task 1: Fix PROCEED marker contract (`reviewing-plan` + `implementing-tasks`)

**Files:**
- Modify: `skills/reviewing-plan/SKILL.md`
- Modify: `skills/implementing-tasks/SKILL.md`

**Interfaces:**
- Produces: canonical PROCEED marker format agreed between both skills
- Contract: marker written by `reviewing-plan` = marker checked by `implementing-tasks`

Canonical format to use in both skills:
```
> **Plan Review:** PROCEED — YYYY-MM-DD
```
For "PROCEED WITH CHANGES", the marker becomes:
```
> **Plan Review:** PROCEED WITH CHANGES — YYYY-MM-DD
```
`implementing-tasks` must accept both by checking for the prefix `> **Plan Review:** PROCEED`.

- [ ] **Step 1: Read both skill files**

Read `skills/reviewing-plan/SKILL.md` and `skills/implementing-tasks/SKILL.md` in full. Find every location that references the PROCEED marker — the append instruction in `reviewing-plan` and the gate check in `implementing-tasks`.

- [ ] **Step 2: Update `reviewing-plan` — clarify both marker variants**

In the verdict-append section, make both variants explicit with exact format:

```markdown
Append exactly one of these lines to the plan file:

> **Plan Review:** PROCEED — YYYY-MM-DD
> **Plan Review:** PROCEED WITH CHANGES — YYYY-MM-DD
> **Plan Review:** DO NOT PROCEED — YYYY-MM-DD

Use the actual date. Use the exact format — `implementing-tasks` checks for the prefix `> **Plan Review:** PROCEED`.
```

- [ ] **Step 3: Update `implementing-tasks` — state the acceptance rule explicitly**

In the gate check section, replace any reference to the marker with:

```markdown
Check the plan file for a line beginning with `> **Plan Review:** PROCEED`.
This matches both `PROCEED` and `PROCEED WITH CHANGES` verdicts.
DO NOT start if the only verdict line is `> **Plan Review:** DO NOT PROCEED`.
```

- [ ] **Step 4: Commit**

```bash
git add skills/reviewing-plan/SKILL.md skills/implementing-tasks/SKILL.md
git commit -m "fix(reviewing-plan,implementing-tasks): align PROCEED marker contract to accept both PROCEED and PROCEED WITH CHANGES"
```

---

## Task 2: Fix deprecated `start-task` name in `picking-up-task`

**Files:**
- Modify: `skills/picking-up-task/SKILL.md`

**Interfaces:**
- The pipeline diagram inside this skill must use `picking-up-task` as the step 1 label

- [ ] **Step 1: Read the file**

Read `skills/picking-up-task/SKILL.md` in full. Find every instance of `start-task` in the body (pipeline diagram, section labels, any references).

- [ ] **Step 2: Replace all `start-task` references with `picking-up-task`**

In the pipeline position diagram and any other location, replace the deprecated name:

```
start-task  →  picking-up-task
```

Verify there are no remaining `start-task` occurrences after the edit.

- [ ] **Step 3: Commit**

```bash
git add skills/picking-up-task/SKILL.md
git commit -m "fix(picking-up-task): replace deprecated start-task name with picking-up-task in pipeline diagram"
```

---

## Task 3: Fix `generating-design-doc` description (BLOCKER D1 + SHOULD-FIX frontmatter + body NITs)

**Files:**
- Modify: `skills/generating-design-doc/SKILL.md`

**Interfaces:**
- Description after fix: trigger-focused, no workflow narration, under 200 words
- Body after fix: "When to use this skill" section removed (content moved to description or dropped)
- Frontmatter after fix: adds `model: inherit`, `color`, `license`

- [ ] **Step 1: Read the file**

Read `skills/generating-design-doc/SKILL.md` in full.

- [ ] **Step 2: Rewrite the description**

Replace the current description (which lists output format, section list, and negative triggers) with a trigger-focused version:

```yaml
description: >
  Use when the user wants to document an existing codebase as a structured
  architecture document. Triggers on "write an architecture doc", "create a
  design document for this system", "document this service", "generate a
  design doc from the codebase", "produce architectural diagrams from code",
  "do a system writeup", "create technical documentation with diagrams", or
  any request combining an existing codebase with an ask for structured
  architectural documentation. Do NOT use for greenfield design proposals
  (no code yet) or for short README-style summaries.
```

- [ ] **Step 3: Add missing frontmatter fields**

Add after the `description` field:

```yaml
model: inherit
color: lightyellow
license: MIT
```

- [ ] **Step 4: Remove the "When to use this skill" section from the body**

Delete the entire "When to use this skill" section from the body — it duplicates the description. Ensure the body now opens with a single sentence stating what the skill does.

- [ ] **Step 5: Strengthen the self-review gate**

Find the self-review checklist section. Add an explicit stop-gate line before the checklist:

```markdown
**STOP before delivering the document.** Run this checklist — if any item fails, fix it before output:
```

- [ ] **Step 6: Commit**

```bash
git add skills/generating-design-doc/SKILL.md
git commit -m "fix(generating-design-doc): rewrite description as trigger-focused, remove body duplication, strengthen self-review gate"
```

---

## Task 4: Fix `reviewing-plan` description and frontmatter

**Files:**
- Modify: `skills/reviewing-plan/SKILL.md`

**Interfaces:**
- Description after fix: trigger-focused, no "Reviews the plan artifact, not code" narration

- [ ] **Step 1: Read the file**

Read `skills/reviewing-plan/SKILL.md` in full.

- [ ] **Step 2: Rewrite the description**

Remove the workflow narration ("Reviews the plan artifact, not code — for post-code review use the reviewing-code skill") and any clause that duplicates body content. Keep the trigger phrases. Result should be clean trigger statements only, under 200 words.

- [ ] **Step 3: Add missing frontmatter fields**

Add after the description:

```yaml
model: inherit
color: lightyellow
license: MIT
```

- [ ] **Step 4: Commit**

```bash
git add skills/reviewing-plan/SKILL.md
git commit -m "fix(reviewing-plan): rewrite description as trigger-focused, add model/color/license frontmatter"
```

---

## Task 5: Fix `planning-from-ticket` description, frontmatter, and self-review gate

**Files:**
- Modify: `skills/planning-from-ticket/SKILL.md`

**Interfaces:**
- Description after fix: no internal workflow details, no mode-flag documentation

- [ ] **Step 1: Read the file**

Read `skills/planning-from-ticket/SKILL.md` in full.

- [ ] **Step 2: Rewrite the description**

Remove "does not fetch from Jira" and the `auto` flag documentation from the description — these belong in the body. Keep only trigger phrases.

- [ ] **Step 3: Add missing frontmatter fields**

Add:

```yaml
model: inherit
color: lightblue
```

(`license: MIT` already present — confirm and keep.)

- [ ] **Step 4: Strengthen the self-review gate**

Find the self-review step. Add before the checklist:

```markdown
**STOP before presenting to the developer.** Check every item — fix failures before showing the plan:
```

- [ ] **Step 5: Commit**

```bash
git add skills/planning-from-ticket/SKILL.md
git commit -m "fix(planning-from-ticket): trim description to trigger-only, add model/color frontmatter, strengthen self-review gate"
```

---

## Task 6: Add self-review gate to `reviewing-code`

**Files:**
- Modify: `skills/reviewing-code/SKILL.md`

**Interfaces:**
- After fix: skill body contains a self-review checklist on the report artifact before it is delivered

- [ ] **Step 1: Read the file**

Read `skills/reviewing-code/SKILL.md` in full. Find where the report compilation step ends and the output is presented to the developer.

- [ ] **Step 2: Insert self-review gate before report delivery**

Add the following block immediately before the step that presents/writes the final report:

```markdown
**STOP before delivering the report.** Check:
- [ ] All dispatched check agents returned a result (no silent failures)
- [ ] Every changed file appears in at least one agent's scope
- [ ] Severity scale applied correctly (Critical = blocks merge, not just "important")
- [ ] Verdict matches the highest severity finding (e.g., any Critical → FAIL)
- [ ] No duplicate findings across agents (deduplicated)

Fix any failures before presenting the report.
```

- [ ] **Step 3: Commit**

```bash
git add skills/reviewing-code/SKILL.md
git commit -m "fix(reviewing-code): add self-review gate on report artifact before delivery"
```

---

## Task 7: Fix `auto` mode invariants across five skills

**Files:**
- Modify: `skills/fetching-tickets/SKILL.md`
- Modify: `skills/generating-tasks/SKILL.md`
- Modify: `skills/crafting-commits/SKILL.md`
- Modify: `skills/reviewing-code/SKILL.md` (if not already addressed in Task 6)

(`planning-from-ticket` is covered in Task 5.)

**Interfaces:**
- After fix: every skill that supports `auto` explicitly states which of the four invariants apply and notes any that are N/A with a reason

The four invariants to document in each `auto` mode section:

```markdown
**`auto` invariants (both modes):**
- No self-commit (commits require explicit developer confirmation)
- No self-push
- Halt on BLOCKER verdict — do not proceed past a blocking finding
- Ask on unresolvable ambiguity — never guess when blocked
```

For purely mechanical skills (fetching-tickets), note which invariants are N/A:

```markdown
- No self-commit — N/A (this skill writes a file, not a commit)
- No self-push — N/A
```

- [ ] **Step 1: Read all four files**

Read each file in full. Find the `auto` mode section in each.

- [ ] **Step 2: Update `fetching-tickets` auto invariants**

Add to the auto mode section:

```markdown
**`auto` invariants:** No self-commit (N/A — writes a file, not a commit). No self-push (N/A). Halt and report if Jira API returns an error or required fields are missing. Ask on unresolvable ambiguity (e.g., duplicate ticket key in URL).
```

- [ ] **Step 3: Update `generating-tasks` auto invariants**

Add to the auto mode section:

```markdown
**`auto` invariants:** No self-commit. No self-push. Halt on self-review BLOCKER before appending tasks. Ask on unresolvable ambiguity.
```

- [ ] **Step 4: Update `crafting-commits` auto invariants**

Add to the auto mode section (it already states no self-execution — extend to cover all four):

```markdown
**`auto` invariants:** No self-commit (the bash script is presented, not executed). No self-push. Halt if the branch cannot be analyzed (e.g., merge conflicts). Ask on unresolvable ambiguity.
```

- [ ] **Step 5: Update `reviewing-code` auto invariants**

Extend the existing read-only statement:

```markdown
**`auto` invariants:** Read-only — no self-commit, no self-push. Halt on FAIL verdict (invoke `superpowers:receiving-code-review`). Ask on unresolvable ambiguity.
```

- [ ] **Step 6: Commit all four files**

```bash
git add skills/fetching-tickets/SKILL.md skills/generating-tasks/SKILL.md skills/crafting-commits/SKILL.md skills/reviewing-code/SKILL.md
git commit -m "fix(fetching-tickets,generating-tasks,crafting-commits,reviewing-code): document all four auto mode invariants explicitly"
```

---

## Task 8: Fix `implementing-tasks` — canonical plan file name + description NIT + frontmatter

**Files:**
- Modify: `skills/implementing-tasks/SKILL.md`

- [ ] **Step 1: Read the file**

Read `skills/implementing-tasks/SKILL.md` in full.

- [ ] **Step 2: Replace non-canonical example plan file name**

Find every occurrence of `PLAN-auth-login-flow.md` (or any other freeform example name) and replace with the canonical form:

```
PLAN-auth-login-flow.md  →  PLAN-TICKET-KEY.md
```

- [ ] **Step 3: Trim description NIT**

Remove "Does not plan features or generate task specs (use planning-from-ticket and generating-tasks for that)" from the description — this is a scope-delimiting clause that belongs in the body's "When NOT to use" section, not the trigger description.

- [ ] **Step 4: Add missing frontmatter field**

Add:

```yaml
license: MIT
```

- [ ] **Step 5: Commit**

```bash
git add skills/implementing-tasks/SKILL.md
git commit -m "fix(implementing-tasks): canonical plan file name in examples, trim description, add license"
```

---

## Task 9: Bulk frontmatter NITs — `crafting-commits`, `fetching-tickets`, `receiving-plan-review`, `testing-pytest`, `testing-vitest`

**Files:**
- Modify: `skills/crafting-commits/SKILL.md`
- Modify: `skills/fetching-tickets/SKILL.md`
- Modify: `skills/receiving-plan-review/SKILL.md`
- Modify: `skills/testing-pytest/SKILL.md`
- Modify: `skills/testing-vitest/SKILL.md`

Add `model: inherit`, `color`, and `license: MIT` to each skill that is missing them. Choose colors that are distinct and consistent with the existing palette (`lightgreen`, `lightblue`, `lightsalmon`, `peachpuff`, `cyan` are already in use).

Assignments:
- `crafting-commits` → `model: inherit`, `color: lavender`, `license: MIT`
- `fetching-tickets` → `model: inherit`, `color: lightyellow`, `license: MIT`
- `receiving-plan-review` → `model: inherit`, `color: mistyrose`, `license: MIT`
- `testing-pytest` → `model: inherit`, `color: lightcyan`, `license: MIT`
- `testing-vitest` → `model: inherit`, `color: lightcyan`, `license: MIT`

- [ ] **Step 1: Read all five files**

Read each file in full to find the current frontmatter block.

- [ ] **Step 2: Add missing fields to each file**

For each file, add the missing fields to the frontmatter block immediately after `description:`. Example for `crafting-commits`:

```yaml
---
name: crafting-commits
description: >
  ...existing description...
model: inherit
color: lavender
license: MIT
---
```

Apply the same pattern to all five files with their assigned colors.

- [ ] **Step 3: Commit**

```bash
git add skills/crafting-commits/SKILL.md skills/fetching-tickets/SKILL.md skills/receiving-plan-review/SKILL.md skills/testing-pytest/SKILL.md skills/testing-vitest/SKILL.md
git commit -m "fix(crafting-commits,fetching-tickets,receiving-plan-review,testing-pytest,testing-vitest): add model/color/license frontmatter fields"
```

---

## Task 10: Body opening NITs — fix multi-sentence openers

**Files:**
- Modify: `skills/crafting-commits/SKILL.md`
- Modify: `skills/generating-tasks/SKILL.md`
- Modify: `skills/receiving-plan-review/SKILL.md`
- Modify: `skills/testing-vitest/SKILL.md`

Each body should open with a single sentence stating what the skill does. Move or fold any second sentence into the workflow steps section.

- [ ] **Step 1: Read all four files**

Read each file in full to see the current body opening.

- [ ] **Step 2: Trim each opener to one sentence**

For each skill:

- `crafting-commits`: Keep the first sentence. Move the second sentence (about modes) into the "Modes" or "Workflow" section of the body.
- `generating-tasks`: Keep the first sentence. Move "You are NOT an autonomous agent…" into a "Scope" or "When NOT to use" section in the body.
- `receiving-plan-review`: Merge the two opening sentences into one, or keep the first and move "Core principle" into a labeled section.
- `testing-vitest`: Keep the first sentence. Move "Before writing any tests…" into step 1 of the workflow.

- [ ] **Step 3: Commit**

```bash
git add skills/crafting-commits/SKILL.md skills/generating-tasks/SKILL.md skills/receiving-plan-review/SKILL.md skills/testing-vitest/SKILL.md
git commit -m "fix(crafting-commits,generating-tasks,receiving-plan-review,testing-vitest): trim body openers to single sentence"
```

---

## Task 11: Description NITs — `generating-tasks`, `picking-up-task`

**Files:**
- Modify: `skills/generating-tasks/SKILL.md`
- Modify: `skills/picking-up-task/SKILL.md`

- [ ] **Step 1: Read both files**

Read each in full.

- [ ] **Step 2: Fix `generating-tasks` description**

Remove "Does not gather requirements or write implementation code" — scope delimiting belongs in the body. Keep trigger phrases only.

- [ ] **Step 3: Fix `picking-up-task` description**

Remove "Do not trigger automatically" — this is an operational instruction to the dispatch mechanism, not a trigger phrase. If the intent is to prevent auto-triggering, the correct signal is in how the trigger phrases are phrased (make them specific enough that they only fire on explicit user invocation).

- [ ] **Step 4: Commit**

```bash
git add skills/generating-tasks/SKILL.md skills/picking-up-task/SKILL.md
git commit -m "fix(generating-tasks,picking-up-task): remove scope-delimiting clauses from descriptions"
```

---

---

## Task 12: Migrate all artifact paths to `local-dev/tickets/`

**Files:**
- Modify: `skills/picking-up-task/SKILL.md`
- Modify: `skills/fetching-tickets/SKILL.md`
- Modify: `skills/planning-from-ticket/SKILL.md`
- Modify: `skills/generating-tasks/SKILL.md`
- Modify: `skills/reviewing-plan/SKILL.md`
- Modify: `skills/implementing-tasks/SKILL.md`
- Modify: `README.md`

**Canonical paths after this task:**
- Ticket file: `local-dev/tickets/TICKET-KEY/TICKET-KEY.md`
- Plan file: `local-dev/tickets/TICKET-KEY/PLAN-TICKET-KEY.md`
- Images subdirectory: `local-dev/tickets/TICKET-KEY/images/`

**Interfaces:**
- All six skills reference the same root — `local-dev/tickets/` — no skill uses `tickets/` bare anymore
- `picking-up-task` adds a one-time setup step to ensure `local-dev/` is in the developer's global gitignore

- [ ] **Step 1: Read all six skill files and README**

Read each file in full to find every occurrence of the old path patterns:
- `tickets/TICKET-KEY/` or `tickets/PROJ-123/` or `tickets/PROJ-42/`
- Any bare `tickets/` root reference

- [ ] **Step 2: Global find-and-replace in each skill file**

For each skill file, replace:
- `tickets/` → `local-dev/tickets/` (all occurrences, including example paths like `tickets/PROJ-123/PROJ-123.md`)

Verify no bare `tickets/` remains after replacement.

- [ ] **Step 3: Add global gitignore setup step to `picking-up-task`**

In the "Workspace setup" section of `picking-up-task`, add a one-time check before the branch creation steps:

```markdown
**One-time setup (first run only):** Ensure `local-dev/` is excluded from git globally so ticket and plan files are never accidentally committed to any project.

Check whether `local-dev` is already in the global gitignore:
```bash
grep -q 'local-dev' "$(git config --global core.excludesfile 2>/dev/null || echo ~/.gitignore_global)" 2>/dev/null \
  && echo "already excluded" \
  || echo "local-dev/" >> "${$(git config --global core.excludesfile):-~/.gitignore_global}"
```
If the global excludes file does not exist yet, create it:
```bash
echo "local-dev/" >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```
```

- [ ] **Step 4: Update README quickstart paths**

In the README quickstart section, replace all example paths:
- `tickets/PROJ-123/PROJ-123.md` → `local-dev/tickets/PROJ-123/PROJ-123.md`
- `tickets/PROJ-123/PLAN-PROJ-123.md` → `local-dev/tickets/PROJ-123/PLAN-PROJ-123.md`

- [ ] **Step 5: Commit all files**

```bash
git add skills/picking-up-task/SKILL.md skills/fetching-tickets/SKILL.md skills/planning-from-ticket/SKILL.md skills/generating-tasks/SKILL.md skills/reviewing-plan/SKILL.md skills/implementing-tasks/SKILL.md README.md
git commit -m "feat(pipeline): migrate artifact root from tickets/ to local-dev/tickets/ and add global gitignore setup"
```

---

## Task 13: Make artifacts root configurable in `picking-up-task`

**Files:**
- Modify: `skills/picking-up-task/SKILL.md`

**Goal:** On first run per project, `picking-up-task` checks for a stored artifacts root. If none is found, it asks the developer once (defaulting to `local-dev/tickets/`) and stores the answer in `.claude/artifacts-root` in the project root. All subsequent path references in that session use the stored value.

**Storage mechanism:** `.claude/artifacts-root` — a single-line plain text file containing the root path (e.g. `local-dev/tickets` or `dev/tickets`). This file should be gitignored (skill instructs user to add it to `.gitignore`).

**Behaviour spec:**

1. At the start of Workspace Setup, check for `.claude/artifacts-root`:
   - If it exists: read the value and use it as `ARTIFACTS_ROOT` for all path construction in this run
   - If it does not exist: ask the developer: *"Where should ticket and plan files go? (default: `local-dev/tickets`)"* — accept their answer or Enter to use the default, then write the value to `.claude/artifacts-root`

2. All path construction in the skill uses `ARTIFACTS_ROOT` — e.g. `$ARTIFACTS_ROOT/TICKET-KEY/TICKET-KEY.md`

3. After writing `.claude/artifacts-root`, instruct the developer to add it to `.gitignore` if they want it project-local:
   ```bash
   echo ".claude/artifacts-root" >> .gitignore
   ```
   Or to commit it if the whole team should share the same root.

**Invariant:** The default, if the developer presses Enter, is `local-dev/tickets` — consistent with Task 12.

- [ ] **Step 1: Read the file**

Read `skills/picking-up-task/SKILL.md` in full to understand the current Workspace Setup section structure.

- [ ] **Step 2: Add the artifacts root check to Workspace Setup**

Insert the following block at the very start of the Workspace Setup section (before the One-time global gitignore setup block from Task 12):

```markdown
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
```

- [ ] **Step 3: Update all hardcoded `local-dev/tickets/` path references in the body**

Replace every hardcoded `local-dev/tickets/` path in the skill body with the variable form `$ARTIFACTS_ROOT/` so that the skill's own examples are consistent with the configured value.

- [ ] **Step 4: Commit**

```bash
git add skills/picking-up-task/SKILL.md
git commit -m "feat(picking-up-task): ask for artifacts root on first run, default local-dev/tickets, store in .claude/artifacts-root"
```

---

## Self-Review

**Spec coverage:**
- B1 PROCEED marker → Task 1 ✓
- B2 start-task deprecated name → Task 2 ✓
- B3 generating-design-doc description → Task 3 ✓
- S1 model: inherit missing (8 skills) → Tasks 3, 4, 5, 9 ✓ (all 8 covered)
- S2 reviewing-plan description → Task 4 ✓
- S3 planning-from-ticket description → Task 5 ✓
- S4 self-review gate (generating-design-doc + planning-from-ticket) → Tasks 3, 5 ✓
- S5 reviewing-code report gate → Task 6 ✓
- S6 auto mode invariants (5 skills) → Task 7 ✓
- S7 implementing-tasks canonical name → Task 8 ✓ (will be superseded by Task 12 path migration)
- N1 color/license (8 skills) → Tasks 3, 4, 5, 8, 9 ✓ (all covered)
- N2 description NITs (3 skills) → Tasks 8, 11 ✓
- N3 body opener NITs (5 skills) → Task 10 ✓
- N4 generating-design-doc "When to use" section → Task 3 ✓
- N5 picking-up-task "Do not trigger automatically" → Task 11 ✓
- Artifact path migration (6 skills + README) → Task 12 ✓
- Configurable artifacts root with first-run prompt → Task 13 ✓

**Placeholder scan:** No TBDs, all steps contain specific instructions, all git commands are concrete.

**Type consistency:** No code types involved — all edits are YAML frontmatter and Markdown prose. Skill names used in commit messages match directory names exactly.
