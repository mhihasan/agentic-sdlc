# Ch. 6 — The Life Cycle of a Domain Object

## Chapter Thesis

Domain objects have life cycles: created, mutated through valid state transitions,
and eventually archived or deleted. Two challenges arise: maintaining invariant
integrity throughout, and preventing the life cycle mechanics from overwhelming the
domain model itself. AGGREGATE, FACTORY, and REPOSITORY each address a distinct
phase of that life cycle.

---

## AGGREGATE

### Evans' Definition

> "Cluster the ENTITIES and VALUE OBJECTS into AGGREGATES and define boundaries
> around each. Choose one ENTITY to be the root of each AGGREGATE, and allow
> external objects to hold references to the root only (not to internal objects of
> the AGGREGATE). Define properties and invariants for the AGGREGATE as a whole
> and give enforcement responsibility to the root or to some designated framework
> mechanism."

### Why This Pattern Exists

In a web of related objects, every change can potentially affect every other object.
Without defined ownership boundaries, it is impossible to maintain invariants or
reason about what a transaction must include. Evans: "It is difficult to guarantee
the consistency of changes to objects in a model with complex associations."

### Evans' Mandatory Rules

1. The root ENTITY has global identity. Internal ENTITIES have local identity only —
   meaningless outside the AGGREGATE boundary.
2. **External objects may only hold references to the root — never to internal objects.**
3. Internal objects may hold references to other AGGREGATE roots.
4. Only the root can be obtained directly from a REPOSITORY.
5. All mutation of objects within the AGGREGATE must go through the root.
6. Deleting the root deletes everything inside the boundary.

### Python Implementation

```python
from dataclasses import dataclass, field
from uuid import UUID, uuid4
from typing import Sequence


@dataclass(frozen=True)
class OrderLine:
    """
    Internal ENTITY — local identity, never exposed outside the AGGREGATE.
    External code must never hold a direct reference to this. (Evans, Ch. 6)
    """
    line_id: UUID = field(default_factory=uuid4)
    product_id: UUID = None
    quantity: int = 0
    unit_price_cents: int = 0

    def __post_init__(self) -> None:
        if self.quantity <= 0:
            raise ValueError("Quantity must be positive")


@dataclass
class Order:
    """AGGREGATE ROOT — sole public interface into this cluster. (Evans, Ch. 6)"""
    id: UUID = field(default_factory=uuid4)
    customer_id: UUID = None
    _lines: list[OrderLine] = field(default_factory=list, repr=False)
    status: str = "draft"

    def add_line(
        self, product_id: UUID, quantity: int, unit_price_cents: int
    ) -> None:
        """All mutation goes through the root. (Evans, Ch. 6)"""
        if self.status != "draft":
            raise ValueError("Cannot modify a non-draft order")
        self._lines.append(
            OrderLine(
                product_id=product_id,
                quantity=quantity,
                unit_price_cents=unit_price_cents,
            )
        )

    @property
    def lines(self) -> Sequence[OrderLine]:
        """Read-only view — callers must not mutate internal objects."""
        return tuple(self._lines)

    @property
    def total_cents(self) -> int:
        return sum(line.quantity * line.unit_price_cents for line in self._lines)

    def place(self) -> None:
        """Invariant enforced at the root before state transition. (Evans, Ch. 6)"""
        if not self._lines:
            raise ValueError("Cannot place an empty order")
        self.status = "placed"

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Order):
            return NotImplemented
        return self.id == other.id

    def __hash__(self) -> int:
        return hash(self.id)
```

### Evans Warns

- "Free database queries can actually breach the encapsulation of domain objects and
  AGGREGATES." Querying for `OrderLine` directly bypasses the root and breaks the
  invariant boundary.
- Keep AGGREGATEs small. Evans: "Use a small cluster of closely related objects."
  An AGGREGATE with ten internal entities is almost certainly modelling multiple
  concepts as one.

### Python: AGGREGATE Invariant Violation — What Goes Wrong

```python
# WRONG — external code mutates internal object directly, bypassing the root
order = order_repo.get(order_id)
line = order.lines[0]       # gets internal OrderLine
line.quantity = 0           # mutates it directly — AGGREGATE boundary violation!
# order.place() will now succeed even though a line has zero quantity.
# The root's invariant enforcement is bypassed entirely.

# WRONG — repository for an internal object (Evans, Ch. 6)
# Only AGGREGATE roots get repositories
class OrderLineRepository(ABC):  # should not exist
    def get(self, line_id: UUID) -> OrderLine: ...

# RIGHT — all changes go through the AGGREGATE root
order = order_repo.get(order_id)
order.update_line_quantity(line_id, new_quantity=3)  # root enforces invariants
order_repo.save(order)
```

The `update_line_quantity` method on the root can enforce that quantity > 0,
that the order is still in draft status, and that total weight limits are not
exceeded — none of which are enforceable when external code mutates `OrderLine`
directly.

---

## FACTORY

### Evans' Definition

> "Shift the responsibility for creating instances of complex objects and AGGREGATES
> to a separate object, which may itself have no responsibility in the domain model
> but is still part of the domain design. Provide an interface that encapsulates all
> complex assembly and that does not require the client to reference the concrete
> classes of the objects being instantiated. Create entire AGGREGATES as a piece,
> enforcing their invariants."

### Why This Pattern Exists

Complex AGGREGATE construction requires knowing internal structure — which violates
encapsulation if put in client code. A FACTORY centralises and hides that knowledge.
Reconstitution from storage is a distinct case: identity must be preserved, not
regenerated.

### When to Use (and Not Use) a FACTORY

Use when: creating a complex AGGREGATE from scratch; reconstituting from stored data;
when the client should not know the concrete types involved.

Do not use when: Evans: "If the constructor is simple enough, just use the
constructor." A `Money(100, "GBP")` needs no factory.

### Python Implementation

```python
from uuid import UUID, uuid4
from domain.model import Order, OrderLine


class OrderFactory:
    """FACTORY — encapsulates AGGREGATE construction. (Evans, Ch. 6)"""

    @staticmethod
    def create_draft(customer_id: UUID) -> Order:
        """New object — assign identity here, not in the caller."""
        return Order(id=uuid4(), customer_id=customer_id, status="draft")

    @staticmethod
    def reconstitute(
        order_id: UUID,
        customer_id: UUID,
        status: str,
        lines: list[OrderLine],
    ) -> Order:
        """
        Restore from storage. Evans, Ch. 6:
        'An ENTITY FACTORY used for reconstitution does not assign a new
        tracking ID. To do so would lose the continuity with the object's
        previous incarnation.'
        """
        order = Order(id=order_id, customer_id=customer_id, status=status)
        order._lines = list(lines)
        return order
```

Evans also describes FACTORY METHOD — a factory embedded as a classmethod on the
AGGREGATE itself, appropriate when construction is not overly complex:

```python
# FACTORY METHOD on the AGGREGATE root — Evans' alternative to a separate class
@dataclass
class Order:
    id: UUID = field(default_factory=uuid4)
    customer_id: UUID = None
    status: str = "draft"
    _lines: list[OrderLine] = field(default_factory=list, repr=False)

    @classmethod
    def place_new(cls, customer_id: UUID, lines: list[dict]) -> "Order":
        """
        FACTORY METHOD — encapsulates creation and initial invariant checking.
        Client code calls Order.place_new(...) rather than constructing directly.
        Appropriate when construction logic is moderate. (Evans, Ch. 6)
        """
        if not lines:
            raise ValueError("Cannot create an order with no lines")
        order = cls(customer_id=customer_id, status="placed")
        for line_data in lines:
            order._lines.append(
                OrderLine(
                    product_id=line_data["product_id"],
                    quantity=line_data["quantity"],
                    unit_price_cents=line_data["unit_price_cents"],
                )
            )
        return order

    @classmethod
    def reconstitute(
        cls, order_id: UUID, customer_id: UUID, status: str, lines: list[OrderLine]
    ) -> "Order":
        """Reconstitution path — preserves identity, skips creation invariants."""
        order = cls.__new__(cls)  # bypass __init__ to set id explicitly
        object.__setattr__(order, 'id', order_id)
        object.__setattr__(order, 'customer_id', customer_id)
        object.__setattr__(order, 'status', status)
        object.__setattr__(order, '_lines', list(lines))
        return order
```

**Decision: separate FACTORY class vs FACTORY METHOD?**
Evans' guideline: use a FACTORY METHOD on the root when the construction logic
is moderate and the root is a natural owner. Use a separate FACTORY class when
construction is complex, involves multiple collaborators, or when the client
must remain fully decoupled from concrete types.

### Evans Warns

- "Avoid calling constructors within constructors of other classes." Deep constructor
  nesting is the signal that a FACTORY is needed.
- FACTORIES should not contain business logic — structural assembly only. Invariant
  *checking* is appropriate; business *reasoning* is not.
- Reconstitution requires different error handling: "A FACTORY reconstituting an
  object will handle violation of an invariant differently... a more flexible response
  may be necessary." A previously valid stored object with a now-stale invariant
  needs a repair strategy, not a hard failure.

---

## REPOSITORY

### Evans' Definition

> "For each type of object that needs global access, create an object that can provide
> the illusion of an in-memory collection of all objects of that type. Set up access
> through a well-known global interface. Provide methods to add and remove objects,
> which will encapsulate the actual insertion or removal of data in the data store.
> Provide methods that select objects based on some criteria and return fully
> instantiated objects or collections of objects whose attribute values meet the
> criteria, thereby encapsulating the actual storage and query technology. Provide
> REPOSITORIES only for AGGREGATE roots that actually need direct access. Keep the
> client focused on the model, delegating all object storage and access to the
> REPOSITORIES."

### Why This Pattern Exists

Without REPOSITORIES, developers either traverse all associations (creating an
unmanageable object web) or write raw queries in application code (pushing domain
logic into SQL and losing model focus). Evans: "Domain logic moves into queries and
client code, and the ENTITIES and VALUE OBJECTS become mere data containers."

### What Belongs in a REPOSITORY

- `add` / `save` / `remove` methods
- Query methods that return fully instantiated domain objects
- Summary calculations the domain needs (counts, totals)

What does NOT belong: business logic, domain rules, or reasoning about which objects
satisfy a domain criterion — that is SPECIFICATION's responsibility *(Ch. 9)*.

### Python Implementation

```python
# domain/repositories.py — abstract interface in the domain layer
from abc import ABC, abstractmethod
from uuid import UUID
from domain.model import Order


class OrderRepository(ABC):
    """
    Abstract REPOSITORY — 'well-known global interface'. (Evans, Ch. 6)
    Interface defined here. Implementation lives in infrastructure/.
    """

    @abstractmethod
    def get(self, order_id: UUID) -> Order | None:
        """Return fully instantiated AGGREGATE or None."""
        ...

    @abstractmethod
    def save(self, order: Order) -> None:
        """Add or update — hides insert/update distinction from caller."""
        ...

    @abstractmethod
    def remove(self, order_id: UUID) -> None: ...

    @abstractmethod
    def find_by_customer(self, customer_id: UUID) -> list[Order]:
        """Hard-coded query — Evans: 'easiest REPOSITORY to build'."""
        ...


# infrastructure/repositories.py — concrete implementation
class InMemoryOrderRepository(OrderRepository):
    """Evans: 'allow easy substitution of a dummy implementation for testing'."""

    def __init__(self) -> None:
        self._store: dict[UUID, Order] = {}

    def get(self, order_id: UUID) -> Order | None:
        return self._store.get(order_id)

    def save(self, order: Order) -> None:
        self._store[order.id] = order

    def remove(self, order_id: UUID) -> None:
        self._store.pop(order_id, None)

    def find_by_customer(self, customer_id: UUID) -> list[Order]:
        return [o for o in self._store.values() if o.customer_id == customer_id]
```

### Evans Warns

- REPOSITORIES only for AGGREGATE roots: "Providing access to other objects muddies
  important distinctions. Free database queries can actually breach the encapsulation
  of domain objects and AGGREGATES."
- Query method names must be domain language: `find_by_customer`, not
  `select_where_customer_id_equals`.
- Performance warning: "Client Code Ignores REPOSITORY Implementation; Developers
  Do Not." A naïve `get_all()` that loads every row into memory is a production
  time-bomb — Evans gives the story of a WebSphere app that loaded the entire
  database to compute a summary.

### Python: REPOSITORY Violations — What Goes Wrong

```python
# WRONG 1 — business rule inside the REPOSITORY (Evans, Ch. 6)
# "Domain logic moves into queries and client code"
class OrderRepository(ABC):
    @abstractmethod
    def find_orders_eligible_for_discount(self, customer_id: UUID) -> list[Order]:
        # This is a DOMAIN RULE — it belongs in a SPECIFICATION, not here
        ...

# WRONG 2 — repository for a non-root object (Evans, Ch. 6)
# OrderLine is internal to the Order AGGREGATE — it must not have its own repo
class OrderLineRepository(ABC):  # should not exist
    @abstractmethod
    def find_by_product(self, product_id: UUID) -> list[OrderLine]: ...

# WRONG 3 — returning raw data instead of domain objects
class OrderRepository(ABC):
    @abstractmethod
    def find_by_customer(self, customer_id: UUID) -> list[dict]:
        # Returns dicts, not Orders — caller must reconstruct, domain logic leaks out
        ...

# RIGHT — clean REPOSITORY that stays in its lane
class OrderRepository(ABC):
    @abstractmethod
    def get(self, order_id: UUID) -> Order | None: ...          # fully instantiated

    @abstractmethod
    def save(self, order: Order) -> None: ...

    @abstractmethod
    def find_by_customer(self, customer_id: UUID) -> list[Order]: ...  # domain language

    @abstractmethod
    def count_placed_since(self, since: datetime) -> int: ...   # summary calc is OK
    # Business rules about WHICH orders qualify stay in SPECIFICATIONs
```
