# Chapter 23: Behavioral — State

## Summary
State allows an object to alter its behaviour when its internal state changes — the object
appears to change its class. It replaces large `if/elif` or `match` blocks that branch on
a "state" variable with a set of State objects, each encapsulating the behaviour for one
state. Transitions happen by replacing the current State object on the Context. The pattern
is the right tool whenever an object's behaviour changes significantly based on its mode,
phase, or status — vending machines, order workflows, connection lifecycle, document approval.

## Key Principles
- **Context**: The main object clients interact with. It delegates all state-specific behaviour to the current State object and exposes a method to switch states.
- **State interface**: Declares methods for every state-sensitive behaviour. Each concrete State implements all of them.
- **Concrete States**: Encapsulate behaviour for one specific state. May trigger transitions by calling `context.set_state(new_state)`.
- **States initiate transitions**: Rather than the Context branching to decide next state, State objects call the transition when appropriate.
- **vs Strategy**: Strategy swaps algorithms that are interchangeable; State manages transitions between distinct modes where history matters.

## Python Example

```python
from __future__ import annotations
from typing import Protocol, Optional
from dataclasses import dataclass

# ❌ Bad: Monolithic if/elif on status field — grows unbounded
class VendingMachineBad:
    def __init__(self):
        self._state = "idle"
        self._credits = 0

    def insert_coin(self, amount: int):
        if self._state == "idle":
            self._credits += amount
            self._state = "has_credit"
        elif self._state == "has_credit":
            self._credits += amount
        elif self._state == "dispensing":
            print("Cannot insert coin while dispensing")
        # Every new state = edit this method AND every other method


# ✅ Good: State pattern

class VendingState(Protocol):
    def insert_coin(self, ctx: "VendingMachine", amount: int) -> None: ...
    def select_product(self, ctx: "VendingMachine", product: str) -> None: ...
    def dispense(self, ctx: "VendingMachine") -> Optional[str]: ...


class IdleState:
    def insert_coin(self, ctx: "VendingMachine", amount: int) -> None:
        ctx.add_credits(amount)
        ctx.set_state(ctx.states["has_credit"])
        print(f"Inserted ${amount}. Credits: ${ctx.credits}")

    def select_product(self, ctx: "VendingMachine", product: str) -> None:
        print("Please insert coins first.")

    def dispense(self, ctx: "VendingMachine") -> Optional[str]:
        print("No product selected.")
        return None


class HasCreditState:
    def __init__(self) -> None:
        self._selection: Optional[str] = None

    def insert_coin(self, ctx: "VendingMachine", amount: int) -> None:
        ctx.add_credits(amount)
        print(f"Added ${amount}. Credits: ${ctx.credits}")

    def select_product(self, ctx: "VendingMachine", product: str) -> None:
        price = ctx.price_of(product)
        if price is None:
            print(f"Unknown product: {product}")
        elif ctx.credits < price:
            print(f"Insufficient credits. Need ${price}, have ${ctx.credits}")
        else:
            self._selection = product
            ctx.set_state(ctx.states["dispensing"])
            print(f"Selected {product}. Dispensing...")

    def dispense(self, ctx: "VendingMachine") -> Optional[str]:
        print("Please select a product first.")
        return None


class DispensingState:
    def insert_coin(self, ctx: "VendingMachine", amount: int) -> None:
        print("Please wait — currently dispensing.")

    def select_product(self, ctx: "VendingMachine", product: str) -> None:
        print("Already dispensing.")

    def dispense(self, ctx: "VendingMachine") -> Optional[str]:
        item = ctx.pending_item
        ctx.deduct_credits(ctx.price_of(item) or 0)
        ctx.clear_pending()
        ctx.set_state(ctx.states["idle"] if ctx.credits == 0 else ctx.states["has_credit"])
        return item


class VendingMachine:
    def __init__(self) -> None:
        self.states = {
            "idle":       IdleState(),
            "has_credit": HasCreditState(),
            "dispensing": DispensingState(),
        }
        self._state: VendingState = self.states["idle"]
        self._credits: int = 0
        self._catalog: dict[str, int] = {"Cola": 2, "Chips": 3, "Water": 1}
        self.pending_item: Optional[str] = None

    def set_state(self, state: VendingState) -> None:
        self._state = state

    @property
    def credits(self) -> int: return self._credits
    def add_credits(self, n: int) -> None: self._credits += n
    def deduct_credits(self, n: int) -> None: self._credits -= n
    def price_of(self, product: str) -> Optional[int]: return self._catalog.get(product)
    def clear_pending(self) -> None: self.pending_item = None

    def insert_coin(self, amount: int) -> None: self._state.insert_coin(self, amount)
    def select_product(self, product: str) -> None:
        if isinstance(self._state, HasCreditState):
            self._state._selection = product  # set pending before state check
        self._state.select_product(self, product)
    def dispense(self) -> Optional[str]: return self._state.dispense(self)


machine = VendingMachine()
machine.insert_coin(2)
machine.states["dispensing"]  # type verification — state objects exist
assert machine.credits == 2
```

## Quick Reference
- **Intent**: Let an object change behaviour when its state changes — appears to change its class
- **Use when**: Many `if/elif` blocks branching on a status/mode variable; new states added often
- **Context delegates**: `context.insert_coin(n)` → `self._state.insert_coin(self, n)`
- **States transition Context**: `ctx.set_state(ctx.states["idle"])` inside State methods
- **Flyweight States**: Stateless State objects can be shared singletons via a `states` dict on Context
- **vs Strategy**: Strategy algorithms are interchangeable and stateless; States have lifecycle transitions
- **vs Command**: Command encapsulates an action; State encapsulates a mode of being
- **Transition logic**: Belongs in State objects, not in Context — keeps Context clean
- **Real uses**: Order lifecycle (pending/paid/shipped/cancelled), TCP connection states, UI modes, game AI state machines
