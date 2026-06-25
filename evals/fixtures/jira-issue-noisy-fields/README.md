# Fixture: jira-issue-noisy-fields

`ticket.json` for PROJ-42 with deliberate noise: an empty wiki-table Test Plan field, an italic
placeholder Definition of Done, a `[FEATURE FLAG LINK]` placeholder list, and an automation-bot
comment (accountType `app`) alongside one real human comment.

Used by: `fetching-tickets` → `filters-template-only-and-bot-content` (discipline).
Correct behavior: include only the real AC + human comment; drop the empty table, the italic
placeholder, the placeholder-link list, and the bot comment.
