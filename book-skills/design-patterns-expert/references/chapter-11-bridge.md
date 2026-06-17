# Chapter 11: Structural — Bridge

## Summary
Bridge splits a large class or a set of closely related classes into two separate hierarchies —
abstraction and implementation — that can vary independently. Without Bridge, adding a new
dimension (e.g., a new platform or a new shape type) causes a combinatorial explosion of
subclasses: `CircleOnWindows`, `CircleOnMac`, `SquareOnWindows`, `SquareOnMac`, etc.
Bridge solves this by extracting one dimension (the "implementation") into a separate class
hierarchy that the "abstraction" references via composition. The result: M abstractions ×
N implementations require only M + N classes instead of M × N.

## Key Principles
- **Abstraction**: High-level control layer. Delegates platform/implementation work to the Implementation object it holds.
- **Implementation**: Interface for platform-specific or variant work. Multiple concrete implementations exist.
- **Composition over inheritance**: Abstraction holds an Implementation reference — this is the "bridge."
- **Independent variation**: Add a new platform by adding a new Implementor; add a new shape by adding a new Abstraction — neither requires touching the other.
- **When to use**: When a class has two or more orthogonal dimensions of variation (shape + renderer, device + remote, notification + channel).

## Python Example

```python
from typing import Protocol
from dataclasses import dataclass

# ❌ Bad: Combinatorial explosion — one class per (shape, renderer) pair
class CircleVectorRenderer: ...
class CircleRasterRenderer: ...
class SquareVectorRenderer: ...
class SquareRasterRenderer: ...
# Adding Triangle requires 2 more classes; adding a new renderer requires N more


# ✅ Good: Bridge pattern

# Implementation interface — rendering "platform"
class Renderer(Protocol):
    def render_circle(self, x: float, y: float, radius: float) -> str: ...
    def render_square(self, x: float, y: float, side: float) -> str: ...


# Concrete Implementations
class VectorRenderer:
    def render_circle(self, x, y, radius) -> str:
        return f"Drawing circle at ({x},{y}) r={radius} [SVG path]"

    def render_square(self, x, y, side) -> str:
        return f"Drawing square at ({x},{y}) s={side} [SVG rect]"


class RasterRenderer:
    def render_circle(self, x, y, radius) -> str:
        return f"Drawing circle at ({x},{y}) r={radius} [pixel fill]"

    def render_square(self, x, y, side) -> str:
        return f"Drawing square at ({x},{y}) s={side} [pixel grid]"


# Abstraction — shape hierarchy
@dataclass
class Shape:
    renderer: Renderer  # the bridge

    def draw(self) -> str:
        raise NotImplementedError

    def resize(self, factor: float) -> None:
        raise NotImplementedError


@dataclass
class Circle(Shape):
    x: float
    y: float
    radius: float

    def draw(self) -> str:
        return self.renderer.render_circle(self.x, self.y, self.radius)

    def resize(self, factor: float) -> None:
        self.radius *= factor


@dataclass
class Square(Shape):
    x: float
    y: float
    side: float

    def draw(self) -> str:
        return self.renderer.render_square(self.x, self.y, self.side)

    def resize(self, factor: float) -> None:
        self.side *= factor


# Client: mix any shape with any renderer — only M+N classes, not M×N
vector = VectorRenderer()
raster = RasterRenderer()

c1 = Circle(vector, 5.0, 5.0, 10.0)
c2 = Circle(raster, 5.0, 5.0, 10.0)
s1 = Square(vector, 0.0, 0.0, 20.0)

assert "SVG path" in c1.draw()
assert "pixel fill" in c2.draw()
assert "SVG rect" in s1.draw()

c1.resize(2)
assert c1.radius == 20.0

# Adding a new renderer (Canvas3D) requires zero changes to Circle or Square
class Canvas3DRenderer:
    def render_circle(self, x, y, radius) -> str:
        return f"Drawing 3D circle at ({x},{y}) r={radius}"
    def render_square(self, x, y, side) -> str:
        return f"Drawing 3D square at ({x},{y}) s={side}"

c3 = Circle(Canvas3DRenderer(), 1.0, 1.0, 5.0)
assert "3D circle" in c3.draw()
```

## Quick Reference
- **Intent**: Decouple abstraction from implementation so both can vary independently
- **Use when**: A class has two or more orthogonal dimensions (shape×renderer, device×remote)
- **Bridge via composition**: `Abstraction.__init__` receives an `Implementor` — the bridge is the field reference
- **Combinatorial explosion signal**: You find yourself naming classes `ConceptAPlatform1`, `ConceptAPlatform2`...
- **vs Adapter**: Adapter makes incompatible interfaces work together (after the fact); Bridge is designed upfront to separate concerns
- **vs Strategy**: Strategy swaps algorithms within one class; Bridge separates two entire hierarchies
- **vs Abstract Factory**: Abstract Factory can *create* Bridge implementations; they're complementary
- **Real uses**: GUI toolkits (widget + platform), logging (logger + handler), notification (channel + formatter)
