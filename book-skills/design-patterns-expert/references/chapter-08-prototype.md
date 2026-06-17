# Chapter 8: Creational — Prototype

## Summary
Prototype creates new objects by cloning an existing instance (the prototype) rather than
instantiating a class from scratch. This is valuable when object creation is expensive
(heavy initialisation, network calls, deep configuration) or when the exact class to
instantiate is unknown at design time. The pattern delegates the copy logic to the object
itself via a `clone()` method, allowing each subclass to control how deep the copy goes.
Python's `copy.copy` (shallow) and `copy.deepcopy` (deep) are direct language-level
implementations of the Prototype pattern.

## Key Principles
- **Clone vs new**: Use Prototype when construction is expensive or configuration-heavy; cloning preserves the costly setup.
- **Deep vs shallow copy**: Shallow clone shares nested objects; deep clone creates fully independent duplicates. Know which you need.
- **Prototype registry**: Store named prototypes in a registry; clients request clones by name without knowing concrete classes.
- **Subclass-controlled copy**: Each class overrides `__copy__`/`__deepcopy__` to define what "copying" means for it.
- **Decouples client from class**: Client calls `prototype.clone()` — never `ConcreteClass()` — so the concrete type is invisible.

## Python Example

```python
import copy
from dataclasses import dataclass, field
from typing import Any

# ❌ Bad: Client knows concrete class and re-does expensive setup for each copy
class MonsterBad:
    def __init__(self):
        self.hp = 100
        self.abilities = []
        self._load_ai()        # expensive: parses AI behaviour tree
        self._load_textures()  # expensive: loads sprite sheet

    def _load_ai(self): pass
    def _load_textures(self): pass

# Every new enemy reruns the expensive setup — no sharing of pre-built state


# ✅ Good: Prototype pattern — clone a pre-configured prototype

@dataclass
class Monster:
    name: str
    hp: int
    abilities: list[str] = field(default_factory=list)
    position: list[int] = field(default_factory=lambda: [0, 0])

    def clone(self) -> "Monster":
        """Deep copy — abilities and position are independent in each clone."""
        return copy.deepcopy(self)

    def __copy__(self) -> "Monster":
        """Shallow copy for cases where shared ability list is intentional."""
        return Monster(self.name, self.hp, self.abilities, list(self.position))

# Build the "master prototype" once (expensive loading happens here)
orc_prototype = Monster(name="Orc Warrior", hp=150, abilities=["axe_swing", "war_cry"])

# Stamp out cheap clones — no re-initialisation needed
orc1 = orc_prototype.clone()
orc2 = orc_prototype.clone()
orc1.position = [10, 20]
orc2.position = [30, 40]
orc1.hp = 120  # wounded orc

# Prototypes are independent
assert orc1.position != orc2.position
assert orc1.hp == 120
assert orc_prototype.hp == 150  # original unchanged

# Each clone's abilities list is independent (deep copy)
orc1.abilities.append("berserk")
assert "berserk" not in orc2.abilities


# ── Prototype Registry ────────────────────────────────────────────────────

class MonsterRegistry:
    def __init__(self) -> None:
        self._prototypes: dict[str, Monster] = {}

    def register(self, key: str, prototype: Monster) -> None:
        self._prototypes[key] = prototype

    def create(self, key: str) -> Monster:
        proto = self._prototypes.get(key)
        if proto is None:
            raise KeyError(f"No prototype registered for '{key}'")
        return proto.clone()


registry = MonsterRegistry()
registry.register("orc_warrior", Monster("Orc Warrior", 150, ["axe_swing"]))
registry.register("goblin_scout", Monster("Goblin Scout", 60, ["stealth"]))

enemy1 = registry.create("orc_warrior")
enemy2 = registry.create("goblin_scout")

assert enemy1.name == "Orc Warrior"
assert enemy2.name == "Goblin Scout"
assert enemy1 is not enemy2  # independent instances


# ── Python built-in support ───────────────────────────────────────────────
import copy

@dataclass
class Config:
    db_host: str
    pool_size: int
    tags: list[str]

base_config = Config("prod-db", 10, ["app", "backend"])
test_config = copy.deepcopy(base_config)
test_config.db_host = "test-db"
test_config.tags.append("test")

assert base_config.db_host == "prod-db"      # unchanged
assert "test" not in base_config.tags         # independent list
```

## Quick Reference
- **Intent**: Create objects by cloning an existing prototype instead of calling constructors
- **Use when**: Object construction is expensive, exact class is unknown, or many similar objects are needed
- **`copy.copy()`**: Shallow clone — nested objects are shared references
- **`copy.deepcopy()`**: Deep clone — fully independent duplicate; safer for mutable state
- **`__copy__` / `__deepcopy__`**: Override to control copy behaviour in custom classes
- **Prototype Registry**: Dict of named prototypes; clients call `registry.create("key")`
- **vs Builder**: Builder assembles from parts; Prototype duplicates from existing state
- **vs Factory Method**: Factory calls constructors; Prototype calls clone — no class knowledge needed
- **Real uses**: Game enemies, test fixtures, document templates, cached expensive configurations
