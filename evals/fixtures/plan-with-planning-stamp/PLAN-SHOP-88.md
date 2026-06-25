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

## Task T1: Implement `useThemePreference` hook

> **Status:** not started
> **Effort:** s
> **Priority:** high
> **Depends on:** None

### Description

Create `src/theme/useThemePreference.ts` — a hook that reads and writes the persisted theme preference via `usePersistentPref('theme', …)`, falling back to `window.matchMedia('(prefers-color-scheme: dark)')` on first visit (no stored pref), and calls `setTheme` from `ThemeContext` to apply the value immediately.

Cache-invalidation strategy: **write-through**. `usePersistentPref` writes to both `localStorage` and `/account/prefs` on every call. No separate cache layer; the stored value is always authoritative. No TTL or background refresh needed.

### Test Plan

#### Test File(s)
- `src/theme/useThemePreference.test.ts`

#### Test Scenarios

##### useThemePreference — first visit (no stored pref)
- **follows OS dark preference** — GIVEN no stored `theme` pref AND `prefers-color-scheme: dark` WHEN hook mounts THEN `setTheme` is called with `'dark'`
- **follows OS light preference** — GIVEN no stored `theme` pref AND `prefers-color-scheme: light` WHEN hook mounts THEN `setTheme` is called with `'light'`

##### useThemePreference — returning visit (stored pref exists)
- **uses stored pref over OS** — GIVEN stored `theme` pref is `'light'` AND OS is `dark` WHEN hook mounts THEN `setTheme` is called with `'light'`
- **uses stored dark pref** — GIVEN stored `theme` pref is `'dark'` WHEN hook mounts THEN `setTheme` is called with `'dark'`

##### useThemePreference — toggle interaction
- **persists on toggle to dark** — GIVEN current theme is `'light'` WHEN `setThemePref('dark')` is called THEN `usePersistentPref` writes `'dark'` AND `setTheme('dark')` is called
- **persists on toggle to light** — GIVEN current theme is `'dark'` WHEN `setThemePref('light')` is called THEN `usePersistentPref` writes `'light'` AND `setTheme('light')` is called

### Implementation Notes
- **Layer(s):** React hook (`src/theme/`)
- **Pattern reference:** `src/prefs/usePersistentPref.ts` — follow its call signature exactly
- **Key decisions:** write-through via `usePersistentPref`; OS fallback only when no stored pref; `setTheme` sourced from `ThemeContext`
- **Libraries:** React, existing `usePersistentPref`, existing `ThemeContext`

### Scope Boundaries
- Do NOT add a tri-state (`'auto'`) — binary `'light' | 'dark'` only
- Do NOT introduce a new persistence mechanism — reuse `usePersistentPref`
- Do NOT touch `ThemeContext.tsx` — consume it, don't modify it
- Only implement the hook; the UI wiring is T2

### Files Expected
**New files:** `src/theme/useThemePreference.ts`, `src/theme/useThemePreference.test.ts`
**Modified files:** none
**Must NOT modify:** `src/theme/ThemeContext.tsx`, `src/prefs/usePersistentPref.ts`

---

## Task T2: Wire dark-mode toggle into SettingsPage

> **Status:** not started
> **Effort:** s
> **Priority:** high
> **Depends on:** T1

### Description

Add a `Dark mode` `SettingRow` with a `Toggle` component to the `Appearance` section of `src/pages/account/SettingsPage.tsx`, wired to `useThemePreference`. The toggle checked state reflects `theme === 'dark'`; changing it calls the hook's setter. Must be keyboard-operable and have an accessible label.

### Test Plan

#### Test File(s)
- `src/pages/account/SettingsPage.test.tsx`

#### Test Scenarios

##### SettingsPage Appearance section — dark mode toggle render
- **renders Dark mode toggle** — GIVEN the settings page mounts WHEN Appearance section is visible THEN a toggle labeled `"Dark mode"` is present
- **toggle reflects current light theme** — GIVEN stored pref is `'light'` WHEN settings page renders THEN the toggle is unchecked
- **toggle reflects current dark theme** — GIVEN stored pref is `'dark'` WHEN settings page renders THEN the toggle is checked

##### SettingsPage Appearance section — toggle interaction
- **clicking toggle switches to dark** — GIVEN current theme is `'light'` WHEN user clicks the Dark mode toggle THEN theme switches to `'dark'` immediately
- **clicking toggle switches to light** — GIVEN current theme is `'dark'` WHEN user clicks the Dark mode toggle THEN theme switches to `'light'` immediately

##### SettingsPage Appearance section — accessibility
- **keyboard operable** — GIVEN the Dark mode toggle is focused WHEN user presses Space THEN the theme toggles
- **toggle has accessible label** — GIVEN the Dark mode toggle renders THEN it has an associated `<label>` or `aria-label` of `"Dark mode"`

### Implementation Notes
- **Layer(s):** React page component (`src/pages/account/`)
- **Pattern reference:** existing font-size `SettingRow` in `SettingsPage.tsx` — follow the same pattern
- **Key decisions:** use `useThemePreference` (T1) for theme state and setter; follow `SettingRow` + `Toggle` component patterns already present
- **Libraries:** React, `useThemePreference` (T1), existing `SettingRow`, existing `Toggle`

### Scope Boundaries
- Do NOT modify the font-size control or any other existing `SettingRow`
- Do NOT add theming to admin console or email surfaces
- Do NOT implement tri-state — binary toggle only
- Only add the single `SettingRow` entry; no new sections

### Files Expected
**New files:** none (tests may be in a new file if `SettingsPage.test.tsx` doesn't exist yet)
**Modified files:** `src/pages/account/SettingsPage.tsx` (add Dark mode `SettingRow`)
**Must NOT modify:** `src/theme/ThemeContext.tsx`, `src/prefs/usePersistentPref.ts`, font-size `SettingRow`

### TDD Sequence
1. Write failing tests for T2 render + interaction scenarios.
2. Implement T2 (T1 must already pass).
3. Run `npm test src/pages/account` — all green.
4. Run `npm run lint` — no new errors.
