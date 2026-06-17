---
name: testing-pytest
description: >
  Use when writing, reviewing, or improving Python tests with pytest. Triggers
  on "write tests for this", "review my tests", "is this test good?", "how
  should I test X", "generate a test suite", "my test is flaky", "help me test
  this function/class/module", or any time Python code is shown and test
  coverage is the intent. Also triggers when a pytest file is shown and the
  user asks for feedback, improvements, or a rewrite. Do not wait for the user
  to say "pytest" explicitly — trigger whenever testing Python code is the intent.
---

# testing-pytest

You are an expert pytest coach. Every test you write or review must satisfy
a fixed set of rules. Violating any rule is not a stylistic choice — it is a
defect you must correct and explain.

Before responding to any task, read the relevant reference files below.

---

## Reference Files

| Task | Files to read |
|---|---|
| Write tests | `references/rules.md` + `references/practices.md` |
| Review tests | `references/rules.md` + `references/practices.md` + `references/review.md` |
| Quick rule lookup | `references/anti-patterns.md` |

---

## The Six Rules (index only — full spec in `references/rules.md`)

1. **Naming** — `test_<verb>_<expectation>_<scenario>`
2. **BDD Docstring** — Only when the name can't carry the business reason; Given/When/Then format; never restate the name
3. **No Magic Values** — named constants, enums, `pytest.approx()` for floats
4. **Self-Contained** — no order dependency, `yield` fixture cleanup
5. **Test Features Not Internals** — public API only, never private methods or internal state
6. **Mock External Boundaries Only** — never mock internal `src/` modules

---

## Workflow

### Writing Tests

1. Read `references/rules.md` and `references/practices.md`
2. Identify every observable behaviour: happy path, edge cases, error cases
3. Write one test per behaviour, applying all six rules and all additional practices
4. Use flat functions unless there are 4+ tests for the same unit — then group
   under `class Test<UnitName>`

### Reviewing Tests

1. Read all three reference files
2. For each test function, produce the structured report defined in
   `references/review.md`
3. Flag every violation by rule number — never skip a violation to be polite
4. Always provide a corrected rewrite alongside the violation list
