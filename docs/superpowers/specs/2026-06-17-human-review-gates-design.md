# Human Review Gates — Design Spec

**Date:** 2026-06-17
**Status:** Draft

## Problem

The agentic pipeline produces several artifacts (plan, tasks, code, commits) and already has AI-as-judge review steps. However, no skill enforces an explicit human approval before the next step begins. Collaborative mode pauses conversationally, but there is no hard gate and no audit trail of what a human actually approved.

## Goal

Every artifact boundary in the pipeline requires an explicit human approval before the next skill can run. The approval is stamped to a log file so it is auditable. Auto mode is not blocked — it stamps automatically and continues — but the audit trail distinguishes human approvals from AI-conducted ones.

---

## Section 1 — The Gate Contract

Every skill that produces an artifact gains a **Review Gate** at the end of its output.

**Collaborative mode (default):**
The skill halts after presenting its artifact summary and prints:
> "Review the [artifact] above. Type **`approve`** to stamp it and proceed, or describe what needs changing."

It waits. Nothing downstream can run. On `approve`, the skill appends a stamp line to `REVIEW-LOG.md` and tells the developer what the next step is. Any response other than `approve` is treated as a change request — the skill re-runs its output from that feedback. No stamp is written until `approve` is received.

**Auto mode:**
The skill appends the stamp automatically with `[auto]` marker and continues to the next step without pausing. The audit trail is still written — the stamp records that the review was AI-conducted, not human-conducted.

---

## Section 2 — The Stamp Format

All stamps live in a single log file per ticket:

```
local-dev/tickets/PROJ-123/REVIEW-LOG.md
```

The plan file and other artifact files stay clean — no stamps are appended to them.

**Human approval (collaborative):**
```
> **Human Review:** APPROVED — YYYY-MM-DD — <step-name>
```

**Auto-conducted (auto mode):**
```
> **Human Review:** AUTO — YYYY-MM-DD — <step-name>
```

**Step names** (the value in `<step-name>`):

| Pipeline step | Step name used in stamp |
|---|---|
| `planning-from-ticket` | `planning-from-ticket` |
| `generating-tasks` | `generating-tasks` |
| `reviewing-plan` | `reviewing-plan` |
| `implementing-tasks` (per-task) | `implementing-tasks-T<n>` (e.g. `implementing-tasks-T1`, `implementing-tasks-T2`) |
| `reviewing-code` | `reviewing-code` |
| `crafting-commits` | `crafting-commits` |

**Re-runs:** If a skill is re-run after changes, it overwrites the existing line for that step name in `REVIEW-LOG.md` (grep-replace the matching line), not appends a duplicate.

**Missing log file:** If `REVIEW-LOG.md` doesn't exist, the skill creates it on first stamp write.

---

## Section 3 — Preflight Check (Downstream Skills)

Each downstream skill gains a **preflight gate check** as its first step, before any other work:

1. Locate `REVIEW-LOG.md` in the ticket directory
2. Grep for `> **Human Review:**` with the expected upstream step name
3. **If absent (or file missing):** halt immediately with:
   > "This step requires a human review stamp from `<upstream-skill>`. Run `/<upstream-skill>` first and approve the artifact before continuing."
4. **If present with `AUTO`:** continue, but note in the output that the upstream review was AI-conducted (no block, visibility only)
5. **If present with `APPROVED`:** proceed normally

**Preflight matrix:**

| Skill | Checks for stamp from |
|---|---|
| `generating-tasks` | `planning-from-ticket` |
| `reviewing-plan` | `generating-tasks` |
| `implementing-tasks` | `reviewing-plan` |
| `reviewing-code` | all `implementing-tasks-T*` stamps present (one per task in the plan) |
| `crafting-commits` | `reviewing-code` |
| `superpowers:finishing-a-development-branch` | `crafting-commits` |

---

## Section 4 — What Changes in Each Skill

Minimal additions only — no restructuring of existing logic.

**Skills that gain a Review Gate (end of skill):**

| Skill | Gate behavior |
|---|---|
| `planning-from-ticket` | Gate after plan is written |
| `generating-tasks` | Gate after tasks section is appended |
| `reviewing-plan` | Human gate wraps the existing Plan Review stamp — AI verdict runs first, then human approves |
| `implementing-tasks` | Gate after each task's tests pass, before moving to next task. Stamp uses task-scoped step name: `implementing-tasks-T<n>` (e.g. `implementing-tasks-T1`). |
| `reviewing-code` | Gate after review report is presented |
| `crafting-commits` | Existing Step 5 human confirmation becomes the formal gate; stamp added on approval |

**Skills that gain a Preflight Check (start of skill):**
All six downstream skills listed in the preflight matrix above.

**No changes to:**
- `picking-up-task` — produces a ticket file, not a reviewable artifact
- `receiving-plan-review` — remediation path, not a gate point
- `superpowers:receiving-code-review` — same
- `testing-pytest` / `testing-vitest` — sub-skills, not pipeline boundary points

---

## Section 5 — Edge Cases & Invariants

**Stamp location:** `local-dev/tickets/PROJ-123/REVIEW-LOG.md` — one file per ticket, accumulates all gate stamps. Plan and other artifact files are never stamped.

**Re-runs:** Overwrite the matching step-name line in `REVIEW-LOG.md`, not append a duplicate.

**`request-changes` flow:** Any response other than `approve` at a gate is treated as a change request. The skill uses it as revision input and re-presents the artifact. No stamp is written until `approve` is received.

**Missing artifact file:** If the artifact file can't be found during preflight, halt with a clear message distinct from a missing stamp.

**Mode detection:** Skills detect mode from their invocation argument (`auto` suffix). No argument = collaborative. Consistent with existing pattern in `crafting-commits` and `implementing-tasks`.

**AUTO visibility:** When a preflight check finds an `AUTO` stamp, the skill notes it in its output header (e.g., "Note: upstream `reviewing-plan` was AI-conducted in auto mode") but does not block.

---

## Invariants (summary)

- Collaborative mode: hard block at every artifact boundary until human types `approve`
- Auto mode: stamp written automatically (`AUTO`), pipeline continues unblocked
- `REVIEW-LOG.md` is the single source of truth for gate status; artifact files are never stamped
- Preflight always runs before any skill logic; a missing stamp is a hard halt
- Re-runs overwrite, not accumulate
- `crafting-commits` existing Step 5 gate is the implementation of the gate for that step — no duplication
