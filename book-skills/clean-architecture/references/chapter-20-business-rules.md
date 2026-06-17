# Chapter 20: Business Rules

## Summary
Martin identifies two types of business rules. **Critical Business Rules** exist independent of any software — encoded in **Entities** (pure domain objects). **Application Business Rules** are the specific orchestration of entities for one system's scenario — encoded in **Use Cases**. Entities are the most stable, innermost ring. Use Cases know entities and Protocols; nothing else.

## Key Principles
- **Entity = Critical Business Rules + Critical Business Data**: Pure Python. Zero imports from infrastructure.
- **Use Case = Application-specific orchestration**: Describes exactly what THIS system does for a specific actor in a specific scenario.
- **Entities outlast use cases**: If the application is replaced (new UI, new use cases), the entities survive unchanged.

## Python Example

```python
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Protocol

# ======== ENTITY: Critical Business Rules ========
@dataclass
class Loan:
    """
    A Loan exists as a business concept independent of software.
    The accrual rule (interest = principal × daily_rate × days) would exist
    on paper even without this system. That is what makes it a Critical Business Rule.
    """
    principal: float
    annual_rate: float
    disbursement_date: datetime

    def accrued_interest(self, as_of: datetime) -> float:
        """Critical rule — belongs in the entity, not in any use case."""
        days = (as_of - self.disbursement_date).days
        return self.principal * (self.annual_rate / 365) * days

    def is_overdue(self, as_of: datetime, due_date: datetime) -> bool:
        return as_of > due_date and self.principal > 0

# Loan: zero imports from Flask, SQLAlchemy, boto3, or any framework.
# Pure financial logic — testable in isolation.
loan = Loan(principal=10_000, annual_rate=0.12,
            disbursement_date=datetime(2025, 1, 1))
assert round(loan.accrued_interest(datetime(2025, 4, 1)), 2) == 295.89  # 90 days
assert loan.is_overdue(datetime(2025, 6, 1), due_date=datetime(2025, 3, 31))


# ======== USE CASE: Application Business Rules ========
# Protocols defined HERE so use case owns its own dependencies
class LoanRepository(Protocol):
    def find(self, loan_id: str) -> Loan | None: ...
    def save(self, loan: Loan) -> None: ...

class LedgerService(Protocol):
    def record_payment(self, loan_id: str, interest: float, principal: float) -> None: ...

@dataclass
class ApplyLoanPaymentRequest:
    loan_id: str
    payment_amount: float
    payment_date: datetime

@dataclass
class ApplyLoanPaymentResponse:
    success: bool
    remaining_principal: float
    interest_paid: float
    error: str | None = None

class ApplyLoanPayment:
    """
    Application rule: what THIS system does when a payment arrives.
    A batch reconciliation system would orchestrate the Loan entity differently.
    This use case is specific to this application — the entity is not.
    """
    def __init__(self, repo: LoanRepository, ledger: LedgerService) -> None:
        self._repo = repo
        self._ledger = ledger

    def execute(self, req: ApplyLoanPaymentRequest) -> ApplyLoanPaymentResponse:
        loan = self._repo.find(req.loan_id)
        if loan is None:
            return ApplyLoanPaymentResponse(
                success=False, remaining_principal=0, interest_paid=0,
                error=f"Loan {req.loan_id} not found",
            )
        interest_due = loan.accrued_interest(req.payment_date)
        interest_paid = min(req.payment_amount, interest_due)
        principal_paid = req.payment_amount - interest_paid
        new_principal = loan.principal - principal_paid
        self._repo.save(Loan(new_principal, loan.annual_rate, loan.disbursement_date))
        self._ledger.record_payment(req.loan_id, interest_paid, principal_paid)
        return ApplyLoanPaymentResponse(
            success=True,
            remaining_principal=new_principal,
            interest_paid=interest_paid,
        )


# ======== Test: no Flask, no DB ========
class InMemoryLoanRepository:
    def __init__(self) -> None: self._store: dict[str, Loan] = {}
    def find(self, loan_id: str) -> Loan | None: return self._store.get(loan_id)
    def save(self, loan: Loan) -> None: self._store["l1"] = loan

class CapturingLedger:
    def __init__(self) -> None: self.entries: list[tuple] = []
    def record_payment(self, loan_id: str, interest: float, principal: float) -> None:
        self.entries.append((loan_id, interest, principal))

def test_payment_applies_to_interest_first() -> None:
    repo = InMemoryLoanRepository()
    disbursement = datetime(2025, 1, 1)
    repo.save(Loan(10_000, 0.12, disbursement))
    repo._store["l1"] = repo._store.pop(list(repo._store)[0])
    repo._store["l1"] = Loan(10_000, 0.12, disbursement)

    ledger = CapturingLedger()
    use_case = ApplyLoanPayment(repo, ledger)
    resp = use_case.execute(ApplyLoanPaymentRequest(
        loan_id="l1",
        payment_amount=500.0,
        payment_date=datetime(2025, 4, 1),   # 90 days → ~295.89 interest
    ))
    assert resp.success
    assert resp.interest_paid > 0
    assert resp.remaining_principal < 10_000
```

## Quick Reference
- Entity = Critical Business Rule + data that would exist on paper without software
- Use Case = orchestration of entities for THIS system's specific scenario
- Entities are the most stable, innermost ring — they outlast applications
- Use cases know entities + Protocols only; never import Flask, SQLAlchemy, boto3
