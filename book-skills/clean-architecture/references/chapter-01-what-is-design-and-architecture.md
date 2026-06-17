# Chapter 1: What Is Design and Architecture?

## Summary
Martin argues there is no meaningful distinction between "design" and "architecture" — both refer to the same decisions viewed at different altitudes. Architecture describes high-level structure; design describes low-level detail — but they are a continuum, not separate concerns. The only measure of good architecture is economics: does the cost of change stay low over the system's lifetime? Bad architecture causes developer productivity to collapse exponentially as the codebase grows, even as effort increases.

## Key Principles
- **Design = Architecture**: High-level structure and low-level detail are inseparable. Treating them as separate disciplines is the root of most architectural failures.
- **The measure is cost**: Good design minimises the human resources required to build and maintain the system. If effort grows with each release, the design is failing.
- **The developer's lie**: "We can clean it up later." This never happens. Mess accumulates, productivity collapses, cost approaches infinity.
- **Slow down to go fast**: There is no short-term/long-term tradeoff. The shortcut is the catastrophe.

## Anti-Patterns
- Treating architecture as a separate phase ("we'll do it properly in v2")
- Measuring velocity by features shipped while ignoring growing drag on subsequent sprints
- Letting framework conventions dictate system structure

## Python Example

```python
# ❌ Bad: Everything in one function — fast to write, catastrophic at scale
def process_order(order_data: dict) -> dict:
    db = get_db_connection()
    user = db.query(f"SELECT * FROM users WHERE id={order_data['user_id']}")
    # validation, persistence, email, logging — all tangled together
    send_email(user["email"], f"Order {order_data['id']} confirmed")
    return {"status": "ok"}
# By release 8: adding a discount requires touching process_order,
# format_invoice, send_confirmation, update_ledger — all coupled.
# Each feature takes 4x longer than release 1.
```

```python
# ✅ Good: Isolated domain object — cost of change stays flat
from dataclasses import dataclass, replace

@dataclass(frozen=True)          # immutable value object
class Order:
    order_id: str
    user_id: str
    items: tuple[dict, ...]       # tuple keeps it hashable

    def total(self) -> float:
        return sum(i["price"] * i["qty"] for i in self.items)

    def with_discount(self, pct: float) -> "Order":
        discounted = tuple(
            {**item, "price": item["price"] * (1 - pct)}
            for item in self.items
        )
        return replace(self, items=discounted)

# Adding discounts in release 8: touches Order only.
# DB, email, HTTP layers unchanged. Cost stays flat.
```

## Quick Reference
- Architecture and design are the same thing at different zoom levels
- The metric: cost of change over the system's lifetime
- Productivity that looks high today but collapses next quarter = bad architecture
- "Clean it up later" is the most expensive lie in software
