# Chapter 2: What Are Design Patterns & Why Learn Them

## Summary
Design patterns are reusable solutions to commonly occurring problems in software design — not
copy-paste code, but a description or template for solving a problem in any context. They were
popularised by the "Gang of Four" (GoF) in 1994. Patterns are organised into three categories:
Creational (how objects are created), Structural (how objects are composed), and Behavioural
(how objects communicate). Learning patterns gives engineers a shared vocabulary and prevents
re-inventing solutions to problems already solved.

## Key Principles
- **Pattern ≠ Algorithm**: An algorithm is a concrete set of steps; a pattern is a higher-level description of a solution whose implementation varies by language and context.
- **Three families**: Creational, Structural, Behavioural — each addresses a different dimension of design.
- **Shared vocabulary**: Saying "use Observer here" communicates intent faster than describing pub/sub from scratch.
- **Patterns expose trade-offs**: Every pattern solves one problem while introducing its own complexity cost. Don't apply blindly.
- **Context matters**: Patterns are not universally applicable — the same problem solved differently in a small script vs. a large platform.

## Python Example

```python
# ❌ Bad: Re-inventing pub/sub from scratch with ad-hoc coupling
class OrderService:
    def __init__(self, email_svc, sms_svc, audit_svc):
        self._email = email_svc
        self._sms = sms_svc
        self._audit = audit_svc

    def place_order(self, order):
        # Business logic entangled with notification logic
        self._email.send(f"Order {order.id} placed")
        self._sms.send(f"Order {order.id} placed")
        self._audit.log(f"Order {order.id} placed")

# ✅ Good: Named pattern (Observer) communicates intent immediately
from typing import Protocol

class OrderObserver(Protocol):
    def on_order_placed(self, order_id: str) -> None: ...

class OrderService:
    def __init__(self) -> None:
        self._observers: list[OrderObserver] = []

    def subscribe(self, obs: OrderObserver) -> None:
        self._observers.append(obs)

    def place_order(self, order_id: str) -> None:
        # Pure business logic — notification is a concern of observers
        print(f"Processing order {order_id}")
        for obs in self._observers:
            obs.on_order_placed(order_id)

# Any new notification type plugs in without touching OrderService
class EmailNotifier:
    def on_order_placed(self, order_id: str) -> None:
        print(f"[Email] Order {order_id} confirmed")

class AuditLogger:
    def on_order_placed(self, order_id: str) -> None:
        print(f"[Audit] Order {order_id} logged")

svc = OrderService()
svc.subscribe(EmailNotifier())
svc.subscribe(AuditLogger())
svc.place_order("ORD-001")
```

## Quick Reference
- **Creational patterns**: Factory Method, Abstract Factory, Builder, Prototype, Singleton
- **Structural patterns**: Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy
- **Behavioural patterns**: Chain of Responsibility, Command, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor
- **GoF book**: "Design Patterns: Elements of Reusable Object-Oriented Software" (1994) — Gamma, Helm, Johnson, Vlissides
- **When NOT to apply**: Simple scripts, throw-away code, or cases where a straightforward function solves the problem cleanly
- **Pattern cost**: Every pattern adds indirection and abstractions — weigh against the actual need
