# Chapter 22: The Clean Architecture

## Summary
Martin synthesises Hexagonal Architecture, Onion Architecture, and DCI into a unified model: four concentric rings. The **Dependency Rule** is absolute: source code dependencies must point only inward. Inner rings know nothing about outer rings. Data crossing boundaries must be translated into simple structures (dataclasses, plain dicts) — never framework objects or ORM entities.

## The Four Rings

| Ring | Contents | Rule |
|---|---|---|
| **Entities** (innermost) | Critical Business Rules, domain objects | No external dependencies |
| **Use Cases** | Application Business Rules, orchestration | Knows Entities + boundary Protocols |
| **Interface Adapters** | Controllers, Presenters, Gateways | Translates between Use Cases and frameworks |
| **Frameworks & Drivers** (outermost) | FastAPI, SQLAlchemy, boto3 | Implementation details, volatile |

## Python Example — Full Four-Ring Stack

```python
# ---- RING 1: Entity (innermost) — pure Python, zero imports ----
from dataclasses import dataclass, replace

@dataclass(frozen=True)
class Invoice:
    invoice_id: str
    customer_id: str
    amount: float
    is_paid: bool = False

    def mark_paid(self) -> "Invoice":
        return replace(self, is_paid=True)    # immutable — returns new object


# ---- RING 2: Use Case — depends on Entities + Protocols ----
from typing import Protocol

# Protocols defined HERE in the use case layer — outer ring implements them
# without importing from this module (duck typing satisfies Protocol)
class InvoiceRepository(Protocol):
    def find(self, invoice_id: str) -> Invoice | None: ...
    def save(self, invoice: Invoice) -> None: ...

class NotificationService(Protocol):
    def notify_paid(self, customer_id: str, invoice_id: str) -> None: ...

@dataclass
class MarkInvoicePaidRequest:
    invoice_id: str

@dataclass
class MarkInvoicePaidResponse:
    success: bool
    error: str | None = None

class MarkInvoicePaid:
    def __init__(self, repo: InvoiceRepository, notifier: NotificationService) -> None:
        self._repo = repo
        self._notifier = notifier

    def execute(self, req: MarkInvoicePaidRequest) -> MarkInvoicePaidResponse:
        invoice = self._repo.find(req.invoice_id)
        if invoice is None:
            return MarkInvoicePaidResponse(success=False, error="Invoice not found")
        self._repo.save(invoice.mark_paid())
        self._notifier.notify_paid(invoice.customer_id, invoice.invoice_id)
        return MarkInvoicePaidResponse(success=True)


# ---- RING 3: Interface Adapter (Controller) ----
class MarkInvoicePaidController:
    def __init__(self, use_case: MarkInvoicePaid) -> None:
        self._use_case = use_case

    def handle(self, raw_input: dict) -> dict:
        req = MarkInvoicePaidRequest(invoice_id=raw_input["invoice_id"])
        resp = self._use_case.execute(req)
        # Translate to plain dict — no ORM objects or Request objects cross this boundary
        return {"success": resp.success, "error": resp.error}


# ---- RING 4: Frameworks & Drivers — FastAPI ----
from fastapi import FastAPI
app = FastAPI()
controller: MarkInvoicePaidController  # wired in Main (Chapter 26)

@app.post("/invoices/{invoice_id}/pay")
def pay_invoice(invoice_id: str) -> dict:
    return controller.handle({"invoice_id": invoice_id})


# ---- RING 4: Frameworks & Drivers — PostgreSQL implementation ----
# Does NOT import InvoiceRepository — satisfies Protocol via duck typing
class PostgresInvoiceRepository:
    def find(self, invoice_id: str) -> Invoice | None:
        # psycopg2 query → translate result to Invoice dataclass
        ...
    def save(self, invoice: Invoice) -> None:
        # psycopg2 upsert from Invoice dataclass fields
        ...


# ---- Test: no HTTP, no DB, runs in microseconds ----
class InMemoryInvoiceRepository:
    def __init__(self) -> None:
        self._store: dict[str, Invoice] = {}
    def find(self, invoice_id: str) -> Invoice | None:
        return self._store.get(invoice_id)
    def save(self, invoice: Invoice) -> None:
        self._store[invoice.invoice_id] = invoice

class CapturingNotificationService:
    def __init__(self) -> None:
        self.notifications: list[tuple[str, str]] = []
    def notify_paid(self, customer_id: str, invoice_id: str) -> None:
        self.notifications.append((customer_id, invoice_id))

def test_mark_invoice_paid() -> None:
    repo = InMemoryInvoiceRepository()
    repo.save(Invoice("inv-1", "cust-1", 500.0))
    notifier = CapturingNotificationService()
    use_case = MarkInvoicePaid(repo, notifier)

    resp = use_case.execute(MarkInvoicePaidRequest("inv-1"))

    assert resp.success
    assert repo.find("inv-1").is_paid
    assert notifier.notifications == [("cust-1", "inv-1")]
```

## Quick Reference
- Four rings: Entities → Use Cases → Interface Adapters → Frameworks & Drivers
- Dependency Rule: imports only point inward, never outward
- Data at boundaries: `@dataclass` DTOs or plain dicts — never ORM objects
- Ring 4 satisfies Ring 2 Protocols via duck typing — no imports needed
- The Dependency Rule means Ring 4 can be swapped without touching Rings 1–2
