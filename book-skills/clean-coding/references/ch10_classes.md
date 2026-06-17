# Chapter 10: Classes

## Core Thesis
Classes should be **small**, have a **single responsibility**, be **highly cohesive**, and be **open for extension but closed for modification**. Designing around these principles leads to systems that are easier to change and understand.

---

## Class Organization

Classes should be organized top-down:
1. Public class variables (constants)
2. Private class variables
3. Public methods
4. Private helper methods (near the public method that uses them)

```python
class Stack:
    # 1. Constants
    MAX_SIZE = 1000

    # 2. Private state
    def __init__(self) -> None:
        self._elements: list = []
        self._size: int = 0

    # 3. Public interface
    def push(self, element) -> None:
        self._guard_against_overflow()
        self._elements.append(element)
        self._size += 1

    def pop(self):
        self._guard_against_underflow()
        self._size -= 1
        return self._elements.pop()

    def is_empty(self) -> bool:
        return self._size == 0

    # 4. Private helpers — near the methods that use them
    def _guard_against_overflow(self) -> None:
        if self._size >= self.MAX_SIZE:
            raise OverflowError(f"Stack has reached maximum size of {self.MAX_SIZE}")

    def _guard_against_underflow(self) -> None:
        if self.is_empty():
            raise UnderflowError("Cannot pop from an empty stack")
```

---

## Single Responsibility Principle (SRP)

A class should have **one reason to change**. If you can describe a class in 25 words without using "if," "and," "or," or "but" — it likely has one responsibility.

```python
# BAD: SuperDashboard has TWO reasons to change
# 1. GUI/component tracking changes  2. Version/build number changes
class SuperDashboard:
    def get_last_focused_component(self): ...
    def set_last_focused(self, component): ...
    def get_major_version_number(self) -> int: ...
    def get_minor_version_number(self) -> int: ...
    def get_build_number(self) -> int: ...

# GOOD: Split into two single-responsibility classes
class Version:
    """Tracks software version — one reason to change: versioning policy."""
    def __init__(self, major: int, minor: int, build: int) -> None:
        self.major = major
        self.minor = minor
        self.build = build

    def __str__(self) -> str:
        return f"{self.major}.{self.minor}.{self.build}"

class FocusTracker:
    """Tracks UI component focus — one reason to change: UI interaction model."""
    def __init__(self) -> None:
        self._last_focused = None

    def set_focused(self, component) -> None:
        self._last_focused = component

    def get_focused(self):
        return self._last_focused
```

**Test for SRP:** "Why would this class change?" — if there are two different answers, split the class.

---

## Cohesion

A class is **cohesive** when most methods use most instance variables. Low cohesion signals the class should be split.

```python
# BAD: Low cohesion — each method uses different variables
class DataProcessor:
    def __init__(self):
        self._connection = None       # used only by DB methods
        self._cache = {}              # used only by cache methods
        self._formatter = None        # used only by format methods
        self._logger = None           # used only by log methods

    def query_db(self, sql): ...          # uses _connection
    def cache_result(self, key, val): ... # uses _cache
    def format_output(self, data): ...    # uses _formatter
    def log_event(self, msg): ...         # uses _logger


# GOOD: High cohesion — each method uses most instance variables
class Stack:
    def __init__(self):
        self._elements = []
        self._size = 0

    def push(self, item):           # uses _elements and _size
        self._elements.append(item)
        self._size += 1

    def pop(self):                  # uses _elements and _size
        self._size -= 1
        return self._elements.pop()

    def is_empty(self) -> bool:     # uses _size
        return self._size == 0

    def peek(self):                 # uses _elements
        return self._elements[-1]
```

**Rule:** When a class has low cohesion, split it. The split usually reveals new, smaller, highly cohesive classes.

---

## Open/Closed Principle (OCP)

Classes should be **open for extension, closed for modification**. New behavior is added by extending, not by changing existing tested code.

```python
# BAD: Adding a new shape requires modifying Geometry
class Geometry:
    def area(self, shape) -> float:
        if isinstance(shape, Square):
            return shape.side ** 2
        elif isinstance(shape, Circle):
            return math.pi * shape.radius ** 2
        # Must add new elif for every new shape!
        raise TypeError("Unknown shape")


# GOOD: OCP via abstract base / Protocol
from abc import ABC, abstractmethod

class Shape(ABC):
    @abstractmethod
    def area(self) -> float: ...

class Square(Shape):
    def __init__(self, side: float) -> None:
        self._side = side

    def area(self) -> float:
        return self._side ** 2

class Triangle(Shape):  # New shape — Geometry is NOT modified
    def __init__(self, base: float, height: float) -> None:
        self._base = base
        self._height = height

    def area(self) -> float:
        return 0.5 * self._base * self._height

# In Python, use Protocol for structural subtyping (duck typing)
from typing import Protocol

class Shape(Protocol):
    def area(self) -> float: ...
```

---

## Dependency Inversion Principle (DIP)

Depend on **abstractions**, not concretions. High-level classes shouldn't depend on low-level details.

```python
# BAD: High-level Portfolio depends on low-level StockExchange implementation
class StockExchange:
    def current_price(self, symbol: str) -> float:
        return requests.get(f"https://api.stocks.com/price/{symbol}").json()["price"]

class Portfolio:
    def __init__(self) -> None:
        self._exchange = StockExchange()  # hard-coded dependency!
        self._stocks: dict[str, int] = {}

    def total_value(self) -> float:
        return sum(
            self._exchange.current_price(symbol) * shares
            for symbol, shares in self._stocks.items()
        )

# Hard to test! Must hit real API.


# GOOD: Depend on an abstraction
from typing import Protocol

class StockExchange(Protocol):
    def current_price(self, symbol: str) -> float: ...

class RealStockExchange:
    def current_price(self, symbol: str) -> float:
        return requests.get(f"https://api.stocks.com/price/{symbol}").json()["price"]

class Portfolio:
    def __init__(self, exchange: StockExchange) -> None:
        self._exchange = exchange  # injected — could be real or test double
        self._stocks: dict[str, int] = {}

    def add(self, symbol: str, shares: int) -> None:
        self._stocks[symbol] = self._stocks.get(symbol, 0) + shares

    def total_value(self) -> float:
        return sum(
            self._exchange.current_price(symbol) * shares
            for symbol, shares in self._stocks.items()
        )

# Easy to test with a fake:
class FixedPriceExchange:
    def __init__(self, prices: dict[str, float]) -> None:
        self._prices = prices

    def current_price(self, symbol: str) -> float:
        return self._prices[symbol]

def test_portfolio_total_value():
    exchange = FixedPriceExchange({"AAPL": 150.0, "GOOG": 2800.0})
    portfolio = Portfolio(exchange)
    portfolio.add("AAPL", 2)
    portfolio.add("GOOG", 1)
    assert portfolio.total_value() == 3100.0
```

---

## Class Size Warning Signs

| Warning Sign | What It Means |
|---|---|
| Name includes Manager, Processor, Handler, Super | Probably aggregating multiple responsibilities |
| Can't describe in 25 words without "and/but/or" | Too many responsibilities |
| Methods use disjoint sets of instance variables | Low cohesion — split the class |
| Must change class when requirements unrelated to its name change | SRP violation |
| Can't write unit tests without complex setup | Too many dependencies — use DI |

---

## Summary

| Principle | Rule | Python Mechanism |
|---|---|---|
| SRP | One reason to change | Small, focused classes |
| High cohesion | Most methods use most variables | Split when cohesion drops |
| OCP | Extend, don't modify | Abstract base class / Protocol |
| DIP | Depend on abstractions | Constructor injection + Protocol |
