# Chapter 26: Behavioral — Visitor

## Summary
Visitor lets you add new operations to an existing object structure (like a Composite tree)
without modifying those objects. You put the new operation into a Visitor class; each element
in the structure "accepts" a visitor by calling the visitor's method that corresponds to the
element's type. The pattern solves the Open/Closed dilemma for adding operations to stable
object hierarchies: you can't always modify the existing classes, but you can always add a
new Visitor. The cost is double dispatch (element calls visitor; visitor method is type-specific)
and the Visitor must be updated when new element types are added.

## Key Principles
- **Double dispatch**: `element.accept(visitor)` → `visitor.visit_element_type(element)`. The element's type is resolved at the `accept()` call.
- **Open for new operations**: Adding a new operation = adding a new Visitor class. Zero changes to elements.
- **Closed for new element types**: Adding a new element type requires updating every existing Visitor — this is the trade-off.
- **Visitor accumulates state**: A single Visitor pass can collect results across the entire tree (e.g., total cost, XML string, dependency graph).
- **vs Iterator**: Iterator traverses; Visitor performs type-specific operations while traversing.

## Python Example

```python
from __future__ import annotations
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

# ❌ Bad: Adding a "pretty-print" operation requires editing every Expr class
# class Number:
#     def evaluate(self): return self.value
#     def pretty_print(self): return str(self.value)  # ← must add to every class
#
# class Add:
#     def evaluate(self): ...
#     def pretty_print(self): ...  # ← repeated for every new operation

# ✅ Good: Visitor — each new operation is a new Visitor class; elements untouched.

# ══════════════════════════════════════════════════════
# Stable element hierarchy — an AST / expression tree
# ══════════════════════════════════════════════════════

class ExprVisitor(ABC):
    @abstractmethod
    def visit_number(self, expr: "Number") -> None: ...
    @abstractmethod
    def visit_add(self, expr: "Add") -> None: ...
    @abstractmethod
    def visit_multiply(self, expr: "Multiply") -> None: ...


class Expr(ABC):
    @abstractmethod
    def accept(self, visitor: ExprVisitor) -> None: ...


@dataclass
class Number(Expr):
    value: float

    def accept(self, visitor: ExprVisitor) -> None:
        visitor.visit_number(self)  # double dispatch


@dataclass
class Add(Expr):
    left: Expr
    right: Expr

    def accept(self, visitor: ExprVisitor) -> None:
        visitor.visit_add(self)


@dataclass
class Multiply(Expr):
    left: Expr
    right: Expr

    def accept(self, visitor: ExprVisitor) -> None:
        visitor.visit_multiply(self)


# ══════════════════════════════════════════════════════
# Operation 1: Evaluate — Visitor accumulates a result
# ══════════════════════════════════════════════════════

class EvaluatorVisitor(ExprVisitor):
    def __init__(self) -> None:
        self._stack: list[float] = []

    def visit_number(self, expr: Number) -> None:
        self._stack.append(expr.value)

    def visit_add(self, expr: Add) -> None:
        expr.left.accept(self)
        expr.right.accept(self)
        self._stack.append(self._stack.pop() + self._stack.pop())

    def visit_multiply(self, expr: Multiply) -> None:
        expr.left.accept(self)
        expr.right.accept(self)
        self._stack.append(self._stack.pop() * self._stack.pop())

    @property
    def result(self) -> float:
        return self._stack[-1]


# Operation 2: Pretty-print — added with ZERO changes to element classes
class PrintVisitor(ExprVisitor):
    def __init__(self) -> None:
        self._parts: list[str] = []

    def visit_number(self, expr: Number) -> None:
        self._parts.append(str(int(expr.value)))

    def visit_add(self, expr: Add) -> None:
        self._parts.append("(")
        expr.left.accept(self)
        self._parts.append(" + ")
        expr.right.accept(self)
        self._parts.append(")")

    def visit_multiply(self, expr: Multiply) -> None:
        self._parts.append("(")
        expr.left.accept(self)
        self._parts.append(" * ")
        expr.right.accept(self)
        self._parts.append(")")

    @property
    def result(self) -> str:
        return "".join(self._parts)


# Build expression: (2 + 3) * 4
expr = Multiply(
    left=Add(Number(2), Number(3)),
    right=Number(4),
)

evaluator = EvaluatorVisitor()
expr.accept(evaluator)
assert evaluator.result == 20.0

printer = PrintVisitor()
expr.accept(printer)
assert printer.result == "((2 + 3) * 4)"


# ── E-commerce document total (from the book) ────────────────────────────

@dataclass
class Item:
    name: str
    price: float
    quantity: int

@dataclass
class Shipping:
    method: str
    cost: float

@dataclass
class Insurance:
    coverage: str
    cost: float

class ExportVisitor(ABC):
    def visit_item(self, item: Item) -> None: ...
    def visit_shipping(self, shipping: Shipping) -> None: ...
    def visit_insurance(self, ins: Insurance) -> None: ...

class TotalCostVisitor:
    def __init__(self) -> None: self.total = 0.0
    def visit_item(self, item: Item) -> None:
        self.total += item.price * item.quantity
    def visit_shipping(self, shipping: Shipping) -> None:
        self.total += shipping.cost
    def visit_insurance(self, ins: Insurance) -> None:
        self.total += ins.cost

components = [
    Item("Widget", 9.99, 3),
    Shipping("Express", 12.50),
    Insurance("Basic", 5.00),
]
calc = TotalCostVisitor()
for c in components:
    if isinstance(c, Item): calc.visit_item(c)
    elif isinstance(c, Shipping): calc.visit_shipping(c)
    elif isinstance(c, Insurance): calc.visit_insurance(c)

assert abs(calc.total - (9.99 * 3 + 12.50 + 5.00)) < 0.001
```

## Quick Reference
- **Intent**: Add operations to an object structure without modifying the structure's classes
- **Double dispatch**: `element.accept(visitor)` → `visitor.visit_concrete_type(element)`
- **`accept()` on every element**: Each element class needs one `accept(visitor)` method — the only intrusion
- **Open for operations**: New operation = new Visitor class; zero element changes
- **Closed for new elements**: New element type = must update all Visitor implementations
- **Visitor accumulates state**: `self._stack`, `self.total`, `self._output` — result collected across the tree
- **vs Iterator**: Iterator handles traversal; Visitor handles per-type operations during traversal
- **vs Strategy**: Strategy swaps one algorithm; Visitor defines N type-specific operations in one object
- **Python singledispatch alternative**: `@functools.singledispatch` provides Visitor-like dispatch without `accept()` intrusion
- **Real uses**: AST compilers (type checker + code generator), document export (HTML/PDF/XML), query plan optimisers, tax calculators
