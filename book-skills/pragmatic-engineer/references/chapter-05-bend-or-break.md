# Chapter 5: Bend, or Break

## Summary
This chapter is about writing code flexible enough to survive a changing world. Nine topics collectively address how coupling, inheritance, configuration, temporal dependencies, shared state, actor concurrency, and blackboards each contribute to or undermine flexibility. The central message: tightly coupled code becomes a liability the moment requirements change. Decouple aggressively, program to interfaces not implementations, treat configuration as data, avoid shared mutable state, and model concurrency through message-passing rather than locks.

## Key Principles

- **Decoupling**: Symptoms of coupling — changes ripple, tests require huge setups, "simple" fixes touch many files. Fix: depend on abstractions, apply Law of Demeter, avoid method chaining across ownership boundaries.
- **Tell, Don't Ask**: Don't query an object's state to decide what to do with it — tell it what to do. This keeps decision logic in the right place and prevents objects from being turned into data structures.
- **Don't Chain Method Calls** (Tip 46): `a.b.c.d()` is a coupling chain — your code now depends on `a`'s structure, `b`'s structure, `c`'s structure, and `d`'s behavior. One change to any link breaks all callers.
- **Avoid Global Data** (Tip 47): Every reference to global state couples every module that touches it. If it's important enough to be global, wrap it in an API (Tip 48) so callers depend on the interface, not the representation.
- **If It's Important Enough to Be Global, Wrap It in an API** (Tip 48): Global state can't be avoided entirely — but access to it should always go through a function/method, never through direct variable access. This lets you change the implementation without breaking callers.
- **Juggling the Real World**: Four strategies for handling events — Finite State Machines for structured state transitions, Observer/Publish-Subscribe for decoupled notification, Reactive Streams for backpressure-controlled pipelines.
- **Transforming Programming — Programs Are About Data** (Tips 49-50): Think of programs as pipelines of data transformations. Data flows in, gets transformed, flows out. Don't hoard state in objects; pass it through transformations. A pipeline is: `code → data → code → data`. This reduces coupling because a function can be reused anywhere its parameter types match.
- **Inheritance Tax**: Inheritance couples you to a superclass's implementation. Prefer interfaces/protocols, mixins, and delegation. Three alternatives that are usually better:
  - **Prefer Interfaces / Protocols** (Tip 52): Express polymorphism through structural typing — callers depend on capabilities, not on class hierarchy.
  - **Delegate to Services: Has-A Trumps Is-A** (Tip 53): If an object *uses* another object's capabilities, inject it as a collaborator. Composition is more flexible and testable than inheritance.
  - **Use Mixins to Share Functionality** (Tip 54): Use mixins or traits for cross-cutting behaviour (logging, serialisation, validation) rather than pulling it into a base class that couples everything.
- **Configuration as Data / Config-as-a-Service** (Tip 55): Parameterize anything that will change between environments. Prefer a configuration service API over flat files for shared, dynamically-updated configuration — multiple apps can read it with proper access control, and changes take effect without restarting services.
- **Breaking Temporal Coupling**: Don't force sequential execution when work could be parallel. Identify what *must* happen before what, model as workflow, make everything else concurrent-capable.
- **Shared State Is Incorrect State**: Two processes sharing a resource without synchronization produces non-deterministic bugs. Either use semaphores/transactions (risky) or eliminate sharing via message passing (safer).
- **Actors and Processes**: Actors run independently, communicate only via messages, share no mutable state. Natural concurrency model — no locks, no races, failures are isolated.

## Python Example: Decoupling and Tell, Don't Ask

```python
# ❌ Bad: Ask-then-decide (bad coupling; UserManager knows User internals)
class UserManager:
    def notify_if_premium(self, user):
        if user.subscription_type == "premium" and user.email_verified:
            if not user.notification_sent_today:
                email_service.send(user.email, "Premium offer")
                user.notification_sent_today = True
        # UserManager is doing User's job AND knows its private state


# ✅ Good: Tell, Don't Ask — objects manage their own state
from typing import Protocol

class Notifiable(Protocol):
    def notify_premium_offer(self) -> bool:
        """Returns True if notification was sent."""
        ...

class User:
    def __init__(self, email: str, subscription: str, email_verified: bool):
        self._email = email
        self._subscription = subscription
        self._email_verified = email_verified
        self._notified_today = False

    def notify_premium_offer(self) -> bool:
        """User decides if it's eligible; manager just asks."""
        if (self._subscription == "premium"
                and self._email_verified
                and not self._notified_today):
            email_service.send(self._email, "Premium offer")
            self._notified_today = True
            return True
        return False

class UserManager:
    def notify_all_premium(self, users: list[Notifiable]) -> int:
        return sum(1 for u in users if u.notify_premium_offer())
```

## Inheritance Tax: Prefer Composition and Protocols

```python
# ❌ Bad: Deep inheritance hierarchy — coupled to parent's implementation
class Animal:
    def breathe(self): ...
    def eat(self): ...

class Pet(Animal):
    def be_loved(self): ...

class Dog(Pet):
    def fetch(self): ...  # Now Dog depends on Animal AND Pet internals


# ✅ Good: Protocols (structural typing) + composition
from typing import Protocol

class Fetchable(Protocol):
    def fetch(self, item: str) -> str: ...

class Lovable(Protocol):
    def respond_to_affection(self) -> str: ...

class Dog:
    """Dog satisfies Fetchable and Lovable without inheriting from either."""
    def __init__(self, name: str):
        self._name = name
        self._tricks = TrickTrainer()   # composition

    def fetch(self, item: str) -> str:
        return f"{self._name} fetches {item}!"

    def respond_to_affection(self) -> str:
        return f"{self._name} wags tail."

def play_fetch(pet: Fetchable) -> None:
    print(pet.fetch("ball"))

play_fetch(Dog("Rex"))  # works without Dog inheriting from any base class
```

## Configuration as Late-Bound Data

```python
# ❌ Bad: Environment-specific values hardcoded in source
class PaymentService:
    API_KEY = "sk_prod_abc123"           # in source code!
    BASE_URL = "https://api.stripe.com"  # can't change without redeploy

# ✅ Good: Config loaded at startup, never in module scope
import os
from dataclasses import dataclass

@dataclass(frozen=True)
class PaymentConfig:
    api_key: str
    base_url: str
    timeout_seconds: int

    @classmethod
    def from_env(cls) -> "PaymentConfig":
        return cls(
            api_key=os.environ["PAYMENT_API_KEY"],
            base_url=os.environ.get("PAYMENT_BASE_URL", "https://api.stripe.com"),
            timeout_seconds=int(os.environ.get("PAYMENT_TIMEOUT", "30")),
        )

# Config is externalized, environment-specific, late-binding
cfg = PaymentConfig.from_env()
```

## Actor Model (No Shared State)

```python
# ❌ Bad: Shared mutable counter — race condition under concurrency
import threading

counter = 0  # shared mutable state

def increment():
    global counter
    counter += 1  # read-modify-write is NOT atomic in Python without GIL guarantees

# ✅ Good: Message-passing actor pattern — each actor owns its own state
import asyncio
from asyncio import Queue

async def counter_actor(inbox: Queue) -> None:
    """This actor is the ONLY entity that modifies count."""
    count = 0
    while True:
        message = await inbox.get()
        if message == "increment":
            count += 1
        elif message == "get":
            # In a real actor system, reply_to would be a response queue
            print(f"Current count: {count}")
        elif message == "stop":
            break

async def main():
    inbox: Queue = Queue()
    actor = asyncio.create_task(counter_actor(inbox))
    for _ in range(1000):
        await inbox.put("increment")   # no locks — one owner
    await inbox.put("get")
    await inbox.put("stop")
    await actor
```

## Configuration as a Service (Tip 55)

```python
# ❌ Bad: Config as a flat global variable — everyone accesses it directly
CONFIG = {"db_url": "postgres://prod", "timeout": 30}  # global, hard to change

def get_timeout():
    return CONFIG["timeout"]  # all callers coupled to CONFIG dict structure


# ✅ Good: Config wrapped in an API (Tip 48 + 55) — change internals without breaking callers
import os
from functools import lru_cache

class ConfigService:
    """Thin API over config source — source can change (env, file, service) transparently."""

    @lru_cache(maxsize=None)
    def get(self, key: str, default: str = "") -> str:
        # Could swap this for a remote config service (AWS Parameter Store, etc.)
        return os.environ.get(key, default)

    def db_url(self) -> str:
        return self.get("DATABASE_URL")

    def timeout_seconds(self) -> int:
        return int(self.get("REQUEST_TIMEOUT", "30"))

config = ConfigService()

def get_timeout() -> int:
    return config.timeout_seconds()  # callers depend on the API, not the storage format
```

## Transforming Programming (Tips 49-50)

```python
# ❌ Bad: Hoarding state in objects — data trapped inside class boundaries
class WordGameProcessor:
    def __init__(self, letters: str):
        self._letters = letters
        self._combinations = []
        self._signatures = {}
        self._matches = []

    def process(self):
        self._build_combinations()
        self._compute_signatures()
        self._find_matches()
        return self._matches  # state scattered across 4 attributes


# ✅ Good: Data flows through transformations — each step is independently testable
from itertools import combinations
from typing import Iterator

def letter_combinations(letters: str, min_len: int = 3) -> Iterator[str]:
    """Step 1: Generate all combinations of sufficient length."""
    for length in range(min_len, len(letters) + 1):
        for combo in combinations(letters, length):
            yield ''.join(combo)

def signature(word: str) -> str:
    """Step 2: Canonical form — anagrams share the same signature."""
    return ''.join(sorted(word))

def find_words(letters: str, dictionary: dict[str, list[str]]) -> list[str]:
    """Pipeline: letters → combinations → signatures → dictionary lookups → words."""
    return [
        word
        for combo in letter_combinations(letters)
        for word in dictionary.get(signature(combo), [])
    ]

# Each transformation is a pure function: testable, reusable, composable
assert signature("vinyl") == signature("linvy")  # same letters → same signature
```

## Quick Reference

- **Law of Demeter test**: `a.b.c.do_thing()` — method chains crossing ownership boundaries signal coupling
- **Tell, Don't Ask test**: Are you querying an object's state to make a decision? Move that decision into the object
- **Don't Chain test**: Count the dots. Two levels deep is suspicious; three or more is a coupling smell
- **Global data rule**: Never access global state directly; wrap it in a function/API so the representation can change
- **Transforming programming test**: Can you describe your program as a pipeline? `input → f1 → f2 → f3 → output`? If not, consider why not
- **Inheritance tax rule**: Before using inheritance, ask "can I use Protocol + delegation instead?" Usually: yes
- **Config rule**: If a value changes between dev/staging/prod, it's config — not code; prefer a config service over flat files for shared multi-app configuration
- **Temporal coupling test**: Draw a dependency graph of your steps. Everything that could be parallel, should be
- **Shared state rule**: Two concurrent writers to the same resource = non-deterministic bug waiting to happen
- **Actor rule**: Actors communicate only through messages — no shared references to mutable data
