# Ch. 14 — Maintaining Model Integrity

## Chapter Thesis

In large systems, a single unified model across all teams and subsystems is neither
feasible nor desirable. Different parts of the system have legitimately different
models for the same real-world concept. The solution is not forced unification, but
making the boundaries and relationships between models explicit and deliberately managed.

Evans opens with a concrete failure: two teams shared a `Charge` object without
realising they had different models of what a charge means. The result was silent
data corruption and production crashes. "What did they do once they knew about the
problem? They created separate Customer Charge and Supplier Charge classes." Making
the boundary explicit is the first step.

---

## BOUNDED CONTEXT

### Evans' Definition

> "Explicitly define the context within which a model applies. Explicitly set
> boundaries in terms of team organization, usage within specific parts of the
> application, and physical manifestations such as code bases and database schemas.
> Keep the model strictly consistent within these bounds, but don't be distracted or
> confused by issues outside."

### Why This Pattern Exists

The word "Customer" means something different in Sales (a prospect being nurtured)
than in Shipping (an address and a delivery preference) than in Billing (a payment
relationship). Forcing one `Customer` class to serve all three contexts produces a
class that serves none of them well, and changes for one context break the others.

### Python Structure

```
src/
├── sales/              # Sales BOUNDED CONTEXT — its own Customer model
│   ├── domain/
│   │   └── model.py    # Customer here means: prospect, pipeline stage, rep
│   └── application/
├── shipping/           # Shipping BOUNDED CONTEXT — different Customer model
│   ├── domain/
│   │   └── model.py    # Customer here means: delivery address, preferences
│   └── application/
└── shared_kernel/      # SHARED KERNEL — agreed-upon shared concepts
```

### Evans Warns

"Trying to maintain one unified model for a large system will result in a model that
serves no context well." The impulse to have one `Customer` across all contexts is
an attempt to avoid translation work — but it creates a worse problem: a model so
generic it expresses nothing clearly.

---

## CONTINUOUS INTEGRATION

### Evans' Definition

> "Institute a process of merging all code and other implementation artifacts
> frequently, with automated tests to flag fragmentation quickly. Relentlessly
> exercise the UBIQUITOUS LANGUAGE to hammer out a shared view of the model as
> the concepts evolve in different people's heads."

### Why This Pattern Exists

Evans places CONTINUOUS INTEGRATION immediately after BOUNDED CONTEXT because
defining the boundary is not enough — the boundary must be actively maintained.
"Having defined a BOUNDED CONTEXT, we must keep it sound." Without continuous
integration, model fragmentation happens even within a single context: developers
unknowingly duplicate concepts or change objects in ways that break others'
assumptions.

Evans is explicit that CI operates at two levels simultaneously:
1. **Conceptual integration** — relentless exercise of the UBIQUITOUS LANGUAGE in
   conversation, maintaining shared understanding as the model evolves.
2. **Implementation integration** — systematic merge/build/test process that
   exposes divergence quickly before it compounds.

### What Evans Requires

- A reproducible merge/build process
- Automated test suites that catch integration breaks
- A rule setting a small upper limit on the lifetime of unintegrated changes
  (Evans cites daily merges as the typical cadence)
- Constant exercise of the UBIQUITOUS LANGUAGE in model discussions — not just
  code merges, but shared conceptual convergence

### Evans Warns

CONTINUOUS INTEGRATION applies **within** a BOUNDED CONTEXT. It is not the
mechanism for coordinating across contexts — that is the job of CONTEXT MAP and
the integration relationship patterns. Evans: "Do not make the job any bigger than
it has to be. CONTINUOUS INTEGRATION is essential only within a BOUNDED CONTEXT."

### What This Guidance Does Not Cover

Evans does not prescribe particular CI tooling. The pattern is a team process
and discipline, not a technology prescription.

---

## CONTEXT MAP

### Evans' Definition

> "Identify each model in play on the project and define its BOUNDED CONTEXT. Name
> each BOUNDED CONTEXT, and make the names part of the UBIQUITOUS LANGUAGE. Describe
> the points of contact between the models, outlining explicit translation for any
> communication and highlighting any sharing."

### Practical Use

The CONTEXT MAP is a document — often a diagram — showing all BOUNDED CONTEXTS and
the named relationships between them. It makes integration points explicit so every
developer knows where translation is required and what the contractual relationship
between contexts is.

Evans: "Until you have an unambiguous CONTEXT MAP that places all your work in
context, you won't know where you stand."

---

## SHARED KERNEL

### Evans' Definition

> "Designate with an explicit boundary some subset of the domain model that the teams
> agree to share. Keep this kernel small. This explicitly shared stuff has special
> status, and shouldn't be changed without consultation with the other team."

A SHARED KERNEL is often the CORE DOMAIN or a set of GENERIC SUBDOMAINS that both
contexts genuinely need to share. Changes to the shared kernel require coordination
between teams — it cannot be modified unilaterally.

### Python: SHARED KERNEL Implementation

The SHARED KERNEL is a separate package that both BOUNDED CONTEXT packages import.
It is small, stable, and changed only through explicit team agreement:

```python
# shared_kernel/money.py — shared VALUE OBJECT agreed on by both contexts
# Both the Sales context and Billing context import this — never the other way
from dataclasses import dataclass
from typing import Self


@dataclass(frozen=True)
class Money:
    """
    SHARED KERNEL — agreed between Sales and Billing teams.
    Neither team modifies this without informing the other. (Evans, Ch. 14)
    """
    amount_cents: int
    currency: str

    def add(self, other: Self) -> Self:
        if self.currency != other.currency:
            raise ValueError("Currency mismatch")
        return Money(self.amount_cents + other.amount_cents, self.currency)

    def __str__(self) -> str:
        return f"{self.amount_cents / 100:.2f} {self.currency}"


# shared_kernel/identifiers.py — shared ID types only (very minimal shared kernel)
from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True)
class CustomerId:
    """Shared identifier — stable across contexts, contains no behaviour."""
    value: UUID


# Each context imports from shared_kernel/, never from the other context
# sales/domain/model.py
from shared_kernel.money import Money
from shared_kernel.identifiers import CustomerId

# billing/domain/model.py
from shared_kernel.money import Money
from shared_kernel.identifiers import CustomerId
```

---

## ANTICORRUPTION LAYER

### Evans' Definition

> "Create an isolating layer to provide clients with functionality in terms of their
> own domain model. The layer talks to the other system through its existing interface,
> requiring little or no modification to the other system. Internally, the layer
> translates in both directions as necessary between the two models."

### Why This Pattern Exists

When integrating with a legacy system, a third-party API, or another team's context,
the external model will not match your domain model. Without a translation layer,
the external model's concepts contaminate your domain. The ANTICORRUPTION LAYER
absorbs the translation so the domain layer never sees the external model.

### Python Implementation

```python
# infrastructure/acl/legacy_crm.py
from uuid import UUID
from domain.model import Customer
from external.legacy_crm import LegacyCRMClient  # external system


class LegacyCRMAntiCorruptionLayer:
    """
    ANTICORRUPTION LAYER — translates external model into our domain model.
    Our domain layer never imports from the external system directly.
    (Evans, Ch. 14)
    """

    def __init__(self, crm_client: LegacyCRMClient) -> None:
        self._crm = crm_client

    def get_customer(self, external_id: str) -> Customer:
        raw = self._crm.fetch_contact(external_id)  # external API call
        return Customer(                              # translate to OUR model
            id=UUID(raw["guid"]),
            name=raw["full_name"],
            email=raw["primary_email_address"],
        )
```

The ANTICORRUPTION LAYER lives in `infrastructure/` — it is a technical adapter,
not a domain object.

---

### Integration Relationship Patterns with Python Examples

These patterns describe the *organisational and contractual relationship* between
two BOUNDED CONTEXTS and determine what integration code is appropriate.

**CUSTOMER/SUPPLIER** — upstream team provides an interface, downstream negotiates:

```python
# Upstream team (Shipping) publishes an interface the downstream (Billing) agreed to
# shipping/api/shipping_service.py — upstream publishes this contract
from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True)
class ShipmentConfirmation:
    """Published by Shipping. Billing agreed this is what it needs. (Ch. 14)"""
    shipment_id: UUID
    cargo_id: UUID
    delivered_at: str
    actual_weight_kg: float


class ShippingService:
    def get_confirmation(self, shipment_id: UUID) -> ShipmentConfirmation: ...


# billing/infrastructure/shipping_adapter.py — downstream consumes
class BillingShippingAdapter:
    """Downstream consumes the upstream contract — CUSTOMER/SUPPLIER."""

    def __init__(self, shipping_service: ShippingService) -> None:
        self._shipping = shipping_service

    def get_billable_weight(self, shipment_id: UUID) -> float:
        confirmation = self._shipping.get_confirmation(shipment_id)
        return confirmation.actual_weight_kg
```

**CONFORMIST** — downstream adopts upstream model wholesale, no translation:

```python
# CONFORMIST — Billing simply uses Shipping's types directly.
# No ANTICORRUPTION LAYER, no translation. Downstream is fully constrained
# by upstream's model. Simpler but less autonomous. (Evans, Ch. 14)
from shipping.api.shipping_service import ShipmentConfirmation, ShippingService

class InvoiceGenerationService:
    def generate_invoice(self, confirmation: ShipmentConfirmation) -> Invoice:
        # Uses ShipmentConfirmation directly — conforms to upstream model
        return Invoice(
            cargo_id=confirmation.cargo_id,
            weight_kg=confirmation.actual_weight_kg,
        )
```

**OPEN HOST SERVICE** — upstream publishes a versioned protocol for all consumers:

```python
# Upstream publishes one versioned API all downstreams use (Evans, Ch. 14)
# shipping/api/v2/protocol.py — published, versioned, stable
from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True)
class ShipmentEvent:
    """
    OPEN HOST SERVICE protocol — versioned, published, used by all consumers.
    Billing, Invoicing, Analytics all use this same event format.
    Changes must be backward-compatible or bumped to v3.
    """
    event_type: str          # "delivered", "damaged", "delayed"
    shipment_id: UUID
    cargo_id: UUID
    timestamp: str
    payload: dict            # extensible — new fields don't break old consumers
```

**PUBLISHED LANGUAGE** — shared schema used as the translation medium:

```python
# PUBLISHED LANGUAGE — both contexts translate to/from a shared JSON schema
# Neither context knows about the other's internal model (Evans, Ch. 14)

# The published language (e.g., a JSON Schema or Pydantic model)
from pydantic import BaseModel
from uuid import UUID


class CargoTransferEvent(BaseModel):
    """
    PUBLISHED LANGUAGE — documented, stable schema both contexts translate through.
    Shipping translates its internal HandingEvent → CargoTransferEvent.
    Billing translates CargoTransferEvent → its internal BillableMilestone.
    Neither context imports from the other. (Evans, Ch. 14)
    """
    cargo_id: UUID
    event_type: str
    location_code: str
    occurred_at: str
    weight_kg: float


# Shipping side — translates OUT to published language
def publish_handling_event(event: HandlingEvent) -> CargoTransferEvent:
    return CargoTransferEvent(
        cargo_id=event.cargo.id,
        event_type=event.type.value,
        location_code=event.location.unlocode,
        occurred_at=event.completion_time.isoformat(),
        weight_kg=event.cargo.weight_kg,
    )


# Billing side — translates IN from published language
def consume_transfer_event(event: CargoTransferEvent) -> BillableMilestone:
    return BillableMilestone(
        reference=event.cargo_id,
        milestone_type=MilestoneType.from_transfer(event.event_type),
        weight=event.weight_kg,
    )
```

**SEPARATE WAYS** — no integration, solve separately:

```python
# SEPARATE WAYS — two contexts that overlap slightly just solve independently
# No shared code, no translation, no coupling. (Evans, Ch. 14)
# Example: both Sales and HR need "address" but for completely different purposes.

# sales/domain/model.py — Sales address: for shipping, billing, territory
@dataclass(frozen=True)
class SalesAddress:
    street: str
    city: str
    country: str
    sales_territory: str   # Sales-specific concept

# hr/domain/model.py — HR address: for payroll, tax jurisdiction, office
@dataclass(frozen=True)
class EmployeeAddress:
    street: str
    city: str
    country: str
    tax_jurisdiction_code: str  # HR-specific concept
# No shared Address class — duplication accepted to avoid coupling.
```

### What This Guidance Does Not Cover

Evans does not address event-driven integration, async messaging between contexts, or
specific API design patterns. Those are architectural decisions outside the book's scope.
