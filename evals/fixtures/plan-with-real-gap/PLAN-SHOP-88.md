# PLAN-SHOP-88 — Add a dark-mode toggle to the settings page

Ticket: SHOP-88 | Branch: feat/SHOP-88/dark-mode-toggle

## Goal

Add a "Dark mode" toggle to the Appearance section of the account settings page that switches the
storefront theme immediately and persists the choice across sessions, defaulting to the OS
`prefers-color-scheme` on first visit.

## Key findings

- `ThemeContext` (`src/theme/ThemeContext.tsx`) already exposes `theme` and `setTheme('light' |
  'dark')`; the provider is mounted at the app root. Nothing consumes `setTheme` yet.
- The settings page (`src/pages/account/SettingsPage.tsx`) renders an `Appearance` section with a
  font-size control — the toggle slots in beside it, following the same `SettingRow` pattern.
- Persistence: the app already uses `usePersistentPref` (`src/prefs/usePersistentPref.ts`) backed
  by `localStorage` + the `/account/prefs` endpoint, so theme persistence reuses it, not a new store.

## Decisions

- **Default to OS preference on first visit** (per ticket Question + product answer): read
  `window.matchMedia('(prefers-color-scheme: dark)')` only when no stored pref exists.
- **Reuse `usePersistentPref('theme', …)`** rather than introduce a new persistence path — the
  codebase already centralizes prefs there.

## Changes by file

- `src/pages/account/SettingsPage.tsx` — add a `Dark mode` `SettingRow` with a `Toggle` wired to
  `theme === 'dark'` and `setTheme`.
- `src/theme/useThemePreference.ts` (new) — small hook: reads/writes the persisted theme pref via
  `usePersistentPref`, falling back to OS preference on first visit; calls `setTheme`.

## Testing

Behavioral, via the project's React testing setup: toggling flips the theme, the choice persists,
first-visit follows OS preference, the control is keyboard-operable and labeled.

## Verification

- `npm run lint` → no new errors
- `npm test src/pages/account` and `npm test src/theme` → all pass

## Out of scope

- Theming any surface outside the storefront (admin console, emails).
- A system-wide "auto" tri-state — this ticket is a binary light/dark toggle only.
- Migrating the existing font-size control to the new hook.

---

# Tasks

## Task T1: Persisted theme hook

> **Status:** not started
> **Effort:** s
> **Priority:** high
> **Depends on:** None

### Description
Add `useThemePreference` that reads/writes the persisted theme via `usePersistentPref` and falls
back to the OS `prefers-color-scheme` on first visit, driving `ThemeContext.setTheme`.

### Test Plan
#### Test File(s)
- `src/theme/useThemePreference.test.tsx`
#### Test Scenarios
##### useThemePreference
- **first visit follows OS preference** — GIVEN no stored pref AND OS prefers dark WHEN the hook mounts THEN theme is 'dark'
- **stored pref wins over OS** — GIVEN a stored 'light' pref AND OS prefers dark WHEN the hook mounts THEN theme is 'light'
- **setting persists** — WHEN the consumer sets dark THEN the pref is written via usePersistentPref

### Scope Boundaries
- Do NOT theme surfaces outside the storefront.
- Only implement the binary light/dark hook.

### Files Expected
**New files:** `src/theme/useThemePreference.ts`, `src/theme/useThemePreference.test.tsx`
**Modified files:** none
**Must NOT modify:** `config/secrets.py` (unrelated; out of scope)

## Task T2: Settings toggle wiring

> **Status:** not started
> **Effort:** s
> **Priority:** high
> **Depends on:** T1

### Description
Add a "Dark mode" SettingRow to the Appearance section wired to `useThemePreference`.

### Test Plan
#### Test File(s)
- `src/pages/account/SettingsPage.test.tsx`
#### Test Scenarios
##### Dark mode toggle
- **toggling switches theme immediately** — GIVEN the settings page WHEN the user toggles Dark mode THEN the theme switches with no reload
- **toggle is labeled and keyboard operable** — THEN the control has an accessible name and responds to keyboard

### Scope Boundaries
- Only the toggle row; do not restructure the Appearance section.

### Files Expected
**New files:** none
**Modified files:** `src/pages/account/SettingsPage.tsx`
**Must NOT modify:** `config/secrets.py`

## Task T3: First-visit OS-default integration

> **Status:** not started
> **Effort:** s
> **Priority:** medium
> **Depends on:** T1, T2

### Description
End-to-end: a first-time visitor with OS dark preference lands on the dark theme; the toggle then overrides and persists.

### Test Plan
#### Test File(s)
- `src/pages/account/SettingsPage.test.tsx`
#### Test Scenarios
##### first-visit default
- **OS dark on first visit** — GIVEN a fresh session AND OS prefers dark WHEN the page loads THEN dark is active
- **override persists across reload** — WHEN the user toggles to light THEN light survives a reload

### Scope Boundaries
- Only the integration wiring.

### Files Expected
**New files:** none
**Modified files:** `src/pages/account/SettingsPage.tsx`
**Must NOT modify:** `config/secrets.py`

## Task T4: Confirmation toast on toggle

> **Status:** not started
> **Effort:** s
> **Priority:** high
> **Depends on:** T2

### Description
Show a "Theme updated" confirmation toast each time the Dark mode toggle is switched.

### Test Plan
#### Test File(s)
- `src/pages/account/SettingsPage.test.tsx`
#### Test Scenarios
##### confirmation toast
- **toast appears on toggle** — GIVEN the settings page WHEN the user toggles Dark mode THEN a "Theme updated" toast is displayed
- **toast appears on each toggle** — WHEN the user toggles again THEN a new "Theme updated" toast is displayed

### Scope Boundaries
- Only the toast triggered by the dark-mode toggle; do not add toasts elsewhere.

### Files Expected
**New files:** none
**Modified files:** `src/pages/account/SettingsPage.tsx`
**Must NOT modify:** `config/secrets.py`

---

## Plan Review — PLAN-SHOP-88 vs SHOP-88

**Verdict: PROCEED**
**Blockers: 0 · Should-fix: 0 · Nits: 0**

### Findings

**[RESOLVED] #1 — Scope gap: the "Theme updated" confirmation-toast AC**
Added T4 covering the confirmation toast ("Theme updated") with two test scenarios.

> **Plan Review:** PROCEED — 2026-06-24
