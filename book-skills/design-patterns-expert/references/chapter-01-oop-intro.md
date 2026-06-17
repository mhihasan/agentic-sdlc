# Chapter 1: OOP Fundamentals — Basics, Pillars, Relations

## Summary
Object-Oriented Programming models software around objects — bundles of state (fields) and
behaviour (methods). A class is the blueprint; an object is the instance. OOP's four pillars —
Abstraction, Encapsulation, Inheritance, and Polymorphism — work together to manage complexity
at scale. Understanding object relations (dependency, association, aggregation, composition)
is essential for reading and drawing architecture diagrams throughout the rest of the book.

## Key Principles
- **Abstraction**: Expose only the interface a client needs; hide implementation details behind it.
- **Encapsulation**: Bundle data and the methods that operate on it; control access via public/private boundaries.
- **Inheritance**: A subclass inherits and can extend or override the parent's interface and implementation. Prefer composition over deep hierarchies.
- **Polymorphism**: The same method call behaves differently depending on the runtime type of the object.
- **Composition > Inheritance**: Favour HAS-A relationships over IS-A to avoid brittle coupling.
- **Object Relations**: Dependency < Association < Aggregation < Composition (increasing coupling strength).

## Python Example

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Protocol

# ❌ Bad: No abstraction — client coupled to concrete class & mutable state exposed
class BankAccountBad:
    balance = 0  # public mutable field — anyone can corrupt it

    def process(self, amount, kind):  # God method, no polymorphism
        if kind == "deposit":
            self.balance += amount
        elif kind == "withdraw":
            self.balance -= amount

# ✅ Good: Encapsulation + Abstraction + Polymorphism

class Transaction(Protocol):
    def apply(self, balance: float) -> float: ...

@dataclass
class Deposit:
    amount: float
    def apply(self, balance: float) -> float:
        return balance + self.amount

@dataclass
class Withdrawal:
    amount: float
    def apply(self, balance: float) -> float:
        if self.amount > balance:
            raise ValueError("Insufficient funds")
        return balance - self.amount

class BankAccount:
    def __init__(self, owner: str, initial: float = 0.0) -> None:
        self._owner = owner
        self._balance = initial  # encapsulated — no direct field access

    @property
    def balance(self) -> float:
        return self._balance

    def apply(self, tx: Transaction) -> None:
        self._balance = tx.apply(self._balance)

# Polymorphism: same call, different behaviour
account = BankAccount("Alice", 1000.0)
for tx in [Deposit(500), Withdrawal(200)]:
    account.apply(tx)

assert account.balance == 1300.0


# Object Relation demo — Composition (Engine is part of Car; can't exist without it)
@dataclass
class Engine:
    horsepower: int

@dataclass
class Car:
    model: str
    engine: Engine = field(default_factory=lambda: Engine(150))  # composed, not inherited

# Aggregation (Team holds Players, but Players can exist without Team)
@dataclass
class Player:
    name: str

class Team:
    def __init__(self) -> None:
        self._roster: list[Player] = []

    def add(self, player: Player) -> None:
        self._roster.append(player)
```

## Quick Reference
- **Class vs Object**: class = blueprint; object = instance with state
- **Encapsulation**: private fields + public methods; Python convention `_field`
- **Polymorphism in Python**: duck typing or `Protocol` — no `implements` keyword needed
- **Dependency**: weakest — A uses B as a parameter/local, no field reference
- **Association**: A holds a reference to B as a field
- **Aggregation**: A holds B but B can live independently (HAS-A, weak ownership)
- **Composition**: A owns B exclusively — B's lifecycle tied to A (HAS-A, strong ownership)
- **Inheritance trap**: every added level multiplies coupling; prefer flat hierarchies
