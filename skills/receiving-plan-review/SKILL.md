---
name: receiving-plan-review
description: Use when a reviewing-plan verdict is DO NOT PROCEED or PROCEED WITH CHANGES and findings need to be worked through — before editing the plan. Triggers on "address plan findings", "fix the plan review", "work through plan blockers", or when reviewing-plan emits findings. Verify each finding against the ticket and codebase before accepting it.
---

# receiving-plan-review

Work through `reviewing-plan` findings with technical rigor. Verify each finding before fixing it. Push back when findings are wrong.

**Core principle:** A finding is a claim, not an order. Verify it against the ticket and codebase before touching the plan.

## The Pattern

```
FOR each finding (BLOCKER first, then SHOULD-FIX, then NIT):
  1. READ the finding completely
  2. VERIFY against the ticket AC and codebase
  3. EVALUATE: does the finding hold up?
  4. DECIDE: accept, push back, or ask
  5. ACT: edit the plan if accepted; state reasoning if rejected
```

**NEVER accept a finding without verifying it first.** The judge ran with limited context. You have the full codebase.

## Verification by Finding Type

**Scope gap (missing AC):** Read the ticket. Does that AC actually exist verbatim? If yes — add the task. If the finding misread the ticket, push back with the exact ticket text.

**Scope creep (extra work):** Check the ticket ACs. If the plan work is traceable to any AC (even indirectly), push back with the AC reference. If genuinely untraceable — accept.

**Codebase grounding (file/export doesn't exist):** Grep the repo. If it doesn't exist — accept. If it does — push back with the path and line number.

**Over-engineering:** Is the abstraction actually introduced? Does the codebase already use this pattern everywhere? If yes, push back — consistency is a valid reason. If genuinely disproportionate — accept.

**Breaking change:** Trace the consumers yourself. If the finding identified real unaddressed consumers — accept. If the change is additive or the consumers are already handled — push back with the evidence.

**Task decomposition:** Would a reviewer meaningfully approve one task while rejecting its neighbor? If tasks are genuinely entangled — accept. If the finding is splitting for its own sake — push back.

## Pushing Back

Push back when:
- The finding misread the ticket (cite the exact AC text)
- The finding flagged a file/export that does exist (cite path + line)
- The finding flagged scope creep that is ticket-traceable (cite the AC)
- The proposed fix introduces more complexity than the original problem

How: one sentence, evidence first. No over-explaining.

## Accepting a Finding

When a finding holds up, make a targeted edit to the plan:
- Scope gap → add the missing task
- Scope creep / over-engineering → remove or simplify the task
- Grounding error → fix the file path or method name
- Silent breaking change → add a migration/compat step

After each edit, note what changed: `"Fixed: added T6 for [AC description]."`

## After All Findings Are Addressed

Once all BLOCKERs and SHOULD-FIXes are resolved or pushed back with reasoning:

> "All findings addressed. Re-run `/reviewing-plan` to get a fresh verdict."

Do not re-run `reviewing-plan` yourself — the developer triggers the next review.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Accepting all findings without reading the ticket | Read the AC first. The judge can be wrong. |
| Editing the plan before verifying | Verify first, always. |
| Pushing back without evidence | Cite the ticket text, file path, or codebase pattern. |
| Fixing NITs before BLOCKERs | BLOCKERs first. NITs are the developer's call. |
| Re-running reviewing-plan yourself | The developer triggers the next review. |
