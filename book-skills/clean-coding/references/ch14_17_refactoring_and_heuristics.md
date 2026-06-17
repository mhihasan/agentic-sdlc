# Chapters 14–17: Successive Refinement, Refactoring, and Smells & Heuristics

## Chapters 14–16: Case Studies Summary

Chapters 14 (Successive Refinement), 15 (JUnit Internals), and 16 (Refactoring SerialDate) are **live refactoring case studies in Java**. The lesson from all three is identical:

> "It is not enough for code to work. Code that works is often badly broken. Programmers who satisfy themselves with merely working code are behaving unprofessionally."

### The Successive Refinement Pattern

All three chapters demonstrate the same workflow:
1. Write code that works (messy, long, tangled)
2. Write tests to lock in the behavior
3. Refactor aggressively — small, safe, test-backed steps
4. The code gets smaller, clearer, and more structured

**Python equivalent: the refactoring cycle**

```python
# Step 1: Working but messy (Args parser initial version)
def parse_args(schema: str, args: list[str]) -> dict:
    result = {}
    schema_parts = schema.split(",")
    schema_map = {}
    for s in schema_parts:
        s = s.strip()
        if len(s) == 1:
            schema_map[s] = "bool"
        elif s.endswith("*"):
            schema_map[s[0]] = "str"
        elif s.endswith("#"):
            schema_map[s[0]] = "int"
    for i, arg in enumerate(args):
        if arg.startswith("-"):
            for c in arg[1:]:
                if schema_map.get(c) == "bool":
                    result[c] = True
                elif schema_map.get(c) == "str":
                    result[c] = args[i+1] if i+1 < len(args) else ""
                elif schema_map.get(c) == "int":
                    result[c] = int(args[i+1]) if i+1 < len(args) else 0
    return result

# Step 2: Write tests first, then refactor
def test_bool_flag():
    args = parse_args("l", ["-l"])
    assert args["l"] is True

def test_string_arg():
    args = parse_args("d*", ["-d", "/usr/logs"])
    assert args["d"] == "/usr/logs"

def test_int_arg():
    args = parse_args("p#", ["-p", "8080"])
    assert args["p"] == 8080

# Step 3: Refactored — SRP, OCP, clear structure
from abc import ABC, abstractmethod
from typing import Any

class ArgumentMarshaler(ABC):
    @abstractmethod
    def set(self, value: str) -> None: ...

    @abstractmethod
    def get(self) -> Any: ...

class BoolArgumentMarshaler(ArgumentMarshaler):
    def __init__(self) -> None:
        self._value = False

    def set(self, value: str) -> None:
        self._value = True

    def get(self) -> bool:
        return self._value

class StringArgumentMarshaler(ArgumentMarshaler):
    def __init__(self) -> None:
        self._value = ""

    def set(self, value: str) -> None:
        self._value = value

    def get(self) -> str:
        return self._value

class IntArgumentMarshaler(ArgumentMarshaler):
    def __init__(self) -> None:
        self._value = 0

    def set(self, value: str) -> None:
        try:
            self._value = int(value)
        except ValueError:
            raise ArgsException(f"Argument -{self._flag} expects an integer")

    def get(self) -> int:
        return self._value

class Args:
    _MARSHALERS: dict[str, type[ArgumentMarshaler]] = {
        "": BoolArgumentMarshaler,
        "*": StringArgumentMarshaler,
        "#": IntArgumentMarshaler,
    }

    def __init__(self, schema: str, args: list[str]) -> None:
        self._marshalers: dict[str, ArgumentMarshaler] = {}
        self._parse_schema(schema)
        self._parse_args(args)

    def get_boolean(self, flag: str) -> bool:
        return self._marshalers.get(flag, BoolArgumentMarshaler()).get()

    def get_string(self, flag: str) -> str:
        return self._marshalers.get(flag, StringArgumentMarshaler()).get()

    def get_int(self, flag: str) -> int:
        return self._marshalers.get(flag, IntArgumentMarshaler()).get()

    def _parse_schema(self, schema: str) -> None:
        for element in schema.split(","):
            element = element.strip()
            if element:
                self._parse_schema_element(element)

    def _parse_schema_element(self, element: str) -> None:
        flag = element[0]
        tail = element[1:]
        marshaler_class = self._MARSHALERS.get(tail)
        if marshaler_class is None:
            raise ArgsException(f"Argument: {flag} has invalid format: {tail}")
        self._marshalers[flag] = marshaler_class()
```

---

# Chapter 17: Smells and Heuristics

## Complete Reference

A "code smell" is a surface indication that a deeper problem exists. These are the heuristics Robert Martin uses when reviewing code.

---

### C — Comments

| Code | Smell | Fix |
|------|-------|-----|
| C1 | Inappropriate information (changelogs, revision history) | Delete; use git |
| C2 | Obsolete comment | Update or delete |
| C3 | Redundant comment (`i++ // increment i`) | Delete |
| C4 | Poorly written comment | Rewrite or delete |
| C5 | Commented-out code | Delete — git remembers it |

---

### E — Environment

| Code | Smell | Fix |
|------|-------|-----|
| E1 | Build requires more than one step | `make`, `./build.sh`, or single `docker build` |
| E2 | Tests require more than one step | `pytest` with zero config |

```python
# E2: Tests should run with one command
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "--tb=short -q"

# Then: just run `pytest`
```

---

### F — Functions

| Code | Smell | Fix |
|------|-------|-----|
| F1 | Too many arguments (> 3) | Wrap in parameter object |
| F2 | Output arguments | Mutate `self` or return new value |
| F3 | Flag arguments (boolean param) | Split into two functions |
| F4 | Dead function (never called) | Delete it |

```python
# F1: Too many arguments → parameter object
# BAD
def create_user(first_name, last_name, email, age, phone, address): ...

# GOOD
@dataclass
class UserRegistration:
    first_name: str
    last_name: str
    email: str
    age: int
    phone: str
    address: str

def create_user(registration: UserRegistration) -> User: ...

# F3: Flag argument → split
# BAD
def render(page, include_suite_setup: bool): ...

# GOOD
def render_test_page(page): ...
def render_suite_page(page): ...
```

---

### G — General

| Code | Key Smell | Python Fix |
|------|-----------|------------|
| G2 | Obvious behavior unimplemented | Follow principle of least surprise |
| G3 | Incorrect behavior at boundaries | Test edge cases: 0, empty, max, None |
| G5 | Duplication (most important!) | Extract function/class; use inheritance or composition |
| G6 | Code at wrong abstraction level | Don't mix SQL and HTML in same function |
| G8 | Too much information (wide interfaces) | Narrow interfaces; expose less |
| G9 | Dead code | Delete unreachable `if` branches, uncalled functions |
| G10 | Vertical separation | Declare variables close to use |
| G11 | Inconsistency | If `fetch_user` then `fetch_order`, not `get_order` |
| G13 | Artificial coupling | Don't put utility in wrong class just because it's convenient |
| G14 | Feature envy | A method that uses another class's data more than its own → move it |
| G15 | Selector arguments | Boolean/enum args that select behavior → split function |
| G16 | Obscured intent | Name the magic; extract explanatory variables |
| G19 | Use explanatory variables | Extract intermediate results to named variables |
| G23 | Prefer polymorphism to if/elif | Use Protocol/ABC + dispatch |
| G25 | Replace magic numbers with named constants | `MAX_RETRIES = 3` |
| G28 | Encapsulate conditionals | `if is_eligible_for_discount(order):` |
| G29 | Avoid negative conditionals | `if is_active():` not `if not is_inactive():` |
| G30 | Functions should do one thing | Extract until you can't anymore |
| G33 | Encapsulate boundary conditions | `next_level = level + 1` instead of repeating `level + 1` |
| G35 | Keep configurable data at high levels | Constants in config, not buried in functions |
| G36 | Avoid transitive navigation (Law of Demeter) | `a.method()` not `a.get_b().get_c().method()` |

```python
# G5: Duplication — Template Method pattern
class DataProcessor(ABC):
    def process(self, data: list) -> list:
        """Template method — defines the algorithm skeleton."""
        validated = self._validate(data)
        transformed = self._transform(validated)
        return self._output(transformed)

    @abstractmethod
    def _validate(self, data: list) -> list: ...

    @abstractmethod
    def _transform(self, data: list) -> list: ...

    def _output(self, data: list) -> list:
        return data  # default — override if needed


# G19: Explanatory variables
# BAD
if re.match(r"[^@]+@[^@]+\.[^@]+", user_input) and len(user_input) < 255:
    ...

# GOOD
is_valid_email = bool(re.match(r"[^@]+@[^@]+\.[^@]+", user_input))
is_reasonable_length = len(user_input) < 255
if is_valid_email and is_reasonable_length:
    ...


# G28: Encapsulate conditionals
# BAD
if employee.seniority > 2 and employee.monthly_pay > 5000 and not employee.on_leave:
    ...

# GOOD
if is_eligible_for_bonus(employee):
    ...

def is_eligible_for_bonus(emp: Employee) -> bool:
    return emp.seniority > 2 and emp.monthly_pay > 5000 and not emp.on_leave


# G29: Positive conditionals
# BAD
if not buffer.should_not_compact():
    ...

# GOOD
if buffer.should_compact():
    ...


# G33: Encapsulate boundary conditions
# BAD
if tags.length == level + 1:
    ...
parts = new_parts(level + 1)

# GOOD
next_level = level + 1
if tags.length == next_level:
    ...
parts = new_parts(next_level)


# G35: Configurable data at high levels
# BAD — buried deep in logic
def retry(fn):
    for _ in range(3):  # magic number deep in code
        ...

# GOOD
MAX_RETRY_ATTEMPTS = 3  # at module/config level

def retry(fn, max_attempts: int = MAX_RETRY_ATTEMPTS):
    for _ in range(max_attempts):
        ...
```

---

### N — Names

| Code | Smell | Fix |
|------|-------|-----|
| N1 | Non-descriptive names | Use intention-revealing names |
| N2 | Names at wrong abstraction level | `page_address` not `node_module_name` |
| N3 | Non-standard nomenclature | Use established patterns: `Repository`, `Factory` |
| N4 | Ambiguous names | `rename_page` not `do_it` |
| N5 | Short names for long scopes | `i` ok in 3-line loop; use full name in 50-line function |
| N6 | Encodings in names | No `m_`, `str_`, `i_` prefixes |
| N7 | Names that hide side effects | `get_or_create_session()` not `get_session()` if it creates |

---

### T — Tests

| Code | Smell | Fix |
|------|-------|-----|
| T1 | Insufficient tests | Test everything that could break |
| T2 | No coverage tool | Use `pytest-cov`; aim for meaningful coverage |
| T3 | Skipping trivial tests | Trivial tests document behavior |
| T4 | Ignored test = ambiguity | Either fix the ambiguity or document why test is skipped |
| T5 | Don't test boundary conditions | Test 0, -1, max, empty, None |
| T6 | Test near bugs exhaustively | When you find a bug, add tests around it |
| T7 | Patterns of failure are revealing | Failures cluster? Something structural is wrong |
| T9 | Slow tests | Tests that aren't run aren't useful |

```python
# T5: Boundary conditions
def test_parser_with_no_args():
    args = Args("l", [])
    assert args.get_boolean("l") is False  # default

def test_parser_with_empty_string_arg():
    args = Args("s*", ["-s", ""])
    assert args.get_string("s") == ""

def test_parser_with_missing_value_raises():
    with pytest.raises(ArgsException):
        Args("s*", ["-s"])  # flag without value

# T2: Coverage in CI
# pyproject.toml
[tool.pytest.ini_options]
addopts = "--cov=src --cov-report=term-missing --cov-fail-under=80"
```

---

## Master Heuristics Quick Reference

```
COMMENTS:    C1-C5  → Delete most; keep only why/legal/intent
ENVIRONMENT: E1-E2  → One command to build; one command to test
FUNCTIONS:   F1-F4  → Few args; no output args; no flags; no dead code
GENERAL:     G1-G36 → The core rules — see table above
NAMES:       N1-N7  → Intention-revealing; appropriate scope; no encodings
TESTS:       T1-T9  → Sufficient; fast; boundary-aware; near-bugs
```
