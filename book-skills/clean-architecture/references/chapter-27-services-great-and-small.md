# Chapter 27: Services — Great and Small


## Summary
Microservices are not architecturally significant merely because they are deployed separately. Services that share data structures, databases, or behaviour are still coupled — they just have a network cable between their coupling. Clean Architecture applies *within* each service. The architecture is defined by dependency direction and boundary placement, not by deployment topology. Services can have architectural boundaries inside them; monoliths can have clean architectural boundaries too.

## Key Principles
- **Services are not automatically architecturally clean**: A fleet of microservices with shared DBs and shared DTOs is a distributed monolith with network overhead.
- **The Kitty Problem**: When a new feature requires coordinated changes across 5 services simultaneously, those services are not architecturally decoupled — they're just physically separated.
- **Clean Architecture inside services**: Each service should internally implement the four-ring model.
- **Services as deployment units, not architectural units**: Deployment independence ≠ architectural independence.

## Python Example

```python
# ❌ Bad: "Microservices" that are actually coupled through a shared DB
# order-service reads users table; user-service writes users table
# billing-service reads orders table; order-service writes orders table
# This is a monolith with network latency. Adding a field to users requires
# deploying 3 services simultaneously.

# ❌ Bad: Services sharing a common DTO package
# common-models/
#   order.py   # imported by order-service, billing-service, shipping-service
# A change to Order DTO requires re-deploying all three services.

# ✅ Good: Services with internal Clean Architecture + bounded context DTOs
# order-service/
#   entities.py               — Order (domain object)
#   use_cases.py              — PlaceOrder, CancelOrder
#   _api/                     — FastAPI adapter (ring 4)
#     schemas.py              — OrderRequest, OrderResponse (API-specific DTOs)
#   _db/                      — SQLAlchemy adapter (ring 4)
#     models.py               — ORM models (private to this service)

# order-service API speaks its own language.
# billing-service translates billing concepts to/from order-service's API.
# No shared code. Loose coupling through explicit contracts.

# Anti-corruption layer in billing-service:
class OrderServiceClient:
    """Translates order-service API into billing's domain concepts."""
    def get_billable_amount(self, order_id: str) -> float:
        # Call order-service, translate response into billing's domain
        raw = httpx.get(f"/orders/{order_id}").json()
        return raw["total"]  # billing only cares about total, nothing else
```

## Quick Reference
- Microservices ≠ clean architecture by default
- Services sharing DB or DTOs = distributed monolith
- Clean Architecture applies inside each service: same 4-ring model
- Anti-corruption layer: translate between service boundaries without leaking domain concepts

---

