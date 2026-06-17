# Chapter 4: Structured Programming


## Summary
Dijkstra proved that `goto` makes programs unprovable and untestable. Structured control flow (sequence, selection, iteration) is sufficient for all computation and enables functional decomposition: breaking large problems into small, independently-testable units. The software corollary to falsifiability — we cannot prove programs correct, but we can prove them incorrect through tests.

## Key Principles
- **Functional decomposition**: Decompose behaviour into small functions, each testable in isolation.
- **Testability as architectural property**: Modules that cannot be tested independently are architecturally broken.
- **Falsifiability**: Tests don't prove correctness; they rule out incorrectness. Design for easy refutation.

## Python Example

```python
# ❌ Bad: Unstructured logic — complex flow, impossible to test in isolation
def process(data):
    result = []
    i = 0
    while i < len(data):
        if data[i] > 0:
            x = data[i] * 2
            if x > 100:
                result.append(x - 10)
                i += 2
                continue
            result.append(x)
        i += 1
    return result

# ✅ Good: Decomposed — each unit independently testable
def double(value: int) -> int:
    return value * 2

def apply_cap_discount(value: int, cap: int = 100, discount: int = 10) -> int:
    return value - discount if value > cap else value

def process_positive(values: list[int]) -> list[int]:
    return [apply_cap_discount(double(v)) for v in values if v > 0]

# Each function: 1 assertion to verify, 1 reason to fail.
```

## Quick Reference
- `goto` → structural unprovability → replaced by sequence/selection/iteration
- Small, pure functions = independently falsifiable units = testable architecture
- If you can't test it in isolation, the structure is wrong

---

