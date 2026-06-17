# Chapter 4: Pragmatic Paranoia

## Summary
The pragmatic position is that you cannot write perfect software, and the correct response is not despair but structured defensiveness. This chapter covers five disciplines that make software robust in the face of imperfection: Design by Contract for specifying correctness, Dead Programs Tell No Lies for detecting corruption early, Assertive Programming for documenting impossible states, How to Balance Resources for ensuring cleanup always happens, and Don't Outrun Your Headlights for taking small, verifiable steps. The unifying theme is: program defensively against your own mistakes, not just external inputs.

## Key Principles

- **Design by Contract (DbC)**: Every function has preconditions (what caller must guarantee), postconditions (what function guarantees), and class invariants (always-true state properties). Make violations visible rather than silently producing wrong results.
- **Dead Programs Tell No Lies**: Crash early and loudly rather than limp forward on corrupted state. A process that halts immediately on detecting impossibility causes far less damage than one that continues corrupting data for an hour.
- **Crash Early — Supervisor Trees** (Tip 38): The Erlang/Elixir philosophy "let it crash" is correct: design programs to fail fast, managed by supervisors that know how to restart or clean up. A dead program does far less damage than a crippled one. In other languages: terminate as soon as an impossible state is detected; don't try to limp forward.
- **Assertive Programming**: Use assertions to document and enforce "this cannot happen" states. Assertions are executable documentation — never remove them for performance without profiling first.
- **Finish What You Start**: The function/object that allocates a resource is responsible for releasing it. Use context managers, RAII, or try/finally to ensure cleanup cannot be skipped, even on exceptions.
- **Act Locally** (Tip 41): Nested allocations must be deallocated in the **opposite order** they were allocated — this prevents orphaned resources and deadlocks. When allocating the same set of resources in multiple places, always allocate them in the **same order** everywhere to prevent circular waits.
- **Don't Outrun Your Headlights**: Take small steps with feedback at each one. Never make large jumps based on assumptions that can't be verified. When uncertain, ask: "What's the smallest step that gives me real information?"
- **Avoid Fortune-Telling** (Tip 43): Don't design for an imagined future that may never arrive. The only way to know what's needed is to take small steps and get feedback. Technologies adopted speculatively (Tip 43's Motif vs. OpenLook example) lock you into a future that didn't happen.

## Python Example: Design by Contract and Resource Balancing

```python
# ❌ Bad: No contracts, no cleanup guarantee, silent corruption
def transfer_funds(from_account, to_account, amount):
    from_account.balance -= amount   # what if amount is negative?
    # Exception here → to_account never credited, from_account already debited
    to_account.balance += amount
    db.commit()  # might not be reached


# ✅ Good: DbC preconditions + resource cleanup guarantee
from contextlib import contextmanager
from typing import Generator

class InsufficientFundsError(ValueError):
    pass

class Account:
    def __init__(self, balance: float):
        assert balance >= 0, "Account balance cannot be negative (invariant)"
        self._balance = balance

    def debit(self, amount: float) -> None:
        # Precondition
        if amount <= 0:
            raise ValueError(f"Debit amount must be positive, got {amount}")
        if amount > self._balance:
            raise InsufficientFundsError(
                f"Insufficient funds: have {self._balance}, need {amount}"
            )
        self._balance -= amount
        # Postcondition
        assert self._balance >= 0, "Balance went negative — invariant violated"

    def credit(self, amount: float) -> None:
        if amount <= 0:
            raise ValueError(f"Credit amount must be positive, got {amount}")
        self._balance += amount

    @property
    def balance(self) -> float:
        return self._balance


@contextmanager
def atomic_transfer(
    db_session,
) -> Generator[None, None, None]:
    """Guarantee: either commit or rollback — resource always balanced."""
    try:
        yield
        db_session.commit()
    except Exception:
        db_session.rollback()   # cleanup always happens
        raise


def transfer_funds(
    from_acct: Account,
    to_acct: Account,
    amount: float,
    db_session,
) -> None:
    # Precondition check via DbC (Account.debit raises on violation)
    with atomic_transfer(db_session):
        from_acct.debit(amount)
        to_acct.credit(amount)
        # Both succeed or both roll back — no partial state


# Verify contracts hold
acct_a = Account(1000.0)
acct_b = Account(500.0)
try:
    acct_a.debit(-50)
except ValueError as e:
    assert "positive" in str(e)  # precondition enforced
```

## Assertive Programming: Document Impossibility

```python
# ❌ Bad: Silently accepting impossible state, continuing with corrupted data
def process_event(event_type: str, payload: dict):
    if event_type == "order.created":
        handle_order(payload)
    elif event_type == "payment.received":
        handle_payment(payload)
    # Unknown event_type? Silently ignored — hidden bug for months


# ✅ Good: Assert the impossible, crash loudly
from enum import Enum

class EventType(Enum):
    ORDER_CREATED = "order.created"
    PAYMENT_RECEIVED = "payment.received"
    SHIPMENT_DISPATCHED = "shipment.dispatched"

def process_event(event_type: EventType, payload: dict) -> None:
    match event_type:
        case EventType.ORDER_CREATED:
            handle_order(payload)
        case EventType.PAYMENT_RECEIVED:
            handle_payment(payload)
        case EventType.SHIPMENT_DISPATCHED:
            handle_shipment(payload)
        case _:
            # This cannot happen if the type system is correct
            # If it does, crash now — don't limp forward
            raise AssertionError(
                f"Unhandled event type {event_type!r} — "
                "update process_event when adding new event types"
            )
```

## Small Steps: Don't Outrun Headlights

```python
# ❌ Bad: Large speculative change with no incremental verification
def migrate_users_to_new_schema():
    users = db.query("SELECT * FROM users")         # could be 10M rows
    for user in users:
        new_format = transform_user_schema(user)    # untested transform
        db.insert("users_v2", new_format)           # irreversible
    db.drop_table("users")                          # no going back

# ✅ Good: Small steps, each verifiable
def migrate_users_incremental(batch_size: int = 1000) -> None:
    """Migrate in small batches with verification at each step."""
    total = db.count("users")
    migrated = 0

    for offset in range(0, total, batch_size):
        batch = db.query("SELECT * FROM users LIMIT ? OFFSET ?",
                         batch_size, offset)
        new_rows = [transform_user_schema(u) for u in batch]

        # Verify transformation before writing
        for original, transformed in zip(batch, new_rows):
            assert transformed["user_id"] == original["id"], \
                f"ID mismatch at offset {offset}"

        db.insert_batch("users_v2", new_rows)
        migrated += len(batch)
        print(f"Migrated {migrated}/{total} — checkpoint: safe to resume from here")
```

## Quick Reference

- **DbC contract**: Preconditions = caller's promise; postconditions = function's promise; invariants = always true
- **Crash Early rule**: A terminated process can't corrupt data; a limping one can corrupt it for hours — let it crash, design with supervisors
- **Assertions**: Never use `assert` to validate external input (use explicit `if/raise`); use it for internal invariants
- **Resource balance rule**: Who allocates, deallocates — use `with` / context managers, not try/finally chains
- **Nested allocation order**: Deallocate in reverse order of allocation; allocate in the same order everywhere to prevent deadlocks
- **Small steps rule**: Each step should be verifiable; never make 5 assumptions at once before getting feedback
- **Avoid Fortune-Telling**: Don't lock in architectural decisions for a future that may never arrive; take small steps and learn
