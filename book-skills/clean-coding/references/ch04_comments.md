# Chapter 4: Comments

## Core Thesis
**Comments are a failure.** Every comment is an admission that you could not express yourself in code. Comments lie, drift, and mislead. The best comment is a function or variable name that makes the comment unnecessary.

> "The only truly good comment is the comment you found a way not to write." — Robert C. Martin

## Good Comments (Justified Exceptions)

### 1. Legal Comments
Required by corporate standards — acceptable, but keep minimal.
```python
# Copyright (c) 2024 Acme Corp. All rights reserved.
# Licensed under the Apache License, Version 2.0
```

### 2. Informative Comments
When the result isn't obvious from the function name alone.
```python
import re

# Matches "kk:mm AM/PM" format — e.g., "12:30 PM"
TIME_PATTERN = re.compile(r"(\d\d):(\d\d) (AM|PM)")

# Better: extract to named constant with descriptive name
TWELVE_HOUR_TIME_PATTERN = re.compile(r"(\d\d):(\d\d) (AM|PM)")
```

### 3. Explanation of Intent
When you explain *why* you chose this approach, not *what* the code does.
```python
def compare_to(self, other: "Widget") -> int:
    # We try to include the maximum number of widgets first,
    # so that the most important widgets appear at the top.
    if self.priority > other.priority:
        return -1
    elif self.priority < other.priority:
        return 1
    return 0
```

### 4. Clarification of Obscure Arguments
When you can't control the interface (third-party API).
```python
import subprocess

result = subprocess.run(
    ["find", path, "-type", "f"],
    capture_output=True,
    text=True,
    check=True,  # raise CalledProcessError if exit code != 0
)
```

### 5. Warning of Consequences
Alert other developers of important side effects.
```python
def create_test_client():
    # NOTE: Creating the TestClient is slow (~5s) because it builds the
    # entire WSGI app stack including all middleware. Do not call in a loop.
    return TestClient(app)

# WARNING: This format string is passed to eval() in the legacy reporting
# engine. Do not allow user input here without sanitization.
REPORT_TEMPLATE = "sum({values}) / len({values})"
```

### 6. TODO Comments
Acceptable when documenting known limitations or future work — but don't let them rot.
```python
# TODO: Replace with async implementation once we migrate to FastAPI (#1234)
def fetch_user_sync(user_id: int) -> User:
    return requests.get(f"/users/{user_id}").json()

# FIXME: This crashes when timezone is None — tracked in JIRA CC-456
def format_event_time(event: Event) -> str:
    return event.start_time.astimezone(event.timezone).isoformat()
```

### 7. Docstrings for Public APIs
Amplify importance of something non-obvious. Essential for public library APIs.
```python
def parse_duration(text: str) -> timedelta:
    """Parse a human-readable duration string into a timedelta.

    Supports: '2h', '30m', '45s', '1h30m', '2h15m30s'
    
    Args:
        text: Duration string in the format described above.

    Returns:
        A timedelta representing the parsed duration.

    Raises:
        ValueError: If the string cannot be parsed as a duration.

    Examples:
        >>> parse_duration('2h30m')
        datetime.timedelta(seconds=9000)
    """
```

---

## Bad Comments (Most Comments Fall Here)

### 1. Mumbling / Noise Comments
Comments that repeat what the code obviously says.

```python
# BAD: The comment adds zero information
# Set the day of the month
self.day_of_month = day_of_month

# BAD: Noise
def get_name(self) -> str:
    # Returns the name
    return self._name

# BAD: Every function has a comment that just restates the name
def load_properties(self) -> None:
    """Loads the properties."""  # tell me something I don't know
    ...
```

### 2. Misleading Comments
Inaccurate comments are worse than no comments — they actively mislead.

```python
# BAD: Comment says "closed" but code checks >= not >
def is_closed_enough(self) -> bool:
    # Returns True when this is closed
    return self.value >= 0  # actually: >= not "closed"
```

### 3. Mandated Comments
Javadoc-style rules that force comments on every function create clutter.

```python
# BAD: These add nothing, just noise
def add(self, a: int, b: int) -> int:
    """
    Add a and b.
    
    Args:
        a: The first number.
        b: The second number.
    
    Returns:
        The sum of a and b.
    """
    return a + b
```

### 4. Journal Comments (Change Logs)
Don't use source comments as a changelog. That's what version control is for.

```python
# BAD
# 2019-01-01 Bob: Added null check
# 2019-03-15 Alice: Refactored to use list comprehension
# 2020-07-01 Bob: Fixed edge case for empty list
def process_items(items: list) -> list:
    return [process(item) for item in items if item is not None]
```

### 5. Commented-Out Code — The Worst Offense
Delete it. Version control remembers it. Commented-out code terrorizes anyone who reads it.

```python
# BAD
def calculate_score(user):
    # Old implementation:
    # total = 0
    # for item in user.items:
    #     total += item.value * item.weight
    # return total / len(user.items) if user.items else 0
    
    return sum(item.value * item.weight for item in user.items) / len(user.items)
```

### 6. Too Much Information
Don't put implementation history, irrelevant details, or RFC discussions in comments.

```python
# BAD
def to_base64(data: bytes) -> str:
    # Base64 encoding was defined in RFC 2045 as part of MIME specification.
    # It uses characters A-Z, a-z, 0-9, +, / with = as padding.
    # The encoding increases size by approximately 33% because every 3 bytes
    # becomes 4 characters...
    import base64
    return base64.b64encode(data).decode()
```

### 7. Non-Local Information
A comment should describe the code it's near, not global system-wide facts.

```python
# BAD: this comment is about DEFAULT_PORT somewhere else, not this function
def connect(port: int = 8080) -> Connection:
    # DEFAULT_PORT is defined in config.py and defaults to 8080.
    # It can be overridden in production via the PORT env variable.
    return Connection(port)
```

---

## The Clean Code Alternative: Express in Code

The refactoring recipe: **When you feel the urge to write a comment, extract a function instead.**

```python
# BAD: comment explains what the block does
# Check if the employee is eligible for full benefits
if employee.flags & HOURLY_FLAG and employee.age > 65:
    ...

# GOOD: express it in code
if is_eligible_for_full_benefits(employee):
    ...

def is_eligible_for_full_benefits(employee: Employee) -> bool:
    return employee.is_hourly() and employee.age > 65
```

```python
# BAD
# Sort by last name, then first name
users.sort(key=lambda u: (u.last_name, u.first_name))

# GOOD: the key function reveals intent
def name_sort_key(user: User) -> tuple[str, str]:
    return (user.last_name, user.first_name)

users.sort(key=name_sort_key)
```

## Summary

| Comment Type | Verdict | Reason |
|---|---|---|
| Legal headers | ✅ Keep | Required, minimal |
| Intent explanation (why) | ✅ Keep | Code can't express reasoning |
| Public API docstrings | ✅ Keep | Essential for library users |
| TODO / FIXME | ✅ Keep (short-term) | Must be tracked and resolved |
| Restatement of code | ❌ Delete | Adds noise, can mislead |
| Changelog in comments | ❌ Delete | Use git |
| Commented-out code | ❌ Delete | Use git |
| What-not-why comments | ❌ Delete | Express in code instead |
| Mandated boilerplate | ❌ Delete | Noise, never updated |
