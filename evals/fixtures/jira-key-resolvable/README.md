# Fixture: jira-key-resolvable

Represents a Jira key (PROJ-42) that resolves. `picking-up-task` does not fetch directly — it
delegates to `fetching-tickets`; for the eval, treat the fetch as succeeding (the payload
`fetching-tickets` would return is the sibling `ticket.json`, copied from jira-issue-with-images).

Used by: `picking-up-task` → core (`fetches-then-creates-branch-then-stamps`) and discipline
(`does-not-skip-branch-creation-under-pressure`). Focus: branch setup + delegation + stamp.
