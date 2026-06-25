# PLAN-SHOP-88 — Add a dark-mode toggle to the settings page

Ticket: SHOP-88 | Branch: feat/SHOP-88/dark-mode-toggle

## Goal

Add a "Dark mode" toggle to the account settings page, switching the storefront theme immediately
and persisting the choice, defaulting to OS preference on first visit.

## Key findings

- `ThemeContext` (`src/theme/ThemeContext.tsx`) exposes the setter, but its current name
  `applyTheme(next)` is unclear; this plan **renames the exported `applyTheme` to `setTheme`** for
  readability while wiring the toggle.
- The settings page (`src/pages/account/SettingsPage.tsx`) has an Appearance section to extend.
- Persistence reuses `usePersistentPref`.

## Decisions

- Rename the exported `applyTheme` → `setTheme` in `src/theme/ThemeContext.tsx` and update the
  settings page to call the new name.
- Default to OS preference on first visit.

## Changes by file

- `src/theme/ThemeContext.tsx` — rename exported `applyTheme` to `setTheme`.
- `src/pages/account/SettingsPage.tsx` — add the Dark mode toggle calling `setTheme`.

## Testing

Behavioral: toggling flips theme, persists, first visit follows OS preference.

## Verification

- `npm run lint` and `npm test src/pages/account` → pass.

## Out of scope

- Theming admin/email surfaces.

---

# Tasks

## Task T1: Rename the theme setter and wire the toggle

> **Status:** not started
> **Effort:** s
> **Priority:** high
> **Depends on:** None

### Description
Rename the exported `applyTheme` to `setTheme` in `ThemeContext`, and add the Dark mode toggle on
the settings page calling `setTheme`.

### Test Plan
#### Test File(s)
- `src/pages/account/SettingsPage.test.tsx`
#### Test Scenarios
##### Dark mode toggle
- **toggling switches theme** — WHEN the user toggles Dark mode THEN the theme switches immediately
- **choice persists** — WHEN toggled THEN the choice survives a reload

### Implementation Notes
- Rename `export function applyTheme` → `export function setTheme` and update the settings page call site.

### Scope Boundaries
- Only the toggle and the rename.

### Files Expected
**New files:** none
**Modified files:** `src/theme/ThemeContext.tsx`, `src/pages/account/SettingsPage.tsx`
**Must NOT modify:** none

<!-- NOTE for the eval: ThemeContext's applyTheme is imported by other modules
     (src/theme/ThemeToggleButton.tsx and src/layout/Header.tsx in this fictional repo).
     The plan renames the export but lists NO migration/compat step and does not name those
     consumers — a SILENT breaking change. reviewing-plan must catch this as a BLOCKER. -->
