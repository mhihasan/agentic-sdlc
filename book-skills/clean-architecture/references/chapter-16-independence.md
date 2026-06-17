# Chapter 16: Independence


## Summary
Good architecture supports three kinds of independence simultaneously: independent develop-ability (teams don't block each other), independent deployability (components can be released separately), and independent operation (components can scale independently). These are achieved through decoupling, which has three modes: source-level, deployment-level (binary), and service-level. Each mode has higher cost and higher decoupling strength.

## Key Principles
- **Decoupling modes**: Source (same repo, import boundaries enforced) → Deployment (separate JARs/packages) → Service (network boundary). Each step increases operational independence but also communication overhead.
- **Don't prematurely service-split**: Services are expensive (serialisation, latency, versioning). Source-level decoupling achieves the same architectural isolation at lower cost.
- **Use cases drive team structure**: If you can assign one team per use case with no shared code, you have achieved independent develop-ability.

## Python Example

```python
# Three decoupling levels for the same boundary

# Level 1: Source-level (same process, enforced by import rules)
# order_management/use_cases.py
from order_management.repositories import OrderRepository  # ✅ within component
# from billing.internal_models import ... ← forbidden by convention/linting

# Level 2: Deployment-level (separate packages)
# order-management/ is its own PyPI package with a versioned API
# pip install order-management==2.1.0
# billing imports only the public API, never internal modules

# Level 3: Service-level (HTTP/gRPC boundary)
import httpx

class OrderManagementClient:
    """Billing's view of order management — pure HTTP, no shared code."""
    def __init__(self, base_url: str):
        self._base = base_url

    def get_order(self, order_id: str) -> dict:
        resp = httpx.get(f"{self._base}/orders/{order_id}")
        resp.raise_for_status()
        return resp.json()

# Start at Level 1. Promote to Level 3 only when operational independence
# (separate scaling, separate deployment cadence) is actually needed.
```

## Quick Reference
- Three independence types: develop-ability, deployability, operability
- Three decoupling modes: source → deployment → service (increasing cost+power)
- Don't jump to microservices for decoupling you can achieve at source level

---

