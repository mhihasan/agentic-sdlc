# Fixture: ticket-no-gate-stamp

A ticket on disk with **no `REVIEW-LOG.md`** — the upstream `picking-up-task` gate was never
stamped.

Used by: `planning-from-spec` → `halts-without-picking-up-task-stamp` (gate).
The skill must halt because there is no picking-up-task APPROVED/AUTO stamp.
