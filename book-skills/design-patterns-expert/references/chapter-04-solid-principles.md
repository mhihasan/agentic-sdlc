# Chapter 4: SOLID Principles — SRP, OCP, LSP, ISP, DIP

## Summary
SOLID is a set of five object-oriented design principles that individually reduce fragility and
collectively make systems easier to extend without breaking existing code. SRP limits reasons
to change per class. OCP lets you add features by extension, not mutation. LSP ensures
substitution contracts are honoured. ISP keeps interfaces lean so clients only see what they
need. DIP points dependencies toward abstractions so high-level policy never depends on
low-level mechanism. Violating any one principle typically creates technical debt that
compounds with every new feature.

## Key Principles
- **SRP (Single Responsibility)**: One class → one reason to change. Split when you find yourself changing a class for unrelated reasons.
- **OCP (Open/Closed)**: Open for extension, closed for modification. Add new behaviour via new code; don't edit working code.
- **LSP (Liskov Substitution)**: A subclass must be substitutable for its base class without altering program correctness. If a subclass weakens contracts, it's not a true subtype.
- **ISP (Interface Segregation)**: Don't force clients to depend on methods they don't use. Split fat interfaces into role-specific ones.
- **DIP (Dependency Inversion)**: High-level modules depend on abstractions; low-level modules implement those abstractions. Neither depends on the other directly.

## Python Example

```python
from typing import Protocol
from dataclasses import dataclass
import json

# ══════════════════════════════════════════════
# SRP — separate report generation from persistence
# ══════════════════════════════════════════════

# ❌ Bad: one class owns both concerns
class EmployeeReportBad:
    def generate(self, emp) -> str: ...   # business logic
    def save_to_db(self, report): ...     # persistence — different reason to change

# ✅ Good
class ReportGenerator:
    def generate(self, name: str, hours: float) -> str:
        return f"{name}: {hours}h"

class ReportRepository:
    def save(self, report: str, path: str) -> None:
        with open(path, "w") as f:
            f.write(report)


# ══════════════════════════════════════════════
# OCP — add shipping methods without touching Order
# ══════════════════════════════════════════════

class ShippingStrategy(Protocol):
    def cost(self, weight_kg: float) -> float: ...

class GroundShipping:
    def cost(self, weight_kg: float) -> float:
        return weight_kg * 1.5

class AirShipping:
    def cost(self, weight_kg: float) -> float:
        return weight_kg * 5.0

# New: SameDayShipping added with zero changes to Order
class SameDayShipping:
    def cost(self, weight_kg: float) -> float:
        return weight_kg * 12.0 + 10.0

@dataclass
class Order:
    weight_kg: float
    shipping: ShippingStrategy

    def total_shipping_cost(self) -> float:
        return self.shipping.cost(self.weight_kg)

assert Order(2.0, AirShipping()).total_shipping_cost() == 10.0


# ══════════════════════════════════════════════
# LSP — subclass must honour the contract
# ══════════════════════════════════════════════

# ❌ Bad: Square breaks Rectangle contract (width/height setters are coupled)
class Rectangle:
    def __init__(self, w: float, h: float):
        self.width = w
        self.height = h
    def area(self) -> float:
        return self.width * self.height

class SquareBad(Rectangle):
    @Rectangle.width.setter  # type: ignore
    def width(self, v):
        self._width = self._height = v  # violates LSP: changing width silently changes height

# ✅ Good: Don't inherit — use a shared Protocol
class Shape(Protocol):
    def area(self) -> float: ...

@dataclass(frozen=True)
class Rect:
    width: float
    height: float
    def area(self) -> float: return self.width * self.height

@dataclass(frozen=True)
class Square:
    side: float
    def area(self) -> float: return self.side ** 2

def print_area(shape: Shape) -> None:
    print(shape.area())  # works for both — LSP satisfied via Protocol

print_area(Rect(3, 4))   # 12
print_area(Square(4))    # 16


# ══════════════════════════════════════════════
# ISP — role interfaces instead of fat interface
# ══════════════════════════════════════════════

# ❌ Bad: CloudProvider forces all implementors to support every method
class CloudProviderBad(Protocol):
    def store_file(self, path: str) -> None: ...
    def get_cdn_url(self, path: str) -> str: ...
    def run_serverless(self, fn) -> None: ...  # not all providers do this

# ✅ Good: Split into role protocols
class FileStorage(Protocol):
    def store_file(self, path: str) -> None: ...

class CDNProvider(Protocol):
    def get_cdn_url(self, path: str) -> str: ...

class FaaSProvider(Protocol):
    def run_serverless(self, fn) -> None: ...

# SimpleStorage only needs to implement FileStorage — no forced no-ops
class SimpleStorage:
    def store_file(self, path: str) -> None:
        print(f"Storing {path}")


# ══════════════════════════════════════════════
# DIP — high-level policy doesn't import low-level detail
# ══════════════════════════════════════════════

# ❌ Bad: NotificationService directly imports MySQLLogger
# from mysql_logger import MySQLLogger  # high-level depends on low-level

# ✅ Good: both depend on the abstraction
class EventLogger(Protocol):
    def log(self, event: str) -> None: ...

class NotificationService:
    def __init__(self, logger: EventLogger) -> None:
        self._logger = logger  # depends on Protocol, not MySQLLogger

    def notify(self, user: str, msg: str) -> None:
        self._logger.log(f"Notifying {user}: {msg}")

class ConsoleLogger:          # low-level detail
    def log(self, event: str) -> None:
        print(event)

class JSONFileLogger:          # another low-level detail
    def log(self, event: str) -> None:
        print(json.dumps({"event": event}))

# High-level policy unchanged when swapping logger
NotificationService(ConsoleLogger()).notify("Alice", "Hello")
NotificationService(JSONFileLogger()).notify("Bob", "Hi")
```

## Quick Reference
- **SRP**: "A class should have only one reason to change" — split by stakeholder or change axis
- **OCP**: New behaviour → new class/function; don't edit tested code. Strategy pattern is the canonical OCP enabler.
- **LSP**: If `isinstance(obj, Base)` is needed to handle a subclass differently, LSP is violated
- **ISP**: Prefer multiple focused Protocols over one large Protocol with optional methods
- **DIP**: High-level modules define the Protocol; low-level modules implement it. The Protocol lives with the consumer.
- **Python DIP idiom**: `typing.Protocol` in the high-level package; concrete adapters in the infrastructure package
- **SOLID together**: DIP makes OCP possible at module boundaries; ISP makes DIP clean; SRP keeps each module focused
