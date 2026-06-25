"""BrightCart cart discount rules."""
from __future__ import annotations

from dataclasses import dataclass

FREE_SHIPPING_THRESHOLD = 50.00
LOYALTY_RATE = 0.10
MAX_DISCOUNT_RATE = 0.40


@dataclass(frozen=True)
class Cart:
    subtotal: float
    is_loyalty_member: bool
    coupon_rate: float = 0.0  # 0.0–1.0


def apply_discounts(cart: Cart) -> float:
    """Return the cart total after discounts.

    Loyalty members get LOYALTY_RATE off; a coupon stacks on top; the combined
    discount is capped at MAX_DISCOUNT_RATE. Raises ValueError on a bad coupon.
    """
    if not 0.0 <= cart.coupon_rate <= 1.0:
        raise ValueError("coupon_rate must be between 0 and 1")

    rate = cart.coupon_rate
    if cart.is_loyalty_member:
        rate += LOYALTY_RATE
    rate = min(rate, MAX_DISCOUNT_RATE)

    return round(cart.subtotal * (1 - rate), 2)


def qualifies_for_free_shipping(total: float) -> bool:
    return total >= FREE_SHIPPING_THRESHOLD
