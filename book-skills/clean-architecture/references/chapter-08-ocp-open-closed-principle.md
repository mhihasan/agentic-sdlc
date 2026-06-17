# Chapter 8: OCP — The Open-Closed Principle

## Summary
Systems should be open for extension but closed for modification. New behaviour is added by writing new code, not by editing existing tested code. Martin frames this as the primary goal of good architecture: high-level policy components must be *protected from* changes in low-level detail components. The mechanism is unidirectional dependency hierarchies — details depend on policy, never the reverse.

## Key Principles
- **Extend via new code**: Adding behaviour means adding modules, not editing existing ones.
- **Protect high-level components**: The more important a component, the more it must be shielded from change.
- **Dependency direction enforces it**: If high-level policy never imports low-level details, changes in details can never break policy.

## Python Example — Three Pythonic Ways to Achieve OCP

```python
# ❌ Bad: Every new format requires editing the existing function
def generate_report(data: list, fmt: str) -> str:
    if fmt == "html":
        return f"<html>{data}</html>"
    elif fmt == "csv":
        return ",".join(str(d) for d in data)
    elif fmt == "pdf":          # adding this required editing working code
        return render_pdf(data)
    # Every new format = modification risk to existing, tested code
```

```python
# ✅ Way 1: Protocol + callables (most Pythonic for simple cases)
from typing import Protocol, Callable

# A formatter is just a callable — no class needed
Formatter = Callable[[list], str]

def html_formatter(data: list) -> str:
    return f"<html>{data}</html>"

def csv_formatter(data: list) -> str:
    return ",".join(str(d) for d in data)

def generate_report(data: list, formatter: Formatter) -> str:
    return formatter(data)         # closed for modification

# Adding PDF: write a new function. Touch nothing else.
def pdf_formatter(data: list) -> str:
    return render_pdf(data)

# Usage: generate_report(data, pdf_formatter)
```

```python
# ✅ Way 2: Protocol for richer formatters with state
from typing import Protocol

class ReportFormatter(Protocol):
    def format(self, data: list) -> str: ...
    def content_type(self) -> str: ...      # formatters with multiple methods

class HtmlFormatter:
    def format(self, data: list) -> str:
        return f"<html>{data}</html>"
    def content_type(self) -> str:
        return "text/html"

class CsvFormatter:
    def format(self, data: list) -> str:
        return ",".join(str(d) for d in data)
    def content_type(self) -> str:
        return "text/csv"

class ReportGenerator:                     # closed: never changes for new formats
    def generate(self, data: list, formatter: ReportFormatter) -> tuple[str, str]:
        return formatter.format(data), formatter.content_type()
```

```python
# ✅ Way 3: functools.singledispatch for type-based extension (truly open/closed)
from functools import singledispatch
from dataclasses import dataclass

@dataclass
class HtmlRequest: data: list
@dataclass
class CsvRequest: data: list
@dataclass
class PdfRequest: data: list

@singledispatch
def render(request) -> str:
    raise NotImplementedError(f"No renderer for {type(request)}")

@render.register
def _(req: HtmlRequest) -> str:
    return f"<html>{req.data}</html>"

@render.register
def _(req: CsvRequest) -> str:
    return ",".join(str(d) for d in req.data)

# Adding PDF: register a new handler. render() itself is never modified.
@render.register
def _(req: PdfRequest) -> str:
    return render_pdf(req.data)
```

## Quick Reference
- OCP = new behaviour via new code, never edits to existing tested code
- Python tools: `Callable` type alias, `Protocol`, `functools.singledispatch`
- Dependency direction: details (new formatters) depend on policy (generate_report), never reversed
- High-level policy must never import the low-level extension modules
