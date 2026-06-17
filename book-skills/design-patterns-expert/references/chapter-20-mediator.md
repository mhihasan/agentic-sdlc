# Chapter 20: Behavioral — Mediator

## Summary
Mediator reduces chaotic dependencies between many communicating objects (components) by
introducing a central hub (the mediator) that routes all communication. Instead of components
talking to each other directly — creating O(n²) dependency links — every component knows
only the mediator interface, resulting in O(n) dependencies. The Mediator pattern is most
useful in UI forms (components notify the mediator; the mediator decides which other
components to update), air traffic control systems, and service coordination layers.
The mediator absorbs all coordination logic, keeping each component focused on its own job.

## Key Principles
- **Central communication hub**: All inter-component messages go through the mediator; components never import or reference each other.
- **Mediator knows all components**: The mediator holds references to components and orchestrates their interactions.
- **Components are self-contained**: Each component knows only the mediator interface, not its siblings.
- **O(n) vs O(n²)**: n components with direct links = n(n-1)/2 connections; with mediator = n connections.
- **vs Facade**: Facade simplifies an interface to a subsystem; Mediator coordinates two-way communication between subsystem objects.

## Python Example

```python
from __future__ import annotations
from typing import Protocol, Optional
from dataclasses import dataclass

# ❌ Bad: Each UI component holds references to every other component it affects
class CheckboxBad:
    def __init__(self, textbox, button, label):
        self._textbox = textbox  # direct coupling to siblings
        self._button = button
        self._label = label

    def toggle(self, checked: bool):
        self._textbox.set_enabled(checked)
        self._button.set_enabled(checked)
        self._label.set_text("Enabled" if checked else "Disabled")
# Adding a 4th component requires modifying Checkbox


# ✅ Good: Mediator pattern

class Mediator(Protocol):
    def notify(self, sender: object, event: str) -> None: ...


class Component:
    """Base component — knows only the mediator."""
    def __init__(self) -> None:
        self._mediator: Optional[Mediator] = None

    def set_mediator(self, mediator: Mediator) -> None:
        self._mediator = mediator


class Checkbox(Component):
    def __init__(self) -> None:
        super().__init__()
        self.checked: bool = False

    def toggle(self) -> None:
        self.checked = not self.checked
        if self._mediator:
            self._mediator.notify(self, "toggle")


class TextInput(Component):
    def __init__(self) -> None:
        super().__init__()
        self.enabled: bool = False
        self.value: str = ""

    def set_enabled(self, enabled: bool) -> None:
        self.enabled = enabled

    def set_text(self, text: str) -> None:
        if self.enabled:
            self.value = text


class SubmitButton(Component):
    def __init__(self) -> None:
        super().__init__()
        self.enabled: bool = False

    def set_enabled(self, enabled: bool) -> None:
        self.enabled = enabled

    def click(self) -> Optional[str]:
        if not self.enabled:
            return None
        if self._mediator:
            self._mediator.notify(self, "click")
        return "submitted"


# Mediator holds all coordination logic
class FormMediator:
    def __init__(
        self,
        checkbox: Checkbox,
        text_input: TextInput,
        submit_btn: SubmitButton,
    ) -> None:
        self._checkbox = checkbox
        self._text_input = text_input
        self._submit_btn = submit_btn

        for component in (checkbox, text_input, submit_btn):
            component.set_mediator(self)

    def notify(self, sender: object, event: str) -> None:
        if sender is self._checkbox and event == "toggle":
            enabled = self._checkbox.checked
            self._text_input.set_enabled(enabled)
            self._submit_btn.set_enabled(enabled)
        elif sender is self._submit_btn and event == "click":
            print(f"[Form submitted] value={self._text_input.value}")


# Wiring
chk  = Checkbox()
inp  = TextInput()
btn  = SubmitButton()
form = FormMediator(chk, inp, btn)

# Initially disabled
assert inp.enabled is False
assert btn.enabled is False

# Toggle checkbox — mediator enables siblings
chk.toggle()
assert inp.enabled is True
assert btn.enabled is True

inp.set_text("hasanul@example.com")
result = btn.click()
assert result == "submitted"

# Toggle off — mediator disables siblings
chk.toggle()
assert inp.enabled is False
assert btn.enabled is False


# ── Event-bus variant (loose mediator) ───────────────────────────────────

from collections import defaultdict
from typing import Callable, Any

class EventBus:
    """Loose mediator — components communicate via named events."""
    def __init__(self) -> None:
        self._listeners: dict[str, list[Callable]] = defaultdict(list)

    def subscribe(self, event: str, callback: Callable) -> None:
        self._listeners[event].append(callback)

    def publish(self, event: str, data: Any = None) -> None:
        for cb in self._listeners[event]:
            cb(data)


bus = EventBus()
received: list[str] = []

bus.subscribe("user.created", lambda d: received.append(f"email:{d['email']}"))
bus.subscribe("user.created", lambda d: received.append(f"audit:{d['id']}"))
bus.publish("user.created", {"id": 1, "email": "alice@example.com"})

assert "email:alice@example.com" in received
assert "audit:1" in received
```

## Quick Reference
- **Intent**: Centralise communication between many objects to reduce O(n²) coupling to O(n)
- **Use when**: Objects communicate in complex ways; direct references create a dependency web
- **Components → mediator**: Components only call `mediator.notify(self, event)` — no sibling refs
- **Mediator → components**: Mediator holds references to all components; decides who to update
- **Event bus variant**: Loose coupling via named events; mediator is implicit (the bus)
- **vs Observer**: Observer is one-to-many; Mediator is many-to-many via a central hub
- **vs Facade**: Facade is one-way (client → subsystem); Mediator is two-way coordination
- **Cost**: Mediator becomes a "God class" if coordination logic grows unbounded — split by domain
- **Real uses**: UI form coordinators, air traffic control, chat room servers, Django signals, AWS EventBridge
