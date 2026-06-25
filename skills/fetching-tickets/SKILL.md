---
name: fetching-tickets
description: Use when fetching a Jira ticket to disk is needed as a standalone operation. Normally invoked by picking-up-task — use this directly only if you already have a branch set up and only need the ticket file. Triggers on "pull this ticket", "save ticket to markdown", "download ticket".
model: inherit
color: lightyellow
license: MIT
---

# Fetching Tickets

Pull a Jira ticket and write it to a local markdown file that faithfully mirrors the ticket's section order and includes all assets downloaded locally.

**Next step:** once the ticket is on disk, the developer typically runs `planning-from-spec` to turn it into an implementation plan.

## Auth path selection

Two paths. Choose based on available credentials — they can be combined for best results:

| Credential state | Issue data | Images |
| --- | --- | --- |
| `JIRA_EMAIL` + `JIRA_API_TOKEN` set | curl (full fidelity — renderedFields HTML) | curl ✓ |
| Neither set (MCP OAuth only) | MCP `jira_getJiraIssue` | ✗ — noted in ticket file |
| MCP only but curl returns 403/404 | Fall back to MCP, warn about token | ✗ — noted in ticket file |

**Hybrid (best of both):** Use MCP for issue data + curl for images when `JIRA_API_TOKEN` is set. This gives full content fidelity without needing `JIRA_EMAIL` for the issue fetch.

If `JIRA_API_TOKEN` is set but curl returns a 403/404 on images, log the failure per image and continue — partial images are better than a halt.

---

## MCP path (primary for OAuth users)

Extract `<cloudId>` and `<KEY>` from the ticket URL: `https://<site>.atlassian.net/browse/<KEY>`

Use `jira_getAccessibleAtlassianResources` to resolve the cloudId if needed.

### Fetch the issue

```
jira_getJiraIssue(
  cloudId = <cloudId>,
  issueIdOrKey = <KEY>,
  fields = ["*all"],
  responseContentFormat = "markdown"
)
```

From the response extract:
- `fields.summary`, `fields.status.name`, `fields.issuetype.name`, `fields.priority.name`
- `fields.assignee.displayName`, `fields.reporter.displayName`
- `fields.description` — main description body
- All `customfield_*` keys that have non-null, non-empty values — check `names` map for human-readable labels
- `fields.subtasks[]` — key + summary + status
- `fields.issuelinks[]` — link type + key + summary + status
- `fields.attachment[]` — id, filename, content URL

### Fetch comments

```
jira_getJiraIssue(
  cloudId = <cloudId>,
  issueIdOrKey = <KEY>,
  fields = ["comment"],
  responseContentFormat = "markdown"
)
```

Filter to human comments only: exclude any where `author.accountType == "app"`.

### Download images (hybrid: MCP data + curl images)

If `JIRA_API_TOKEN` is set, download attachments via curl using the content URLs from `fields.attachment[]`:

```bash
mkdir -p images
curl -s -L \
  -u "${JIRA_EMAIL:-token}:${JIRA_API_TOKEN}" \
  -o "images/<filename>" \
  "<content-url-from-attachment>"
```

Note: `JIRA_EMAIL` can be any non-empty string if only the token is needed for Bearer auth — some instances accept token-only. If download fails (non-2xx), note the attachment as `[image not downloaded: <filename>]` inline and continue.

If `JIRA_API_TOKEN` is not set, add to the ticket file's metadata block:

```
> **Note:** This ticket has attachments that could not be downloaded (no JIRA_API_TOKEN set).
> To include images, set JIRA_API_TOKEN and re-run fetching-tickets.
> Attachments: <comma-separated filenames>
```

### Write the ticket file

Follow the Section Order below. For custom fields, include only those with real human-written content (non-null, non-empty, not just whitespace or placeholder text).

---

## Curl path (full fidelity)

```bash
export JIRA_EMAIL="you@example.com"
export JIRA_API_TOKEN="your-api-token"   # https://id.atlassian.com/manage-profile/security/api-tokens
```

Extract `<site>` and `<key>` from the ticket URL: `https://<site>.atlassian.net/browse/<key>`

### Quick Reference

| Step | Command |
| --- | --- |
| 1. Fetch everything | `curl … ?expand=names,renderedFields&fields=*all` |
| 2. Find custom field IDs | Grep output for "Acceptance Criteria", "Direct Link", etc. |
| 3. Read rendered HTML | Use `renderedFields` for exact image-bullet ordering |
| 4. Download images | `curl -s -L -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" <content-url> -o <file>` — no `Accept` header |
| 5. Write markdown | Follow ticket section order exactly from rendered HTML |

### Step 1 — Fetch Everything in One Call

```bash
curl -s -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  "https://<site>.atlassian.net/rest/api/3/issue/<KEY>?expand=names,renderedFields&fields=*all" \
  > ticket.json
```

From this single response you get:
- `fields.summary`, `fields.status`, `fields.assignee`, `fields.priority`, `fields.attachment`, etc. — standard fields
- `names` — map of every field ID to its human-readable name
- `renderedFields` — HTML-rendered version of every rich-text field (use this for section ordering)
- `fields.self` — contains the Cloud ID for building attachment download URLs

### Step 2 — Discover Custom Fields

```bash
python3 -c "
import json
d = json.load(open('ticket.json'))
names = d.get('names', {})
for k, v in d['fields'].items():
    if k.startswith('customfield_') and v is not None:
        print(f'{k} [{names.get(k, k)}]: {str(v)[:100]}')
"
```

Content fields — those written by humans (Acceptance Criteria, Direct Link, etc.) — have ADF doc objects as their value (`{"type": "doc", ...}`). Only include fields with **real human-written content** — many fields contain empty wiki tables, placeholder italic text, or boilerplate checklists.

```python
import json, re

d = json.load(open('ticket.json'))
names = d.get('names', {})
fields = d['fields']
rendered = d.get('renderedFields', {})

def is_empty_wiki_table(html):
    """Wiki table skeleton: ||Header|| rows with all empty | | | cells."""
    if not re.search(r'\|\|.*?\|\|', html):
        return False
    data_rows = re.findall(r'(?<!\|)\|([^|<\r\n]+)\|', html)
    non_empty = [c.strip() for c in data_rows if c.strip() not in ('', ' ')]
    return len(non_empty) == 0

def has_real_content(raw):
    if not raw:
        return False
    if is_empty_wiki_table(raw):
        return False
    # Placeholder-only list (e.g. [FEATURE FLAG LINK] × 3 — no real values filled in)
    if re.search(r'&#91;[A-Z ]+LINK&#93;', raw):
        return False
    plain = re.sub(r'<[^>]+>', ' ', raw)
    plain = re.sub(r'&[a-z0-9#]+;', ' ', plain)
    plain = re.sub(r'\s+', ' ', plain).strip()
    if len(plain) < 10:
        return False
    # "No X logged" sentinel
    if re.match(r'^No .{1,40} logged$', plain, re.IGNORECASE):
        return False
    # Strip italic placeholders and generic boilerplate
    stripped = re.sub(r'\*[^*]+\*', '', plain)
    stripped = re.sub(r'Remember to update.*', '', stripped, flags=re.IGNORECASE).strip()
    return len(stripped) >= 10

# Always-show fields (even when empty)
ALWAYS_SHOW = {}  # e.g. {'customfield_10721': 'Direct Link'} if your instance has it

content_fields = {}
for k, v in fields.items():
    if not k.startswith('customfield_'):
        continue
    if isinstance(v, dict) and v.get('type') == 'doc':
        r = rendered.get(k, '') or ''
        if has_real_content(r) or k in ALWAYS_SHOW:
            content_fields[k] = names.get(k, k)
content_fields.update(ALWAYS_SHOW)

for k, name in sorted(content_fields.items(), key=lambda x: x[1]):
    print(f'{k} [{name}]')
```

This surfaces only fields with actual human-written content — no DoD checklists, no empty tables, no placeholder prompts.

**Important:** Acceptance Criteria is almost never in `description` — it is always a separate custom field.

### Step 3 — Read Rendered HTML for Section Order

The `renderedFields` key contains HTML for every rich-text field. Use it as the authoritative source for:
- Exact ordering of images and bullet points within Acceptance Criteria
- Sub-section headings within Description (e.g. "Questions", "Direct Link")

```bash
python3 -c "
import json
d = json.load(open('ticket.json'))
# Description
print('=== DESCRIPTION ===')
print(d['renderedFields'].get('description', ''))
# Acceptance Criteria (replace with your discovered field ID)
print('=== ACCEPTANCE CRITERIA ===')
print(d['renderedFields'].get('customfield_XXXXX', ''))
"
```

### Step 4 — Download Images

Attachment `content` URLs are in `fields.attachment[].content` — use them directly, no Cloud ID needed. They return a 303 redirect to the actual file.

```bash
# List attachments with their download URLs
python3 -c "
import json
d = json.load(open('ticket.json'))
for a in d['fields'].get('attachment', []):
    print(a['id'], a['filename'], a['content'])
"

# Download each — no Accept header (causes 406 if set)
mkdir -p images
curl -s -L \
  -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -o "images/<filename>" \
  "<content-url-from-attachment>"
```

## Section Order

Match the Jira ticket's left-panel reading order exactly:

```
# TICKET-KEY — Summary

Metadata block (type, status, priority, sprint, story points, assignee, epic, URL)

## Description
(user story + body — preserve all sub-sections like "Questions", "Direct Link: None")

## <Each discovered ADF content field, in alphabetical order by name>
(e.g. Acceptance Criteria, Direct Link, Entry Criteria, Feature Flags, etc.)
(use rendered HTML for content — write "None" if the field is empty)

## Subtasks
(table of subtask key + summary + status — or "None" if empty)

## Linked Work Items
(table of link type + key + summary + status — or "None" if empty)

## Comments
(human comments only — skip any comment where `author.accountType === "app"`)
```

**Critical rules:**
- Include ONLY ADF content fields with real human-written content (use the `has_real_content` filter from Step 2)
- Skip template-only fields: empty wiki tables, `*italic placeholders*`, "No X logged", boilerplate checklists
- Never invent sub-section headers not present in the source
- Always include Subtasks and Linked Work Items even when empty
- Images go inline where they appear in the rendered HTML — not in a separate Attachments table at the bottom

### Rendering Subtasks and Linked Work Items

```python
import json
d = json.load(open('ticket.json'))

# Subtasks — fields.subtasks[]
subtasks = d['fields'].get('subtasks', [])
if subtasks:
    for s in subtasks:
        print(s['key'], s['fields']['summary'], s['fields']['status']['name'])
else:
    print('None')

# Linked work items — fields.issuelinks[]
# Each link has either an inwardIssue or outwardIssue, and a type with inward/outward label
links = d['fields'].get('issuelinks', [])
if links:
    for l in links:
        if 'outwardIssue' in l:
            issue = l['outwardIssue']
            label = l['type']['outward']
        else:
            issue = l['inwardIssue']
            label = l['type']['inward']
        print(label, issue['key'], issue['fields']['summary'], issue['fields']['status']['name'])
else:
    print('None')
```

Render as markdown tables:

```markdown
## Subtasks

| Key | Summary | Status |
|---|---|---|
| PROJ-124 | Implement observe keys | In development |

## Linked Work Items

| Type | Key | Summary | Status |
|---|---|---|---|
| is blocked by | PROJ-100 | Design spec | Done |
```

Or when empty:

```markdown
## Subtasks

None

## Linked Work Items

None
```

## Output Layout

```
local-dev/tickets/
  TICKET-KEY/
    TICKET-KEY.md
    images/
      screenshot.png
      diagram.png
```

Reference images with relative paths: `![filename](images/filename.png)`

## Self-Review Before Handoff

Before declaring the ticket file done, review your own output against this checklist and fix any
failure. These are objective checks — they run in **both** collaborative and `auto` mode.

| Check | Pass condition |
| --- | --- |
| AC present | Acceptance Criteria custom field discovered and included (not left in `description`) |
| Real content only | `has_real_content()` filter applied — no empty wiki tables, italic placeholders, "No X logged" |
| All images local | Every image referenced in rendered HTML downloaded to `images/` and inlined at its rendered position |
| Section order | Matches rendered HTML exactly; no invented sub-headers |
| Relations present | Subtasks + Linked Work Items rendered (even when "None") |
| Bots filtered | Comments where `author.accountType == "app"` excluded |
| Blocking deps surfaced | If Linked Work Items contains an unresolved "is blocked by", flag it explicitly to the developer (collaborative) or record it prominently in the file (`auto`) — this ticket may not be ready to start |

**Red flag — STOP:** About to hand off the ticket file without running this self-review → STOP. Run it first.

## Modes

This skill is mechanical, so the mode mostly affects how a blocking dependency is handled:

- **Collaborative (default):** if a self-review check fails or a blocking dependency surfaces, raise it with the developer.
- **Auto:** record the blocker prominently in the ticket file and continue; the fetch itself doesn't pause.

**`auto` invariants:** No self-commit (N/A — writes a file, not a commit). No self-push (N/A). Halt and report if Jira API returns an error or required fields are missing. Ask on unresolvable ambiguity (e.g., duplicate ticket key in URL).

## Common Mistakes

| Mistake | Fix |
| --- | --- |
| Looking for AC in `description` | AC is a custom field — discover it via the `names` map |
| Hardcoding a custom field ID | Field IDs differ per Jira instance — always discover |
| Using `-H "Accept: image/png"` in curl | Omit Accept header — causes 406; the endpoint redirects automatically |
| Inventing sub-headers inside AC | Copy structure from rendered HTML exactly |
| Including template-only fields | Filter with `has_real_content()` — skip empty wiki tables, italic placeholders, "No X logged", boilerplate checklists |
| Converting `<tt>` to backtick code spans | Jira uses `<tt>` for visual monospace, not semantic code — strip the tags, keep the text plain |
| Tab-indented list items rendering as code blocks | Jira HTML has `\t<li>` — strip the leading tab when converting: `re.sub(r'<li>(.*?)</li>', lambda m: '- ' + m.group(1).strip() + '\n', h)` and then `re.sub(r'^\t(- )', r'\1', output, flags=re.MULTILINE)` |
| Separate Attachments table at the bottom | Images belong inline in the section where they're referenced |
| Including bot/automation comments | Filter out comments where `author.accountType == "app"` — only include human comments (`"atlassian"`) |
