# Chapter 21: Behavioral — Memento

## Summary
Memento captures and externalises an object's internal state — without violating encapsulation —
so the object can be restored to that state later. The pattern separates "what to remember"
(Originator's internal state) from "who remembers it" (Caretaker), keeping the snapshot
opaque to everything except the Originator that created it. The canonical use case is
undo/redo where the Command pattern manages the operation history but Memento provides the
state snapshots. It also powers game save states, transaction rollback, and configuration
checkpointing.

## Key Principles
- **Originator**: The object whose state is saved. Only it knows how to create and restore from a Memento.
- **Memento**: An opaque snapshot of the Originator's state. The Caretaker can store it but cannot inspect or edit it.
- **Caretaker**: Manages the Memento stack (undo history). Asks the Originator to create/restore Mementos.
- **Encapsulation preserved**: The Memento exposes no setters or getters to the Caretaker — it's a black box.
- **vs Command**: Command stores the *operation* needed to undo; Memento stores the *state* before the operation. Use together for full undo/redo.

## Python Example

```python
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional
import copy

# ❌ Bad: Saving state by exposing internals — breaks encapsulation
class EditorBad:
    def __init__(self):
        self.text = ""
        self.cursor = 0
        self.font = "Arial"
        # Caretaker must know all three fields to save/restore state
        # Any internal field change = caretaker update required


# ✅ Good: Memento pattern

@dataclass(frozen=True)
class EditorMemento:
    """
    Opaque snapshot — Caretaker stores these but cannot read their internals.
    frozen=True enforces immutability; only Editor can create/consume these.
    """
    _text: str
    _cursor: int
    _font: str


class TextEditor:
    """Originator — creates and restores Mementos."""

    def __init__(self) -> None:
        self._text: str = ""
        self._cursor: int = 0
        self._font: str = "Arial"

    def type(self, text: str) -> None:
        self._text = self._text[:self._cursor] + text + self._text[self._cursor:]
        self._cursor += len(text)

    def set_font(self, font: str) -> None:
        self._font = font

    def move_cursor(self, position: int) -> None:
        self._cursor = max(0, min(position, len(self._text)))

    @property
    def text(self) -> str:
        return self._text

    def save(self) -> EditorMemento:
        """Create an opaque snapshot of current state."""
        return EditorMemento(
            _text=self._text,
            _cursor=self._cursor,
            _font=self._font,
        )

    def restore(self, memento: EditorMemento) -> None:
        """Restore state from snapshot — only Originator can read Memento fields."""
        # We access private-by-convention fields because we're the Originator
        self._text = memento._text
        self._cursor = memento._cursor
        self._font = memento._font


class EditorHistory:
    """Caretaker — manages the undo/redo stack of Mementos."""

    def __init__(self, editor: TextEditor) -> None:
        self._editor = editor
        self._history: list[EditorMemento] = []
        self._redo_stack: list[EditorMemento] = []

    def backup(self) -> None:
        """Save current state before a change."""
        self._history.append(self._editor.save())
        self._redo_stack.clear()

    def undo(self) -> bool:
        if not self._history:
            return False
        self._redo_stack.append(self._editor.save())
        self._editor.restore(self._history.pop())
        return True

    def redo(self) -> bool:
        if not self._redo_stack:
            return False
        self._history.append(self._editor.save())
        self._editor.restore(self._redo_stack.pop())
        return True


# Usage
editor  = TextEditor()
history = EditorHistory(editor)

history.backup()
editor.type("Hello")
assert editor.text == "Hello"

history.backup()
editor.type(", World")
assert editor.text == "Hello, World"

history.backup()
editor.set_font("Courier")

history.undo()
assert editor.text == "Hello, World"
assert editor._font == "Arial"  # font change undone

history.undo()
assert editor.text == "Hello"

history.redo()
assert editor.text == "Hello, World"


# ── Lightweight variant: dict snapshot (for simple objects) ───────────────

@dataclass
class GameCharacter:
    name: str
    hp: int
    position: tuple[int, int]
    inventory: list[str] = field(default_factory=list)

    def save_state(self) -> dict:
        return copy.deepcopy(self.__dict__)  # shallow fields + deep mutable ones

    def load_state(self, state: dict) -> None:
        self.__dict__.update(copy.deepcopy(state))


hero = GameCharacter("Hasanul", 100, (0, 0), ["sword"])
checkpoint = hero.save_state()

hero.hp = 30
hero.position = (50, 80)
hero.inventory.append("shield")

hero.load_state(checkpoint)
assert hero.hp == 100
assert hero.position == (0, 0)
assert "shield" not in hero.inventory
```

## Quick Reference
- **Intent**: Capture and restore an object's state without exposing its internals
- **Originator**: Creates the Memento (`save()`); restores from it (`restore(memento)`)
- **Memento**: Immutable snapshot (`@dataclass(frozen=True)`); opaque to Caretaker
- **Caretaker**: Maintains undo/redo stacks of Mementos; never reads their contents
- **Encapsulation**: Memento's fields are private-by-convention; only Originator accesses them
- **vs Command undo**: Command stores the *inverse operation*; Memento stores the *prior state* — Memento is simpler for complex state graphs
- **Memory cost**: Each snapshot is a full state copy — consider incremental snapshots for large objects
- **Deep copy**: Use `copy.deepcopy` for mutable nested state to prevent snapshot corruption
- **Real uses**: Text editor undo, game save/checkpoint, database transaction rollback, config restore
