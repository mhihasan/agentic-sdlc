# Chapter 11: Systems

## Core Thesis
Cities work because they separate concerns: each team manages one domain (water, power, law). Software systems must do the same — **separate construction from use**, and modularize at the system level just as we modularize at the function/class level.

---

## Separate Construction from Use

The startup process (wiring objects together) must be separated from the runtime logic that uses those objects.

### Anti-Pattern: Lazy Initialization Scattered Everywhere

```python
# BAD: Construction mixed into runtime logic
class OrderService:
    def get_service(self):
        if self._service is None:
            self._service = MyServiceImpl(...)  # hard-coded dependency!
        return self._service

# Problems:
# 1. Hard-coded dependency on MyServiceImpl — can't swap implementations
# 2. Testing requires workarounds before calling get_service()
# 3. SRP violation: runtime logic AND construction responsibility
```

### Pattern 1: Separation via Main

```python
# main.py — construction happens here
def main():
    db = PostgresDatabase(url=settings.DATABASE_URL)
    user_repo = UserRepository(db)
    email_service = SmtpEmailService(settings.SMTP_URL)
    user_service = UserService(user_repo, email_service)
    app = create_app(user_service)
    app.run()

# app.py — uses objects; no construction here
def create_app(user_service: UserService) -> Flask:
    app = Flask(__name__)
    # ... register routes using user_service ...
    return app
```

### Pattern 2: Dependency Injection Container

```python
# Using a DI container (e.g., dependency-injector, lagom, or FastAPI's Depends)
from dependency_injector import containers, providers

class Container(containers.DeclarativeContainer):
    config = providers.Configuration()

    database = providers.Singleton(
        PostgresDatabase,
        url=config.database.url,
    )
    user_repository = providers.Factory(
        UserRepository,
        db=database,
    )
    email_service = providers.Singleton(
        SmtpEmailService,
        smtp_url=config.email.smtp_url,
    )
    user_service = providers.Factory(
        UserService,
        repo=user_repository,
        mailer=email_service,
    )

# Production wiring
container = Container()
container.config.from_yaml("settings.yml")

# Testing wiring — swap implementations
container.email_service.override(providers.Singleton(InMemoryEmailService))
```

---

## Cross-Cutting Concerns: AOP with Decorators

Concerns like logging, security, and transactions cut across many classes. In Python, decorators and context managers serve the same purpose as AOP proxies.

```python
# Security concern — don't scatter auth checks everywhere
import functools

def require_auth(role: str):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            current_user = get_current_user()
            if not current_user.has_role(role):
                raise PermissionError(f"Role '{role}' required")
            return func(*args, **kwargs)
        return wrapper
    return decorator

class OrderService:
    @require_auth("admin")
    def delete_order(self, order_id: int) -> None:
        self._repo.delete(order_id)

    @require_auth("user")
    def place_order(self, order: Order) -> None:
        self._repo.save(order)


# Transaction concern — don't scatter db.commit() everywhere
from contextlib import contextmanager

@contextmanager
def transaction(session):
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise

class UserRepository:
    def save(self, user: User) -> None:
        with transaction(self._session):
            self._session.add(user)
```

---

## Scaling Up

Good system design allows you to scale from simple to complex without rewriting. Start simple; let the system grow. Use DI to keep components loosely coupled.

```python
# Start simple: in-memory for day 1
class App:
    def __init__(self):
        self.user_repo = InMemoryUserRepository()
        self.order_repo = InMemoryOrderRepository()

# Scale up: swap to persistent storage — nothing else changes
class App:
    def __init__(self, db_session):
        self.user_repo = SqlUserRepository(db_session)
        self.order_repo = SqlOrderRepository(db_session)
```

---

# Chapter 12: Emergence

## Kent Beck's Four Rules of Simple Design (in priority order)

1. **Runs all the tests** — a system that can't be verified shouldn't be deployed
2. **Contains no duplication** — duplication is the primary enemy of a well-designed system
3. **Expresses the intent of the programmer** — future maintainers can understand it
4. **Minimizes the number of classes and methods**

### Rule 1: Tests Drive Better Design

Writing tests forces small, focused classes (SRP) and low coupling (DIP). You can't easily test a tightly coupled system.

```python
# Hard to test — tightly coupled
class ReportGenerator:
    def generate(self, user_id: int) -> str:
        user = PostgresDatabase().query(f"SELECT * FROM users WHERE id={user_id}")
        return f"Report for {user['name']}"

# Easy to test — dependencies injected
class ReportGenerator:
    def __init__(self, user_repo: UserRepository) -> None:
        self._repo = user_repo

    def generate(self, user_id: int) -> str:
        user = self._repo.find(user_id)
        return f"Report for {user.name}"

def test_report_generation():
    repo = InMemoryUserRepository([User(id=1, name="Alice")])
    gen = ReportGenerator(repo)
    assert gen.generate(1) == "Report for Alice"
```

### Rule 2: No Duplication

```python
# BAD: duplicated logic
class ImageProcessor:
    def scale_to_dimension(self, desired: float, actual: float) -> None:
        if abs(desired - actual) < ERROR_THRESHOLD:
            return
        factor = desired / actual
        new_image = ImageUtils.scale(self._image, factor)
        self._image.dispose()
        self._image = new_image

    def rotate(self, degrees: int) -> None:
        new_image = ImageUtils.rotate(self._image, degrees)
        self._image.dispose()  # duplicated!
        self._image = new_image  # duplicated!

# GOOD: extract duplicated structure
class ImageProcessor:
    def _replace_image(self, new_image) -> None:
        self._image.dispose()
        self._image = new_image

    def scale_to_dimension(self, desired: float, actual: float) -> None:
        if abs(desired - actual) < ERROR_THRESHOLD:
            return
        factor = desired / actual
        self._replace_image(ImageUtils.scale(self._image, factor))

    def rotate(self, degrees: int) -> None:
        self._replace_image(ImageUtils.rotate(self._image, degrees))
```

### Rule 3: Expressiveness

```python
# BAD: no expressiveness
def calc(x, y, op):
    if op == 0: return x + y
    if op == 1: return x - y
    if op == 2: return x * y

# GOOD: expressive
from enum import Enum

class Operation(Enum):
    ADD = "+"
    SUBTRACT = "-"
    MULTIPLY = "*"

def calculate(left: float, right: float, operation: Operation) -> float:
    match operation:
        case Operation.ADD:      return left + right
        case Operation.SUBTRACT: return left - right
        case Operation.MULTIPLY: return left * right
    raise ValueError(f"Unsupported operation: {operation}")
```

### Rule 4: Minimal Classes and Methods

Don't create classes/functions dogmatically. If SRP and no-duplication are satisfied, don't over-engineer.

```python
# Over-engineered: needless class proliferation
class NameValidator:
    def validate(self, name: str) -> bool: ...

class EmailValidator:
    def validate(self, email: str) -> bool: ...

# Good enough: a single validator module if the logic is simple
def is_valid_name(name: str) -> bool:
    return bool(name and len(name) <= 100)

def is_valid_email(email: str) -> bool:
    return "@" in email and "." in email.split("@")[-1]
```

---

# Chapter 13: Concurrency

## Core Thesis
Concurrency is **hard**. It decouples *what* is done from *when* it is done, which improves throughput but introduces subtle, intermittent, and non-reproducible bugs. Clean concurrency requires discipline and isolation.

---

## Concurrency Defense Principles

### 1. Single Responsibility for Concurrency Code

Concurrency code has its own lifecycle and complexity. Keep it separate from domain logic.

```python
# BAD: business logic and threading mixed together
import threading

class UserService:
    _lock = threading.Lock()
    _cache: dict = {}

    def get_user(self, user_id: int) -> User:
        with self._lock:
            if user_id not in self._cache:
                self._cache[user_id] = self._db.fetch(user_id)
            return self._cache[user_id]
    
    def calculate_discount(self, user: User) -> float:  # unrelated to threading
        return 0.1 if user.is_premium else 0.0

# GOOD: separate the concurrency concern
class ThreadSafeUserCache:
    """Handles concurrency only — no business logic."""
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._cache: dict[int, User] = {}

    def get_or_load(self, user_id: int, loader: Callable[[int], User]) -> User:
        with self._lock:
            if user_id not in self._cache:
                self._cache[user_id] = loader(user_id)
            return self._cache[user_id]

class UserService:
    """Business logic only — no threading awareness."""
    def __init__(self, cache: ThreadSafeUserCache, db: UserRepository) -> None:
        self._cache = cache
        self._db = db

    def get_user(self, user_id: int) -> User:
        return self._cache.get_or_load(user_id, self._db.fetch)

    def calculate_discount(self, user: User) -> float:
        return 0.1 if user.is_premium else 0.0
```

### 2. Limit Scope of Shared Data

```python
# BAD: many places can mutate shared state
class SharedCounter:
    count = 0  # class variable — global shared state!

def increment():
    SharedCounter.count += 1  # not thread-safe!

# GOOD: use thread-safe primitives
import threading

class SafeCounter:
    def __init__(self) -> None:
        self._count = 0
        self._lock = threading.Lock()

    def increment(self) -> None:
        with self._lock:
            self._count += 1

    def get(self) -> int:
        with self._lock:
            return self._count

# BETTER for simple counters: use atomic types from standard library
from multiprocessing import Value
import ctypes

counter = Value(ctypes.c_int, 0)
with counter.get_lock():
    counter.value += 1
```

### 3. Use Copies of Data

```python
# Avoid sharing mutable data — pass copies or immutable objects
import copy

class ReportJob:
    def __init__(self, data: list[dict]) -> None:
        self._data = copy.deepcopy(data)  # own copy — no shared mutation

    def process(self) -> str:
        return "\n".join(str(row) for row in self._data)
```

### 4. Thread-Local Storage

```python
import threading

# Each thread gets its own database connection
_thread_local = threading.local()

def get_db_connection():
    if not hasattr(_thread_local, "connection"):
        _thread_local.connection = create_db_connection()
    return _thread_local.connection
```

### 5. Python-Specific: Use asyncio for I/O Concurrency

```python
import asyncio
import httpx

# GOOD: async/await for I/O-bound concurrent work
async def fetch_user(client: httpx.AsyncClient, user_id: int) -> dict:
    response = await client.get(f"/api/users/{user_id}")
    response.raise_for_status()
    return response.json()

async def fetch_all_users(user_ids: list[int]) -> list[dict]:
    async with httpx.AsyncClient() as client:
        tasks = [fetch_user(client, uid) for uid in user_ids]
        return await asyncio.gather(*tasks)
```

### 6. Keep Synchronized Sections Small

```python
# BAD: holding lock during slow I/O
class UserService:
    def refresh_cache(self) -> None:
        with self._lock:
            users = self._db.fetch_all()  # slow! lock held during entire DB call
            self._cache = {u.id: u for u in users}

# GOOD: minimize critical section
class UserService:
    def refresh_cache(self) -> None:
        new_cache = {u.id: u for u in self._db.fetch_all()}  # no lock here
        with self._lock:
            self._cache = new_cache  # fast swap — lock held briefly
```

---

## Summary

| Concept | Key Rule |
|---|---|
| Systems | Separate construction from use; use DI |
| Cross-cutting concerns | Use decorators/context managers, not scattered code |
| Simple Design | Tests → No duplication → Expressive → Minimal |
| Concurrency | Separate concurrency code; limit shared data scope; keep locks small |
