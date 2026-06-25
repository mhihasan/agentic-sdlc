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
