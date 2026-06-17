# Chapter 8: Boundaries

## Core Thesis
Third-party code and external APIs have different goals than your system. **Clean boundaries** protect your system from change, limit exposure of external APIs, and let you learn third-party libraries safely before integrating them.

---

## Using Third-Party Code

Third-party interfaces are designed for broad applicability — they expose more than you need. Don't pass them around raw; wrap them.

### Wrap Boundary Interfaces

```python
# BAD: Raw dict passed everywhere — anyone can mutate it; implementation leaks
sensors: dict[str, Sensor] = {}

# Any caller can do this:
sensors.clear()  # deletes everything — not our intent
sensors["bad_key"] = "wrong_type"  # type safety gone

# GOOD: Wrap the boundary interface
class SensorRepository:
    def __init__(self) -> None:
        self._sensors: dict[str, Sensor] = {}

    def add(self, sensor_id: str, sensor: Sensor) -> None:
        self._sensors[sensor_id] = sensor

    def get_by_id(self, sensor_id: str) -> Sensor:
        sensor = self._sensors.get(sensor_id)
        if sensor is None:
            raise SensorNotFoundError(f"Sensor '{sensor_id}' not found")
        return sensor

    def get_all(self) -> list[Sensor]:
        return list(self._sensors.values())
```

**Rule**: Never return a raw boundary type (`dict`, `list`, third-party object) from a public API. Wrap it, control what operations are exposed, and constrain the types.

---

## Learning Tests

When integrating a new library, write **learning tests** to explore your understanding of the API. They're controlled experiments, not production tests.

Benefits:
1. You learn the API without touching production code
2. You encode your understanding in runnable tests
3. When the library updates, your learning tests break first — alerting you to behavior changes

```python
# Learning tests for the `httpx` library
import httpx
import pytest

class TestHttpxLearning:
    """Learning tests — explore httpx behavior before integrating."""

    def test_get_returns_200_for_valid_url(self):
        response = httpx.get("https://httpbin.org/get")
        assert response.status_code == 200

    def test_response_body_is_json_parseable(self):
        response = httpx.get("https://httpbin.org/json")
        data = response.json()
        assert isinstance(data, dict)

    def test_timeout_raises_on_slow_endpoint(self):
        with pytest.raises(httpx.TimeoutException):
            httpx.get("https://httpbin.org/delay/5", timeout=0.1)

    def test_404_does_not_raise_by_default(self):
        # Learning: httpx does NOT raise on non-2xx by default
        response = httpx.get("https://httpbin.org/status/404")
        assert response.status_code == 404  # no exception!

    def test_raise_for_status_raises_on_4xx(self):
        response = httpx.get("https://httpbin.org/status/404")
        with pytest.raises(httpx.HTTPStatusError):
            response.raise_for_status()
```

---

## Using Code That Does Not Yet Exist

When you depend on an interface that isn't built yet (another team owns it), define **your own interface** to what you *wish* it looked like.

```python
# The transmitter team hasn't built their API yet.
# Define the interface YOU need:
from abc import ABC, abstractmethod

class Transmitter(ABC):
    @abstractmethod
    def transmit(self, frequency: float, data_stream) -> None:
        """Transmit data_stream on the given frequency."""

# Your code depends on YOUR interface — not their messy API
class CommunicationsController:
    def __init__(self, transmitter: Transmitter) -> None:
        self._transmitter = transmitter

    def send(self, message: bytes) -> None:
        freq = self._compute_frequency()
        self._transmitter.transmit(freq, message)

# When their API arrives, write an ADAPTER:
class TransmitterAdapter(Transmitter):
    """Adapts the third-party API to our clean Transmitter interface."""

    def __init__(self, legacy_api: ThirdPartyTransmitterAPI) -> None:
        self._api = legacy_api

    def transmit(self, frequency: float, data_stream) -> None:
        # Translate our clean API to their messy one
        self._api.set_frequency(frequency)
        self._api.initialize_channel()
        for chunk in data_stream:
            self._api.write_bytes(chunk)
        self._api.close_channel()
```

This is the **Adapter Pattern** at a boundary. Benefits:
- Your code doesn't change when their API changes — only the adapter does
- You can test `CommunicationsController` with a mock `Transmitter`
- The adapter isolates all the ugly translation code in one place

---

## Clean Boundaries: Summary Principles

```python
# 1. Wrap third-party code — never pass raw boundary types
# BAD
def process(sensors: dict[str, Sensor]) -> None: ...

# GOOD
def process(sensors: SensorRepository) -> None: ...


# 2. Learning tests — explore before integrating
class TestPandasLearning:
    def test_groupby_returns_dataframe(self):
        df = pd.DataFrame({"a": [1, 1, 2], "b": [10, 20, 30]})
        result = df.groupby("a")["b"].sum()
        assert result[1] == 30


# 3. Define your own interface for unknown/not-yet-existing code
class PaymentGateway(Protocol):
    def charge(self, amount_cents: int, card_token: str) -> PaymentResult: ...
    def refund(self, transaction_id: str) -> RefundResult: ...

# Your code depends on the Protocol — not on Stripe/Braintree directly


# 4. Adapter for ugly third-party APIs
class StripeAdapter:
    def __init__(self, stripe_client) -> None:
        self._client = stripe_client

    def charge(self, amount_cents: int, card_token: str) -> PaymentResult:
        result = self._client.PaymentIntent.create(
            amount=amount_cents,
            currency="usd",
            payment_method=card_token,
            confirm=True,
        )
        return PaymentResult(
            success=result.status == "succeeded",
            transaction_id=result.id,
        )
```

---

## Summary Table

| Problem | Solution |
|---|---|
| Third-party type with too many capabilities | Wrap in a domain class; expose only what you need |
| Learning a new library | Write learning tests first; encode API behavior as assertions |
| Depending on an API that doesn't exist yet | Define your own interface; write an Adapter when it arrives |
| Third-party exceptions leaking across boundary | Wrap in domain exceptions (see Ch. 7) |
| Testing code that calls external services | Depend on your own interface; mock the interface in tests |
