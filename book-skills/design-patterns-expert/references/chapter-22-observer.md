# Chapter 22: Behavioral — Observer

## Summary
Observer defines a one-to-many dependency so that when one object (the Subject/Publisher)
changes state, all its dependents (Observers/Subscribers) are notified and updated
automatically. It is the foundational pattern behind every event system, reactive framework,
and pub/sub architecture. The Subject maintains a list of observers and calls a notification
method on each when its state changes. Observers register themselves with the Subject;
neither side needs to know the concrete type of the other — they communicate through
a shared interface.

## Key Principles
- **Publisher/Subject**: Maintains observer list; notifies on state change; provides subscribe/unsubscribe.
- **Subscriber/Observer**: Implements `update(event)` interface; reacts to notifications.
- **Loose coupling**: Publisher knows only the Observer interface; Observers know only the Publisher interface.
- **Push vs Pull**: Push model sends data with the notification; Pull model sends a reference to the publisher and lets observer fetch what it needs.
- **Unsubscribe is essential**: Observers that don't unsubscribe cause memory leaks — they keep the publisher alive and receive stale notifications.

## Python Example

```python
from __future__ import annotations
from typing import Protocol, Callable, Any
from dataclasses import dataclass, field
import weakref

# ❌ Bad: Publisher hard-codes all consumer calls — adding a consumer requires editing Publisher
class StockTicker:
    def __init__(self):
        self._price = 0.0
        self._dashboard = Dashboard()   # tightly coupled to specific consumers
        self._alert_service = AlertService()

    def update_price(self, price: float):
        self._price = price
        self._dashboard.refresh(price)      # must edit this method for every new consumer
        self._alert_service.check(price)


# ✅ Good: Observer pattern — typed Protocol approach

@dataclass
class StockEvent:
    symbol: str
    price: float
    change_pct: float

class StockObserver(Protocol):
    def on_price_change(self, event: StockEvent) -> None: ...


class StockPublisher:
    """Subject/Publisher."""
    def __init__(self, symbol: str) -> None:
        self._symbol = symbol
        self._price: float = 0.0
        self._observers: list[StockObserver] = []

    def subscribe(self, observer: StockObserver) -> None:
        self._observers.append(observer)

    def unsubscribe(self, observer: StockObserver) -> None:
        self._observers.remove(observer)

    def set_price(self, new_price: float) -> None:
        old = self._price
        self._price = new_price
        change = ((new_price - old) / old * 100) if old else 0.0
        event = StockEvent(self._symbol, new_price, round(change, 2))
        self._notify(event)

    def _notify(self, event: StockEvent) -> None:
        for obs in list(self._observers):  # copy to allow unsubscription during iteration
            obs.on_price_change(event)


# Concrete Observers — each has one responsibility
class PriceDashboard:
    def __init__(self) -> None:
        self.latest: list[StockEvent] = []

    def on_price_change(self, event: StockEvent) -> None:
        self.latest.append(event)
        print(f"[Dashboard] {event.symbol}: ${event.price} ({event.change_pct:+.1f}%)")


class PriceAlertService:
    def __init__(self, threshold_pct: float) -> None:
        self._threshold = threshold_pct
        self.alerts: list[str] = []

    def on_price_change(self, event: StockEvent) -> None:
        if abs(event.change_pct) >= self._threshold:
            msg = f"ALERT: {event.symbol} moved {event.change_pct:+.1f}%!"
            self.alerts.append(msg)
            print(msg)


aapl = StockPublisher("AAPL")
dashboard = PriceDashboard()
alerts    = PriceAlertService(threshold_pct=5.0)

aapl.subscribe(dashboard)
aapl.subscribe(alerts)

aapl.set_price(150.0)
aapl.set_price(160.0)  # +6.7% — triggers alert

assert len(dashboard.latest) == 2
assert len(alerts.alerts) == 1
assert "AAPL" in alerts.alerts[0]

# Unsubscribe — dashboard no longer receives updates
aapl.unsubscribe(dashboard)
aapl.set_price(155.0)
assert len(dashboard.latest) == 2  # still 2 — not updated


# ── Pythonic: callable-based event emitter ────────────────────────────────

class EventEmitter:
    """Lightweight pub/sub using callables instead of Protocol classes."""
    def __init__(self) -> None:
        self._handlers: dict[str, list[Callable]] = {}

    def on(self, event: str, handler: Callable) -> None:
        self._handlers.setdefault(event, []).append(handler)

    def off(self, event: str, handler: Callable) -> None:
        self._handlers.get(event, []).remove(handler)

    def emit(self, event: str, *args: Any, **kwargs: Any) -> None:
        for h in list(self._handlers.get(event, [])):
            h(*args, **kwargs)


emitter = EventEmitter()
log: list[str] = []

emitter.on("user.login", lambda uid: log.append(f"login:{uid}"))
emitter.on("user.login", lambda uid: log.append(f"audit:{uid}"))

emitter.emit("user.login", "alice")
assert log == ["login:alice", "audit:alice"]
```

## Quick Reference
- **Intent**: One-to-many notification — Subject state change auto-notifies all Observers
- **Use when**: One object's change should trigger updates in an unknown/varying number of others
- **Subscribe/Unsubscribe**: Always provide both; missing unsubscribe → memory leaks
- **Push model**: Event object carries data (`StockEvent`) — observers get everything they need
- **Pull model**: Observer receives publisher reference and fetches what it needs — avoids fat events
- **Thread safety**: Copy observer list before iterating to allow mid-notification unsubscription
- **vs Mediator**: Mediator manages two-way M:M coordination; Observer is one-way 1:M notification
- **Python native**: `@property` with descriptor + `__set__` can auto-notify on attribute change
- **Real uses**: Django signals, React state updates, AWS EventBridge, RxPY observables, GUI event loops
