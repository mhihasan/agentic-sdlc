# Chapter 21: Screaming Architecture


## Summary
The top-level structure of a codebase should announce its business purpose, not its framework. A healthcare system's directory tree should scream "Healthcare." A financial system should scream "Finance." If it screams "Rails" or "Django" or "Spring," the framework has colonised the architecture. The use cases are the most important thing about the system — they must be visible at the top level.

## Key Principles
- **Architecture expresses intent**: Top-level directories, package names, and module organisation should reflect domain concepts, not technical layers.
- **Frameworks are tools, not architectures**: The choice of Flask vs Django vs FastAPI should be an implementation detail, not the dominant structural force.
- **Use cases as first-class citizens**: A developer should be able to read the project structure and immediately understand what the system *does*, not how it's built.

## Anti-Patterns
- `app/models/`, `app/views/`, `app/controllers/` as top-level structure (screams MVC framework)
- `src/api/`, `src/database/`, `src/services/` (screams technical layers)

## Python Example

```python
# ❌ Bad: Screaming "Django" — framework colonised the structure
#
# myapp/
#   models/          ← Django ORM models
#     order.py
#     user.py
#   views/           ← Django views
#     order_views.py
#   serializers/     ← DRF serializers
#   urls.py
#
# What does this system DO? Impossible to tell from directory structure.
# Adding a new business capability: which 4 directories do I touch?

# ✅ Good: Screaming "Order Management" — domain is front and centre
#
# myapp/
#   order_management/
#     entities.py         (Order, OrderLine — pure domain)
#     use_cases.py        (PlaceOrder, CancelOrder, ShipOrder)
#     repositories.py     (OrderRepository interface)
#     _django_models.py   (Django ORM — implementation detail, underscore = private)
#     _views.py           (Django views — thin HTTP adapter)
#   user_management/
#     entities.py
#     use_cases.py
#   billing/
#     entities.py
#     use_cases.py
#
# What does this system do? Immediately obvious.
# Where does PlaceOrder logic live? order_management/use_cases.py
```

```python
# FastAPI example: framework as outer ring, not structural spine
# ❌ Bad: FastAPI routes contain business logic
from fastapi import FastAPI
app = FastAPI()

@app.post("/orders")
def create_order(user_id: str, item_id: str, qty: int):
    # Business logic here — screams "FastAPI app" not "Order System"
    if qty > get_stock(item_id):
        return {"error": "no stock"}
    order = save_order(user_id, item_id, qty)
    return {"order_id": order.id}

# ✅ Good: FastAPI is a plugin — business logic unchanged if you swap to Flask
from fastapi import FastAPI
from order_management.use_cases import PlaceOrder, PlaceOrderRequest

app = FastAPI()
place_order = PlaceOrder(repo=..., inventory=...)

@app.post("/orders")
def create_order_endpoint(user_id: str, item_id: str, qty: int):
    result = place_order.execute(PlaceOrderRequest(user_id, item_id, qty))
    if not result.success:
        return {"error": result.error}
    return {"order_id": result.order_id}
```

## Quick Reference
- Top-level structure should scream the domain, not the framework
- Frameworks: outer ring only, never the dominant structural organiser
- Test: can a new dev identify the 5 main use cases from the directory tree in 30 seconds?

---

