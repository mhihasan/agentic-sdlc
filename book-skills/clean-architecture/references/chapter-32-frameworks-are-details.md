# Chapter 32: Frameworks Are Details


## Summary
Frameworks are powerful but ask a high price: they demand you structure your code around them, inherit from their base classes, and accept their conventions as architectural constraints. Martin calls this "marrying the framework." The risk: when the framework evolves or is replaced, the entire codebase must be refactored. Treat frameworks as tools — use them in the outermost ring only, never let them penetrate the business logic.

## Key Principles
- **Don't marry the framework**: Use it; don't build your architecture around it.
- **Framework base classes belong in the outer ring**: Never inherit from Flask/Django/SQLAlchemy base classes in entities or use cases.
- **Framework conventions ≠ architecture**: MVC, ActiveRecord, route-based organisation are framework conventions, not architectural decisions.
- **Defer framework selection**: A testable system can defer the choice of web framework until the last responsible moment.

## Anti-Patterns
- Django ORM models used directly as domain entities
- Flask `current_app` accessed from within business logic
- FastAPI `Depends()` injected into use case constructors
- `@app.route` decorators on business logic functions

## Python Example

```python
# ❌ Bad: Business logic married to Django
from django.db import models
from django.core.mail import send_mail

class Order(models.Model):    # ← business entity depends on Django ORM
    user = models.ForeignKey("User", on_delete=models.CASCADE)
    total = models.DecimalField(max_digits=10, decimal_places=2)

    def complete(self):
        self.status = "complete"
        self.save()                      # ← direct DB call in entity
        send_mail("Order complete", ...) # ← email sending in entity
# Switching frameworks: rewrite Order. Testing: requires Django test runner.
```

```python
# ✅ Good: Framework at arm's length — entity has zero framework imports
from dataclasses import dataclass
from decimal import Decimal

@dataclass
class Order:                 # pure Python — no Django, no SQLAlchemy
    order_id: str
    user_id: str
    total: Decimal
    status: str = "pending"

    def complete(self) -> "Order":
        return Order(self.order_id, self.user_id, self.total, status="complete")

# Use case — no framework
class CompleteOrder:
    def __init__(self, repo: OrderRepository, notifier: EmailNotifier):
        self._repo = repo
        self._notifier = notifier

    def execute(self, order_id: str) -> Order:
        order = self._repo.find(order_id)
        completed = order.complete()
        self._repo.save(completed)
        self._notifier.send_completion(order.user_id, order_id)
        return completed

# Django lives only in ring 4:
# infrastructure/django_models.py  — ORM models
# web/django_views.py              — URL handlers
# infrastructure/django_email.py   — send_mail wrapper
```

## Quick Reference
- Framework = tool, not architecture — outer ring only
- Never inherit from framework base classes in entities or use cases
- "Replacing the framework" should require changes only in ring 4
- Test: can you run your entire test suite with zero framework imports in the business logic?

---