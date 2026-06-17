# Chapter 18: Behavioral — Command

## Summary
Command encapsulates a request as an object, thereby enabling: parameterisation of clients
with different requests, queuing or logging requests, and undoable operations. A Command
object bundles the action (what to do), the receiver (who does it), and the parameters
(with what data) into a single portable unit. The invoker — button, scheduler, queue
consumer — knows only that it calls `execute()`. This decouples the UI/trigger layer from
the business logic entirely. The pattern is the canonical solution for undo/redo, job queues,
transactional command logging, and macro recording.

## Key Principles
- **Command interface**: A single `execute()` method (and optionally `undo()`).
- **Receiver**: The object that knows how to perform the actual work.
- **Invoker**: Calls `execute()` on commands without knowing what they do.
- **Concrete Command**: Binds a specific Receiver + operation + parameters into one object.
- **Undo/Redo**: Commands store the state needed to reverse their action in `undo()`.

## Python Example

```python
from __future__ import annotations
from typing import Protocol
from dataclasses import dataclass, field
from collections import deque

# ❌ Bad: Button knows about every possible action it might trigger
class SaveButtonBad:
    def __init__(self, editor):
        self._editor = editor
    def click(self):
        self._editor.save_to_disk()  # tightly coupled — a new button = new coupling

class CopyButtonBad:
    def __init__(self, editor, clipboard):
        self._editor = editor
        self._clipboard = clipboard
    def click(self):
        self._clipboard.write(self._editor.get_selection())


# ✅ Good: Command pattern

class Command(Protocol):
    def execute(self) -> None: ...
    def undo(self) -> None: ...


# Receiver — performs the actual document operations
class TextEditor:
    def __init__(self, text: str = "") -> None:
        self.text = text
        self._clipboard: str = ""

    def insert(self, position: int, content: str) -> None:
        self.text = self.text[:position] + content + self.text[position:]

    def delete(self, position: int, length: int) -> None:
        self.text = self.text[:position] + self.text[position + length:]

    def copy_selection(self, start: int, end: int) -> None:
        self._clipboard = self.text[start:end]

    def paste(self, position: int) -> None:
        self.insert(position, self._clipboard)


# Concrete Commands
@dataclass
class InsertCommand:
    _editor: TextEditor
    _position: int
    _content: str

    def execute(self) -> None:
        self._editor.insert(self._position, self._content)

    def undo(self) -> None:
        self._editor.delete(self._position, len(self._content))


@dataclass
class DeleteCommand:
    _editor: TextEditor
    _position: int
    _length: int
    _deleted_text: str = field(default="", init=False)

    def execute(self) -> None:
        self._deleted_text = self._editor.text[self._position:self._position + self._length]
        self._editor.delete(self._position, self._length)

    def undo(self) -> None:
        self._editor.insert(self._position, self._deleted_text)


# Invoker — button, shortcut handler, scheduler — knows only Command.execute()
class CommandHistory:
    def __init__(self) -> None:
        self._history: deque[Command] = deque()
        self._redo_stack: deque[Command] = deque()

    def execute(self, cmd: Command) -> None:
        cmd.execute()
        self._history.append(cmd)
        self._redo_stack.clear()  # new command invalidates redo stack

    def undo(self) -> None:
        if not self._history:
            return
        cmd = self._history.pop()
        cmd.undo()
        self._redo_stack.append(cmd)

    def redo(self) -> None:
        if not self._redo_stack:
            return
        cmd = self._redo_stack.pop()
        cmd.execute()
        self._history.append(cmd)


# Usage
editor = TextEditor("Hello World")
history = CommandHistory()

history.execute(InsertCommand(editor, 5, ","))
assert editor.text == "Hello, World"

history.execute(InsertCommand(editor, 13, "!"))
assert editor.text == "Hello, World!"

history.undo()
assert editor.text == "Hello, World"

history.undo()
assert editor.text == "Hello World"

history.redo()
assert editor.text == "Hello, World"


# ── Queue-based job dispatch (Command as task unit) ───────────────────────

class EmailCommand:
    def __init__(self, to: str, subject: str, body: str) -> None:
        self._to = to
        self._subject = subject
        self._body = body

    def execute(self) -> None:
        print(f"[Email] To: {self._to} | Subject: {self._subject}")

    def undo(self) -> None:
        print(f"[Email] Cannot unsend to {self._to}")  # no-op


job_queue: list[Command] = [
    EmailCommand("alice@example.com", "Welcome", "Hi Alice!"),
    EmailCommand("bob@example.com", "Invoice", "Please pay..."),
]

for job in job_queue:
    job.execute()
```

## Quick Reference
- **Intent**: Encapsulate a request as an object with `execute()` and optionally `undo()`
- **Use when**: Need undo/redo, job queues, request logging, macro recording, or deferred execution
- **Invoker**: Stores and calls commands without knowing their implementation (`history.execute(cmd)`)
- **Receiver**: Does the actual work; Command holds a reference to it
- **Undo state**: Command saves pre-execution state in `execute()`; restores it in `undo()`
- **vs Strategy**: Strategy swaps algorithms; Command encapsulates a one-shot action as an object
- **vs Chain of Responsibility**: CoR passes until someone handles; Command routes to a specific receiver
- **Python callable alternative**: For simple cases with no undo, `Callable[[], None]` can replace a Command class
- **Real uses**: Text editor undo/redo, Celery tasks, database migration runners, GUI button handlers, AWS Lambda async invocation
