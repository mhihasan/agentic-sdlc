# Ch. 16 — Large-Scale Structure

## Chapter Thesis

In very large systems, even well-bounded contexts and clean AGGREGATES leave
developers without a sense of where a given piece of logic belongs. Large-Scale
Structure provides system-wide organising principles that guide placement decisions
without requiring everyone to understand everything — and without constraining the
detailed design of individual parts.

Evans opens with the AIDS Quilt: thousands of people worked independently to create
panels. The quilt has coherent large-scale structure (size, shape, borders) while
allowing complete freedom in individual panel design. That is the goal here.

---

## EVOLVING ORDER

### Evans' Definition

> "Let this Large-Scale Structure evolve with the application, possibly changing to
> a completely different type of structure along the way. Don't overconstrain the
> detailed design and model decisions that must be made with detailed knowledge."

### Evans' Primary Guidance

Do not impose large-scale structure up front. Evans is explicit: an architecture
imposed before the system is understood will constrain rather than guide. Let the
structure emerge from refactoring as understanding deepens, and be willing to replace
it entirely when a better structure becomes apparent.

This is the meta-pattern for the chapter: all the patterns below are candidates to
try, not prescriptions to impose.

---

## RESPONSIBILITY LAYERS

### Evans' Definition

> "Look at the conceptual dependencies in your model and the varying rates and
> sources of change of different parts of your domain. If you identify natural strata
> in the domain, cast them as broad abstract layers."

### What This Is — and Is Not

RESPONSIBILITY LAYERS are domain-level layers — distinct from the technical LAYERED
ARCHITECTURE of Ch. 4. They describe how *domain concepts* depend on one another,
not how technical components are stacked.

Evans' example layers (for a generic business system — these are illustrative, not
prescriptive):
- **Potential** — what could happen (capabilities, resources)
- **Operations** — what is happening (active transactions, current state)
- **Policy** — rules governing operations
- **Decision support** — analysis, recommendations

A developer looking at a class knows which responsibility layer it belongs to and
can immediately reason about what kinds of dependencies are appropriate. A Policy
object depending on an Operations object is expected. The reverse would be unusual
and worth questioning.

### Python: RESPONSIBILITY LAYERS in a Shipping System

```python
# RESPONSIBILITY LAYERS — domain-level strata (Evans, Ch. 16)
# Layer flows downward: Policy → Operations → Potential
# Upper layers know about lower layers; lower layers do NOT know about upper.

# --- Potential layer: what assets and capabilities exist ---
from dataclasses import dataclass, field
from uuid import UUID, uuid4


@dataclass
class Vessel:
    """Potential — what capacity could carry cargo."""
    id: UUID = field(default_factory=uuid4)
    capacity_teu: int = 0
    allowed_cargo_types: list[str] = field(default_factory=list)

    def can_carry(self, cargo_type: str) -> bool:
        return cargo_type in self.allowed_cargo_types


# --- Operations layer: what is actually happening ---
@dataclass
class Voyage:
    """Operations — an active journey. Depends on Potential (downward ✓)."""
    id: UUID = field(default_factory=uuid4)
    vessel: Vessel = None   # Potential layer object — downward dependency ✓
    booked_teu: int = 0

    @property
    def available_teu(self) -> int:
        return self.vessel.capacity_teu - self.booked_teu


@dataclass
class Cargo:
    """Operations — cargo being shipped. No dependency on Policy layer ✓."""
    id: UUID = field(default_factory=uuid4)
    size_teu: int = 1
    cargo_type: str = "general"


# --- Policy layer: rules governing operations ---
@dataclass(frozen=True)
class OverbookingPolicy:
    """
    Policy — governs how Operations layer objects may be used.
    Policy depends on Operations (downward ✓).
    Operations does NOT import or reference Policy (no upward dependency ✓).
    """
    allowance_factor: float = 1.1

    def is_allowed(self, voyage: Voyage, cargo: Cargo) -> bool:
        if not voyage.vessel.can_carry(cargo.cargo_type):  # Potential ✓
            return False
        max_teu = voyage.vessel.capacity_teu * self.allowance_factor
        return voyage.booked_teu + cargo.size_teu <= max_teu


# The booking service sits at Policy level — it knows about both layers
class VoyageBookingService:
    def __init__(self, policy: OverbookingPolicy) -> None:
        self._policy = policy

    def book(self, voyage: Voyage, cargo: Cargo) -> None:
        if not self._policy.is_allowed(voyage, cargo):
            raise ValueError("Booking refused by overbooking policy")
        voyage.booked_teu += cargo.size_teu
```

The key discipline: `Voyage` and `Cargo` (Operations) never import `OverbookingPolicy`
(Policy). The dependency is strictly one-directional — downward.

---

## KNOWLEDGE LEVEL

### Evans' Definition

> "Create a distinct set of objects that can be used to describe and constrain the
> structure and behavior of the basic model. Keep these two levels separate, and
> allow the KNOWLEDGE LEVEL to be used flexibly."

### Why This Pattern Exists

When the rules governing objects need to be configurable at runtime — different
loan products with different interest rules, different subscription tiers with
different feature sets — embedding those rules directly on the objects means code
changes whenever business rules change.

KNOWLEDGE LEVEL separates the *operational objects* (a specific loan instance) from
the *objects that describe the rules governing them* (a loan product definition).

### Python Implementation

```python
# KNOWLEDGE LEVEL — describes how operational objects should behave
@dataclass(frozen=True)
class LoanProduct:
    """
    KNOWLEDGE LEVEL — configurable rules. (Evans, Ch. 16)
    Changes when business rules change, not when a loan is created.
    """
    product_code: str
    interest_rate: Decimal
    max_term_months: int
    early_repayment_penalty: Decimal


# OPERATIONAL LEVEL — the actual instance, governed by the knowledge level
@dataclass
class Loan:
    """Operational object — governed by LoanProduct at runtime."""
    id: UUID = field(default_factory=uuid4)
    product: LoanProduct = None   # reference to KNOWLEDGE LEVEL
    principal_cents: int = 0
    term_months: int = 0

    def monthly_payment_cents(self) -> int:
        """Uses knowledge level rules to compute operational values."""
        rate = self.product.interest_rate / 12
        n = self.term_months
        return int(self.principal_cents * rate / (1 - (1 + rate) ** -n))
```

### Evans Warns

The two levels must remain genuinely separate. A common failure is to merge them —
putting the configurable rules directly on the operational object — which means
every rule change requires modifying objects that should be stable.

---

## PLUGGABLE COMPONENT FRAMEWORK

### Evans' Definition

> "Distill an ABSTRACT CORE of interfaces and interactions and create a framework
> that allows diverse implementations of those interfaces to be freely substituted.
> Likewise, allow any application to use those components, so long as it operates
> strictly through the interfaces of the ABSTRACT CORE."

### Why This Pattern Exists

When a large system is broken into many BOUNDED CONTEXTS, integration overhead
grows: translations between contexts limit cohesion, and a SHARED KERNEL is only
feasible for closely collaborating teams. A PLUGGABLE COMPONENT FRAMEWORK resolves
this by defining an ABSTRACT CORE of shared interfaces at the hub — any component
that conforms to those interfaces can plug in, regardless of what BOUNDED CONTEXT
or team produced it.

Evans notes several widely used technical frameworks support this pattern (OSGi,
Eclipse plugins), but the pattern is conceptual first. A technical framework is
needed only if it solves an essential technical problem such as distribution.

### Python Structure

```python
# abstract_core/interfaces.py — the shared hub contracts
from abc import ABC, abstractmethod

class PricingEngine(ABC):
    """Hub interface — any conforming implementation can plug in."""
    @abstractmethod
    def calculate_price(self, order: Order) -> Money: ...

class FraudDetector(ABC):
    """Hub interface — swappable across BOUNDED CONTEXTS."""
    @abstractmethod
    def assess_risk(self, transaction: Transaction) -> RiskScore: ...


# Component A — conforms to hub interface, knows nothing of Component B
class RuleBasedPricingEngine(PricingEngine):
    def calculate_price(self, order: Order) -> Money: ...

# Component B — independently developed, plugs into same hub
class MLFraudDetector(FraudDetector):
    def assess_risk(self, transaction: Transaction) -> RiskScore: ...
```

### Evans Warns

"This is a very difficult pattern to apply. It requires precision in the design
of the interfaces and a deep enough model to capture the necessary behavior in
the ABSTRACT CORE." A poorly designed hub forces all components into a rigid
contract that does not serve any of them well — the same failure mode as a
premature unified model.

---

## SYSTEM METAPHOR

### Evans' Definition

> "When a concrete analogy to the system emerges that captures the imagination of
> team members and seems to lead design in a useful direction, adopt it as a large
> scale structure."

### What This Is

The most informal of the large-scale structure patterns. When a metaphor naturally
emerges that the whole team finds intuitive — "the system works like an air traffic
control tower" or "it's a contract negotiation" — that metaphor can guide intuitive
design decisions without requiring explicit documentation.

Evans is careful: the metaphor should emerge from working with the domain, not be
imposed as a clever analogy. And when the metaphor starts to mislead — when it
suggests a design that the domain actually does not support — it must be abandoned.

### What This Guidance Does Not Cover

Evans does not cover microservices architecture, event sourcing, CQRS, or any
distributed systems patterns. Large-Scale Structure addresses how developers navigate
and reason about a large codebase — not how services communicate across a network.
Those are outside the book's scope.
