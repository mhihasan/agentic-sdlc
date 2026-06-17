# Chapter 6: Creational — Abstract Factory

## Summary
Abstract Factory produces families of related objects without specifying their concrete classes.
Where Factory Method creates one product, Abstract Factory creates an entire suite of products
that must be used together (e.g., Button + Checkbox + Dialog for a given UI theme). The factory
interface declares creation methods for each product in the family; concrete factories implement
those methods for a specific variant. The client receives a factory and calls it — never knowing
which theme or platform it's working with. The pattern is the right tool whenever a system must
be independent of how its products are created, composed, and represented.

## Key Principles
- **Product families**: Multiple related products that must be used consistently (Mac widgets together, Windows widgets together).
- **Factory interface**: Declares one creation method per product type; concrete factories implement for each variant.
- **Client isolation**: Client code depends only on abstract product interfaces and the abstract factory — no concrete imports.
- **Consistency guarantee**: Using one factory ensures all created objects belong to the same family (no Mac button with Windows dialog).
- **Extension cost**: Adding a new product type requires changing the abstract factory interface and all concrete factories — plan product families carefully upfront.

## Python Example

```python
from typing import Protocol
from dataclasses import dataclass

# ❌ Bad: UI code checks OS at every widget creation — scattered branching
def render_ui_bad(os: str) -> None:
    if os == "mac":
        btn = MacButton()
        chk = MacCheckbox()
    else:
        btn = WinButton()
        chk = WinCheckbox()
    # must duplicate this everywhere a widget is needed


# ✅ Good: Abstract Factory pattern

# Abstract Products
class Button(Protocol):
    def render(self) -> str: ...
    def on_click(self) -> str: ...

class Checkbox(Protocol):
    def render(self) -> str: ...
    def toggle(self) -> str: ...

# Abstract Factory
class UIFactory(Protocol):
    def create_button(self) -> Button: ...
    def create_checkbox(self) -> Checkbox: ...


# ── Mac family ─────────────────────────────────────────────────────────────
class MacButton:
    def render(self) -> str: return "[Mac Button]"
    def on_click(self) -> str: return "Mac click ripple"

class MacCheckbox:
    def render(self) -> str: return "[Mac ☑]"
    def toggle(self) -> str: return "Mac smooth toggle"

class MacFactory:
    def create_button(self) -> Button: return MacButton()
    def create_checkbox(self) -> Checkbox: return MacCheckbox()


# ── Windows family ─────────────────────────────────────────────────────────
class WinButton:
    def render(self) -> str: return "[Win Button]"
    def on_click(self) -> str: return "Win click"

class WinCheckbox:
    def render(self) -> str: return "[Win □]"
    def toggle(self) -> str: return "Win checkbox toggle"

class WinFactory:
    def create_button(self) -> Button: return WinButton()
    def create_checkbox(self) -> Checkbox: return WinCheckbox()


# ── Client — depends only on UIFactory + abstract products ─────────────────
class Application:
    def __init__(self, factory: UIFactory) -> None:
        self._button = factory.create_button()
        self._checkbox = factory.create_checkbox()

    def render(self) -> list[str]:
        return [self._button.render(), self._checkbox.render()]


# Factory selected once at startup (e.g., from config)
import platform

def get_factory() -> UIFactory:
    return MacFactory() if platform.system() == "Darwin" else WinFactory()

app = Application(MacFactory())
output = app.render()
assert "[Mac Button]" in output
assert "[Mac ☑]" in output

app2 = Application(WinFactory())
assert "[Win Button]" in app2.render()


# ── Adding a new family (Dark Mode) — zero changes to Application ──────────
class DarkButton:
    def render(self) -> str: return "[◼ Dark Button]"
    def on_click(self) -> str: return "Dark ripple"

class DarkCheckbox:
    def render(self) -> str: return "[◼ ☑]"
    def toggle(self) -> str: return "Dark toggle"

class DarkThemeFactory:
    def create_button(self) -> Button: return DarkButton()
    def create_checkbox(self) -> Checkbox: return DarkCheckbox()

app3 = Application(DarkThemeFactory())
assert "Dark Button" in app3.render()[0]
```

## Quick Reference
- **Intent**: Create families of related objects without specifying concrete classes
- **Use when**: System must be independent of product creation, and products must be used in consistent families
- **Structure**: `AbstractFactory` (Protocol) → `ConcreteFactory` per family → `AbstractProduct` per type
- **Consistency guarantee**: One factory = guaranteed family consistency; mixing factories causes inconsistency
- **vs Factory Method**: Factory Method creates one product type; Abstract Factory creates a whole family
- **Extension cost**: New product *type* = breaking change to factory interface. New product *family* = just a new factory.
- **Python idiom**: `Protocol` for both factory and products — no forced inheritance on concrete classes
- **Real uses**: GUI toolkits (Qt themes), database abstraction (PostgreSQL vs SQLite backends), cloud provider SDKs
