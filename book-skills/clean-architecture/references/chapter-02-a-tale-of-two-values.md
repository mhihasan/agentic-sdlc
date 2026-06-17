# Chapter 2: A Tale of Two Values

## Summary
Software delivers two values: **behavior** (what it does right now) and **structure** (how easy it is to change). Developers are incentivised to prioritise behavior — it's visible and demanded. Structure is invisible until it's gone. Martin argues structure is the more important value: a system that does the right thing but cannot be changed is a dead end; a system that does the wrong thing but can be changed can be fixed. Architects must fight to preserve structure even under business pressure.

## Key Principles
- **Behavior vs. Structure**: Behavior satisfies current requirements. Structure enables all future requirements. Sacrificing structure for behavior is borrowing against the future at compound interest.
- **The Eisenhower Matrix**: Urgent = behavior (bugs, features demanded now). Important = structure (architecture, tests). Developers always do urgent first. Architects must force Important-but-Not-Urgent onto the agenda.
- **Architecture is a business concern**: A system that cannot change has zero long-term business value.
- **Fight for architecture**: Architects have a professional responsibility to push back on decisions that damage structure.

## Anti-Patterns
- "Just this once we skip the tests/refactor" per sprint
- "We'll pay down tech debt later" as an actual plan
- Architecture decisions made by whoever screams loudest about features
- Measuring engineering performance only by feature throughput

## Python Example

```python
# ❌ BEHAVIOR VALUE — works today, structure sacrificed
# Any new payment method requires editing this function
def checkout(cart: dict, payment_method: str) -> bool:
    if payment_method == "credit_card":
        return charge_stripe(cart["total"], cart["card_token"])
    elif payment_method == "paypal":
        return charge_paypal(cart["total"], cart["paypal_email"])
    elif payment_method == "crypto":
        return charge_coinbase(cart["total"], cart["wallet"])
    # Adding Apple Pay: must edit this function, re-test everything
```

```python
# ✅ STRUCTURE VALUE — more work now, pays forever
# Python's duck typing makes this even simpler than Java/C# — no base class needed.
from typing import Protocol

class PaymentGateway(Protocol):
    # Protocol = structural subtyping: any object with this method qualifies.
    # The implementor does NOT need to import or inherit from this Protocol.
    def charge(self, amount: float, token: str) -> bool: ...

def checkout(cart: dict, gateway: PaymentGateway) -> bool:
    return gateway.charge(cart["total"], cart["token"])

# Adding Apple Pay: write a new class with a charge() method. Zero other changes.
class ApplePayGateway:                 # no inheritance required
    def charge(self, amount: float, token: str) -> bool:
        return apple_pay_client.debit(token, amount)

# mypy verifies ApplePayGateway satisfies PaymentGateway — statically, no runtime overhead.
```

```python
# The Eisenhower Matrix applied to engineering decisions
from enum import Enum

class WorkType(Enum):
    URGENT_IMPORTANT     = "Production outage, security breach"
    URGENT_NOT_IMPORTANT = "Feature request from loudest stakeholder"
    IMPORTANT_NOT_URGENT = "Refactor, architecture, test coverage"   # architects own this
    NEITHER              = "Gold-plating, premature optimisation"

# The trap: URGENT_NOT_IMPORTANT crowds out IMPORTANT_NOT_URGENT every sprint.
# After 18 months: structure degraded, cost of change 5x.
```

## Quick Reference
- Two values: behavior (urgent) and structure (important)
- Structure outlasts any individual feature — protect it unconditionally
- Tech debt is an ongoing tax on every future feature, not a planning line item
- Architects must argue for structure investment; stakeholders never ask for it
