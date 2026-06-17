# Chapter 23: Presenters and Humble Objects

## Summary
The Humble Object pattern splits a component into two parts at every architectural boundary: a **testable** piece (all the logic) and a **humble** piece (so simple it needs no tests — it just shuffles pre-formatted data into a slot). Applied to the View/Presenter boundary: the Presenter contains *all* formatting logic and is fully unit-testable; the View is a dumb template that fills slots with pre-formed strings. This pattern appears at every architectural boundary — not just the UI.

## Key Principles
- **Humble Object = dumb I/O, zero decisions**: The View just passes pre-formatted values to a template.
- **Presenter = all formatting logic**: Date formats, currency, conditional visibility — fully unit-testable.
- **The split appears at every boundary**: DB gateway (translate ORM → domain), service adapter (translate wire format → domain), test boundary (test doubles).

## Python Example

```python
from dataclasses import dataclass
from datetime import datetime

# ======== Domain object (ring 1) ========
@dataclass(frozen=True)
class Invoice:
    invoice_id: str
    customer_id: str
    amount: float
    date: datetime
    due_date: datetime
    is_paid: bool = False


# ======== View Model (pre-formatted data — no logic required to render) ========
@dataclass(frozen=True)
class InvoiceViewModel:
    amount_display: str        # "$1,234.56"
    date_display: str          # "January 15, 2025"
    due_date_display: str      # "February 15, 2025"
    status_label: str          # "OVERDUE" | "PAID" | "DUE"
    status_css_class: str      # "text-red-500" | "text-green-500" | "text-yellow-500"
    is_overdue: bool


# ======== Presenter (all logic — fully unit-testable, no HTTP/template engine) ========
class InvoicePresenter:
    def present(self, invoice: Invoice, now: datetime) -> InvoiceViewModel:
        overdue = not invoice.is_paid and invoice.due_date < now
        if invoice.is_paid:
            label, css = "PAID", "text-green-500"
        elif overdue:
            label, css = "OVERDUE", "text-red-500"
        else:
            label, css = "DUE", "text-yellow-500"
        return InvoiceViewModel(
            amount_display=f"${invoice.amount:,.2f}",
            date_display=invoice.date.strftime("%B %d, %Y"),
            due_date_display=invoice.due_date.strftime("%B %d, %Y"),
            status_label=label,
            status_css_class=css,
            is_overdue=overdue,
        )


# ======== Tests — no Flask, no template engine, no DB ========
PAST   = datetime(2020, 1, 1)
FUTURE = datetime(2099, 1, 1)
NOW    = datetime(2025, 6, 1)

def make_invoice(**kwargs) -> Invoice:
    defaults = dict(invoice_id="i1", customer_id="c1", amount=500.0,
                    date=PAST, due_date=PAST, is_paid=False)
    return Invoice(**{**defaults, **kwargs})

def test_overdue_unpaid_invoice() -> None:
    vm = InvoicePresenter().present(make_invoice(due_date=PAST), now=NOW)
    assert vm.status_label == "OVERDUE"
    assert vm.status_css_class == "text-red-500"
    assert vm.is_overdue is True

def test_paid_invoice_never_overdue() -> None:
    vm = InvoicePresenter().present(make_invoice(due_date=PAST, is_paid=True), now=NOW)
    assert vm.status_label == "PAID"
    assert vm.is_overdue is False

def test_future_due_date_shows_due() -> None:
    vm = InvoicePresenter().present(make_invoice(due_date=FUTURE), now=NOW)
    assert vm.status_label == "DUE"
    assert vm.status_css_class == "text-yellow-500"

def test_amount_formatting() -> None:
    vm = InvoicePresenter().present(make_invoice(amount=1234.56), now=NOW)
    assert vm.amount_display == "$1,234.56"

# Run them (no test runner needed):
test_overdue_unpaid_invoice()
test_paid_invoice_never_overdue()
test_future_due_date_shows_due()
test_amount_formatting()
print("All presenter tests pass ✅")


# ======== Humble View (Flask) — zero logic, just fills slots ========
# from flask import render_template
# @app.get("/invoice/<id>")
# def show_invoice(invoice_id: str):
#     invoice = repo.find(invoice_id)
#     vm = InvoicePresenter().present(invoice, now=datetime.now())
#     return render_template("invoice.html", vm=vm)
#     # invoice.html just uses {{ vm.amount_display }}, {{ vm.status_label }}, etc.
#     # The template contains no if/else, no formatting logic.
```

```python
# ---- Humble Object at the DB boundary ----
# The repository is the "humble" piece: translate ORM rows → domain objects.
# The domain object carries no ORM knowledge — it's the testable piece.

class SqlAlchemyInvoiceRepository:
    def find(self, invoice_id: str) -> Invoice | None:
        row = self._session.get(InvoiceOrmModel, invoice_id)   # humble I/O
        if row is None:
            return None
        # Translation: ORM row → pure domain object (the clean data)
        return Invoice(
            invoice_id=str(row.id),
            customer_id=row.customer_id,
            amount=float(row.amount),
            date=row.created_at,
            due_date=row.due_date,
            is_paid=row.status == "paid",
        )
    # The ORM model never escapes this method — only Invoice crosses the boundary.
```

## Quick Reference
- Humble Object = dumb I/O shell — fills slots, makes no decisions
- Presenter = all formatting decisions = fully unit-testable without a browser
- Apply at every boundary: View/Presenter, ORM/Repository, service adapter
- ViewModel: pre-formatted strings ready to display — no conditional logic in templates
