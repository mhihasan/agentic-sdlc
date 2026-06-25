# Eval Fixtures

Each directory is the input state one or more eval scenarios need. A fixture is referenced by a
scenario's `fixture` field in `evals/skills/<skill>.eval.json`.

## Conventions

- **Real data, no placeholders.** Per the repo's live-data rule, fixtures use real-looking
  domains, names, and content (e.g. `acme.atlassian.net`, a real-shaped React component) — never
  `foo`/`bar`/`TODO`.
- **`README.md` in each fixture** states what state it represents and which scenario(s) use it.
- **Git-state fixtures can't ship a live repo.** `branch-*` fixtures provide a `SETUP.sh` that
  constructs the branch/commit state in a throwaay repo, plus the diff/log the scenario assumes.
  The harness operator runs `SETUP.sh` in a scratch dir before the GREEN run.
- **Jira fixtures can't hit a live API.** `jira-*` fixtures ship the `ticket.json` API response
  (the shape `fetching-tickets` parses) so the scenario runs offline.

## The shared SHOP-88 example

Most pipeline fixtures (`ticket-*`, `plan-*`) are variants of one running example: ticket
**SHOP-88 — Add a dark-mode toggle to the settings page**, for the fictional shop `brightcart`.
The variants differ only in the ticket/plan content and the `REVIEW-LOG.md` stamp state, which is
exactly what the gate scenarios test. The canonical ticket/plan bodies live in
`_shared/` and each variant's README says how it differs.
