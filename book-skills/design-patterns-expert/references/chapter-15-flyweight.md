# Chapter 15: Structural — Flyweight

## Summary
Flyweight reduces memory overhead by sharing the intrinsic (immutable, context-independent)
state of objects across many instances, while each instance only stores its unique extrinsic
(context-dependent) state. The pattern is the right tool when you need a very large number
of similar objects and memory is the bottleneck. The shared immutable state is stored in a
Flyweight object; the unique state is passed to its methods at call time. A Flyweight Factory
manages the pool of shared objects, creating them lazily and reusing them on subsequent
requests for the same intrinsic state.

## Key Principles
- **Intrinsic state**: Shared, immutable, context-independent. Stored inside the Flyweight. Example: character glyph, particle sprite.
- **Extrinsic state**: Unique, context-dependent. Passed as a parameter at call time. Example: particle position, character coordinates.
- **Flyweight Factory**: Caches and returns existing Flyweights by intrinsic key; creates new ones only when needed.
- **Immutability requirement**: Flyweights must be immutable — shared state cannot be mutated by one user without affecting all others.
- **Trade-off**: CPU ↑ (extracting extrinsic state, hashing keys) in exchange for RAM ↓. Worthwhile only with thousands+ of instances.

## Python Example

```python
from __future__ import annotations
from dataclasses import dataclass
import sys
from typing import Any

# ❌ Bad: Each particle stores a full copy of sprite data
class ParticleBad:
    def __init__(self, x, y, color, sprite_bytes):
        self.x = x
        self.y = y
        self.color = color
        self.sprite_bytes = sprite_bytes  # 1 MB per particle — 1000 particles = 1 GB

# 1000 * (1 MB sprite + metadata) = ~1 GB RAM for a particle effect


# ✅ Good: Flyweight pattern

@dataclass(frozen=True)  # frozen = immutable = shareable
class ParticleType:
    """Flyweight — intrinsic (shared) state only."""
    color: str
    sprite_key: str

    def render(self, x: float, y: float, velocity: tuple[float, float]) -> str:
        # extrinsic state passed in — never stored here
        vx, vy = velocity
        return (
            f"[{self.color} particle @ ({x:.1f},{y:.1f}) "
            f"v=({vx:.1f},{vy:.1f}) sprite={self.sprite_key}]"
        )


class ParticleTypeFactory:
    """Flyweight Factory — caches shared ParticleType instances."""
    _cache: dict[tuple[str, str], ParticleType] = {}

    @classmethod
    def get(cls, color: str, sprite_key: str) -> ParticleType:
        key = (color, sprite_key)
        if key not in cls._cache:
            cls._cache[key] = ParticleType(color, sprite_key)
            print(f"  [Factory] Created new ParticleType: {key}")
        return cls._cache[key]

    @classmethod
    def cache_size(cls) -> int:
        return len(cls._cache)


@dataclass
class Particle:
    """Context object — stores extrinsic (unique) state only."""
    x: float
    y: float
    velocity: tuple[float, float]
    _type: ParticleType  # reference to shared flyweight

    def render(self) -> str:
        return self._type.render(self.x, self.y, self.velocity)


# Simulate 1000 particles of only 3 types
import random

particles: list[Particle] = []
configs = [
    ("red", "fire_sprite"),
    ("blue", "ice_sprite"),
    ("green", "leaf_sprite"),
]

for _ in range(1000):
    color, sprite = random.choice(configs)
    pt = ParticleTypeFactory.get(color, sprite)  # reuses cached flyweight
    particles.append(
        Particle(
            x=random.uniform(0, 100),
            y=random.uniform(0, 100),
            velocity=(random.uniform(-1, 1), random.uniform(-1, 1)),
            _type=pt,
        )
    )

# 1000 particles but only 3 ParticleType objects in memory
assert ParticleTypeFactory.cache_size() <= 3
print(particles[0].render())


# ── Python interned strings / __slots__ as related optimisations ──────────
# Python's string interning is a built-in flyweight for short strings.
# __slots__ reduces per-instance memory similarly.

class SlottedPoint:
    """~40% less RAM per instance than a regular class with __dict__."""
    __slots__ = ("x", "y")

    def __init__(self, x: float, y: float) -> None:
        self.x = x
        self.y = y
```

## Quick Reference
- **Intent**: Share intrinsic (immutable) state across thousands of objects to reduce memory
- **Use when**: Huge numbers of similar objects; memory is the bottleneck; most state is shared
- **Intrinsic**: immutable, shared → stored in Flyweight (`@dataclass(frozen=True)`)
- **Extrinsic**: unique, context-dependent → passed to Flyweight methods as parameters
- **Factory**: dict-based cache `{intrinsic_key: flyweight}` — create once, reuse many times
- **Immutability is mandatory**: shared state mutated by one client corrupts all others
- **Cost**: slightly more CPU complexity; only worthwhile at scale (thousands of instances)
- **Python built-ins**: `sys.intern()` for strings, `__slots__` for memory-efficient classes
- **Real uses**: Game particle engines, font glyph renderers, icon caches, DOM node style sheets
