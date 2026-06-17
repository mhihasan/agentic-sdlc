# Chapter 15: What Is Architecture?

## Summary
Architecture is the set of decisions that shape a system into components, define how they communicate, and — critically — preserve *options*. Good architecture defers decisions about databases, frameworks, and UI as long as possible, because these are details. The primary job of architecture is to support the use cases of the system while maximising the number of decisions that have not yet been made.

## Key Principles
- **Architecture supports use cases**: Use cases are first-class citizens, not the database or framework.
- **Defer decisions**: The longer you delay choosing a database, framework, or transport protocol, the more information you'll have. Good architecture makes deferral possible.
- **Details vs. policy**: Policy = business rules. Details = I/O, UI, storage, transport. Architecture separates them.

## Python Example

```python
# ✅ Architecture that defers the DB decision
from typing import Protocol
from dataclasses import dataclass

@dataclass
class Order:
    order_id: str
    user_id: str
    item_id: str
    qty: int

@dataclass
class PlaceOrderRequest:
    user_id: str
    item_id: str
    qty: int

@dataclass
class PlaceOrderResponse:
    success: bool
    order_id: str | None = None
    reason: str | None = None

# Protocol defined — implementation deferred
class OrderRepository(Protocol):
    def save(self, order: Order) -> None: ...

class InventoryService(Protocol):
    def is_available(self, item_id: str, qty: int) -> bool: ...

class PlaceOrder:
    def __init__(self, orders: OrderRepository, inventory: InventoryService) -> None:
        self._orders = orders                  # ← injected, not imported
        self._inventory = inventory

    def execute(self, req: PlaceOrderRequest) -> PlaceOrderResponse:
        if not self._inventory.is_available(req.item_id, req.qty):
            return PlaceOrderResponse(success=False, reason="Out of stock")
        order = Order(
            order_id=generate_id(),
            user_id=req.user_id,
            item_id=req.item_id,
            qty=req.qty,
        )
        self._orders.save(order)
        return PlaceOrderResponse(success=True, order_id=order.order_id)

# At development time: in-memory repos — no DB decision needed yet
class InMemoryOrderRepository:
    def __init__(self) -> None:
        self._store: dict[str, Order] = {}

    def save(self, order: Order) -> None:
        self._store[order.order_id] = order

class AlwaysAvailableInventory:
    def is_available(self, item_id: str, qty: int) -> bool:
        return True

# Fully testable today — PostgreSQL decision can wait until load testing
use_case = PlaceOrder(
    orders=InMemoryOrderRepository(),
    inventory=AlwaysAvailableInventory(),
)
result = use_case.execute(PlaceOrderRequest("user-1", "widget-a", 3))
assert result.success
```

## Quick Reference
- Architecture = component shapes + communication rules + preserved options
- Primary job: support use cases, defer detail decisions
- "What database?" is a detail — the answer should not constrain architecture
- If you can't test a use case without a database, architecture is wrong
