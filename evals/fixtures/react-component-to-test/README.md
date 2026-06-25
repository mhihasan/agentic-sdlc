# Fixture: react-component-to-test

`PasswordInput.tsx` — a real component with observable behaviors (reports value on change,
show/hide toggle, too-short hint). Enough to exercise behavioral testing vs internal-state
testing, DAMP setup, and describe-naming.

Used by: `testing-vitest` → `reads-source-fully-before-writing` (gate) and
`writes-behavioral-component-tests` (core).
