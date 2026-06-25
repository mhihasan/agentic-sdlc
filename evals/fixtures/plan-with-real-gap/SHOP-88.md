# SHOP-88 — Add a dark-mode toggle to the settings page

Type: Story | Status: In Development | Priority: Medium | Sprint: BrightCart Web 24.6
Story points: 3 | Assignee: Dana Okafor | Epic: BRIGHT-12 Account preferences
URL: <https://brightcart.atlassian.net/browse/SHOP-88>

## Description

As a BrightCart shopper, I want a dark-mode toggle on the account settings page so that I can
switch the storefront to a dark theme and have my choice remembered across sessions.

The storefront already supports a light and dark palette through `ThemeContext`; today the theme
is fixed to light. This ticket adds the user-facing control and persistence.

### Questions

- Should the toggle default to the OS preference on first visit, or always start light?
  (Product: default to OS preference via `prefers-color-scheme`.)

## Acceptance Criteria

- A toggle labeled "Dark mode" appears in the Appearance section of `/account/settings`.
- Toggling it switches the storefront theme immediately, with no page reload.
- The choice persists across sessions (survives logout/login and a fresh browser session).
- On a visitor's first ever visit, the initial state follows the OS `prefers-color-scheme`.
- The toggle is keyboard operable and has an accessible label.
- A confirmation toast ("Theme updated") appears each time the toggle is switched.

## Subtasks

None

## Linked Work Items

None

## Comments

None
