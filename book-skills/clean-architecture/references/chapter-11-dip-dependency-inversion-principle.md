# Chapter 11: DIP — The Dependency Inversion Principle

## Summary
High-level policy must not depend on low-level detail. Both should depend on abstractions. DIP is the single most important principle in Clean Architecture — every boundary crossing is implemented through it. Stable abstractions (Protocols, ABCs) absorb volatility: when implementations change, the abstract contract remains stable and callers are unaffected. In Python, `typing.Protocol` makes DIP nearly frictionless — no inheritance required.

## Key Principles
- **Depend on abstractions, not concretions**: Across layer boundaries, type-hint with `Protocol`, not concrete classes.
- **The interface lives in the high-level layer**: The use case defines what it needs; the infrastructure provides it.
- **Stable abstractions absorb change**: Volatile implementations sit behind stable protocols — changes don't propagate inward.
- **Python advantage**: With `Protocol`, the outer ring never needs to import anything from the inner ring to satisfy the interface.

## Anti-Patterns
- `import psycopg2` in a use case or entity module
- `import flask` or `from fastapi import ...` in business logic
- `import boto3` in domain objects

## Python Example

```python
# ❌ Bad: Use case imports concrete infrastructure — untestable, tightly coupled
import boto3   # high-level policy depends on AWS SDK

class SendWelcomeEmail:
    def execute(self, user_email: str) -> None:
        ses = boto3.client("ses")
        ses.send_email(
            Source="noreply@app.com",
            Destination={"ToAddresses": [user_email]},
            Message={"Subject": {"Data": "Welcome!"}, "Body": {"Text": {"Data": "Hello"}}},
        )
# Impossible to test without AWS credentials.
# Switching to SendGrid: rewrite this entire use case.
```

```python
# ✅ Good: Protocol-based DIP — outer ring needs no import from inner ring
from typing import Protocol
from dataclasses import dataclass

# --- Inner ring (use case layer): defines the protocol it needs ---
class EmailSender(Protocol):
    def send(self, to: str, subject: str, body: str) -> None: ...

class SendWelcomeEmail:
    def __init__(self, sender: EmailSender) -> None:
        self._sender = sender

    def execute(self, user_email: str) -> None:
        self._sender.send(
            to=user_email,
            subject="Welcome!",
            body="Thanks for signing up.",
        )

# --- Outer ring (infrastructure): satisfies Protocol without importing it ---
class SesEmailSender:                  # no import of EmailSender required
    def send(self, to: str, subject: str, body: str) -> None:
        import boto3                   # infrastructure detail stays here
        boto3.client("ses").send_email(...)

class SendGridEmailSender:             # drop-in replacement, zero use case changes
    def send(self, to: str, subject: str, body: str) -> None:
        import sendgrid
        sendgrid.send(to=to, subject=subject, content=body)

# --- Test double: no AWS, no network, runs in microseconds ---
class CapturingEmailSender:
    def __init__(self) -> None:
        self.sent: list[dict] = []

    def send(self, to: str, subject: str, body: str) -> None:
        self.sent.append({"to": to, "subject": subject, "body": body})

def test_welcome_email_sends_correct_subject() -> None:
    sender = CapturingEmailSender()
    SendWelcomeEmail(sender).execute("user@example.com")
    assert len(sender.sent) == 1
    assert sender.sent[0]["subject"] == "Welcome!"
    assert sender.sent[0]["to"] == "user@example.com"
```

```python
# DIP with Callable — the simplest possible abstraction in Python
from typing import Callable

# A factory is just a callable that returns a connection
DbFactory = Callable[[], "Connection"]

class OrderRepository:
    def __init__(self, db_factory: DbFactory) -> None:
        self._db = db_factory        # depends on Callable, not psycopg2

# Production
repo = OrderRepository(db_factory=lambda: psycopg2.connect(DSN))

# Tests
repo = OrderRepository(db_factory=lambda: InMemoryDb())
```

```python
# DIP: where the Protocol lives matters
# ✅ Correct: Protocol defined in the USE CASE layer, implemented in INFRASTRUCTURE

# domain/use_cases/send_welcome_email.py  (inner ring)
class EmailSender(Protocol): ...          # ← Protocol lives here

# infrastructure/ses_email.py  (outer ring)
class SesEmailSender:                     # ← implementation lives here
    def send(self, ...): ...              # no import from domain needed

# ❌ Wrong: Protocol defined in infrastructure, use case imports from infra
# infrastructure/email_protocol.py
# class EmailSender(Protocol): ...

# domain/use_cases/send_welcome_email.py
# from infrastructure.email_protocol import EmailSender  ← dependency inverted wrong way
```

## Quick Reference
- DIP: high-level policy → Protocol ← low-level detail (both point at abstraction)
- The Protocol lives in the inner (use case) layer — outer ring implements it without importing it
- Python: `typing.Protocol` gives structural subtyping; no inheritance needed
- If your use case has `import boto3`, `import sqlalchemy`, or `from fastapi import`, DIP is violated
- Use `Callable[..., T]` for simple single-operation abstractions
