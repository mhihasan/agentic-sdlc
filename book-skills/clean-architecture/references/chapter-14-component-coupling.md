# Chapter 14: Component Coupling

## Summary
Three structural principles govern *relationships between* components. Violating them produces systems where changes cascade unpredictably, stability metrics invert, and large-scale refactoring becomes necessary.

## Key Principles

### ADP — Acyclic Dependencies Principle
The dependency graph between components must be a DAG (no cycles). Cycles produce the "morning after syndrome": you change component A and B, C, D — untouched — all break. Fix cycles with DIP (extract a shared Protocol) or by factoring out a new shared component.

### SDP — Stable Dependencies Principle
Depend in the direction of stability. **Instability I = Fan-out / (Fan-in + Fan-out)**. Stable components (I ≈ 0, many dependents, no dependencies) must not depend on unstable ones (I ≈ 1).

### SAP — Stable Abstractions Principle
Stable components must be abstract (Protocols, ABCs). Concrete components must be unstable. Components should sit near the **main sequence** (Abstractness A + Instability I ≈ 1). Zone of Pain (I=0, A=0): concrete and stable — rigid, impossible to extend. Zone of Uselessness (I=1, A=1): abstract but unstable — nobody depends on it.

## Python Example

```python
# ---- ADP: Detecting and breaking a cycle ----

# ❌ Cycle: order_mgmt → billing → user_mgmt → order_mgmt
# order_mgmt/use_cases.py: from billing.service import BillingService
# billing/service.py:      from user_mgmt.models import UserProfile
# user_mgmt/models.py:     from order_mgmt.entities import Order  ← CYCLE

# Effect: you cannot import order_mgmt without also loading billing AND user_mgmt.
# A test of order_mgmt pulls in the entire dependency ring.
# A change in user_mgmt.models can break order_mgmt tests.

# ✅ Break cycle: extract a shared Protocol into a separate component
# shared_protocols/user_context.py
from typing import Protocol

class UserContext(Protocol):
    user_id: str
    email: str

# order_mgmt imports shared_protocols.UserContext   (no cycle)
# billing    imports shared_protocols.UserContext   (no cycle)
# user_mgmt  implements UserContext                 (no import of UserContext needed)
```

```python
# ---- SDP: Measuring and enforcing stability ----
from dataclasses import dataclass

@dataclass
class Component:
    name: str
    fan_in: int    # number of components that depend on this
    fan_out: int   # number of components this depends on

    @property
    def instability(self) -> float:
        total = self.fan_in + self.fan_out
        return self.fan_out / total if total else 0.0

core_domain   = Component("CoreDomain",   fan_in=8, fan_out=0)  # I=0.0  very stable
order_svc     = Component("OrderService", fan_in=4, fan_out=2)  # I=0.33 middling
api_handlers  = Component("APIHandlers",  fan_in=0, fan_out=5)  # I=1.0  very unstable

# SDP rules verified:
assert api_handlers.instability > core_domain.instability   # ✅ unstable depends on stable
# ❌ core_domain depending on api_handlers would violate SDP:
#    stable (I=0) must not depend on unstable (I=1)

def check_sdp(depender: Component, dependee: Component) -> bool:
    """Returns True if SDP is satisfied."""
    return depender.instability >= dependee.instability

assert check_sdp(api_handlers, core_domain)    # ✅ unstable → stable
assert not check_sdp(core_domain, api_handlers)  # ❌ stable → unstable
```

```python
# ---- SAP: Stable components must be abstract ----
from typing import Protocol

# ✅ core_domain (I≈0, stable) is mostly Protocols — abstract and stable
class OrderRepository(Protocol):        # stable abstraction
    def save(self, order: object) -> None: ...
    def find_by_id(self, order_id: str) -> object | None: ...

class PricingPolicy(Protocol):          # stable abstraction
    def calculate(self, base: float, qty: int) -> float: ...

# ✅ infrastructure (I≈1, unstable) is concrete
class PostgresOrderRepository:         # concrete, volatile — no Protocol import needed
    def save(self, order: object) -> None: ...
    def find_by_id(self, order_id: str) -> object | None: ...

class TieredPricingPolicy:             # concrete, volatile
    def calculate(self, base: float, qty: int) -> float:
        return base * qty * 0.95 if qty > 10 else base * qty

# A/I main sequence check:
# core_domain:    A≈1  (mostly Protocols), I≈0  → A+I≈1 ✅ on main sequence
# infrastructure: A≈0  (all concrete),    I≈1  → A+I≈1 ✅ on main sequence
# Zone of Pain:   A=0, I=0 → concrete AND stable → impossible to change without breaking dependents
# Zone of Useless:A=1, I=1 → abstract AND unstable → nobody depends on it, pointless abstraction
```

## Quick Reference
- ADP: no cycles in component graph — use `pydeps` or `import-linter` to detect
- SDP: I(depender) ≥ I(dependee) — unstable depends on stable, never reversed
- SAP: A + I ≈ 1; stable → abstract (Protocol); unstable → concrete
- Cycle-breaking: extract shared Protocol into a neutral `shared_protocols` package
