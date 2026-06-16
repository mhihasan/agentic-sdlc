---
name: planning-from-ticket
description: "Use when the user points to a local Jira ticket or spec markdown file and wants an implementation plan written to a PLAN file beside it. Triggers on phrases like 'read this ticket and make a plan', 'plan PROJ-1234', 'write an implementation plan for this spec'. Assumes the ticket is already on disk — does not fetch from Jira."
license: MIT
---

# Planning From Ticket

Turn a **local ticket or spec file** into a reviewed implementation plan written **beside it** as `PLAN-<KEY>.md`.

You are a thin orchestrator. You own the read → explore → decide → review → write workflow. You delegate the design dialogue to the brainstorming skill. You do NOT fetch tickets from a tracker (the ticket is already on disk), and you do NOT write implementation code — you produce exactly one plan file.

## Core Principle

**The user must approve the plan in chat before the file is written.** "Write a plan to a file" is a request for a *reviewed* plan, not a request to skip review. Writing the file is the LAST step, never the first deliverable.

**REQUIRED SUB-SKILL:** Use superpowers:brainstorming for the clarifying-question and design-proposal dialogue. Do not re-implement that conversation here — invoke it for the thinking, and use this skill for the ticket-specific workflow and the file output.

## When to Use

- The user gives a path to a ticket/spec markdown file and asks for a plan.
- "Read PROJ-1234 and produce an implementation plan."
- "Plan out this spec before we code."

**When NOT to use:**
- The ticket isn't on disk yet → fetch it first (a tracker-to-markdown skill), then use this.
- The user wants to start coding now → this skill stops at the plan file.
- Planning a whole project/epic spanning many features → use a project-level planning skill.

## Workflow

Create a TodoWrite item for each step and complete them in order. Do not collapse or skip steps.

### 1. Read the source completely

- Read the ticket/spec markdown end to end.
- Read EVERY image it references (screenshots, mockups, annotated UI). Tickets routinely encode the real acceptance criteria inside images — the text alone is not the whole spec.
- Capture: the ticket key, the acceptance criteria, and any "Questions" the ticket itself raises.

### 2. Explore the codebase before proposing anything

- Dispatch a read-only exploration agent to map the files, components, and patterns the work touches.
- VERIFY the agent's key claims by reading the actual files yourself. Never plan against an unread summary — a wrong assumption here propagates into every task downstream.
- Note where the ticket may already be partly implemented (check the relevant files and recent commits), so the plan reflects reality rather than assuming from-scratch work.

### 3. Surface decisions — do not guess

Build the open-questions list from three sources:
- Ambiguities in the ticket text.
- The ticket's own "Questions" section, if any.
- Decisions the **codebase forces** that the ticket couldn't anticipate (e.g. "this is a single shared component, so a per-instance value needs a conditional", or "the ticket says verify-only but the code shows it's unimplemented").

Resolve them with AskUserQuestion (this is the brainstorming dialogue). Lead each option list with your recommendation, labeled "(Recommended)". If after honest review there are genuinely zero open questions, state that explicitly and continue.

### 4. Present the plan in chat — REVIEW GATE

Present the full plan in chat and get explicit approval **before writing any file.** Cover:
- Goal, key findings from exploration, the change list by file, any mapping table the ticket specifies (keys/values/identifiers/copy), the testing approach, and explicit out-of-scope items.

If the user requests changes, revise and re-present. Only proceed to step 5 once they approve.

### 5. Write the plan file beside the ticket

- Write to `<ticket-dir>/PLAN-<KEY>.md`, where `<KEY>` is the ticket key (e.g. `PLAN-PROJ-1234.md`) and `<ticket-dir>` is the directory containing the source file.
- If that file already exists, ask before overwriting.
- Structure the file to match exactly what the user approved in chat.

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

## Red Flags — STOP

- About to write the plan file without presenting it in chat → STOP. Present and get approval first.
- Thinking "the user said write a file, so review doesn't apply" → STOP. "Write a plan" means a *reviewed* plan; the file is the last step.
- Planning against an exploration summary you never opened → STOP. Read the files.
- Skipped the ticket's images because it "looked simple" → STOP. Read every image.
- Guessing on an ambiguous requirement → STOP. Ask with AskUserQuestion.
- Tempted to fetch the ticket from the tracker → wrong skill. The ticket is already on disk.

## Common Mistakes

| Mistake | Reality / Fix |
|---|---|
| Writing the file before review | "Write a plan" = reviewed plan. The chat review gate is mandatory; the file is the final step. |
| Treating "write to a file" as license to skip approval | The instruction names the *output*, not permission to skip the *process*. |
| Ignoring referenced images | ACs frequently live in images. Read every one. |
| Asking zero questions on an ambiguous ticket | If the ticket or codebase is ambiguous, surface it. Silence is a guess. |
| Assuming from-scratch work | Check whether it's already partly built; frame the plan against reality. |
| Over-scoping | Plan only what the ticket asks; everything else goes under Out of Scope. |
| Re-implementing the design dialogue | Delegate the clarifying questions to superpowers:brainstorming. |
