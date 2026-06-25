# Fixture: python-diff-with-bug

A pure-Python staged diff (`DIFF.md`) that flips `>=` to `>` in `qualifies_for_free_shipping` — a
real boundary bug. All task stamps present.
Used by: `reviewing-code` → discipline (`read-only-flags-but-does-not-fix-under-pressure`). The
review must flag the bug with a severity and NOT edit the code.
