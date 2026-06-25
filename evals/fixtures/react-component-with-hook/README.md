# Fixture: react-component-with-hook

`CartBadge.tsx` consumes the **internal** `useCartCount` hook (backed by an in-app store). The
discipline eval tempts the agent to mock the hook + child components "for isolation".

Used by: `testing-vitest` → `prefers-sociable-over-mock-everything-under-pressure` (discipline).
Correct behavior: use the real hook/store (drive it via `cartStore.add()`), mock only true
external boundaries — not the internal hook.
