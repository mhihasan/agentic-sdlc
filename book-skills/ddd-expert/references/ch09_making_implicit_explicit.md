# Ch. 9 — Making Implicit Concepts Explicit

## Chapter Thesis

Many powerful domain concepts remain hidden — scattered as conditions across multiple
methods rather than existing as named objects. Bringing them out as explicit model
elements, especially as SPECIFICATIONS, makes the model richer, more testable, and
easier to evolve.

---

## SPECIFICATION

### Evans' Definition

> "Create explicit predicate-like VALUE OBJECTS for specialized purposes. A
> SPECIFICATION is a predicate that determines if an object does or does not satisfy
> some criteria. It states a constraint, which may or may not be satisfied by the
> candidate object."

### Why This Pattern Exists

Business rules that determine whether something qualifies for some treatment (eligible
for a discount, ready to ship, overdue for review) tend to get scattered across query
methods, application services, and entity methods. They are hard to name, test, or
reuse independently. A SPECIFICATION gives each such rule a name, a location, and
a testable interface.

### Evans' Three Uses for SPECIFICATION

1. **Validation** — is this object in a valid state for a given purpose?
2. **Selection** — filter a collection to find objects that meet the criteria
3. **Building to order** — describe what an object should look like before creating it

### Python: Use 1 — Validation

```python
# domain/specifications.py
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime, timedelta
from domain.model import Order, Container, Chemical


class OrderSpecification(ABC):
    """SPECIFICATION base — VALUE OBJECT predicate. (Evans, Ch. 9)"""

    @abstractmethod
    def is_satisfied_by(self, order: Order) -> bool: ...

    def and_(self, other: "OrderSpecification") -> "OrderSpecification":
        return _AndSpecification(self, other)

    def or_(self, other: "OrderSpecification") -> "OrderSpecification":
        return _OrSpecification(self, other)


@dataclass(frozen=True)
class _AndSpecification(OrderSpecification):
    left: OrderSpecification
    right: OrderSpecification

    def is_satisfied_by(self, order: Order) -> bool:
        return self.left.is_satisfied_by(order) and self.right.is_satisfied_by(order)


@dataclass(frozen=True)
class LargeOrderSpecification(OrderSpecification):
    """Validation — is this order large enough to qualify for bulk pricing?"""
    threshold_cents: int

    def is_satisfied_by(self, order: Order) -> bool:
        return order.total_cents > self.threshold_cents


# Validation use: check before applying a business action
def apply_bulk_discount(order: Order, discount_pct: int) -> None:
    spec = LargeOrderSpecification(threshold_cents=50_000)
    if not spec.is_satisfied_by(order):
        raise ValueError("Order does not meet bulk discount threshold")
    order.apply_discount(discount_pct)
```

### Python: Use 2 — Selection (filtering a collection)

```python
@dataclass(frozen=True)
class RecentOrderSpecification(OrderSpecification):
    """Selection — find orders placed within the lookback window."""
    within_days: int

    def is_satisfied_by(self, order: Order) -> bool:
        cutoff = datetime.now() - timedelta(days=self.within_days)
        return order.placed_at > cutoff


# Composition — in an Application Service, not in a REPOSITORY
eligible = LargeOrderSpecification(10_000).and_(RecentOrderSpecification(30))
qualifying = [order for order in orders if eligible.is_satisfied_by(order)]
```

### Python: Use 3 — Building to Order (generating to a specification)

Evans uses the chemical warehouse packer as the canonical example. A
SPECIFICATION describes what a valid container configuration looks like.
A packing algorithm uses it both to constrain what it generates *and* to
validate the result afterwards — same object, two roles:

```python
# domain/specifications.py — Use 3: building to order (Evans, Ch. 9)
from enum import Enum


class ContainerFeature(Enum):
    ARMORED = "armored"
    VENTILATED = "ventilated"
    STANDARD = "standard"


@dataclass(frozen=True)
class ContainerSpecification:
    """
    SPECIFICATION describing what container a chemical requires.
    Evans Ch. 9: 'the same SPECIFICATION that is passed into the generator's
    interface can also be used, in its validation role, to confirm that the
    created object is correct.'
    """
    required_feature: ContainerFeature

    def is_satisfied_by(self, container: "Container") -> bool:
        return container.has_feature(self.required_feature)


@dataclass
class Chemical:
    name: str
    container_spec: ContainerSpecification  # describes what it needs


@dataclass
class Container:
    feature: ContainerFeature
    contents: list[Chemical] = None

    def __post_init__(self) -> None:
        self.contents = self.contents or []

    def has_feature(self, feature: ContainerFeature) -> bool:
        return self.feature == feature

    def can_accept(self, chemical: Chemical) -> bool:
        return chemical.container_spec.is_satisfied_by(self)


# Packing algorithm — SPECIFICATION drives both generation and validation
def pack_chemicals(
    chemicals: list[Chemical], containers: list[Container]
) -> dict[Chemical, Container]:
    assignment: dict[Chemical, Container] = {}
    for chemical in chemicals:
        for container in containers:
            if container.can_accept(chemical):
                # Same SPECIFICATION used in validation role to confirm result
                assert chemical.container_spec.is_satisfied_by(container), \
                    "Packing algorithm violated its own specification"
                assignment[chemical] = container
                container.contents.append(chemical)
                break
        else:
            raise ValueError(f"No suitable container for {chemical.name}")
    return assignment


# Usage
tnt = Chemical("TNT", ContainerSpecification(ContainerFeature.ARMORED))
ammonia = Chemical("Ammonia", ContainerSpecification(ContainerFeature.VENTILATED))
armored_container = Container(feature=ContainerFeature.ARMORED)
ventilated_container = Container(feature=ContainerFeature.VENTILATED)
packing = pack_chemicals([tnt, ammonia], [armored_container, ventilated_container])
```

### Where SPECIFICATIONs Live

A SPECIFICATION is a VALUE OBJECT — it belongs in the domain layer. It describes
criteria; it never executes queries or accesses the database directly.

### SPECIFICATION + REPOSITORY Integration

Evans dedicates significant text to this because it is where implementations most
often go wrong. He shows three approaches, ordered from cleanest to most pragmatic.

**Option 1 — In-memory filtering (simplest, not always practical):**
The REPOSITORY loads candidates and the SPECIFICATION filters them in Python.
Clean separation, but only viable when the collection is small enough to load fully.

```python
# Application Service
all_orders = order_repo.find_by_customer(customer_id)
spec = LargeOrderSpecification(10_000).and_(RecentOrderSpecification(30))
qualifying = [o for o in all_orders if spec.is_satisfied_by(o)]
```

**Option 2 — Double dispatch (Evans' preferred approach for large datasets):**
The SPECIFICATION delegates back to the REPOSITORY through a named method.
The rule stays in the SPECIFICATION; the efficient query lives in the REPOSITORY.

```python
# domain/specifications.py
class DelinquentInvoiceSpecification(InvoiceSpecification):
    def __init__(self, as_of_date: date) -> None:
        self._as_of_date = as_of_date

    def is_satisfied_by(self, invoice: Invoice) -> bool:
        return invoice.due_date + invoice.grace_period < self._as_of_date

    def satisfying_elements_from(
        self, repo: "InvoiceRepository"
    ) -> list[Invoice]:
        # Rule declared here; efficient query delegated to REPOSITORY.
        # Evans, Ch. 9: the rule is not embedded in the REPOSITORY method.
        return repo.find_where_grace_period_past(self._as_of_date)


# domain/repositories.py
class InvoiceRepository(ABC):

    @abstractmethod
    def find_where_grace_period_past(self, as_of: date) -> list[Invoice]:
        """Specialized query — not a rule, just an efficient access path."""
        ...

    @abstractmethod
    def select_satisfying(self, spec: InvoiceSpecification) -> list[Invoice]:
        """Calls spec.satisfying_elements_from(self). (Evans, Ch. 9)"""
        ...
```

**Option 3 — Query generation inside SPECIFICATION (Evans shows this but warns):**
The SPECIFICATION produces a SQL fragment directly. Evans notes this leaks table
structure into the domain layer and undermines maintainability. Use only if
the infrastructure leaves no better path.

### Evans Warns

- Never embed the business rule inside the REPOSITORY query method. A method named
  `find_orders_eligible_for_discount` has placed a domain decision inside
  infrastructure — the rule is now invisible to the model and untestable without
  a database.
- SPECIFICATION is a VALUE OBJECT — must be immutable. `frozen=True` enforces this.
- Names must be domain language: `DelinquentInvoiceSpecification`, not
  `InvoiceFilterCriteria`.

### What This Guidance Does Not Cover

Evans does not cover ORM-specific query builders (SQLAlchemy `filter()`, Django
Q objects, etc.). The double-dispatch pattern above is the conceptual model; how
the REPOSITORY implementation produces efficient SQL is an infrastructure concern
outside the book's scope.
