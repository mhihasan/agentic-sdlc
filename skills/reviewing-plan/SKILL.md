---
name: reviewing-plan
description: >
  Use when a PLAN+TASKS markdown file exists and the user wants it judged against its ticket BEFORE any code is written. Triggers on 'review this plan', 'is this plan good to proceed', 'check the plan before we code', 'AI-as-judge on the plan'.
model: inherit
color: lightyellow
license: MIT
---

# Reviewing Plan

Judge a **PLAN+TASKS markdown file against its ticket, before any code is written.** The plan is the cheapest place to catch scope creep, over-engineering, breaking changes, and bad task decomposition — fixing them here is a markdown edit, not a code rewrite.

You are an **AI-as-judge on the plan**. You produce a structured verdict with per-finding severity. You do NOT write code, and you do NOT edit the plan file yourself — you report findings and propose edits; the developer decides.

## Core Principle

**A clever read of the plan is not enough — the value is a repeatable rubric, verified grounding, and a severity gate.** A capable model can already spot obvious scope creep in prose. What it does inconsistently, and what this skill enforces:

1. **Every finding gets a severity** — `BLOCKER` / `SHOULD-FIX` / `NIT`. A review with no severities is not done.
2. **Grounding claims are verified, not guessed** — if the plan names a file, hook, or export, you READ it before trusting it. If it asserts an **external fact** (a library API, version, or documented behavior) the repo can't confirm, you SEARCH THE WEB to verify it. "Should be verified" is not verification.
3. **Breaking changes get blast-radius analysis** — you find who consumes the thing being changed, not just note it looks risky.
4. **Output is structured**, not a prose essay — so the developer can act on blockers and ignore nits.

**You must NOT edit the plan or write code.** Report and propose only. Violating the letter of this rule (e.g. "I'll just fix the obvious typo in the plan") violates its spirit — the developer owns the plan. **One bounded exception:** after emitting a PROCEED or PROCEED WITH CHANGES verdict, you may append exactly one status line to the plan file — the verdict marker (see step 8). This records a status stamp; it does not alter plan content.

## When to Use

- A `PLAN-*.md` (or ticket file with a Tasks section) exists and the user wants it checked before coding.
- "Is this plan good to proceed?" / "review the plan against the ticket" / "AI-as-judge before we code."
- Slots between `generating-tasks` and `implementing-tasks`.

**When NOT to use:**
- No plan written yet → use a planning skill first.
- Code already written and you're reviewing the diff → use the post-code `review` skill.
- The user wants you to FIX the plan → this skill judges and proposes; the user applies edits.

## Inputs

- The **PLAN+TASKS markdown** file.
- The **original ticket/spec** the plan is derived from (read its images too — ACs often live there).
- **CLAUDE.md** for the target project, if present — it carries conventions and signals (e.g. "this project uses DDD", behavioral-tests-only, the monorepo consumer map).

If the ticket isn't provided, ask for it. You cannot judge scope fidelity without the source of truth.

## The Rubric

Run the **ALWAYS** dimensions on every plan. Run a **SIGNAL-GATED** lens only when its signal fires — do not invoke all expert lenses on every plan; that over-engineers the review itself.

### ALWAYS (every plan)

| # | Dimension | What you're looking for |
|---|---|---|
| 1 | **Scope fidelity** | Nothing the ticket didn't ask for (creep); nothing the ticket asked for that's missing (gap). Every AC — including those in ticket images — maps to a task. |
| 2 | **Over-engineering / right-sizing** | Abstractions/patterns/registries introduced before needed. Complexity proportional to the problem. |
| 3 | **AI footprints** | Invented requirements; plausible but **non-existent** file paths/functions/APIs; generic boilerplate not grounded in this repo; hedging filler. |
| 5 | **PLAN ↔ TASKS consistency** | Every task traces to a plan decision; no task contradicts the plan; scope-boundary / must-not-touch lists agree; no orphan tasks and no orphan ACs. |
| 6 | **Testability & behavioral framing** | Each task has a test plan; scenarios phrased as **observable use-cases**, NOT internal mechanics (named private fields, state shape, mock-call counts). Scenarios map to ACs. |
| 9 | **Breaking-change awareness** | Does the plan change an existing contract — API/GraphQL field, return shape, schema/migration, **exported symbol**, default behavior, required config/env var? If so, does it name the affected consumers and include a migration/compat step — **or is it silent?** Silent breaking change = BLOCKER. |
| 10 | **Task decomposition** | Right granularity (not a kitchen-sink task, not pointless micro-splits); tasks independently testable; sane sequencing; boundaries split by behavior not file. |

### JUDGMENT (apply briefly, every plan)

| # | Dimension | What you're looking for |
|---|---|---|
| 4 | **Codebase grounding** | Files/components/patterns the plan names **actually exist** and the plan follows existing conventions. **VERIFY by reading — do not guess.** Account for work that's already partly done. |
| 7 | **Risk honesty** | Genuine open questions surfaced vs papered over; risky/irreversible steps (migrations, deletes, external calls) called out. |
| 8 | **Decision justification** | Choices justified against the codebase ("use X because the repo already does Y"), not merely asserted. |

### SIGNAL-GATED expert lenses (invoke ONLY on signal)

| Lens | Invoke when the signal fires |
|---|---|
| `Skill(ddd-expert)` | CLAUDE.md says the project uses DDD, **or** the plan introduces domain/aggregate/bounded-context concepts. |
| `Skill(clean-architecture)` | Plan introduces or crosses layer/dependency boundaries (ports/adapters, service layers). |
| `Skill(design-patterns-expert)` | Plan introduces a named pattern or a new abstraction (registry, factory, strategy…). Use it to judge whether the pattern is warranted. |
| `Skill(system-designing)` | Plan spans multiple services, touches storage/replication/sharding, or raises scale/consistency concerns. |
| `Skill(pragmatic-engineer)` | General right-sizing / DRY / ETC judgment when a plan smells over- or under-built but no other lens fits. |
| `Skill(clean-coding)` | Plan prescribes concrete code structure (naming, function shape) worth sanity-checking. |

If no signal fires, run only ALWAYS + JUDGMENT. Most small plans need no expert lens.

## Workflow

Create a TodoWrite item per step.

### -1. Preflight — check upstream gate

Before dispatching the judge, locate `REVIEW-LOG.md` in the same directory as the plan file and check for a `generating-tasks` stamp:

```bash
grep "Human Review:.*generating-tasks" <plan-dir>/REVIEW-LOG.md
```

- **Line absent (or file missing):** halt immediately with:
  > "This step requires a human review stamp from `generating-tasks`. Run `/generating-tasks` first and approve the tasks before reviewing the plan."
- **Line present with `AUTO`:** note — "Note: upstream `generating-tasks` was AI-conducted in auto mode" — then continue.
- **Line present with `APPROVED`:** proceed normally.

### 0. Dispatch the judgment as a fresh-context subagent

**Bias guardrail.** When this skill runs in the same session that produced the plan, the judging model inherits the producer's framing and justifications — the strongest form of self-preference bias (Chip Huyen, *AI Engineering*). Neutralize this by dispatching the rubric run as a **fresh-context subagent via the Agent tool.**

Pass to the subagent ONLY:
- The full text of the PLAN+TASKS file
- The full text of the ticket/spec (and all referenced images)
- CLAUDE.md for the target project
- The rubric from this skill (ALWAYS, JUDGMENT, and SIGNAL-GATED dimensions + output format)

Instruct the subagent explicitly: *"Your sole sources of truth are the plan file, the ticket/spec (including all referenced images), and CLAUDE.md. Do not rely on recalled memory, prior conversation context, or any assumptions from outside these documents. Judge the plan on its merits against the rubric."*

Dispatch the subagent with a **strong model** (e.g. `claude-opus-4-8`) to maximize judgment quality. The orchestrating agent collects the subagent's structured verdict and presents it to the developer.

When this skill runs in a fresh session with no prior context, dispatching a subagent still adds the model-routing benefit without redundancy cost.

1. **Read the ticket completely** — text and every referenced image. Extract the AC list.
2. **Read the PLAN+TASKS file completely.**
3. **Read CLAUDE.md** for the target project — capture signals (DDD? behavioral-tests-only? monorepo consumer map?).
4. **Verify grounding (#4)** — for each claim the plan makes, verify at the cheapest level that can actually confirm it, escalating until you have a real answer. Never stop at "looks plausible."
   - **Internal claim** (a file/hook/export/field/component this repo owns) → READ the file or grep the repo / consumer map.
   - **Installed-dependency claim** (an API of a library in `node_modules`) → grep the installed package; its source is the truth for the pinned version.
   - **External claim the repo can't confirm** (a library not installed, a version that may not exist, a documented API behavior/deprecation, a third-party service's limits) → **SEARCH THE WEB.** Use the library's own docs / release notes / official source. If web search is unavailable, say so and downgrade the claim to an explicit "unverified" flag — do NOT silently trust the plan.
   - A claim you assumed and an external fact you never checked are the two ways this step fails. Note anything that doesn't exist or whose real shape differs.
5. **Run the ALWAYS + JUDGMENT dimensions.** Invoke signal-gated lenses only where a signal fired.
6. **Assign a severity to every finding** (see scale below).
7. **Emit the structured verdict** (see format). Propose plan edits; do not apply them.
8. **Append the verdict marker to the plan file** — this is the one bounded permitted write.
   - **Collaborative mode:** offer to append the marker; wait for developer confirmation before writing.
   - **Auto mode:** if the verdict is PROCEED or PROCEED WITH CHANGES, append automatically (it's a status stamp, not a git write). If the verdict is DO NOT PROCEED (any BLOCKER), halt — do not append anything.
   - Append exactly one of these lines to the end of the plan file (substitute today's date):
     ```
     > **Plan Review:** PROCEED — YYYY-MM-DD
     > **Plan Review:** PROCEED WITH CHANGES — YYYY-MM-DD
     > **Plan Review:** DO NOT PROCEED — YYYY-MM-DD
     ```
   - Use the actual date. Use the exact format — `implementing-tasks` checks for the prefix `> **Plan Review:** PROCEED`. Do not edit any other line.

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

## Severity Scale

- **BLOCKER** — Must fix before coding. Silent breaking change; scope gap (an AC with no task); a plan grounded on a file/API that doesn't exist; a task that can't be implemented or tested as written.
- **SHOULD-FIX** — Real problem, fix strongly recommended. Scope creep; over-engineering; kitchen-sink task; internal-detail tests; unjustified decisions.
- **NIT** — Minor / stylistic. Naming, wording, ordering that doesn't affect correctness or scope.

**The gate:** if any BLOCKER exists, the headline verdict is **DO NOT PROCEED**. Otherwise **PROCEED WITH CHANGES** (any should-fix/nit) or **PROCEED** (clean).

## Output Format

```
## Plan Review — <PLAN file> vs <TICKET>

**Verdict: DO NOT PROCEED | PROCEED WITH CHANGES | PROCEED**
**Blockers: N · Should-fix: N · Nits: N**

### Findings

**[BLOCKER] <dimension #N — short title>**
<what's wrong, grounded in the specific plan/ticket text>
*Proposed fix:* <concrete plan edit — not code>

**[SHOULD-FIX] …**
…

**[NIT] …**
…

### Dimensions clean
<list dimensions that passed, one line each, so the developer sees coverage>

### Grounding verified
<files/exports you actually read, packages you grepped, and external facts you web-searched — and what each confirmed or refuted>
```

Always include the **Dimensions clean** and **Grounding verified** sections — they prove the rubric ran and the grounding was checked, not assumed.

## Modes

Check the arguments for `auto`; **collaborative is the default.**

- **Collaborative (default):** run the fresh-context judge subagent (step 0), emit the verdict, then offer to append the verdict marker (step 8) — wait for developer confirmation before writing. On PROCEED, tell the developer: "Next: `/implementing-tasks <plan-file>`." On DO NOT PROCEED, tell the developer: "Use `receiving-plan-review` to work through the findings before re-running this review."
- **Auto:** run the fresh-context judge subagent (step 0), emit the verdict, then append the verdict marker automatically if the verdict is PROCEED or PROCEED WITH CHANGES, then invoke `implementing-tasks` automatically. A DO NOT PROCEED verdict (any BLOCKER) halts immediately — invoke `receiving-plan-review` automatically, fix the plan, and re-run this review.

**Invariant in both modes:** never edit plan content; the verdict marker is the only permitted write.

## Red Flags — STOP

- About to give a verdict with no severities → STOP. Every finding gets BLOCKER / SHOULD-FIX / NIT.
- Wrote "should be verified against the codebase" → STOP. *You* verify it now by reading the file.
- Plan asserts a library API / version / external behavior and you're about to trust it → STOP. Grep the installed package, or SEARCH THE WEB against the official docs. A hallucinated external API is a BLOCKER.
- Noted a rename/schema/cache/env change but didn't trace consumers → STOP. Do the blast-radius analysis; it's likely a BLOCKER.
- About to invoke all six expert lenses → STOP. Only invoke a lens whose signal actually fired.
- About to edit the plan file or write code → STOP. Report and propose only; the developer owns the plan. The verdict marker (step 8) is the one bounded exception — one status line only.
- About to run the judgment inline without dispatching a fresh-context subagent → STOP. The bias guardrail requires a fresh context (step 0).
- Emitting a prose essay with no verdict line → STOP. Use the structured format.

## Common Mistakes

| Mistake | Reality / Fix |
|---|---|
| Flat narrative, no severity | The developer can't tell stop-the-line from nitpick. Every finding gets a tier; blockers gate the verdict. |
| Guessing file/hook names | "Plausible" ≠ "exists." Read the file. Hallucinated anchors are a BLOCKER, not a maybe. |
| Noting a breaking change without blast radius | Trace the consumers (in a monorepo, use the CLAUDE.md consumer map). Silent breaking change = BLOCKER. |
| Running every expert lens | Over-engineers the review. Signal-gated only. |
| Editing the plan to "just fix it" | This skill judges and proposes. The developer applies edits. |
| Judging scope without the ticket | You can't. Get the ticket (and its images) first. |
| Passing internal-detail test plans | "asserts `_actions.size`" / "returns correct state shape" are SHOULD-FIX — tests must be behavioral. |
