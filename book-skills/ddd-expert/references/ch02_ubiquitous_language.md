# Ch. 2 — Communication and the Use of Language

## Chapter Thesis

A domain model is only valuable if it becomes the backbone of a language used
consistently by the entire team — in code, conversation, and documentation. Without
this, the model and the implementation silently drift apart.

---

## UBIQUITOUS LANGUAGE

### Evans' Definition

> "Use the model as the backbone of a language. Commit the team to exercising that
> language relentlessly in all communication within the team and in the code. Use the
> same language in diagrams, writing, and especially speech. Iron out difficulties by
> experimenting with alternative expressions, which reflect alternative models. Then
> refactor the code, renaming classes, methods, and modules to conform to the new
> model. Resolve confusion over terms in conversation, in just the way we expect
> Ubiquitous Language problems to be dealt with, with laughter and immediate
> self-correction."

### Why This Pattern Exists

When developers use one vocabulary in code and domain experts use a different one in
conversation, every interaction requires mental translation. That translation cost
accumulates as subtle misunderstandings in requirements, design decisions that don't
reflect domain reality, and bugs that exist precisely because the code does not say
what the domain expert means.

### Python: Class and Method Naming

The most immediate expression of the Ubiquitous Language is in class and method names:

```python
# Wrong — technical vocabulary, no domain meaning (Evans, Ch. 2)
class OrderManager:
    def process_order_status_update(self, order_id: UUID, new_status: str) -> None: ...
    def execute_order_cancellation(self, order_id: UUID, reason_code: int) -> None: ...
    def handle_order_submission(self, order_id: UUID) -> bool: ...

# Right — Ubiquitous Language: names come from what the domain expert says
class Order:
    def place(self) -> None: ...            # expert says "place an order"
    def cancel(self, reason: str) -> None: ...  # expert says "cancel with reason"
    def fulfil(self) -> None: ...           # expert says "fulfil the order"
    def confirm(self) -> None: ...          # expert says "confirm receipt"
```

### Python: Exception Naming

Exceptions are part of the Ubiquitous Language too. They describe domain events,
not technical failures:

```python
# Wrong — technical exception names, no domain meaning
class InvalidStateError(Exception): ...
class ValidationFailed(Exception): ...
class ProcessingException(Exception): ...

# Right — exceptions named in domain language (Evans, Ch. 2)
class InsufficientFundsError(Exception):
    """Domain expert says 'the transfer fails if funds are insufficient'."""
    def __init__(self, requested: int, available: int) -> None:
        super().__init__(
            f"Cannot transfer {requested} cents — only {available} cents available"
        )

class OverbookingError(Exception):
    """Domain expert says 'we reject bookings that exceed our overbooking policy'."""
    pass

class CargoAlreadyClaimedError(Exception):
    """Named after a real domain event that happens at the port."""
    pass
```

### Python: Module (Package) Naming

Module names are part of the Ubiquitous Language. They should name domain concepts,
not technical layers:

```python
# Wrong — grouped by technical role, tells you nothing about the domain
# src/models/order.py
# src/handlers/order_handler.py
# src/utils/order_utils.py

# Right — grouped by domain concept, names are in the Ubiquitous Language
# src/ordering/model.py        — "Ordering" is what the domain expert calls it
# src/ordering/services.py
# src/shipment/model.py        — "Shipment" is a distinct domain concept
# src/shipment/tracking.py
```

### Python: Test Naming

Tests should read as domain scenarios, not technical descriptions:

```python
# Wrong — test names describe implementation, not domain behaviour
def test_order_status_field_set_to_cancelled_when_cancel_method_called(): ...
def test_voyage_capacity_exceeded_returns_false(): ...

# Right — test names use Ubiquitous Language to describe domain scenarios
def test_placed_order_can_be_confirmed(): ...
def test_cancelling_a_fulfilled_order_raises_error(): ...
def test_voyage_refuses_booking_that_exceeds_overbooking_policy(): ...
def test_cargo_without_itinerary_is_not_routed(): ...
```

### Python: Evans' Two-Scenario Demonstration

Evans shows the same conversation with and without Ubiquitous Language. The
second version is more concise because both parties use the same vocabulary:

```python
# Scenario 1 — developer and user talking past each other
# User: "When we change the customs clearance point, we need to redo the routing."
# Developer: "Right. We'll delete all the rows in the shipment table with that
#             cargo id, then we'll pass the origin, destination, and the new
#             customs clearance point into the Routing Service, and it will
#             repopulate the table."

# The code that results: technical, no domain concepts visible
def update_customs_point(cargo_id: int, new_point: str, db) -> None:
    db.execute("DELETE FROM shipment WHERE cargo_id = ?", cargo_id)
    rows = routing_service.get_route(cargo_id, origin, dest, new_point)
    db.executemany("INSERT INTO shipment VALUES (?,?,?,?)", rows)


# Scenario 2 — same conversation with Ubiquitous Language
# User: "When we change anything in the Route Specification, we need to regenerate
#        the Itinerary."
# Developer: "Right. When the Route Specification changes, we check whether the
#              current Itinerary still satisfies it. If not, we ask the Routing
#              Service for a new Itinerary."

# The code that results: reads like the conversation
def update_route_specification(
    cargo: Cargo,
    new_spec: RouteSpecification,
    routing_service: RoutingService,
) -> None:
    if not cargo.itinerary or not new_spec.is_satisfied_by(cargo.itinerary):
        new_itinerary = routing_service.route_for(new_spec)
        cargo.assign_itinerary(new_itinerary)
```

### Evans Warns

"Recognize that a change in the UBIQUITOUS LANGUAGE is a change to the model."
When a domain expert corrects your terminology in conversation, rename it in the
code in the same sprint. A class named `Invoice` in code while the business calls
it a `Bill` is a model divergence that compounds over time.

Documents and diagrams must use the same language. Evans: "If the terms explained
in a design document don't match the names in the code, the document is misleading."

### What This Guidance Does Not Cover

Evans does not provide rules for managing language evolution (when terms legitimately
change meaning as the domain is understood better). That is treated as a normal part
of model refinement — the language changes, and the code changes with it.
