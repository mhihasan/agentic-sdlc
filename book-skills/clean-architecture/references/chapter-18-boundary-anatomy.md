# Chapter 18: Boundary Anatomy


## Summary
Boundaries are crossed via three mechanisms: function calls (monolith, cheap), process communication (sockets/pipes, medium cost), and network calls (services, expensive). All three can implement clean architectural boundaries; the choice is a deployment and operational decision, not an architectural one. In a monolith, the boundary is enforced by source-code organisation and dependency rules — the effect is identical to a service boundary at a fraction of the cost.

## Key Principles
- **All three mechanisms can implement the same boundary**: The architecture is defined by the direction of dependencies, not the deployment topology.
- **Communication cost increases with boundary crossing level**: Function call (nanoseconds) → IPC (microseconds) → network (milliseconds).
- **Monolith with clean boundaries**: Architecturally equivalent to microservices, but operationally simpler and faster.

## Python Example

```python
# Same architectural boundary, three crossing mechanisms

# --- Mechanism 1: Function call (monolith) ---
class OrderService:
    def __init__(self, billing: BillingService):
        self._billing = billing  # dependency injected, pointing inward

    def complete_order(self, order_id: str) -> None:
        order = self._get_order(order_id)
        self._billing.charge(order.user_id, order.total)  # function call

# --- Mechanism 2: Process boundary (same machine, different process) ---
import subprocess, json

class BillingServiceClient:
    def charge(self, user_id: str, amount: float) -> bool:
        result = subprocess.run(
            ["billing-service", "charge", user_id, str(amount)],
            capture_output=True, text=True
        )
        return json.loads(result.stdout)["success"]

# --- Mechanism 3: Network service ---
import httpx

class BillingServiceClient:
    def charge(self, user_id: str, amount: float) -> bool:
        resp = httpx.post(
            "https://billing.internal/charge",
            json={"user_id": user_id, "amount": amount}
        )
        return resp.json()["success"]

# OrderService.complete_order() is identical in all three cases.
# The boundary direction (OrderService → BillingService abstraction) is unchanged.
# Deployment topology is a separate decision.
```

## Quick Reference
- Boundaries exist at three levels: function call, process, network
- The boundary *direction* (which side knows about which) is the architectural decision
- Monolith + clean boundaries ≈ microservices architecturally, much cheaper operationally

---