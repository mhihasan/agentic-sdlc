# Chapter 9: LSP — The Liskov Substitution Principle

## Summary
Subtypes must be substitutable for their base types without altering the correctness of the program. LSP violations force callers to use `isinstance()` or `type()` checks — creating coupling to concrete types. Martin extends LSP beyond class hierarchies to REST APIs and microservices: any service claiming to implement an interface contract must honour it fully and identically across all implementations.

## Key Principles
- **Substitutability**: Code using a base type must work correctly with any subtype, without modification.
- **No weakening postconditions**: A subtype must deliver at least what the base type promises.
- **No strengthening preconditions**: A subtype must accept at least what the base type accepts.
- **Extends to services**: REST endpoints are interface contracts — all implementations must honour them identically.

## Python Example

```python
# ❌ Bad: LSP violation — Square silently breaks Rectangle's contract
class Rectangle:
    def __init__(self, w: float, h: float) -> None:
        self.width = w
        self.height = h

    def area(self) -> float:
        return self.width * self.height

class Square(Rectangle):
    def __setattr__(self, name: str, value: float) -> None:
        # Forces both sides equal — violates Rectangle's independent-sides contract
        if name in ("width", "height"):
            super().__setattr__("width", value)
            super().__setattr__("height", value)
        else:
            super().__setattr__(name, value)

def stretch_and_measure(r: Rectangle) -> float:
    r.width = 5
    r.height = 4
    return r.area()     # expects 20

rect = Rectangle(1, 1)
sq = Square(1, 1)
assert stretch_and_measure(rect) == 20.0       # ✅
assert stretch_and_measure(sq) == 20.0         # ❌ returns 16 — LSP violated
```

```python
# ✅ Good: Don't force substitutability where the geometry doesn't allow it
from typing import Protocol

class Shape(Protocol):
    def area(self) -> float: ...

class Rectangle:
    def __init__(self, width: float, height: float) -> None:
        self.width = width
        self.height = height

    def area(self) -> float:
        return self.width * self.height

class Square:
    def __init__(self, side: float) -> None:
        self.side = side

    def area(self) -> float:
        return self.side ** 2

def total_area(shapes: list[Shape]) -> float:
    return sum(s.area() for s in shapes)

# Both satisfy Shape.area() — no substitution contract broken.
# Code using Shape never needs to stretch dimensions.
assert total_area([Rectangle(5, 4), Square(3)]) == 29.0
```

```python
# LSP applied to service contracts
# Any implementation of this contract must behave identically from the caller's view.
from typing import Protocol

class BillingGateway(Protocol):
    def charge(self, user_id: str, amount: float) -> bool:
        """True = charged. False = insufficient funds. Raises on network error."""
        ...

class StripeBillingGateway:
    def charge(self, user_id: str, amount: float) -> bool:
        return stripe_client.charge(user_id, amount)

class FakeBillingGateway:
    def __init__(self, should_succeed: bool = True) -> None:
        self.charges: list[tuple[str, float]] = []
        self._succeed = should_succeed

    def charge(self, user_id: str, amount: float) -> bool:
        self.charges.append((user_id, amount))
        return self._succeed       # honours contract — same return semantics

# ❌ LSP violation at service level:
class BrokenBillingGateway:
    def charge(self, user_id: str, amount: float) -> None:  # returns None, not bool
        # or: raises Exception instead of returning False for insufficient funds
        stripe_client.charge(user_id, amount)
# Callers expecting bool break silently.
```

```python
# LSP smell: isinstance() check = LSP violated somewhere upstream
def process_payment(gateway: BillingGateway, user_id: str, amount: float) -> str:
    if isinstance(gateway, FakeBillingGateway):   # ❌ this check is the smell
        return "test mode"
    return "charged" if gateway.charge(user_id, amount) else "declined"
# The correct fix is to ensure FakeBillingGateway honours the full contract.
```

## Quick Reference
- LSP: callers of a Protocol must never need to inspect the concrete type
- Smell: `isinstance(obj, ConcreteSubtype)` inside calling code
- Python: use `Protocol` — structure guarantees substitutability via mypy
- Applies to REST APIs and microservices: contract violations cause distributed LSP failures
