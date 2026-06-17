# Chapter 25: Behavioral — Template Method

## Summary
Template Method defines the skeleton of an algorithm in a base class, deferring some steps
to subclasses. Subclasses can override specific steps (the "hooks") without changing the
overall algorithm structure. The base class controls the flow — it calls the hooks in order —
and the subclasses provide the specialised implementations. This is the inverse of Strategy:
Strategy composes a whole algorithm from outside; Template Method partially implements an
algorithm inside the base class, letting subclasses fill in the blanks.

## Key Principles
- **Template method**: The algorithm skeleton in the base class. Calls abstract or hook steps in a fixed order.
- **Abstract steps**: Steps that every subclass MUST implement (pure abstract methods).
- **Hook steps**: Steps with a default implementation that subclasses MAY override.
- **Hollywood Principle**: "Don't call us, we'll call you" — base class calls subclass methods, not the other way around.
- **vs Strategy**: Template Method uses inheritance; Strategy uses composition. Prefer Strategy when you need to swap algorithms without subclassing.

## Python Example

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional

# ❌ Bad: Duplicated algorithm skeleton across subclasses — only differences should differ
class CSVReport:
    def generate(self, data: list) -> str:
        # Step 1: validate
        if not data: return ""
        # Step 2: format header
        header = ",".join(data[0].keys())
        # Step 3: format rows (CSV-specific)
        rows = [",".join(str(v) for v in row.values()) for row in data]
        # Step 4: assemble
        return header + "\n" + "\n".join(rows)

class HTMLReport:
    def generate(self, data: list) -> str:
        # Steps 1, 2, 4 are IDENTICAL to CSV — only step 3 differs
        if not data: return ""
        header = "<tr>" + "".join(f"<th>{k}</th>" for k in data[0].keys()) + "</tr>"
        rows = ["<tr>" + "".join(f"<td>{v}</td>" for v in row.values()) + "</tr>" for row in data]
        return "<table>" + header + "".join(rows) + "</table>"


# ✅ Good: Template Method pattern

class ReportGenerator(ABC):
    """Template — defines the algorithm skeleton."""

    def generate(self, data: list[dict]) -> str:
        """Template method — fixed sequence."""
        if not self._validate(data):
            return self._empty_report()
        header = self._format_header(list(data[0].keys()))
        rows   = [self._format_row(list(row.values())) for row in data]
        return self._assemble(header, rows)

    # ── Abstract steps — subclasses MUST implement ────────────────────────
    @abstractmethod
    def _format_header(self, columns: list[str]) -> str: ...

    @abstractmethod
    def _format_row(self, values: list) -> str: ...

    @abstractmethod
    def _assemble(self, header: str, rows: list[str]) -> str: ...

    # ── Hook steps — subclasses MAY override ──────────────────────────────
    def _validate(self, data: list[dict]) -> bool:
        """Default: reject empty data."""
        return bool(data)

    def _empty_report(self) -> str:
        """Default: return empty string."""
        return ""


class CSVReport(ReportGenerator):
    def _format_header(self, columns: list[str]) -> str:
        return ",".join(columns)

    def _format_row(self, values: list) -> str:
        return ",".join(str(v) for v in values)

    def _assemble(self, header: str, rows: list[str]) -> str:
        return header + "\n" + "\n".join(rows)


class HTMLReport(ReportGenerator):
    def _format_header(self, columns: list[str]) -> str:
        cells = "".join(f"<th>{c}</th>" for c in columns)
        return f"<tr>{cells}</tr>"

    def _format_row(self, values: list) -> str:
        cells = "".join(f"<td>{v}</td>" for v in values)
        return f"<tr>{cells}</tr>"

    def _assemble(self, header: str, rows: list[str]) -> str:
        body = header + "".join(rows)
        return f"<table>{body}</table>"


class MarkdownReport(ReportGenerator):
    def _format_header(self, columns: list[str]) -> str:
        header = "| " + " | ".join(columns) + " |"
        sep    = "| " + " | ".join("---" for _ in columns) + " |"
        return header + "\n" + sep

    def _format_row(self, values: list) -> str:
        return "| " + " | ".join(str(v) for v in values) + " |"

    def _assemble(self, header: str, rows: list[str]) -> str:
        return header + "\n" + "\n".join(rows)


data = [
    {"name": "Alice", "score": 95},
    {"name": "Bob",   "score": 87},
]

csv  = CSVReport().generate(data)
html = HTMLReport().generate(data)
md   = MarkdownReport().generate(data)

assert "name,score" in csv
assert "Alice,95" in csv
assert "<table>" in html
assert "<th>name</th>" in html
assert "| name |" in md
assert "| --- |" in md


# ── Hook example: optional pre-/post-processing ───────────────────────────

class DataMiner(ABC):
    def mine(self, path: str) -> dict:
        """Template."""
        raw  = self._extract(path)
        data = self._parse(raw)
        self._analyse(data)           # abstract
        self._send_report(data)       # hook
        return data

    @abstractmethod
    def _extract(self, path: str) -> str: ...

    @abstractmethod
    def _parse(self, raw: str) -> dict: ...

    @abstractmethod
    def _analyse(self, data: dict) -> None: ...

    def _send_report(self, data: dict) -> None:
        """Hook — default does nothing."""
        pass
```

## Quick Reference
- **Intent**: Define algorithm skeleton in base class; subclasses fill in specific steps
- **Template method**: The `generate()` / `mine()` method in the base class — calls steps in fixed order
- **Abstract steps**: `@abstractmethod` — subclasses must override
- **Hook steps**: Concrete methods with default implementation — subclasses *may* override
- **Hollywood Principle**: Base class calls subclass hooks — not the other way
- **vs Strategy**: Template Method = inheritance (IS-A); Strategy = composition (HAS-A). Prefer Strategy for flexibility.
- **vs Factory Method**: Factory Method is a specialised Template Method for object creation
- **Fragile base class risk**: Changing the template method breaks all subclasses — keep it stable
- **Real uses**: Django class-based views (`get()`, `post()`, `dispatch()`), test case `setUp`/`tearDown`, data pipeline stages, report generators
