# Chapter 12: Structural — Composite

## Summary
Composite lets clients treat individual objects and compositions of objects uniformly through
a shared interface. It models part-whole hierarchies as a tree: leaf nodes do real work,
composite nodes delegate to their children and aggregate results. The canonical examples are
file systems (files and folders), UI component trees (buttons and panels), and document
structures (words, paragraphs, sections). The power of the pattern is that the client never
needs to know whether it's operating on a single leaf or a deeply nested tree — it calls the
same interface on both.

## Key Principles
- **Component interface**: Shared interface that both Leaf and Composite implement.
- **Leaf**: Has no children; performs actual work when the operation is called.
- **Composite**: Holds child Components; implements operations by delegating to children and aggregating.
- **Uniform treatment**: Client code calls `component.operation()` without knowing if it's a leaf or a subtree.
- **Recursive structure**: Composites can contain other Composites, enabling arbitrarily deep trees.

## Python Example

```python
from __future__ import annotations
from typing import Protocol
from dataclasses import dataclass, field

# ❌ Bad: Client must check type and recurse manually
def calculate_total_bad(item) -> float:
    if isinstance(item, dict) and "children" in item:
        return sum(calculate_total_bad(c) for c in item["children"])
    elif isinstance(item, dict):
        return item["price"]
    return 0.0  # fragile, coupled to dict structure


# ✅ Good: Composite pattern

class PricedItem(Protocol):
    def total_price(self) -> float: ...
    def describe(self, indent: int = 0) -> str: ...


@dataclass
class Product:
    """Leaf — no children."""
    name: str
    price: float

    def total_price(self) -> float:
        return self.price

    def describe(self, indent: int = 0) -> str:
        return f"{'  ' * indent}[Product] {self.name}: ${self.price:.2f}"


@dataclass
class Bundle:
    """Composite — holds child PricedItems."""
    name: str
    _children: list[PricedItem] = field(default_factory=list)
    discount: float = 0.0  # e.g. 0.10 for 10% bundle discount

    def add(self, item: PricedItem) -> Bundle:
        self._children.append(item)
        return self  # fluent

    def remove(self, item: PricedItem) -> None:
        self._children.remove(item)

    def total_price(self) -> float:
        subtotal = sum(c.total_price() for c in self._children)
        return subtotal * (1 - self.discount)

    def describe(self, indent: int = 0) -> str:
        lines = [f"{'  ' * indent}[Bundle] {self.name} (discount={self.discount*100:.0f}%)"]
        for child in self._children:
            lines.append(child.describe(indent + 1))
        lines.append(f"{'  ' * (indent+1)}Subtotal: ${self.total_price():.2f}")
        return "\n".join(lines)


# Build a product tree
keyboard = Product("Mechanical Keyboard", 120.0)
mouse    = Product("Wireless Mouse", 60.0)
monitor  = Product("4K Monitor", 400.0)

peripherals = Bundle("Peripherals Bundle", discount=0.05)
peripherals.add(keyboard).add(mouse)

workstation = Bundle("Workstation Setup", discount=0.10)
workstation.add(monitor).add(peripherals)  # composite contains composite

# Client treats everything uniformly
assert keyboard.total_price() == 120.0
assert peripherals.total_price() == (120 + 60) * 0.95  # 171.0
expected_workstation = (400 + (120 + 60) * 0.95) * 0.90
assert abs(workstation.total_price() - expected_workstation) < 0.01

print(workstation.describe())


# ── File system example ───────────────────────────────────────────────────

class FSNode(Protocol):
    def size_bytes(self) -> int: ...
    def path(self) -> str: ...

@dataclass
class File:
    name: str
    _size: int
    _parent_path: str = ""

    def size_bytes(self) -> int: return self._size
    def path(self) -> str: return f"{self._parent_path}/{self.name}"

@dataclass
class Directory:
    name: str
    _parent_path: str = ""
    _children: list[FSNode] = field(default_factory=list)

    def add(self, node: FSNode) -> None:
        self._children.append(node)

    def size_bytes(self) -> int:
        return sum(c.size_bytes() for c in self._children)

    def path(self) -> str: return f"{self._parent_path}/{self.name}"

root = Directory("root")
root.add(File("readme.txt", 1024))
src = Directory("src")
src.add(File("main.py", 4096))
src.add(File("utils.py", 2048))
root.add(src)

assert root.size_bytes() == 1024 + 4096 + 2048
```

## Quick Reference
- **Intent**: Treat individual objects and compositions uniformly via a shared interface
- **Use when**: You need to represent part-whole hierarchies; clients should ignore leaf/composite distinction
- **Leaf**: implements Component — does real work, no children
- **Composite**: implements Component — delegates to children, aggregates results
- **Recursive aggregation**: `total = sum(child.operation() for child in self._children)`
- **Python Protocol**: Avoids forcing `File` and `Directory` to inherit from a common ABC
- **vs Decorator**: Decorator adds behaviour to a single object; Composite aggregates a tree
- **vs Iterator**: Iterator can traverse a Composite tree without the client managing recursion
- **Real uses**: File systems, UI widget trees (React component trees), org charts, XML/HTML DOM, bill of materials
