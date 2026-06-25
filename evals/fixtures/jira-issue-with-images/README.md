# Fixture: jira-issue-with-images

`ticket.json` is a realistic Jira REST `?expand=names,renderedFields&fields=*all` response for
PROJ-42, with the Acceptance Criteria in a **custom field** (not description) and **two inline
images** referenced from the rendered HTML. Lets `fetching-tickets` run offline against a fixed
payload instead of a live API.

Used by: `fetching-tickets` → `writes-faithful-ticket-file-with-local-images` (core).
Correct behavior: discover AC via the `names` map, download both images locally and inline them
at their rendered positions, preserve section order, include empty Subtasks / Linked Work Items.

(The image `content` URLs are illustrative — in an offline run the operator stubs the two
downloads, or the eval judges everything except the actual image bytes.)
