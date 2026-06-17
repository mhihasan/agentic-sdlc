# Ch. 1 — Crunching Knowledge

## Chapter Thesis

Software development is fundamentally a knowledge-acquisition activity. The developer
must become a partner to the domain expert, continuously extracting and refining
understanding into a working model. Evans: "The heart of software is its ability to
solve domain-related problems for its user."

## No Named Patterns

Chapter 1 introduces no named patterns. It establishes the *practice* of knowledge
crunching — the iterative process of listening to domain experts, building rough
models, probing them with scenarios, and distilling what is learned back into both
code and conversation.

## What Evans Establishes Here

**The model is not a document.** It is the shared understanding in the team's heads,
expressed through code simultaneously. A diagram that does not match the code is not
a model — it is a lie.

**Early models are always incomplete.** Evans describes his own PCB experience: the
first model was wrong, the second was better, and insight accumulated through
iteration. The goal is not to design the right model upfront but to make the current
model less wrong through continuous refinement.

**Domain experts do not hand you the model.** They know their domain but do not
think in terms of software abstractions. The developer's job is to mine their
knowledge, notice concepts they rely on implicitly, and give those concepts explicit
form in code.

## Python: Model Evolution Through Knowledge Crunching

Evans uses a shipping booking application to show three iterations of understanding.
The same domain, three progressively deeper models — each produced by knowledge
crunching, not upfront design.

### Iteration 1 — First attempt: nouns from the spec

The developer reads the spec ("book cargo onto a voyage, allow 10% overbooking")
and maps nouns to classes. The overbooking rule is hidden as a guard clause:

```python
# Iteration 1 — knowledge shallow, business rule buried (Evans, Ch. 1)
class Voyage:
    def __init__(self, capacity: int) -> None:
        self.capacity = capacity
        self._booked_size = 0

    def add_cargo(self, cargo_size: int) -> bool:
        # Business rule hidden as a guard — domain expert cannot see it
        if self._booked_size + cargo_size > self.capacity * 1.1:
            return False
        self._booked_size += cargo_size
        return True
```

The domain expert cannot read this. The 10% rule is invisible. When it changes,
no one knows where to find it.

### Iteration 2 — After a knowledge-crunching session

The developer asks: "What do you call that 10% rule?" The expert says: "That's our
overbooking policy." A concept emerges, gets a name, gets its own object:

```python
# Iteration 2 — overbooking policy made explicit (Evans, Ch. 1)
# Evans: 'the more explicit design has advantages' — the rule is now
# visible, named, and testable independently of Voyage.
from dataclasses import dataclass


@dataclass(frozen=True)
class OverbookingPolicy:
    """Named by the domain expert. Testable alone. Change is isolated here."""
    allowance_factor: float = 1.1  # 110% of capacity

    def is_allowed(self, cargo_size: int, voyage: "Voyage") -> bool:
        return (
            voyage.booked_size + cargo_size
            <= voyage.capacity * self.allowance_factor
        )


@dataclass
class Voyage:
    capacity: int
    booked_size: int = 0

    def book(self, cargo_size: int, policy: OverbookingPolicy) -> int:
        if not policy.is_allowed(cargo_size, self):
            raise ValueError("Booking exceeds allowed capacity under current policy")
        self.booked_size += cargo_size
        return self._next_confirmation()

    def _next_confirmation(self) -> int:
        return id(self)  # simplified
```

Now the domain expert can read `OverbookingPolicy`. A test can verify it in
isolation. When rules change (115% for preferred customers), the change is contained.

### Iteration 3 — Deeper insight: transfer of responsibility

Months later, a deeper model emerges. The team realises shipping is not about
moving cargo but about *transferring responsibility* between parties. New concepts
emerge: `HandlingEvent`, `TransportLeg`, `Itinerary`. The previous model was not
wrong — it was incomplete. Knowledge crunching produced the insight:

```python
# Iteration 3 — deeper model after sustained knowledge crunching (Evans, Ch. 1)
# Evans: 'Useful models seldom lie on the surface.'
from dataclasses import dataclass, field
from datetime import datetime
from uuid import UUID, uuid4


@dataclass(frozen=True)
class TransportLeg:
    """One segment of an itinerary — emerged when expert described 'legs'."""
    voyage_id: UUID
    load_location: str
    unload_location: str
    load_time: datetime
    unload_time: datetime


@dataclass(frozen=True)
class Itinerary:
    """
    Was always implicit in data rows — knowledge crunching made it explicit.
    Now Routing Service returns it; Operations Service consumes it; the
    booking report renders it. One concept, three uses, zero duplication.
    """
    legs: tuple[TransportLeg, ...]

    @property
    def initial_departure(self) -> str:
        return self.legs[0].load_location

    @property
    def final_destination(self) -> str:
        return self.legs[-1].unload_location

    def is_satisfying(self, origin: str, destination: str) -> bool:
        """Validation against a Route Specification — emerges from deeper insight."""
        return (
            self.initial_departure == origin
            and self.final_destination == destination
        )


@dataclass
class Cargo:
    id: UUID = field(default_factory=uuid4)
    origin: str = ""
    destination: str = ""
    itinerary: Itinerary | None = None

    def assign_itinerary(self, itinerary: Itinerary) -> None:
        """Named for what it means in the domain — not set_itinerary_data()."""
        if not itinerary.is_satisfying(self.origin, self.destination):
            raise ValueError("Itinerary does not satisfy cargo route requirements")
        self.itinerary = itinerary

    def is_routed(self) -> bool:
        return self.itinerary is not None
```

## Evans' Five Ingredients of Effective Modelling

Evans lists these explicitly in Ch. 1. Each has a direct Python implication:

```python
# Ingredient 3: Knowledge-rich model — objects enforce rules, not just hold data
# Wrong: data container with no behaviour
@dataclass
class Invoice:
    amount: int
    due_date: date
    paid: bool = False

# Right: knowledge-rich — domain rule is in the object
@dataclass
class Invoice:
    amount_cents: int
    due_date: date
    grace_period_days: int
    paid_at: datetime | None = None

    def is_delinquent(self, as_of: date) -> bool:
        """Domain rule explicit in code — Evans Ch. 1, Ingredient 3."""
        if self.paid_at is not None:
            return False
        deadline = self.due_date + timedelta(days=self.grace_period_days)
        return as_of > deadline
```

## Implications for Python Practice

When a question touches on how to discover or evolve a model rather than how to
implement a specific pattern, this chapter is the reference. The answer: work through
concrete scenarios with domain experts, let the model emerge from that conversation,
and let the code reflect what you learn in real time.

Evans explicitly rejects big design upfront — a model designed in isolation from code
will drift. The model and the implementation must evolve together.
