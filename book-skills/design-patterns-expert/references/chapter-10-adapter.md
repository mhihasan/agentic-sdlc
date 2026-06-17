# Chapter 10: Structural — Adapter

## Summary
Adapter converts the interface of one class into the interface expected by a client, making
incompatible interfaces work together without changing either side. It acts as a wrapper:
the client calls the Adapter using the target interface; the Adapter translates those calls
to the Adaptee's incompatible API. The pattern is the surgical tool for integrating
third-party libraries, legacy code, or external services into a system that uses a different
interface contract. In Python, Adapter is almost always implemented via object composition
(wrapping), not class inheritance.

## Key Principles
- **Target interface**: The interface the client expects. The Adapter must implement this.
- **Adaptee**: The existing class with an incompatible interface that you cannot (or should not) modify.
- **Adapter (wrapper)**: Implements Target; holds a reference to Adaptee; translates calls.
- **Two-way adapters**: An Adapter can also make the target interface usable by the adaptee's callers.
- **When to use**: Integrating a third-party library, wrapping legacy code, or adapting a data format (XML → JSON, imperial → metric).

## Python Example

```python
from typing import Protocol
import json
import xml.etree.ElementTree as ET

# ❌ Bad: Client directly coupled to third-party library interface
import requests  # type: ignore

class StockTrackerBad:
    def get_price(self, symbol: str) -> float:
        # Directly calls third-party API — if the library changes, tracker breaks
        resp = requests.get(f"https://finance-api.example.com/v1/price/{symbol}")
        return resp.json()["last_price"]


# ✅ Good: Adapter pattern

# Target interface — what OUR system expects
class StockDataProvider(Protocol):
    def get_stock_price(self, symbol: str) -> float: ...
    def get_stock_history(self, symbol: str, days: int) -> list[float]: ...


# Adaptee — a third-party library with an incompatible interface
class LegacyFinanceAPI:
    """Third-party library we cannot modify."""
    def fetch_price_xml(self, ticker: str) -> str:
        # Returns XML: <price ticker="AAPL"><last>175.23</last></price>
        return f'<price ticker="{ticker}"><last>175.23</last></price>'

    def fetch_history_csv(self, ticker: str, period: int) -> str:
        # Returns CSV string: "175.23,176.01,174.88"
        return ",".join(str(175.0 + i) for i in range(period))


# Adapter — wraps LegacyFinanceAPI, implements StockDataProvider
class FinanceAPIAdapter:
    def __init__(self, legacy_api: LegacyFinanceAPI) -> None:
        self._api = legacy_api  # object composition

    def get_stock_price(self, symbol: str) -> float:
        xml_str = self._api.fetch_price_xml(symbol)
        root = ET.fromstring(xml_str)
        return float(root.find("last").text)  # type: ignore

    def get_stock_history(self, symbol: str, days: int) -> list[float]:
        csv = self._api.fetch_history_csv(symbol, days)
        return [float(v) for v in csv.split(",")]


# Client code — depends only on StockDataProvider Protocol
class StockTracker:
    def __init__(self, provider: StockDataProvider) -> None:
        self._provider = provider

    def alert_if_drop(self, symbol: str, threshold: float) -> str:
        price = self._provider.get_stock_price(symbol)
        if price < threshold:
            return f"ALERT: {symbol} dropped below {threshold} (now {price})"
        return f"{symbol} OK at {price}"


# Wiring: swap the third-party library by swapping the adapter
adapter = FinanceAPIAdapter(LegacyFinanceAPI())
tracker = StockTracker(adapter)
result = tracker.alert_if_drop("AAPL", 100.0)
assert "AAPL OK" in result


# ── Format Adapter: imperial → metric ────────────────────────────────────

class MetricTemperature(Protocol):
    def celsius(self) -> float: ...

class FahrenheitSensor:
    """Legacy hardware sensor that speaks Fahrenheit."""
    def read_fahrenheit(self) -> float:
        return 98.6

class FahrenheitToMetricAdapter:
    def __init__(self, sensor: FahrenheitSensor) -> None:
        self._sensor = sensor

    def celsius(self) -> float:
        return (self._sensor.read_fahrenheit() - 32) * 5 / 9

sensor = FahrenheitToMetricAdapter(FahrenheitSensor())
assert abs(sensor.celsius() - 37.0) < 0.1
```

## Quick Reference
- **Intent**: Convert an incompatible interface into one the client expects
- **Use when**: Integrating third-party libs, legacy code, or incompatible data formats
- **Object Adapter** (preferred in Python): Adapter wraps Adaptee via composition
- **Class Adapter**: Adapter inherits from both Target and Adaptee — avoid in Python (MRO complexity)
- **Single Responsibility**: Adapter's only job is translation — no business logic
- **Testing**: Swap the Adapter for a mock implementation of the Target Protocol — Adaptee never appears in tests
- **vs Facade**: Facade simplifies a complex subsystem for clients; Adapter makes an incompatible interface compatible
- **vs Decorator**: Decorator adds behaviour to an existing interface; Adapter changes the interface
- **Real uses**: ORM adapters (SQLAlchemy dialects), payment gateway wrappers, cloud SDK abstractions
