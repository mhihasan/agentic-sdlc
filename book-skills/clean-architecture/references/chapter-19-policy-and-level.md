# Chapter 19: Policy and Level

## Summary
Every system contains policies at different levels of abstraction. **Level = distance from inputs and outputs**. High-level policies (core business rules) are far from I/O — they do not know what triggered them or where results go. Low-level policies (parsing, formatting, transport) are close to I/O. Source-code dependencies must point from low-level toward high-level — never the reverse. This is how high-level components achieve reusability.

## Key Principles
- **Level = distance from I/O**: A pure pricing rule is high level. An HTTP parser is low level.
- **Dependencies point toward high-level policy**: Low-level components call high-level ones via abstractions — never the reverse.
- **Reuse = level isolation**: High-level components are reusable precisely because they carry no low-level dependencies.

## Python Example

```python
# ---- LEVEL 3 (highest): Core domain — zero I/O, zero framework ----
class PricingEngine:
    """Knows nothing about HTTP, databases, or who is calling it."""
    TIERS = {"gold": 0.20, "silver": 0.10, "bronze": 0.05}

    def calculate(self, base_price: float, quantity: int, tier: str) -> float:
        discount = self.TIERS.get(tier, 0.0)
        return base_price * quantity * (1 - discount)

# Fully testable with zero infrastructure
engine = PricingEngine()
assert engine.calculate(10.0, 5, "gold")   == 40.0   # 50 * 0.80
assert engine.calculate(10.0, 5, "bronze") == 47.5   # 50 * 0.95
assert engine.calculate(10.0, 5, "unknown") == 50.0  # no discount
```

```python
# ---- LEVEL 2: Use case — knows domain, not HTTP/DB ----
from typing import Protocol
from dataclasses import dataclass

class ProductRepository(Protocol):
    def get_base_price(self, item_id: str) -> float: ...

@dataclass
class QuoteResult:
    item_id: str
    qty: int
    total: float

class QuoteUseCase:
    def __init__(self, pricing: PricingEngine, products: ProductRepository) -> None:
        self._pricing = pricing
        self._products = products

    def get_quote(self, item_id: str, qty: int, customer_tier: str) -> QuoteResult:
        base = self._products.get_base_price(item_id)
        total = self._pricing.calculate(base, qty, customer_tier)
        return QuoteResult(item_id=item_id, qty=qty, total=total)

# Test at level 2 — no HTTP, no DB
class FakeProductRepository:
    def get_base_price(self, item_id: str) -> float:
        return {"widget-a": 10.0}.get(item_id, 0.0)

def test_gold_quote() -> None:
    use_case = QuoteUseCase(PricingEngine(), FakeProductRepository())
    result = use_case.get_quote("widget-a", qty=5, customer_tier="gold")
    assert result.total == 40.0

test_gold_quote()
```

```python
# ---- LEVEL 1 (lowest): Infrastructure — HTTP, DB, serialisation ----
# This layer translates between the real world and the use case language.
# It depends on level 2. Level 2 does NOT depend on this.

from fastapi import FastAPI
app = FastAPI()

# Wired in Main (Ch 26); not created here
use_case: QuoteUseCase = ...  # injected

@app.get("/quote")
def quote_endpoint(item_id: str, qty: int, tier: str = "standard") -> dict:
    # Translate HTTP params → use case input (low → high level)
    result = use_case.get_quote(item_id=item_id, qty=qty, customer_tier=tier)
    # Translate use case output → HTTP response (high → low level)
    return {"item_id": result.item_id, "qty": result.qty, "total": result.total}

# PricingEngine has ZERO knowledge of HTTP, FastAPI, or databases.
# ❌ This would be a level violation: PricingEngine importing FastAPI
```

## Quick Reference
- Level = distance from I/O (high = far from I/O)
- Dependencies: low-level → high-level (imports only point inward)
- A domain class that imports `fastapi`, `boto3`, or `sqlalchemy` has inverted the hierarchy
- Test: can you call the use case from a unit test with no infrastructure? If not, level is wrong
