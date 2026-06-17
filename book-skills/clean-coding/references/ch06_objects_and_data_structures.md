# Chapter 6: Objects and Data Structures

## Core Thesis
Objects hide data behind abstractions and expose behavior. Data structures expose data and have no behavior. These two paradigms are **complementary opposites** — choosing between them is a deliberate design decision.

## The Fundamental Dichotomy

### Objects vs. Data Structures

| | Objects | Data Structures |
|---|---|---|
| **Data** | Hidden behind abstractions | Exposed directly |
| **Behavior** | Exposed as methods | Handled by external functions |
| **Adding new types** | Easy (new class, no changes to existing) | Hard (all functions must change) |
| **Adding new functions** | Hard (all classes must change) | Easy (add a function, data untouched) |

> "Mature programmers know that the idea that everything is an object is a myth. Sometimes you really do want simple data structures with procedures operating on them."

### Python Example: Procedural vs. OOP Shapes

```python
# PROCEDURAL: Data structures + external functions
# Easy to ADD new functions; hard to add new shapes
from dataclasses import dataclass
import math

@dataclass
class Square:
    top_left: tuple[float, float]
    side: float

@dataclass
class Circle:
    center: tuple[float, float]
    radius: float

@dataclass
class Rectangle:
    top_left: tuple[float, float]
    height: float
    width: float

# Adding area() is easy; adding a new shape requires changing ALL functions
def area(shape) -> float:
    if isinstance(shape, Square):
        return shape.side ** 2
    elif isinstance(shape, Circle):
        return math.pi * shape.radius ** 2
    elif isinstance(shape, Rectangle):
        return shape.height * shape.width
    raise TypeError(f"Unknown shape: {type(shape)}")

def perimeter(shape) -> float:  # Adding this is easy — no shape changes needed
    if isinstance(shape, Square):
        return 4 * shape.side
    elif isinstance(shape, Circle):
        return 2 * math.pi * shape.radius
    elif isinstance(shape, Rectangle):
        return 2 * (shape.height + shape.width)
    raise TypeError(f"Unknown shape: {type(shape)}")
```

```python
# OO: Objects with polymorphic behavior
# Easy to ADD new shapes; hard to add new functions
from abc import ABC, abstractmethod

class Shape(ABC):
    @abstractmethod
    def area(self) -> float: ...

    @abstractmethod
    def perimeter(self) -> float: ...

class Square(Shape):
    def __init__(self, side: float) -> None:
        self._side = side

    def area(self) -> float:
        return self._side ** 2

    def perimeter(self) -> float:
        return 4 * self._side

class Circle(Shape):
    def __init__(self, radius: float) -> None:
        self._radius = radius

    def area(self) -> float:
        return math.pi * self._radius ** 2

    def perimeter(self) -> float:
        return 2 * math.pi * self._radius
```

**When to choose which:**
- Expect **new types** (shapes, users, products) → OO / polymorphism
- Expect **new behaviors** (new calculations, serializers, reporters) → Data structures / procedural

---

## Data Abstraction

Don't expose implementation details through getters/setters. Expose **meaningful abstractions**.

```python
# BAD: Exposes implementation (is it Cartesian? Polar?)
@dataclass
class ConcretePoint:
    x: float
    y: float

# BAD: Getter/setter wrappers are just public fields in disguise
class ConcreteVehicle:
    def get_fuel_tank_capacity_in_gallons(self) -> float: ...
    def get_gallons_of_gasoline(self) -> float: ...

# GOOD: Hides representation, exposes meaning
class Point:
    """Represents a point — implementation (Cartesian vs Polar) is hidden."""
    def __init__(self, x: float, y: float) -> None:
        self._x = x
        self._y = y

    def set_cartesian(self, x: float, y: float) -> None:
        self._x = x
        self._y = y

    def get_r(self) -> float:
        return math.sqrt(self._x**2 + self._y**2)

    def get_theta(self) -> float:
        return math.atan2(self._y, self._x)

class AbstractVehicle:
    def get_percent_fuel_remaining(self) -> float: ...  # hides gallons/liters distinction
```

---

## The Law of Demeter

> "Talk to friends, not strangers."

A method `f` of class `C` should only call methods of:
1. `C` itself
2. Objects created by `f`
3. Objects passed as arguments to `f`
4. Objects held in instance variables of `C`

**Do NOT** chain method calls through returned objects.

```python
# BAD: Train wreck — violates Law of Demeter
output_dir = ctx.get_options().get_scratch_dir().get_absolute_path()

# BAD (splits the chain but same violation — we still navigate through strangers)
opts = ctx.get_options()
scratch_dir = opts.get_scratch_dir()
output_dir = scratch_dir.get_absolute_path()

# GOOD: Ask ctx to do the work — it knows its internals
output_dir = ctx.get_scratch_directory_absolute_path()
# OR ask for what you need, not how to get there
ctx.create_scratch_file("output.txt")
```

```python
# BAD: In Django — violates Demeter
user = request.user
email = user.profile.contact.email  # navigating through multiple objects

# GOOD: Method on User that knows how to get its own contact email
email = request.user.get_contact_email()
```

---

## Data Transfer Objects (DTOs)

Pure data structures with no behavior — the legitimate use of exposed data.

```python
# DTO: pure data, no behavior — this is correct usage
@dataclass
class UserRecord:
    """Raw database record — no behavior, just data."""
    id: int
    username: str
    email: str
    created_at: datetime

# Active Record pattern (common in ORMs) — hybrid; keep business logic out
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    username = Column(String)
    email = Column(String)

    # BAD: business logic in Active Record
    def calculate_loyalty_discount(self) -> float: ...

    # GOOD: Keep it as pure data access; put business logic in a service
    def update_email(self, email: str) -> None:  # simple mutation OK
        self.email = email

class UserService:
    def calculate_loyalty_discount(self, user: User) -> float: ...
```

---

## Summary

| Concept | Rule |
|---|---|
| Data abstraction | Hide fields; expose meaningful operations, not raw accessors |
| OO vs procedural | Choose based on what changes: types → OO; functions → procedural |
| Law of Demeter | Call methods on direct collaborators only; don't navigate object graphs |
| Train wrecks | Never chain `a.get_b().get_c().get_d()` — ask the root object |
| DTOs | Pure data is legitimate; just don't put business logic in them |
