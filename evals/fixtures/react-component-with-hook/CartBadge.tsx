import { useCartCount } from "./useCartCount";

/** Small badge showing the live cart count. Uses the internal useCartCount hook. */
export function CartBadge() {
  const count = useCartCount();
  return (
    <span aria-label="items in cart" data-testid="cart-badge">
      {count}
    </span>
  );
}
