# Chapter 5: Object-Oriented Programming

## Summary
Martin debunks the standard definition of OOP (encapsulation, inheritance, polymorphism) — all three existed in C before OOP. OOP's unique and critical contribution is **safe, convenient polymorphism**, which enables **Dependency Inversion**: making source-code dependencies point *opposite* to the flow of control. This is the foundation of plugin architectures and makes Clean Architecture possible.

## Key Principles
- **Polymorphism enables DIP**: In procedural code, call graphs mirror dependency graphs. With polymorphism, a module can depend on an abstraction while calling concrete implementations at runtime.
- **Plugin architecture**: High-level business logic becomes independent of low-level I/O details because dependencies point inward via interfaces.
- **Python note**: Python achieves this without forcing inheritance. `Protocol` gives you compile-time (mypy) and duck-type (runtime) polymorphism with zero coupling between the interface definition and its implementors.

## Anti-Patterns
- Depending directly on concrete classes across layer boundaries
- Using inheritance for code reuse instead of composition + protocols
- Letting framework base classes appear in the business logic layer

## Python Example

```python
# ❌ Bad: Business logic directly imports a concrete infrastructure class
import psycopg2

class OrderService:
    def get_order(self, order_id: str) -> dict:
        conn = psycopg2.connect("postgresql://...")   # concrete DB dependency
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM orders WHERE id = %s", (order_id,))
        return dict(cursor.fetchone())
# Cannot test without a real database.
# Switching to DynamoDB requires rewriting OrderService.
```

```python
# ✅ Good: Dependency Inversion via Protocol — zero coupling to implementation
from typing import Protocol
from dataclasses import dataclass

@dataclass
class Order:
    order_id: str
    user_id: str
    total: float

# Protocol defined in the business layer (inner ring).
# Implementors in the infrastructure layer do NOT import this Protocol —
# they just need to have the right method signatures. Duck typing handles the rest.
class OrderRepository(Protocol):
    def find_by_id(self, order_id: str) -> Order | None: ...

class OrderService:
    def __init__(self, repo: OrderRepository) -> None:
        self._repo = repo                      # depends on Protocol, not Postgres

    def get_order(self, order_id: str) -> Order:
        order = self._repo.find_by_id(order_id)
        if order is None:
            raise ValueError(f"Order {order_id} not found")
        return order

# Postgres implementation (outer ring) — does NOT import OrderRepository
class PostgresOrderRepository:
    def find_by_id(self, order_id: str) -> Order | None:
        # ... psycopg2 implementation ...
        pass
    # mypy confirms this satisfies OrderRepository without any inheritance

# In-memory stub for tests — runs in microseconds, no database
class InMemoryOrderRepository:
    def __init__(self, orders: dict[str, Order]) -> None:
        self._orders = orders

    def find_by_id(self, order_id: str) -> Order | None:
        return self._orders.get(order_id)

# Tests: zero infrastructure required
def test_get_order_raises_when_missing() -> None:
    service = OrderService(InMemoryOrderRepository({}))
    try:
        service.get_order("missing-id")
        assert False, "Expected ValueError"
    except ValueError:
        pass

def test_get_order_returns_correct_order() -> None:
    order = Order("o1", "u1", 99.99)
    service = OrderService(InMemoryOrderRepository({"o1": order}))
    assert service.get_order("o1") == order
```

## Why Protocol > ABC in Python

```python
# ABC forces the outer ring to import from the inner ring (violates DIP slightly):
from domain.repositories import OrderRepository  # outer imports inner for inheritance

class PostgresOrderRepository(OrderRepository):  # must inherit
    ...

# Protocol: outer ring needs no import at all
class PostgresOrderRepository:           # no import, no inheritance
    def find_by_id(self, order_id: str) -> Order | None: ...
    # mypy infers Protocol compliance structurally
```

## Quick Reference
- OOP's value = safe polymorphism = dependency inversion
- Python: use `Protocol` (PEP 544) not `ABC` for interface definitions across layers
- Implementors in the outer ring need not import the Protocol — duck typing handles it
- Concrete implementations are plugins to the abstract core
