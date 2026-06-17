# Chapter 7: Error Handling

## Core Thesis
Error handling is important, but if it **obscures logic, it's wrong**. Clean error handling keeps the happy path readable and separates error-handling concerns from business logic.

---

## Rules

### 1. Use Exceptions Rather Than Return Codes

Return codes force callers to check immediately, cluttering call sites and making it easy to forget to check.

```python
# BAD: error code style
E_OK = 0
E_ERROR = -1

def send_shutdown(device_id: str) -> int:
    handle = get_handle(device_id)
    if handle == INVALID_HANDLE:
        logger.error(f"Invalid handle for: {device_id}")
        return E_ERROR
    if get_device_record(handle).status == SUSPENDED:
        logger.error("Device suspended. Unable to shut down")
        return E_ERROR
    pause_device(handle)
    clear_device_work_queue(handle)
    close_device(handle)
    return E_OK

# Caller must check every time — easy to forget
if send_shutdown("DEV1") != E_OK:
    handle_error()

# GOOD: exception style — happy path is uncluttered
def send_shutdown(device_id: str) -> None:
    try:
        _shut_down_device(device_id)
    except DeviceShutdownError as e:
        logger.error(e)

def _shut_down_device(device_id: str) -> None:
    handle = get_handle(device_id)
    record = retrieve_device_record(handle)
    pause_device(handle)
    clear_device_work_queue(handle)
    close_device(handle)
```

### 2. Write Try/Except First (TDD Approach)

When writing code that can fail, write the try/except scaffold first — it defines the contract.

```python
# Start with the test that expects an exception
import pytest

def test_retrieve_section_raises_on_missing_file():
    store = SectionStore()
    with pytest.raises(StorageError):
        store.retrieve_section("nonexistent-file")

# Then write the implementation stub
class SectionStore:
    def retrieve_section(self, section_name: str) -> list:
        try:
            with open(section_name) as f:
                return self._parse(f)
        except FileNotFoundError as e:
            raise StorageError(f"Section not found: {section_name}") from e
```

### 3. Use Unchecked Exceptions (Python default)

Python only has unchecked exceptions, which is correct. Checked exceptions (Java) break encapsulation — every level of the call stack must know about low-level failures.

```python
# Python naturally does this right:
# Low-level function raises specific error
def read_config(path: str) -> dict:
    with open(path) as f:  # raises FileNotFoundError if missing
        return json.load(f)  # raises json.JSONDecodeError if invalid

# High-level code only catches what it can handle
def load_app_config() -> AppConfig:
    try:
        return AppConfig.from_dict(read_config("config.json"))
    except (FileNotFoundError, json.JSONDecodeError) as e:
        raise ConfigurationError("Failed to load app config") from e
```

### 4. Provide Context with Exceptions

Exceptions must have enough context to debug the problem. Include: what operation failed, with what data, and why.

```python
# BAD: context-free
raise ValueError("Invalid input")
raise RuntimeError("Failed")

# GOOD: context-rich
raise ValueError(
    f"Invalid email format: '{email}'. "
    f"Expected format: user@domain.tld"
)

# GOOD: chain exceptions to preserve original cause
try:
    result = db.execute(query)
except DatabaseError as e:
    raise DataAccessError(
        f"Failed to fetch user with id={user_id}: {e}"
    ) from e  # 'from e' preserves the original traceback
```

### 5. Define Exception Classes by Caller's Needs

Group exceptions at the level of abstraction the caller cares about. Don't expose third-party exceptions through your API boundary.

```python
# BAD: caller must know about ALL third-party exception types
import requests

def fetch_user(user_id: int) -> dict:
    response = requests.get(f"/api/users/{user_id}")
    response.raise_for_status()
    return response.json()

# Caller must handle: ConnectionError, Timeout, HTTPError, JSONDecodeError...
try:
    user = fetch_user(42)
except requests.ConnectionError:
    ...
except requests.Timeout:
    ...
except requests.HTTPError:
    ...

# GOOD: wrap third-party exceptions in your own hierarchy
class UserServiceError(Exception):
    """Base error for UserService operations."""

class UserNotFoundError(UserServiceError):
    """Raised when a user doesn't exist."""

class UserServiceUnavailableError(UserServiceError):
    """Raised when the user service cannot be reached."""

class UserService:
    def fetch_user(self, user_id: int) -> dict:
        try:
            response = requests.get(f"/api/users/{user_id}", timeout=5)
            if response.status_code == 404:
                raise UserNotFoundError(f"User {user_id} not found")
            response.raise_for_status()
            return response.json()
        except requests.ConnectionError as e:
            raise UserServiceUnavailableError("User service is unreachable") from e
        except requests.Timeout as e:
            raise UserServiceUnavailableError("User service timed out") from e

# Caller only needs to know your exceptions
try:
    user = service.fetch_user(42)
except UserNotFoundError:
    return 404_response()
except UserServiceUnavailableError:
    return 503_response()
```

### 6. Special Case Pattern (Null Object / Default Object)

Instead of returning `None` and forcing every caller to null-check, return a special-case object that has safe default behavior.

```python
# BAD: returns None, forcing every caller to check
def get_employee_meals_per_diem(employee_id: int) -> float | None:
    employee = find_employee(employee_id)
    if employee is None:
        return None  # every caller must check this!
    return employee.get_meals_per_diem()

# Every call site is polluted:
per_diem = get_employee_meals_per_diem(employee_id)
if per_diem is not None:
    total += per_diem

# GOOD: Special Case / Null Object pattern
class NullEmployee:
    def get_meals_per_diem(self) -> float:
        return 0.0  # safe default

    def get_name(self) -> str:
        return "Unknown"

def find_employee(employee_id: int) -> Employee | NullEmployee:
    result = db.query(employee_id)
    return result if result else NullEmployee()

# Call site is clean:
employee = find_employee(employee_id)
total += employee.get_meals_per_diem()  # always safe
```

### 7. Don't Return None — Don't Pass None

Returning `None` requires every caller to defend against it. Passing `None` as an argument creates hidden coupling.

```python
# BAD: returning None propagates null-checks everywhere
def get_user(user_id: int) -> User | None:
    return db.find_user(user_id)  # might be None

# BAD: passing None as argument
def calculate_pay(employee, bonus_rate=None):
    if bonus_rate is None:
        bonus_rate = DEFAULT_BONUS_RATE
    ...

# GOOD: raise early, return defaults, use Optional type hints honestly
def get_user(user_id: int) -> User:
    user = db.find_user(user_id)
    if user is None:
        raise UserNotFoundError(f"User {user_id} does not exist")
    return user

# GOOD: use default values explicitly
def calculate_pay(employee: Employee, bonus_rate: float = DEFAULT_BONUS_RATE) -> float:
    return employee.base_pay * (1 + bonus_rate)
```

---

## Exception Hierarchy Design

```python
# Good exception hierarchy for a service
class AppError(Exception):
    """Base error for this application."""

class ValidationError(AppError):
    """Input failed validation rules."""

class NotFoundError(AppError):
    """Requested resource doesn't exist."""

class ConflictError(AppError):
    """Operation conflicts with current state."""

class ExternalServiceError(AppError):
    """A call to an external dependency failed."""

class DatabaseError(ExternalServiceError):
    """Database operation failed."""

class CacheError(ExternalServiceError):
    """Cache operation failed."""
```

---

## Summary

| Rule | Bad | Good |
|---|---|---|
| Return codes | `if result == E_OK` chains | Raise and let propagate |
| Context | `raise ValueError("bad")` | Include what failed and why |
| Third-party exceptions | Leak `requests.HTTPError` | Wrap in your own hierarchy |
| None returns | `if user is None: ...` everywhere | Special Case object or raise |
| None arguments | `if bonus is None: bonus = default` | Default parameter values |
| Try/except scope | Mixed with business logic | Isolated in error-handler function |
