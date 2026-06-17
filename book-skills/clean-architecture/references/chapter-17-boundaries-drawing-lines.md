# Chapter 17: Boundaries — Drawing Lines


## Summary
Boundaries separate things that *matter* from things that *don't yet matter* (implementation details). Draw a boundary between two components when they change for different reasons and at different rates. The GUI changes frequently; the business rules rarely. The database schema is a detail; the business entities are not. Every boundary is a decision to *delay* — it says "we don't need to commit to this yet."

## Key Principles
- **Boundary = different rate of change**: If A and B change for different reasons at different rates, put a boundary between them.
- **GUI is a detail**: The user interface is just one of many possible I/O devices. Architect the core independently of it.
- **Database is a detail**: The data model matters; the storage engine does not.
- **Boundaries protect the core**: The business rules are in the centre; all volatile details are outside, depending inward.

## Python Example

```python
# ❌ Bad: No boundary — business logic knows about the HTTP layer
from flask import request, jsonify

def place_order():
    data = request.json              # Flask-specific object in business logic
    if data["qty"] > data["stock"]:
        return jsonify({"error": "out of stock"}), 400
    # ... business logic mixed with HTTP details
    return jsonify({"order_id": new_order.id}), 201
```

```python
# ✅ Good: Boundary drawn — HTTP is a thin adapter, business logic is pure
from dataclasses import dataclass

# ---- Business logic (inner layer, no HTTP) ----
@dataclass
class PlaceOrderRequest:
    user_id: str
    item_id: str
    qty: int

@dataclass
class PlaceOrderResponse:
    success: bool
    order_id: str | None = None
    error: str | None = None

class PlaceOrderUseCase:
    def execute(self, req: PlaceOrderRequest) -> PlaceOrderResponse:
        # pure business logic — no Flask, no HTTP
        if not self._check_stock(req.item_id, req.qty):
            return PlaceOrderResponse(success=False, error="out of stock")
        order = self._create_order(req)
        return PlaceOrderResponse(success=True, order_id=order.id)

# ---- HTTP adapter (outer layer) ----
from flask import Flask, request, jsonify

app = Flask(__name__)
use_case = PlaceOrderUseCase(...)

@app.post("/orders")
def place_order_endpoint():
    body = request.json
    req = PlaceOrderRequest(
        user_id=body["user_id"],
        item_id=body["item_id"],
        qty=body["qty"],
    )
    resp = use_case.execute(req)
    if not resp.success:
        return jsonify({"error": resp.error}), 400
    return jsonify({"order_id": resp.order_id}), 201
```

## Quick Reference
- Draw boundaries where rates of change differ
- GUI, DB, frameworks: outer layers, volatile, replaceable
- Business rules: inner layer, stable, boundary-protected
- "Can I replace the DB without touching business logic?" — this is the test

---

