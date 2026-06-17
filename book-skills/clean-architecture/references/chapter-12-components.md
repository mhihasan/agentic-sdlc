# Chapter 12: Components

## Summary
Components are the units of deployment: Python packages, JARs, DLLs, shared libraries. They are independently deployable and independently developable — enabling team autonomy. Martin traces the history from the 1960s (manually positioned code in memory) through static linking, to today's dynamically-loaded runtime components. The key insight: the ability to deploy independently is what grants teams the ability to develop independently.

## Key Principles
- **Component = unit of independent deployment**: If two things must always be deployed together, they are one component, not two.
- **Stable public interface**: The `__init__.py` exports are the contract. Internal modules are implementation details — volatile, freely changeable.
- **Dynamic loading enables plugins**: Python's import system loads components at runtime; `importlib` can load them based on configuration.

## Python Example

```python
# A Python package as a component
#
# my_payments/
#   __init__.py      ← stable public interface (the contract)
#   _gateway.py      ← private: changes without affecting callers
#   _stripe.py       ← private: implementation detail
#   _paypal.py       ← private: implementation detail
#   _models.py       ← private: internal data structures

# my_payments/__init__.py — PUBLIC CONTRACT, rarely changes
from ._models import PaymentRequest, PaymentResult
from ._gateway import PaymentGateway

__all__ = ["PaymentGateway", "PaymentRequest", "PaymentResult"]

# Callers always import from the package root, never from internals:
# ✅  from my_payments import PaymentGateway
# ❌  from my_payments._stripe import StripeClient  ← breaks when internals change
```

```python
# Demonstrating independent deployability
# billing_service imports my_payments by version — never by internal path

# requirements.txt / pyproject.toml:
# my-payments>=2.1.0,<3.0.0

# billing_service/use_cases.py
from my_payments import PaymentGateway, PaymentRequest, PaymentResult
# billing_service has NO knowledge of _stripe.py or _paypal.py
# my_payments can replace Stripe with Adyen internally → billing_service untouched

def charge_customer(gateway: PaymentGateway, amount: float, token: str) -> bool:
    result: PaymentResult = gateway.charge(PaymentRequest(amount=amount, token=token))
    return result.success
```

```python
# Plugin architecture via component loading
import importlib
from typing import Protocol

class StorageBackend(Protocol):
    def save(self, key: str, data: bytes) -> None: ...
    def load(self, key: str) -> bytes: ...

def load_storage_backend(module_path: str) -> StorageBackend:
    """Load a storage component by name — no import at the top of this file."""
    module = importlib.import_module(module_path)
    return module.create()       # each component exposes create()

# Configuration-driven component selection — business logic never changes
# backend = load_storage_backend("storage_s3")      # production
# backend = load_storage_backend("storage_local")   # development
# backend = load_storage_backend("storage_memory")  # tests
```

## Quick Reference
- Component = independently deployable unit (Python package, wheel, service)
- `__init__.py` is the stable contract; `_module.py` = private implementation detail
- Test: "Can we upgrade this component without touching its consumers?" — yes = good boundary
- Never import from `package._internal` — only from `package`
