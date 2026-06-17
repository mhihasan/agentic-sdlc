# Chapter 24: Partial Boundaries

## Summary
Full architectural boundaries — defined Protocols, separate packages, DIP fully implemented on both sides — are expensive to build and maintain. Three partial boundary strategies let you invest incrementally based on evidence, not speculation: (1) build the infrastructure, deploy as one; (2) one-dimensional Protocol (only the calling side abstracts); (3) Facade (hides complexity, no DIP). Use partial boundaries when the cost of a full boundary is not yet justified by evidence of need.

## Key Principles
- **Defer full boundaries**: Build the Protocol when you have evidence you'll need the flexibility.
- **Strategy 1 (skip-the-last-step)**: Both sides of the boundary exist; they just deploy as one unit today. Split by changing Main only.
- **Strategy 2 (one-dimensional)**: Define the Protocol on the calling side only — half the cost, half the protection.
- **Strategy 3 (Facade)**: Hides subsystem complexity behind a single class. Not a full DIP boundary, but reduces coupling surface.

## Python Example

```python
# ---- Strategy 1: Infrastructure-ready, single deployment ----
# Build the full Protocol + implementation today.
# Keep them in the same package. Split by changing Main when ready.

from typing import Protocol

class ReportingService(Protocol):
    def generate(self, params: dict) -> bytes: ...

class PdfReportingService:             # implementation exists
    def generate(self, params: dict) -> bytes:
        return b"<PDF content>"

# Today: wired as a local function call in Main
# Later: split into a separate HTTP service by replacing only the Main wiring
# Zero changes to the calling use case either way.
```

```python
# ---- Strategy 2: One-dimensional Protocol (calling side only) ----
# The caller abstracts what it needs. The implementor has no Protocol to import.
# Half the boundary cost — the caller is decoupled, but no reciprocal interface.

from typing import Protocol

class EmailSender(Protocol):           # defined in the use case layer
    def send(self, to: str, subject: str, body: str) -> None: ...

class SendWelcomeEmail:
    def __init__(self, sender: EmailSender) -> None:
        self._sender = sender

    def execute(self, email: str) -> None:
        self._sender.send(email, "Welcome!", "Thanks for joining.")

# SES, SendGrid — they satisfy EmailSender via duck typing.
# No abstract base class. No import of EmailSender in the implementation.
# Switching implementations: change Main. Touch nothing else.
class SesEmailSender:                  # no import of EmailSender
    def send(self, to: str, subject: str, body: str) -> None:
        print(f"SES → {to}: {subject}")  # stub

def test_one_dimensional_boundary() -> None:
    class CapturingSender:
        sent: list[str] = []
        def send(self, to: str, subject: str, body: str) -> None:
            self.sent.append(to)

    capture = CapturingSender()
    SendWelcomeEmail(capture).execute("user@example.com")
    assert capture.sent == ["user@example.com"]

test_one_dimensional_boundary()
print("One-dimensional boundary test ✅")
```

```python
# ---- Strategy 3: Facade ----
# Hides a messy subsystem behind a clean surface.
# Not a true DIP boundary (callers still depend on this concrete class),
# but dramatically reduces coupling surface and enables future replacement.

class DataWarehouseFacade:
    """Hides 5 legacy modules behind a single clean interface."""
    def __init__(self) -> None:
        self._conn = LegacyDWConnector()
        self._qb   = LegacyQueryBuilder()
        self._rp   = LegacyResultParser()

    def run_query(self, sql: str) -> list[dict]:
        conn = self._conn.connect()
        raw  = self._qb.execute(conn, sql)
        return self._rp.parse(raw)

# Callers see one class. Legacy internals are fully hidden.
# Not a full DIP boundary — but easy to wrap in a Protocol later if needed:

class DWService(Protocol):
    def run_query(self, sql: str) -> list[dict]: ...

# Now DataWarehouseFacade satisfies DWService via duck typing.
# Full boundary achieved at almost zero extra cost.
```

## Quick Reference
- Full boundaries are expensive — build them when evidence demands it, not speculatively
- Strategy 1: skip-the-last-step → both sides exist, single deployment today
- Strategy 2: one-dimensional Protocol → calling side abstracts, no base class needed
- Strategy 3: Facade → hides complexity, easiest to later wrap with a Protocol
- Progression: Facade → one-dimensional Protocol → full boundary (as evidence accumulates)
