# Chapter 3: Design Principles — Encapsulate, Interface, Composition

## Summary
Three foundational design principles precede SOLID and underpin every pattern in the book.
"Encapsulate what varies" isolates change so one alteration doesn't ripple through the codebase.
"Program to an interface, not an implementation" lets you swap behaviour without changing callers.
"Favour composition over inheritance" avoids the fragile base class problem and enables runtime
flexibility that inheritance can never offer. These three principles collectively reduce coupling
and increase cohesion — the two levers that determine long-term maintainability.

## Key Principles
- **Encapsulate what varies**: Find what changes across use cases or time and put it behind an interface so the stable parts never need to touch it.
- **Program to an interface**: Callers depend on abstract contracts, not concrete classes — enables substitution and independent testing.
- **Favour composition**: Build complex behaviour by combining small, focused objects rather than layering inheritance.
- **Code quality signals**: High cohesion (each unit does one job), low coupling (units don't know each other's internals), extensibility (add features without modifying working code).
- **Reuse via composition**: Two unrelated classes can share behaviour by delegating to the same strategy object — inheritance would force an artificial IS-A relationship.

## Python Example

```python
from typing import Protocol
from dataclasses import dataclass

# ❌ Bad: Tax calculation hard-coded — changing rates requires touching OrderProcessor
class OrderProcessor:
    def total(self, price: float, country: str) -> float:
        if country == "CA":
            return price * 1.13
        elif country == "US":
            return price * 1.08
        else:
            return price  # forgotten cases silently return wrong value


# ✅ Good: Encapsulate what varies (tax calculation) behind a Protocol

class TaxStrategy(Protocol):
    def calculate(self, price: float) -> float: ...

@dataclass
class CanadianTax:
    rate: float = 0.13
    def calculate(self, price: float) -> float:
        return price * (1 + self.rate)

@dataclass
class USTax:
    rate: float = 0.08
    def calculate(self, price: float) -> float:
        return price * (1 + self.rate)

class NoTax:
    def calculate(self, price: float) -> float:
        return price


# Program to an interface — OrderProcessor knows only TaxStrategy Protocol
class OrderProcessor:
    def __init__(self, tax: TaxStrategy) -> None:
        self._tax = tax  # composed, not inherited

    def total(self, price: float) -> float:
        return self._tax.calculate(price)


# Composition lets us swap strategy at runtime
ca_order = OrderProcessor(CanadianTax())
us_order = OrderProcessor(USTax())

assert ca_order.total(100) == 113.0
assert us_order.total(100) == 108.0


# Composition vs Inheritance — Duck example from the book
class FlyBehaviour(Protocol):
    def fly(self) -> str: ...

class QuackBehaviour(Protocol):
    def quack(self) -> str: ...

class WingFlight:
    def fly(self) -> str: return "flying with wings"

class NoFlight:
    def fly(self) -> str: return "cannot fly"

class LoudQuack:
    def quack(self) -> str: return "QUACK!"

class Squeak:
    def quack(self) -> str: return "squeak"

@dataclass
class Duck:
    name: str
    _fly: FlyBehaviour
    _quack: QuackBehaviour

    def perform_fly(self) -> str: return self._fly.fly()
    def perform_quack(self) -> str: return self._quack.quack()

mallard = Duck("Mallard", WingFlight(), LoudQuack())
rubber  = Duck("RubberDuck", NoFlight(), Squeak())

assert mallard.perform_fly() == "flying with wings"
assert rubber.perform_fly()  == "cannot fly"
# Changing rubber duck's behaviour at runtime — impossible with inheritance
rubber._quack = LoudQuack()
assert rubber.perform_quack() == "QUACK!"
```

## Quick Reference
- **Encapsulate what varies**: Extract volatile parts into separate classes/functions behind an interface
- **Program to interface**: `Protocol` in Python — structural subtyping without import coupling
- **Favour composition**: `__init__` receives collaborators; swap them without subclassing
- **Cohesion**: a module/class should have one clear reason to exist
- **Coupling red flags**: `isinstance` checks, `import ConcreteClass` in business logic, deeply nested inheritance
- **Runtime flexibility**: Only composition lets you change behaviour after instantiation
- **Good design is extensible**: Adding a new tax strategy above requires zero changes to `OrderProcessor`
