# Chapter 6: Concurrency

## Summary
Concurrency is when code *acts as if* it runs simultaneously; parallelism is when it *does* run simultaneously. This distinction matters because concurrency is a design concern (how you structure code) while parallelism is a runtime concern (how hardware executes it). The chapter covers four strategies: workflow analysis to find natural concurrency, mutual exclusion for shared resources, the actor model to eliminate sharing entirely, and blackboards for loosely coordinated multi-agent systems. The core insight: shared mutable state is the root of nearly all concurrency bugs.

## Key Principles

- **Analyze Workflow for Concurrency**: Before writing any concurrent code, map out what must happen sequentially and what can happen in parallel. Activity diagrams reveal natural concurrency that sequential code hides.
- **Shared State Is Incorrect State**: If two processes can access the same mutable resource without synchronization, you have a bug — even if it doesn't manifest immediately. Semaphores, transactions, and atomic operations are the remedies.
- **Semaphores and Mutual Exclusion**: A semaphore is a flag that only one party can hold at a time. Databases use transactions; file systems use locks; application code should use language primitives (`asyncio.Lock`, threading `Lock`, database row locks).
- **Random Failures Are Concurrency Issues**: Non-deterministic, "cannot reproduce" bugs are almost always concurrency problems. When you see them: look for shared state.
- **Actors: No Shared State**: The actor model guarantees no race conditions by construction — actors own their state exclusively and communicate only via asynchronous messages. Erlang/OTP pioneered this; Python has `asyncio`, `multiprocessing` actors, and frameworks like `Pykka`.
- **Blackboards**: A shared knowledge store where independent agents post and read facts. No agent knows about other agents — just the blackboard. Natural for AI inference systems, event-driven architectures, and rule engines.

## Python Example: Shared State Bug and Semaphore Fix

```python
import asyncio
from dataclasses import dataclass

# ❌ Bad: Classic TOCTOU (Time of Check to Time of Use) race condition
@dataclass
class Seat:
    available: bool = True

async def book_seat_unsafe(seat: Seat, user: str) -> bool:
    if seat.available:                  # CHECK
        await asyncio.sleep(0)          # Another coroutine runs here!
        seat.available = False          # USE — now two users have "booked" it
        print(f"{user} booked seat")
        return True
    return False

# ✅ Good: Semaphore ensures mutual exclusion
async def book_seat_safe(
    seat: Seat,
    user: str,
    lock: asyncio.Lock,
) -> bool:
    async with lock:                    # Only one coroutine enters at a time
        if seat.available:
            seat.available = False
            print(f"{user} booked seat")
            return True
        return False

async def demo_race_condition():
    seat = Seat()
    lock = asyncio.Lock()

    # Simulate two concurrent booking attempts
    results = await asyncio.gather(
        book_seat_safe(seat, "Alice", lock),
        book_seat_safe(seat, "Bob", lock),
    )
    # Exactly one True, one False — no double booking
    assert results.count(True) == 1, f"Double booking! {results}"
    print(f"Results: {results}")  # [True, False] or [False, True]
```

## Actor Model: Message-Passing Without Locks

```python
import asyncio
from asyncio import Queue
from dataclasses import dataclass
from typing import Any

@dataclass
class Message:
    type: str
    payload: Any
    reply_to: Queue | None = None

async def inventory_actor(inbox: Queue) -> None:
    """
    Owns inventory state exclusively.
    No other actor reads or writes inventory directly.
    """
    inventory: dict[str, int] = {"item_A": 100, "item_B": 50}

    while True:
        msg: Message = await inbox.get()

        if msg.type == "check_stock":
            item = msg.payload
            stock = inventory.get(item, 0)
            if msg.reply_to:
                await msg.reply_to.put({"item": item, "stock": stock})

        elif msg.type == "reserve":
            item, qty = msg.payload["item"], msg.payload["qty"]
            if inventory.get(item, 0) >= qty:
                inventory[item] -= qty
                if msg.reply_to:
                    await msg.reply_to.put({"success": True})
            else:
                if msg.reply_to:
                    await msg.reply_to.put({"success": False, "reason": "insufficient stock"})

        elif msg.type == "stop":
            break

async def checkout_actor(inventory_inbox: Queue) -> None:
    """Coordinates checkout — sends messages, never touches inventory directly."""
    reply_queue: Queue = Queue()

    # Check stock
    await inventory_inbox.put(Message("check_stock", "item_A", reply_queue))
    stock_info = await reply_queue.get()
    print(f"Stock check: {stock_info}")

    # Reserve
    await inventory_inbox.put(Message(
        "reserve", {"item": "item_A", "qty": 3}, reply_queue
    ))
    result = await reply_queue.get()
    print(f"Reservation: {result}")

    await inventory_inbox.put(Message("stop", None))

async def main():
    inventory_inbox: Queue = Queue()
    inv = asyncio.create_task(inventory_actor(inventory_inbox))
    checkout = asyncio.create_task(checkout_actor(inventory_inbox))
    await asyncio.gather(inv, checkout)
```

## Blackboard Pattern

```python
# Blackboard: shared knowledge store; agents post facts independently
from threading import Lock
from typing import Callable

class Blackboard:
    """Loosely-coupled coordination — agents know the blackboard, not each other."""

    def __init__(self):
        self._facts: dict = {}
        self._lock = Lock()
        self._listeners: list[Callable] = []

    def post(self, key: str, value) -> None:
        with self._lock:
            self._facts[key] = value
        for listener in self._listeners:
            listener(key, value)  # notify interested agents

    def read(self, key: str):
        with self._lock:
            return self._facts.get(key)

    def subscribe(self, listener: Callable) -> None:
        self._listeners.append(listener)

# Usage: fraud detection agents post independently
board = Blackboard()

def geo_agent():
    board.post("login_country", "NG")
    board.post("account_country", "CA")

def fraud_rule_agent(key: str, value) -> None:
    if key in ("login_country", "account_country"):
        login = board.read("login_country")
        account = board.read("account_country")
        if login and account and login != account:
            board.post("fraud_alert", {"reason": "geo_mismatch", "login": login})

board.subscribe(fraud_rule_agent)
geo_agent()
print(board.read("fraud_alert"))  # {"reason": "geo_mismatch", "login": "NG"}
```

## Quick Reference

- **Concurrency vs. parallelism**: Concurrency = design structure; parallelism = runtime execution
- **Workflow analysis**: Map sequential dependencies first; everything else is a parallelism candidate
- **Semaphore rule**: Lock the *check and modify* as one atomic operation — never check then lock separately
- **Random failures = concurrency bug**: Add logging of thread/task IDs before investigating anything else
- **Actor rule**: One actor owns each piece of mutable state; others send messages to request changes
- **Blackboard rule**: Agents only depend on the blackboard schema, not on each other
