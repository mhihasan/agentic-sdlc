# Chapter 24: Behavioral — Strategy

## Summary
Strategy defines a family of interchangeable algorithms, encapsulates each one, and makes
them interchangeable at runtime. The Context delegates the algorithm to a Strategy object
it holds, rather than implementing the algorithm itself. The pattern is one of the most
commonly used in Python — replacing `if/elif` algorithm-selection branches with composable
strategy objects. It is also the primary enabler of OCP: adding a new algorithm means
adding a new Strategy class with zero changes to the Context.

## Key Principles
- **Context**: Holds a reference to a Strategy; delegates the algorithm call to it.
- **Strategy interface**: Single-method interface (often `execute()`, `sort()`, `calculate()`) that all concrete strategies implement.
- **Interchangeable**: Strategies can be swapped at runtime — same context, different behaviour.
- **Stateless strategies preferred**: Strategies that carry no state can be shared across contexts (flyweight opportunity).
- **vs State**: Strategy swaps algorithms that have no lifecycle transitions; State manages object modes that transition.

## Python Example

```python
from typing import Protocol, Callable
from dataclasses import dataclass
import functools

# ❌ Bad: Sort routine baked into Context — adding a new sort algorithm requires editing
class DataProcessor:
    def sort(self, data: list, algorithm: str) -> list:
        if algorithm == "bubble":
            # bubble sort implementation...
            return sorted(data)
        elif algorithm == "merge":
            # merge sort implementation...
            return sorted(data)
        elif algorithm == "quick":
            # quick sort implementation...
            return sorted(data)
        else:
            raise ValueError(f"Unknown algorithm: {algorithm}")


# ✅ Good: Strategy pattern

class SortStrategy(Protocol):
    def sort(self, data: list[int]) -> list[int]: ...


class BubbleSort:
    def sort(self, data: list[int]) -> list[int]:
        arr = list(data)
        n = len(arr)
        for i in range(n):
            for j in range(n - i - 1):
                if arr[j] > arr[j + 1]:
                    arr[j], arr[j + 1] = arr[j + 1], arr[j]
        return arr


class MergeSort:
    def sort(self, data: list[int]) -> list[int]:
        if len(data) <= 1:
            return list(data)
        mid = len(data) // 2
        left  = MergeSort().sort(data[:mid])
        right = MergeSort().sort(data[mid:])
        return self._merge(left, right)

    def _merge(self, left: list[int], right: list[int]) -> list[int]:
        result, i, j = [], 0, 0
        while i < len(left) and j < len(right):
            if left[i] <= right[j]:
                result.append(left[i]); i += 1
            else:
                result.append(right[j]); j += 1
        return result + left[i:] + right[j:]


class BuiltinSort:
    def sort(self, data: list[int]) -> list[int]:
        return sorted(data)


class DataProcessor:
    def __init__(self, strategy: SortStrategy) -> None:
        self._strategy = strategy

    def set_strategy(self, strategy: SortStrategy) -> None:
        self._strategy = strategy  # swap at runtime

    def process(self, data: list[int]) -> list[int]:
        return self._strategy.sort(data)


data = [5, 2, 8, 1, 9, 3]

proc = DataProcessor(BubbleSort())
assert proc.process(data) == [1, 2, 3, 5, 8, 9]

proc.set_strategy(MergeSort())
assert proc.process(data) == [1, 2, 3, 5, 8, 9]

# Swap to built-in at runtime for large datasets
proc.set_strategy(BuiltinSort())
assert proc.process(data) == [1, 2, 3, 5, 8, 9]


# ── Strategy with callables (Pythonic for simple cases) ───────────────────

@dataclass
class Validator:
    _rules: list[Callable[[str], bool]]

    def validate(self, value: str) -> list[str]:
        errors = []
        for rule in self._rules:
            if not rule(value):
                errors.append(f"Failed: {rule.__name__}")
        return errors


def not_empty(v: str) -> bool: return len(v.strip()) > 0
def min_length_8(v: str) -> bool: return len(v) >= 8
def has_digit(v: str) -> bool: return any(c.isdigit() for c in v)
def has_upper(v: str) -> bool: return any(c.isupper() for c in v)

password_validator = Validator([not_empty, min_length_8, has_digit, has_upper])
errors = password_validator.validate("weakpw")
assert "Failed: min_length_8" in errors
assert "Failed: has_digit" in errors

strong_errors = password_validator.validate("Str0ngPass!")
assert strong_errors == []


# ── Payment strategy (real-world example) ────────────────────────────────

class PaymentStrategy(Protocol):
    def charge(self, amount: float) -> str: ...

class CreditCard:
    def __init__(self, last4: str) -> None:
        self._last4 = last4
    def charge(self, amount: float) -> str:
        return f"Charged ${amount:.2f} to card ending {self._last4}"

class PayPal:
    def __init__(self, email: str) -> None:
        self._email = email
    def charge(self, amount: float) -> str:
        return f"Charged ${amount:.2f} via PayPal ({self._email})"

class Crypto:
    def charge(self, amount: float) -> str:
        return f"Charged ${amount:.2f} in BTC"

@dataclass
class Checkout:
    payment: PaymentStrategy

    def complete(self, amount: float) -> str:
        return self.payment.charge(amount)

assert "card ending 4242" in Checkout(CreditCard("4242")).complete(99.99)
assert "PayPal" in Checkout(PayPal("alice@example.com")).complete(49.99)
```

## Quick Reference
- **Intent**: Define a family of interchangeable algorithms; let context choose at runtime
- **Use when**: Many algorithm variants exist; selection happens at runtime or varies by config
- **Protocol interface**: Single-method Protocol (`def sort(self, data) -> result`) — keep it focused
- **Stateless strategies**: Can be module-level singletons; no per-instance state → reusable
- **Callable variant**: For single-operation strategies, plain `Callable` often suffices
- **vs State**: State manages lifecycle transitions; Strategy just swaps an algorithm
- **vs Template Method**: Template Method defines skeleton in base class + hooks; Strategy composes whole algorithm
- **OCP enabler**: New algorithm = new Strategy class; Context and other strategies unchanged
- **Real uses**: Sort algorithms, payment processors, compression codecs, routing algorithms, ML model selection
