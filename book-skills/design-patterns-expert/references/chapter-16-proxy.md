# Chapter 16: Structural — Proxy

## Summary
Proxy provides a surrogate or placeholder for another object, controlling access to it.
The Proxy implements the same interface as the real subject, so the client can't tell
the difference. Three major variants exist: Virtual Proxy (defers expensive initialisation
until the object is actually needed), Protection Proxy (adds access control checks before
delegating), and Remote Proxy (handles network communication so clients call a local
object as if it were remote). The structure is identical to Decorator, but the intent
is control of access, not addition of behaviour.

## Key Principles
- **Same interface**: Proxy implements the exact same interface as the real subject — transparent substitution.
- **Virtual Proxy**: Lazy initialisation — creates the expensive real object only on first use.
- **Protection Proxy**: Checks permissions before forwarding calls to the real subject.
- **Caching Proxy**: Caches results of expensive operations on the real subject.
- **vs Decorator**: Both wrap objects with the same interface, but Proxy controls access while Decorator adds behaviour.

## Python Example

```python
from typing import Protocol, Optional
from functools import wraps
import time

# ❌ Bad: No proxy — every caller creates a DatabaseService immediately,
# paying full connection cost even if the db is never actually queried.
# class UserService:
#     def __init__(self):
#         self._db = DatabaseService("postgresql://prod-db/app")  # always expensive

# ✅ Good: Virtual Proxy — connection deferred until first actual use.

# ══════════════════════════════════════════════
# Subject interface
# ══════════════════════════════════════════════

class DataService(Protocol):
    def fetch(self, query: str) -> dict: ...
    def save(self, data: dict) -> bool: ...


# ══════════════════════════════════════════════
# Real subject — expensive to initialise
# ══════════════════════════════════════════════

class DatabaseService:
    def __init__(self, dsn: str) -> None:
        print(f"[DB] Connecting to {dsn}...")  # expensive
        time.sleep(0.001)  # simulate connection overhead
        self._dsn = dsn

    def fetch(self, query: str) -> dict:
        return {"result": f"data for '{query}' from {self._dsn}"}

    def save(self, data: dict) -> bool:
        print(f"[DB] Saving {data}")
        return True


# ══════════════════════════════════════════════
# Virtual Proxy — defers DB connection until first use
# ══════════════════════════════════════════════

class LazyDatabaseProxy:
    def __init__(self, dsn: str) -> None:
        self._dsn = dsn
        self._real: Optional[DatabaseService] = None  # not yet created

    def _get_real(self) -> DatabaseService:
        if self._real is None:
            self._real = DatabaseService(self._dsn)  # created on first access
        return self._real

    def fetch(self, query: str) -> dict:
        return self._get_real().fetch(query)

    def save(self, data: dict) -> bool:
        return self._get_real().save(data)


proxy = LazyDatabaseProxy("postgresql://prod-db:5432/myapp")
# No connection yet — expensive object not created
result = proxy.fetch("SELECT * FROM users LIMIT 1")
# Connection established only now (on first use)
assert "data for" in result["result"]


# ══════════════════════════════════════════════
# Protection Proxy — role-based access control
# ══════════════════════════════════════════════

class User:
    def __init__(self, name: str, role: str) -> None:
        self.name = name
        self.role = role

class ProtectedDatabaseProxy:
    def __init__(self, real: DataService, current_user: User) -> None:
        self._real = real
        self._user = current_user

    def fetch(self, query: str) -> dict:
        # All roles can read
        return self._real.fetch(query)

    def save(self, data: dict) -> bool:
        if self._user.role != "admin":
            raise PermissionError(f"User '{self._user.name}' is not allowed to write")
        return self._real.save(data)


real_db = DatabaseService("postgresql://prod-db:5432/myapp")
admin = User("Alice", "admin")
guest = User("Bob", "viewer")

admin_proxy = ProtectedDatabaseProxy(real_db, admin)
guest_proxy = ProtectedDatabaseProxy(real_db, guest)

assert admin_proxy.save({"id": 1}) is True

try:
    guest_proxy.save({"id": 2})
    assert False, "Should have raised"
except PermissionError as e:
    assert "not allowed" in str(e)


# ══════════════════════════════════════════════
# Caching Proxy
# ══════════════════════════════════════════════

class CachingProxy:
    def __init__(self, real: DataService, ttl_seconds: float = 60.0) -> None:
        self._real = real
        self._cache: dict[str, tuple[dict, float]] = {}
        self._ttl = ttl_seconds

    def fetch(self, query: str) -> dict:
        now = time.monotonic()
        if query in self._cache:
            data, ts = self._cache[query]
            if now - ts < self._ttl:
                print(f"[Cache HIT] {query}")
                return data
        result = self._real.fetch(query)
        self._cache[query] = (result, now)
        return result

    def save(self, data: dict) -> bool:
        self._cache.clear()  # invalidate on write
        return self._real.save(data)
```

## Quick Reference
- **Intent**: Control access to an object via a same-interface surrogate
- **Virtual Proxy**: Lazy init — defer expensive construction until first use
- **Protection Proxy**: ACL/permission checks before forwarding
- **Caching Proxy**: Memoize expensive `fetch` calls; invalidate on mutation
- **Remote Proxy**: Local stand-in that handles serialisation/network for remote objects
- **vs Decorator**: Same structure; Proxy = access control; Decorator = behaviour addition
- **vs Facade**: Facade simplifies a *subsystem*; Proxy controls access to a *single object*
- **Transparent**: Client code calls `proxy.fetch()` the same way it would call `real.fetch()`
- **Real uses**: ORM lazy loading, API rate-limiting wrappers, AWS SDK clients, memoisation, ACL middleware
