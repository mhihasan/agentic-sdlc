# Chapter 34: The Missing Chapter (Simon Brown)


## Summary
Simon Brown's contribution addresses the gap between Clean Architecture theory and codebase reality: how do you actually structure your code? Four strategies, evaluated honestly:

| Strategy | Structure | Enforces Boundaries? | Team Ergonomics |
|---|---|---|---|
| **Package-by-Layer** | `models/`, `services/`, `repos/` | ❌ No | Poor — scattered business logic |
| **Package-by-Feature** | `order/`, `billing/`, `user/` | Partial | Good — co-located changes |
| **Ports & Adapters** | `domain/`, `application/`, `adapters/` | ✅ Yes | Excellent — explicit boundary |
| **Package-by-Component** | `OrderComponent/` (coarse-grained) | ✅ Yes | Best for teams |

Brown's recommendation: **Package-by-Component** — a coarse-grained component contains all implementation details behind a clean public interface. The component boundary is enforced by access modifiers (or Python `__all__` + underscore conventions).

## Key Principles
- **Package organisation encodes architectural intent**: The directory structure is your first line of architectural enforcement.
- **Package-by-layer is the worst option**: It scatters a single business capability across 4+ directories.
- **Package-by-component**: Each component exposes a stable public interface; internal implementation uses private modules.
- **Architecture must be enforced**: Without tooling (linters, import checkers), architecture decays. Name and document the rules; automate their enforcement.

## Python Example

```python
# ❌ Worst: Package-by-Layer
# A change to "how orders are placed" touches ALL FOUR of these:
# models/order.py
# services/order_service.py
# repositories/order_repository.py
# schemas/order_schema.py
# No boundary enforcement — any module can import any other.


# ✅ Package-by-Feature (intermediate step)
# order_management/
#   order.py               (model + service + repo combined)
# billing/
#   billing.py
# Better: co-location. Worse: no explicit interface.


# ✅ Ports & Adapters (Hexagonal)
# order_management/
#   domain/                (entities, value objects — ring 1)
#     order.py
#   application/           (use cases, port interfaces — ring 2)
#     place_order.py
#     order_repository.py  (port/interface)
#   adapters/              (ring 3+4)
#     postgres_repo.py     (driven adapter)
#     fastapi_controller.py (driving adapter)


# ✅ Package-by-Component (Brown's recommendation)
# order_management/
#   __init__.py            ← PUBLIC API: only PlaceOrder, GetOrder exported
#   _entities.py           ← private: Order, OrderLine
#   _use_cases.py          ← private: PlaceOrder implementation
#   _repository.py         ← private: interface + SQLAlchemy implementation
#
# __init__.py:
from order_management._use_cases import PlaceOrder
from order_management._use_cases import GetOrder
__all__ = ["PlaceOrder", "GetOrder"]

# External code can only import PlaceOrder and GetOrder.
# _entities, _repository, _use_cases are private by convention.
# Import linting (e.g., import-linter) enforces this automatically.
```

```python
# Enforcing architecture with import-linter (installable: pip install import-linter)
# .importlinter config:

[importlinter]
root_package = myapp

[importlinter:contract:layers]
name = Clean Architecture layers
type = layers
layers =
    myapp.web
    myapp.order_management
    myapp.billing
    myapp.infrastructure
# Verifies: web can import order_management; order_management CANNOT import web.
# Run: lint-imports  (fails CI if violated)
```

```python
# Practical enforcement with module-level __all__ + underscore naming
# order_management/__init__.py
from ._use_cases import PlaceOrder, CancelOrder, GetOrderStatus
from ._entities import OrderStatus   # only the enum — not the full entity

__all__ = ["PlaceOrder", "CancelOrder", "GetOrderStatus", "OrderStatus"]

# Any import of order_management._entities directly from outside is:
# (a) a visible violation by naming convention
# (b) caught by import-linter in CI
```

## Quick Reference
- Package-by-layer: worst — scatters domain logic, no enforced boundaries
- Package-by-component: best — coarse-grained, stable public interface, internal details private
- Architecture decays without enforcement — use import-linter or equivalent in CI
- Public interface = `__init__.py` exports; private = `_module.py` naming