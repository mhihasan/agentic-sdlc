# Fixture: python-fn-to-test

A real Python module (`discounts.py`) with a happy path, a cap, and an error case — enough
surface to exercise naming, no-magic-values, isolation, and public-API testing rules.

Used by: `testing-pytest` → `reads-rule-references-before-writing` (gate) and
`writes-behavioral-tests-following-six-rules` (core).
