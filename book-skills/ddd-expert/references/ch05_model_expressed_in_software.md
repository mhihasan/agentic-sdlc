# Ch. 5 — A Model Expressed in Software

## Chapter Thesis

Domain concepts are expressed through three kinds of model elements: ENTITIES
(things defined by identity), VALUE OBJECTS (things defined by attributes), and
DOMAIN SERVICES (operations that belong to neither). Getting this classification
right is the structural foundation of every other DDD pattern.

---

## ENTITY

### Evans' Definition

> "When an object is distinguished by its identity, rather than its attributes, make
> this primary to its definition in the model. Keep the class definition simple and
> focused on life cycle continuity and identity. Define a means of distinguishing
> each object regardless of its form or history. Be alert to requirements that call
> for matching objects by attributes. Define an operation that is guaranteed to
> produce a unique result for each object, possibly by attaching a symbol that is
> guaranteed unique. This means of identification may come from the outside, or it
> may be an arbitrary identifier created by and for the system, but it must
> correspond to the identity distinctions in the model. The model must define what
> it means to be the same thing."

### Why This Pattern Exists

Two bank transactions for the same amount on the same account on the same day are
still distinct transactions. Without explicit identity, there is no way to tell them
apart — leading to the data corruption Evans describes. Identity is a modelling
decision, not a database artefact.

Evans' identity test: "An ENTITY is anything that has continuity through a life
cycle and distinctions independent of attributes that are important to the
application's user."

### Python Implementation

```python
from dataclasses import dataclass, field
from uuid import UUID, uuid4


@dataclass
class Order:
    """ENTITY — identity drives equality, not attributes. (Evans, Ch. 5)"""
    id: UUID = field(default_factory=uuid4)
    customer_id: UUID = None
    status: str = "pending"

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Order):
            return NotImplemented
        return self.id == other.id  # identity-based — never compare attributes

    def __hash__(self) -> int:
        return hash(self.id)

    def confirm(self) -> None:
        """Domain behaviour belongs on the ENTITY. (Evans, Ch. 5)"""
        if self.status != "pending":
            raise ValueError(f"Cannot confirm an order in status '{self.status}'")
        self.status = "confirmed"
```

### Evans Warns

- Attribute comparison for ENTITY equality is the source of the data corruption
  bugs Evans describes. Two orders with identical attributes are still different
  orders.
- "Identity is a subtle and meaningful attribute of ENTITIES, which can't be turned
  over to the automatic features of the language." Python's default `==` compares
  object identity (memory address) — override `__eq__` explicitly.
- Giving every object a UUID does not make everything an ENTITY. Evans: "This
  identity mechanism means very little in other application domains." Whether
  something needs identity is a domain decision.

---

## VALUE OBJECT

### Evans' Definition

> "When you care only about the attributes and logic of an element of the model,
> classify it as a VALUE OBJECT. Make it express the meaning of the attributes it
> conveys and give it related functionality. Treat the VALUE OBJECT as immutable.
> Make all operations Side-Effect-Free Functions that return a Value Object. Don't
> give a VALUE OBJECT any identity and avoid the design complexities necessary to
> maintain ENTITIES."

### Why This Pattern Exists

Tracking identity for objects that have no meaningful identity adds complexity with
no benefit. Evans: "some frameworks assign a unique ID to every object. The system
has to cope with all that tracking, and many possible performance optimizations are
ruled out." VALUE OBJECTs can be freely shared, copied, and discarded without any
tracking overhead.

### Python Implementation

Use `frozen=True` dataclass — immutability is enforced at runtime:

```python
from dataclasses import dataclass
from typing import Self


@dataclass(frozen=True)
class Money:
    """VALUE OBJECT — immutable, equality by attributes. (Evans, Ch. 5)"""
    amount: int    # store in smallest unit (cents) to avoid float arithmetic
    currency: str

    def __post_init__(self) -> None:
        if self.amount < 0:
            raise ValueError("Money amount cannot be negative")
        if not self.currency:
            raise ValueError("Currency code required")

    def add(self, other: Self) -> Self:
        """Side-effect-free — returns a new instance. (Evans, Ch. 5)"""
        if self.currency != other.currency:
            raise ValueError(f"Cannot add {self.currency} and {other.currency}")
        return Money(self.amount + other.amount, self.currency)
```

Use `NamedTuple` for structurally simple VALUE OBJECTs with no behaviour:

```python
from typing import NamedTuple

class Address(NamedTuple):
    street: str
    city: str
    postal_code: str
    country: str
```

### Evans Warns

- A mutable VALUE OBJECT is an oxymoron. `frozen=True` is not optional. Without it,
  two parts of the code can hold a reference to the same `Money` instance, one
  mutates it, and the other sees the change unexpectedly — the aliasing bug Evans
  describes.

```python
# The aliasing bug Evans describes — what happens with a mutable VALUE OBJECT
@dataclass   # frozen=True missing — this is wrong
class Money:
    amount: int
    currency: str

price = Money(1000, "GBP")
cart_total = price          # same instance, not a copy

# Elsewhere in code, a discount is applied by mutation — WRONG
cart_total.amount -= 100    # mutates the shared instance

print(price.amount)         # 900 — price was corrupted silently!
# This is exactly the aliasing bug Evans describes in Ch. 5.


# RIGHT — frozen=True makes sharing safe
@dataclass(frozen=True)
class Money:
    amount: int
    currency: str

    def subtract(self, discount: int) -> "Money":
        return Money(self.amount - discount, self.currency)  # new instance

price = Money(1000, "GBP")
discounted = price.subtract(100)   # price is unchanged
print(price.amount)        # 1000 — safe
print(discounted.amount)   # 900
```

- Operations on VALUE OBJECTs must return new instances, never mutate. Evans:
  "If two Value Objects have the same attributes, they can be used interchangeably"
  — this shareability only holds because they are immutable.
- Do not give a VALUE OBJECT a database primary key unless the domain genuinely
  tracks that identity. Adding an `id` column for ORM convenience turns a VALUE
  OBJECT into an accidental ENTITY.

---

## DOMAIN SERVICE

### Evans' Definition

> "When a significant process or transformation in the domain is not a natural
> responsibility of an ENTITY or VALUE OBJECT, add an operation to the model as a
> standalone interface declared as a SERVICE. Define a service contract, a set of
> assertions about interactions with the SERVICE. State these assertions in the
> UBIQUITOUS LANGUAGE of a specific BOUNDED CONTEXT. Give the SERVICE a name, which
> also becomes part of the UBIQUITOUS LANGUAGE."

### Evans' Three Criteria — All Three Must Hold

1. The operation relates to a domain concept that is not a natural part of any single
   ENTITY or VALUE OBJECT.
2. The interface is defined in terms of other elements of the domain model.
3. The operation is stateless.

### Python Implementation

```python
# domain/services.py
from uuid import UUID
from domain.model import Account, Money
from domain.repositories import AccountRepository


class FundsTransferService:
    """
    DOMAIN SERVICE — operation spans two AGGREGATE roots. (Evans, Ch. 5)
    Stateless. Not on Account because it intrinsically involves two accounts.
    """

    def __init__(self, account_repo: AccountRepository) -> None:
        self._accounts = account_repo

    def transfer(
        self, source_id: UUID, destination_id: UUID, amount: Money
    ) -> None:
        source = self._accounts.get(source_id)
        destination = self._accounts.get(destination_id)
        if source is None or destination is None:
            raise ValueError("Account not found")
        source.debit(amount)        # domain behaviour on ENTITY
        destination.credit(amount)  # domain behaviour on ENTITY
        self._accounts.save(source)
        self._accounts.save(destination)
```

### Evans Warns

- Do not reach for a DOMAIN SERVICE by default. Evans: "The more common mistake is
  to give up too easily on fitting the behavior into an appropriate object, which
  leads to the gradual loss of behavior from the domain layer." An ENTITY should hold
  its own behaviour wherever that behaviour is naturally part of that object.
- Name DOMAIN SERVICEs using verb phrases from the Ubiquitous Language:
  `FundsTransferService` — not `AccountManager`, `TransactionProcessor`.
- DOMAIN SERVICEs are stateless — they must not accumulate state between calls.
  State lives on AGGREGATEs.

---

## MODULE

### Evans' Definition

> "Choose MODULES that tell the story of the system and contain a cohesive set of
> concepts. Give the MODULES names that become part of the UBIQUITOUS LANGUAGE.
> MODULES are part of the model and their names should reflect insight into the
> domain."

### Python Mapping

Evans' MODULES map to Python packages. Package names are domain language, not
technical groupings.

```
# Wrong — grouped by technical role (tells you nothing about the domain)
src/
├── models/
├── services/
└── repositories/

# Right — grouped by domain concept (Evans, Ch. 5)
src/
├── ordering/       # "Ordering" is a concept in the domain
│   ├── __init__.py
│   ├── model.py
│   ├── services.py
│   └── repositories.py
└── inventory/      # "Inventory" is a concept in the domain
    ├── __init__.py
    ├── model.py
    └── repositories.py
```

The `__init__.py` exposes the MODULE's public interface — only what the domain
says external code should be able to see:

```python
# ordering/__init__.py — public interface of the Ordering MODULE (Evans, Ch. 5)
# Evans: "The name of the MODULE conveys its meaning."
# Only expose what other modules are allowed to reference.

from ordering.model import Order, OrderLine
from ordering.services import PricingService
from ordering.repositories import OrderRepository

__all__ = ["Order", "OrderLine", "PricingService", "OrderRepository"]
# OrderFactory is an internal detail — not exported
```

Cross-module imports should go through the public interface, not internal files.
Evans warns about coupling that makes MODULES hard to understand independently:

```python
# Wrong — importing internals of another MODULE (Evans, Ch. 5)
from inventory.model import StockLevel   # OK — model is public
from inventory._internal_tracker import WarehouseGrid  # WRONG — internal detail

# Right — depend only on the MODULE's published interface
from inventory import StockLevel  # uses inventory/__init__.py
```

### Evans Warns

High cohesion and low coupling apply to domain concepts, not just technical
components. "The MODULES and the smaller elements should reflect domain concepts."
A module named `utils` or `common` is a domain modelling failure — it means the
developer could not find a domain concept to group these things under.
