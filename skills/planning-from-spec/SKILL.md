---
name: planning-from-spec
description: >
  Use when the user has a spec, ticket, or requirement doc (local file or
  pasted text) and wants an implementation plan. Triggers on phrases like
  'make a plan for this', 'plan PROJ-1234', 'write an implementation plan',
  'turn this spec into a plan'.
model: inherit  # producer skill, not a judge — follows repo default per CLAUDE.md
color: lightblue
license: MIT
---

# Planning From Spec

Turn a **local ticket or spec file** into a reviewed implementation plan written **beside it** as `PLAN-<KEY>.md`.

You own the entire read → explore → decide → review → write workflow yourself. You do NOT fetch tickets from a tracker (the ticket is already on disk), and you do NOT write implementation code — you produce exactly one plan file.

## Core Principle

**A plan must be reviewed before it is trusted.** "Write a plan to a file" is a request for a *reviewed* plan, not a request to skip review. Writing the file is the LAST step, never the first deliverable.

In **collaborative mode** (default), the reviewer is the developer — present the plan in chat and get explicit approval before writing any file. In **auto mode**, the chat-gate is replaced by self-review (step 4) plus the independent `reviewing-plan` judge — the discipline is identical, the reviewer changes. Auto mode does NOT mean "write without review." Whether the design is over-engineered, or a breaking change is acceptably handled, is `reviewing-plan`'s call — do not self-adjudicate it in step 4.

## Questioning & Design Discipline

Run the decision dialogue (step 3) and the plan presentation (step 5) by these rules:

- **One question at a time.** Don't batch questions; ask, get the answer, then ask the next.
- **Prefer multiple-choice.** Easier to answer than open-ended; lead every option list with your recommended option, labeled "(Recommended)".
- **Propose 2–3 approaches when the design is non-obvious.** Give trade-offs; lead with your recommendation and the reason for it. Don't present a single approach as if it were the only one, and don't bury the recommendation.
- **Present the plan in sections, scaled to complexity.** Confirm each section before moving to the next, so the developer can redirect early instead of at the end.
- **YAGNI.** Plan only what the ticket asks for. Everything else goes under Out of Scope.

## Plan Rigor

The plan body must be executable by an engineer with zero context. No placeholders:

- Never "TBD", "TODO", "implement later", "similar to above", or "handle edge cases" without the actual content.
- Exact file paths always.
- Where a step describes a change, show the change — not a description of it.
- Verification commands with their expected output, not just "run tests".
- DRY, YAGNI, TDD.

## Designing the Changes

Before listing changes by file, decide the shape of the work:

- **Focused units.** Each file/component the plan creates or touches should have one clear responsibility. Prefer smaller, focused files over large ones that do too much — a file that has grown unwieldy is a signal it's doing too much.
- **Clear interfaces.** For each unit, you should be able to say what it does, how it's used, and what it depends on. If a consumer can't understand a unit without reading its internals, the boundary needs work.
- **Follow existing patterns.** In an existing codebase, match the structure and conventions already there. Don't unilaterally restructure — but if a file you're modifying has grown unwieldy, a targeted split is reasonable.
- **No unrelated refactoring.** Stay focused on what the ticket asks for. Out-of-scope cleanup goes under Out of Scope, not into this plan.

## When to Use

- The user gives a path to a ticket/spec markdown file and asks for a plan.
- "Read PROJ-1234 and produce an implementation plan."
- "Plan out this spec before we code."

**When NOT to use:**
- The ticket isn't on disk yet → fetch it first with `fetching-tickets`, then use this.
- The user wants to start coding now → this skill stops at the plan file.
- Planning a whole project/epic spanning many features → use a project-level planning skill.

**Next step:** once the plan file is written, the developer typically runs `generating-tasks` to add TDD task specs to it.

## Workflow

Create a TodoWrite item for each step and complete them in order. Do not collapse or skip steps.

### 0. Preflight — check upstream gate

Before any other work, locate `REVIEW-LOG.md` in the same directory as the ticket file (i.e. `<ticket-dir>/REVIEW-LOG.md`) and check for a `picking-up-task` stamp:

```bash
grep "Human Review:.*picking-up-task" <ticket-dir>/REVIEW-LOG.md
```

- **Line absent (or file missing):** halt immediately with:
  > "This step requires a human review stamp from `picking-up-task`. Run `/picking-up-task` first and approve the ticket before planning."
- **Line present with `AUTO`:** note in output — "Note: upstream `picking-up-task` was AI-conducted in auto mode" — then continue.
- **Line present with `APPROVED`:** proceed normally.

### 1. Read the source completely

- Read the ticket/spec markdown end to end.
- Read EVERY image it references (screenshots, mockups, annotated UI). Tickets routinely encode the real acceptance criteria inside images — the text alone is not the whole spec.
- Capture: the ticket key, the acceptance criteria, and any "Questions" the ticket itself raises.
- **Scope check.** If the spec spans multiple independent subsystems, flag it before planning details — recommend one plan per subsystem, each producing working, testable software on its own, rather than a single mega-plan. Don't refine the details of work that should be decomposed first.

### 2. Explore the codebase before proposing anything

- Dispatch a read-only exploration agent to map the files, components, and patterns the work touches.
- VERIFY the agent's key claims by reading the actual files yourself. Never plan against an unread summary — a wrong assumption here propagates into every task downstream.
- Note where the ticket may already be partly implemented (check the relevant files and recent commits), so the plan reflects reality rather than assuming from-scratch work.

### 3. Surface decisions — do not guess

Build the open-questions list from three sources:
- Ambiguities in the ticket text.
- The ticket's own "Questions" section, if any.
- Decisions the **codebase forces** that the ticket couldn't anticipate (e.g. "this is a single shared component, so a per-instance value needs a conditional", or "the ticket says verify-only but the code shows it's unimplemented").

Resolve them with AskUserQuestion, following the Questioning & Design Discipline above — one question at a time, multiple-choice, recommendation-led, and propose 2–3 approaches where the design is non-obvious. If after honest review there are genuinely zero open questions, state that explicitly and continue.

### 4. Self-review the draft — before the developer sees it

**STOP before presenting to the developer.** Check every item — fix failures before showing the plan:

| Check | Pass condition |
| --- | --- |
| No placeholders | Zero "TBD", "TODO", "similar to above", or "as needed" in the plan body |
| Decisions are complete | Every open question from step 3 has a recorded answer with rationale |
| Scope is tight | Nothing in the change list goes beyond what the ticket explicitly asks for |
| Verification is concrete | Every command has an expected output, not just "run tests" |
| Grounded in reality | Every file path and pattern reference was read in step 2 — no assumptions |
| Grounding verified | Every file path / function / API named in the plan was actually read or grepped in step 2 — no plausible-but-unverified references. Objective check: "did you read it, yes/no" |
| Interfaces consistent | Names, signatures, and types referenced across the change list match — no `clearLayers()` in one file and `clearFullLayers()` in another |
| Out-of-scope is explicit | At least one item listed; "N/A" is only valid for trivial single-line tickets |

If any check fails, fix the plan before proceeding. Do not present a draft you know has gaps — the developer's review is for judgment calls, not for catching incomplete work.

### 5. Present the plan in chat — REVIEW GATE

Present the full plan in chat and get explicit approval **before writing any file.** Follow the Questioning & Design Discipline: present in sections scaled to complexity, confirm each before moving on, apply YAGNI. Cover:
- Goal, key findings from exploration, the change list by file, any mapping table the ticket specifies (keys/values/identifiers/copy), the testing approach, and explicit out-of-scope items.

If the user requests changes, revise and re-present. Only proceed to step 6 once they approve.

### 6. Write the plan file beside the ticket

- Write to `<ticket-dir>/PLAN-<KEY>.md`, where `<KEY>` is the ticket key (e.g. `PLAN-PROJ-1234.md`) and `<ticket-dir>` is the directory containing the source file.
- If that file already exists, ask before overwriting.
- Structure the file to match exactly what the user approved in chat.

After writing the plan file, open the Review Gate.

**Collaborative mode (default):** The plan was already presented and approved in step 5 — that approval is the gate. Write (or upsert) this line in `<ticket-dir>/REVIEW-LOG.md`:

```
> **Human Review:** APPROVED — YYYY-MM-DD — planning-from-spec
```

Then update `.agentic-sdlc/active/<KEY>.md` — read the file, set `step: generating-tasks` and `plan: <ticket-dir>/PLAN-<KEY>.md`, write back:

```
key: PROJ-42
step: generating-tasks
task:
branch: feat/PROJ-42/add-dark-mode
ticket: local-dev/tickets/PROJ-42/PROJ-42.md
plan: local-dev/tickets/PROJ-42/PLAN-PROJ-42.md
```

If `.agentic-sdlc/active/<KEY>.md` does not exist (skill invoked directly, not via `/sdlc-start`), skip silently — active state tracking is optional.

Then ask: > Ready to proceed? `/generating-tasks <path>` (yes/no)

On yes, invoke `/generating-tasks <path>`.

**Auto mode:** Write the stamp automatically with `AUTO`:

```
> **Human Review:** AUTO — YYYY-MM-DD — planning-from-spec
```

## Plan File Structure

Scale each section to the work; omit what doesn't apply.

- **Title + ticket key + branch** (if a branch exists)
- **Goal** — one paragraph, the user-facing outcome
- **Key findings** — what exploration revealed that shapes the plan
- **Decisions** — each confirmed decision with its rationale
- **Changes by file** — the concrete edit list
- **Mapping table** — keys / values / identifiers / copy, where the ticket specifies them
- **Testing** — the test approach (behavioral unless the project says otherwise)
- **Verification** — the commands that must pass (build / lint / test)
- **Out of scope** — what this deliberately does NOT do

## Modes

Check the arguments for `auto`; **collaborative is the default.**

- **Collaborative (default):** Resolve open questions via AskUserQuestion; present the full plan in chat; wait for explicit developer approval before writing the file. The developer is the reviewer.
- **Auto:** Resolve decisions using the recommended option where defensible; skip the chat presentation; write the file after step 4 self-review passes. Stop only on unresolvable ambiguity (when no defensible recommended option exists). The plan must still clear `reviewing-plan` before `implementing-tasks` starts — the chat-gate is replaced by the independent judge, not dropped.

**Invariants in both modes:** never overwrite an existing PLAN file without asking; never start implementation from this skill.

## Red Flags — STOP

- About to present the plan without self-reviewing it first → STOP. Run step 4 checks; fix failures before the developer sees the draft.
- About to write the plan file without presenting it in chat → STOP. Present and get approval first.
- Thinking "the user said write a file, so review doesn't apply" → STOP. "Write a plan" means a *reviewed* plan; the file is the last step.
- Planning against an exploration summary you never opened → STOP. Read the files.
- Skipped the ticket's images because it "looked simple" → STOP. Read every image.
- Guessing on an ambiguous requirement → STOP. Ask with AskUserQuestion.
- Tempted to fetch the ticket from the tracker → wrong skill. The ticket is already on disk.

## Common Mistakes

| Mistake | Reality / Fix |
| --- | --- |
| Writing the file before review | "Write a plan" = reviewed plan. The chat review gate is mandatory; the file is the final step. |
| Treating "write to a file" as license to skip approval | The instruction names the *output*, not permission to skip the *process*. |
| Ignoring referenced images | ACs frequently live in images. Read every one. |
| Asking zero questions on an ambiguous ticket | If the ticket or codebase is ambiguous, surface it. Silence is a guess. |
| Assuming from-scratch work | Check whether it's already partly built; frame the plan against reality. |
| Over-scoping | Plan only what the ticket asks; everything else goes under Out of Scope. |
| Skipping the questioning discipline | Own it here: one question at a time, multiple-choice, recommendation-led, propose 2–3 approaches before settling. |
