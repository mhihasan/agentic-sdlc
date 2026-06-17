# Chapter 28: The Test Boundary


## Summary
Tests are a component in the architecture — the outermost ring. The Fragile Tests Problem: tests coupled to implementation details (internal function names, DB schema, HTTP routes) break with every refactor, making developers afraid to change code. Tests should use the same abstraction boundaries the production system uses. A testable API — a set of interactors and data structures — lets tests bypass GUI and DB entirely.

## Key Principles
- **Tests are system components**: They follow the Dependency Rule — they depend on inner rings, inner rings never depend on them.
- **Fragile Tests Problem**: Tests that know about implementation details become a barrier to refactoring.
- **Test-specific API**: A suite of interactors and data structures that tests use directly — avoiding GUI and DB layers.
- **Design for testability = good architecture**: If a system is hard to test, its architecture is flawed.

## Python Example

```python
# ❌ Bad: Tests coupled to implementation — every refactor breaks them
def test_create_order_via_http():
    # Knows about: Flask routes, JSON schema, DB table structure
    response = client.post("/api/v1/orders", json={
        "user_id": 1,
        "items": [{"sku": "ABC", "qty": 2}]
    })
    assert response.status_code == 201
    # Now checks the DB directly — knows about table structure
    row = db.execute("SELECT * FROM orders WHERE user_id=1").fetchone()
    assert row["status"] == "pending"
# If you rename the route, change the JSON schema, or rename the DB column:
# test breaks. None of those changes altered the business rule being tested.
```

```python
# ✅ Good: Tests use the use case layer directly — bypass HTTP and DB
from order_management.use_cases import PlaceOrder, PlaceOrderRequest
from tests.fakes import InMemoryOrderRepository, FakeInventoryService

def test_place_order_creates_pending_order():
    repo = InMemoryOrderRepository()
    inventory = FakeInventoryService(available={"ABC": 10})
    use_case = PlaceOrder(repo=repo, inventory=inventory)

    result = use_case.execute(PlaceOrderRequest(
        user_id="user-1", item_id="ABC", qty=2
    ))

    assert result.success
    saved = repo.find(result.order_id)
    assert saved.status == "pending"
    assert saved.qty == 2

# This test:
# - Survives route renaming, JSON schema changes, DB column renaming
# - Runs in <1ms (no HTTP, no DB)
# - Tests exactly one business rule: PlaceOrder creates a pending order
```

```python
# Test API: a dedicated interactor layer for tests
# For end-to-end tests, expose a "Test API" that bypasses the GUI

class TestApplicationAPI:
    """API used by integration tests — bypasses HTTP entirely."""
    def __init__(self, use_cases: dict):
        self._use_cases = use_cases

    def place_order(self, user_id: str, item_id: str, qty: int):
        return self._use_cases["place_order"].execute(
            PlaceOrderRequest(user_id=user_id, item_id=item_id, qty=qty)
        )

    def get_order(self, order_id: str):
        return self._use_cases["get_order"].execute(order_id)
```

## Quick Reference
- Tests follow the Dependency Rule: depend on inner rings, never the reverse
- Fragile tests = tests coupled to implementation = barrier to refactoring
- Test at the use case layer: survives all UI and DB changes
- "Hard to test" is an architecture smell, not a testing problem

---

