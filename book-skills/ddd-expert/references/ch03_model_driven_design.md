# Ch. 3 — Binding Model and Implementation

## Chapter Thesis

A model only has value when it is directly and literally reflected in code. Analysis
models that diverge from the implementation create a double-maintenance burden and
a model that cannot be trusted.

---

## MODEL-DRIVEN DESIGN

### Evans' Definition

> "Design a portion of the software system to reflect the domain model in a very
> literal way, so that mapping is obvious. Revisit the model and modify it to be
> implemented more naturally in software, even as you seek to make it reflect deeper
> insight into the domain. Demand a single model that serves both purposes well, in
> addition to supporting a robust UBIQUITOUS LANGUAGE."

### Why This Pattern Exists

Evans describes a project where analysts built a detailed model over months —
then handed it to developers. The developers produced working software that bore
no resemblance to the analysis model. When bugs arose, there was no conceptual
anchor. The analysis model was useless for reasoning about the code.

The failure: treating analysis and design as separate activities. MODEL-DRIVEN
DESIGN requires they be the same activity. The model that domain experts and
developers discuss *is* the model expressed in code.

### Python: The Divide Between Analysis and Implementation

```python
# WRONG — analysis model says "NetAssignment groups Nets by rules";
# implementation has abandoned that concept entirely (Evans, Ch. 3)
#
# Analysis model:                Implementation:
#   NetAssignment                  def apply_rules_to_file(filepath):
#   - nets: list[Net]                  data = parse_netlist(filepath)
#   - rule: AssignmentRule             for row in data:
#                                          if row['type'] == 'bus':
#                                              apply_bus_rules(row)
#
# The code does what the model described, but nothing in the code corresponds
# to NetAssignment or AssignmentRule. Bugs are impossible to locate in the model.


# RIGHT — MODEL-DRIVEN DESIGN: code reflects the model literally (Evans, Ch. 3)
from dataclasses import dataclass, field
from uuid import UUID


@dataclass(frozen=True)
class Net:
    """Corresponds directly to the Net concept domain experts use."""
    name: str
    component_pins: tuple[str, ...]  # "pin belongs to exactly one net"


@dataclass(frozen=True)
class AssignmentRule:
    """The rule concept from the analysis model — explicit in code."""
    rule_name: str
    applies_to_pattern: str  # e.g. "BUS_*"

    def matches(self, net: Net) -> bool:
        import fnmatch
        return fnmatch.fnmatch(net.name, self.applies_to_pattern)


@dataclass
class NetAssignment:
    """
    The central concept from the analysis model — present unchanged in code.
    A domain expert can look at this class and recognise what it represents.
    """
    nets: list[Net] = field(default_factory=list)
    rule: AssignmentRule = None

    def apply_to(self, net: Net) -> bool:
        """Returns True if this assignment applies to the given net."""
        return self.rule.matches(net)
```

### Python: Two Models vs One Model

The most common MODEL-DRIVEN DESIGN violation is maintaining a separate "domain
model" and "persistence model" — effectively two models that must be kept in sync:

```python
# WRONG — two models: the 'domain' Order and the 'persistence' OrderRecord
# Every change to domain logic requires updating both (Evans, Ch. 3)

# "Domain" model — used in business logic
@dataclass
class Order:
    id: UUID
    customer_id: UUID
    status: str
    line_items: list

# "Persistence" model — used for database mapping
@dataclass
class OrderRecord:
    order_id: str           # different type, different name
    cust_id: int            # different type, different name
    order_status: str
    # line items in separate table — not even represented here

# Translation layer that must be maintained forever
def order_to_record(order: Order) -> OrderRecord:
    return OrderRecord(
        order_id=str(order.id),
        cust_id=int(str(order.customer_id).replace("-", "")[:8], 16),
        order_status=order.status,
    )


# RIGHT — one model, one class, persistence handled in infrastructure layer
# The Order class IS the model. Infrastructure maps it to tables — not the other
# way around. (Evans, Ch. 3)

from dataclasses import dataclass, field
from uuid import UUID, uuid4


@dataclass
class Order:
    """
    One class that serves both analysis and design.
    Domain experts recognise it. Developers implement with it.
    Infrastructure layer maps it to storage — Order never knows about tables.
    """
    id: UUID = field(default_factory=uuid4)
    customer_id: UUID = None
    status: str = "draft"
    _lines: list = field(default_factory=list, repr=False)

    def place(self) -> None:
        if not self._lines:
            raise ValueError("Cannot place an empty order")
        self.status = "placed"

    def cancel(self, reason: str) -> None:
        if self.status == "fulfilled":
            raise ValueError("Cannot cancel a fulfilled order")
        self.status = "cancelled"
```

### Python: The PCB Bus Example — MODEL-DRIVEN vs Mechanistic

Evans uses a PCB layout tool example to show the difference. The mechanistic
approach parses files and applies rules procedurally — no model. The model-driven
approach creates objects that correspond to domain concepts:

```python
# WRONG — mechanistic: procedures on data, no domain concepts (Evans, Ch. 3)
def apply_bus_rules(netlist_file: str, bus_name: str, rules: dict) -> None:
    with open(netlist_file) as f:
        lines = f.readlines()
    for i, line in enumerate(lines):
        if bus_name in line:
            lines[i] = line + f" RULE={rules['impedance']}"
    with open(netlist_file, 'w') as f:
        f.writelines(lines)


# RIGHT — MODEL-DRIVEN: domain concepts present in code (Evans, Ch. 3)
@dataclass(frozen=True)
class LayoutRule:
    """Concept from the domain model — rules govern nets, not file lines."""
    impedance_ohms: int
    max_length_mm: float
    layer_preference: str


@dataclass
class Bus:
    """
    A Bus groups nets that share the same layout rules.
    Domain experts think in buses — so the code uses buses.
    """
    name: str
    nets: list[Net] = field(default_factory=list)
    rule: LayoutRule = None

    def apply_rule_to_all_nets(self) -> None:
        """One operation, all nets in the bus — matches how experts describe it."""
        for net in self.nets:
            net.assign_layout_rule(self.rule)
```

### Evans Warns

"If the design, or some central part of it, does not map to the domain model, that
model is of little value, and the correctness of the software is suspect."

A codebase full of `Manager`, `DTO`, `Mapper`, and `Processor` classes with no
domain vocabulary is a symptom that MODEL-DRIVEN DESIGN has been abandoned. When
every domain concept has a parallel "data transfer" representation, the team is
maintaining two models. Evans is also clear about direction of change: when the
implementation reveals that the model is awkward, *change the model*, not just
the implementation.

### What This Guidance Does Not Cover

Evans does not prescribe a specific modelling notation or diagramming tool. The
"model" can be expressed in any form the team finds useful — whiteboard sketches,
lightweight UML, structured prose — as long as it stays consistent with the code.
