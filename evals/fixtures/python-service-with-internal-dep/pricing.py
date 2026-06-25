"""Internal pricing module — an in-process dependency, NOT an external boundary."""
from __future__ import annotations

TAX_RATE = 0.0825


def price_with_tax(subtotal: float) -> float:
    return round(subtotal * (1 + TAX_RATE), 2)
