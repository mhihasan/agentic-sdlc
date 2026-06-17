# Chapter 13: Structural — Decorator

## Summary
Decorator attaches additional responsibilities to an object dynamically by wrapping it in
decorator objects that share the same interface. It is a flexible alternative to subclassing
for extending behaviour — each decorator adds one concern, and decorators can be stacked in
any order and combination at runtime. The classic coffee shop example from the book shows
that serving "Espresso with Milk and Caramel" should not require an `EspressoMilkCaramel`
class — it should be three objects composed together. In Python, the `@decorator` syntax
is a direct language-level embodiment of this pattern for functions.

## Key Principles
- **Same interface**: Both the Component and every Decorator implement the same interface — the client never knows it's wrapped.
- **Wrap and delegate**: Each Decorator holds a reference to the wrapped Component and calls it, then adds its own behaviour before/after.
- **Stackable**: Decorators compose: `d3(d2(d1(component)))` — order matters and is controlled at runtime.
- **Single responsibility per decorator**: Each decorator adds exactly one cross-cutting concern (logging, caching, auth, compression).
- **Runtime flexibility**: Composition chosen at runtime vs. inheritance which is fixed at compile time.

## Python Example

```python
from typing import Protocol
from functools import wraps
import time

# ❌ Bad: Subclassing explosion — one subclass per feature combination
class PlainNotifier: ...
class LoggingNotifier(PlainNotifier): ...
class AuthNotifier(PlainNotifier): ...
class LoggingAuthNotifier(LoggingNotifier): ...  # ← combinatorial explosion


# ✅ Good: Decorator pattern — class-based

class Notifier(Protocol):
    def send(self, message: str) -> str: ...


class EmailNotifier:
    """Concrete component — the base."""
    def __init__(self, email: str) -> None:
        self._email = email

    def send(self, message: str) -> str:
        return f"[Email → {self._email}]: {message}"


class BaseDecorator:
    """Base decorator — delegates to wrapped component."""
    def __init__(self, wrapped: Notifier) -> None:
        self._wrapped = wrapped

    def send(self, message: str) -> str:
        return self._wrapped.send(message)


class SlackDecorator(BaseDecorator):
    """Also sends to Slack."""
    def __init__(self, wrapped: Notifier, channel: str) -> None:
        super().__init__(wrapped)
        self._channel = channel

    def send(self, message: str) -> str:
        base = super().send(message)
        slack = f"[Slack → #{self._channel}]: {message}"
        return f"{base}\n{slack}"


class SMSDecorator(BaseDecorator):
    """Also sends SMS."""
    def __init__(self, wrapped: Notifier, phone: str) -> None:
        super().__init__(wrapped)
        self._phone = phone

    def send(self, message: str) -> str:
        base = super().send(message)
        sms = f"[SMS → {self._phone}]: {message}"
        return f"{base}\n{sms}"


# Stack decorators at runtime — order and combination chosen by caller
base = EmailNotifier("alice@example.com")
with_slack = SlackDecorator(base, "alerts")
with_slack_and_sms = SMSDecorator(with_slack, "+1-555-0100")

result = with_slack_and_sms.send("Server down!")
assert "[Email → alice@example.com]" in result
assert "[Slack → #alerts]" in result
assert "[SMS → +1-555-0100]" in result


# ── Pythonic: function decorators for cross-cutting concerns ──────────────

def retry(max_attempts: int = 3, delay: float = 0.1):
    """Decorator that retries a function on exception."""
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            last_exc = None
            for attempt in range(max_attempts):
                try:
                    return fn(*args, **kwargs)
                except Exception as exc:
                    last_exc = exc
                    time.sleep(delay * (2 ** attempt))  # exponential backoff
            raise last_exc  # type: ignore
        return wrapper
    return decorator


def timed(fn):
    """Decorator that logs execution time."""
    @wraps(fn)
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = fn(*args, **kwargs)
        elapsed = time.perf_counter() - start
        print(f"{fn.__name__} took {elapsed:.4f}s")
        return result
    return wrapper


@timed
@retry(max_attempts=3)
def fetch_data(url: str) -> dict:
    # Simulated: first call succeeds
    return {"data": "ok"}

result = fetch_data("https://api.example.com/data")
assert result["data"] == "ok"

# Decorators are stacked: timed wraps retry wraps fetch_data
# Execution order: timed → retry → fetch_data
```

## Quick Reference
- **Intent**: Attach responsibilities to objects dynamically by wrapping with same-interface decorators
- **Use when**: You need to add behaviours in combinations without class explosion; behaviours are optional
- **Stack order**: `outer(inner(component))` — outer's `send()` runs first, then delegates inward
- **Same interface**: Decorator must implement the same Protocol as the Component
- **Python `@decorator`**: Function decorators are the language-native Decorator pattern for callables
- **vs Inheritance**: Inheritance is static (compile-time); Decorator is dynamic (runtime) and composable
- **vs Composite**: Composite aggregates a tree for uniform treatment; Decorator wraps a single object to add behaviour
- **vs Proxy**: Proxy controls access to an object; Decorator adds behaviour. The structure is similar but intent differs.
- **Real uses**: Python `@functools.lru_cache`, `@login_required`, logging middleware, HTTP request pipelines
