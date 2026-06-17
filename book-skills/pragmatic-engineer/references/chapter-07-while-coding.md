# Chapter 7: While You Are Coding

## Summary
Coding is not mechanical transcription of a design. The decisions made while coding — whether to follow instincts that signal something is wrong, how to test what you're building, when to refactor, how to name things, how to think about security and algorithm efficiency — determine whether a system is maintainable or a liability. This chapter covers eight topics: listening to your gut, avoiding programming by coincidence, estimating algorithmic complexity, refactoring with discipline, testing as design, property-based testing, security as first-class concern, and naming as communication.

## Key Principles

- **Listen to Your Lizard Brain**: When code "feels wrong," that discomfort is your subconscious pattern-matching on experience. Stop, step back from the keyboard, articulate what bothers you. The feeling precedes the articulation.
- **Don't Program by Coincidence**: Know *why* your code works, not just *that* it works. Code that works by accident breaks by accident. Test boundary conditions, understand every dependency, don't keep code you don't understand.
- **Algorithm Speed (Big-O)**: Estimate the runtime and memory complexity of algorithms before profiling. Understand when O(n²) is fine (n=100) and catastrophic (n=1,000,000). Use the right data structure for the access pattern.
- **Test Your Estimates** (Tip 64): After writing an algorithm, test your Big-O estimate. Use timing or counting to verify the actual growth curve matches your prediction. If they disagree, your model is wrong.
- **Refactor Early, Refactor Often**: Refactoring is not a special phase — it's continuous gardening. The two rules: (1) Don't add functionality while refactoring. (2) Have tests before refactoring. Small, safe steps.
- **Testing Is Not About Finding Bugs**: The primary value of tests is the thinking they force — tests are the first user of your code, and writing a test shows you how hard it is to use. Hard-to-test code is poorly designed code.
- **Build End-to-End, Not Top-Down or Bottom Up** (Tip 68): The only way to build software is incrementally — small pieces of end-to-end functionality that learn about the problem as you go. Beware TDD tunnel vision: the "green tests" glow can seduce you into endlessly polishing details while ignoring whether you're solving the actual problem. Build toward a destination, not just toward passing tests.
- **Design to Test** (Tip 69): Think about how you will test code before and during writing it. If a piece of code is hard to test, that is a design signal — not a testing problem. Refactor the interface until testing becomes straightforward.
- **Test Your Software, or Your Users Will** (Tip 70): If you don't test thoroughly, your users become your test suite — in production. Ruthless, automated, continuous testing is not optional; it's the only way to find bugs before users do.
- **Property-Based Testing** (Tip 71): Instead of cherry-picked examples, generate thousands of random inputs and assert invariants that must always hold. Use frameworks like `hypothesis`. Finds edge cases your examples never would.
- **Security as First-Class Concern**: Minimize attack surface, apply least privilege, validate all external inputs, encrypt sensitive data. Apply security patches quickly (Tip 73) — the window between a known vulnerability and exploitation is often hours. Security is not a feature sprint — it's continuous practice.
- **Naming Things**: Names are the primary communication medium in code. A name that requires a comment to explain is a bad name. Rename aggressively when the name no longer matches the intent.

## Python Example: Programming by Coincidence vs. Deliberate Code

```python
# ❌ Bad: Works by coincidence — relies on dict insertion order as a side effect
def get_first_admin(users: dict) -> str:
    for user_id, role in users.items():
        if role == "admin":
            return user_id   # returns "first inserted" admin, not "first by ID"
    return ""

# Works today because we always insert admins first — but no one documented why.
# Refactoring insert order silently breaks this.


# ✅ Good: Explicit intent, tested boundary conditions
from typing import Optional

def get_lowest_id_admin(users: dict[int, str]) -> Optional[int]:
    """
    Returns the numerically smallest user_id with role 'admin'.
    Returns None if no admin exists.

    Not relying on insertion order — explicit sort by key.
    """
    admin_ids = [uid for uid, role in users.items() if role == "admin"]
    return min(admin_ids) if admin_ids else None

# Test boundary conditions explicitly
assert get_lowest_id_admin({}) is None                          # empty
assert get_lowest_id_admin({1: "user", 2: "admin"}) == 2       # single admin
assert get_lowest_id_admin({3: "admin", 1: "admin"}) == 1      # returns min, not first
```

## Refactoring: Two Rules in Action

```python
# ❌ Bad: Adding features during a "refactoring" — mixing concerns
def calculate_order_total(items):
    # "While I'm in here, let me add discount logic"
    total = sum(item.price * item.quantity for item in items)
    if total > 100:  # NEW FEATURE added mid-refactor
        total *= 0.9  # 10% discount
    return total


# ✅ Good: Refactor first, feature second — separate commits, separate tests
# COMMIT 1: Refactor (no behavior change)
def calculate_subtotal(items) -> float:
    """Extracted: pure subtotal calculation, no discounts."""
    return sum(item.price * item.quantity for item in items)

# Tests pass unchanged — behavior preserved
assert calculate_subtotal([MockItem(10.0, 2)]) == 20.0

# COMMIT 2: Add feature on clean foundation
def apply_bulk_discount(subtotal: float) -> float:
    """10% discount on orders over $100."""
    return subtotal * 0.9 if subtotal > 100 else subtotal

def calculate_order_total(items) -> float:
    return apply_bulk_discount(calculate_subtotal(items))
```

## Property-Based Testing

```python
from hypothesis import given, strategies as st

def reverse_list(lst: list) -> list:
    return lst[::-1]

# ❌ Bad: Example-based tests — only checks what you thought of
def test_reverse():
    assert reverse_list([1, 2, 3]) == [3, 2, 1]
    assert reverse_list([]) == []

# ✅ Good: Property-based — asserts invariants across thousands of inputs
@given(st.lists(st.integers()))
def test_reverse_is_involution(lst):
    """Reversing twice gives the original — always."""
    assert reverse_list(reverse_list(lst)) == lst

@given(st.lists(st.integers()))
def test_reverse_preserves_length(lst):
    assert len(reverse_list(lst)) == len(lst)

@given(st.lists(st.integers(), min_size=1))
def test_reverse_first_becomes_last(lst):
    assert reverse_list(lst)[0] == lst[-1]
```

## Security: Minimizing Attack Surface

```python
# ❌ Bad: Broad permissions, no input validation, secrets in code
import os
import subprocess

API_KEY = "sk-hardcoded-secret-12345"   # in source → in git history forever

def run_report(user_query: str) -> str:
    cmd = f"psql -c 'SELECT {user_query}'"  # SQL injection via user input
    return subprocess.check_output(cmd, shell=True).decode()  # shell=True is dangerous


# ✅ Good: Least privilege, validate inputs, externalize secrets
import os
import re
from typing import Optional

def get_api_key() -> str:
    key = os.environ.get("REPORT_API_KEY")
    if not key:
        raise EnvironmentError("REPORT_API_KEY not set")
    return key

ALLOWED_COLUMNS = frozenset({"order_id", "customer_name", "total", "created_at"})

def run_report(column: str) -> list:
    if column not in ALLOWED_COLUMNS:
        raise ValueError(f"Column {column!r} not in allowed set: {ALLOWED_COLUMNS}")
    # Parameterized query — no string interpolation with user data
    return db.execute("SELECT ? FROM orders LIMIT 1000", (column,)).fetchall()
```

## Naming: When to Rename

```python
# ❌ Bad: Names that require comments to understand
def proc(d: dict, f: bool = False) -> list:  # What is d? What does f mean?
    res = []
    for k, v in d.items():
        if f:
            res.append((k, v * 1.1))         # 1.1 = ?
        else:
            res.append((k, v))
    return res

# ✅ Good: Names communicate intent; no comment needed
TAX_RATE = 1.10  # 10% tax

def apply_optional_tax(
    price_by_item: dict[str, float],
    include_tax: bool = False,
) -> list[tuple[str, float]]:
    if include_tax:
        return [(item, price * TAX_RATE) for item, price in price_by_item.items()]
    return list(price_by_item.items())
```

## Quick Reference

- **Lizard brain signal**: Discomfort when coding = stop and articulate what feels wrong before proceeding
- **Coincidence test**: Can you explain *why* every line works, not just *that* it works?
- **Big-O rule**: Profile first, optimize second — but estimate complexity before writing, then verify with timing tests
- **Refactoring two rules**: (1) No new features simultaneously. (2) Tests exist before you touch anything
- **Build end-to-end rule**: Build thin slices that work top-to-bottom; don't get lost in green-test glow without a destination
- **Design to test rule**: If writing the test is hard, redesign the interface — testability is a design signal not a test problem
- **Test your users rule**: If you don't test thoroughly, your users will test it for you — in production
- **Property test**: Find an invariant that must hold for all inputs (commutativity, idempotency, round-trip, identity)
- **Security patches**: Apply immediately — the window between disclosure and exploitation is often hours
- **Security minimum**: Validate all external input; apply least privilege; never hardcode secrets
- **Naming rule**: A name requiring a comment to understand is a bad name — rename it
