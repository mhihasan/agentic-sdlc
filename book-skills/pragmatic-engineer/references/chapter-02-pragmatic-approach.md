# Chapter 2: A Pragmatic Approach

## Summary
This chapter delivers the core design and process principles that span all levels of software development. ETC (Easier to Change) is the master principle from which DRY, Orthogonality, and Reversibility all derive. Tracer Bullets and Prototypes are contrasted as distinct development strategies. Domain Languages show how to raise abstraction to the problem's vocabulary. Estimating closes the chapter with the discipline of turning uncertainty into calibrated ranges.

## Key Principles

- **ETC — Easier to Change**: Every good design decision ultimately makes the system easier to change. When unsure between two paths, ask "which is easier to change later?" This subsumes DRY, SRP, decoupling, and good naming.
- **DRY — Don't Repeat Yourself**: Every piece of *knowledge* must have a single authoritative representation. DRY is not "don't copy code" — it's "don't duplicate intent." Identical code representing different concepts is *not* a DRY violation.
- **Orthogonality**: Changes to one component should not force changes to unrelated components. The helicopter metaphor: non-orthogonal systems have controls that interfere — touch one, compensate everywhere.
- **Reversibility**: Never treat an architectural decision as final. Use abstraction layers and configuration to defer and reverse decisions. "There are no final decisions."
- **Forgo Following Fads** (Tip 19): Server-side architecture has gone through big iron → clusters → VMs → containers → serverless → back to big iron in twenty years. You can't predict which fad survives. What you *can* do: hide third-party APIs behind your own abstraction layers and keep code modular so swapping is possible.
- **Tracer Bullets**: Build a thin, end-to-end slice of the real system — not throwaway code — to validate assumptions across all layers under real conditions. Adjust aim based on what you learn.
- **Prototypes**: Throwaway code to answer specific questions (Is this UI intuitive? Can this algorithm hit the performance target?). Different from tracer bullets — prototypes get discarded; tracer code becomes the skeleton of production.
- **Domain Languages**: Write code that reads like the problem domain. Internal DSLs reuse host language power; external DSLs give full syntax control. Don't spend more effort building the DSL than you'll save using it.
- **Estimating**: Use scaled units (days for <3 weeks, weeks for <6, months for longer). Model the system, decompose into components, give each parameter a value, and iterate schedules with the code rather than committing upfront to a single number.

## Python Example: DRY vs. Orthogonality

```python
# ❌ Bad: DRY violation — same validation logic duplicated, schema and code out of sync
def create_user(name: str, age: int):
    if not name or len(name) < 2:
        raise ValueError("Name must be at least 2 chars")
    if age < 0 or age > 150:
        raise ValueError("Age must be 0-150")
    db.insert("users", {"name": name, "age": age})

def update_user(user_id: int, name: str, age: int):
    if not name or len(name) < 2:        # duplicated knowledge
        raise ValueError("Name must be at least 2 chars")
    if age < 0 or age > 150:             # duplicated knowledge
        raise ValueError("Age must be 0-150")
    db.update("users", user_id, {"name": name, "age": age})


# ✅ Good: Single authoritative representation of validation rules
from dataclasses import dataclass

@dataclass
class UserData:
    name: str
    age: int

    def __post_init__(self):
        if not self.name or len(self.name) < 2:
            raise ValueError("Name must be at least 2 chars")
        if not (0 <= self.age <= 150):
            raise ValueError("Age must be 0-150")

def create_user(data: UserData) -> None:
    db.insert("users", {"name": data.name, "age": data.age})

def update_user(user_id: int, data: UserData) -> None:
    db.update("users", user_id, {"name": data.name, "age": data.age})

# Test: validation is in ONE place
try:
    UserData(name="X", age=200)
except ValueError as e:
    assert "Age" in str(e)
```

## Tracer Bullets vs. Prototypes

```python
# TRACER BULLET: thin but real, kept in production, tests real integration
# e.g. Sprint 1 end-to-end: accept HTTP request → parse → persist → return ID
from fastapi import FastAPI
app = FastAPI()

@app.post("/orders")
async def create_order(payload: dict) -> dict:
    # Minimal but real: hits real DB, real auth, real event bus
    order_id = await order_repo.insert(payload)
    await event_bus.publish("order.created", {"id": order_id})
    return {"id": order_id}  # not every field — tracer, not complete


# PROTOTYPE: throwaway, explores one question, never ships
# e.g. "Can we hit <50ms p99 with this serialization approach?"
import timeit, json, msgpack  # noqa — prototype dependencies

def benchmark_serialization(data: dict, runs: int = 10_000):
    json_time = timeit.timeit(lambda: json.dumps(data), number=runs)
    msgpack_time = timeit.timeit(lambda: msgpack.packb(data), number=runs)
    print(f"JSON: {json_time:.3f}s | msgpack: {msgpack_time:.3f}s")
    # Throw this away once you have your answer
```

## Estimation Scale

```python
def format_estimate(working_days: int) -> str:
    """Express estimates at the right granularity (Tip 23)."""
    if working_days <= 15:
        return f"~{working_days} days"
    elif working_days <= 30:
        return f"~{working_days // 5} weeks"
    elif working_days <= 100:
        return f"~{round(working_days / 20)} months"
    else:
        return "Think hard before committing — break down further first"

assert format_estimate(5)  == "~5 days"
assert format_estimate(20) == "~4 weeks"
assert format_estimate(80) == "~4 months"
```

## Quick Reference

- **ETC test**: "Does this change make the system easier or harder to change later?"
- **DRY acid test**: "If this requirement changes, how many places do I edit?"
- **Orthogonality test**: "If I change this module's internals, how many other modules need updating?" — answer should be zero
- **Reversibility rule**: Hide third-party APIs behind your own abstraction; defer irreversible decisions
- **Tracer ≠ Prototype**: Tracer is lean production code; prototype is throwaway exploration
- **DSL rule**: Don't spend more building it than you'll save using it; prefer off-the-shelf (YAML/JSON) when possible
- **Estimate answer**: When asked cold, say "I'll get back to you" — always model before committing
