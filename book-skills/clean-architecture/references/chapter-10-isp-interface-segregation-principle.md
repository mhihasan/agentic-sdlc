# Chapter 10: ISP — The Interface Segregation Principle

## Summary
Don't depend on things you don't use. Fat interfaces force clients to depend on methods they never call — a change to any method triggers recompilation or redeployment of every client, even those that don't use the changed method. In Python this manifests as: importing a large module for one function, pulling in a heavy dependency to use one method, or declaring a Protocol that no concrete type can fully satisfy. Narrow, role-specific interfaces ensure each client depends only on what it needs.

## Key Principles
- **Role interfaces**: Define one Protocol per client role, not one per implementation.
- **Fat interface cost**: Changes to unused methods force client rebuilds and create false coupling.
- **Python-specific**: Even unused `import` statements create dependency coupling — ISP applies at module level too.

## Python Example

```python
# ❌ Bad: Fat Protocol — Robot is forced to acknowledge methods it cannot satisfy
from typing import Protocol

class Worker(Protocol):
    def work(self) -> None: ...
    def eat(self) -> None: ...    # robots don't eat
    def sleep(self) -> None: ...  # robots don't sleep

class Robot:
    def work(self) -> None:
        print("Working...")
    # mypy error: Robot does not satisfy Worker (missing eat, sleep)
    # Only fix: add stub methods that raise NotImplementedError — ISP violation
```

```python
# ✅ Good: Segregated Protocols — each client depends only on what it uses
from typing import Protocol

class Workable(Protocol):
    def work(self) -> None: ...

class Feedable(Protocol):
    def eat(self) -> None: ...

class Restable(Protocol):
    def sleep(self) -> None: ...

class HumanWorker:
    def work(self) -> None: print("Working")
    def eat(self) -> None:  print("Eating")
    def sleep(self) -> None: print("Sleeping")

class Robot:
    def work(self) -> None: print("Working")    # satisfies Workable only

def assign_task(worker: Workable) -> None:
    worker.work()     # works for HumanWorker and Robot — no fat interface

assign_task(HumanWorker())   # ✅
assign_task(Robot())         # ✅ Robot satisfies Workable
```

```python
# ISP at module level — Python's import system enforces ISP naturally
# ❌ Bad: one fat utils module forces consumers to take everything
# utils/__init__.py imports PdfGenerator (heavy: reportlab, 10MB)
# A Lambda that only needs JSON must package PdfGenerator too
from utils import json_formatter   # forces reportlab into the Lambda package

# ✅ Good: narrow modules, consumers take only what they need
from json_utils import json_formatter   # 2KB — just what's needed
from pdf_utils import pdf_generator     # imported only by the report service
```

```python
# Real-world ISP: Repository split by consumer needs
from typing import Protocol

class OrderReader(Protocol):          # use case: GetOrder only needs reads
    def find(self, order_id: str) -> "Order | None": ...

class OrderWriter(Protocol):          # use case: PlaceOrder only needs writes
    def save(self, order: "Order") -> None: ...

class OrderRepository(Protocol):      # admin use case: needs both
    def find(self, order_id: str) -> "Order | None": ...
    def save(self, order: "Order") -> None: ...
    def list_all(self) -> list["Order"]: ...

class GetOrder:
    def __init__(self, repo: OrderReader) -> None:  # depends only on what it uses
        self._repo = repo

class PlaceOrder:
    def __init__(self, repo: OrderWriter) -> None:  # depends only on what it uses
        self._repo = repo
```

## Quick Reference
- ISP: depend only on the methods you call
- Python: define narrow `Protocol` types — one per consumer role
- Fat interfaces create false coupling; changes anywhere affect everywhere
- Module-level ISP: large imports force heavyweight dependencies into unrelated consumers
