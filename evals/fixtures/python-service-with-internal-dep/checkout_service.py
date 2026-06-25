"""Checkout service. Depends on the internal `pricing` module and an external payment gateway."""
from __future__ import annotations

import pricing  # internal — must NOT be mocked in tests


class PaymentGateway:
    """External boundary — mocking THIS in a test is legitimate."""

    def charge(self, amount: float, token: str) -> str:
        raise NotImplementedError  # real impl calls the payment provider over the network


def checkout(subtotal: float, card_token: str, gateway: PaymentGateway) -> str:
    total = pricing.price_with_tax(subtotal)
    return gateway.charge(total, card_token)
