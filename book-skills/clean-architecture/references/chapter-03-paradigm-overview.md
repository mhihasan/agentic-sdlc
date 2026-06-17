# Chapter 3: Paradigm Overview

## Summary
Three paradigms have shaped programming since the 1950s: structured, object-oriented, and functional. Each paradigm *removed* a dangerous capability: structured eliminated arbitrary `goto`; OOP eliminated unrestricted function pointers; functional eliminated assignment. Paradigms are discipline, not feature sets — they constrain what you can do to protect you from yourself. All three contribute to Clean Architecture: structured = algorithmic correctness, OOP = dependency direction control, functional = data safety.

## Key Principles
- **Paradigms subtract, not add**: Each removes a dangerous freedom.
- **Structured** → sequence/selection/iteration. Enables testability and decomposition.
- **OO** → safe polymorphism. Enables dependency inversion and plugin architectures.
- **Functional** → immutability. Enables safe concurrency and event sourcing.

## Python Is All Three

Python is uniquely suited to Clean Architecture because it embraces all three paradigms natively.

```python
# STRUCTURED PARADIGM — functional decomposition, each piece testable
def calculate_tax(amount: float, rate: float) -> float:
    return amount * rate

def apply_discount(amount: float, discount_pct: float) -> float:
    return amount * (1 - discount_pct)

def final_price(base: float, discount_pct: float, tax_rate: float) -> float:
    discounted = apply_discount(base, discount_pct)
    return discounted + calculate_tax(discounted, tax_rate)
# Each function independently testable. Composition is explicit.
```

```python
# OO PARADIGM — dependency control via Protocol (Python's polymorphism)
from typing import Protocol

class NotificationSender(Protocol):
    def send(self, recipient: str, message: str) -> None: ...

def notify_user(user_email: str, msg: str, sender: NotificationSender) -> None:
    sender.send(user_email, msg)

# EmailSender, SmsSender, SlackSender — all work without inheriting anything
class EmailSender:
    def send(self, recipient: str, message: str) -> None:
        print(f"Email to {recipient}: {message}")
# Python's duck typing IS dependency inversion — no boilerplate needed.
```

```python
# FUNCTIONAL PARADIGM — immutable data, no side effects in core logic
from dataclasses import dataclass, replace
from typing import Sequence

@dataclass(frozen=True)
class CartItem:
    sku: str
    price: float
    qty: int

def apply_bulk_discount(items: Sequence[CartItem], threshold: int, pct: float) -> tuple[CartItem, ...]:
    """Pure function: same input → same output, no mutation."""
    return tuple(
        replace(item, price=item.price * (1 - pct)) if item.qty >= threshold else item
        for item in items
    )
# No shared state, no locks needed. Safe to run concurrently.
```

## Quick Reference
- No new paradigms since the 1950s–1970s — the discipline already exists
- Python supports all three natively: functions, Protocols, dataclasses/immutability
- Architecture uses all three: structure for algorithms, OO for boundaries, functional for data
