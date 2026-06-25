# Skill Evaluations

Evaluations for the `agentic-sdlc` skills. An eval is a test case for a skill: a query
(+ optional fixture) and a rubric of `expected_behavior` strings the skill's output must
satisfy. Per `docs/SKILL-BEST-PRACTICES.md`, every skill should have **≥3 evals**.

## Layout

```
evals/
├── README.md            # this file
├── run.py               # loader + schema validator + judge-prompt renderer
├── judge_prompt.md       # the rubric-judge instruction (rendered per scenario)
├── fixtures/            # input repos/files a scenario needs (real data, no placeholders)
└── skills/
    └── <skill>.eval.json # one file per skill, an array of >=3 scenarios
```

## Method — RED before GREEN (TDD for skills)

These evals follow `superpowers:writing-skills`: **writing a skill is TDD for process docs.**
The Iron Law — *no skill without a failing test first* — applies to evals too:

> An eval only means something if a no-skill agent **fails** it (RED). If the base model
> already passes without the skill, the eval tests the model, not the skill — make it harder.

So every scenario records a **`baseline`**: what a no-skill agent does (the RED failure the
skill must fix). The flow per scenario:

1. **RED** — `python3 evals/run.py baseline <skill> <name>` → run the query in a fresh session
   with the skill NOT loaded. Confirm the agent exhibits the recorded `baseline` failure.
   (If it doesn't fail, the scenario is too easy — rewrite it.)
2. **GREEN** — `python3 evals/run.py render <skill> <name>` → run the query WITH the skill, judge
   the transcript against `expected_behavior`. The skill passes if every item is ✅.

`discipline` scenarios are **pressure tests** (per the skill-testing methodology): they apply
time / sunk-cost / authority / social-proof pressure in the query, because a discipline skill's
job is to hold under pressure. Each carries a `pressure` field naming the pressure(s).

## Eval file schema

Each `skills/<skill>.eval.json` is a JSON array of scenarios:

```json
{
  "name": "halts-without-upstream-stamp",
  "category": "gate | core | discipline",
  "query": "the user request that triggers the skill",
  "scripted_answers": ["answers fed to AskUserQuestion pauses, in order"],
  "fixture": "fixtures/<dir>/ or null",
  "baseline": "what a no-skill agent does — the RED failure the skill must fix (required)",
  "pressure": "for discipline scenarios only: the pressure applied (time/sunk-cost/authority/...)",
  "expected_behavior": ["claim the GREEN transcript must satisfy", "..."]
}
```

**Every skill must cover all three categories** (the harness enforces this):

- **gate** — given a missing upstream stamp / bad input / missing prerequisite, the skill
  HALTS or REFUSES and does not proceed.
- **core** — given valid input, the skill produces its artifact with the required structure.
- **discipline** — under pressure, the skill does NOT do the thing it must never do (write the
  file before approval, fix code during review, mock an internal module, rewrite main, etc.).
  Discipline scenarios MUST carry a `pressure` field (validated).

The rubric source for each scenario is the skill's own **Red Flags** / **You Must NOT** /
self-review tables — transcribe those into `expected_behavior`, and write the matching
`baseline` from what the skill exists to prevent.

## Running

```bash
# Validate every eval file + show coverage (CI-friendly; exits non-zero on any problem)
python3 evals/run.py validate

# Coverage table only
python3 evals/run.py coverage

# Print the RED (baseline) prompt(s) — run with the skill ABSENT, confirm the failure
python3 evals/run.py baseline reviewing-plan
python3 evals/run.py baseline reviewing-plan silent-breaking-change-is-a-blocker-despite-clean-look

# Print the GREEN judge prompt(s) — run with the skill present, judge the transcript
python3 evals/run.py render reviewing-plan
python3 evals/run.py render reviewing-plan silent-breaking-change-is-a-blocker-despite-clean-look
```

## Scoring a skill (the manual / CI loop)

`run.py` does not drive a live CLI session — it prepares the RED and GREEN prompts. To score:

1. **RED — confirm the baseline failure.** `run.py baseline <skill> <name>` → run the query in
   a fresh session with the skill NOT loaded. Confirm the agent does the recorded `baseline`.
   If it already behaves correctly, the scenario is too easy — rewrite it harder. (Do this once
   per scenario; re-confirm only when the base model changes.)
2. **GREEN — run the skill.** Run the same query in a fresh session WITH the skill, feeding
   `scripted_answers` to each AskUserQuestion pause in order. Capture the full transcript.
3. **Render the judge prompt:** `run.py render <skill> <name>`; paste the transcript into the
   `<<< PASTE … >>>` placeholder.
4. **Have a strong model judge it.** It returns PASS/FAIL per `expected_behavior` item with
   transcript evidence, plus a headline PASS/FAIL.

A scenario passes only if the RED baseline genuinely failed AND every GREEN
`expected_behavior` item is ✅. (RED failing is what proves the skill — not the model — earned
the GREEN pass.)

## Model coverage

The best-practices checklist wants Haiku / Sonnet / Opus coverage. Current evals are written
to be judged by a single strong model; running the skill-under-test across the model matrix is
a later enhancement (the rubrics are model-agnostic, so no eval rewrite is needed).

## CI (not yet wired — by design)

Evals are **not** a PR gate. LLM-judge runs cost tokens and are nondeterministic, so a hard
per-PR gate would be flaky. The intended wiring (deferred) is a nightly or `run-evals`-labeled
job that runs the suite and reports drift. What IS safe to run in CI today is the schema +
coverage check, which is deterministic and free:

```bash
python3 evals/run.py validate
```

## Status

All 11 skills have 3 evals each (gate/core/discipline), each with a written `baseline` and —
for discipline scenarios — a `pressure` field. The harness (`validate` / `coverage` / `render`
/ `baseline`) and rubrics are complete and validated.

**Done:** Fixtures — all 25 referenced `fixture` dirs exist under `evals/fixtures/` with a
`README.md` each (real BrightCart/`SHOP-88` data per the live-data rule). Pipeline fixtures
(`ticket-*`, `plan-*`) vary one shared example by stamp/marker state; `branch-*` ship a
`SETUP.sh` that builds the git state in a scratch dir; `jira-*` ship a `ticket.json` payload so
`fetching-tickets` runs offline; code/diff fixtures ship real source + a `DIFF.md`.

**Not yet done (next passes, non-blocking):**

- **RED confirmation** — the `baseline` strings are written from each skill's purpose but have
  NOT yet been confirmed against a live no-skill run. Per the method, a scenario isn't proven
  until its baseline is observed failing. Run `run.py baseline <skill>` and verify before
  trusting any GREEN pass.
- **Live GREEN scoring** and the **model matrix** (Haiku/Sonnet/Opus) — the per-release loop,
  not a build step.
```
