# Ch. 4 — Isolating the Domain

## Chapter Thesis

Domain logic can only be modelled clearly once it is isolated from the technical
concerns that surround it. Without explicit layering, business rules bleed into UI,
persistence, and orchestration code — making them impossible to reason about, test,
or evolve independently.

---

## LAYERED ARCHITECTURE

### Evans' Definition

> "Partition a complex program into layers. Develop a design within each layer that
> is cohesive and that depends only on the layers below. Follow standard architectural
> patterns to provide loose coupling to the layers above. Concentrate all the code
> related to the domain model in one layer and isolate it from the user interface,
> application, and infrastructure code. The domain objects, freed from the
> responsibility of displaying themselves, storing themselves, managing application
> tasks, and so forth, can be focused on expressing the domain model."

### Evans' Four Layers

```
┌──────────────────────────────────────┐
│           User Interface             │
│   Displays information, interprets   │
│   user commands. No business logic.  │
├──────────────────────────────────────┤
│         Application Layer            │
│   Thin. Orchestrates use cases.      │
│   Loads aggregates from repos,       │
│   calls domain services or entity    │
│   methods, saves results.            │
│   Contains NO business rules.        │
├──────────────────────────────────────┤
│           Domain Layer               │
│   Business rules live here.          │
│   ENTITIES, VALUE OBJECTS,           │
│   AGGREGATES, DOMAIN SERVICES.       │
│   Abstract REPOSITORY interfaces     │
│   are defined here.                  │
├──────────────────────────────────────┤
│        Infrastructure Layer          │
│   REPOSITORY implementations,        │
│   ORM configuration, messaging,      │
│   external API clients.              │
│   Depends on domain interfaces,      │
│   not the other way around.          │
└──────────────────────────────────────┘
```

### Python: Layer Violation — What Goes Wrong

The most common violation is domain logic seeping into the Application Layer or
infrastructure imports appearing in domain objects:

```python
# WRONG — Application Layer doing domain reasoning (Evans, Ch. 4)
# "The domain objects become mere data containers"
class TransferApplicationService:
    def transfer_funds(self, from_id: UUID, to_id: UUID, amount_cents: int) -> None:
        source = self._accounts.get(from_id)
        destination = self._accounts.get(to_id)

        # Domain rule in the Application Layer — VIOLATION
        if source.balance_cents < amount_cents:
            raise ValueError("Insufficient funds")
        if amount_cents > 10_000_00:  # daily limit — another domain rule, VIOLATION
            raise ValueError("Exceeds daily transfer limit")

        source.balance_cents -= amount_cents      # mutating state directly — VIOLATION
        destination.balance_cents += amount_cents
        self._accounts.save(source)
        self._accounts.save(destination)


# WRONG — domain object importing infrastructure (Evans, Ch. 4)
from sqlalchemy.orm import Session  # infrastructure import in domain — VIOLATION

@dataclass
class Account:
    id: UUID
    balance_cents: int
    _db_session: Session = None  # domain object knows about database — VIOLATION

    def debit(self, amount: int) -> None:
        self.balance_cents -= amount
        self._db_session.commit()  # infrastructure in domain — VIOLATION
```

### Python: Correct Layering

```python
# RIGHT — each layer does exactly its job (Evans, Ch. 4)

# domain/model.py — pure Python, zero infrastructure imports
from dataclasses import dataclass, field
from uuid import UUID, uuid4
from domain.exceptions import InsufficientFundsError, DailyLimitExceededError


@dataclass
class Account:
    """Domain object — knows nothing about databases, HTTP, or frameworks."""
    id: UUID = field(default_factory=uuid4)
    balance_cents: int = 0
    daily_transferred_cents: int = 0
    DAILY_LIMIT_CENTS: int = field(default=10_000_00, repr=False)

    def debit(self, amount_cents: int) -> None:
        """Business rule lives on the ENTITY — Evans Ch. 4."""
        if amount_cents > self.balance_cents:
            raise InsufficientFundsError(amount_cents, self.balance_cents)
        self.balance_cents -= amount_cents

    def credit(self, amount_cents: int) -> None:
        self.balance_cents += amount_cents

    def record_outgoing_transfer(self, amount_cents: int) -> None:
        if self.daily_transferred_cents + amount_cents > self.DAILY_LIMIT_CENTS:
            raise DailyLimitExceededError(amount_cents, self.DAILY_LIMIT_CENTS)
        self.daily_transferred_cents += amount_cents


# domain/services.py — DOMAIN SERVICE: spans two AGGREGATEs
from domain.model import Account
from domain.repositories import AccountRepository


class FundsTransferService:
    """Business logic that naturally spans two accounts — domain layer. Ch. 4."""

    def __init__(self, account_repo: AccountRepository) -> None:
        self._accounts = account_repo

    def transfer(self, from_id: UUID, to_id: UUID, amount_cents: int) -> None:
        source = self._accounts.get(from_id)
        destination = self._accounts.get(to_id)
        if source is None or destination is None:
            raise ValueError("Account not found")
        source.record_outgoing_transfer(amount_cents)  # enforce daily limit
        source.debit(amount_cents)                     # enforce balance rule
        destination.credit(amount_cents)
        self._accounts.save(source)
        self._accounts.save(destination)


# application/services.py — APPLICATION SERVICE: orchestrates the use case
from uuid import UUID
from domain.services import FundsTransferService


class BankingApplicationService:
    """
    Thin orchestrator — no business rules here. (Evans, Ch. 4)
    Loads objects, delegates to domain, saves results.
    """

    def __init__(self, transfer_service: FundsTransferService) -> None:
        self._transfer = transfer_service

    def execute_transfer(
        self, from_id: UUID, to_id: UUID, amount_cents: int
    ) -> None:
        self._transfer.transfer(from_id, to_id, amount_cents)
        # Transaction management, audit logging, notification — all here, not in domain
```

### APPLICATION SERVICE vs DOMAIN SERVICE

```python
# DOMAIN SERVICE — holds domain logic that spans multiple objects (Ch. 5)
# Lives in domain/, defined in terms of domain model elements, stateless
class FundsTransferService:
    def transfer(self, source: Account, destination: Account, amount: Money) -> None:
        source.debit(amount)       # delegates actual rule enforcement to ENTITY
        destination.credit(amount)


# APPLICATION SERVICE — orchestrates a use case, no business rules (Ch. 4)
# Lives in application/, thin, coordinates domain objects and infrastructure
class TransferApplicationService:
    def execute_transfer(self, from_id: UUID, to_id: UUID, amount_cents: int) -> None:
        source = self._accounts.get(from_id)        # load
        destination = self._accounts.get(to_id)     # load
        money = Money(amount_cents, "GBP")
        self._transfer_service.transfer(source, destination, money)  # delegate
        self._accounts.save(source)                 # save
        self._accounts.save(destination)            # save
        self._notifications.send_transfer_confirmation(from_id, amount_cents)  # side effect
```

### Python Directory Structure

```
src/
├── domain/                  # Pure Python — zero infrastructure imports
│   ├── __init__.py
│   ├── model.py             # ENTITIES, VALUE OBJECTS, AGGREGATES
│   ├── services.py          # DOMAIN SERVICES
│   ├── repositories.py      # Abstract interfaces (abc.ABC)
│   └── exceptions.py        # Domain-named exceptions
├── application/
│   ├── __init__.py
│   └── services.py          # APPLICATION SERVICES — thin orchestration
└── infrastructure/
    ├── __init__.py
    ├── repositories.py      # Concrete REPOSITORY implementations (SQLAlchemy, etc.)
    └── notifications.py     # Email, SMS — technical services
```

### Python: The SMART UI Anti-Pattern

Evans describes SMART UI as the alternative to LAYERED ARCHITECTURE — not a
transitional step. If you are already in SMART UI, the patterns in the rest of the
book do not apply until you escape it:

```python
# SMART UI — all logic in the handler/view, no domain layer (Evans, Ch. 4)
# "An alternate, mutually exclusive fork in the road"
# Works for simple CRUD apps; does not scale to complex domains

def handle_transfer_request(request):  # Flask/FastAPI handler
    from_id = request.json["from_account"]
    to_id = request.json["to_account"]
    amount = request.json["amount"]

    # Business rule directly in HTTP handler
    source_balance = db.execute(
        "SELECT balance FROM accounts WHERE id = ?", from_id
    ).fetchone()[0]
    if source_balance < amount:
        return {"error": "insufficient funds"}, 400
    if amount > 1_000_000:
        return {"error": "exceeds limit"}, 400

    db.execute("UPDATE accounts SET balance = balance - ? WHERE id = ?", amount, from_id)
    db.execute("UPDATE accounts SET balance = balance + ? WHERE id = ?", amount, to_id)
    db.commit()
    return {"status": "ok"}, 200
```

Evans: "SMART UI is not evil. For simple applications, it works fine. But it is
incompatible with the approach of domain-driven design."

### Evans Warns

"The domain layer is where the model lives." Any import of SQLAlchemy, Django ORM,
an HTTP client, or any other infrastructure concern inside `domain/` is an
architectural violation. The domain layer must be independently testable — no
database, no framework, no network required.

When domain logic spreads into application services and infrastructure, "the domain
objects become mere data containers." The model loses its expressive power.

### What This Guidance Does Not Cover

Evans does not address hexagonal architecture, ports and adapters, or Clean
Architecture by name. These follow compatible principles. Evans does not cover
dependency injection frameworks — constructor injection of REPOSITORY abstractions
into DOMAIN SERVICES is sufficient for testability.
