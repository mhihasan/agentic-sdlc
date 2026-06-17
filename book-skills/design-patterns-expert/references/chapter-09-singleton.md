# Chapter 9: Creational — Singleton

## Summary
Singleton ensures a class has only one instance and provides a global access point to it.
The two core problems it solves are: preventing multiple instantiations of a resource that
must be shared (database connection pool, config store, logger), and providing a well-known
global access point without polluting the module namespace with bare globals. In Python, the
module system already acts as a natural singleton — a module is imported once and cached.
The explicit Singleton class pattern is therefore rarely needed in Python, but understanding
it is essential for recognising and replacing heavyweight singletons in other languages'
codebases you will inevitably encounter.

## Key Principles
- **Single instance guarantee**: Constructor logic is hidden; all clients receive the same object.
- **Global access point**: Unlike a bare global variable, the Singleton controls its own initialisation and can be lazy.
- **Thread safety**: In concurrent code, the instance creation must be protected or use a language-safe mechanism.
- **Python idiom — module-level**: A module imported anywhere in a Python process is the same object; use module-level state as the idiomatic singleton.
- **Singleton is often a design smell**: If you find yourself needing Singleton for everything, it usually means hidden global state and tight coupling. Prefer dependency injection.

## Python Example

```python
import threading
from typing import Optional

# ❌ Bad: Bare global — no initialisation control, no thread safety guarantee
_connection_pool = None  # anyone can set this to None again accidentally

def get_pool():
    global _connection_pool
    if _connection_pool is None:
        _connection_pool = connect()  # race condition in threads
    return _connection_pool


# ✅ Good Option 1: Classic thread-safe Singleton class

class DatabasePool:
    _instance: Optional["DatabasePool"] = None
    _lock: threading.Lock = threading.Lock()

    def __new__(cls) -> "DatabasePool":
        if cls._instance is None:
            with cls._lock:
                # Double-checked locking
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialised = False
        return cls._instance

    def __init__(self) -> None:
        if self._initialised:
            return
        self._pool: list[str] = ["conn1", "conn2", "conn3"]
        self._initialised = True

    def acquire(self) -> str:
        return self._pool.pop()

    def release(self, conn: str) -> None:
        self._pool.append(conn)


pool_a = DatabasePool()
pool_b = DatabasePool()
assert pool_a is pool_b  # same instance


# ✅ Good Option 2: Metaclass-based Singleton

class SingletonMeta(type):
    _instances: dict = {}
    _lock: threading.Lock = threading.Lock()

    def __call__(cls, *args, **kwargs):
        with cls._lock:
            if cls not in cls._instances:
                cls._instances[cls] = super().__call__(*args, **kwargs)
        return cls._instances[cls]


class AppConfig(metaclass=SingletonMeta):
    def __init__(self) -> None:
        self.debug = False
        self.db_url = "postgresql://localhost/mydb"

cfg1 = AppConfig()
cfg2 = AppConfig()
assert cfg1 is cfg2


# ✅ Good Option 3: Python idiom — module-level singleton (preferred)
# config.py
# ─────────────────────────────────────────────
# db_url = "postgresql://localhost/mydb"
# debug = False
# ─────────────────────────────────────────────
# Anywhere in the codebase:
# import config
# config.db_url  → always the same module object

# ✅ Good Option 4: Dependency injection (best for testability)
class Cache:
    def __init__(self) -> None:
        self._store: dict = {}

    def get(self, key: str):
        return self._store.get(key)

    def set(self, key: str, value) -> None:
        self._store[key] = value

# One instance created at startup, injected where needed — easy to swap in tests
cache = Cache()

class UserService:
    def __init__(self, cache: Cache) -> None:
        self._cache = cache  # injected — not fetched from a global

svc = UserService(cache)
# In tests: UserService(Cache())  ← fresh isolated instance per test
```

## Quick Reference
- **Intent**: Ensure one instance exists; provide global access to it
- **Use when**: Shared resource (DB pool, config, logger) must not be duplicated
- **Thread safety**: Use `threading.Lock` with double-checked locking or `SingletonMeta`
- **Python idiom**: Module-level variables are singletons by default — prefer this over `__new__` tricks
- **Best practice**: Inject the shared instance via `__init__` rather than having classes fetch it globally
- **Testing pain**: Global singletons make unit tests stateful and order-dependent — DI solves this
- **Smell**: If >3 classes import the same singleton directly, it's hidden global coupling — refactor to DI
- **vs Borg pattern**: Borg shares state between instances (all instances have same `__dict__`); Singleton shares identity
