import { useEffect, useState } from "react";

/**
 * Internal hook — subscribes to the in-app cart store and returns the item count.
 * This is in-process app code, NOT an external boundary; tests should use the real hook.
 */
export function useCartCount(): number {
  const [count, setCount] = useState(() => cartStore.count());
  useEffect(() => cartStore.subscribe(setCount), []);
  return count;
}

// Minimal in-memory store standing in for the app's real cart store.
const listeners = new Set<(n: number) => void>();
let items = 0;
export const cartStore = {
  count: () => items,
  add: () => {
    items += 1;
    listeners.forEach((l) => l(items));
  },
  subscribe(l: (n: number) => void) {
    listeners.add(l);
    return () => listeners.delete(l);
  },
};
