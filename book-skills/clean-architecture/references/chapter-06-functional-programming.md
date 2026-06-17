# Chapter 6: Functional Programming


## Summary
Functional programming's defining constraint is immutability — the elimination of assignment. Immutable values cannot produce race conditions, making concurrent programs safe by construction. Martin connects this to architecture: systems should segregate mutable state to narrow, explicitly-managed components. Event sourcing — storing a log of transactions rather than current state — is the extreme functional architecture: the entire application state is derivable from replaying events, enabling perfect auditability and horizontal scalability.

## Key Principles
- **Immutability eliminates concurrency hazards**: No assignment → no shared mutable state → no locks required.
- **Segregate mutability**: Pure functions at the core; mutation isolated at the edges (I/O layer).
- **Event sourcing**: Store events (facts), not state (current value). State = fold over events. Unlimited undo, audit trail, replay.
- **Referential transparency**: A function called with the same inputs always returns the same output — independently testable, cacheable, parallelisable.

## Anti-Patterns
- Shared mutable global state in multi-threaded services
- Mutating input arguments inside functions
- Storing "current state" when storing "event log" would be more durable and auditable

## Python Examples

### ❌ Bad: Mutable shared state — race conditions under concurrency
```python
inventory = {}  # global mutable state

def reserve_item(item_id: str, qty: int) -> bool:
    if inventory.get(item_id, 0) >= qty:
        inventory[item_id] -= qty  # race condition if two threads hit this
        return True
    return False
```

### ✅ Good: Immutable events + derived state
```python
from dataclasses import dataclass
from typing import Sequence
from functools import reduce

@dataclass(frozen=True)
class InventoryEvent:
    item_id: str
    delta: int   # positive = stock added, negative = reserved

def apply_event(state: dict[str, int], event: InventoryEvent) -> dict[str, int]:
    current = state.get(event.item_id, 0)
    return {**state, event.item_id: current + event.delta}

def current_inventory(events: Sequence[InventoryEvent]) -> dict[str, int]:
    return reduce(apply_event, events, {})

# Events are immutable facts. State is always derived — never stored directly.
# Replay from any point. Audit trail is the source of truth.
events = [
    InventoryEvent("widget-a", 100),
    InventoryEvent("widget-a", -3),
    InventoryEvent("widget-a", -5),
]
assert current_inventory(events) == {"widget-a": 92}
```

### ✅ Segregate mutability: pure core, impure edges
```python
# Pure core — all logic, no side effects
def calculate_discount(order_total: float, tier: str) -> float:
    tiers = {"gold": 0.20, "silver": 0.10, "bronze": 0.05}
    return order_total * tiers.get(tier, 0.0)

# Impure edge — I/O only, no logic
def apply_and_persist_discount(order_id: str, db) -> float:
    order = db.get_order(order_id)            # impure: reads DB
    discount = calculate_discount(           # pure: testable in isolation
        order.total, order.customer_tier
    )
    db.update_order(order_id, discount=discount)  # impure: writes DB
    return discount
```

## Quick Reference
- Immutability = no race conditions by construction
- Isolate mutation to the I/O edge; keep business logic pure
- Event sourcing = events are facts, state is derived — audit trail is free
- Pure functions: same input → same output → trivially testable and parallelisable
