# Ch. 15 — Distillation

## Chapter Thesis

Not all parts of the domain model are equally important. CORE DOMAIN is the part
that makes the product competitively valuable. Everything else — authentication,
email, currency conversion — is supporting structure. Identifying the CORE DOMAIN
and protecting it with the best developers and the most careful design is where
investment has the highest return.

Evans opens with Maxwell's equations: four equations expressing the entirety of
classical electromagnetism. Distillation is the process of separating the essential
from the supporting — in physics and in software.

---

## CORE DOMAIN

### Evans' Definition

> "Boil the model down. Find the CORE DOMAIN and provide a means of easily
> distinguishing it from the mass of supporting model and code. Bring the most
> valuable and specialized concepts into sharp relief. Make the CORE small."

### Why This Pattern Exists

In a large system, it becomes impossible to give everything equal attention. If the
team cannot distinguish between what is differentiating and what is commodity, they
will invest equally in both — and the CORE DOMAIN that justifies the product's
existence gets treated the same as a logging utility.

### Practical Implications

- The most experienced developers work on CORE DOMAIN code.
- CORE DOMAIN code gets the most careful model refinement and the most rigorous tests.
- When faced with a "make vs buy" decision, the answer for CORE DOMAIN is almost
  always "make" — buying means accepting someone else's model for your differentiating
  logic.

### Python Structure

Mark the CORE DOMAIN explicitly so it is visually distinct:

```
src/
├── core/              # CORE DOMAIN — your competitive advantage lives here
│   ├── domain/
│   └── application/
├── pricing/           # GENERIC SUBDOMAIN — pricing engine, possibly bought
├── notifications/     # GENERIC SUBDOMAIN — email/SMS sending
└── auth/              # GENERIC SUBDOMAIN — authentication
```

---

## GENERIC SUBDOMAIN

### Evans' Definition

> "Identify cohesive subdomains that are not the motivation for your project. Factor
> out GENERIC SUBDOMAINS and place them in separate MODULES. Give their continuing
> development lower priority than the CORE DOMAIN, and avoid assigning your core
> developers to the tasks."

### Why This Pattern Exists

Generic subdomains consume development capacity without producing competitive
advantage. Treating them as if they were differentiating is the most common way
engineering teams waste resources.

### Evans' Three Options for Generic Subdomains

1. **Buy an off-the-shelf solution.** An authentication library, a payment processor,
   a tax calculation service. If the problem is well-defined and solved, buy.
2. **Use an open-source solution.** If buying is not appropriate, adopt an existing
   solution rather than building.
3. **Build in-house with junior developers.** If none of the above applies, build it —
   but assign it to developers who are still developing their skills, not to the
   senior engineers who should be on the CORE DOMAIN.

Evans is unambiguous: "Avoid assigning your core developers to the tasks." A senior
engineer building a password reset flow is a misallocation.

### Python: Separating GENERIC SUBDOMAIN from CORE DOMAIN

```python
# WRONG — generic notification logic entangled in the CORE (Evans, Ch. 15)
# delivery/services.py — CORE service polluted with email concern
class DeliveryProgressService:
    def record_handling_event(self, event: HandlingEvent) -> None:
        cargo = self._cargo_repo.get(event.cargo_id)
        cargo.record_event(event)
        self._cargo_repo.save(cargo)
        # GENERIC SUBDOMAIN concern entangled in CORE — WRONG
        if event.event_type == "delivered":
            self._smtp.send(
                cargo.customer_email,
                f"Cargo {cargo.id} delivered",
                f"At {event.location}"
            )


# RIGHT — GENERIC SUBDOMAIN separated into its own package (Evans, Ch. 15)

# notifications/service.py — GENERIC SUBDOMAIN, potentially replaced by SendGrid
class NotificationService:
    """Email sending: solved problem, not differentiating, junior-developer work."""
    def __init__(self, smtp_client: SmtpClient) -> None:
        self._smtp = smtp_client

    def notify_delivery_completed(
        self, recipient: str, cargo_id: UUID, location: str
    ) -> None:
        self._smtp.send(
            to=recipient,
            subject=f"Cargo {cargo_id} delivered",
            body=f"Delivered at {location}",
        )


# delivery/services.py — CORE service, clean; notification injected as dependency
class DeliveryProgressService:
    def __init__(
        self,
        cargo_repo: CargoRepository,
        notifications: "NotificationService",
    ) -> None:
        self._cargo_repo = cargo_repo
        self._notifications = notifications

    def record_handling_event(self, event: HandlingEvent) -> None:
        cargo = self._cargo_repo.get(event.cargo_id)
        cargo.record_event(event)                    # CORE logic here
        self._cargo_repo.save(cargo)
        if cargo.is_delivered():
            self._notifications.notify_delivery_completed(  # delegate to generic
                cargo.customer_email, cargo.id, event.location
            )
```

---

## DOMAIN VISION STATEMENT

### Evans' Definition

> "Write a short description (about one page) of the CORE DOMAIN and the value it
> will bring... Revise the document as you come to deeper understanding."

This is a written document, not a code pattern. It keeps the team anchored on what
the CORE DOMAIN actually is. When priorities are contested, the DOMAIN VISION
STATEMENT is the reference. It should be short enough to be read in two minutes and
specific enough that two developers would agree on whether a given feature belongs
to the CORE DOMAIN.

---

## COHESIVE MECHANISM

### Evans' Definition

> "Partition a conceptually COHESIVE MECHANISM into a separate lightweight framework.
> Particularly watch for formalisms or well-documented categories of algorithms.
> Expose the capabilities of the framework with an INTENTION-REVEALING INTERFACE."

### Why This Pattern Exists

Some computations — graph traversal, constraint satisfaction, financial calculation
engines, rules evaluation — are complex enough to require significant implementation
effort but are not domain logic themselves. They are mechanisms that *support* domain
logic. If this complexity lives inside the domain layer, it overwhelms the domain
model.

### Python Implementation

Extract the mechanism into its own module with a clean, domain-facing interface:

```python
# mechanisms/route_optimizer.py
# Complex algorithm — NOT domain logic, but supports domain decisions

class RouteOptimizer:
    """
    COHESIVE MECHANISM — complex graph algorithm with a clean interface.
    (Evans, Ch. 15) The domain calls this; the mechanism knows nothing of
    the domain's concepts.
    """

    def find_optimal_route(
        self, waypoints: list[Coordinate], constraints: RouteConstraints
    ) -> Route:
        # Complex Dijkstra/A* implementation here — opaque to the domain
        ...
```

The domain calls `route_optimizer.find_optimal_route(...)` — it does not know or
care about the algorithm inside. The mechanism's interface uses domain types
(`Coordinate`, `Route`), but the mechanism itself contains no domain rules.

### What This Guidance Does Not Cover

Evans does not address specific algorithmic techniques, performance optimisation
of mechanisms, or how to test complex algorithmic code. Those are engineering
concerns outside the scope of the book.

---

## SEGREGATED CORE

### Evans' Definition

> "Refactor the model to separate the CORE concepts from supporting players
> (including ill-defined ones) and strengthen the cohesion of the CORE while
> reducing its coupling to other code. Factor all generic or supporting elements
> into other objects and place them into other packages, even if this means
> refactoring the model in ways that separate highly coupled elements."

### Why This Pattern Exists

Even after factoring out GENERIC SUBDOMAINS, the CORE DOMAIN often remains
entangled with supporting elements. Class diagrams of the CORE are cluttered
with peripheral concerns, making the most important relationships hard to see.
Evans: "Designers can't clearly see the most important relationships, leading to
a weak design."

SEGREGATED CORE takes the opposite approach to GENERIC SUBDOMAIN: instead of
identifying what is generic and moving it out, identify what is CORE and move
*that* into its own package — leaving everything else behind.

### Evans' Refactoring Steps

1. Identify a CORE subdomain (use the DOMAIN VISION STATEMENT as a guide).
2. Move related CORE classes into a new MODULE named for the concept.
3. Refactor to sever data and functionality that are not direct expressions of
   the CORE concept. Place removed aspects into other packages.
4. Simplify the SEGREGATED CORE MODULE's relationships and minimise its
   references to other modules.
5. Repeat with each CORE subdomain until the SEGREGATED CORE is complete.

### Python: Before and After SEGREGATED CORE

```python
# BEFORE — CORE domain entangled with billing, customer, routing (Evans, Ch. 15)
# Everything in one module — hard to see what the CORE actually is
# shipping/domain/model.py

@dataclass
class Cargo:
    id: UUID
    customer_id: UUID           # Customer concept tangled in
    weight_kg: float
    itinerary: list             # CORE concept
    billing_reference: str      # Billing concept tangled in
    invoice_amount: int         # Billing concept tangled in
    customer_name: str          # Customer concept tangled in

@dataclass
class HandlingEvent:            # CORE concept — but buried with non-CORE
    cargo_id: UUID
    event_type: str
    location: str
    invoice_line_id: UUID       # Billing reference tangled in

class CustomerAgreement: ...    # Generic customer concept — not CORE
class Invoice: ...              # Billing — not CORE
class PaymentRecord: ...        # Billing — not CORE


# AFTER — SEGREGATED CORE: delivery package contains only CORE concepts
# Non-CORE moved to their own packages (Evans, Ch. 15)

# delivery/model.py — SEGREGATED CORE (the product's competitive advantage)
@dataclass
class Cargo:
    """CORE: cargo and its delivery requirements — stripped of billing concerns."""
    id: UUID
    weight_kg: float
    itinerary: "Itinerary | None" = None
    customer_agreement: "CustomerAgreement | None" = None  # agreement, not customer

@dataclass(frozen=True)
class HandlingEvent:
    """CORE: what physically happens to the cargo during its journey."""
    cargo_id: UUID
    event_type: str   # "loaded", "unloaded", "cleared_customs"
    location: str
    occurred_at: datetime

@dataclass(frozen=True)
class CustomerAgreement:
    """CORE: the contractual constraints on delivery — stays in CORE because
    it directly constrains how cargo is handled."""
    required_arrival_by: datetime
    special_handling: list[str]


# billing/model.py — GENERIC SUBDOMAIN (important but not differentiating)
@dataclass
class Invoice:
    cargo_id: UUID
    amount_cents: int
    issued_at: datetime

# customer/model.py — supporting role
@dataclass
class Customer:
    id: UUID
    name: str
    contact_email: str
```

### Python: Directory Structure After Segregation

```
src/
├── delivery/               # SEGREGATED CORE — the heart of this product
│   ├── __init__.py
│   ├── model.py            # Cargo, HandlingEvent, Itinerary, CustomerAgreement
│   └── services.py         # DeliveryProgressService, RouteAssignmentService
├── billing/                # Supporting subdomain
│   ├── __init__.py
│   └── model.py            # Invoice, PaymentRecord
├── customer/               # Supporting role
│   ├── __init__.py
│   └── model.py            # Customer (the generic concept)
└── shared_kernel/
    └── money.py
```

### Python Structure

```
src/
├── delivery/           # SEGREGATED CORE — named for the core concept
│   ├── model.py        # Cargo, CustomerAgreement, HandlingStep
│   └── services.py
├── billing/            # Supporting subdomain — important but not CORE
│   └── model.py
├── routing/            # GENERIC SUBDOMAIN or supporting role
│   └── model.py
└── customer/           # Supporting role — Customer pulled out of CORE
    └── model.py
```

### Evans Warns

Segregating the CORE requires a whole-team decision. "An individual (or
programming pair) cannot act on those insights unilaterally." The definition of
what is CORE must be jointly agreed and consistently applied — and it will evolve
as deeper understanding emerges.

---

## ABSTRACT CORE

### Evans' Definition

> "Identify the most fundamental concepts in the model and factor them into
> distinct classes, abstract classes, or interfaces. Design this abstract model
> so that it expresses most of the interaction between significant components.
> Place this abstract overall model in its own MODULE, while the specialized,
> detailed implementation classes are left in their own MODULES defined by
> subdomain."

### Why This Pattern Exists

When many MODULES interact heavily, you face a dilemma: either create many
cross-module references (defeating the value of partitioning) or make
interactions indirect (obscuring the model). ABSTRACT CORE resolves this by
extracting the fundamental *polymorphic interfaces* that most interactions rely
on into a shared module — letting subdomains depend on the abstraction rather
than on each other.

Evans: "We are not looking for a technical trick here. This is a valuable
technique only when the polymorphic interfaces correspond to fundamental concepts
in the domain."

### Python Structure

```python
# core/interfaces.py — ABSTRACT CORE MODULE
from abc import ABC, abstractmethod

class Party(ABC):
    """Fundamental concept referenced across subdomains."""
    @abstractmethod
    def role_in(self, context: "TransactionContext") -> str: ...

class Commitment(ABC):
    """Abstract interaction that all subdomains depend on."""
    @abstractmethod
    def is_fulfilled(self) -> bool: ...


# Each subdomain implements the ABSTRACT CORE interfaces
# but does NOT import from other specialized subdomains.
# sales/model.py — imports from core/, not from shipping/
# shipping/model.py — imports from core/, not from sales/
```

### Evans Warns

Factoring out the ABSTRACT CORE is not mechanical. "If all the classes that were
frequently referenced across MODULES were automatically moved into a separate
MODULE, the likely result would be a meaningless mess." It requires deep
understanding of which concepts are genuinely fundamental — this is an example
of refactoring toward deeper insight, not a structural optimisation.
